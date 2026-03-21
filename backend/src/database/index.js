const { env } = require('../config/env');

function createDatabase() {
  switch (env.DB_TYPE) {
    case 'firestore':
      return require('./firestore.adapter').create();
    case 'sql':
      return require('./sql.adapter').create();
    case 'mongo':
      return require('./mongo.adapter').create();
    default:
      throw new Error(
        `Unsupported DB_TYPE: "${env.DB_TYPE}". Supported values: firestore, sql, mongo`,
      );
  }
}

const { db, FieldValue } = createDatabase();

module.exports = { db, FieldValue };
