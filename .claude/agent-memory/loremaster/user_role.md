---
name: user-role
description: The user is the designer/director of Hand and Seal — solo-ish Godot project, wants believable-not-accurate medieval legal fiction, works via adversarial subagents
metadata:
  type: user
---

The user is the designer and director of *Hand and Seal*, a Papers-Please-style
document inspection game in Godot 4 / GDScript, set in a fictionalized Holy Roman
Empire. They work across a Mac laptop and a Windows desktop.

What they value, in their own framing:
- **"Believable rather than accurate, the way Papers Please is a believable-not-real
  Cold War border."** Real historical *mechanisms* are the raw material; fidelity
  is not the goal and proper nouns are off-limits.
- **Game feel is the deliverable, not features.** They would rather have two
  documents that feel excellent than eight that feel like UI.
- **Diegetic everything.** The reference books are books on the desk. The desk is
  deliberately too small and digging is a mechanic, not a bug.
- **Learnability over flavour.** They will cut a historically gorgeous idea if it
  produces a puzzle the player cannot reason about in a couple of hours.

How they work: they run a stable of ten subagents in `.claude/agents/`, three of
them deliberately adversarial (`feel-critic`, `rules-auditor`,
`design-prosecutor`), and they explicitly do not want those softened. They brief
in depth, name the candidate ideas they have already considered, and expect to be
told which ones to reject. They ask for ranked recommendations and a plain
build/don't-build call on each item — hedging is not useful to them.
