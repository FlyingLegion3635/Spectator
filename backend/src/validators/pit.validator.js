const { z } = require('zod');

const pitEntryIdParamSchema = z.object({
  id: z.string().trim().min(1),
});

const createPitEntrySchema = z
  .object({
    eventId: z.string().trim().nullable().optional(),
    datasheetId: z.string().trim().nullable().optional(),
    teamNumber: z.string().trim().min(1).max(20),
    teamName: z.string().trim().min(1).max(120),
    humanPlayerConfidence: z.string().trim().max(120).optional(),
    driveTrain: z.string().trim().max(120).optional(),
    mainScoringPotential: z.string().trim().max(200).optional(),
    pointsInAutonomous: z.string().trim().max(60).optional(),
    teleOperatedCapabilities: z.string().trim().max(200).optional(),

    // Compatibility with existing Flutter mock payload keys.
    hpConfidence: z.string().trim().max(120).optional(),
    scoring: z.string().trim().max(200).optional(),
    auto: z.string().trim().max(60).optional(),
    teleop: z.string().trim().max(200).optional(),
    customResponses: z.record(z.any()).optional(),
  })
  .transform((value) => ({
    eventId: value.eventId,
    datasheetId: value.datasheetId,
    teamNumber: value.teamNumber,
    teamName: value.teamName,
    humanPlayerConfidence:
      value.humanPlayerConfidence || value.hpConfidence || '',
    driveTrain: value.driveTrain || '',
    mainScoringPotential: value.mainScoringPotential || value.scoring || '',
    pointsInAutonomous: value.pointsInAutonomous || value.auto || '',
    teleOperatedCapabilities:
      value.teleOperatedCapabilities || value.teleop || '',
    customResponses: value.customResponses || {},
  }));

const updatePitEntrySchema = createPitEntrySchema;

const restorePitEntrySchema = z.object({
  version: z.coerce.number().int().min(1),
});

const listPitEntriesQuerySchema = z.object({
  eventId: z.string().trim().optional(),
  datasheetId: z.string().trim().optional(),
  teamNumber: z.string().trim().optional(),
  teamName: z.string().trim().optional(),
  limit: z.coerce.number().int().min(1).max(100).optional().default(50),
});

module.exports = {
  pitEntryIdParamSchema,
  createPitEntrySchema,
  updatePitEntrySchema,
  restorePitEntrySchema,
  listPitEntriesQuerySchema,
};
