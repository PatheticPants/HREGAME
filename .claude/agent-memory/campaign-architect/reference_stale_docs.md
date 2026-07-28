---
name: reference-stale-docs
description: Which Hand and Seal docs are stale and cannot be trusted for orientation; read source instead.
metadata:
  type: reference
---

`docs/CONTINUITY.md` and `docs/HANDOFF_CODEX.md` are stale. `README.md` is partly stale — it
still says "Vertical slice: one day, three petitioners", "no fourth case", and "Not yet a git
repository". None of those are true: it is a git repo, and there are 7 cases across 2 days.

Trustworthy for orientation: `docs/CAMPAIGN_IMPLEMENTATION.md` (describes the two-day build as
shipped), `data/days/_order.json`, and the source itself.

Authoritative for current state: `data/`, `scripts/`, and `git log`.

**How to apply:** use docs for intent and vocabulary only; verify every factual claim about
scope, counts or capabilities against `data/` and `scripts/` before building on it.
