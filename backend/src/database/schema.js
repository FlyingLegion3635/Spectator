const JSON_FIELDS = {
  users: ['passkeys'],
  students: [],
  student_tasks: [],
  events: [],
  matches: ['teams'],
  pit_entries: ['customResponses', 'versions'],
  match_entries: ['versions'],
  pit_templates: ['fields'],
  about_profiles: ['sponsors', 'socialLinks', 'uiTheme'],
  datasheets: [],
};

async function createSchema(knex) {
  if (!(await knex.schema.hasTable('users'))) {
    await knex.schema.createTable('users', (t) => {
      t.string('id', 36).primary();
      t.string('username', 255);
      t.string('usernameNormalized', 255);
      t.string('email', 255);
      t.string('emailNormalized', 255);
      t.text('passwordHash');
      t.string('teamNumber', 20);
      t.string('role', 50);
      t.string('status', 20).defaultTo('active');
      t.text('avatarUrl');
      t.json('passkeys');
      t.timestamp('passkeyUpdatedAt');
      t.timestamp('lastLoginAt');
      t.timestamp('createdAt');

      t.index(['usernameNormalized', 'teamNumber']);
      t.index(['emailNormalized']);
      t.index(['teamNumber']);
    });
  }

  if (!(await knex.schema.hasTable('students'))) {
    await knex.schema.createTable('students', (t) => {
      t.string('id', 36).primary();
      t.string('teamNumber', 20);
      t.string('name', 255);
      t.string('username', 255);
      t.string('usernameNormalized', 255);
      t.string('email', 255);
      t.string('emailNormalized', 255);
      t.string('role', 50);
      t.string('grade', 20);
      t.string('status', 20).defaultTo('invited');
      t.string('inviteCodeHash', 64);
      t.string('inviteCodeDisplay', 6);
      t.timestamp('inviteCreatedAt');
      t.string('invitedByUserId', 36);
      t.string('invitedByUsername', 255);
      t.string('linkedUserId', 36);
      t.string('linkedUsername', 255);
      t.string('linkedEmail', 255);
      t.string('approvedByUserId', 36);
      t.string('approvedByUsername', 255);
      t.timestamp('activatedAt');
      t.string('createdBy', 36);
      t.timestamp('createdAt');

      t.index(['teamNumber']);
      t.index(['teamNumber', 'status']);
      t.index(['teamNumber', 'inviteCodeHash']);
    });
  }

  if (!(await knex.schema.hasTable('student_tasks'))) {
    await knex.schema.createTable('student_tasks', (t) => {
      t.string('id', 36).primary();
      t.string('teamNumber', 20);
      t.string('studentId', 36);
      t.string('assignedToUsername', 255);
      t.string('title', 500);
      t.text('description');
      t.string('status', 20).defaultTo('todo');
      t.string('assignedByUserId', 36);
      t.string('assignedByUsername', 255);
      t.string('updatedByUserId', 36);
      t.string('updatedByUsername', 255);
      t.timestamp('completedAt');
      t.timestamp('createdAt');
      t.timestamp('updatedAt');

      t.index(['teamNumber']);
      t.index(['studentId']);
    });
  }

  if (!(await knex.schema.hasTable('events'))) {
    await knex.schema.createTable('events', (t) => {
      t.string('id', 36).primary();
      t.string('name', 255);
      t.string('code', 50);
      t.integer('season');
      t.string('location', 500);
      t.string('createdBy', 36);
      t.timestamp('createdAt');
      t.timestamp('updatedAt');

      t.index(['season']);
    });
  }

  if (!(await knex.schema.hasTable('matches'))) {
    await knex.schema.createTable('matches', (t) => {
      t.string('id', 100).primary();
      t.string('eventId', 36);
      t.integer('matchNumber');
      t.json('teams');
      t.string('updatedBy', 36);
      t.timestamp('updatedAt');

      t.index(['eventId']);
    });
  }

  if (!(await knex.schema.hasTable('pit_entries'))) {
    await knex.schema.createTable('pit_entries', (t) => {
      t.string('id', 36).primary();
      t.string('eventId', 36);
      t.string('datasheetId', 36);
      t.string('teamNumber', 20);
      t.string('teamName', 255);
      t.text('humanPlayerConfidence');
      t.text('driveTrain');
      t.text('mainScoringPotential');
      t.text('pointsInAutonomous');
      t.text('teleOperatedCapabilities');
      t.json('customResponses');
      t.string('createdByUserId', 36);
      t.string('createdByUsername', 255);
      t.string('submittedByTeamNumber', 20);
      t.string('updatedByUserId', 36);
      t.string('updatedByUsername', 255);
      t.integer('restoredFromVersion');
      t.integer('version').defaultTo(1);
      t.json('versions');
      t.timestamp('createdAt');
      t.timestamp('updatedAt');

      t.index(['eventId']);
      t.index(['datasheetId']);
      t.index(['teamNumber']);
      t.index(['submittedByTeamNumber']);
    });
  }

  if (!(await knex.schema.hasTable('match_entries'))) {
    await knex.schema.createTable('match_entries', (t) => {
      t.string('id', 36).primary();
      t.string('eventId', 36);
      t.string('datasheetId', 36);
      t.string('matchNumber', 20);
      t.string('teamNumber', 20);
      t.string('allianceColor', 10);
      t.float('fireRate');
      t.integer('shotsAttempted');
      t.float('accuracy');
      t.float('calculatedPoints');
      t.boolean('autoClimb');
      t.string('climbLevel', 50);
      t.string('scoutedAt', 50);
      t.string('createdByUserId', 36);
      t.string('createdByUsername', 255);
      t.string('submittedByTeamNumber', 20);
      t.string('updatedByUserId', 36);
      t.string('updatedByUsername', 255);
      t.integer('restoredFromVersion');
      t.integer('version').defaultTo(1);
      t.json('versions');
      t.timestamp('createdAt');
      t.timestamp('updatedAt');

      t.index(['eventId']);
      t.index(['datasheetId']);
      t.index(['teamNumber']);
      t.index(['submittedByTeamNumber']);
      t.index(['matchNumber']);
    });
  }

  if (!(await knex.schema.hasTable('pit_templates'))) {
    await knex.schema.createTable('pit_templates', (t) => {
      t.string('id', 20).primary();
      t.string('teamNumber', 20);
      t.json('fields');
      t.string('updatedByUserId', 36);
      t.string('updatedByUsername', 255);
      t.timestamp('createdAt');
      t.timestamp('updatedAt');

      t.index(['teamNumber']);
    });
  }

  if (!(await knex.schema.hasTable('about_profiles'))) {
    await knex.schema.createTable('about_profiles', (t) => {
      t.string('id', 20).primary();
      t.string('teamNumber', 20);
      t.text('title');
      t.text('mission');
      t.text('missionMarkdown');
      t.json('sponsors');
      t.text('website');
      t.json('socialLinks');
      t.json('uiTheme');
      t.string('dataVisibility', 20).defaultTo('team_only');
      t.string('updatedByUserId', 36);
      t.string('updatedByUsername', 255);
      t.timestamp('createdAt');
      t.timestamp('updatedAt');

      t.index(['teamNumber']);
    });
  }

  if (!(await knex.schema.hasTable('datasheets'))) {
    await knex.schema.createTable('datasheets', (t) => {
      t.string('id', 36).primary();
      t.string('teamNumber', 20);
      t.string('season', 10);
      t.string('name', 255);
      t.text('description');
      t.string('status', 20).defaultTo('active');
      t.string('createdByUserId', 36);
      t.string('createdByUsername', 255);
      t.timestamp('createdAt');

      t.index(['teamNumber']);
      t.index(['teamNumber', 'season']);
    });
  }
}

module.exports = { createSchema, JSON_FIELDS };
