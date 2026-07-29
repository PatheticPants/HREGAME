# Brief for the next session

You are picking up **Hand and Seal**, a Papers-Please-style document-inspection
game in Godot 4 / GDScript at `C:\HREGAME`, set in a fictionalised Holy Roman
Empire. You are a low-born notary of the Imperial Chancery; petitioners bring
claims to land and title; you verify charters, wax seals, witness lists and
regnal dates against a body of law, then rule in wax with a signet ring. One
carried candle is the only light in the room and the day's clock.

Read in this order:

1. **`docs/GRAPHICS.md`** — the standing rules for how this game is allowed to
   look and how to work on it. This session's work is mostly graphics, so this is
   the rulebook.
2. **`docs/CONTINUITY.md`** — the traps that have already cost time and the
   conventions that are decisions rather than habits.
3. **`README.md`** — how the game actually plays.
4. This file — the plan.

Do not trust any of them over the actual files. Every one has been caught lying
in the last two sessions, including about whether the project was a git
repository.

---

## Run this before you touch anything

```bash
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --script tests/test_rules.gd
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --fixed-fps 60 --scene res://tests/test_presentation.tscn
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --fixed-fps 60 --scene res://tests/test_session.tscn
python tools/verify_content.py
```

Green is **rules 90, presentation 305, session 76, content PASS**. Run the rules
suite before the Python one: it writes `.tools/derived_findings.json`, and the
Python compares every finding against it rather than only the final verdict.

Then capture, and **open the frames**:

```bash
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --path . --resolution 1600x900 --scene res://tests/qa_capture.tscn
```

Adding a `class_name` breaks every file that references it until the class cache
is rebuilt (`--headless --path . --editor --quit`), and the error you get is a
parse error in an *unrelated* file. You will hit this. It is in CONTINUITY.

---

## What the owner wants

Verbatim, across three sessions:

> Improved animations and perspective shifts. Better stylized realism in almost
> every part of the game. Materials, lighting, depth, weight. Pixel-art anchored,
> not photoreal.

> I want this to be a very atmospheric game. The night time vibe is very nice.
> Continue to expand upon this and create a truly immersive experience.

> **I really want graphics, lighting, and animations to be improved upon.**

Plus: sparse, subtle humour (budgeted and documented — read the rule in
CONTINUITY before adding one line), and vigilance about the loop becoming
repetitive.

**They notice detail, and both bugs they have reported personally were real,
invisible to the test suite, and things a previous session had looked at and
passed over.** Assume anything they mention is real, and reproduce it in a
capture before theorising.

---

## WHERE THE LAST SESSION GOT TO (2026-07-28)

**Phases 0, 1 and 5 are done. The 2026-07-28 return pass also completed the
largest remaining Phase 2 visual targets.** What follows the status includes
historical reasoning; read this status first or you will redo work.

| | |
|---|---|
| **Phase 0** | Historical exact stress pose: **9.22 ms, 108 fps**, 19 draggables, four open books, 3 outline builds. Repeated current capture-harness runs measure **6.45–6.73 ms, 149–155 fps**, 17 live draggables, four open books, and 10 cached outlines. Both are below the 10 ms intervention line; preserve the scenario when comparing. `seal_tag` surface randomness is now generated once and cached. |
| **Phase 1** | Done. `scripts/presentation/surface.gd`. **Named `Surface`, not `Material` — `Material` is a Godot built-in and `class_name Material` does not compile.** Shipped with nothing migrated and no pixels changed, as the plan asked. |
| **Phase 2** | The candle, wax pool and spoon, seal veil, brass response, Ledger arrival, page turn and blind tooling, magnifier, desk ledge, packet sweep, and view transition have all received implemented and rendered passes. |
| **Phase 4** | The door takes the candle; cold morning has directional shutter geometry, band-limited dust, and cold material reflection; the near foreground desk fascia is implemented. The acoustic bed remains open. |
| **Bugs** | A second cold sweep found 21 candidates; 6 were refuted and **15 were reproduced and fixed** across six commits. See the log from "Two books were printing off the edge of their own boards" onward. |
| **Phase 5** | Decided and done. See the commit "Phase 5: the Kalendar convicts one man". |

