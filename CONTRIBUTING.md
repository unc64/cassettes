# Submitting a cassette

Three ways, the first the easiest. All of them end in a pull request that a person reads and merges. The rules are [the guidelines](https://unc64.com/portal/guidelines/); AI-made cassettes are welcome, and nobody is asked to say which way a program was written.

## 1. The Submit page (no git, no tools)

1. Open **[unc64.com/portal/submit](https://unc64.com/portal/submit/)**.
2. Drop your program on it: a `.unc.png` (the Machine Room's Export), a `.tap` (what the game's `SAVE` writes to `Documents/UNC 64/Cassettes`), a `.s` with its `.include`d files, or a `.bas`.
3. Label it: title, who it's by, a line about it, its kind, what it needs (16K or 64K, the NIECE), the keys and, if it needs saying, how to play. The keys go a line each, `A D: move`, `UP DOWN LEFT RIGHT: steer`, `SPACE: fire`: the Portal shows them as keycaps beside the screen, and on a phone makes buttons of them. Both travel on the cassette. Leave **Put the source on the cassette** ticked if you'd like people to be able to open it and learn from it.
4. Tick that it's yours to share, and press **Submit it**. The cassette downloads, and the form here opens with your answers in it.
5. Drag the downloaded `.unc.png` into the form's last box, **The cassette**, and submit the issue. You need a GitHub account for this step. Without one, post the file in `#show-your-programs` on [the Discord](https://discord.gg/ZHHDqkFjw) and say it's for the Portal.

From the Machine Room it's shorter: **Export**, **Submit to the Portal** does steps 1 and 2 for you.

## 2. The form, by hand

If you already have a `.unc.png`: [open the form](https://github.com/unc64/cassettes/issues/new?template=cassette.yml), fill it in, and drag the file into **The cassette**.

If the bot answers that there's no program in the file, the upload changed it. Put the `.unc.png` in a `.zip` and attach the zip instead (edit the issue: the bot looks again).

## 3. A pull request

If you'd rather use git:

```sh
git clone https://github.com/unc64/cassettes && cd cassettes
node tools/shelf.mjs add ~/my-game.unc.png --category game \
  --controls "A D: move\nSPACE: fire" --instructions "Shoot everything. Three lives."
node tools/shelf.mjs check
```

`add` checks the cassette, copies it to `cassettes/<id>.unc.png` (the id is the title in lower case; `--id` picks another) and writes its entry into `index.json`. Commit both, and open a pull request. One cassette to a pull request, please. Leave `featured` alone: the front row is picked by hand.

`node tools/shelf.mjs inspect FILE.unc.png` checks a file without touching anything.

## What the bot checks

- It's a cassette: a PNG with a `unCt` chunk, format version 1 ([the format](https://github.com/unc64/unc64/blob/main/docs/cassettes.md)).
- Every program on its tape has a checksum that matches.
- One megabyte at most.
- The face is in a cassette's proportions (1004 x 638, or the same shape from 502 to 2008 wide).
- A title of 40 characters or fewer, an author of 60, a line about it of 600.

It doesn't run the program. The person who merges does, on the Portal's [try-out page](https://unc64.com/portal/try/), which plays a cassette straight from its pull request's branch.

## A new version

Send it the same way and say which cassette it replaces. The bot gives a cassette whose title is taken a new id, and the person merging puts it in the old one's place if it's yours.

## Taking one down

Yours, and you want it gone: [open an issue](https://github.com/unc64/cassettes/issues/new) or write to unc@viljami.io.

## For the people who merge

- Play it (the link in the pull request), and read it against the guidelines: theirs to share, says what it is, decent.
- `category`, `tags`, `controls`, `instructions`, `featured` and `cover` in `index.json` are yours to edit on the branch; run `node tools/shelf.mjs build` after.
- Merge. The Portal's site copies the shelf from here every hour (the `portal` workflow in the site's repository; run it by hand to hurry it).
- `node tools/shelf.mjs remove ID` takes one off.
- The bot needs **Settings, Actions, General, "Allow GitHub Actions to create and approve pull requests"**. Without it, it still pushes the branch `submission/<issue>` and says so.
