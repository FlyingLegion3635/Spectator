const { z } = require('zod');

const matchEntryIdParamSchema = z.object({
  id: z.string().trim().min(1),
});

const createMatchEntrySchema = z
  .object({
    eventId: z.string().trim().nullable().optional(),
    datasheetId: z.string().trim().nullable().optional(),
    matchNumber: z.string().trim().min(1).max(20),
    teamNumber: z.string().trim().min(1).max(20),
    allianceColor: z.enum(['Red', 'Blue']),
    fireRate: z.coerce.number().min(0).max(40).optional().default(0),
    shotsAttempted: z.coerce.number().int().min(0).max(400).optional(),

    // Compatibility alias for existing Flutter naming.
    ballsShot: z.coerce.number().int().min(0).max(400).optional(),

    accuracy: z.coerce.number().min(0).max(1),
    calculatedPoints: z.coerce.number().int().min(0).max(600),
    autoClimb: z.coerce.boolean().default(false),
    climbLevel: z.enum(['None', 'L1', 'L2', 'L3']).default('None'),
    scoutedAt: z.string().datetime().optional(),
  })
  .refine((value) => value.shotsAttempted !== undefined || value.ballsShot !== undefined, {
    message: 'shotsAttempted or ballsShot is required',
    path: ['shotsAttempted'],
  })
  .transform((value) => ({
    eventId: value.eventId,
    datasheetId: value.datasheetId,
    matchNumber: value.matchNumber,
    teamNumber: value.teamNumber,
    allianceColor: value.allianceColor,
    fireRate: value.fireRate,
    shotsAttempted: value.shotsAttempted ?? value.ballsShot ?? 0,
    accuracy: value.accuracy,
    calculatedPoints: value.calculatedPoints,
    autoClimb: value.autoClimb,
    climbLevel: value.climbLevel,
    scoutedAt: value.scoutedAt,
  }));

const updateMatchEntrySchema = z
  .object({
    eventId: z.string().trim().nullable().optional(),
    datasheetId: z.string().trim().nullable().optional(),
    matchNumber: z.string().trim().min(1).max(20),
    teamNumber: z.string().trim().min(1).max(20),
    allianceColor: z.enum(['Red', 'Blue']),
    fireRate: z.coerce.number().min(0).max(40).optional().default(0),
    shotsAttempted: z.coerce.number().int().min(0).max(400).optional(),
    ballsShot: z.coerce.number().int().min(0).max(400).optional(),
    accuracy: z.coerce.number().min(0).max(1),
    calculatedPoints: z.coerce.number().int().min(0).max(600),
    autoClimb: z.coerce.boolean().default(false),
    climbLevel: z.enum(['None', 'L1', 'L2', 'L3']).default('None'),
    scoutedAt: z.string().datetime().optional(),
  })
  .refine((value) => value.shotsAttempted !== undefined || value.ballsShot !== undefined, {
    message: 'shotsAttempted or ballsShot is required',
    path: ['shotsAttempted'],
  })
  .transform((value) => ({
    eventId: value.eventId,
    datasheetId: value.datasheetId,
    matchNumber: value.matchNumber,
    teamNumber: value.teamNumber,
    allianceColor: value.allianceColor,
    fireRate: value.fireRate,
    shotsAttempted: value.shotsAttempted ?? value.ballsShot ?? 0,
    accuracy: value.accuracy,
    calculatedPoints: value.calculatedPoints,
    autoClimb: value.autoClimb,
    climbLevel: value.climbLevel,
    scoutedAt: value.scoutedAt,
  }));

const listMatchEntriesQuerySchema = z.object({
  eventId: z.string().trim().optional(),
  datasheetId: z.string().trim().optional(),
  teamNumber: z.string().trim().optional(),
  matchNumber: z.string().trim().optional(),
  limit: z.coerce.number().int().min(1).max(150).optional().default(50),
});

const teamSummaryParamSchema = z.object({
  teamNumber: z.string().trim().min(1),
});

const restoreMatchEntrySchema = z.object({
  version: z.coerce.number().int().min(1),
});

module.exports = {
  matchEntryIdParamSchema,
  createMatchEntrySchema,
  updateMatchEntrySchema,
  restoreMatchEntrySchema,
  listMatchEntriesQuerySchema,
  teamSummaryParamSchema,
};
