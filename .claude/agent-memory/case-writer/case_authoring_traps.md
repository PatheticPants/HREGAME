---
name: case-authoring-traps
description: Non-obvious constraints when authoring data/cases/*.json for Hand and Seal - spoiler-safe titles, mandatory portrait_path, day-relative dialogue, docket text budget, and no shell to run the verifier.
metadata:
  type: project
---

Things that cost real time to discover while writing and auditing cases, none of
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

**3. This agent context has had no Bash/shell tool.** Observed 2026-07-28: only
Read, Write, Edit, Grep, Glob were available, so `python tools/verify_content.py`
could not be executed.
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

**5. A docket slip is 330x235 and has a hard text budget.** `DocketView` flows
title/name/style/claim_summary/received_note downward and then pins
`doorkeeper_note` with `maxf(...)` only — there is no `minf` clamp to the foot,
and `Sheet` does not clip, so overrun is painted onto the desk. Shipped
`claim_summary` values sit at 100-180 characters; 300 pushes the footer off the
parchment. `tests/test_presentation.gd` measures this ONLY for
`Lore.data.desk_note`, not for case dockets.
**Why:** the same overrun already destroyed the desk memorandum once, which is
why that sheet is 400x585 and has a `_geometry_note`.
**How to apply:** keep `claim_summary` under ~180 characters, or say the docket
needs to grow. Office knowledge that a puzzle depends on does not belong in a
sentence that may not render.

Related: [[user-role]].
