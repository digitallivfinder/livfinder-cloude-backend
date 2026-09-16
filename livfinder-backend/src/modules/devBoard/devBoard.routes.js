import { Router } from "express";
import { z } from "zod";
import { asyncHandler } from "../../middleware/errors.js";
import { validate } from "../../middleware/validation.js";
import { writeLimiter } from "../../middleware/rateLimit.js";
import { requireAuth, requireAdmin, requirePermission } from "../../middleware/auth.js";
import { detailResponse } from "../../utils/http.js";
import { auditFromRequest } from "../system/audit.service.js";
import * as board from "./devBoard.repository.js";
import {
  createColumnSchema,
  renameColumnSchema,
  reorderColumnsSchema,
  createCardSchema,
  updateCardSchema,
  reorderCardsSchema,
  createLabelSchema,
  updateLabelSchema,
  commentBodySchema,
  createCommentSchema,
  updateSettingsSchema,
  LABEL_COLORS,
} from "./devBoard.schemas.js";

/**
 * Internal Kanban board for staff to track the pipeline of upcoming
 * developments. One board, self-contained module — see
 * db/db/migrations/0054_dev_board.sql for the schema.
 */
const router = Router();

router.use(requireAuth, requireAdmin);

const publicIdParam = z.object({ id: z.string().trim().min(10).max(40) });
const cardLabelParams = z.object({
  cardId: z.string().trim().min(10).max(40),
  labelId: z.string().trim().min(10).max(40),
});

router.get(
  "/board",
  requirePermission("devBoard.view"),
  asyncHandler(async (req, res) => {
    const [columns, settings] = await Promise.all([board.getBoard(), board.getSettings()]);
    res.json(detailResponse({ columns, labelPalette: LABEL_COLORS, backgroundImageUrl: settings.backgroundImageUrl }));
  })
);

router.patch(
  "/settings",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ body: updateSettingsSchema }),
  asyncHandler(async (req, res) => {
    await board.updateSettings(req.body);
    await auditFromRequest(req, { action: "devBoard.settings_updated", subjectType: "devBoardSettings", changes: req.body });
    res.json(detailResponse({ backgroundImageUrl: req.body.backgroundImageUrl ?? null }));
  })
);

router.get(
  "/labels",
  requirePermission("devBoard.view"),
  asyncHandler(async (req, res) => {
    res.json(detailResponse(await board.listLabels()));
  })
);

router.post(
  "/labels",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ body: createLabelSchema }),
  asyncHandler(async (req, res) => {
    const label = await board.createLabel(req.body);
    await auditFromRequest(req, { action: "devBoard.label_created", subjectType: "devBoardLabel", subjectLabel: label.id });
    res.status(201).json(detailResponse(label));
  })
);

router.patch(
  "/labels/:id",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ params: publicIdParam, body: updateLabelSchema }),
  asyncHandler(async (req, res) => {
    await board.updateLabel(req.params.id, req.body);
    await auditFromRequest(req, { action: "devBoard.label_updated", subjectType: "devBoardLabel", subjectLabel: req.params.id, changes: req.body });
    res.json(detailResponse({ id: req.params.id }));
  })
);

router.delete(
  "/labels/:id",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ params: publicIdParam }),
  asyncHandler(async (req, res) => {
    await board.deleteLabel(req.params.id);
    await auditFromRequest(req, { action: "devBoard.label_deleted", subjectType: "devBoardLabel", subjectLabel: req.params.id });
    res.status(204).end();
  })
);

router.post(
  "/columns",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ body: createColumnSchema }),
  asyncHandler(async (req, res) => {
    const column = await board.createColumn(req.body);
    await auditFromRequest(req, { action: "devBoard.column_created", subjectType: "devBoardColumn", subjectLabel: column.id });
    res.status(201).json(detailResponse(column));
  })
);

router.patch(
  "/columns/:id",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ params: publicIdParam, body: renameColumnSchema }),
  asyncHandler(async (req, res) => {
    const column = await board.renameColumn(req.params.id, req.body);
    await auditFromRequest(req, { action: "devBoard.column_renamed", subjectType: "devBoardColumn", subjectLabel: req.params.id, changes: req.body });
    res.json(detailResponse(column));
  })
);

