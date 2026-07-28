---
name: project-concurrent-agents
description: C:\HREGAME is a live repo worked on by multiple agent sessions (case-writer, feel-critic, etc.) concurrently with review sessions — the working tree can change under you mid-review.
metadata:
  type: project
---

During a review on 2026-07-28, `git worktree add` + `git stash -u` (used to diff
pre-batch vs current behavior) revealed that HEAD and the working tree were
changing while the review was in progress: uncommitted WIP appeared (a new
`case_08_mill_on_the_aue.json`, an erasure added to the practice leaf in
`data/world/world.json`, `tests/qa_capture.gd` additions) and HEAD advanced
through at least two further commits (`d41c677`, `095b2a4`, `47b6dca`) between
the start of the review and its end, none of which were in the reviewed set.

**Why:** `docs/CONTINUITY.md` documents ten subagents including `case-writer`
and `feel-critic` that run in the same working directory. This is a shared,
actively-mutating checkout, not a static snapshot — likely several agent
sessions running against the same `C:\HREGAME` concurrently.

**How to apply:** Do the actual code reading for a review as one contiguous
pass and treat that as the reviewed snapshot; don't assume `git log`/`git
status` run later in the same session still describe the same state. Avoid
`git stash` on the shared working tree at all — if a pre/post comparison is
needed, use `git worktree add <fresh-dir> <commit>` only (it does not touch
the primary worktree or require stashing). Always `git worktree remove` when
done. If uncommitted changes are ever stashed by mistake, `git stash pop`
immediately before doing anything else. Don't chase a moving target: findings
should cite the commits/files actually read, not re-verify against whatever
HEAD has become by the time the review is written up.
