#!/usr/bin/env node
// The shelf: the cassettes in cassettes/ and index.json, which unc64.com/portal, the Machine
// Room and the game list them from. Needs Node 20 or later, and nothing else.
//
//   node tools/shelf.mjs inspect FILE.unc.png   the shelf's rules on a file; nothing is written
//   node tools/shelf.mjs add FILE.unc.png [--id ID] [--category game|demo|music|tool|other]
//        [--tags a,b] [--controls "A D: move\nSPACE: fire"] [--instructions TEXT] [--source-url https://github.com/you/game] [--featured] [--added 2026-11-14] [--discuss URL]
//   node tools/shelf.mjs remove ID
//   node tools/shelf.mjs build    after editing index.json by hand
//   node tools/shelf.mjs check    fails if a cassette breaks a rule, or index.json isn't what build writes
//
// index.json holds two kinds of thing. The curation is yours to edit: id, file, category,
// tags, controls, instructions, source_url (the author's own repository on GitHub, where
// "Read the source" leads), cover and shot (pictures the site holds: a card shows the
// screenshot with the cover on its corner, and the cassette's face without them), deck (it saves and loads: the
// Portal's player shows the tape deck's Rec and Play), featured, added, discuss (controls and instructions
// come from the cassette when the index doesn't say). The rest is read from each cassette
// (title, author, about, machine, programs, bytes, width, height, source, lang) and
// rewritten by build. The format: docs/cassettes.md in unc64/unc64, "The Portal's index".
import { readFileSync, writeFileSync, existsSync, mkdirSync, rmSync, copyFileSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const INDEX = join(ROOT, 'index.json');
export const CATEGORIES = { game: 'Game', demo: 'Demo', music: 'Music', tool: 'Tool', other: 'Other' };
// names the Portal's own pages have
const RESERVED = ['cassettes', 'submit', 'guidelines', 'try', 'shots', 'covers', 'index', 'assets', 'img', 'new', 'featured', 'api'];
const MAX_BYTES = 1024 * 1024;
const MAX_ABOUT = 600;

// The Machine Room's cassette reader (web/cassette.js in unc64/unc64), as it is.
globalThis.window = globalThis;
(0, eval)(readFileSync(join(ROOT, 'tools', 'cassette.js'), 'utf8'));
const C = globalThis.UNCCassette;

export const slug = (s) => String(s).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40);
const fail = (msg) => { throw new Error(msg); };

export function readIndex() {
  if (!existsSync(INDEX)) return { format: 'unc64-portal', version: 1, updated: null, cassettes: [] };
  return JSON.parse(readFileSync(INDEX, 'utf8'));
}

// The rules a cassette on the shelf keeps (the guidelines' technical half).
// -> { cassette, bytes, width, height, programs }, or throws with the reason, in plain words.
export function inspect(path) {
  const bytes = new Uint8Array(readFileSync(path));
  if (!C.isPNG(bytes)) fail('not a .unc.png: the Portal takes cassettes (unc64.com/portal/submit makes one from a .tap, a .s or a .bas)');
  if (bytes.length > MAX_BYTES) fail(`${bytes.length.toLocaleString('en')} bytes: a cassette on the Portal is at most ${MAX_BYTES.toLocaleString('en')}`);
  const c = C.read(bytes, 'the file');
  const chunks = C.chunks(bytes);
  if (chunks.some((k) => !k.crcOK)) fail('the PNG is damaged (a chunk\'s CRC doesn\'t match)');
  const ihdr = chunks.find((k) => k.type === 'IHDR');
  const dv = new DataView(ihdr.data.buffer, ihdr.data.byteOffset);
  const [width, height] = [dv.getUint32(0), dv.getUint32(4)];
  if (Math.abs(width / height - 1004 / 638) > 0.03 || width < 500 || width > 2008) fail(`the face is ${width} x ${height}: a cassette's is 1004 x 638 (or the same shape, 502 to 2008 wide)`);
  const programs = C.programs(c.tape);
  if (!programs.length) fail('there is nothing on the tape');
  const bad = programs.find((p) => !p.ok);
  if (bad) fail(`the tape is damaged: ${bad.error || `${bad.name}'s checksum doesn't match`}`);
  if (!c.title.trim() || c.title.length > 40) fail('the title is empty, or longer than 40 characters');
  if (c.about.length > MAX_ABOUT) fail(`the line about it is ${c.about.length} characters: ${MAX_ABOUT} at most`);
  if (c.author.length > 60) fail('the author is longer than 60 characters');
  return { cassette: c, bytes: bytes.length, width, height, programs, screenshots: screenshots(c), art: c.extra.cover === undefined ? null : pictureOf(c.extra.cover, 'the cover') };
}

