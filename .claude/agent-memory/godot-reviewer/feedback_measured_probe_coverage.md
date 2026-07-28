---
name: feedback-measured-probe-coverage
description: The project's 5.9ms/frame measurement (tests/tmp_perf_probe.gd) only lays out a case's documents and opens both books — it never strikes a wax seal. Don't let "frame time is measured" block flagging real per-frame waste in code paths the probe doesn't exercise.
metadata:
  type: feedback
---

`docs/GRAPHICS.md` and `docs/CONTINUITY.md` both say frame time was measured
at 5.9ms/frame with 19 draggables and both reference books open, and
instruct reviewers not to report speculative performance problems given that
number. Read `tests/tmp_perf_probe.gd` before leaning on that number: it
instantiates `main.tscn`, lays out one case's documents, opens the books, and
measures — it never presses a signet ring into wax, so no `WaxPool` in that
scene ever has `impressed = true`.

Found 2026-07-28: `wax_pool.gd`'s `_draw_stamp()` calls `_struck_polygons()`
every frame once a seal is struck, which rebuilds `_outline()` (a fresh
`PackedVector2Array`) and then runs `Geometry2D.intersect_polygons()` against
it — every frame, forever, for as long as the struck charter exists, even
after `radius`, `seat_depth` and `impact` have all settled to fixed values and
the polygon intersection is provably identical frame to frame. This is the
same *shape* of waste as the `WaxShape.outline()` bug already fixed for
`ReferenceBook` (rebuilding a pure function of unchanging inputs inside
`_draw`), but the 5.9ms probe cannot have priced it in because the probe never
creates an impressed pool.

**Why:** "The frame time is measured, don't report speculative problems" is a
good instruction in general, but it only covers the code paths the probe
actually runs. A reviewer who treats the measurement as covering the whole
codebase will wrongly wave through real, confirmed (not speculative)
redundant computation in paths the probe skips.

**How to apply:** When the standing instructions cite a measured number,
check what scenario produced it (read the probe script) before using that
number to suppress a finding. If the finding's code path isn't in the
probe's scenario, it's still fair game — report it as confirmed waste, and
say plainly that it's unpriced by the existing measurement rather than
claiming it's slow.
