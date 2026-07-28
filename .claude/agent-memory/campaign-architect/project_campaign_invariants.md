---
name: campaign-invariants
description: Hard constraints any Hand and Seal campaign proposal must satisfy — data-vs-code split, diegetic-only rule, evidence contracts, humour budget, polity cap.
metadata:
  type: project
---

Non-negotiable. A proposal that violates one of these is unusable, not merely weaker.

**Content is data.** New cases, days, letters and books are JSON under `data/`. If a design
needs more than one new `Check` subclass, it is probably the wrong design. Always state plainly
which parts are data and which need code.

**`scripts/rules/` never touches a node, a signal or the scene tree.** That is what keeps the
law runnable headless. `CheckContext` is the only channel into it.

**Diegetic only.** No HUD, menus, floating UI or score screen. Exactly one screen-space element
exists in the whole game and both its captions retire once the player has visited the plane
they describe. Every mechanic must be an object on the desk. A design that needs a panel needs
a piece of paper instead.

**Everything the ledger says was findable must have been renderable on the desk.** Violated
three times historically; every occurrence was treated as critical.

**Absence is never evidence.** The Kalendar's silences must stay worth nothing.

**An anomaly is not a crime.** `case_01` exists to unteach the denying reflex. Nothing may make
suspicion the correct default.

**The question is "which authority am I choosing to satisfy", not "is this correct".**
Verification is the floor, not the ceiling.

**No `is_forged` flag anywhere.** Forgery is derived from the documents.

**Humour is rationed: 6-8 dry beats per working day, never two in one matter.** Flat
declarative, past tense, joke in a subordinate clause, and it must always carry information —
a line still funny with its facts removed is the wrong line. At least three of a day's beats
live inside a book the player must open. FORBIDDEN ABSOLUTELY: every `outcomes[].aftermath`;
anything Adelheid Vesser says or that is said about her; `case_08`'s `hold_to_light` and
`waiting_long` lines; every DENY and REFER reaction; `burnt_out_text`; the ledger's "Heard, not
ruled" and "Not heard" blocks; any `Finding` text in `scripts/rules/`.

**Historical base.** Fictionalised Holy Roman Empire, relatively historically accurate.
Chancery practice, diplomatic, sealing, regnal dating, partible inheritance, ministeriales,
obit rolls are real things and must behave like real things. Invent polities and people, not
procedures. Hard cap 6-9 polities (currently 7); do not add one without saying what it
displaces.

**Why:** these were issued as the framing for the 2026-07-28 campaign-architecture pass and
they encode past incidents (the three findability violations, the humour drift) rather than
taste.

**How to apply:** check every proposal against this list before ranking it. See
[[owner-direction-hook-and-twists]] and [[project-campaign-state]].
