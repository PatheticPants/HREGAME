---
name: matter-shape-redesign
description: Live initiative from 2026-07-30 — the owner wants matter shapes whose evidence is physical/spatial/visual rather than textual, because ~3/4 of a matter's cost is reading and 6 of 8 shipped matters are lookups.
metadata:
  type: project
---

Opened 2026-07-30 by the owner, verbatim: *"We could have land disputes (or other
things please be creative) that are just handed to us by a servant and they walk
out the door instantly and we have to decide what to do in an interesting and
engaging way. Everything is very wordy at the moment and I am thinking we may need
a way to make it less of a reading simulator."*

**Two measurements that motivate it and should not be re-derived from scratch:**
about three quarters of a matter's cost is reading, and six of the eight shipped
matters have exactly one defensible verdict — they are lookups, not decisions.

**Measured baseline for "how wordy" (method: count only strings that reach a
rendered surface).** One shipped matter (`case_08_mill_on_the_aue`) is roughly
**245 words of packet** (docket face 69, charter face 160, seal legend under the
glass 4, backlit ghosts 12) plus **~320 words of dialogue** (113 of it forced
arrival speech) plus **~230 words of reference pages** the design names. Call it
**~800 words to dispose of one matter, ~245 of which is the packet.**
`case_02_grellwater` measures 223 for the packet, so the packet figure is stable.
Quote these rather than re-counting.

**Why:** the owner is not asking for a new defect type. They are asking for the
evidence to be legible with the hands and eyes. The existence proof already in the
build is `Sheet._draw_erasures` — a scraped patch backlit against the flame
resolves a whole check with no reading at all.

**How to apply:**
- Judge any new matter proposal on whether its DECISIVE fact is reachable by a
  gesture (lift to flame, glass on wax, lay two things side by side, count) before
  judging whether it is a good puzzle.
- Hard constraints the owner restated: no new `Check` subclass, no HUD or overlay,
  content is JSON under `data/`, the rules layer never touches a node.
- The cheapest genuinely-physical extension point in the build is the lens: it
  duck-types `has_detail()` / `detail_centre()` / `draw_detail()` by name
  (`scripts/presentation/lens.gd:175-189`), so any Node2D in `surface` becomes
  magnifiable with zero lens changes.
- See [[case-authoring-traps]] item 8 for the one-charter-per-packet rule that
  constrains every multi-document shape.

Related: [[owner-loop-direction]], [[case-authoring-traps]].
