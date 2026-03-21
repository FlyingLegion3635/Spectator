const { MongoClient } = require('mongodb');
const crypto = require('crypto');
const { env } = require('../config/env');

function isSentinel(value) {
  return value && typeof value === 'object' && value.__sentinel;
}

function generateId() {
  return crypto.randomUUID();
}

const FieldValue = {
  serverTimestamp: () => ({ __sentinel: 'serverTimestamp' }),
  delete: () => ({ __sentinel: 'deleteField' }),
};

function create() {
  const client = new MongoClient(env.MONGO_URI);
  let _db = null;
  let _connected = false;

  async function getMongoDb() {
    if (!_connected) {
      await client.connect();
      _connected = true;
    }
    if (!_db) {
      _db = client.db(env.MONGO_DB_NAME || 'spectator');
    }
    return _db;
  }

  function processDataForWrite(data) {
    const setFields = {};
    const unsetFields = {};

    for (const [key, value] of Object.entries(data)) {
      if (value === undefined) continue;

      if (isSentinel(value)) {
        if (value.__sentinel === 'serverTimestamp') {
          setFields[key] = new Date();
        } else if (value.__sentinel === 'deleteField') {
          unsetFields[key] = '';
        }
      } else {
        setFields[key] = value;
      }
    }

    return { setFields, unsetFields };
  }

  function processDocForRead(doc) {
    if (!doc) return null;
    const { _id, ...rest } = doc;
    const result = { id: String(_id), ...rest };

    for (const [key, value] of Object.entries(result)) {
      if (value instanceof Date) {
        result[key] = value.toISOString();
      }
    }

    return result;
  }

  function createDocSnapshot(collectionName, doc) {
    const processed = processDocForRead(doc);
    const exists = !!processed;
    const id = processed?.id || null;

    return {
      exists,
      id,
      ref: exists ? createDocRef(collectionName, id) : null,
      data() {
        if (!exists) return undefined;
        const { id: _id, ...rest } = processed;
        return rest;
      },
    };
  }

  function createDocRef(collectionName, docId) {
    const ref = {
      id: docId,
      _tableName: collectionName,

      async get() {
        const mongoDb = await getMongoDb();
        const doc = await mongoDb.collection(collectionName).findOne({ _id: docId });
        return createDocSnapshot(collectionName, doc);
      },

      async update(data) {
        const mongoDb = await getMongoDb();
        const { setFields, unsetFields } = processDataForWrite(data);
        const updateOps = {};

        if (Object.keys(setFields).length > 0) {
          updateOps.$set = setFields;
        }
        if (Object.keys(unsetFields).length > 0) {
          updateOps.$unset = unsetFields;
        }

        if (Object.keys(updateOps).length > 0) {
          await mongoDb.collection(collectionName).updateOne({ _id: docId }, updateOps);
        }
      },

      async set(data, options = {}) {
        const mongoDb = await getMongoDb();
        const { setFields } = processDataForWrite(data);

        if (options.merge) {
          await mongoDb
            .collection(collectionName)
            .updateOne({ _id: docId }, { $set: setFields }, { upsert: true });
        } else {
          await mongoDb
            .collection(collectionName)
            .replaceOne({ _id: docId }, setFields, { upsert: true });
        }
      },

      async delete() {
        const mongoDb = await getMongoDb();
        await mongoDb.collection(collectionName).deleteOne({ _id: docId });
      },
    };

    return ref;
  }

  function buildMongoFilter(constraints) {
    const filter = {};

    for (const c of constraints) {
      if (c.op === '==' || c.op === '=') {
        filter[c.field] = c.value;
      } else if (c.op === 'in') {
        filter[c.field] = { $in: c.value };
      } else if (c.op === '!=') {
        filter[c.field] = { $ne: c.value };
      } else if (c.op === '<') {
        filter[c.field] = { ...(filter[c.field] || {}), $lt: c.value };
      } else if (c.op === '<=') {
        filter[c.field] = { ...(filter[c.field] || {}), $lte: c.value };
      } else if (c.op === '>') {
        filter[c.field] = { ...(filter[c.field] || {}), $gt: c.value };
      } else if (c.op === '>=') {
        filter[c.field] = { ...(filter[c.field] || {}), $gte: c.value };
      }
    }

    return filter;
  }

  function createQuery(collectionName, constraints = [], limitVal = null) {
    return {
      where(field, op, value) {
        return createQuery(collectionName, [...constraints, { field, op, value }], limitVal);
      },

      limit(n) {
        return createQuery(collectionName, constraints, n);
      },

      async get() {
        const mongoDb = await getMongoDb();
        const filter = buildMongoFilter(constraints);
        let cursor = mongoDb.collection(collectionName).find(filter);

        if (limitVal) {
          cursor = cursor.limit(limitVal);
        }

        const results = await cursor.toArray();
        const docs = results.map((doc) => createDocSnapshot(collectionName, doc));

        return {
          empty: docs.length === 0,
          docs,
        };
      },
    };
  }

  function collection(name) {
    const query = createQuery(name);

    return {
      where: query.where,
      limit: query.limit,
      get: query.get,

      doc(id) {
        return createDocRef(name, id);
      },

      async add(data) {
        const mongoDb = await getMongoDb();
        const id = generateId();
        const { setFields } = processDataForWrite(data);
        await mongoDb.collection(name).insertOne({ _id: id, ...setFields });
        return createDocRef(name, id);
      },
    };
  }

  function batch() {
    const operations = [];

    return {
      set(docRef, data, options = {}) {
        operations.push({
          type: 'set',
          collectionName: docRef._tableName,
          docId: docRef.id,
          data,
          options,
        });
      },

      update(docRef, data) {
        operations.push({
          type: 'update',
          collectionName: docRef._tableName,
          docId: docRef.id,
          data,
        });
      },

      delete(docRef) {
        operations.push({
          type: 'delete',
          collectionName: docRef._tableName,
          docId: docRef.id,
        });
      },

      async commit() {
        const mongoDb = await getMongoDb();
        const session = client.startSession();

        try {
          await session.withTransaction(async () => {
            for (const op of operations) {
              const coll = mongoDb.collection(op.collectionName);

              switch (op.type) {
                case 'set': {
                  const { setFields } = processDataForWrite(op.data);
                  if (op.options.merge) {
                    await coll.updateOne(
                      { _id: op.docId },
                      { $set: setFields },
                      { upsert: true, session },
                    );
                  } else {
                    await coll.replaceOne({ _id: op.docId }, setFields, {
                      upsert: true,
                      session,
                    });
                  }
                  break;
                }
                case 'update': {
                  const { setFields, unsetFields } = processDataForWrite(op.data);
                  const updateOps = {};
                  if (Object.keys(setFields).length > 0) updateOps.$set = setFields;
                  if (Object.keys(unsetFields).length > 0) updateOps.$unset = unsetFields;
                  if (Object.keys(updateOps).length > 0) {
                    await coll.updateOne({ _id: op.docId }, updateOps, { session });
                  }
                  break;
                }
                case 'delete': {
                  await coll.deleteOne({ _id: op.docId }, { session });
                  break;
                }
              }
            }
          });
        } finally {
          await session.endSession();
        }
      },
    };
  }

  const db = {
    collection,
    batch,

    async initialize() {
      await getMongoDb();
    },

    async close() {
      await client.close();
    },
  };

  return { db, FieldValue };
}

module.exports = { create };
