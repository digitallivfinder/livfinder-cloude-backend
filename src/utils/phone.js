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
