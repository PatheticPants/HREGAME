---
name: feedback-review-style
description: How the Hand and Seal owner wants design review delivered — engineer-facing, ranked by value-per-hour, unsoftened, file:line specific.
metadata:
  type: feedback
---

Deliver design output as an implementation brief, not prose for a reader. Name files and line
numbers. Say what to change, never "consider". Rank by value-per-hour of implementation. Do
not soften criticism. State which single item you would build first and why.

**Why:** the output is consumed directly by an implementing engineer. The owner also keeps two
deliberately adversarial review agents (`feel-critic`, `rules-auditor`) and says their value is
that they disagree with him — hedged review is worthless to him.

**How to apply:** on every proposal or review. Two specific gradings he asked for:
a new case type alone is LOW value; anything that changes the shape of a day, or gives the
player something to want or something to lose, is HIGH. Also: "what does the player physically
DO at the desk that they cannot do now" is the first question every idea must answer, because
the game has no menus and every mechanic must be an object on a desk.

Related: [[reference-stale-docs]], [[project-campaign-state]].