// The pictures a cassette carries: `screenshots`, up to four, and `cover`, its cover art;
// each a PNG or a WebP of 200 KB at most, as base64. -> { ext, bytes }, or throws. Nothing
// here opens a picture: the site copies them out as files (shots/<id>-<n>, covers/<id>).
function pictureOf(b64, what) {
  if (typeof b64 !== 'string' || b64.length > 280000 || !/^[A-Za-z0-9+/=\s]*$/.test(b64)) fail(`${what} isn't a picture of 200 KB or less`);
  const bytes = Buffer.from(b64, 'base64');
  const png = bytes.length > 24 && bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  const webp = bytes.length > 16 && bytes.toString('latin1', 0, 4) === 'RIFF' && bytes.toString('latin1', 8, 12) === 'WEBP';
  if (!png && !webp) fail(`${what} must be a PNG or a WebP`);
  if (bytes.length > 200 * 1024) fail(`${what} is over 200 KB`);
  return { ext: png ? 'png' : 'webp', bytes };
}
function screenshots(c) {
  const list = c.extra.screenshots;
  if (list === undefined) return [];
  if (!Array.isArray(list) || list.length > 4) fail('its screenshots must be a list of four at most');
  return list.map((b64, i) => pictureOf(b64, `screenshot ${i + 1}`));
}

// The keys and how to play: from the index if it says, else from the cassette itself
// (`controls`, `instructions` in the format). Plain text, of a size a panel can hold.
// The keys are a line each, `KEYS: what they do` (A D: move / UP DOWN LEFT RIGHT: steer).
function text(name, v, most) {
  if (typeof v !== 'string' || !v.trim()) return {};
  const t = v.replace(/\r\n?/g, '\n').split('\n').map((l) => l.trim()).filter(Boolean).slice(0, 12).join('\n');
  if (t.length > most) fail(`its ${name} are ${t.length} characters: ${most} at most`);
  return { [name]: t };
}

// Where the source lives, if its author keeps it on GitHub: a repository, or a folder or a
// file in one. From the index if it says, else from the cassette (`source_url` in the
// format). Only github.com, so "Read the source" on the Portal never leads anywhere else.
export function sourceURL(v) {
  if (typeof v !== 'string' || !v.trim()) return {};
  const u = v.trim();
  if (u.length > 200 || !/^https:\/\/github\.com\/[A-Za-z0-9][A-Za-z0-9-]{0,38}\/[A-Za-z0-9._-]{1,100}(\/[A-Za-z0-9._~\/-]*)?$/.test(u) || u.includes('..')) fail('its source link must be a repository on github.com (https://github.com/you/your-game), or a folder or a file in one');
  return { source_url: u };
}

function derive(entry) {
  const { cassette: c, bytes, width, height, programs, screenshots: pics, art } = inspect(join(ROOT, entry.file));
  // the cover: the site's own picture if the index names one, else the cassette's
  const ours = entry.cover && !entry.cover.startsWith(`covers/${entry.id}.`) ? entry.cover : null;
  const cover = ours || (art ? `covers/${entry.id}.${art.ext}` : null);
  const lang = programs[0].type === 2 || (c.main && /\.bas$/i.test(c.main)) ? 'basic' : 'asm';
  return {
    id: entry.id, file: entry.file, title: c.title, author: c.author, about: c.about,
    category: CATEGORIES[entry.category] ? entry.category : 'other', tags: entry.tags || [],
    ...text('controls', entry.controls ?? c.extra.controls, 400),
    ...text('instructions', entry.instructions ?? c.extra.instructions, 800),
    ...sourceURL(entry.source_url ?? c.extra.source_url),
    ...(cover ? { cover } : {}),
    ...(entry.shot ? { shot: entry.shot } : {}),
    ...(pics.length ? { shots: pics.map((p, i) => `shots/${entry.id}-${i + 1}.${p.ext}`) } : {}),
    ...(entry.deck ? { deck: true } : {}),
    machine: { ram: c.machine.ram, niece: !!c.machine.niece, ...(c.machine.aunt === false ? { aunt: false } : {}) },
    programs: programs.map((p) => ({ name: p.name, type: p.type, length: p.length })),
    bytes, width, height, source: !!c.files, lang,
    added: entry.added || new Date().toISOString().slice(0, 10), featured: !!entry.featured,
    ...(entry.discuss ? { discuss: entry.discuss } : {}),
  };
}
const order = (list) => [...list].sort((a, b) => (b.featured - a.featured) || b.added.localeCompare(a.added) || a.title.localeCompare(b.title));

