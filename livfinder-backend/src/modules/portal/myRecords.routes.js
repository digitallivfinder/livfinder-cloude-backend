import { Router } from "express";
import { asyncHandler } from "../../middleware/errors.js";
import { query, queryValue } from "../../db/query.js";
import { detailResponse } from "../../utils/http.js";
import { isoDate } from "../../serializers/primitives.js";

/**
 * What a person sent, as opposed to what their account received: `/inquiries` and `/bookings`
 * are the seller's inbox. These read by `user_id`, which `claimRecordsByEmail` fills in for
 * records made before the account existed, once the address is confirmed.
 */
export const myRecordsRouter = Router();

const emailConfirmed = async (userId) =>
  Boolean(await queryValue("SELECT email_verified_at FROM users WHERE id = ?", [userId]));

myRecordsRouter.get(
  "/my-enquiries",
  asyncHandler(async (req, res) => {
    const userId = req.auth.user.id;
    const rows = await query(
      `SELECT i.public_id, i.reference, i.inquiry_type, i.subject, i.message, i.status, i.created_at,
              l.title AS listing_title, o.name AS organization_name
         FROM inquiries i
         LEFT JOIN listings l ON l.id = i.listing_id
         LEFT JOIN organizations o ON o.id = i.organization_id
        WHERE i.user_id = ? AND i.deleted_at IS NULL
        ORDER BY i.created_at DESC LIMIT 100`,
      [userId]
    );
    return res.json(
      detailResponse({
        emailConfirmed: await emailConfirmed(userId),
        items: rows.map((row) => ({
          id: row.public_id,
          reference: row.reference,
          type: row.inquiry_type,
          listing: row.listing_title ?? row.subject,
          sentTo: row.organization_name,
          message: row.message,
          status: row.status,
          sentAt: isoDate(row.created_at),
        })),
      })
    );
  })
);

myRecordsRouter.get(
  "/my-viewings",
  asyncHandler(async (req, res) => {
    const rows = await query(
      `SELECT b.public_id, b.reference, b.booking_type, b.status, b.scheduled_start, b.meeting_location,
              l.title AS listing_title, o.name AS organization_name
         FROM bookings b
         LEFT JOIN listings l ON l.id = b.listing_id
         LEFT JOIN organizations o ON o.id = b.organization_id
        WHERE b.user_id = ? AND b.deleted_at IS NULL
        ORDER BY b.scheduled_start DESC LIMIT 100`,
      [req.auth.user.id]
    );
    return res.json(
      detailResponse(
        rows.map((row) => ({
          id: row.public_id,
          reference: row.reference,
          type: row.booking_type,
          status: row.status,
          scheduledStart: isoDate(row.scheduled_start),
          location: row.meeting_location,
          listing: row.listing_title,
          with: row.organization_name,
        }))
      )
    );
  })
);
