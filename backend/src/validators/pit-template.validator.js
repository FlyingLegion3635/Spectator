const { z } = require('zod');

const inputFieldSchema = z.object({
  key: z.string().trim().min(1).max(40),
  label: z.string().trim().min(1).max(100),
  type: z.enum(['text', 'select', 'checkbox']),
  options: z.array(z.string().trim().min(1).max(80)).max(30).optional(),
  required: z.boolean().optional().default(false),
});

const separatorFieldSchema = z.object({
  key: z.string().trim().max(40).optional().default(''),
  label: z.string().trim().max(100).optional().default(''),
  type: z.literal('separator'),
  required: z.boolean().optional().default(false),
});

const titleFieldSchema = z.object({
  key: z.string().trim().max(40).optional().default(''),
  label: z.string().trim().min(1).max(100),
  type: z.literal('title'),
  required: z.boolean().optional().default(false),
});

const fieldSchema = z.discriminatedUnion('type', [
  inputFieldSchema,
  separatorFieldSchema,
  titleFieldSchema,
]);

const upsertPitTemplateSchema = z.object({
  teamNumber: z.string().trim().optional(),
  fields: z.array(fieldSchema).max(80),
});

const getPitTemplateQuerySchema = z.object({
  teamNumber: z.string().trim().optional(),
});

module.exports = {
  upsertPitTemplateSchema,
  getPitTemplateQuerySchema,
};