**Three things the last session found that the plan did not predict**, all of
which are the same shape — a defect invisible in code review and obvious once
something was measured:

1. **The candle's flame had been drawn upside down since it was written.**
   `atan2(lean.x, -8.0)`; a negative second argument returns an angle near pi.
   Tip in the wax, blue base at the top, in every frame, for the life of the
   project — through four rounds of judging that exact object from captures.
2. **"Molten is darker than set" was recorded as fixed and was only fixed on the
   candle.** The pool and the spoon still had it inverted.
3. **The struck seal never took the shade veil**, because `WaxPool` is a *child*
   of the sheet and children draw after their parent — so the sheet's veil went
   down and the wax drew over it.

**Where the plan was wrong, for the record.** The Phase 1 class name does not
compile. The Phase 5 "obvious fix" — convert an existing witness on case_04 —
does not survive the data: one of the two has no house by design, the other is
shared with case_02 and moving him damages a shipped case. And `docs/GRAPHICS.md`
was telling every session to avoid `ease(x, 0.4)` for a reason that is false;
measured, it covers 4% of the distance in the first frame rather than snapping.
All three are corrected in place.

## THE LOOP: HOOK, SPINE, AND WHAT TO BUILD NEXT

From a cold sweep — six designers, one synthesis, three prosecutors. Read this
before adding content; it is the shape the content is supposed to make.

### The hook

You are the third hand at the third desk, and the man who sat here before you is
not in the building. He left the memorandum, addressed TO THE THIRD HAND and
signed R.V., and it is the most useful thing anybody says to you all week. Then
the first man comes up with a seal rubbed to nothing and a witness who died the
year it was drawn — and he is telling the truth, and the game's opening move is
to punish the reflex you walked in with. What brings you back is smaller and
worse: the third petitioner quotes what you did to the first, correctly. Your
rulings go into a book, the book is on the desk, and other people open it. Three
of its entries are not yours.

### The spine

**THE EMPIRE SUPPLIES ME. THE CHURCH INFORMS ME. THE COUNTRY COMES TO ME.**

Favour is a supply line, not a score. Standing is inspected by noticing the
Kalendar is thinner, the resin is worse and the tray is emptier — **never** by
reading a number off a page. If a player cannot infer their standing from the
state of the desk, the fix is stronger effects, never a readout. The antagonist
is the record: six separate reasonable decisions turn out to be a position, and
people plan around it before you notice it.

### Build next, in order

0. **The thread has a shape now — keep it inert.** `after_case` and
   `after_investigation` on `DayOpeningDocument` are the two delivery channels;
   both are data. The R.V. thread uses one of each and still answers nothing.
   Anything new that pulls on it should add a FACT and not a CONCLUSION, and
   nobody in the office may notice the eleven-years-against-eight arithmetic on
   the player's behalf.
1. **`Register.standing(authority)`** — call the already-written, never-called
   `favor_totals()` (`register.gd:96`), band it coarsely, and widen
   `DayOpeningDocument` with `requires_standing` / `requires_burnt_out` /
   `requires_unsound_at_least`. Then spend it in data. The mid-day arrival
   channel (`after_case`) shipped this session and is the same plumbing.
2. **Dockets say who MOVED the matter** (`interests`, rendered like the letters'
   existing `endorsements`), and tray slips stamp any subject this desk has
   already written on. Forecast without spoiling: an endorsement names a mover,
   never who will approve of which verdict.
3. **Saturday**, built on the returning Ford at Lenz — R.V.'s own referral,
   already in `register_seed.json`, coming back down the stair.

### The prosecutors' amendments — do not skip these

