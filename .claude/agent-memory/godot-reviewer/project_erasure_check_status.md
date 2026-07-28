---
name: project-erasure-check-status
description: RESOLVED as of commit 01588ea (2026-07-28) — ErasureCheck/Rasura now has shipped case content (case_08) and test_rules.gd coverage. Previously flagged as content/test gap; do not re-flag without new evidence.
metadata:
  type: project
---

Updated 2026-07-28. Previously (as of `af5dd24`) `ErasureCheck` shipped with no
case content and no test coverage — see the old version of this note. As of
`01588ea` that gap is closed:

- `data/cases/case_08_mill_on_the_aue.json` uses an `erasures` array and drives
  a DENY verdict via `erasure_dispositive` (confirmed via
  `python tools/verify_content.py` output: "PASS case_08_mill_on_the_aue ...
  fatal:erasure_dispositive, note:erasure_innocent").
- `tests/test_rules.gd` has `_test_erasures()` (line ~294) exercising a clean
  packet, a forged one, an honestly-tidied one, and an illegible one.

**Why:** This was tracked because the project's own doctrine ("every new Check
must be written twice", "everything the ledger says findable must be
renderable") was being violated in spirit. That is no longer the case.

**How to apply:** Do not re-raise "ErasureCheck has no content/tests" as a
finding unless you've re-checked `data/cases/*.json` and `tests/test_rules.gd`
and found the coverage has regressed. See [[project-zindex-latent-cases]] for
an unrelated but similarly-shaped issue found in the same session this was
closed out.
