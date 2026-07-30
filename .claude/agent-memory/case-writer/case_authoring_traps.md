---
name: case-authoring-traps
description: Non-obvious constraints when authoring data/ content for Hand and Seal - spoiler-safe titles, mandatory portrait_path, day-relative dialogue, sheet text budgets (docket AND letter), no shell, and where canon actually lives.
metadata:
  type: project
---

Things that cost real time to discover while writing and auditing content, none of
which is visible from the case files alone.

**1. A case title is a spoiler surface.** `scripts/presentation/docket_slip.gd`
draws `case_data.title` on the slip in the docket tray, so the player reads every
title *before* choosing a case. A title that names the mechanic ("The Scraped
Year") signposts the puzzle from the tray.
**Why:** every shipped title is place-based instead — "The Plot on Küfergasse",
"The Woodland of Kesselholt".
**How to apply:** name cases after the land or the party, never after the defect.

**2. `portrait_path` cannot be omitted, whatever the fallback figure suggests.**
`PetitionerView` does have an authored fallback, but `ContentLoader._validate()`
raises an error on an empty path *and* `tests/test_presentation.gd` asserts both
that the path resolves and that it ends in `_bust.png` for every case.
**Why:** omitting it looks safe and breaks the presentation test.
**How to apply:** always point at an existing bust in `art/petitioners/` and flag
the face reuse in `_design` and in the report.

**3. This agent context has had no Bash/shell tool.** Observed 2026-07-28, twice
in separate runs: only Read, Write, Edit, Grep, Glob were available, so
`python tools/verify_content.py` could not be executed.
**Why:** the brief asks for the verifier output, and silently skipping it would be
the worst possible failure for a content-correctness tool.
**How to apply:** check for a shell first. If there is none, hand-simulate
`adjudicate()` in `tools/verify_content.py` finding-by-finding (erasure, seal,
date, necrology, authority, in that order), cross-check against the matching
`scripts/rules/*.gd`, and state plainly in the report that the verifier was not
executed. Do not present a hand-derived findings list as verifier output.

**4. NEVER write a day-relative time reference into dialogue ("this morning",
"on Tuesday").** A day slot with `requires_ruled` falls back to the *unruled*
predecessor case, so any case can be heard on a later day than its author
assumed, and `DialogueLine.matches()` only consults `Register.find()`, which has
no notion of which day the prior ruling happened on.
**Why:** burning out the candle mid-Tuesday pushes an unheard matter into
Thursday's tray; conditional lines then narrate the wrong day. A case with NO
`requires_ruled` gate of its own (case_04) is the worst offender, because its
predecessor may be ruled minutes earlier on the same day.
**How to apply:** write "already", "earlier", "in this office" — never a weekday
and never "this morning". Check both directions: can this case slip later, and
can the case it cites slip later?

**5. Sheets flow text downward and NOTHING clips it. This applies to letters as
well as dockets.** `DocketView` flows title/name/style/claim_summary/received_note
and then pins `doorkeeper_note` with `maxf(...)` only — no `minf` clamp to the
foot, and `Sheet` does not clip, so overrun is painted onto the desk. `LetterView`
is the same shape: label, title, sender, recipient, body, closing, all flowing,
with the endorsement wax circles drawn at a FIXED `r.end.y - MARGIN - 22`, so a
long body runs straight through them. Shipped `claim_summary` values sit at
100-180 characters; shipped letter bodies at ~330 characters in a 360x455 sheet.
`tests/test_presentation.gd` measures this ONLY for `Lore.data.desk_note`.
**Why:** the same overrun already destroyed the desk memorandum once, which is
why that sheet is 400x585 and has a `_geometry_note`.
**How to apply:** keep `claim_summary` under ~180 characters and a letter `body`
under ~350 at 360x455, or say the sheet needs to grow. Ask for a capture frame
before believing any new sheet fits.

**6. `docs/lore/` DOES NOT EXIST**, though briefs keep instructing you to read it.
Canon lives in `data/world/world.json` (reigns, polities, the desk memorandum),
`data/world/necrology.json`, `data/world/matrices.json`,
`data/world/register_seed.json` (the predecessor R.V.), `data/world/books/*.json`,
and `docs/CONTINUITY.md` for the conventions.
**How to apply:** do not report a missing-canon blocker; read those files instead.

**7. `DayData.opening_documents` is a full, mostly unused authoring surface.**
It accepts any document `kind` the loader knows — `letter`, `docket` AND
`charter` — and `Desk._make_document_view` builds a real view for each. A charter
laid as a day document renders its body, its erasures and its backlit nap
normally, but it gets NO `SealTag` (that code lives only in `lay_out_packet`) and
it cannot be sealed (`PressController.target_sheet` is bound only to the case
charter). `ContentLoader._validate` only walks `lore.cases`, so day documents are
not validated for known emperor/polity.
**How to apply:** a returned, recalled or exemplified instrument can be put on the
desk as pure evidence with zero code. Set `takes_seal: false` explicitly, keep the
`size` identical to the original if you want its `erasures` (which are fractions
of the sheet's own size) to land in the same place, and explain the missing wax
in prose because there is no way to render a detached seal or a cancellation slash.

**8. A PACKET IS ONE CHARTER. The engine disagrees with itself about which one.**
`CheckContext.charter()` (scripts/rules/check_context.gd:40-45) returns the FIRST
`CharterData` in `documents`, and every one of the six checks opens with
`var ch := ctx.charter()`. `Desk.lay_out_packet` (scripts/presentation/desk.gd:429-430)
assigns `current_charter` inside the loop, so it holds the LAST one — and
`current_charter` is what gets the only `SealTag`, the only pourable wax
(`press.reset_for_new_case`), and the only `hold_to_light` beat.
**Why:** author two charters in one packet and the office adjudicates one sheet
while the player can only seal and backlight the other. Silent, and it looks fine.
**How to apply:** exactly one `CharterData` per case. A second instrument goes in
as a `letter`/`docket`, or as a day document (see 7). Corollaries worth knowing:
only ONE pendant seal is ever built (`ch.seal`, singular); `_make_document_view` is
typed `-> Sheet` so nothing that is not a sheet can arrive in a packet; and
`lay_out_day_documents` never calls `_refresh_lens_subjects()`, so a dawn document
implementing `has_detail` is not magnifiable until the player picks anything up
(`deliver_day_document` is fine — it calls `bring_to_front`).

Related: [[user-role]], [[owner-loop-direction]], [[matter-shape-redesign]].
