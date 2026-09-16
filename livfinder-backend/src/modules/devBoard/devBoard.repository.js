import { query, queryOne, execute } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { ulid } from "../../utils/ids.js";
import { AppError } from "../../utils/errors.js";

async function columnRowId(publicId, executor) {
  const row = await queryOne(
    "SELECT id FROM dev_board_columns WHERE public_id = ? AND deleted_at IS NULL",
    [publicId],
    executor
  );
  if (!row) throw AppError.notFound("That column no longer exists.");
  return row.id;
}

async function cardRowId(publicId, executor) {
  const row = await queryOne(
    "SELECT id, column_id FROM dev_board_cards WHERE public_id = ? AND deleted_at IS NULL",
    [publicId],
    executor
  );
  if (!row) throw AppError.notFound("That card no longer exists.");
  return row;
}

async function labelRowId(publicId, executor) {
  const row = await queryOne("SELECT id FROM dev_board_labels WHERE public_id = ?", [publicId], executor);
  if (!row) throw AppError.notFound("That label no longer exists.");
  return row.id;
}

async function commentRowId(publicId, executor) {
  const row = await queryOne("SELECT id FROM dev_board_comments WHERE public_id = ?", [publicId], executor);
  if (!row) throw AppError.notFound("That comment no longer exists.");
  return row.id;
}

function mapCard(row) {
  return {
    id: row.public_id,
    columnId: row.column_public_id,
    title: row.title,
    description: row.description,
    coverImageUrl: row.cover_image_url,
    position: row.position,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    commentCount: Number(row.comment_count || 0),
    labels: [],
  };
}

/** The whole board in one shape: columns, each carrying its ordered cards and their labels. */
export async function getBoard() {
  const columns = await query(
    `SELECT id, public_id, name, position, created_at, updated_at
       FROM dev_board_columns
      WHERE deleted_at IS NULL
      ORDER BY position ASC, id ASC`
  );

  const cardRows = await query(
    `SELECT c.id, c.public_id, c.title, c.description, c.cover_image_url, c.position, c.created_at, c.updated_at,
            col.public_id AS column_public_id,
            (SELECT COUNT(*) FROM dev_board_comments WHERE card_id = c.id) AS comment_count
       FROM dev_board_cards c
       JOIN dev_board_columns col ON col.id = c.column_id
      WHERE c.deleted_at IS NULL
      ORDER BY c.column_id ASC, c.position ASC, c.id ASC`
  );

  const cardsByPublicId = new Map();
  const cardsByColumn = new Map();
  for (const row of cardRows) {
    const card = mapCard(row);
    cardsByPublicId.set(card.id, card);
    const bucket = cardsByColumn.get(row.column_public_id) || [];
    bucket.push(card);
    cardsByColumn.set(row.column_public_id, bucket);
  }

  const labelLinks = cardRows.length
    ? await query(
        `SELECT c.public_id AS card_public_id, l.public_id AS label_public_id, l.name, l.color
           FROM dev_board_card_labels cl
           JOIN dev_board_cards c ON c.id = cl.card_id
           JOIN dev_board_labels l ON l.id = cl.label_id
          WHERE c.deleted_at IS NULL
          ORDER BY l.position ASC, l.id ASC`
      )
    : [];
  for (const link of labelLinks) {
    const card = cardsByPublicId.get(link.card_public_id);
    if (card) card.labels.push({ id: link.label_public_id, name: link.name, color: link.color });
  }

  return columns.map((column) => ({
    id: column.public_id,
    name: column.name,
    position: column.position,
    createdAt: column.created_at,
    updatedAt: column.updated_at,
    cards: cardsByColumn.get(column.public_id) || [],
  }));
}

/** Board-wide preferences. One pinned row, so there is no id to pass in. */
export async function getSettings() {
  const row = await queryOne("SELECT background_image_url FROM dev_board_settings WHERE id = 1");
  return { backgroundImageUrl: row?.background_image_url ?? null };
}