- **Do not band IMPERIAL favour.** It is already a soundness proxy: in three of
  eight matters the imperial delta is exactly +1 for the lawful verdict and −1
  for the unlawful one. Banding it hands the player a competence score in
  costume, which is the one thing the three-column rule exists to prevent. Use
  church/custom for supply, or decouple the deltas first.
- **`test_session.gd` asserts `not desk.ledger.allow_next_day`**, and
  `allow_next_day` is `day_index + 1 < days.size()`. Adding `day_03` to
  `_order.json` fails that assertion the instant it lands. Update it in the same
  commit.
- **`content_loader._load_days` parses only `case_id`, `requires_ruled`,
  `fallback_case_id`.** Any new `DayCaseSlot` field is SILENTLY IGNORED — no
  error, no test failure, the feature just never fires. This is the same class of
  bug as the `after_case` field: if you add one, parse it.
- **A foreign-hand prior is a party's argument, not the office's settled
  position.** `PrecedentCheck._same_claimant` / `_competing_claimant` fold the
  player's own priors into `Lex.Authority.OFFICE`; R.V.'s must not go the same
  branch. And the distinction needs one authored sentence inside the case that
  uses it — a player who spent Thursday treating the Register as uniformly
  binding will read it as an inconsistency, not a revelation.
- **Decide case_09's verdict model before writing dialogue.** Two incompatible
  shipped patterns exist: fixed `correct_verdict` (case_03) and
  `"DYNAMIC"` + `dynamic_precedent: true` (case_05/06, gated at
  `content_loader.gd:284` and `register_book.gd:133`).
- **`DocketSlip` extends `Draggable`, whose `_process` redraws every frame.** Do
  any Register lookup once in `bind()`, not in `_draw`.
- **`DocketView.content_bottom()` is hand-mirrored against `_draw_face`.** Adding
  a line to one without the other reproduces the overflow bug a third time.

### The twist seeds, planted and unfired

- **R.V.'s tenure does not fit the household book.** Odo Fenne (d. 1208) and
  Isenbard Kliff ("eight years at the desk", d. 1216) are both entered as notary
  at the third desk; R.V. claims eleven years, which begins in 1210 and overlaps
  Kliff by six. Two written records that cannot both be true, findable with three
  books already in the room. **No answer exists in the build. Do not add one
  without deciding what it costs.**
- **The archive at Lenz burnt in '18 and took forty years of oath-rolls with
  it** — R.V.'s own marginal note in the Book of Matrices, and the reason the
  Count of Hallenstein's roll will not come. "Nobody has worked out yet what that
  means for the Nether March. It will not be pretty when they do."
- **The steward's line is ruled and blank.** He enters a man on the day his bed
  is stripped, the bed under the stair has been stripped, and he has no date.

## THE PLAN OF ATTACK

Review it, disagree with it, expand it. It is ordered so that each phase makes
the next one cheaper — do not reorder without a reason.

**Phase 2's named work has landed.** The page turn carries its physical recto and
verso, blind tooling uses the shared `Surface` convention, the magnifier, ledge,
packet sweep, and view transition have landed, and morning has geometry. Judge
further material work from fresh captures instead of treating the historical
list below as unfinished scope.

**Phase 2 is deliberately not split into "the refactor" and "the fun part".** An
earlier draft of this plan did split them, and that was a mistake twice over: a
big-bang migration of ten objects' `_draw` producing no visible change is exactly
when things quietly get worse, because nobody looks at pixels while they are deep
in an abstraction — and it concentrates all the unrewarding work into one block
that a session is tempted to skip. Per-object passes that do material and motion
together are slower to describe and much harder to get wrong.

### Phase 0 — MEASURED. Mostly already done. (an hour)

**Do not spend a day here. The previous session's brief called this a blocker and
then measured it, and it was not.**