router.post(
  "/columns/reorder",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ body: reorderColumnsSchema }),
  asyncHandler(async (req, res) => {
    await board.reorderColumns(req.body);
    await auditFromRequest(req, { action: "devBoard.columns_reordered", subjectType: "devBoardColumn" });
    res.status(204).end();
  })
);

router.delete(
  "/columns/:id",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ params: publicIdParam }),
  asyncHandler(async (req, res) => {
    await board.archiveColumn(req.params.id);
    await auditFromRequest(req, { action: "devBoard.column_deleted", subjectType: "devBoardColumn", subjectLabel: req.params.id });
    res.status(204).end();
  })
);

router.post(
  "/cards",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ body: createCardSchema }),
  asyncHandler(async (req, res) => {
    const card = await board.createCard({ ...req.body, createdBy: req.auth.user.id });
    await auditFromRequest(req, { action: "devBoard.card_created", subjectType: "devBoardCard", subjectLabel: card.id });
    res.status(201).json(detailResponse(card));
  })
);

router.patch(
  "/cards/:id",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ params: publicIdParam, body: updateCardSchema }),
  asyncHandler(async (req, res) => {
    await board.updateCard(req.params.id, req.body);
    await auditFromRequest(req, { action: "devBoard.card_updated", subjectType: "devBoardCard", subjectLabel: req.params.id, changes: req.body });
    res.json(detailResponse({ id: req.params.id }));
  })
);

router.post(
  "/cards/reorder",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ body: reorderCardsSchema }),
  asyncHandler(async (req, res) => {
    await board.reorderCards(req.body);
    await auditFromRequest(req, { action: "devBoard.cards_reordered", subjectType: "devBoardCard" });
    res.status(204).end();
  })
);

router.delete(
  "/cards/:id",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ params: publicIdParam }),
  asyncHandler(async (req, res) => {
    await board.archiveCard(req.params.id);
    await auditFromRequest(req, { action: "devBoard.card_deleted", subjectType: "devBoardCard", subjectLabel: req.params.id });
    res.status(204).end();
  })
);

router.post(
  "/cards/:cardId/labels/:labelId",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ params: cardLabelParams }),
  asyncHandler(async (req, res) => {
    await board.attachLabel(req.params.cardId, req.params.labelId);
    res.status(204).end();
  })
);

router.delete(
  "/cards/:cardId/labels/:labelId",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ params: cardLabelParams }),
  asyncHandler(async (req, res) => {
    await board.detachLabel(req.params.cardId, req.params.labelId);
    res.status(204).end();
  })
);

router.get(
  "/cards/:id/comments",
  requirePermission("devBoard.view"),
  validate({ params: publicIdParam }),
  asyncHandler(async (req, res) => {
    res.json(detailResponse(await board.listComments(req.params.id)));
  })
);

router.post(
  "/cards/:id/comments",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ params: publicIdParam, body: createCommentSchema }),
  asyncHandler(async (req, res) => {
    const commentId = await board.addComment({ cardId: req.params.id, authorUserId: req.auth.user.id, body: req.body.body, imageUrl: req.body.imageUrl });
    await auditFromRequest(req, { action: "devBoard.comment_added", subjectType: "devBoardComment", subjectLabel: commentId });
    res.status(201).json(detailResponse({ id: commentId }));
  })
);

router.patch(
  "/comments/:id",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ params: publicIdParam, body: commentBodySchema }),
  asyncHandler(async (req, res) => {
    await board.updateComment(req.params.id, req.body.body);
    await auditFromRequest(req, { action: "devBoard.comment_updated", subjectType: "devBoardComment", subjectLabel: req.params.id });
    res.json(detailResponse({ id: req.params.id }));
  })
);

router.delete(
  "/comments/:id",
  requirePermission("devBoard.edit"),
  writeLimiter,
  validate({ params: publicIdParam }),
  asyncHandler(async (req, res) => {
    await board.deleteComment(req.params.id);
    await auditFromRequest(req, { action: "devBoard.comment_deleted", subjectType: "devBoardComment", subjectLabel: req.params.id });
    res.status(204).end();
  })
);

export default router;
