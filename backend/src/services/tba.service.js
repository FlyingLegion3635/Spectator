const { env } = require('../config/env');
const { ApiError } = require('../utils/apiError');

const TBA_BASE = 'https://www.thebluealliance.com/api/v3';

function normalizeTeamNumber(teamNumber) {
  return String(teamNumber).replace(/[^\d]/g, '');
}

function normalizeTeamKey(teamNumberOrKey) {
  const raw = String(teamNumberOrKey || '').trim();
  if (!raw) return '';
  if (raw.startsWith('frc')) return raw;
  const normalized = normalizeTeamNumber(raw);
  return normalized ? `frc${normalized}` : '';
}

function assertTbaConfigured() {
  if (!env.TBA_API_KEY) {
    throw new ApiError(
      503,
      'TheBlueAlliance integration is not configured on the server',
    );
  }
}

async function fetchTba(path) {
  assertTbaConfigured();

  const response = await fetch(`${TBA_BASE}${path}`, {
    headers: {
      'X-TBA-Auth-Key': env.TBA_API_KEY,
      Accept: 'application/json',
    },
  });

  if (response.status === 404) {
    throw new ApiError(404, 'Resource not found in TheBlueAlliance');
  }

  if (!response.ok) {
    throw new ApiError(
      502,
      `TheBlueAlliance request failed with status ${response.status}`,
    );
  }

  return response.json();
}

async function fetchTeamLogo(teamNumber) {
  const teamKey = normalizeTeamKey(teamNumber);

  if (!teamKey) {
    throw new ApiError(400, 'Invalid team number');
  }

  const currentYear = new Date().getUTCFullYear();
  const years = [];
  for (let year = currentYear; year >= currentYear - 10; year -= 1) {
    years.push(year);
  }

  for (const year of years) {
    let media = [];
    try {
      media = await fetchTba(`/team/${teamKey}/media/${year}`);
    } catch (_error) {
      media = [];
    }

    const preferred = media.find((item) => item.type === 'avatar') || media[0];
    if (!preferred) {
      continue;
    }

    if (preferred.type === 'avatar' && preferred.details?.base64Image) {
      return `data:image/png;base64,${preferred.details.base64Image}`;
    }

    if (preferred.details?.image_partial) {
      return `https://www.thebluealliance.com${preferred.details.image_partial}`;
    }
  }

  return '';
}

async function fetchTeamInfo(teamNumber) {
  const normalized = normalizeTeamNumber(teamNumber);

  if (!normalized) {
    throw new ApiError(400, 'Invalid team number');
  }

  const teamKey = `frc${normalized}`;
  const [team, logoUrl] = await Promise.all([
    fetchTba(`/team/${teamKey}`),
    fetchTeamLogo(normalized).catch(() => ''),
  ]);

  return {
    teamNumber: normalized,
    key: team.key || teamKey,
    nickname: team.nickname || '',
    name: team.name || '',
    schoolName: team.school_name || '',
    city: team.city || '',
    state: team.state_prov || '',
    country: team.country || '',
    website: team.website || '',
    rookieYear: team.rookie_year || null,
    districtKey: team.district_key || '',
    logoUrl,
  };
}

async function fetchTeamEvents(teamNumber, year) {
  const teamKey = normalizeTeamKey(teamNumber);

  if (!teamKey) {
    throw new ApiError(400, 'Invalid team number');
  }

  const events = await fetchTba(`/team/${teamKey}/events/${year}`);

  return events.map((event) => ({
    key: event.key,
    name: event.name,
    shortName: event.short_name || '',
    eventCode: event.event_code || '',
    districtKey: event.district?.key || '',
    city: event.city || '',
    stateProv: event.state_prov || '',
    country: event.country || '',
    startDate: event.start_date || '',
    endDate: event.end_date || '',
  }));
}

function normalizeAllianceTeams(alliances, allianceName) {
  const teams = alliances?.[allianceName]?.team_keys || [];
  return teams.map((teamKey) => Number(String(teamKey).replace('frc', '')) || 0);
}

async function fetchEventMatches(eventKey) {
  const matches = await fetchTba(`/event/${eventKey}/matches/simple`);

  return matches
    .map((match) => {
      const red = normalizeAllianceTeams(match.alliances, 'red');
      const blue = normalizeAllianceTeams(match.alliances, 'blue');

      return {
        key: match.key,
        eventKey: match.event_key,
        compLevel: match.comp_level,
        setNumber: match.set_number,
        matchNumber: match.match_number,
        teams: [...red, ...blue],
        redTeams: red,
        blueTeams: blue,
        time: match.time || null,
        predictedTime: match.predicted_time || null,
      };
    })
    .sort((a, b) => Number(a.matchNumber) - Number(b.matchNumber));
}

function translateKeyLabel(type, key) {
  const value = String(key || '').trim();
  if (!value) return '';

  if (type === 'district' && /^(\d{4})([a-z]+)$/i.test(value)) {
    const [, year, code] = value.match(/^(\d{4})([a-z]+)$/i);
    const map = {
      pch: 'Peachtree District',
      fim: 'FIRST In Michigan District',
      fnc: 'FIRST North Carolina District',
      ne: 'New England District',
      pnw: 'Pacific Northwest District',
    };
    return `${map[code.toLowerCase()] || code.toUpperCase()} (${year})`;
  }

  if (type === 'team' && value.startsWith('frc')) {
    return `Team ${value.replace('frc', '')}`;
  }

  if (type === 'match') {
    return value.toUpperCase();
  }

  if (type === 'event') {
    return value.toUpperCase();
  }

  return value;
}

function translateKeys({ districtKey, teamKey, matchKey, eventKey }) {
  return {
    districtKey: districtKey || '',
    districtLabel: translateKeyLabel('district', districtKey),
    teamKey: teamKey || '',
    teamLabel: translateKeyLabel('team', teamKey),
    matchKey: matchKey || '',
    matchLabel: translateKeyLabel('match', matchKey),
    eventKey: eventKey || '',
    eventLabel: translateKeyLabel('event', eventKey),
  };
}

module.exports = {
  fetchTeamInfo,
  fetchTeamLogo,
  fetchTeamEvents,
  fetchEventMatches,
  translateKeys,
};
