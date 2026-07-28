---
name: user-role
description: The user is the solo designer-developer of "Hand and Seal", a Godot 4 document-inspection game at C:\HREGAME; works via adversarial review subagents and cares most about diegetic design.
metadata:
  type: user
---

Solo designer-developer of **Hand and Seal** (git user `PatheticPants`), a
document-inspection game set in a fictionalised Holy Roman Empire. Works across a
Mac and a Windows desktop (hence the LF/`.uid` discipline in the repo).

What they value, inferred from the code, the README and the case briefs they write:

- **Diegetic above all.** No HUD, no menu, no button that says Confirm. Every
  design question is answered with an object on a desk. A proposal that would add
  a screen, a checklist or a validated text box is the wrong answer here.
- **The player must be allowed to be wrong with a clear conscience.** Cases are
  written so that a plausible, diligent process still reaches the wrong ruling.
  "A clean, valid, boring claim" is treated as important content.
- **Rules are derived, never stored.** There is deliberately no `is_forged` field
  anywhere in `data/`. Suggesting a boolean that caches a verdict will be rejected.
- **Two independent implementations of the same rules** (`scripts/rules/` in
  GDScript and `tools/verify_content.py`) are kept deliberately unshared, so
  disagreement between them is the bug detector.
- They brief subagents in precise, opinionated prose and expect the constraints in
  the brief to be treated as load-bearing — including "say the case is broken
  rather than shipping it."

See [[case-authoring-traps]] for the practical gotchas when writing content for them.
