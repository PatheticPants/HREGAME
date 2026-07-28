# Continuity note

For whoever picks this up next — a fresh session, or a returning one.

Read `README.md` first for how the game works and `docs/HANDOFF_CODEX.md` for the
design rationale. This file is only the things that are **not inferable from the
code** and the traps that have already cost time.

---

## Verified state

All green as of this note. Run these before changing anything, so you know
whether a failure is yours:

```bash
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --script tests/test_rules.gd
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --fixed-fps 60 --scene res://tests/test_presentation.tscn
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --fixed-fps 60 --scene res://tests/test_session.tscn
python tools/verify_content.py
```

| suite | checks |
|---|---|
| rules | 71 |
| presentation | 156 |
| the day (full loop) | 66 |
| content + encoding | PASS |

**It is a git repository now.** `github.com/PatheticPants/HREGAME`, branch `main`.
The previous version of this file said it was not; that was the first thing a
fresh session found to be false, which is the whole reason for the warning at the
bottom of this document.

---

## Look at the pixels

`tests/qa_capture.tscn` writes ~32 annotated PNGs to `.tools/shot_*.png`
(gitignored) and it is the fastest way to find out that something is wrong:

```bash
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --path . --resolution 1600x900 --scene res://tests/qa_capture.tscn
```

Deliberately **not** headless — Godot cannot render 2D lights with the dummy
driver, and lighting is what these exist to check. Several defects fixed in this
pass were invisible in code review and obvious in a frame: parchment that ignored
the candle, a spoon throwing the shadow of a brick, verdict rings whose names
could not be read.

If you change anything visual, capture it. If you add a subsystem, add a shot for
it — the door and the petitioner had none, which is why their two worst defects
survived so long.

---

## Traps that have already cost time

**Never rewrite a source file with PowerShell `Set-Content` / `-replace`.** It
round-trips through cp1252 and silently mangles every non-ASCII character — seven
em dashes in `candle.gd` became `â€"` and the file still ran. Use the editor
tooling. `tools/verify_content.py` checks every text file for this on every run;
it also catches BOMs and CRLF.

**A new `class_name` is invisible until the class cache is rebuilt.** Adding a
script with `class_name` from the CLI breaks every file that references it until:

```bash
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --editor --quit
```

The error you get is a *parse error in an unrelated file* — usually
`Could not resolve class "ContentLoader"` — so it looks like you broke something
else. You did not. Rebuild the cache.

**Dialogue only advances on a click.** `petitioner.on_click()`. Any automation
that doesn't click will hang forever waiting for `Stage.SPEAKING` to end.

**Most tests deliberately freeze the session.** `test_presentation` calls
`desk.set_process(false)` and `session.set_process(false)` so it can pose the desk
and drive the press by hand. If you drive the press manually *without* freezing
the desk, the desk ticks it every frame with an empty hand and silently aborts the
descent. `test_session.tscn` is the only suite that runs the real loop.

**Coordinate spaces.** Props live in `desk.surface`, inside `work_plane`, inside
`desk` (positioned at 960,640). Mixing global and parent-local is the most common
mistake here — use `desk.surface.to_local(...)`.

**`String.capitalize()` title-cases every word and splits snake_case.** Use
`Lex.sentence()` for prose.

**Identity in the necrology is matched on `person_id`, never on name.** Two men
are called Hugo Wend. The cost is that a typo does not error — the man is simply
never found, the roll reports itself silent, and a witness who should have been
caught walks. `verify_content.py` catches a name known under two different ids,
which is the only shape of that bug that is detectable; nothing catches an id
that is wrong in both places.

---

## Conventions that are decisions, not habits

- `scripts/rules/` never touches a node, a signal or the scene tree. This is what
  lets the rules run headless. Do not relax it.
- No `is_forged` flag anywhere in the data. Forgery is derived.
- Content is JSON under `data/`; tuning is `.tres` (live-editable while running).
- Soundness, Favour and Craft are three columns and are never combined.
- Everything the ledger says was findable must have been renderable on the desk.
  This has been violated three times and every one was treated as critical. The
  most recent: an obit roll longer than a page silently dropped its tail, so
  `WitnessCheck` could convict on a name that was not on any leaf.