// index.json as build writes it, or throws with every problem found.
export function built(index) {
  const errors = [];
  const list = [];
  const seen = new Set();
  for (const entry of index.cassettes) {
    try {
      if (!/^[a-z0-9][a-z0-9-]{1,39}$/.test(entry.id) || RESERVED.includes(entry.id)) fail('its id must be 2-40 of a-z, 0-9 and -, and not a page of the Portal\'s own');
      if (seen.has(entry.id)) fail('its id is taken twice');
      seen.add(entry.id);
      if (entry.file !== `cassettes/${entry.id}.unc.png`) fail(`its file must be cassettes/${entry.id}.unc.png`);
      if (entry.discuss && !/^https:\/\/github\.com\/unc64\/cassettes\/(issues|pull)\/\d+$/.test(entry.discuss)) fail('its discuss link must be an issue or a pull request here');
      list.push(derive(entry));
    } catch (e) { errors.push(`${entry.id}: ${e.message}`); }
  }
  const dir = join(ROOT, 'cassettes');
  for (const f of existsSync(dir) ? readdirSync(dir) : []) if (!list.some((e) => e.file === `cassettes/${f}`) && !errors.some((e) => e.startsWith(f.replace(/\.unc\.png$/, '') + ':'))) errors.push(`cassettes/${f}: not in index.json (add it, or delete it)`);
  if (errors.length) fail(errors.join('\n'));
  const sorted = order(list);
  // `updated` moves only when the shelf does
  const updated = index.updated && JSON.stringify(index.cassettes) === JSON.stringify(sorted) ? index.updated : new Date().toISOString().replace(/\.\d+Z$/, 'Z');
  return { text: JSON.stringify({ format: 'unc64-portal', version: 1, updated, cassettes: sorted }, null, 1) + '\n', list: sorted };
}
export function build(index) {
  const { text, list } = built(index);
  const changed = !existsSync(INDEX) || readFileSync(INDEX, 'utf8') !== text;
  if (changed) writeFileSync(INDEX, text);
  return { list, changed };
}

// Takes a file onto the shelf (into `index`, not yet written): -> the id it got.
export function add(index, file, o = {}) {
  const info = inspect(file);
  const id = o.id || slug(info.cassette.title);
  if (o.category && !CATEGORIES[o.category]) fail(`the category is one of ${Object.keys(CATEGORIES).join(', ')}`);
  const entry = {
    id, file: `cassettes/${id}.unc.png`, category: o.category || 'other', tags: o.tags ? String(o.tags).split(',').map((t) => t.trim()).filter(Boolean) : [],
    ...(o.controls ? { controls: String(o.controls).replace(/\\n/g, '\n') } : {}), ...(o.instructions ? { instructions: o.instructions } : {}), ...(o['source-url'] ? { source_url: o['source-url'] } : {}), featured: !!o.featured, added: o.added || new Date().toISOString().slice(0, 10), ...(o.discuss ? { discuss: o.discuss } : {}),
  };
  mkdirSync(join(ROOT, 'cassettes'), { recursive: true });
  if (resolve(file) !== join(ROOT, entry.file)) copyFileSync(file, join(ROOT, entry.file));
  const at = index.cassettes.findIndex((e) => e.id === id);
  if (at >= 0) index.cassettes[at] = { ...index.cassettes[at], ...entry, added: o.added || index.cassettes[at].added, featured: o.featured ?? index.cassettes[at].featured };
  else index.cassettes.push(entry);
  return { id, replaced: at >= 0, title: info.cassette.title, author: info.cassette.author };
}

function flags(args) {
  const o = { _: [] };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--featured') o.featured = true;
    else if (a.startsWith('--')) o[a.slice(2)] = args[++i];
    else o._.push(a);
  }
  return o;
}
function main() {
  const [cmd, ...rest] = process.argv.slice(2);
  const index = readIndex();
  const say = (r) => console.log(`The shelf: ${r.list.length} cassettes${r.changed ? '; wrote index.json' : '; nothing changed'}.`);
  if (cmd === 'inspect') {
    for (const f of rest) { const i = inspect(f); console.log(`${f}: ${i.cassette.title}${i.cassette.author ? ` by ${i.cassette.author}` : ''}, in order.`); }
  } else if (cmd === 'add') {
    const o = flags(rest);
    if (!o._.length) fail('usage: node tools/shelf.mjs add FILE.unc.png [--id ID] [--category game|demo|music|tool|other] [--tags a,b] [--controls TEXT] [--featured] [--added DATE] [--discuss URL]');
    for (const f of o._) { const r = add(index, f, o); console.log(`${r.replaced ? 'Replaced' : 'Added'} ${r.id}: ${r.title}${r.author ? ` by ${r.author}` : ''}.`); }
    say(build(index));
  } else if (cmd === 'remove') {
    const e = index.cassettes.find((x) => x.id === rest[0]);
    if (!e) fail(`no cassette called ${rest[0]}`);
    index.cassettes = index.cassettes.filter((x) => x !== e);
    rmSync(join(ROOT, e.file), { force: true });
    say(build(index));
  } else if (cmd === 'build') say(build(index));
  else if (cmd === 'check') {
    const { text, list } = built(index);
    if (readFileSync(INDEX, 'utf8') !== text) fail('index.json is stale: run `node tools/shelf.mjs build`.');
    console.log(`The shelf: ${list.length} cassettes, all in order.`);
  } else fail('usage: node tools/shelf.mjs inspect FILE | add FILE ... | remove ID | build | check');
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(); } catch (e) { console.error(e.message); process.exit(1); }
}
