---
name: project-zindex-latent-cases
description: Candle (scripts/presentation/candle.gd:142) sets a permanent z_index=1, structurally the same shape as the wax_pool bug fixed in 7d68bfa — unguarded by any test or capture as of 01588ea. Check whether it has been made transient (like signet_ring/wax_spoon) or removed before re-flagging.
metadata:
  type: project
---

Found during the 2026-07-28 review at commit `01588ea`, after `docs/GRAPHICS.md`
and `docs/CONTINUITY.md` had already documented the wax_pool z_index bug
("the wax sat on top of the room instead of on the parchment", fixed in
`7d68bfa`) and established the house rule that legitimate z_index uses on this
desk are transient and self-cancelling (ring while held/in the wax, a falling
bead, the lens).

`Candle._ready()` (`scripts/presentation/candle.gd:142`) sets `z_index = 1`
once, unconditionally, and it is never toggled anywhere else in the file —
unlike `signet_ring.gd:105` (`z_index = 3 if is_held or press_depth > 0.001 or
peel_amount > 0.001 else 0`) and `wax_spoon.gd:49`, which both rise only while
held and fall back to 0. `reference_book.gd` (Almanac, Book of Matrices,
Kalendar, Register) never sets `z_index` at all, so it stays at the Node2D
default of 0 — meaning, given Godot's global z-sort (higher z always draws
above lower z regardless of tree/child order), NONE of those books can ever
draw above the candle no matter where `desk.gd`'s `bring_to_front()` (called
on every pickup, for every Draggable including the candle itself) places them
in `surface`'s child list. This contradicts `desk.gd`'s own docblock ("Draw
order is child order in surface, full stop... There is no z_index juggling")
and candle.gd's own justifying comment ("can be picked up and buried by a
book") — the only book that actually CAN bury it is `Ledger`
(`z_index = 6`, in `ledger.gd:48`), which is invisible during ordinary play
(`visible = false` until end-of-day `open_with()`), so in practice no book a
player handles mid-case can ever cover the candle, silently.

Confirmed by reading `candle.gd`, `reference_book.gd`, `draggable.gd`,
`ledger.gd`, `desk.gd`'s `_pick`/`bring_to_front`, and by grepping
`tests/test_presentation.gd` for any `z_index` assertion involving the candle
(none exist — only the wax_pool regression test at line ~747 checks
`pool.z_index == 0`). No capture frame demonstrates the failure state either
(a sheet/book dragged over the candle *after* it was set down); `shot_03_candle_on_charter.png`
shows the candle on top of a charter but is consistent with both the correct
child-order behavior and the z_index override, since in that frame the candle
was plausibly also last in child order — it does not distinguish the two.

**Why this is worth carrying forward:** it is the exact same shape as a bug
that already shipped for months in this codebase (identical z_index value,
same "permanent override defeats child order" mechanism), and it is the one
z_index in the whole `presentation/` tree that neither matches the documented
legitimate-exception list (ring/bead/lens) nor has been made transient like
its siblings.

**How to apply:** Before re-flagging, check whether `candle.gd`'s z_index has
been made conditional (e.g. `z_index = 1 if is_held else 0`, mirroring
signet_ring/wax_spoon) or removed outright, and whether a capture or
`test_presentation.gd` assertion now exercises "a sheet dragged over a
set-down candle." If so, this is closed; if not, it is still live.
