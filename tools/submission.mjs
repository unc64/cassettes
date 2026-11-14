#!/usr/bin/env node
// A submission issue, turned into a pull request: what .github/workflows/submission.yml runs.
// It reads the issue from the event (GITHUB_EVENT_PATH), finds the attached cassette,
// fetches it, checks it against the shelf's rules, and takes it onto the shelf in the
// working tree. It writes what happened to $RUNNER_TEMP/submission.json for the workflow's
// next steps: { ok, id, title, branch, commit, pr_title, pr_body, comment }.
//
// Everything in an issue is somebody's typing. Nothing from it reaches a shell: the fields
// go into index.json as data (through shelf.mjs's rules), and into the pull request's text
// with their markup taken out. Only an attachment on github.com is fetched, and at most
// MAX bytes of it.
//
//   node tools/submission.mjs            in the workflow
//   node tools/submission.mjs --dry EVENT.json [FILE]   try it here: FILE stands in for the download
import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { readIndex, add, build, built, slug, inspect, sourceURL, CATEGORIES } from './shelf.mjs';

const MAX = 1100 * 1024;
const dry = process.argv[2] === '--dry';
const event = JSON.parse(readFileSync(dry ? process.argv[3] : process.env.GITHUB_EVENT_PATH, 'utf8'));
const issue = event.issue;
const out = join(process.env.RUNNER_TEMP || tmpdir(), 'submission.json');
const done = (r) => { writeFileSync(out, JSON.stringify(r, null, 1)); console.log(r.comment); process.exit(0); };
const sorry = (why) => done({ ok: false, comment: `Thanks for sending this in. I couldn't take it onto the shelf yet:\n\n> ${why}\n\nEdit the issue (the pencil on its first comment) and I'll look again. A person will be along too.\n\n<sub>The shelf's bot. The rules: https://unc64.com/portal/guidelines/</sub>` });

