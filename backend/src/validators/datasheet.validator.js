const { z } = require('zod');

const createDatasheetSchema = z.object({
  season: z.coerce.number().int().min(2020).max(2100),
  name: z.string().trim().min(2).max(80),
  description: z.string().trim().max(300).optional(),
});

const listDatasheetsQuerySchema = z.object({
  teamNumber: z.string().trim().optional(),
  season: z.coerce.number().int().min(2020).max(2100).optional(),
  limit: z.coerce.number().int().min(1).max(100).optional().default(50),
});

const datasheetIdParamSchema = z.object({
  id: z.string().trim().min(1),
});

module.exports = {
  createDatasheetSchema,
  listDatasheetsQuerySchema,
  datasheetIdParamSchema,
};
