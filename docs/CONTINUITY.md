# Continuity note

For whoever picks this up next — a fresh session, or a returning one.

**If you are starting a new session, read `docs/NEXT_SESSION.md` first.** It has
the owner's standing priorities, a phased plan of attack, and what changed in the
reviewers. **`docs/GRAPHICS.md` is the rulebook for anything that draws** — the
light model, what a material owes, the animation rules, and the workflow. This
file is the reference underneath both: the things **not inferable from the code**,
and the traps that have already cost time.

`README.md` is how the game works. `docs/HANDOFF_CODEX.md` is the design
rationale.

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
| rules | 90 |
| presentation | 305 |
| the day (full loop) | 76 |
| content + encoding | PASS |

The capture harness writes **59** frames. The latest additions are 57 for the
glass on the charter's physical closing formula, 58 for parchment and ink at
inspection scale, and 59 for an open book's guttered shadow under grazing
candlelight. Frames 52-56 still cover the petition packet, intermediate
desk-to-audience poses, and the viscous wax neck.

**Run the rules suite before the Python one.** `tests/test_rules.gd` writes the
finding set it actually derived to `.tools/derived_findings.json`, and
`tools/verify_content.py` asserts its own list matches it case for case, in
order. Without that file the Python still runs — it must, because being runnable
with no Godot at all is the entire reason it is a separate implementation — but
it falls back to comparing only the final verdict, which is a three-valued
summary of a dozen findings and agrees by luck on most divergences.

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
survived so long, and the wax had no frame in which anything was ON TOP of it,
which is why it spent months drawing over the entire room.

**Capture the object in the state you are worried about, not in isolation.** Every
frame of the seal showed the seal alone, so "is the wax actually on the
parchment" was never a question any frame could answer. Every frame of the candle
was desk-wide, where it is ninety pixels and no change to it is visible; the 4x
series (36-41) was added specifically because the owner could see it was wrong
and the harness could not.

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

**`z_index` breaks the desk's stacking rule, silently and permanently.** Draw
order on this desk is child order in `surface`, full stop — except that any
CanvasItem with a higher `z_index` draws above ALL lower-z siblings whatever the
tree says, and `z_as_relative` is on by default so a child's z is added to its
parent's. The poured wax carried `z_index = 1` for months and therefore floated
above every other paper on the desk once struck, while the spoon that poured it
(z=4 while held, 0 once set down) slid underneath it. If you find yourself
reaching for `z_index` to get something above something else, you almost
certainly want child order instead. The legitimate uses are transient and
self-cancelling: a ring while it is in the hand or in the wax, a falling bead,
the lens.

**NOTHING IN THIS GAME CLIPS ITS OWN TEXT.** `Ink.block` passes `max_lines = -1`,
the only `clip_children` in the project is `wax_pool.gd`, and the shade veil
covers boards rather than content. So text that overruns its surface is not
truncated — it is drawn onto whatever is underneath, unlit, and silently lost.
Four surfaces were doing it: the Almanac's ring-doctrine page (~150 px, taking
the whole FALSE-versus-DEFECTIVE doctrine with it), the books' marginalia, the
Kalendar's front matter, and three of the eight dockets. There are now fit
assertions for both families — `ReferenceBook.page_bottom()` and
`DocketView.content_bottom()`, each kept deliberately adjacent to the `_draw`
they mirror. **If you add a flowed text surface, add its fit check.**

