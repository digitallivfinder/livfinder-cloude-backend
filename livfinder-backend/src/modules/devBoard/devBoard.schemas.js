import { z } from "zod";

/**
 * Trello's own label palette is a fixed set of names, not free color pickers —
 * that is what keeps a board's labels visually consistent. This mirrors it.
 */
export const LABEL_COLORS = [
  "green", "yellow", "orange", "red", "purple",
  "blue", "sky", "lime", "pink", "black",
];

const publicId = z.string().trim().min(10).max(40);
const title = z.string().trim().min(1).max(200);
const imageUrl = z.string().trim().max(500);

export const createColumnSchema = z.object({
  name: z.string().trim().min(1).max(120),
});

export const renameColumnSchema = z.object({
  name: z.string().trim().min(1).max(120),
});

export const reorderColumnsSchema = z.object({
  orderedIds: z.array(publicId).min(1).max(200),
});

export const createCardSchema = z.object({
  columnId: publicId,
  title,
  coverImageUrl: imageUrl.optional(),
});

export const updateCardSchema = z
  .object({
    title: title.optional(),
    description: z.string().trim().max(5000).nullable().optional(),
    coverImageUrl: imageUrl.nullable().optional(),
  })
  .refine((value) => Object.keys(value).length > 0, "Nothing to update.");

const columnCardOrder = z.object({
  columnId: publicId,
  orderedCardIds: z.array(publicId).max(500),
});

export const reorderCardsSchema = z.object({
  moves: z.array(columnCardOrder).min(1).max(2),
});

export const createLabelSchema = z.object({
  name: z.string().trim().max(60).optional(),
  color: z.enum(LABEL_COLORS),
});

export const updateLabelSchema = z
  .object({
    name: z.string().trim().max(60).nullable().optional(),
    color: z.enum(LABEL_COLORS).optional(),
  })
  .refine((value) => Object.keys(value).length > 0, "Nothing to update.");

export const commentBodySchema = z.object({
  body: z.string().trim().min(1).max(4000),
});

export const updateSettingsSchema = z.object({
  backgroundImageUrl: imageUrl.nullable(),
});

export const createCommentSchema = z.object({
  body: z.string().trim().min(1).max(4000),
  imageUrl: imageUrl.optional(),
});