A throwaway probe with 19 draggables on the desk and both reference books open,
at 1600x900, reported **5.9 ms/frame — about 169 fps**. There is no performance
problem today.

What was genuinely wrong is fixed: `WaxShape.outline()` was being called from
inside `_draw` by the reference book's matrix and polity plates, so an open book
rebuilt a seeded polygon plus two smoothing passes every frame for as long as it
stayed open. It is memoised now, the probe reports 3 outline builds for a whole
session, and `test_presentation` asserts the memo holds.

What is left is **speculative**: `Draggable._process` calls `queue_redraw()`
unconditionally, twice per object, every frame, with no dirty flag, and so do
`Desk`, `WaxPool` and `ReferenceBook`. At this object count it costs nothing
measurable.

So your actual Phase 0 is:

1. **Re-run the probe and write the number down.** It is about twenty lines —
   instantiate `main.tscn`, open both books, time 240 frames, print the average.
   Delete it afterwards; `tmp_*` is gitignored.
2. **Grep `_draw` and `_process` for allocation** — `RandomNumberGenerator.new()`,
   array building, polygon generation, `%`-formatting. Those are real waste
   regardless of frame time. `Candle` and `WaxShape` are the reference for how to
   cache them.
3. **Leave the dirty flag alone** unless the number says otherwise.

Then measure again after Phase 1. **If a materials pass pushes it past about
10 ms, fix the dirty flag then** — `desk_ledge.gd` has the pattern. Not before.

### Phase 1 — EXTRACT a material helper. Do not design one. (half a day)

The reason the graphics work has not scaled is that every object invents its own
lighting from scratch. `Sheet` has a banded gradient. `ReferenceBook` has
`_lit`/`_toward_light`, a lit lip and a dark trough, board thickness and a
tracking specular. `SignetRing` has an engraved device drawn as two offset
passes. `RingStand` has bone inlay. `WaxShape` has nested silhouettes. **They
share nothing**, so every new prop starts at zero and every existing one drifts.

**Extract the helper from the code that already works — do not invent an API and
then bend ten objects to fit it.** `ReferenceBook._draw` and `SignetRing._draw`
between them already contain most of the vocabulary; lift it out and name it.

A `Material` class beside `WaxShape` and `Ink`, owning roughly:

- `toward(node)` — flame direction in local space, which half these objects
  recompute by hand today
- `lit(node)` — the `light_level x light_strength` product, same clamp everywhere
- `tint(base, lit)` — the warm-near/grey-away response
- `engrave(node, path, toward, lit)` — the lit-lip / dark-trough pair
- `specular(node, at, toward, lit)` — the moving highlight
- `bevel(node, rect, toward, lit)` — a raised or sunken edge

Ship it with **nothing migrated**. The commit should change no pixels. Then:

### Phase 2 — One object at a time, material AND motion together (2–3 days)

**This replaces what was previously two separate phases, and the reason is that
the split was a mistake.** A big-bang refactor that touches ten objects' `_draw`
and produces no visible change is exactly the kind of work that quietly makes
things worse, because nobody is looking at pixels while they are deep in an
abstraction — and it puts all the boring work in one block that a session is
tempted to skip in favour of the visible wins.

So there is no boring phase. Each object gets **one pass that does everything**,
and lands as its own commit:

1. migrate its `_draw` onto `Material`
2. give it whatever the material table in `docs/GRAPHICS.md` §3 says it still owes
3. fix its motion at the same time — phases, easing, variance, audio hooks
4. **capture before and after, and put both in the commit message**
5. add the assertion or the capture frame that would catch a regression

Order by visibility, worst first. A suggested order, which you should challenge:

- **`PressController` + `SignetRing` + `WaxPool`.** The money moment, and
  `feel-critic` has never once been pointed at `press_controller.gd`. Biggest
  single win available.
- **`ReferenceBook`'s page turn.** `_draw_turning_page` is a rectangle whose width
  sweeps across the gutter; its own comment calls it crude. Books are open for
  most of every case.
