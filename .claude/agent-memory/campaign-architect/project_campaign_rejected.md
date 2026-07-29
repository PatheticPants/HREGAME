---
name: campaign-rejected-structures
description: Campaign structures considered for Hand and Seal and rejected, with the file or fact that kills each one — so they are not re-proposed.
metadata:
  type: project
---

Rejected, with the reason. Re-proposing one of these without addressing the reason wastes a
session.

**Gating the rules layer per day (a `CheckContext.sources` set that makes checks return nothing
when their book is absent).** Rejected 2026-07-29. It makes the same packet produce different
findings on different days, which breaks `CaseData.correct_verdict` verification outright:
`SessionController._verify_content()` and `tests/test_rules.gd` both adjudicate every case with
no day context, and `Adjudicator.adjudicate_case` sets `ctx.necrology` unconditionally. The
findability contract is a CONTENT contract and belongs in the verifiers, not in six `Check`
subclasses. **Corollary:** if a book is withheld from a day, no case reachable on that day may
be authored to depend on it — enforced statically, never at runtime.

**A `teaches_case` / `taught_by` key naming which case introduces a system.** Rejected
2026-07-29. It is a second hand-maintained assertion about the same relationship and it rots the
moment a `Check` changes meaning. The relationship is derivable: the first case in day order
whose findings require an instrument is the case that teaches it. Derive and print it; do not
store it.

**Blank pages in an issued-but-unwritten reference book.** Rejected 2026-07-29. The Chancery does
not bind blank books, it costs a `BookData` filter path, and it is a lie the player catches by
turning a page. Absent means not on the desk; the empty pigeonhole is the state.

**A mid-day doorkeeper hand-off of a reference book.** Rejected 2026-07-29 on cost, not taste:
`Desk._make_document_view` builds only Sheet subclasses, so a book arriving through
`deliver_day_document()` is new code. Dawn delivery into the rack plus a slip on the blotter is
free and uses the shipped `opening_documents` channel.

**Banding IMPERIAL favour.** Rejected earlier (the prosecutors' amendment in
`docs/NEXT_SESSION.md`): in three of eight matters the imperial delta is exactly +1 for the
lawful verdict and -1 for the unlawful one, so banding it hands the player a competence score in
costume — the one thing the three-column rule exists to prevent.

**How to apply:** check any new proposal against this list first. See
[[project-campaign-state]], [[campaign-invariants]], [[campaign-open-questions]].
