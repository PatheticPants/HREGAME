---
name: feedback-brainstorm-format
description: How the user wants loremaster brainstorms delivered — ranked, with build/don't-build calls, contradictions at the top, rejections stated explicitly
metadata:
  type: feedback
---

Deliver brainstorms as a ranked report with a plain build-or-not call on every
item, and put consistency contradictions at the very top of the response.

**Why:** the user briefs with a list of candidate ideas they have already thought
of and asks which to *reject*. They stated the constraint directly: reject your
own ideas when they are historically flavorful but produce puzzles the player
cannot reason about. A brainstorm that returns only enthusiasm gives them nothing
to cut, and they have an adversarial subagent stable precisely because they want
disagreement rather than agreement.

**How to apply:**
- Lead with the answer. Contradictions against canon go at the top, naming the
  conflicting facts and the file each lives in — never buried at the end.
- Per idea, four things in this order: historical root, player-facing verb, what
  the engine would need, build-it-or-not. Keep each to a few sentences.
- Name the ideas you are *rejecting* and say why, especially ones the user
  suggested. That is the most useful part of the reply.
- End with a ranked top five.
- Ground "what the engine would need" in the actual scripts, not in guesses —
  the user's continuity doc says not to trust any summary of the codebase over
  the files, including its own.
- Do not write report/summary `.md` files unless asked. The report is the reply.
