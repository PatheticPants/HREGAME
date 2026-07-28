# Visual and Animation Pass

> **HISTORICAL.** This records the visual pass made *before* the two large
> sessions of 2026-07-28. Several things it describes have since been replaced:
> the candle's melt was rebuilt entirely (it described a flood that turned out to
> read as crumpled paper), the audience-view door was rewritten onto a hinge
> spring, and the shade veil now governs how much of any face is legible at all.
> Read it for the reasoning behind decisions that survived — the die striking
> where the ring was, wax pouring where you tip it, the projection contract — and
> read `docs/CONTINUITY.md` and `docs/NEXT_SESSION.md` for what is true now.

This pass responds to the six visual concerns raised after the campaign build:

1. the candle melt and flame appeared off-centre;
2. the signet impression was too small for the poured wax;
3. the audience-view projection flattened every desk object;
4. seals looked like a tooltip rather than real wax under the glass;
5. desk materials needed more physical depth;
6. the melting, pouring, pooling, pressing, and peeling sequence needed better motion.

The changes are implemented and visually verified. No new raster plate was
introduced: the existing authored pixel/painterly assets remain the style anchor,
while the physical behaviour and close detail are rendered procedurally.

## Candle registration

`scripts/presentation/candle.gd`

- `WICK` is now registered to the actual dark wick in
  `art/props/candle_holder.png` at local `(-16, -28)`.
- The flame, light rig, heat point, dead wick, and spent-wax flood all use that
  one coordinate, so they remain aligned throughout the day.
- The candle still drowns into its own irregular set-wax pool; the corrected
  origin removes the previous down-right slide across the candle body.

## Seal and wax proportions

`scripts/presentation/signet_ring.gd`,
`scripts/presentation/wax_pool.gd`,
`data/tuning/wax_feel.tres`

- The die face increased from radius `23` to `30`.
- A unit wax pour decreased from radius `46` to `42`.
- A good pour now settles at roughly 39–41 desk units, leaving the 30-unit die
  large enough to dominate the pool while retaining a believable raised wax rim.
- The desk-scale impression now includes an unreadable ring of matrix strokes;
  the magnifier resolves those strokes into lettering.
- The device occupies the central field rather than a tiny island inside several
  oversized rings.
- The ring now compresses slightly into the wax instead of growing toward the
  camera while it sinks.

The off-rim mechanic is unchanged. The die still strikes exactly where the ring
was held, the impression remains clipped to the wax geometry, and partial
coverage still affects craft grade.

## Audience-view depth

`scripts/presentation/desk.gd`,
`scripts/presentation/draggable.gd`

The desk surface still pivots around its far edge, but props no longer inherit
the full vertical squash.

- The contact plane foreshortens to `0.62`.
- Every `Draggable` receives local relief compensation, preserving most of its
  apparent height while its contact point still recedes with the desk.
- A small far-to-near scale gradient (`0.90` to `1.06` at full audience view)
  adds depth without making near objects lurch toward the camera.
- Candle lights remain counter-scaled in world space, so the view change does not
  turn the illumination into a horizontal stripe.
- Returning to work view restores exact unit scale.

The relevant presentation test now separately proves that the desk surface
foreshortens and that raised props retain a healthy vertical-to-horizontal scale.

## Magnifier and seal material

`scripts/presentation/lens.gd`,
`scripts/presentation/seal_tag.gd`,
`scripts/presentation/wax_pool.gd`,
`scripts/presentation/wax_shape.gd`,
`scripts/presentation/ink.gd`

The old enlarged view placed a small seal at the top of the lens and explanatory
text below it. That has been removed.

The glass now presents the seal as an optical close-up:

- the wax fills most of the circular field;
- nested irregular silhouettes describe the wax shoulder, compressed face,
  raised rim, meniscus, and moving candle gloss;
- the heraldic device is incuse, with light and dark edges derived from depth;
- the actual legend is cut around the matrix as circular incuse lettering;
- worn letters and physical chips remain visible without a caption explaining
  them;
- the clerk's own off-centre strike stays off-centre beneath the glass rather
  than being cosmetically corrected;
- the focus transition resolves over the last few percent instead of scaling an
  image up from a dot.

The magnifier itself increased from radius `92` to `104` and now has:

- dark edge refraction and a nearly clear centre;
- reflections drawn above the enlarged wax;
- a candle-oriented highlight and opposite tarnished shadow on the bezel;
- a layered wooden handle with brass collar;
- a larger, steadier optical field.

This keeps inspection diegetic: legal and craft conclusions remain in the
Register/ledger, while the glass shows only what is physically in the wax.

## Melt, pour, pool, and press motion

`scripts/presentation/wax_spoon.gd`,
`scripts/presentation/wax_drop.gd`,
`scripts/presentation/wax_pool.gd`,
`scripts/presentation/signet_ring.gd`,
`scripts/presentation/press_controller.gd`

### Melting spoon

- The solid resin cake initially follows the brass bowl.
- As it melts, the reservoir progressively decouples from the bowl rotation and
  remains level under gravity.
- Molten wax gathers toward the low pouring lip.
- Heat shimmer and registered bubbles remain tied to temperature and melt state.

### Pour

- Surface tension draws a tapering wax neck out of the lip between drops.
- Falling beads are oriented teardrops, stretched by motion with a faint trailing
  filament, rather than circular dots moving on a rail.
- Beads still travel to their real landing position and only add volume on
  impact.

### Pool

- Radius now follows a damped viscous spring rather than a direct interpolation.
- Each arriving drop carries outward momentum; surface tension then settles the
  rim to its volume-derived target.
- A decaying landing wave travels across the surface.
- Hot gloss, resin bubbles, inclusions, splash satellites, cooling, and
  candle-relative rim light share the same physical state.

### Press

- Resistance, creep, shudder, give, hold, and sticky peel remain separate phases.
- The give now produces a short compression pulse in both ring and wax.
- The enlarged die makes the resulting impression materially legible.
- The wax string still rises from the actual strike point and snaps during peel.

## Visual QA

Run:

```powershell
.\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe `
  --path . --resolution 1600x900 --scene res://tests/qa_capture.tscn
```

The harness writes the following new or materially revised frames to `.tools/`:

- `shot_09_audience_view.png`
- `shot_08_strike_centre_close.png`
- `shot_16_glass_on_own_seal.png`
- `shot_22_wax_molten.png`
- `shot_23_wax_pouring.png`
- `shot_24_wax_pool_fresh.png`
- `shot_25_glass_on_pendant_seal.png`
- `shot_26_glass_pendant_close.png`

The close pendant capture verifies that the circular legend remains readable,
the device remains identifiable, and glass reflections sit above rather than
inside the wax.

## Verification

The presentation suite covers the preserved gameplay contracts and the new
projection contract:

```powershell
.\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe `
  --headless --fixed-fps 60 --path . `
  --scene res://tests/test_presentation.tscn
```

Final verification:

- rules: **90 checks, 0 failures**
- session: **76 checks, 0 failures**
- presentation: **288 checks, 0 failures**
- independent content verifier: **passed**

The Godot session and presentation harnesses still print their pre-existing
exit-time resource-retention diagnostics after successful assertions; both
processes return exit code `0`.
