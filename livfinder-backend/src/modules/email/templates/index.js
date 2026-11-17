import account from "./account.js";
import business from "./business.js";
import marketplace from "./marketplace.js";

/** Every email template by key ("area.name"). See catalog.js for the categories they belong to. */
export const TEMPLATES = Object.freeze({ ...account, ...marketplace, ...business });

export function templateFor(key) {
  const template = TEMPLATES[key];
  if (!template) throw new Error(`Unknown email template: ${key}`);
  return template;
}
