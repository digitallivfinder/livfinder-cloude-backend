import { z } from "zod";

/**
 * `users.phone_e164` is a generated column over `phone_country_code` and
 * `phone_number`, so a write has to supply the parts, not the whole.
 *
 * A number that does not parse as international is stored as the national
 * number with no country code rather than being dropped — losing a contact
 * number because it was typed without a `+` would be worse than storing it
 * imprecisely.
 */
export function splitPhone(value) {
  const raw = String(value ?? "").trim();
  if (!raw) return { countryCode: null, number: null };

  const digitsOnly = raw.replace(/\D/g, "");
  if (!digitsOnly) return { countryCode: null, number: null };

  if (raw.startsWith("+")) {
    const match = /^\+(\d{1,4})\D*(\d.*)$/.exec(raw);
    if (match) {
      const number = match[2].replace(/\D/g, "").slice(0, 32);
      if (number) return { countryCode: match[1].slice(0, 8), number };
    }
  }
  return { countryCode: null, number: digitsOnly.slice(0, 32) };
}

/**
 * The international standard (E.164) in digits, country code included: a number can be no longer
 * than 15, and the shortest real ones (Niue, +683 and four digits) have 7. It holds for mobile,
 * landline and WhatsApp numbers alike, so only the digits are checked: which ranges a country uses
 * changes too often to refuse a number on it.
 */
export const MIN_PHONE_DIGITS = 7;
export const MAX_PHONE_DIGITS = 15;
export const PHONE_LENGTH_MESSAGE = `Enter ${MIN_PHONE_DIGITS} to ${MAX_PHONE_DIGITS} digits, including the country code. Digits only.`;

export function hasPhoneLength(value) {
  const digits = String(value ?? "").replace(/\D/g, "").length;
  return digits >= MIN_PHONE_DIGITS && digits <= MAX_PHONE_DIGITS;
}

/**
 * An optional number on a form: digits, with a leading + for the country code. Spaces and the
 * punctuation older numbers were saved with are taken out, and letters are refused.
 */
export const optionalPhone = z
  .string()
  .trim()
  .max(40)
  .transform((value) => value.replace(/[\s().-]/g, ""))
  .refine((value) => !value || (/^\+?\d+$/.test(value) && hasPhoneLength(value)), PHONE_LENGTH_MESSAGE)
  .optional()
  .nullable();
