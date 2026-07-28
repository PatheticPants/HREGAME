---
name: case-authoring-traps
description: Non-obvious constraints when authoring data/cases/*.json for Hand and Seal - spoiler-safe titles, mandatory portrait_path, and no shell to run the verifier.
metadata:
  type: project
---

Three things that cost real time to discover while writing `case_08_mill_on_the_aue`,
none of which is visible from the case files alone.

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

Related: [[user-role]].
