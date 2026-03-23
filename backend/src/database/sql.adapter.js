const knex = require('knex');
const crypto = require('crypto');
const { env } = require('../config/env');
const { createSchema, JSON_FIELDS } = require('./schema');

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
  const connectionConfig = {};

  if (env.DB_CLIENT === 'sqlite3') {
    connectionConfig.filename = env.DB_NAME || './spectator.sqlite';
  } else {
    connectionConfig.host = env.DB_HOST || 'localhost';
    connectionConfig.port = env.DB_PORT ? Number(env.DB_PORT) : undefined;
    connectionConfig.user = env.DB_USER;
    connectionConfig.password = env.DB_PASSWORD;
    connectionConfig.database = env.DB_NAME;
  }

  const knexInstance = knex({
    client: env.DB_CLIENT,
    connection: connectionConfig,
    useNullAsDefault: true,
    pool: { min: 0, max: 10 },
  });

  function processDataForWrite(tableName, data) {
    const result = {};
    const jsonFields = JSON_FIELDS[tableName] || [];

    for (const [key, value] of Object.entries(data)) {
      if (value === undefined) continue;

      if (isSentinel(value)) {
        if (value.__sentinel === 'serverTimestamp') {
          result[key] = new Date();
        } else if (value.__sentinel === 'deleteField') {
          result[key] = null;
        }
      } else if (jsonFields.includes(key) && value !== null && typeof value === 'object') {
        result[key] = JSON.stringify(value);
      } else if (typeof value === 'boolean') {
        result[key] = value ? 1 : 0;
      } else {
        result[key] = value;
      }
    }

    return result;
  }

  function processRowForRead(tableName, row) {
    if (!row) return null;
    const jsonFields = JSON_FIELDS[tableName] || [];
    const result = { ...row };

    for (const field of jsonFields) {
      if (result[field] != null && typeof result[field] === 'string') {
        try {
          result[field] = JSON.parse(result[field]);
        } catch (_e) {
          // leave as string
        }
      }
    }

    for (const [key, value] of Object.entries(result)) {
      if (value instanceof Date) {
        result[key] = value.toISOString();
      }
      // SQLite stores booleans as 0/1
      if (key === 'autoClimb' && typeof value === 'number') {
        result[key] = Boolean(value);
      }
    }

    return result;
  }

  function createDocSnapshot(tableName, row) {
    const processed = processRowForRead(tableName, row);
    const exists = !!processed;
    const id = processed?.id || null;

    return {
      exists,
      id,
      ref: exists ? createDocRef(tableName, id) : null,
      data() {
        if (!exists) return undefined;
        const { id: _id, ...rest } = processed;
        return rest;
      },
    };
  }

  function createDocRef(tableName, docId) {
    const ref = {
      id: docId,
      _tableName: tableName,

      async get() {
        const row = await knexInstance(tableName).where('id', docId).first();
        return createDocSnapshot(tableName, row);
      },

      async update(data) {
        const processed = processDataForWrite(tableName, data);
        await knexInstance(tableName).where('id', docId).update(processed);
      },

      async set(data, options = {}) {
        const processed = processDataForWrite(tableName, { id: docId, ...data });
        if (options.merge) {
          const existing = await knexInstance(tableName).where('id', docId).first();
          if (existing) {
            const { id: _id, ...updateData } = processed;
            await knexInstance(tableName).where('id', docId).update(updateData);
          } else {
            await knexInstance(tableName).insert(processed);
          }
        } else {
          const existing = await knexInstance(tableName).where('id', docId).first();
          if (existing) {
            const { id: _id, ...updateData } = processed;
            await knexInstance(tableName).where('id', docId).update(updateData);
          } else {
            await knexInstance(tableName).insert(processed);
          }
        }
      },

      async delete() {
        await knexInstance(tableName).where('id', docId).delete();
      },
    };

    return ref;
  }

  function createQuery(tableName, constraints = [], limitVal = null) {
    function applyConstraints(qb) {
      for (const c of constraints) {
        if (c.op === '==' || c.op === '=') {
          qb = qb.where(c.field, '=', c.value);
        } else if (c.op === 'in') {
          qb = qb.whereIn(c.field, c.value);
        } else if (c.op === '!=') {
          qb = qb.where(c.field, '!=', c.value);
        } else {
          qb = qb.where(c.field, c.op, c.value);
        }
      }
      if (limitVal) {
        qb = qb.limit(limitVal);
      }
      return qb;
    }

    return {
      where(field, op, value) {
        return createQuery(tableName, [...constraints, { field, op, value }], limitVal);
      },

      limit(n) {
        return createQuery(tableName, constraints, n);
      },

      async get() {
        let qb = knexInstance(tableName);
        qb = applyConstraints(qb);
        const rows = await qb.select('*');
        const docs = rows.map((row) => createDocSnapshot(tableName, row));

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
        const id = generateId();
        const processed = processDataForWrite(name, { id, ...data });
        await knexInstance(name).insert(processed);
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
          tableName: docRef._tableName,
          docId: docRef.id,
          data,
          options,
        });
      },

      update(docRef, data) {
        operations.push({
          type: 'update',
          tableName: docRef._tableName,
          docId: docRef.id,
          data,
        });
      },

      delete(docRef) {
        operations.push({
          type: 'delete',
          tableName: docRef._tableName,
          docId: docRef.id,
        });
      },

      async commit() {
        await knexInstance.transaction(async (trx) => {
          for (const op of operations) {
            switch (op.type) {
              case 'set': {
                const processed = processDataForWrite(op.tableName, {
                  id: op.docId,
                  ...op.data,
                });
                const existing = await trx(op.tableName).where('id', op.docId).first();
                if (existing) {
                  const { id: _id, ...updateData } = processed;
                  await trx(op.tableName).where('id', op.docId).update(updateData);
                } else {
                  await trx(op.tableName).insert(processed);
                }
                break;
              }
              case 'update': {
                const processed = processDataForWrite(op.tableName, op.data);
                await trx(op.tableName).where('id', op.docId).update(processed);
                break;
              }
              case 'delete': {
                await trx(op.tableName).where('id', op.docId).delete();
                break;
              }
            }
          }
        });
      },
    };
  }

  const db = {
    collection,
    batch,

    async initialize() {
      await createSchema(knexInstance);
    },

    async close() {
      await knexInstance.destroy();
    },
  };

  return { db, FieldValue };
}

module.exports = { create };
