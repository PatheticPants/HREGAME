---
name: canon-open-questions
description: NOT CANON — unresolved Hand and Seal lore gaps and near-contradictions. Never promote one of these to canon without being told to.
metadata:
  type: project
---

**These are open questions, not facts.** Never cite one as canon. Never promote
one without explicit instruction from the user.

Recorded 2026-07-28 after a full read of `data/` and `scripts/rules/`.

1. **Seven electors vs. seven polities.** `world.json` gives Aachen-Verd the
   succession "Elective. Seven electors." There are exactly seven polities
   *including* Aachen-Verd, so either the Crown votes for itself or the elector
   roll is not the polity roll. The campaign builds toward a contested election;
   this must be settled before any election content is written. Proposed but not
   adopted: the roll mixes prelates and lay princes, some of whom are offices
   inside polities rather than the polities themselves.

2. **No Margrave of Thurn since 1211.** Dietrich's second die was broken at his
   death in 1211. Thurn is male primogeniture, so a son succeeded — but no
   successor is named anywhere and no post-1211 Thurn die exists in
   `matrices.json`. For ten years of game-present history Thurn cannot seal.

3. **Coronation dating is coded but unusable.** `Lex.Dating.CORONATION` works in
   `RegnalMath`, and the Almanac warns it is "a trap for a clerk who has learnt
   only two of the three" — but no reign earlier than Otbert II exists, so no
   instrument can legitimately use it. The Almanac promises a trap the content
   cannot deliver. A fourth, pre-Otbert reign would fix it (a reign is not a
   polity; no cap implication).

4. **Two fires in 1218.** The lower town at Grellwater, and the archive at Lenz.
   Different places, same year. Players will assume they are one event. Decide
   whether to unify them.

5. **Witness deaths live on the parchment.** `DateCheck._witness_findings` reads
   `died_*` from the charter's own witness entry, so Eckhard von Melle carries a
   death record in `case_02` and none in `case_04`. A forger who omits the
   annotation defeats the check. A world-level necrology would close this.

6. **Polity headroom.** 7 of 9 used. Two slots remain and should stay unspent
   unless a proposal genuinely cannot be served by an existing polity.
