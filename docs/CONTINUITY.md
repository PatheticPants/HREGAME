# Continuity note

For whoever picks this up next — a fresh session, or a returning one.

Read `README.md` first for how the game works and `docs/HANDOFF_CODEX.md` for the
design rationale. This file is only the things that are **not inferable from the
code** and the traps that have already cost time.

---

## Verified state

All green as of this note. Run these before changing anything, so you know
whether a failure is yours:

```bash
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --script tests/test_rules.gd
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --fixed-fps 60 --scene res://tests/test_presentation.tscn
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --fixed-fps 60 --scene res://tests/test_session.tscn
python tools/verify_content.py
```

| suite | checks |
|---|---|
| rules | 64 |
| presentation | 138 |
| the day (full loop) | 66 |
| content + encoding | 7 cases PASS, 87 files |

77 `.gd` files, 7 cases, 10 subagents in `.claude/agents/`.

**Not a git repository.** There is no restore point. Initialising one is the
single highest-value housekeeping act available:

```bash
git init && git add -A && git commit -m "Hand and Seal: vertical slice"
```

---

## Traps that have already cost time

**Never rewrite a source file with PowerShell `Set-Content` / `-replace`.** It
round-trips through cp1252 and silently mangles every non-ASCII character — seven
em dashes in `candle.gd` became `â€"` and the file still ran. Use the editor
tooling. `tools/verify_content.py` now checks 87 text files for this on every run;
it also catches BOMs and CRLF.

**A new `class_name` is invisible until the class cache is rebuilt.** Adding a
script with `class_name` from the CLI breaks every file that references it until:

```bash
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --editor --quit
```

**Dialogue only advances on a click.** `petitioner.on_click()`. Any automation
that doesn't click will hang forever waiting for `Stage.SPEAKING` to end.

**Most tests deliberately freeze the session.** `test_presentation` calls
`desk.set_process(false)` and `session.set_process(false)` so it can pose the desk
and drive the press by hand. If you drive the press manually *without* freezing
the desk, the desk ticks it every frame with an empty hand and silently aborts the
descent. `test_session.tscn` is the only suite that runs the real loop.

**Coordinate spaces.** Props live in `desk.surface`, inside `work_plane`, inside
`desk` (positioned at 960,640). Mixing global and parent-local is the most common
mistake here — use `desk.surface.to_local(...)`.

**Lights need a real window.** Godot cannot render 2D lights with the dummy
driver, so `tests/qa_capture.tscn` is deliberately not headless. Screenshots land
in `.tools/shot_*.png` (gitignored).

**`String.capitalize()` title-cases every word and splits snake_case.** Use
`Lex.sentence()` for prose.

---

## Conventions that are decisions, not habits

- `scripts/rules/` never touches a node, a signal or the scene tree. This is what
  lets the rules run headless. Do not relax it.
- No `is_forged` flag anywhere in the data. Forgery is derived.
- Content is JSON under `data/`; tuning is `.tres` (live-editable while running).
- Soundness, Favour and Craft are three columns and are never combined.
- Everything the ledger says was findable must have been renderable on the desk.
  This has been violated twice and both were treated as critical.
- One screen-space element exists in the whole game (`view_hint.gd`), and it
  permanently retires itself after first use.

---

## The subagents

Ten, in `.claude/agents/`. **They load at session start** — a newly added one is
not callable until the next session.

| | |
|---|---|
| `loremaster` | canon, persistent memory, hard cap 6–9 polities |
| `case-writer` | cases as data; must state the decisive fact and the path to it |
| `feel-critic` | read-only; phases, easing, weight, variance, audio hooks |
| `godot-reviewer` | read-only; cross-platform safety first |
| `rules-auditor` | read-only; hunts second solutions |
| `campaign-architect` | multi-day consequence, precedent, faction pressure |
| `design-prosecutor` | adversarial: is this a game or beautiful craft over a thin loop |
| `difficulty-curator` | teaching order and difficulty curve |
| `player-advocate` | cold first-time-player walkthroughs |
| `sound-director` | sonic language, feedback hierarchy |

They are the main lever for a large task: each one starts with a cold context, so
the heavy reading happens in *their* window rather than the main one. Use them
before the main context fills, not after.

`feel-critic`, `rules-auditor` and `design-prosecutor` are deliberately
adversarial. Do not soften their prompts — their value is that they disagree.

---

## If you are a fresh session

Do not trust any summary of the codebase, including this one, over the files. The
project has roughly doubled in content twice now, and each time the previous
session's mental model went stale in ways that were not obvious. Read the actual
files for anything you intend to change.