- **`Ledger`.** It arrives, and writes itself with a sound and no pen. It is the
  last thing a player sees each day.
- **`WaxSpoon` and `Lens`.** Metal that should catch the flame as it moves.
- **`DeskPlaneView` and `DeskLedge`.** The surfaces everything else sits on.
- **`Desk._tick_sweep`.** Papers freed on a flat 1.5 s timer.
- **`ViewController`.** The spring works; nothing in the room reacts to the head
  coming up except parallax.

Re-measure frame time after the third object and again at the end (see Phase 0).

### Phase 3 — Shaders, gated and optional (1 day, exploratory)

The project now has **one localized canvas shader**:
`shaders/lens_refraction.gdshader`. It uses the Compatibility renderer's screen
texture only inside the magnifier aperture and preserves nearest-pixel sampling.
Do not turn it into a full-screen post-process. Confirm renderer support before
adding a second shader family.

Two candidates, both of which would replace a lot of banded-rect faking:
**parchment translucency** (the backlit sheet, the candle's molten cup, the thin
lip of a pool) and **wax subsurface** (the sealing wax and the candle share
`WaxShape`, so one shader serves both).

Do not shader anything that currently looks right. If it fights the pixel-art
anchor, abandon it and write that down in CONTINUITY so nobody tries again.

### Phase 4 — Atmosphere as systems (half a day)

Dust and the shade veil landed. Still open, from a cold `feel-critic` sweep:

- The door has never met the candle — it takes no light at all.
- No depth layer sits nearer the camera than the desk.
- The room's acoustic bed is one flat 3-second loop at −30 dB that never changes
  across a session; the candle is acoustically silent for ~86% of a day.
  `sound-director` has a full layered proposal with generator code that fits
  `tools/make_placeholder_audio.py`'s idiom.
- The day's-end lighting turn has no geometry to turn on.

### Phase 5 — DONE. Kept below only so the decision can be argued with.

**Decided: add a third witness to case_04 — Herbord Gantz, castellan of
Thurnstadt — and one obit putting him dead two years before the grant.** Two data
edits, no code. case_04 turns CONFIRM -> REFER on `witness_dead`, which is the
build's first and only `defect:` tier finding, so the DEFECT -> REFER policy row
now executes in play. Frames 45 and 46 prove both halves are legible on the desk.
The full reasoning, and each rejected alternative with the file that kills it, is
in the commit message. The original brief follows.

### Phase 5 (original) — The Kalendar decision. **Yours to make.** (half a day)

The owner has explicitly handed this one to you. Make the call, do the work, and
say clearly in the commit what you decided and why so they can disagree
afterwards. Do not ask first.

**The problem.** The Kalendar of the Dead has four rolls, thirty-odd obits, its
own model classes, a generated book and one of the four pigeonholes — and no
shipped case turns on it. A player who consults it twice correctly infers it
never matters and stops opening it, which inverts the exact lesson it was built
to teach. Separately, there is not one finding at the `defect:` tier anywhere in
`.tools/derived_findings.json`, so the `DEFECT -> REFER` row of
`data/tuning/verdict_policy.tres` **has never once executed in play**, and REFER
is only ever taught as "two laws disagree" and never as "this is broken, send it
back".

**The obvious fix** is a witness edit on `case_04_second_lion` — a man on its
list who the Thurn chapel's roll records as dead before the charter's date. That
makes the Kalendar decisive exactly once, fires the unused policy row, and turns
the day's acknowledged sag into the case that teaches the third ring. It changes
that case's verdict from CONFIRM to REFER, which means rewriting its three
outcome branches and its `_design` note, and re-checking `PrecedentCheck` on
Thursday.

**Decide it against these, which are the game's actual philosophy:**

- *Everything the ledger says was findable must have been renderable on the desk.*
  Non-negotiable, violated three times, every one treated as critical.
