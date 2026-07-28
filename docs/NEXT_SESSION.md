# Brief for the next session

You are picking up **Hand and Seal**, a Papers-Please-style document-inspection
game in Godot 4 / GDScript at `C:\HREGAME`, set in a fictionalised Holy Roman
Empire. You are a low-born notary of the Imperial Chancery; petitioners bring
claims to land and title; you verify charters, wax seals, witness lists and
regnal dates against a body of law, then rule in wax with a signet ring. One
carried candle is the only light in the room and the day's clock.

**Read `docs/CONTINUITY.md` first.** Then `README.md`. Then this. Do not trust any
of the three over the actual files — every one of them has been caught lying in
the last two sessions, including about whether the project was a git repository.

---

## Run this before you touch anything

```bash
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --script tests/test_rules.gd
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --fixed-fps 60 --scene res://tests/test_presentation.tscn
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --fixed-fps 60 --scene res://tests/test_session.tscn
python tools/verify_content.py
```

Green is **rules 81, presentation 172, session 73, content PASS**. Run the rules
suite before the Python one: it writes `.tools/derived_findings.json` and the
Python compares every finding against it rather than only the final verdict.

And then, before you form any opinion about how the game looks:

```bash
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --path . --resolution 1600x900 --scene res://tests/qa_capture.tscn
```

43 annotated PNGs land in `.tools/shot_*.png`. **Open them.** Deliberately not
headless — Godot cannot render 2D lights with the dummy driver, and lighting is
what they exist to check.

---

## What the owner has asked for

Verbatim, across two sessions:

> Improved animations and perspective shifts. Better stylized realism in almost
> every part of the game. Materials, lighting, depth, weight. Pixel-art anchored,
> not photoreal.

> I want this to be a very atmospheric game. The night time vibe is very nice.
> Continue to expand upon this and create a truly immersive experience.

> I really want graphics, lighting, and animations to be improved upon.

They also want **sparse, subtle humour** (budgeted and documented — read the rule
in CONTINUITY before adding a single line), and they are watching for the loop
becoming **repetitive or boring**.

They notice detail. Both bugs they have reported personally were real, were
invisible to the test suite, and were things I had looked at and passed over: a
candle whose melt was drawn in the wrong colour relationship, and wax that drew
on top of the entire room. **Assume anything they mention is real and reproduce
it in a capture before you theorise about it.**

---

## The single highest-value thing you can do

**Build the graphics and animation pass into a system, not another list of
fixes.** The last two sessions have been individually-diagnosed defects: this
sheet does not darken, that shadow is a rectangle, this book has no boards. The
project is now past the point where that scales.

Three concrete candidates, in the order I would take them:

### 1. The presentation layer has no material vocabulary

Every object invents its own lighting from scratch. `Sheet` has a banded
gradient. `ReferenceBook` has a lit lip and a dark trough. `SignetRing` has a
specular that tracks the flame. `RingStand` has inlay. `WaxShape` has a whole
nested-silhouette treatment. **They share nothing**, so every new prop starts at
zero and every existing one drifts.

There should be a `Material` helper next to `WaxShape` and `Ink` that owns:
warm/cool tint by light level, the directional lit-edge/dark-edge pair, a moving
specular, a contact shadow, and the shade veil. Then every `_draw` becomes a
description of a shape rather than a re-derivation of how light works. That is
what makes the next twenty props cheap and consistent — and it is the actual
precondition for "improve the graphics" being a day of work rather than a month.

Read `draggable.gd` (`shade_alpha`, `draw_shade`, `draw_soft_shadow`), `sheet.gd`
`_draw_body`, `reference_book.gd` `_lit`/`_toward_light`, and `wax_shape.gd`
before designing it. Much of the vocabulary already exists; it is just scattered.

### 2. gl_compatibility has shaders and this project uses none

`project.godot` declares `renderer/rendering_method="gl_compatibility"`. There
are zero `.gdshader` files and zero `CanvasItemMaterial`s in the project. A
`godot-reviewer` pass mapped what is and is not available on this renderer —
re-run it before committing to anything. A single cheap canvas shader for
parchment translucency, or for the wax's subsurface, would replace a great deal
of the banded-rect faking. **But**: `Draggable._process` calls `queue_redraw()`
unconditionally twice per object per frame with no dirty flag, and so do `Desk`,
`WaxPool` (four child CanvasItems) and `ReferenceBook`. Attaching per-object
materials on top of that is the thing that will finally make this run slowly.
Fix the dirty flag first — it is recorded under "Known and deliberately not
fixed" in CONTINUITY and it is now a blocker rather than a nicety.

### 3. Animation still has holes the beats pass did not reach

The door, the petitioner's walk, the session's between-case timing and the
candle have all had a pass. These have not:

- **The press.** The money moment. It has phases and easing but has never been
  reviewed since; `feel-critic` has never been pointed at `press_controller.gd`.
- **The page turn.** `reference_book.gd` `_draw_turning_page` is a rectangle
  whose width sweeps across the gutter. Its own comment calls it crude.
- **The ledger arriving and writing itself.** A reviewer found it writes with a
  sound and no pen.
- **The sweep.** `Desk._tick_sweep` frees papers on a 1.5s timer.
- **The view transition.** Reviewed once; the spring works, but nothing in the
  room reacts to the head coming up except parallax.

---

## Known and deliberately not done

All recorded in CONTINUITY with reasoning. The three that matter:

1. **The Kalendar of the Dead convicts nobody.** Four rolls, thirty-odd obits,
   its own model classes, a generated book and one of four pigeonholes — and no
   shipped case turns on it. A player who consults it twice correctly infers it
   never matters. The fix is a witness edit on `case_04_second_lion` so it
   convicts exactly once; that also fires the `DEFECT -> REFER` policy row, which
   **has never once executed in play** (verify it yourself: no `defect:` line
   exists anywhere in `.tools/derived_findings.json`). It changes that case's
   verdict from CONFIRM to REFER, so it is a content decision — put it to the
   owner rather than doing it silently.
2. **Favour is stored and inert.** `Register.favor_totals()` is written and never
   called.
3. **Thursday closes on three consecutive "nothing is wrong, confirm it"
   matters**, one of which is Tuesday's matrix lookup with the answer inverted.
   This is the repetition the owner is worried about, and it is content work.

---

## How to work here

**Use the ten subagents in `.claude/agents/` heavily.** Each starts with a cold
context, so the deep reading happens in their window rather than yours. Run them
in parallel against a cold read before a large pass. The signal worth acting on
is **convergence**: when several agents that share no context independently name
the same defect, it is real. That is how the arrival path, the dead air between
cases, the unreadable ring stand and the flat candle were all found.

`feel-critic`, `rules-auditor` and `design-prosecutor` are deliberately
adversarial. Do not soften them.

**And do not take them at face value.** In the last session a reviewer claimed
the desk surface is never lit; it is, and one screenshot settled it. Another
claimed a book section had no marginalia; it had. Adversarially verifying
findings before acting on them caught nine wrong claims out of sixteen. The
verifier that actually rendered a frame and measured the ink bands was right when
I, looking at the same frame, was wrong.

**Commit as you go**, with messages that say what was wrong and why the fix is
the right shape. The repo is live at `github.com/PatheticPants/HREGAME` on `main`.

**Look at the pixels.** Twice now the owner has seen something in a screenshot
that no test could see. Capture the object in the state you are worried about,
not in isolation — the wax had no frame in which anything was on top of it, which
is exactly why it drew over the room for months.
