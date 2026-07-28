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

Green is **rules 81, presentation 173, session 73, content PASS**. Run the rules
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

## THE PLAN OF ATTACK

Review it, disagree with it, expand it. It is ordered so that each phase makes
the next one cheaper — do not reorder without a reason.

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

### Phase 1 — Give the game a material vocabulary (1–2 days)

**This is the headline change and the reason the graphics work has not scaled.**

Every object invents its own lighting from scratch. `Sheet` has a banded
gradient. `ReferenceBook` has `_lit`/`_toward_light`, a lit lip and a dark
trough. `SignetRing` has a specular that tracks the flame. `RingStand` has
inlay. `WaxShape` has nested silhouettes. **They share nothing**, so every new
prop starts at zero and every existing one drifts apart from the others.

Build a `Material` helper beside `WaxShape` and `Ink` that owns:

- `tint(base, light_level, light_strength)` — the warm/cool response
- `toward(node)` — the flame direction in local space, the thing half these
  objects recompute by hand
- `engrave(node, path, toward, lit)` — the lit-lip / dark-trough pair
- `specular(node, at, toward, lit)` — a moving highlight
- `bevel(node, rect, toward, lit)` — a raised or sunken edge
- and re-export `draw_soft_shadow` / `draw_shade` so there is one place to look

Then rewrite `Sheet`, `ReferenceBook`, `SignetRing`, `RingStand`, `WaxSpoon`,
`Lens`, `WaxTablet`, `DeskLedge`, `DocketTray` and `DeskPlaneView` against it —
each `_draw` becoming a description of a shape rather than a re-derivation of how
light works.

**Capture before and after, object by object.** The success condition is that
nothing looks worse and every surface has gained at least the missing third of
the minimum material (see `docs/GRAPHICS.md` §3). Expect to find two or three
objects that were quietly better than the rest and must not be levelled down.

### Phase 2 — Then, and only then, shaders (1 day, exploratory)

The project has **zero `.gdshader` files and zero `CanvasItemMaterial`s**, and
`gl_compatibility` supports canvas shaders. Ask `godot-reviewer` what is actually
available on this renderer *before* committing.

The two best candidates, both of which would replace a lot of banded-rect faking:

- **Parchment translucency** — the backlit sheet, the candle's molten cup, the
  thin lip of wax at a pool's edge.
- **Wax subsurface** — the sealing wax and the candle share `WaxShape`, so one
  shader serves both.

Do not shader anything that currently looks right. Budget one day; if it fights
the pixel-art anchor, abandon it and say so in CONTINUITY.

### Phase 3 — The animation holes the beats pass never reached (1 day)

The door, the petitioner's walk, the between-case timing and the candle have all
had a pass. These have not:

- **The press.** The money moment, and `feel-critic` has never been pointed at
  `press_controller.gd`. Start here.
- **The page turn.** `reference_book.gd` `_draw_turning_page` is a rectangle whose
  width sweeps across the gutter. Its own comment calls it crude.
- **The ledger arriving and writing itself.** It writes with a sound and no pen.
- **The sweep.** `Desk._tick_sweep` frees papers on a flat 1.5s timer.
- **The view transition.** The spring works, but nothing in the room reacts to
  the head coming up except parallax.

### Phase 4 — Atmosphere as systems (half a day)

Dust and the shade veil landed. Still open, from a cold `feel-critic` sweep:

- The door has never met the candle — it takes no light at all.
- No depth layer sits nearer the camera than the desk.
- The room's acoustic bed is one flat 3-second loop at −30 dB that never changes
  across a session; the candle is acoustically silent for ~86% of a day.
  `sound-director` has a full layered proposal with generator code that fits
  `tools/make_placeholder_audio.py`'s idiom.
- The day's-end lighting turn has no geometry to turn on.

### Phase 5 — Put the content decision to the owner (their call, not yours)

**The Kalendar of the Dead convicts nobody.** Four rolls, thirty-odd obits, its
own model classes, a generated book, one of four pigeonholes — and no shipped
case turns on it, so a player who consults it twice correctly concludes it never
will. The fix is a witness edit on `case_04_second_lion` so it convicts exactly
once. That also fires the `DEFECT -> REFER` policy row, which **has never once
executed in play** — verify it yourself, there is no `defect:` line anywhere in
`.tools/derived_findings.json`, so REFER is currently only ever taught as "two
laws disagree" and never as "this is broken, send it back".

It changes that case's verdict from CONFIRM to REFER. **Ask before doing it.**

---

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
The three that matter beyond Phase 5:

1. **Favour is stored and inert.** `Register.favor_totals()` is written and never
   called. It is the least systemic of the three judgement columns.
2. **Thursday closes on three consecutive "nothing is wrong, confirm it"
   matters**, one of which is Tuesday's matrix lookup with the answer inverted.
   This is the repetition risk, and it is content work.
3. **`WitnessCheck` fires no defect in any shipped case.** Proven by synthetic
   packets in the rules suite and by nothing the player will ever be handed.

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
