const { z } = require('zod');

const teamNumberParamSchema = z.object({
  teamNumber: z.string().trim().regex(/^\d+$/, 'Team number must be numeric'),
});

const teamAndYearParamSchema = z.object({
  teamNumber: z.string().trim().regex(/^\d+$/, 'Team number must be numeric'),
  year: z.coerce.number().int().min(2020).max(2100),
});

const eventKeyParamSchema = z.object({
  eventKey: z.string().trim().min(5),
});

const translateQuerySchema = z.object({
  districtKey: z.string().trim().optional(),
  teamKey: z.string().trim().optional(),
  matchKey: z.string().trim().optional(),
  eventKey: z.string().trim().optional(),
});

module.exports = {
  teamNumberParamSchema,
  teamAndYearParamSchema,
  eventKeyParamSchema,
  translateQuerySchema,
};