export async function updateSettings({ backgroundImageUrl }) {
  await execute("UPDATE dev_board_settings SET background_image_url = ? WHERE id = 1", [backgroundImageUrl || null]);
}

export async function createColumn({ name }) {
  const publicId = ulid();
  const [{ next }] = await query("SELECT COALESCE(MAX(position), -1) + 1 AS next FROM dev_board_columns WHERE deleted_at IS NULL");
  await execute(
    "INSERT INTO dev_board_columns (public_id, name, position) VALUES (?, ?, ?)",
    [publicId, name, next]
  );
  return { id: publicId, name, position: next, cards: [] };
}

export async function renameColumn(columnPublicId, { name }) {
  const id = await columnRowId(columnPublicId);
  await execute("UPDATE dev_board_columns SET name = ? WHERE id = ?", [name, id]);
  return { id: columnPublicId, name };
}

export async function reorderColumns({ orderedIds }) {
  await withTransaction(async (trx) => {
    for (let index = 0; index < orderedIds.length; index += 1) {
      const id = await columnRowId(orderedIds[index], trx);
      await execute("UPDATE dev_board_columns SET position = ? WHERE id = ?", [index, id], trx);
    }
  });
}

/** Soft-deletes the column and every card still in it, together. */
export async function archiveColumn(columnPublicId) {
  await withTransaction(async (trx) => {
    const id = await columnRowId(columnPublicId, trx);
    await execute("UPDATE dev_board_cards SET deleted_at = NOW(3) WHERE column_id = ? AND deleted_at IS NULL", [id], trx);
    await execute("UPDATE dev_board_columns SET deleted_at = NOW(3) WHERE id = ?", [id], trx);
  });
}

export async function createCard({ columnId, title, createdBy, coverImageUrl }) {
  const colId = await columnRowId(columnId);
  const publicId = ulid();
  const [{ next }] = await query(
    "SELECT COALESCE(MAX(position), -1) + 1 AS next FROM dev_board_cards WHERE column_id = ? AND deleted_at IS NULL",
    [colId]
  );
  await execute(
    "INSERT INTO dev_board_cards (public_id, column_id, title, position, created_by, cover_image_url) VALUES (?, ?, ?, ?, ?, ?)",
    [publicId, colId, title, next, createdBy || null, coverImageUrl || null]
  );
  return { id: publicId, columnId, title, description: null, coverImageUrl: coverImageUrl || null, position: next, labels: [], commentCount: 0 };
}

export async function updateCard(cardPublicId, changes) {
  const { id } = await cardRowId(cardPublicId);
  const fields = [];
  const params = [];
  if (changes.title !== undefined) { fields.push("title = ?"); params.push(changes.title); }
  if (changes.description !== undefined) { fields.push("description = ?"); params.push(changes.description); }
  if (changes.coverImageUrl !== undefined) { fields.push("cover_image_url = ?"); params.push(changes.coverImageUrl); }
  if (!fields.length) return;
  params.push(id);
  await execute(`UPDATE dev_board_cards SET ${fields.join(", ")} WHERE id = ?`, params);
}

export async function archiveCard(cardPublicId) {
  const { id } = await cardRowId(cardPublicId);
  await execute("UPDATE dev_board_cards SET deleted_at = NOW(3) WHERE id = ?", [id]);
}

/**
 * Rewrites column membership and position for every card id listed, per move
 * entry. A single-entry move is a same-column drag; two entries (source and
 * destination, each with their full new order) is a cross-column drag. This
 * needs no notion of "the" moved card — every id present in a list is placed
 * in that column at that index, which is exactly what a drop handler already
 * knows after the drag ends.
 */