**A FIXED RESERVATION IS THE BUG, NOT THE TEXT.** Both families failed the same
way: a hole of constant height (54 px for book marginalia, 30 px for the
doorkeeper's note) with a variable-length note pinned into it. The existing
`maxf` guards only stopped two blocks colliding; they said nothing about the note
being taller than its own reservation. **Diagnostic worth keeping: if shortening
the text does not change the measured overflow, the text is not what is
overflowing.** Trimming prose twice produced the identical 14 px and 34 px before
that landed.

**AN INVISIBLE OBJECT WAS ANSWERING CLICKS.** `Draggable.contains_point` checked
`draggable_enabled` and not `visible`. The Ledger sits in `surface` from
construction with `visible = false` all day, `z_index = 6`, and the biggest hit
rectangle on the desk — so it absorbed clicks meant for the lens, the rings, the
spoon and the candle wherever their rectangles overlapped it. Fixed.

**`_pick` sorts by z_index now, then child order.** The renderer sorts by z
first, so child-order-only hit testing could return something other than the
object visibly on top — the lens (permanent `z_index = 2`) lost to any sheet
picked up after it. This does NOT relax the stacking rule: child order still
decides everything within a z level, and later-child-still-wins at equal z.

**WRITING THE ASSERTION IS A SECOND SEARCH OF THE SAME GROUND.** It happened
three times in one session: the leaf-fit check found the Kalendar overflow after
only the Almanac had been fixed, the lens hit-test assertion uncovered the
invisible Ledger, and the docket check found two more overflowing dockets plus
the fixed-reservation cause. Budget for it; it is not paperwork that follows a
fix.

**`class_name Material` does not compile — `Material` is a Godot built-in.** The
shared lighting helper is `Surface` (`scripts/presentation/surface.gd`) for that
reason and no other. Before adding any `class_name`, check it against
`ClassDB.class_exists()` rather than against your memory of the engine.

**A pixel-art silhouette can be completely wrong and still read as the thing.**
The candle's flame was drawn upside down for the life of the project — apex in
the wax, blue base at the top — and survived four rounds of deliberately judging
that object from capture frames. At ship scale it is nine pixels by thirteen, and
an inverted teardrop still parses as "a flame is there". When you assert on
drawn geometry, assert on **where a point ends up**, not on the angle you handed
the transform: 148 degrees is a plausible-looking number to read past.

**Measure before believing your own eyes on a colour change.** Comparing spoon
frames after the wax fix, the new one looked *brighter* and was in fact 18%
darker — washed orange `(204,58,30)` had become deep crimson `(190,40,18)`.
Saturation reads as brightness. `PIL` is available; diff the two frames, take the
bounding box of pixels that actually changed, and compare luminance only over
those. Desk-wide frames are useless for this because the flame's flicker is not
deterministic between capture runs and swamps the signal — only the 4x series
could see it.

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
- **The campaign is short on purpose. Scaffold now, prose last.** Eight matters
  across two days is a decision, not a gap: content authored against systems that
  are still moving has to be re-authored, and the writing is the one thing in this
  project that cannot be regenerated. So the SHAPE of a campaign — which days
  exist, what each is allowed to teach, which existing matter carries it, what is
  on the desk yet — is cheap and may be built freely. The docket, the charter
  body, the petitioner's lines and the outcome branches are expensive and wait
  until the mechanics have stopped changing. Test pacing by RE-SEQUENCING the
  eight matters that exist, never by writing new ones; `DayData.case_slots`,
  `requires_ruled` and `fallback_case_id` already allow a matter heard on Thursday
  to be a matter not heard on Tuesday.

  The corollary is a new way to break the oldest contract here. Once books start
  arriving on different days, a day's findings can depend on a book that day does
  not have — and "everything the ledger says was findable must have been
  renderable on the desk" has been violated three times already and treated as
  critical each time. When the curriculum becomes data, that has to be **enforced
  by `tools/verify_content.py`, not remembered.**

- **Humour is rationed: six to eight dry beats per working day, and never two in
  one matter.** The voice is flat declarative, past tense, the joke in a
  subordinate clause, and it always carries information — `matrices.json`'s
  "Ulrich seals a great deal and reads very little of it" is the register, and a
  line that would still be funny with its facts removed is the wrong line. At
  least three of the day's beats live inside a book the player has to open, so
  the office is funny when investigated rather than funny at the player.

  FORBIDDEN ABSOLUTELY: every `outcomes[].aftermath`; anything Adelheid Vesser
  says or that is said about her; case_08's `hold_to_light` and `waiting_long`
  lines; every DENY and REFER `reaction`; `burnt_out_text` and the ledger's
  "Heard, not ruled" and "Not heard" blocks; and any `Finding` text in
  `scripts/rules/`. The doorkeeper may be contemptuous about a person but never
  about a ruling — his note is written at the door, before the wax, and a docket
  that comments on the outcome is the game winking. What makes Grellwater land is
  that nothing anywhere near it is trying to be liked.

---

## What is actually built

A third day is not built. Two are: Tuesday (fixed order, four matters) and
Thursday (a tray you choose from, four of five slots used). Eight cases, and the
campaign seams in `data/days/*.json` mean a third day is data rather than a
session change.

A portrait constrains scheduling: Reimbold Zant reuses Gero Kalt's bust because
no new art exists, so the two of them cannot be heard on the same day. That is
why the knife is a Tuesday matter.

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
that is not a lookup. It answers on every sheet — a sound skin transmits evenly
with its laid lines and follicles coming up, a scraped one shows a bright patch
with the removed words feathering back — because a verb that sometimes does
nothing is a verb the player concludes is broken.

**The candle carries over.** What is left of Tuesday's is what Thursday is given,
floored at 45%. `Candle.carry_forward()` -> `Desk.last_candle_remaining` ->
`SessionController.day_seconds()`. The Tuesday ledger says so before the
consequence lands, because a scarcity you only discover by having lost it is a
trap rather than a decision.

**Humour is budgeted at six to eight dry beats a working day**, with a written
forbidden list — see the conventions above. The register is flat declarative,
past tense, joke in a subordinate clause, always carrying information.

---

## The subagents

Eleven, in `.claude/agents/`. **They load at session start** — a newly added one
is not callable until the next session.

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
| `render-critic` | read-only; materials, lighting, depth, silhouette, pixel-art coherence |

`render-critic` is required to open capture frames and describe what it sees
before asserting anything, and every read-only reviewer now has to separate what
it **confirmed** from what it **inferred** — nine of sixteen findings in one
session did not survive an adversarial check.

They are the main lever for a large task: each one starts with a cold context, so
the heavy reading happens in *their* window rather than the main one. Use them
before the main context fills, not after.

`feel-critic`, `render-critic`, `rules-auditor` and `design-prosecutor` are
deliberately adversarial. Do not soften their prompts — their value is that they
disagree.

Running all ten at once against a cold read of the codebase is worth doing before
a large pass. The signal is **convergence**: when four agents with no shared
context independently name the same defect, it is real. That is how the arrival
path, the dead air between cases and the unreadable ring stand were all found.

---

## Known and deliberately not fixed

These are recorded so the next person does not think they are undiscovered.

- **`Draggable._process` redraws unconditionally every frame**, twice per object,
  with no dirty flag, as do `Desk` and `WaxPool`. The original 2026-07-28 probe
  measured 5.9 ms/frame; the return graphics pass now measures **9.22 ms/frame,
  about 108 fps, with 19 draggables and all four books open**. It remains below
  the 10 ms intervention line. The permanent capture-harness probe added by the
  magnifier pass measures **6.45–6.73 ms/frame, 149–155 fps, with 17 live
  draggables and all four books open**. Because those poses differ, neither
  number replaces the other; preserve the scenario and keep measuring before
  another broad material layer.
  `ReferenceBook`'s half of this — a seeded wax outline rebuilt per frame per open
  plate — WAS real and is fixed: `WaxShape.outline` is memoised and the
  presentation suite asserts the memo holds.
- **Favour is REPORTED and inert.** The day ledger names who is pleased (see
  `session_controller.gd`'s `_compose_ledger`), so it is not invisible — but it
  has no downstream consequence whatever, and `Register.favor_totals()` itself is
  still called by nothing. The plan for making it a supply line rather than a
  score is in `docs/NEXT_SESSION.md`, along with the reason IMPERIAL favour must
  not be the one banded. It is the least systemic of the three columns and the most obvious
  place to spend the next campaign-scale effort.
- ~~**Thursday is three consecutive "nothing is wrong, confirm it" matters.**~~
  **Half fixed 2026-07-28.** case_04 now produces the build's first and only
  `defect:` tier finding, so `verdict_policy`'s DEFECT -> REFER row executes in
  play and REFER is taught as "this is broken, send it back" as well as "two laws
  disagree". Thursday is no longer three consecutive confirms. What remains true
  is that case_04 was Tuesday's matrix lookup inverted; it now *starts* that way
  and then turns on something else, which is the point.
- ~~**The Kalendar convicts nobody.**~~ **Fixed 2026-07-28**, see the commit
  "Phase 5: the Kalendar convicts one man". Herbord Gantz, castellan of
  Thurnstadt, is on case_04's witness list and in the Margrave's chapel roll as
  dead two years before the grant. The reasoning, and the three alternatives
  rejected and why, are in that commit message — argue with it there.
- **Two of Thursday's four matters cannot be ruled wrongly**, because a pure
  precedent contest marks every ring defensible.
- ~~**`WitnessCheck` fires no defect in any shipped case.**~~ Fixed by the same
  edit. It now fires exactly once, on a positive roll entry rather than a
  silence.
- **No shipped case springs the reckoning trap.** The Thurn chapel reckons by
  accession, the same style as case_04's charter, so the game's one decisive
  Kalendar lookup is a direct comparison of two regnal years and costs no
  cross-reckoning arithmetic. The Saint Wend chapter counts from *election* and
  a clerk who reduces its obits as an imperial notary gets a number three years
  wrong — and nothing a player is ever handed exercises that. This was left
  deliberately: case_04 already teaches a new book, a new finding tier and a new
  meaning for a ring, and a fourth new thing in one matter is bad teaching. It is
  the obvious next case and it should be a *different* case.
- **`data/world/books/almanac.json`'s ring-doctrine page contradicts the engine.**
  It tells the player that an unlookuppable name is a referable defect; the engine
  holds that silence is worth nothing and only ever emits a NOTE. Latent while
  nothing turned on the Kalendar, and now one page away from a case that does.
  Either the page or the doctrine should move.
- **`ReferenceBook`'s blind tooling is lit inside out.** A groove's lit lip
  belongs on the side AWAY from the flame; the book draws it toward, so the
  boards' stamped borders read as raised rather than impressed and swing the
  wrong way as the candle passes. `SignetRing` has it right. The convention and
  the physics are written down in `Surface` and asserted; the book itself is
  waiting on its own pass, with a before/after frame.
- **A witness's claimed house is never rendered on the parchment.** The rules
  read `house` to decide which roll would have had a man; the charter shows only
  his name and style. A player can infer the house from the style most of the
  time, which is the intended lookup — but where they cannot, the ledger knows
  something the desk never said.

---

## If you are a fresh session

Do not trust any summary of the codebase, including this one, over the files. The
project has roughly doubled in content three times now, and each time the previous
session's mental model went stale in ways that were not obvious — including this
file's own claim that there was no git repository.

Read the actual files for anything you intend to change, and run the capture
harness for anything you intend to look at.
