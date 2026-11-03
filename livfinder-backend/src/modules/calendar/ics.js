/**
 * A one-event iCalendar invite (RFC 5545), as an email attachment every calendar reads.
 *
 * `method: "CANCEL"` with the same uid removes an event the recipient already holds, and a
 * higher `sequence` tells their calendar this version replaces the last one.
 */
const stamp = (date) => new Date(date).toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");

const escapeText = (value) =>
  String(value ?? "")
    .replace(/\\/g, "\\\\")
    .replace(/;/g, "\\;")
    .replace(/,/g, "\\,")
    .replace(/\r?\n/g, "\\n");

/** Lines fold at 75 octets, counting bytes so a multi-byte name is never split. */
function fold(line) {
  const parts = [];
  let current = "";
  let size = 0;
  for (const character of line) {
    const width = Buffer.byteLength(character);
    if (size + width > 75) {
      parts.push(current);
      current = " ";
      size = 1;
    }
    current += character;
    size += width;
  }
  parts.push(current);
  return parts.join("\r\n");
}

export function buildInvite({ uid, sequence = 0, method = "REQUEST", start, end, summary, description, location, organizer, attendee }) {
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//LivFinder//Viewings//EN",
    "CALSCALE:GREGORIAN",
    `METHOD:${method}`,
    "BEGIN:VEVENT",
    `UID:${uid}`,
    `SEQUENCE:${sequence}`,
    `DTSTAMP:${stamp(Date.now())}`,
    `DTSTART:${stamp(start)}`,
    `DTEND:${stamp(end)}`,
    `SUMMARY:${escapeText(summary)}`,
    ...(description ? [`DESCRIPTION:${escapeText(description)}`] : []),
    ...(location ? [`LOCATION:${escapeText(location)}`] : []),
    ...(organizer ? [`ORGANIZER;CN=LivFinder:mailto:${organizer}`] : []),
    ...(attendee ? [`ATTENDEE;ROLE=REQ-PARTICIPANT;RSVP=FALSE:mailto:${attendee}`] : []),
    `STATUS:${method === "CANCEL" ? "CANCELLED" : "CONFIRMED"}`,
    "END:VEVENT",
    "END:VCALENDAR",
  ];
  return `${lines.map(fold).join("\r\n")}\r\n`;
}
