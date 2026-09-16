import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { client, ensureTestPassword, adminEmail, execute } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";

/**
 * The Upcoming Developments board, against the real database: column and card
 * CRUD, the cross-column drag reorder, labels, comments, the permission gate,
 * and the cascade soft-delete of a column's cards. See
 * db/db/migrations/0054_dev_board.sql for the schema this exercises.
 */
const PASSWORD = "LivFinder!2026";
const admin = client();
const moderator = client();

let columnAId = null;
let columnBId = null;
let cardId = null;
let labelId = null;
let commentId = null;

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
  await admin.login(await adminEmail("super_admin"), PASSWORD);
  const moderatorEmail = await adminEmail("moderator");
  if (moderatorEmail) await moderator.login(moderatorEmail, PASSWORD);
});

afterAll(async () => {
  if (commentId) await execute("DELETE FROM dev_board_comments WHERE public_id = ?", [commentId]);
  if (labelId) await execute("DELETE FROM dev_board_labels WHERE public_id = ?", [labelId]);
  if (cardId) await execute("DELETE FROM dev_board_cards WHERE public_id = ?", [cardId]);
  if (columnAId) await execute("DELETE FROM dev_board_columns WHERE public_id = ?", [columnAId]);
  if (columnBId) await execute("DELETE FROM dev_board_columns WHERE public_id = ?", [columnBId]);
  await closePool();
});

describe("dev board", () => {
  it("rejects an unauthenticated request", async () => {
    const anon = client();
    const response = await anon.get("/v1/admin/dev-board/board");
    expect(response.status).toBe(401);
  });

  it("rejects a signed-in admin who does not hold devBoard.view", async () => {
    if (!moderator.csrfToken) return; // no seeded moderator in this environment
    const response = await moderator.get("/v1/admin/dev-board/board");
    expect(response.status).toBe(403);
  });

  it("creates two columns and a card, then moves the card between them by reordering", async () => {
    const suffix = Date.now();

    const columnA = await admin.send("post", "/v1/admin/dev-board/columns", { name: `Suite Column A ${suffix}` });
    expect(columnA.status).toBe(201);
    columnAId = columnA.body.data.id;

    const columnB = await admin.send("post", "/v1/admin/dev-board/columns", { name: `Suite Column B ${suffix}` });
    expect(columnB.status).toBe(201);
    columnBId = columnB.body.data.id;

    const card = await admin.send("post", "/v1/admin/dev-board/cards", { columnId: columnAId, title: "Suite card" });
    expect(card.status).toBe(201);
    cardId = card.body.data.id;
    expect(card.body.data.columnId).toBe(columnAId);

    const moved = await admin.send("post", "/v1/admin/dev-board/cards/reorder", {
      moves: [
        { columnId: columnBId, orderedCardIds: [cardId] },
        { columnId: columnAId, orderedCardIds: [] },
      ],
    });
    expect(moved.status).toBe(204);

    const board = await admin.get("/v1/admin/dev-board/board");
    const destination = board.body.data.columns.find((column) => column.id === columnBId);
    const origin = board.body.data.columns.find((column) => column.id === columnAId);
    expect(destination.cards.map((c) => c.id)).toEqual([cardId]);
    expect(origin.cards).toEqual([]);
  });

  it("renames a column and updates a card's title and description", async () => {
    const renamed = await admin.send("patch", `/v1/admin/dev-board/columns/${columnBId}`, { name: "Renamed by suite" });
    expect(renamed.status).toBe(200);

    const updated = await admin.send("patch", `/v1/admin/dev-board/cards/${cardId}`, {
      title: "Suite card (revised)",
      description: "Added by the integration suite.",
    });
    expect(updated.status).toBe(200);

    const board = await admin.get("/v1/admin/dev-board/board");
    const column = board.body.data.columns.find((c) => c.id === columnBId);
    expect(column.name).toBe("Renamed by suite");
    const persistedCard = column.cards.find((c) => c.id === cardId);
    expect(persistedCard.title).toBe("Suite card (revised)");
  });

  it("creates a label, attaches it to the card, then detaches it", async () => {
    const label = await admin.send("post", "/v1/admin/dev-board/labels", { color: "purple", name: "Suite label" });
    expect(label.status).toBe(201);
    labelId = label.body.data.id;

    const attach = await admin.send("post", `/v1/admin/dev-board/cards/${cardId}/labels/${labelId}`);
    expect(attach.status).toBe(204);

    let board = await admin.get("/v1/admin/dev-board/board");
    let card = board.body.data.columns.flatMap((c) => c.cards).find((c) => c.id === cardId);
    expect(card.labels.map((l) => l.id)).toContain(labelId);

    const detach = await admin.send("delete", `/v1/admin/dev-board/cards/${cardId}/labels/${labelId}`);
    expect(detach.status).toBe(204);

    board = await admin.get("/v1/admin/dev-board/board");
    card = board.body.data.columns.flatMap((c) => c.cards).find((c) => c.id === cardId);
    expect(card.labels.map((l) => l.id)).not.toContain(labelId);
  });

  it("adds, edits and deletes a comment on the card", async () => {
    const added = await admin.send("post", `/v1/admin/dev-board/cards/${cardId}/comments`, { body: "First pass looks good." });
    expect(added.status).toBe(201);
    commentId = added.body.data.id;

    const edited = await admin.send("patch", `/v1/admin/dev-board/comments/${commentId}`, { body: "Edited by the suite." });
    expect(edited.status).toBe(200);

    let comments = await admin.get(`/v1/admin/dev-board/cards/${cardId}/comments`);
    expect(comments.body.data.map((c) => c.id)).toContain(commentId);
    expect(comments.body.data.find((c) => c.id === commentId).body).toBe("Edited by the suite.");

    const deleted = await admin.send("delete", `/v1/admin/dev-board/comments/${commentId}`);
    expect(deleted.status).toBe(204);
    commentId = null;

    comments = await admin.get(`/v1/admin/dev-board/cards/${cardId}/comments`);
    expect(comments.body.data).toEqual([]);
  });

  it("deleting a column soft-deletes it and every card still inside it", async () => {
    const deleted = await admin.send("delete", `/v1/admin/dev-board/columns/${columnBId}`);
    expect(deleted.status).toBe(204);

    const board = await admin.get("/v1/admin/dev-board/board");
    expect(board.body.data.columns.some((c) => c.id === columnBId)).toBe(false);
    expect(board.body.data.columns.flatMap((c) => c.cards).some((c) => c.id === cardId)).toBe(false);
    // cardId and columnBId are only soft-deleted; afterAll hard-deletes both by public_id.
  });
});
