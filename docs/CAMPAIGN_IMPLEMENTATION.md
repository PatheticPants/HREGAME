# Hand and Seal — campaign implementation

This document records the production pass built from the review now preserved in
`CODEX_IMPLEMENTATION_AND_REVIEW_HANDOFF.md`. It describes the game as
implemented, the contracts that should survive future content work, and the
verification commands for the current two-day campaign.

## What the player now experiences

The game begins before the first knock with a discarded, sealable practice leaf.
Practice is not timed, cannot enter the Register, and cannot affect the campaign.
After striking an office device, the player must hold the magnifying glass over
their own impression. Confirmed lens focus opens the door but leaves the detail
under the glass; putting the glass down begins the working day.

Tuesday presents the original three matters in fixed order:

1. Küfergasse teaches that wear is not falsity.
2. Grellwater turns on whether a physical die was alive when the wax was struck.
3. Kesselholt presents a genuine conflict between Imperial accession reckoning
   and Church election reckoning.

The candle is free while the player only listens. The first physical engagement
with a live matter starts working time; from then on it burns through research,
thought, and petitioner speech until judgment. Docket selection and moving the
permanent memorandum do not start it. The engagement has a distinct delayed
sound, a longer flame catch, and a persistent new bead of wax in the saucer.

The Tuesday ledger has a folded, content-authored `THURSDAY` corner. Turning it
lights a fresh candle and exposes four physical passage dockets. The player can
hear them in any order by dragging one into the central hearing notch. Selection
costs no candle.

Thursday contains:

- a clean second Thurn lion as a quick mastery check;
- a Grellwater regrant whose result depends on the player's earlier title;
- a competing Imperial Kesselholt writ that reverses the substantive claimant
  positions without erasing either authority;
- a fresh Marchfeld exemplification that explicitly cures the earlier
  Küfergasse evidentiary question.

If a prerequisite Tuesday matter was never ruled, that matter returns instead
of spawning its consequence case. Tuesday's Kesselholt choice also produces one
of three physical opening letters: Imperial objection, Church appeal, or a joint
covering sheet whose two endorsements still disagree.

## Legal model

`lawful_verdict` remains serialized for compatibility, but now means the office's
procedural instruction. It is not a universal statement of legal truth.

For an ordinary factual defect, the instrument has one defensible disposition.
For a pure authority conflict, the adjudication records each authority's
substantive position:

- `CONFIRM` chooses an authority that admits the instrument;
- `DENY` chooses an authority that refuses it;
- `REFER` follows office procedure without choosing between them.

`RulingRecord.was_sound` therefore means legally defensible. It is distinct from
`RulingRecord.follows_office()`.

The generic `PrecedentCheck` works from stable `subject_id` and `claimant_id`
fields. It handles:

- the same title returning;
- a new instrument that explicitly cures the old objection;
- a competing claimant whose substantive positions invert;
- the drawing authority of the new clean instrument;
- the office's stored position as precedent rather than sovereign law.

Feedback adjudicates against `Register.before(record)`. A ruling can never become
its own precedent, and later rulings can never be retroactively presented as
evidence that was available earlier.

## The physical Register

The Register persists across candles and is grouped under authored `TUESDAY` and
`THURSDAY` dividers. It records the ruling, the authority positions, and the
consequence note.

An indefensible ruling is reviewed only after another call has passed through
the office. When the senior marginalium appears, the Register is physically
returned from the rack with a vermilion `REVIEWED` slip. Opening it lands on the
latest correction and clears the now-spent slip. The correction quotes a
specific principle that was findable—never only “incorrect.”

## Data-driven campaign seams

`data/days/_order.json` defines campaign order. Each day JSON defines:

- `entry_label` for its ledger corner and Register divider;
- `heading`, candle length, and burnout text;
- `selection_mode` (`fixed` or `tray`);
- case slots with optional `requires_ruled` and `fallback_case_id`;
- conditional physical opening documents.

Adding a third day does not require a hardcoded weekday or a new session stage.

Dynamic consequence cases set `dynamic_precedent: true` and
`correct_verdict: "DYNAMIC"`. Static startup verification skips authored equality
for those cases; dedicated branch tests and the independent verifier prove their
Register-dependent outcomes.

## New authored assets

Four petitioner portraits were generated with the built-in image generation
model, using `art/petitioners/wilhelm_ott_bust.png` as the style reference. The
shared prompt requested a late-1990s, hand-authored pixel-art, frontal
upper-body chancery portrait at 384×384, candlelit, with no text or watermark.
Character-specific clothing, age, posture, and expression were supplied for:

- `art/petitioners/gero_kalt_bust.png`
- `art/petitioners/emmerich_hove_bust.png`
- `art/petitioners/matthias_erken_bust.png`
- `art/petitioners/elsbeth_ott_bust.png`

The generated green backgrounds were removed with the skill's chroma-removal
helper, and each final PNG was visually inspected and imported by Godot.

`audio/candle_catch.wav` is a deterministic placeholder event generated through
`tools/make_placeholder_audio.py`. It can be replaced later without changing
gameplay code because presentation addresses audio by event name.

## Verification

From `C:\HREGAME`:

```powershell
& '.\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' `
  --headless --path . --script tests\test_rules.gd

& '.\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' `
  --headless --fixed-fps 60 --path . --scene res://tests/test_session.tscn

& '.\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' `
  --headless --fixed-fps 60 --path . --scene res://tests/test_presentation.tscn

python tools\verify_content.py

& '.\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' `
  --path . --resolution 1600x900 --scene res://tests/qa_capture.tscn
```

The final logic suites cover plural authority, every dynamic precedent branch,
all conditional letter variants, unresolved-case fallbacks, a successful
reverse-order Thursday, candle burnout on both days, campaign end behavior,
review-slip delivery, and day-separated Register pages.

The presentation harness may print an ObjectDB/resource warning while tearing
down its synthetic scene. Its assertions complete successfully; this remains
test-harness cleanup debt rather than a demonstrated gameplay failure.
