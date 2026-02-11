const { z } = require('zod');

const eventIdParamSchema = z.object({
  eventId: z.string().trim().min(1),
});

const createEventSchema = z.object({
  name: z.string().trim().min(2).max(120),
  code: z.string().trim().min(2).max(30),
  season: z.coerce.number().int().min(2020).max(2100),
  startDate: z.string().datetime().optional(),
  endDate: z.string().datetime().optional(),
  location: z.string().trim().min(2).max(140).optional(),
});

const listEventsQuerySchema = z.object({
  search: z.string().trim().optional(),
  season: z.coerce.number().int().min(2020).max(2100).optional(),
  limit: z.coerce.number().int().min(1).max(100).optional().default(25),
});

const upsertMatchesSchema = z.object({
  matches: z
    .array(
      z.object({
        matchNumber: z.coerce.number().int().positive(),
        teams: z.array(z.string().trim().min(1)).length(6),
      }),
    )
    .min(1)
    .max(200),
});

module.exports = {
  eventIdParamSchema,
  createEventSchema,
  listEventsQuerySchema,
  upsertMatchesSchema,
};
