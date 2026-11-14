/**
 * Reads a large XML file one element at a time, straight from its bytes.
 *
 * A pushed portal export can run to 75 MB and 16,000+ listings. Parsing it whole into one object
 * tree took about 1.1 GB, more than the API container has, and the process was killed mid-request.
 * Turning the bytes into one JavaScript string alone costs up to twice the file size. Here the
 * bytes are only scanned: each top-level entry (a <listing>, a <property>…) is found by position,
 * decoded and parsed on its own, so at any moment one entry is in memory, not the file.
 *
 * Every tag's name is checked against the one it closes, so a file that is not well formed is
 * still refused; the content of each entry is checked when that entry is parsed.
 */

const LT = 0x3c; // <
const GT = 0x3e; // >
const SLASH = 0x2f; // /
const BANG = 0x21; // !
const QUESTION = 0x3f; // ?
const QUOTE = 0x22; // "
const APOSTROPHE = 0x27; // '
const OPEN_BRACKET = 0x5b; // [
const CLOSE_BRACKET = 0x5d; // ]

/** Why the scanner refused a file: a tag that does not close, or closes the wrong element. */
export class XmlShapeError extends Error {}

/** The file as bytes: a pushed body already is; a string (tests, small files) is encoded. */
export const toBytes = (content) => (Buffer.isBuffer(content) ? content : Buffer.from(String(content ?? ""), "utf8"));

/** The UTF-8 text of `[start, end)`. */
export const textOf = (bytes, start, end) => bytes.toString("utf8", start, end);

const startsWith = (bytes, at, marker) => bytes.toString("latin1", at, at + marker.length) === marker;

function skipTo(bytes, from, marker) {
  const at = bytes.indexOf(marker, from, "latin1");
  if (at === -1) throw new XmlShapeError(`"${marker}" is missing.`);
  return at + marker.length;
}

/** The end of a start or end tag that begins at `from` (the `<`), past any quoted attribute values. */
function tagEnd(bytes, from, to) {
  let quote = 0;
  for (let i = from + 1; i < to; i++) {
    const byte = bytes[i];
    if (quote) {
      if (byte === quote) quote = 0;
    } else if (byte === QUOTE || byte === APOSTROPHE) {
      quote = byte;
    } else if (byte === GT) {
      return i + 1;
    }
  }
  throw new XmlShapeError("A tag is not closed with \">\".");
}

/** A `<!DOCTYPE …>` declaration, with any internal subset in brackets. */
function doctypeEnd(bytes, from, to = bytes.length) {
  let depth = 0;
  let quote = 0;
  for (let i = from + 2; i < to; i++) {
    const byte = bytes[i];
    if (quote) {
      if (byte === quote) quote = 0;
    } else if (byte === QUOTE || byte === APOSTROPHE) {
      quote = byte;
    } else if (byte === OPEN_BRACKET) {
      depth++;
    } else if (byte === CLOSE_BRACKET) {
      depth--;
    } else if (byte === GT && depth <= 0) {
      return i + 1;
    }
  }
  throw new XmlShapeError("The DOCTYPE declaration is not closed.");
}

/** The element name in a tag (`<name …>`, `</name>`). Names are ASCII-safe to read as latin1. */
function nameAt(bytes, from, end) {
  let i = from + 1;
  if (bytes[i] === SLASH) i++;
  const start = i;
  while (i < end) {
    const byte = bytes[i];
    if (byte === SLASH || byte === GT || byte <= 0x20) break;
    i++;
  }
  return bytes.toString("utf8", start, i);
}

/**
 * The elements directly inside `[from, to)` of the bytes, in order, as
 * `{ name, start, end, openEnd, selfClosing }`: bytes `[start, end)` are the whole element and
 * `[start, openEnd)` its start tag. Comments, CDATA, processing instructions and the DOCTYPE are
 * stepped over. Throws XmlShapeError when an end tag does not match its start tag, or the range
 * ends with an element still open.
 */
export function* childElements(bytes, from = 0, to = bytes.length) {
  const open = [];
  let current = null;
  let i = from;
  while (i < to) {
    const lt = bytes.indexOf(LT, i);
    if (lt === -1 || lt >= to) break;
    const next = bytes[lt + 1];
    if (next === BANG) {
      if (startsWith(bytes, lt, "<!--")) i = skipTo(bytes, lt + 4, "-->");
      else if (startsWith(bytes, lt, "<![CDATA[")) i = skipTo(bytes, lt + 9, "]]>");
      else i = doctypeEnd(bytes, lt, to);
    } else if (next === QUESTION) {
      i = skipTo(bytes, lt + 2, "?>");
    } else if (next === SLASH) {
      const end = tagEnd(bytes, lt, to);
      const name = nameAt(bytes, lt, end);
      const expected = open.pop();
      if (expected !== name) {
        throw new XmlShapeError(expected === undefined ? `</${name}> closes nothing.` : `</${name}> closes <${expected}>.`);
      }
      if (open.length === 0 && current) {
        current.end = end;
        yield current;
        current = null;
      }
      i = end;
    } else {
      const end = tagEnd(bytes, lt, to);
      const selfClosing = bytes[end - 2] === SLASH;
      const name = nameAt(bytes, lt, end);
      if (open.length === 0) {
        const element = { name, start: lt, end, openEnd: end, selfClosing };
        if (selfClosing) yield element;
        else current = element;
      }
      if (!selfClosing) open.push(name);
      i = end;
    }
  }
  if (open.length) throw new XmlShapeError(`<${open[open.length - 1]}> is never closed.`);
}

/** The file's root element: `{ name, start, openEnd, contentEnd, end, selfClosing }`. */
export function rootElement(bytes) {
  let root = null;
  for (const element of childElements(bytes)) {
    if (root) throw new XmlShapeError(`The file has more than one root element (<${root.name}> and <${element.name}>).`);
    root = element;
  }
  if (!root) return null;
  return { ...root, contentEnd: contentEnd(bytes, root) };
}

/** Where an element's content ends: the start of its end tag. */
export const contentEnd = (bytes, element) => (element.selfClosing ? element.end : bytes.lastIndexOf(LT, element.end - 1));

/** The `<!DOCTYPE …>` declaration before the root, when it declares entities; otherwise "". */
export function entityDeclarations(bytes, rootStart) {
  const head = bytes.subarray(0, rootStart);
  const at = head.indexOf("<!DOCTYPE", 0, "latin1");
  if (at === -1) return "";
  const declaration = textOf(head, at, doctypeEnd(head, at));
  return /<!ENTITY/i.test(declaration) ? declaration : "";
}
