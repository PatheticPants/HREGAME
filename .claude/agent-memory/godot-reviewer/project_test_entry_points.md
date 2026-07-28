---
name: project-test-entry-points
description: Where Hand and Seal's three headless/windowed test suites live and how they're invoked, plus the portable Godot binary location.
metadata:
  type: reference
---

Portable Godot binary used for review verification (workspace-local, gitignored):
`C:\HREGAME\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe`

Three test entry points, each a separate scene/script under `tests/`:
- `tests/test_rules.gd` — pure rules-layer test, run as a `SceneTree` script via
  `--headless --script tests/test_rules.gd`. Never touches nodes/autoloads.
- `tests/test_presentation.gd` / `tests/test_presentation.tscn` — headless
  integration smoke test of the real desk scene (drag physics, press sequence,
  candle light, tablet). Run with `--headless --fixed-fps 60 --scene res://tests/test_presentation.tscn`.
- `tests/test_session.gd` / `tests/test_session.tscn` — full-day integration test
  driven through the real `SessionController` (the other two deliberately freeze
  it). Covers both a normal full day and a candle-drowns-mid-day cutoff. Run with
  `--headless --fixed-fps 60 --scene res://tests/test_session.tscn`.
- `tests/qa_capture.gd` / `tests/qa_capture.tscn` — NOT headless (2D lights need a
  real renderer); captures PNG screenshots to `res://.tools/` (gitignored) for
  visual QA. Not a pass/fail test.

There is also `tools/verify_content.py` — a second, independent implementation of
the rules logic (deliberately not sharing code with scripts/rules/) that validates
data/ content and cross-checks authored `correct_verdict` against derived verdicts,
plus the cross-platform encoding checks (see [[project-cross-platform-safeguards]]).

**How to apply:** When asked to confirm a suggested fix doesn't break anything,
these are the four things to run/check, in order of speed: verify_content.py,
test_rules.gd, test_presentation.tscn, test_session.tscn.