// ---------- the form's answers: "### Label\n\nvalue" ----------
const body = String(issue.body || '').replace(/\r\n/g, '\n');
const field = (label) => {
  const m = body.match(new RegExp(`^### ${label}\\s*\\n+([\\s\\S]*?)(?=\\n### |(?![\\s\\S]))`, 'm')); // to the next heading, or the end
  const v = m ? m[1].trim() : '';
  return v === '_No response_' ? '' : v;
};
// plain text for a pull request: no markup, no mentions, one line
const plain = (s, most = 200) => String(s).replace(/[`<>\[\]()*_~#|!\\]/g, ' ').replace(/@/g, '@ ').replace(/\s+/g, ' ').trim().slice(0, most);
const kind = Object.keys(CATEGORIES).find((k) => CATEGORIES[k].toLowerCase() === field('Kind').toLowerCase()) || 'other';
// the keys a line each, how to play: as the form has them, else as the cassette carries them
const lines = (s, most) => s.split('\n').map((l) => plain(l, 120)).filter(Boolean).slice(0, 12).join('\n').slice(0, most);
const controls = lines(field('The keys'), 400);
const instructions = lines(field('How to play'), 800);
// the author's own repository, if they gave one: a link on github.com, or nothing
let source = field('Source on GitHub').split(/\s/)[0] || '';
try { sourceURL(source); } catch (e) { source = ''; }

// ---------- the attachment ----------
// A file dragged into an issue: github.com/user-attachments/assets/<uuid> (a picture) or
// .../files/<n>/<name> (anything else, a .zip among them).
const urls = [...field('The cassette').matchAll(/https:\/\/github\.com\/user-attachments\/(?:assets\/[0-9a-f-]{36}|files\/\d+\/[\w.%+-]+)/g)].map((m) => m[0]);
if (!urls.length) sorry('There\'s no file in "The cassette". Drag your `.unc.png` into that box, as a file.');

async function fetchBytes(url) {
  const res = await fetch(url, { redirect: 'follow', headers: process.env.GITHUB_TOKEN ? { authorization: `Bearer ${process.env.GITHUB_TOKEN}` } : {} });
  if (!res.ok) throw new Error(`the attachment didn't arrive (${res.status})`);
  const len = Number(res.headers.get('content-length') || 0);
  if (len > MAX) throw new Error('the attachment is over a megabyte');
  const chunks = [];
  let n = 0;
  for await (const c of res.body) { n += c.length; if (n > MAX) throw new Error('the attachment is over a megabyte'); chunks.push(c); }
  return Buffer.concat(chunks);
}
const dir = mkdtempSync(join(tmpdir(), 'submission-'));
const file = join(dir, 'submitted.unc.png');
let why = '';
let got = false;
for (const url of urls.slice(0, 3)) {
  try {
    let bytes = dry && process.argv[4] ? readFileSync(process.argv[4]) : await fetchBytes(url);
    // a zip (PK): the first .unc.png in it, and no more than MAX of that
    if (bytes[0] === 0x50 && bytes[1] === 0x4B) {
      const zip = join(dir, 'submitted.zip');
      writeFileSync(zip, bytes);
      const names = execFileSync('unzip', ['-Z1', zip], { encoding: 'utf8' }).split('\n').filter((n) => /\.unc\.png$/i.test(n));
      if (!names.length) throw new Error('the zip has no .unc.png in it');
      bytes = execFileSync('unzip', ['-p', zip, names[0].replace(/[[\]*?\\]/g, '\\$&')], { maxBuffer: MAX });
    }
    writeFileSync(file, bytes);
    inspect(file);
    got = true;
    break;
  } catch (e) { why = e.code === 'ERR_CHILD_PROCESS_STDIO_MAXBUFFER' ? 'the cassette in the zip is over a megabyte' : e.message; }
}
if (!got) sorry(`${why}.${/no program in it|not a cassette|not a \.unc\.png/.test(why) ? ' If it is a cassette on your computer, the upload may have changed it: put the `.unc.png` in a `.zip` and attach that instead.' : ''}`);

// ---------- onto the shelf ----------
const index = readIndex();
const info = inspect(file);
// A title that's taken gets a number: an update of somebody's cassette is a person's call.
let id = slug(info.cassette.title) || `cassette-${issue.number}`;
if (id.length < 2) id = `cassette-${issue.number}`;
const taken = index.cassettes.find((e) => e.id === id && e.discuss !== issue.html_url);
if (taken) id = `${id.slice(0, 34)}-${issue.number}`;
let r;
try {
  r = add(index, file, { id, category: kind, controls, instructions, 'source-url': source, discuss: issue.html_url });
  build(index);
} catch (e) { sorry(e.message); }

const c = info.cassette;
// the link as the shelf took it (the form's, else the cassette's own)
const shown = index.cassettes.find((e) => e.id === id)?.source_url || built(index).list.find((e) => e.id === id)?.source_url || '';
const title = plain(c.title, 60);
const by = plain(c.author, 60);
const branch = `submission/${issue.number}`;
const tryIt = `https://unc64.com/portal/try/?ref=${encodeURIComponent(branch)}&id=${id}`;
const needs = `${c.machine.ram}K${c.machine.niece ? ' + NIECE' : ''}`;
const progs = info.programs.map((p) => `${plain(p.name, 16)} (${p.type === 2 ? 'BASIC' : 'machine language'}, ${p.length} bytes)`).join(', ');
done({
  ok: true, id, title, branch,
  commit: `${title}${by ? ` by ${by}` : ''}: onto the shelf (#${issue.number})`,
  pr_title: `${title}${by ? ` by ${by}` : ''}`,
  pr_body: [
    `From #${issue.number}, sent in by @${issue.user.login}. Closes #${issue.number}.`,
    '',
    `**[Play it](${tryIt})** on the Portal's try-out page, straight from this branch.`,
    '',
    '| | |', '|---|---|',
    `| Title | ${title} |`, `| By | ${by || '(nobody named)'} |`, `| About | ${plain(c.about, 600) || '(nothing)'} |`,
    `| Kind | ${CATEGORIES[kind]} |`, `| Keys | ${(controls || plain(c.extra.controls || '', 400) || '(none given)').replace(/\n/g, '<br>')} |`,
    `| How to play | ${(instructions || plain(c.extra.instructions || '', 800) || '(nothing)').replace(/\n/g, ' ')} |`, `| Needs | ${needs} |`,
    `| On the tape | ${progs} |`, `| Source | ${c.files ? `on the cassette: ${Object.keys(c.files).map((p) => plain(p, 60)).join(', ')}` : 'not on the cassette'}${shown ? `; linked: ${shown}` : ''} |`,
    `| Pictures | ${info.screenshots.length} screenshot${info.screenshots.length === 1 ? '' : 's'}${info.art ? ', and cover art' : ', no cover art'} |`,
    `| File | \`cassettes/${id}.unc.png\`, ${info.bytes.toLocaleString('en')} bytes |`,
    '',
    taken ? `**\`${slug(c.title)}\` is taken** by a cassette already on the shelf, so this one is \`${id}\`. If it's an update of that one by the same person, rename the file and the entry before merging.\n` : '',
    'Before merging: play it, and read it against [the guidelines](https://unc64.com/portal/guidelines/) (theirs to share, says what it is, decent). `category`, `tags`, `controls` and `featured` in `index.json` are yours to change. Merging puts it on the shelf; the Portal picks it up within the hour.',
  ].join('\n'),
  comment: `Thanks! **${title}** keeps the shelf's rules: it's a cassette, ${needs}, with ${progs} on the tape${c.files ? ', source included' : ''}.\n\nYou can [play it here](${tryIt}) as it will be on the Portal. A person reads every submission before it goes on the shelf; this issue closes when it does.\n\n<sub>The shelf's bot. Edit the issue to send a new version.</sub>`,
});
