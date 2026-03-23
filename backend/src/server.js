const { app } = require('./app');
const { env } = require('./config/env');
const { db } = require('./database');

async function start() {
  if (typeof db.initialize === 'function') {
    await db.initialize();
    // eslint-disable-next-line no-console
    console.log(`Database initialized (${env.DB_TYPE})`);
  }

  app.listen(env.PORT, () => {
    // eslint-disable-next-line no-console
    console.log(`Spectator backend listening on port ${env.PORT}`);
  });
}

start().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Failed to start server:', err);
  process.exit(1);
});
