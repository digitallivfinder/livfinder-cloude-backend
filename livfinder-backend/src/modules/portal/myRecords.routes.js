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
              l.title AS listing_title, l.public_id AS listing_public_id, l.reference AS listing_reference,
              l.price, l.currency_code, l.status AS listing_status, p.code AS purpose_code,
              o.name AS organization_name,
              -- The buyer's latest offer on this listing, and the seller's latest answer to it.
              ofr.reference AS offer_reference, ofr.amount AS offer_amount, ofr.currency_code AS offer_currency,
              ofr.status AS offer_status, ofr.response_note AS offer_response_note,
              (SELECT oe.amount FROM offer_events oe WHERE oe.offer_id = ofr.id AND oe.event_type = 'countered'
                ORDER BY oe.id DESC LIMIT 1) AS offer_counter_amount
         FROM inquiries i
         LEFT JOIN listings l ON l.id = i.listing_id
         LEFT JOIN purposes p ON p.id = l.purpose_id
         LEFT JOIN organizations o ON o.id = i.organization_id
         LEFT JOIN offers ofr ON ofr.id = (
              SELECT o2.id FROM offers o2
               WHERE o2.listing_id = i.listing_id AND o2.buyer_user_id = i.user_id AND o2.deleted_at IS NULL
               ORDER BY o2.id DESC LIMIT 1)
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
          listingId: row.listing_public_id ?? null,
          listingReference: row.listing_reference ?? null,
          askingPrice: row.price != null ? { amount: Number(row.price), currency: row.currency_code } : null,
          // An offer can be made on a live listing for sale, from this enquiry.
          canOffer: Boolean(row.listing_public_id && row.listing_status === "active" && row.purpose_code === "sale"),
          offer: row.offer_reference
            ? {
                reference: row.offer_reference,
                amount: Number(row.offer_amount),
                currency: row.offer_currency,
                status: row.offer_status,
                counterAmount: row.offer_counter_amount != null ? Number(row.offer_counter_amount) : null,
                responseNote: row.offer_response_note ?? null,
              }
            : null,
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
