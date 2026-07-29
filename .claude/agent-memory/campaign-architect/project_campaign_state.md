---
name: project-campaign-state
description: Hand and Seal — what persists across days today, which persistence channels exist, and which stored state is inert (re-verified against source 2026-07-28).
metadata:
  type: project
---

Re-verified against source on 2026-07-28. 8 cases, 2 authored days (`data/days/day_01.json`,
`day_02.json`, manifest `_order.json`), one `Register` held in `SessionController`, no save
system. Six Checks fire; `GenealogyCheck`, `PalaeographyCheck`, `JurisdictionCheck` unwritten.

**Four working Register-to-play channels exist.** These are the whole campaign machinery today:
1. `PrecedentCheck` — reads `ctx.register` via `Register.latest_for_subject()`.
2. `DialogueLine.requires_case` / `requires_verdict` / `requires_soundness` / `priority`.
3. `DayOpeningDocument.matches(register)` — conditional morning letters.
4. `DayCaseSlot.resolve()` — `requires_ruled` + `fallback_case_id`.

**Favour is stored and completely inert.** `CaseOutcome.favor` -> `RulingRecord.favor` -> one
prose sentence in `SessionController._ledger_summary()`. `Register.favor_totals()` is written
and never called anywhere. Keys in use: `imperial`, `church`, `custom`. Largest built-but-unused
system in the game.

**Craft is also inert beyond the ledger line.** `ImpressionRecord` is stored per ruling and
never consulted again.

Four load-bearing facts that constrain any campaign design:
- **`Register.latest_for_subject()` and `entries_for_day()` filter out `foreign_hand`**, so
  R.V.'s three seeded rulings are structurally unreachable by `PrecedentCheck`. The seed
  entries also carry **no `subject_id`**. Making the predecessor's precedent contestable needs
  both a seed edit and a deliberate second accessor.
- **`Necrology.silences` is a Dictionary rendered as a real `kind == "silence"` page** by
  `KalendarBook.build`, placed second, before any roll. Adding or removing a roll therefore has
  a correct, self-documenting, non-evidential in-world representation for free, and
  `WitnessCheck` degrades to honest ignorance automatically.
- **`Adjudicator.adjudicate_case` sets `ctx.necrology = world.necrology`** — the rules layer and
  the Kalendar book read the same object, so one filter changes both.
- **Exactly one pigeonhole is free (ledge slot 0).** Tablet=1, Kalendar=2, Register=3. Spending
  it is a real and final cost; `desk.gd:276-281` records this on purpose.

**Five facts re-confirmed 2026-07-29 while designing the introduction curve** (read the source
before trusting any of them again, but they were true on that date):
- **Every one of the eight shipped cases has 2-3 witnesses carrying a `house`.** So every case
  emits at least one `WitnessCheck` finding. The Kalendar therefore cannot be withheld from any
  day that hears a shipped matter without at minimum a CLEAN-severity contract breach, and
  `case_01` breaks it at NOTE (`witness_died_that_year`).
- **`PrecedentCheck` provably emits nothing on `day_01`.** It reads only
  `ctx.register.latest_for_subject()`, which filters `foreign_hand`, and none of the three
  `register_seed.json` entries carries a `subject_id`. The Register book is the ONE reference
  volume that can be withheld from Tuesday with zero effect on any finding.
- **`DayData.resolve_cases()` already tolerates a slot resolving to null** (it skips nulls and
  dedupes), and `lore.case_by_id(&"")` returns null. An "empty slot" needs no new code.
- **`practice_documents` is global, not per-day.** It lives in `world.json`, runs once from
  `SessionController._begin_practice()`, and `_on_practice_lens_dropped` hardcodes
  `_begin_day(0)`. Teaching a verb with a no-stakes rehearsal on any day but the first needs a
  flow change, not just data.
- **`deliver_day_document()` cannot deliver a book.** `_make_document_view` builds only
  `CharterView`/`LetterView`/`DocketView`. A mid-day book arrival is new code; a dawn arrival in
  a pigeonhole is free.

**The economy exists only as a planted seam**, not as code: `register_seed.json` has R.V.'s
"Fee for the writing, two marks, received of the party." No purse, no coin, no tariff.

**How to apply:** judge any campaign proposal first on whether it converts one of the dead
stores (favour, craft, fee) into access, price, throughput or risk, before it proposes a new
verification type. A new `Check` subclass is the cheapest work in this codebase and therefore
rarely the highest-value work. See [[campaign-open-questions]], [[campaign-invariants]].
