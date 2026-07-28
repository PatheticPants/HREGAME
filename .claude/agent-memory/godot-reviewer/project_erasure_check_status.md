---
name: project-erasure-check-status
description: As of commit af5dd24 (2026-07-28), ErasureCheck/Rasura ships with no case content using "erasures" and no test_rules.gd/test_presentation.gd coverage — check whether this got closed in later commits before re-flagging.
metadata:
  type: project
---

`af5dd24` ("Rasura: a fourth investigative verb...") added `scripts/model/erasure.gd`,
`scripts/rules/erasure_check.gd` (runs FIRST, ahead of SealCheck — decisive
over it), `Sheet._draw_erasures`/backlight rendering, and a Python mirror in
`tools/verify_content.py`. At that commit:

- No file under `data/cases/*.json` contains an `"erasures"` array — the
  mechanic cannot be encountered by a player in the shipped two-day campaign.
- Neither `tests/test_rules.gd` nor `tests/test_presentation.gd` exercises
  `ErasureCheck` (no `_test_erasures`-style function, unlike `_test_witnesses`
  which was added alongside the Kalendar in the prior commit `7c5ecb0`).
- `docs/CONTINUITY.md:130` claims "Checks that fire on shipped content:
  `ErasureCheck`, SealCheck, ..." — false at this commit for ErasureCheck.

Uncommitted work-in-progress observed during the review (not part of
`af5dd24`) was already adding an erasure to the practice leaf in
`data/world/world.json` and a `qa_capture.gd` screenshot beat for it — so this
may already be in flight. `qa_capture.gd` is screenshot-only and does not
count as pass/fail coverage; a `_test_erasures` in `test_rules.gd` is still
the missing piece even if content gets wired up.

**Why:** The project's own stated doctrine (`docs/CONTINUITY.md`) is "every
new Check must be written twice" and "everything the ledger says was findable
must have been renderable on the desk" — a check with zero content and zero
test coverage violates the spirit of both without technically breaking either
rule as literally stated.

**How to apply:** On the next review touching `scripts/rules/erasure_check.gd`
or `data/cases/`, check whether a case now uses `erasures` and whether
`test_rules.gd` has erasure assertions before re-raising this finding.
