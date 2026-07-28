---
name: project-campaign-state
description: Hand and Seal — what persists across days today, which persistence channels exist, and which stored state is inert (as of 2026-07-28).
metadata:
  type: project
---

As of 2026-07-28 the campaign is 7 cases across 2 authored days (`data/days/day_01.json`,
`day_02.json`), one `Register` carried in `SessionController`, no save system.

**Three working Register-to-play channels exist.** These are the whole campaign machinery today:
1. `PrecedentCheck` (rules layer) — reads `ctx.register` by `subject_id` / `claimant_id`.
2. `DialogueLine.requires_case` / `requires_verdict` — petitioners quote your ruling back.
3. `DayOpeningDocument.matches(register)` and `DayCaseSlot.resolve(...)` — conditional
   morning letters and conditional/fallback docket slots.

**Favour is stored and inert.** `CaseOutcome.favor` -> `RulingRecord.favor` -> one prose
sentence in `SessionController._ledger_summary()`. `Register.favor_totals()` is written and
never called. Nothing in the game reads favour to change access, price, risk or availability.
This is the single largest violation of "state must return as play" in the build.

**Craft is also inert beyond the ledger line.** `ImpressionRecord` is stored per ruling and
never consulted again.

**The economy exists only as a planted seam**, not as code: `data/world/register_seed.json`
has R.V.'s entry "Fee for the writing, two marks, received of the party." There is no purse,
no coin object, no tariff.

**Why:** the vertical slice deliberately shipped the columns without their consequences; the
README's "Not built, on purpose" section says the economy and remaining verification types
have "a place in the schema and nothing more."

**How to apply:** any campaign proposal should be judged first on whether it converts one of
these dead stores (favour, craft, fee) into access/price/risk, before it proposes a new
verification type. Adding a Check subclass is the cheapest new work in this codebase and is
therefore rarely the highest-value work. See [[project-campaign-open-questions]].