- *An anomaly is not a crime.* Case 1 exists to unteach the denying reflex. Any
  new defect must not make suspicion the correct default.
- *The question is "which authority am I choosing to satisfy", not "is this
  correct".* Verification is the floor, not the ceiling.
- *A system the player correctly concludes never matters is worse than no system*,
  because it also teaches them to stop investigating.
- *Absence is never evidence.* Whatever you do, the Kalendar's silences must stay
  worth nothing — a roll that convicts by omission is the hole this whole
  subsystem was built to close.
- *Soundness, Favour and Craft are three columns and never one number.*
- *The correct answer is often cruel, and that is allowed.* What is not allowed is
  a wrong answer that the desk gave the player no way to avoid.
- *Content is data.* If this needs a code change beyond one `Check`, you have
  probably picked the wrong fix.

Alternatives worth weighing before you take the obvious one: author a ninth case
rather than change a shipped verdict; or put the defect on a Thursday matter that
is already weak instead of case_04. Say which you rejected and why.

## The reviewers

Eleven now, in `.claude/agents/`. **They load at session start**, so anything
added mid-session is not callable until the next one.

Changed this session:

- **`render-critic` is new.** Nothing owned materials, lighting, depth, silhouette
  or pixel-art coherence — `feel-critic` owns motion and `godot-reviewer` owns
  correctness, and the gap between them is exactly where the flat candle and the
  unreadable ring stand lived. It is required to open capture frames and describe
  what it sees before asserting anything.
- **`feel-critic` now has a stated border with it**, plus the two traps that cost
  real time: `ease(x, 0.4)` snapping on the first frame, and comments claiming
  "spring" at damping ratios that overshoot by a tenth of a pixel.
- **`godot-reviewer` gained two standing checks**: `z_index` versus child order
  (which produced a shipped bug), and per-frame allocation.
- **Every read-only reviewer now has to separate *confirmed* from *inferred*.**
  Nine of sixteen findings in one session did not survive an adversarial check.
  The most valuable review this project has had rendered a frame and measured the
  ink bands rather than reading the layout code, and it was right when everyone
  reading the code was wrong.

Run them cold and in parallel before a large pass. The signal worth acting on is
**convergence** — several agents sharing no context naming the same defect. That
is how the arrival path, the dead air between cases, the unreadable ring stand
and the flat candle were all found.

`feel-critic`, `render-critic`, `rules-auditor` and `design-prosecutor` are
deliberately adversarial. Do not soften them.

---

## Known and deliberately not done

Full list with reasoning in CONTINUITY under "Known and deliberately not fixed".
The two that matter beyond Phase 5:

1. **Favour is stored and inert.** `Register.favor_totals()` is written and never
   called. It is the least systemic of the three judgement columns.
2. **Thursday closes on three consecutive "nothing is wrong, confirm it"
   matters**, one of which is Tuesday's matrix lookup with the answer inverted.
   This is the repetition risk, and it is content work.

`WitnessCheck` firing no defect in any shipped case is the same problem as Phase
5 and is solved by it.

---

## How to work here

**Commit as you go**, with messages saying what was wrong and why the fix is the
right *shape*. Live at `github.com/PatheticPants/HREGAME` on `main`.

**Change one thing, re-capture, compare.** The candle took four iterations, each
judged from a frame — including the one where the wax physics were backwards and
only the picture showed it.

**Add the assertion that would have caught it.** Every fix this session shipped
with a test or a capture frame that fails if it regresses.

**Look at the pixels.** Three times now the owner has seen something in a
screenshot that no test could see.

**Decide things.** The owner reviews after, and would rather see a decision made
with the philosophy applied than a question sent back up. Phase 5 is explicitly
yours. Where you do make a judgement call, put the reasoning in the commit
message so it can be argued with rather than reverse-engineered — and record it
in CONTINUITY if it is the kind of thing the next session would otherwise redo.
