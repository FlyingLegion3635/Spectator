const { z } = require('zod');

const getAboutProfileQuerySchema = z.object({
  teamNumber: z.string().trim().optional(),
});

const upsertAboutProfileSchema = z.object({
  teamNumber: z.string().trim().optional(),
  title: z.string().trim().min(2).max(120),
  mission: z.string().trim().min(2).max(4000),
  sponsors: z.array(z.string().trim().min(1).max(120)).max(100).optional(),
  website: z.string().trim().url().optional().or(z.literal('')),
  socialLinks: z
    .array(
      z.object({
        label: z.string().trim().min(1).max(40),
        url: z.string().trim().url(),
      }),
    )
    .max(20)
    .optional(),
});

module.exports = {
  getAboutProfileQuerySchema,
  upsertAboutProfileSchema,
};