export async function reorderCards({ moves }) {
  await withTransaction(async (trx) => {
    for (const move of moves) {
      const colId = await columnRowId(move.columnId, trx);
      for (let index = 0; index < move.orderedCardIds.length; index += 1) {
        const { id } = await cardRowId(move.orderedCardIds[index], trx);
        await execute(
          "UPDATE dev_board_cards SET column_id = ?, position = ? WHERE id = ?",
          [colId, index, id],
          trx
        );
      }
    }
  });
}

export async function listLabels() {
  const rows = await query("SELECT public_id, name, color, position FROM dev_board_labels ORDER BY position ASC, id ASC");
  return rows.map((row) => ({ id: row.public_id, name: row.name, color: row.color }));
}

export async function createLabel({ name, color }) {
  const publicId = ulid();
  const [{ next }] = await query("SELECT COALESCE(MAX(position), -1) + 1 AS next FROM dev_board_labels");
  await execute(
    "INSERT INTO dev_board_labels (public_id, name, color, position) VALUES (?, ?, ?, ?)",
    [publicId, name || null, color, next]
  );
  return { id: publicId, name: name || null, color };
}

export async function updateLabel(labelPublicId, changes) {
  const id = await labelRowId(labelPublicId);
  const fields = [];
  const params = [];
  if (changes.name !== undefined) { fields.push("name = ?"); params.push(changes.name); }
  if (changes.color !== undefined) { fields.push("color = ?"); params.push(changes.color); }
  if (!fields.length) return;
  params.push(id);
  await execute(`UPDATE dev_board_labels SET ${fields.join(", ")} WHERE id = ?`, params);
}

export async function deleteLabel(labelPublicId) {
  const id = await labelRowId(labelPublicId);
  await execute("DELETE FROM dev_board_labels WHERE id = ?", [id]);
}

export async function attachLabel(cardPublicId, labelPublicId) {
  const { id: cardId } = await cardRowId(cardPublicId);
  const labelId = await labelRowId(labelPublicId);
  await execute("INSERT IGNORE INTO dev_board_card_labels (card_id, label_id) VALUES (?, ?)", [cardId, labelId]);
}

export async function detachLabel(cardPublicId, labelPublicId) {
  const { id: cardId } = await cardRowId(cardPublicId);
  const labelId = await labelRowId(labelPublicId);
  await execute("DELETE FROM dev_board_card_labels WHERE card_id = ? AND label_id = ?", [cardId, labelId]);
}

export async function listComments(cardPublicId) {
  const { id: cardId } = await cardRowId(cardPublicId);
  const rows = await query(
    `SELECT c.public_id, c.body, c.image_url, c.created_at, c.updated_at,
            u.id AS author_id, u.display_name, u.first_name, u.last_name
       FROM dev_board_comments c
       LEFT JOIN users u ON u.id = c.author_user_id
      WHERE c.card_id = ?
      ORDER BY c.created_at ASC, c.id ASC`,
    [cardId]
  );
  return rows.map((row) => ({
    id: row.public_id,
    body: row.body,
    imageUrl: row.image_url,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    author: row.author_id
      ? { name: row.display_name || [row.first_name, row.last_name].filter(Boolean).join(" ") || "Admin" }
      : null,
  }));
}

export async function addComment({ cardId, authorUserId, body, imageUrl }) {
  const { id: cardRowIdValue } = await cardRowId(cardId);
  const publicId = ulid();
  await execute(
    "INSERT INTO dev_board_comments (public_id, card_id, author_user_id, body, image_url) VALUES (?, ?, ?, ?, ?)",
    [publicId, cardRowIdValue, authorUserId || null, body, imageUrl || null]
  );
  return publicId;
}

export async function updateComment(commentPublicId, body) {
  const id = await commentRowId(commentPublicId);
  await execute("UPDATE dev_board_comments SET body = ? WHERE id = ?", [body, id]);
}

export async function deleteComment(commentPublicId) {
  const id = await commentRowId(commentPublicId);
  await execute("DELETE FROM dev_board_comments WHERE id = ?", [id]);
}
