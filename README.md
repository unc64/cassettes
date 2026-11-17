# UNC 64 cassettes

The shelf behind [the Portal](https://unc64.com/portal/): the community's programs for the [UNC 64](https://github.com/unc64/unc64), a fantasy 8-bit computer. Every program here is a **cassette**, a `.unc.png`: a picture of a tape with the program inside it. What's merged here is on the Portal within the hour, playable in the browser, in the [Machine Room](https://unc64.github.io/unc64/) (Browse, Online) and in the game (pause, Settings, The Portal).

However you made it, by hand, with a friend, or with an AI, it's welcome ([AI and the UNC 64](https://unc64.com/ai/)).

## Submit a cassette

**The easy way.** Go to **[unc64.com/portal/submit](https://unc64.com/portal/submit/)** and drop your program on it:

- a `.unc.png` from the Machine Room's **Export** (which also has **Submit to the Portal**, and does the next step for you),
- a `.tap`, as the game's `SAVE` leaves in `Documents/UNC 64/Cassettes`,
- a `.s` (assembly, with the files it `.include`s) or a `.bas` (a UNC BASIC listing) from any editor.

The page packs it into a cassette on a UNC 64 of its own, takes the label's picture from the screen, and checks that it loads. Give it a title, your name, a line about it and its keys, then press **Submit it**. That downloads the cassette and opens [the form here](https://github.com/unc64/cassettes/issues/new?template=cassette.yml) with your answers filled in. Drag the downloaded file into the form's last box and submit the issue.

**What happens then.** A bot fetches the cassette, checks it, and answers on your issue in a minute or so, with a link to play it as it will be on the Portal, or with what's wrong and how to fix it (edit the issue and it looks again). It opens a pull request for it. A person plays it, reads it against the guidelines, and merges; your issue closes, and the cassette is on the shelf.

**Other ways in**, and the details: [CONTRIBUTING.md](CONTRIBUTING.md).

**Before you do:** [the guidelines](https://unc64.com/portal/guidelines/). The short version: make something for the UNC 64, make sure it's yours to share, say what it is, be decent to each other.

## What's here

| | |
|---|---|
| `cassettes/<id>.unc.png` | The cassettes, byte for byte as they were sent in. `<id>` is a cassette's name on the Portal: `unc64.com/portal/<id>/`. |
| `source/<id>/` | Each cassette's source, if its author included it, as files to read: what "Read the source" on the Portal opens (the file the cassette runs from). Only a cassette that carries no source leads to its author's own repository instead, if they gave its link. Written from the cassettes by `tools/shelf.mjs build`; don't edit it. |
| `index.json` | The shelf's index, which the Portal, the Machine Room and the game read: what's on each cassette, and the curation (kind, keys, the front row). |
| `tools/shelf.mjs` | The shelf's rules and its index: `inspect`, `add`, `remove`, `build`, `check`. Node 20 or later, nothing to install. |
| `tools/submission.mjs` | The bot: a submission issue into a pull request. |
| `tools/cassette.js` | The cassette reader, a copy of the Machine Room's. |

The cassette format is [docs/cassettes.md](https://github.com/unc64/unc64/blob/main/docs/cassettes.md) in the machine's repository.

## Whose they are

Each cassette belongs to whoever made it. By submitting one, its author lets UNC 64 keep it here and on the Portal, and lets people download it and play it. Nothing here grants more than that unless the cassette says so itself (a line about it, or a `README.md` among its files). The files in `tools/` and `.github/` are MIT, as the machine is.

**About something on the shelf** (it's broken, it's yours and you didn't send it, it shouldn't be there): [open an issue](https://github.com/unc64/cassettes/issues/new), or write to unc@viljami.io. It comes down first and gets discussed second.
