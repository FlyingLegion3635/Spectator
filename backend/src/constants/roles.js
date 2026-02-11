const ROLES = {
  TEAM_MANAGER: 'team_manager',
  SCOUT_MANAGER: 'scout_manager',
  SCOUTER: 'scouter',
  LEGACY_MANAGER: 'manager',
};

function normalizeRole(role) {
  if (role === ROLES.LEGACY_MANAGER) {
    return ROLES.TEAM_MANAGER;
  }

  if (
    role === ROLES.TEAM_MANAGER ||
    role === ROLES.SCOUT_MANAGER ||
    role === ROLES.SCOUTER
  ) {
    return role;
  }

  return ROLES.SCOUTER;
}

module.exports = { ROLES, normalizeRole };