- One screen-space element exists in the whole game (`view_hint.gd`), and each of
  its two captions retires when the player has actually visited the plane it
  describes — **not** on any input, which used to delete the tutorial before it
  had been read.
- Every new `Check` must be written **twice**: once in `scripts/rules/` and once,
  independently, in `tools/verify_content.py`. When the two disagree, one has a
  bug. They had silently disagreed about `date_sound` for months because only the
  final verdict was ever compared.

---

## What is actually built

Three days is not built. Two are: Tuesday (fixed order, three matters) and
Thursday (a tray you choose from). Seven cases plus one, and the campaign seams
in `data/days/*.json` mean a third day is data rather than a session change.

Checks that fire on shipped content: `ErasureCheck`, `SealCheck`, `DateCheck`,
`WitnessCheck`, `AuthorityCheck`, `PrecedentCheck`. Still unwritten:
`GenealogyCheck`, `PalaeographyCheck`, `JurisdictionCheck`.

Four books on the desk: the Almanac, the Book of Matrices, the Register (grows
during the day), and the Kalendar of the Dead (generated from
`data/world/necrology.json`, so it cannot drift from the law).

**Three of four pigeonholes are occupied before the first knock** — the tablet,
the Kalendar and the Register. One hole is left. The next person to add a book is
spending it, and should say so out loud rather than discovering it in a playtest.

The four investigative verbs are: read it, put the glass on it, look it up in a
book, and **hold it up to the flame**. The last is the newest and is the only one
that is not a lookup.

---

## The subagents

Ten, in `.claude/agents/`. **They load at session start** — a newly added one is
not callable until the next session.

| | |
|---|---|
| `loremaster` | canon, persistent memory, hard cap 6–9 polities |
| `case-writer` | cases as data; must state the decisive fact and the path to it |
| `feel-critic` | read-only; phases, easing, weight, variance, audio hooks |
| `godot-reviewer` | read-only; cross-platform safety first |
| `rules-auditor` | read-only; hunts second solutions |
| `campaign-architect` | multi-day consequence, precedent, faction pressure |
| `design-prosecutor` | adversarial: is this a game or beautiful craft over a thin loop |
| `difficulty-curator` | teaching order and difficulty curve |
| `player-advocate` | cold first-time-player walkthroughs |
| `sound-director` | sonic language, feedback hierarchy |

They are the main lever for a large task: each one starts with a cold context, so
the heavy reading happens in *their* window rather than the main one. Use them
before the main context fills, not after.

`feel-critic`, `rules-auditor` and `design-prosecutor` are deliberately
adversarial. Do not soften their prompts — their value is that they disagree.

Running all ten at once against a cold read of the codebase is worth doing before
a large pass. The signal is **convergence**: when four agents with no shared
context independently name the same defect, it is real. That is how the arrival
path, the dead air between cases and the unreadable ring stand were all found.

---

## Known and deliberately not fixed

These are recorded so the next person does not think they are undiscovered.

- **`Draggable._process` redraws unconditionally every frame**, twice per object,
  with no dirty flag — as does `Desk`, `WaxPool` (four child CanvasItems) and
  `ReferenceBook` (which regenerates a seeded wax outline per frame per open
  plate). Nothing renders slowly today. It is the first thing to fix if anything
  ever does, and it is a hard blocker on attaching per-object materials.
- **Favour is stored and inert.** `Register.favor_totals()` is written and never
  called. It is the least systemic of the three columns and the most obvious
  place to spend the next campaign-scale effort.
- **The candle buys nothing.** It is the only scarce thing in the game and it
  purchases no advantage; running out costs a paragraph of ledger prose. Making
  candle-seconds convertible is the single largest missing system.
- **Two of Thursday's four matters cannot be ruled wrongly**, because a pure
  precedent contest marks every ring defensible.

---

## If you are a fresh session

Do not trust any summary of the codebase, including this one, over the files. The
project has roughly doubled in content three times now, and each time the previous
session's mental model went stale in ways that were not obvious — including this
file's own claim that there was no git repository.

Read the actual files for anything you intend to change, and run the capture
harness for anything you intend to look at.
