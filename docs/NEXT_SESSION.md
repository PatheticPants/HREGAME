# Brief for the next session

You are picking up **Hand and Seal**, a Papers-Please-style document-inspection
game in Godot 4 / GDScript at `C:\HREGAME`, set in a fictionalised Holy Roman
Empire. You are a low-born notary of the Imperial Chancery; petitioners bring
claims to land and title; you verify charters, wax seals, witness lists and
regnal dates against a body of law, then rule in wax with a signet ring. One
carried candle is the only light in the room and the day's clock.

**Newest first: `docs/CODEX_IMPLEMENTATION_AND_REVIEW_HANDOFF.md` opens with the
2026-07-29 review of the Codex optics pass.** Six defects were fixed there and
three things were investigated and rejected; the rejections are worth as much as
the fixes, because two of them are time sinks that look like real bugs.

Read in this order:

1. **`docs/GRAPHICS.md`** — the standing rules for how this game is allowed to
   look and how to work on it. This session's work is mostly graphics, so this is
   the rulebook.
2. **`docs/CONTINUITY.md`** — the traps that have already cost time and the
   conventions that are decisions rather than habits.
3. **`README.md`** — how the game actually plays.
4. This file — the plan.

Do not trust any of them over the actual files. Every one has been caught lying
in the last two sessions, including about whether the project was a git
repository.

---

## Run this before you touch anything

```bash
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --script tests/test_rules.gd
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --fixed-fps 60 --scene res://tests/test_presentation.tscn
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --fixed-fps 60 --scene res://tests/test_session.tscn
python tools/verify_content.py
```

Green is **rules 96, presentation 340, session 90, content PASS**. Run the rules
suite before the Python one: it writes `.tools/derived_findings.json`, and the
Python compares every finding against it rather than only the final verdict.

And there is a fifth now, which is the only one that plays the game. Not
headless, for the same reason the capture harness is not:

```bash
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --path . --resolution 1600x900 --fixed-fps 60 --scene res://tests/play_day.tscn --session-log=.tools/play.jsonl --dwell=8
```

**Re-run it after anything that touches pacing, the desk layout, or the press.**
It reports candle remaining at the start of the last matter; `--dwell` is the
seconds of reading a machine cannot supply, and `--dwell=0` prices the
mechanical floor alone.

Then capture, and **open the frames**:

```bash
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --path . --resolution 1600x900 --scene res://tests/qa_capture.tscn
```

Adding a `class_name` breaks every file that references it until the class cache
is rebuilt (`--headless --path . --editor --quit`), and the error you get is a
parse error in an *unrelated* file. You will hit this. It is in CONTINUITY.

---

## THE 2026-07-29 PLAYTHROUGH SESSION — READ THIS BEFORE ANYTHING BELOW IT

Everything under "THE 2026-07-29 PLAN" further down was the plan. This is what
happened to it. Green is now **rules 96, presentation 340, session 90, content
PASS**.

### The number, and it changes the argument

**Somebody finally played it.** `tests/play_day.tscn` drives both days end to end
through the real input path — `Input.warp_mouse` plus a synthesised button event,
so `Desk._input -> _begin_press -> _pick -> Draggable.grab` runs as it does under
a hand. It melts, pours, presses and peels through `PressController`'s own state
machine, opens the books, puts the glass on the seal and the closing formula,
holds the parchment to the flame, and carries a docket into the hearing notch.

`--session-log` writes one JSONL line per action carrying **two** clocks: wall
time, which always advances, and candle-seconds, which advance only while the
player is deliberating. The gap between them is the answer to every pacing
question, and nothing here could tell them apart before.

| | mechanical floor | competent (`--dwell=8`) |
|---|---|---|
| one matter | ~22 s | ~85 s |
| **Tuesday: candle at the last matter** | **94.6%** | **78.8%** |
| **Thursday: candle at the last matter** | **89.5%** | **50.0%** |

**THE CLOCK IS NOT DECORATION, AND IT IS NOT FELT ON TUESDAY EITHER. It is
back-loaded.** Tuesday costs 28% of its candle at a competent pace. The same
work costs 67% of Thursday, which is short both because it is authored at 720
and because it is scaled by what Tuesday left. Tuesday buys Thursday — which is
exactly what "the office issues a candle, not a candle a day" claims, so the
mechanism works and only the *timing* of the pressure is not what the brief
assumed.

The reference books are **not** a trap: opening all four every matter, including
fetching two out of the rack, fits inside the 22 s floor. The seal ritual is
about 5 s of it; half the floor is carrying things around the desk.

### What that means for phase B, which was conditional on this number

**Phase B (favour as a supply line) is NOT built, and the condition is why.** It
was gated on the day being genuinely tight. It is tight on Thursday and loose on
Tuesday, so the lever the brief names — a shorter issued candle — would compound
on the day that already bites and do nothing to the day that is decoration.
Building it now means building against a premise the measurement half-refuted.

**The honest next move is Tuesday's `day_seconds`, not a new system.** 1200 s
against 341 s of competent work is 3.5x headroom. But note before touching it:
that headroom is what produces a carry of ~0.72, sitting nicely inside
`[0.45, 1.0]`, so Tuesday is well tuned *for the carry mechanic* and badly tuned
*for tension on the day*. Those pull opposite ways and the choice between them
is a design decision, not a bug fix. **Re-measure with `play_day` after any
change to it** — that is what the harness is for.

### Also done

- **Half the memorandum was under the Almanac.** `_build_desk_note()` ran before
  the books and draw order is child order, so 255 units of it were hidden at
  dawn — including the seal instruction, "there is no second impression", the
  candle rule, and the whole CONFIRM/DENY/REFER footer. Found by opening
  shot_19. Fixed by child order. The note is now nine sentences; four moved onto
  delivered leaves, four were retired to books that already carry them.
- **Tuesday's false witness rule is fixed** — one obit, no verdict change.
- **Saturday exists**, gated so it is offered only when the week left somebody
  in the passage. `requires_unruled` landed with its loader line, both validator
  rows and its `verify_content.py` entry in one commit, and `verify_content.py`
  now rejects **any** slot key the loader does not parse.

### Do not redo these

- The full week re-sequencing (case_04 to Tuesday, Thursday down to two matters)
  was designed and **rejected**: every docket names its day in player-visible
  `received_note` prose and three of case_06's arrival lines open "On Tuesday
  you admitted". Six cases' shipped prose to move one matter.
- `data/world/curriculum.json`, still rejected, still for the same reason.

---

## What the owner wants

Verbatim, across three sessions:

> Improved animations and perspective shifts. Better stylized realism in almost
> every part of the game. Materials, lighting, depth, weight. Pixel-art anchored,
> not photoreal.

> I want this to be a very atmospheric game. The night time vibe is very nice.
> Continue to expand upon this and create a truly immersive experience.

> **I really want graphics, lighting, and animations to be improved upon.**

Plus: sparse, subtle humour (budgeted and documented — read the rule in
CONTINUITY before adding one line), and vigilance about the loop becoming
repetitive.

**They notice detail, and both bugs they have reported personally were real,
invisible to the test suite, and things a previous session had looked at and
passed over.** Assume anything they mention is real, and reproduce it in a
capture before theorising.

---

## WHERE THE LAST SESSION GOT TO (2026-07-28)

**Phases 0, 1 and 5 are done. The 2026-07-28 return pass also completed the
largest remaining Phase 2 visual targets.** What follows the status includes
historical reasoning; read this status first or you will redo work.

| | |
|---|---|
| **Phase 0** | Historical exact stress pose: **9.22 ms, 108 fps**, 19 draggables, four open books, 3 outline builds. Repeated current capture-harness runs measure **6.45–6.73 ms, 149–155 fps**, 17 live draggables, four open books, and 10 cached outlines. Both are below the 10 ms intervention line; preserve the scenario when comparing. `seal_tag` surface randomness is now generated once and cached. |
| **Phase 1** | Done. `scripts/presentation/surface.gd`. **Named `Surface`, not `Material` — `Material` is a Godot built-in and `class_name Material` does not compile.** Shipped with nothing migrated and no pixels changed, as the plan asked. |
| **Phase 2** | The candle, wax pool and spoon, seal veil, brass response, Ledger arrival, page turn and blind tooling, magnifier, desk ledge, packet sweep, and view transition have all received implemented and rendered passes. |
| **Phase 4** | The door takes the candle; cold morning has directional shutter geometry, band-limited dust, and cold material reflection; the near foreground desk fascia is implemented. The acoustic bed remains open. |
| **Bugs** | A second cold sweep found 21 candidates; 6 were refuted and **15 were reproduced and fixed** across six commits. See the log from "Two books were printing off the edge of their own boards" onward. |
| **Phase 5** | Decided and done. See the commit "Phase 5: the Kalendar convicts one man". |

**Three things the last session found that the plan did not predict**, all of
which are the same shape — a defect invisible in code review and obvious once
something was measured:

1. **The candle's flame had been drawn upside down since it was written.**
   `atan2(lean.x, -8.0)`; a negative second argument returns an angle near pi.
   Tip in the wax, blue base at the top, in every frame, for the life of the
   project — through four rounds of judging that exact object from captures.
2. **"Molten is darker than set" was recorded as fixed and was only fixed on the
   candle.** The pool and the spoon still had it inverted.
3. **The struck seal never took the shade veil**, because `WaxPool` is a *child*
   of the sheet and children draw after their parent — so the sheet's veil went
   down and the wax drew over it.

**Where the plan was wrong, for the record.** The Phase 1 class name does not
compile. The Phase 5 "obvious fix" — convert an existing witness on case_04 —
does not survive the data: one of the two has no house by design, the other is
shared with case_02 and moving him damages a shipped case. And `docs/GRAPHICS.md`
was telling every session to avoid `ease(x, 0.4)` for a reason that is false;
measured, it covers 4% of the distance in the first frame rather than snapping.
All three are corrected in place.

## THE 2026-07-29 PLAN — READ THIS INSTEAD OF THE OLDER PHASE LIST

The older phase list below is done or superseded. This is the current plan, and
it opens with an argument you should be willing to disagree with.

### Stop doing graphics. The machine is finished; the campaign is deliberately unwritten.

Three consecutive sessions have gone into materials, lighting, optics and depth,
and the result is genuinely good — the candle now governs what can be *read*, the
wax is wax, the glass is an instrument. None of that was wasted.

But look at the ratio. **Five checks, four physical reference books, a necrology
of thirty-odd obits, a precedent engine, dynamic consequence cases, an authority
split, three judgement columns — against eight matters across two days.** The
systems could carry forty cases. There are eight.

**That is a decision, not a gap — see the amendment below before drawing the
obvious conclusion.** Content authored against systems that are still moving has
to be re-authored, and prose is the one thing here that cannot be regenerated. An
earlier draft of this section read the ratio as neglect. It is a refusal to spend
writing on mechanics that might not survive, which is correct.

And the thing that should worry us most: **nobody has played it.** Everything any
session knows about whether this loop is *fun* comes from reading source and
looking at still frames. Three visual passes have been spent on a loop whose
central question — does verifying a charter under time pressure feel good the
fifth time — has never once been tested by a human being playing to the end.

The presentation suite is at 316 checks for eight cases. That is a beautifully
guarded, thinly played game. I added eleven of those assertions myself, and I
would trade all eleven for one recorded playthrough.

So: **the next session's first job is not to make anything prettier.**

---

### AMENDMENT — the small content set is a DECISION, and the correction to the section above

Stated by the owner, 2026-07-29, and binding:

> We definitely should introduce all these systems at a slower pace, but I didn't
> want to bloat the game testing with 30 days when we are constantly changing
> this.

**The section above got the ratio right and the cause wrong.** Eight matters
against systems that could carry forty is a real observation, but it is not
neglect and it is not a gap. It is a deliberate refusal to author content against
moving systems. Thirty days of prose written now would be re-authored every time
a `Check` changes meaning, and re-authoring is the most expensive kind of waste
there is — it burns the one thing in this project that cannot be regenerated,
which is the writing.

So "the machine is finished; the game is not written" is the wrong reading. The
correct reading is: **the machine is finished, the game is deliberately not
written yet, and the next work is the SHAPE of the campaign rather than its
prose.**

Two things follow, and they pull in opposite directions from what came before.

**1. The introduction is far too fast, and that IS in scope.** On day one the
player currently meets the docket, the charter, the lens on a seal, the lens on
the closing formula at 7pt, the Book of Matrices, the Almanac, the Kalendar of the
Dead, hold-to-the-flame, melt/pour/press, the rack, and the wax tablet. That is
eleven teachable things before the second knock. Spreading them out costs no new
prose at all — it is a re-sequencing of content that already exists, which is
exactly the kind of work the owner's constraint permits.

**2. Do NOT author bulk content. Author the SCAFFOLD.** The distinction is the
whole amendment:

- **Scaffold** — which day exists, what it is allowed to teach, which existing
  matter carries it. Data, cheap to change, survives a system being redesigned.
  **But not "what is on the desk yet": see the settled section below.** Every
  shipped matter needs every book, so instruments cannot be staged at all without
  breaking the findable-must-be-renderable contract. The scaffold that IS cheap is
  the DELIVERY OF THE TELLING, not the withholding of the tools.
- **Prose** — the docket, the charter body, the petitioner's lines, the outcome
  branches, the aftermath. Expensive, irreplaceable, and must not be written
  against a mechanic that might not survive.

Build the scaffold now. Write the prose last, once the systems have stopped
moving.

**Test the curve with re-sequenced existing matters, not new ones.** The
design-prosecutor's earlier note applies directly: *a matter heard on Thursday is
a matter not heard on Tuesday.* `DayData.case_slots`, `requires_ruled` and
`fallback_case_id` already support re-using the eight shipped matters across more
days. That means the pacing of a six-day shape can be judged without authoring a
single new sentence.

**And this sharpens phase A rather than replacing it.** Play the days that exist.
The one number that matters — candle remaining at the start of the last matter —
is measurable on two days and tells you whether the clock is real. Do that before
deciding how many days the shape wants.

**What this amendment forbids:**

- Authoring new cases to "fill out" the campaign while any `Check` is still in
  flux.
- A tutorial overlay, a hint system, or any non-diegetic teaching. If a system is
  not yet introduced it is simply **not on the desk yet**, and it arrives as an
  object with a slip on it, the way the Register already comes back from review.
- Letting a day's findings depend on a book that day does not have. This is the
  same contract that has been violated three times and treated as critical each
  time — everything the ledger says was findable must have been renderable — and
  it becomes much easier to break the moment books start arriving on different
  days. It must be **enforced by the verifier, not remembered.**

---

### SETTLED — what "slower" actually means, and why my own proposal was wrong

Three specialists designed against the owner's constraint and one adjudicated
against `.tools/derived_findings.json` and the case data. The result contradicts
the obvious reading of "introduce the systems more slowly", so read this before
acting on the amendment above.

**You cannot withhold the books.** Verified against the derived findings for all
eight matters: every shipped case emits a `SealCheck`, a `DateCheck` **and** a
`WitnessCheck` finding. Case 01 alone emits `note:witness_died_that_year` and
`clean:witness_roll_silent`, and both are derived from the **necrology** —
`witness_check.gd` reads the roll, and `Witness.died_*` is demoted to the
parchment's claim feeding only `annotation_disagrees`. So the Book of Matrices,
the Almanac and the Kalendar of the Dead are all load-bearing on day one.
Withholding any of them breaks the oldest contract in the project: everything the
ledger says was findable must have been renderable on the desk.

The Register is the one book the rules provably do not need on Tuesday. Withholding
it is still wrong, because `Desk.reveal_register_review()` is the game's only
mid-day, physical, diegetic correction — and Tuesday is the day case 01 is
*designed* to be got wrong.

**So "stage the instruments" is unbuildable against the content that exists**, and
`data/world/curriculum.json` — which the amendment above proposed — is rejected.
Building enforcement for a curriculum that cannot exist until the prose does is
exactly the waste the owner's constraint forbids.

**What is genuinely front-loaded is one JSON string.** `world.json`'s `desk_note`
names ten instructions before the first knock: glass on wax, glass on the closing
formula, Almanac reduction, live-versus-dead die, tablet and stylus, the Kalendar
and its silences, hold-to-the-flame, melt/lift/pour/one-ring, the candle rule, and
CONFIRM/DENY/REFER as law versus procedure. **That paragraph is the whole
over-teaching problem, and it is data.** Stage it through the
`opening_documents` / `after_case` channel the R.V. thread already uses, keeping
only what the practice leaf immediately rehearses. No new system, no new prose —
the sentences already exist and only their delivery moves.

Note also that the rack is live from the second second with **no in-world
explanation anywhere except that paragraph**, which is worth solving deliberately
rather than by deleting the sentence.

### The misconception nobody had noticed

Both witness deaths a player meets on Tuesday — Reinmar Vogt in case 01 and
Eckhard von Melle in case 02 — carry `died_*` fields that render **on the
parchment** as a margin note via `charter_view.gd`. Nothing on Tuesday ever shows
a death that is *not* on the charter. Case 04, the first case where the Kalendar
is decisive, is therefore the first time "the parchment is silent and only the
roll knows" has ever been true.

So Tuesday teaches "a dead witness always shows on the document" twice, without a
single exception, and Thursday reverses it — which is precisely the misconception
the Kalendar's own doctrine, *absence is never evidence*, exists to forbid.

The fix is cheap and needs no new case: case 03 has three witnesses with no
`died_*` fields and a REFER verdict with slack in it. Give one of them a death
that lives **only** in the roll and changes nothing about the verdict. One
no-stakes "the book knows something the parchment does not" moment, inside a case
that can afford it.

### Three days, not six — and play the two you have first

**Three is the minimum, and the reason is the candle.**
`Candle.carry_forward()` clamps to `[0.45, 1.0]` and feeds
`SessionController.day_seconds()`. Two days is a single hop, so the floor and the
cap can never both be observed and a *chain* can never be observed at all. Three
days is the minimum where a day is **entered** on a candle that was already short
— the only condition under which carry-forward is a curve rather than a one-off
penalty.

Three is also the minimum that has a shape. As shipped, Tuesday is teach, test and
twist compressed into one day and Thursday is entirely test, twist and
consequence. There is no zero-point anywhere in the build, so "Thursday feels
hard" cannot be attributed to anything.

**And the measured playthrough of the two days that exist comes before the third
is authored.** That ordering is not negotiable; it is the whole point of phase A.

### The one schema change that is warranted

Not a curriculum file. **One field:** `requires_unruled: StringName` on
`DayCaseSlot`, with `resolve()` choosing `fallback_case_id` when the register
already holds a player ruling for it. Left empty, the slot vanishes for free —
`DayData.resolve_cases()` already skips nulls. That gives you *a matter you never
heard chases you down the week*, which is the consequence a third day exists to
carry.

**Named trap, and it is a nasty one:** `content_loader._load_days` parses exactly
three slot keys. A fourth key in the JSON is **silently ignored, with no error and
no test failure.** So the loader line, the validator row and the
`verify_content.py` slot loop must all land in the same commit as the field, or
the data will look correct and do nothing.

### What was rejected, with reasons

- **`data/world/curriculum.json`** and a per-instrument `findable_by` contract —
  my own proposal. Every case needs every book; there is nothing to sequence.
- **Withholding the Register on Tuesday** — safe at the rules level, but it is the
  only diegetic mid-day correction, on the day the game intends to be got wrong.
- **A per-day desk-furniture manifest** — `Desk._build_fixtures()` runs before
  `session.begin()`, so the desk does not yet know which day it is.
- **A second, third and fourth practice leaf** — the completion condition is
  welded to the lens on the player's own impression. Keep one leaf, for the two
  purely physical craft verbs. Everything else uses the pattern already shipped
  for the closing-formula lens: dressed non-decisively early, decisive later.
- **One-matter days and stretching eight matters across six thin days** —
  splitting days does not reduce day-one load at all, because everything the
  player meets on day one is inside case 01.
- **Reordering Tuesday's first three matters** — case 01 and case 02 are the only
  ungated matters in the build, and case 03's priority-5 arrival lines depend on
  case 02 having been ruled.

---

### A — Prove the loop (half a day, and do it first)

Not a system. An instrument and an honest look.

1. **Make the game recordable.** A `--session-log` flag that appends one JSONL
   line per player action with a timestamp and the candle's burn: picked up,
   opened book, put glass on X, ruled, referred. No telemetry service, no UI, one
   file under `.tools/`. It is the only way any later question about pacing gets
   answered with data.
2. **Then play both days, end to end, at `day_seconds` as authored, and write
   down where it dragged.** Not a subagent — the session's own hands on the real
   build, with the log open afterwards. Record: how long the first matter took,
   how much candle each of the four Tuesday matters actually consumed, and which
   book got opened and which never did.
3. **Report the number that matters:** candle remaining at the start of the last
   matter. If the day is never tight, the clock is decoration and the design's
   central pressure claim is false. If it is always tight, the reference books are
   a trap rather than a tool.

Nothing below this line should be built before that half day is spent.

---

### B — Favour becomes a supply line (the biggest idea, and the most philosophy-true)

The spine document already says it: **the Empire supplies me, the Church informs
me, the country comes to me.** Favour is stored on every ruling, and
`Register.favor_totals()` is written and never called. It is the largest
completely inert system in the project.

Make standing **physically inspectable and never legible as a number.** Nobody
tells you where you stand. You notice your tools getting worse.

- **The Kalendar comes back thinner.** Lose the Church and a gathering is razored
  out of the obit rolls with a "recalled to the chamber" slip in the stub — using
  the same physical vocabulary as the vermilion REVIEWED slip that already exists.
  Now a witness you could have checked is simply uncheckable, and *absence is
  never evidence* becomes something that happens **to** you.
- **The resin gets worse.** Lose the Empire and Thursday's wax cake is poorer:
  swap a harsher `WaxFeel` .tres, so the pour window narrows and Craft grades
  drop through no fault of your hands. The tuning resources are already
  hot-swappable; this needs no new system at all.
- **The candle you are issued is shorter.** `day_seconds` already scales by what
  you left in the dish. Let standing scale it too.
- **The tray is emptier, or fuller.** Fewer matters means less to rule on and less
  favour to earn — a debt spiral you can see in the rail before anyone says a word.

Every one of these reuses machinery that exists: `BookData` rebuilds
(`refresh_register_book` is the pattern), `.tres` swaps, `day_seconds`,
`DayCaseSlot`. **No new subsystem. No readout. If the player cannot infer their
standing from the state of the desk, the answer is a stronger effect, never a
number.**

---

### C — The Register acquires an author who is not you

Three of its entries are already in another hand, and that is the best hook in
the game. Extend it: **there is a second notary at another desk, and his rulings
appear in your Register between days.**

He rules on matters adjacent to yours. Sometimes he agrees with you. Sometimes he
has already decided the exact question you are about to face, the other way, and
in a firmer hand. You cannot argue with him, write to him, or find him. You can
only rule consistently with a colleague you have never met, or against him — and
`PrecedentCheck` already makes both cost something.

This turns the record from a memory into an antagonist, which is what the spine
document says the antagonist *is*. It is pure data: `RulingRecord` entries with
`foreign_hand`, delivered by the channels `DayOpeningDocument` already has.

---

### D — The doorkeeper will fetch one thing

The investigation is currently a fixed sweep: read, glass, book, flame. Every
matter runs the same four verbs in the same order, which is exactly the
repetition the owner keeps asking about.

Give the player **one errand per matter.** There is a hatch in the door. Write on
a slip with the stylus you already own, put it through, and the doorkeeper brings
back exactly one thing — the city book, a man's whereabouts, the other party's
copy, a second opinion from the second desk.

- It **costs candle**, so the clock finally buys something the player wants.
- It is **one per matter**, so it is a decision and not a shopping list.
- It is **physical**: a slip, a hatch, a wait, and something arriving through the
  door in the middle of your reading.
- And it makes two players' investigations of the same charter *different*, which
  is the test the prosecutor keeps applying and the game keeps failing.

---

### E — R.V., and the ending the game is already implying

The strongest thing in this project is not a mechanic. It is that the man who sat
at this desk before you is not in the building, and the most useful thing anybody
says to you all week is a memorandum he left addressed TO THE THIRD HAND.

His hand is in the marginalia of two books, the front matter of the Kalendar, and
three Register entries — **one of which is a recorded bribe, in the same hand as
the helpful ones.** That is already assembled and nobody has written what it is
for.

The campaign's spine should be that you work out what happened to him entirely
through documents, and that the last matter you are handed concerns him. Then the
game asks its real question, which is the one it has been rehearsing since case
one: *you have three rings and a body of law, and the man whose notes taught you
the job is on the wrong side of it.*

Do not write the answer as a twist. Write it as a matter — a docket, a charter,
a seal, a date — that reduces cleanly and produces a verdict nobody wants.

---

### What NOT to do next

- **No more graphics passes** until A is done. The marginal hour is worth more in
  the campaign's SHAPE than in pixels, and that is a change of advice from the
  last three briefs.
- **No authoring bulk prose while any `Check` is in flux.** Scaffold, not prose —
  see the amendment. This is the owner's standing constraint and it outranks every
  suggestion in this file.
- **No new `Check` subclasses.** There are five and two of them barely fire in
  shipped content. Feed the existing ones.
- **No more presentation assertions** unless they guard a defect you actually
  reproduced. The suite is large enough that its size is now a signal about where
  effort has been going.
- **Do not combine the three judgement columns.** Do not add a readout for
  favour. Do not put a number anywhere.
- **Do not build `data/world/curriculum.json`.** It was proposed in the amendment
  above and rejected against the derived findings — there is nothing to sequence,
  because every case needs every book. Stage the MEMORANDUM, not the instruments.
---

## THE LOOP: HOOK, SPINE, AND WHAT TO BUILD NEXT

From a cold sweep — six designers, one synthesis, three prosecutors. Read this
before adding content; it is the shape the content is supposed to make.

### The hook

You are the third hand at the third desk, and the man who sat here before you is
not in the building. He left the memorandum, addressed TO THE THIRD HAND and
signed R.V., and it is the most useful thing anybody says to you all week. Then
the first man comes up with a seal rubbed to nothing and a witness who died the
year it was drawn — and he is telling the truth, and the game's opening move is
to punish the reflex you walked in with. What brings you back is smaller and
worse: the third petitioner quotes what you did to the first, correctly. Your
rulings go into a book, the book is on the desk, and other people open it. Three
of its entries are not yours.

### The spine

**THE EMPIRE SUPPLIES ME. THE CHURCH INFORMS ME. THE COUNTRY COMES TO ME.**

Favour is a supply line, not a score. Standing is inspected by noticing the
Kalendar is thinner, the resin is worse and the tray is emptier — **never** by
reading a number off a page. If a player cannot infer their standing from the
state of the desk, the fix is stronger effects, never a readout. The antagonist
is the record: six separate reasonable decisions turn out to be a position, and
people plan around it before you notice it.

### Build next, in order

0. **The thread has a shape now — keep it inert.** `after_case` and
   `after_investigation` on `DayOpeningDocument` are the two delivery channels;
   both are data. The R.V. thread uses one of each and still answers nothing.
   Anything new that pulls on it should add a FACT and not a CONCLUSION, and
   nobody in the office may notice the eleven-years-against-eight arithmetic on
   the player's behalf.
1. **`Register.standing(authority)`** — call the already-written, never-called
   `favor_totals()` (`register.gd:96`), band it coarsely, and widen
   `DayOpeningDocument` with `requires_standing` / `requires_burnt_out` /
   `requires_unsound_at_least`. Then spend it in data. The mid-day arrival
   channel (`after_case`) shipped this session and is the same plumbing.
2. **Dockets say who MOVED the matter** (`interests`, rendered like the letters'
   existing `endorsements`), and tray slips stamp any subject this desk has
   already written on. Forecast without spoiling: an endorsement names a mover,
   never who will approve of which verdict.
3. **Saturday**, built on the returning Ford at Lenz — R.V.'s own referral,
   already in `register_seed.json`, coming back down the stair.

### The prosecutors' amendments — do not skip these

- **Do not band IMPERIAL favour.** It is already a soundness proxy: in three of
  eight matters the imperial delta is exactly +1 for the lawful verdict and −1
  for the unlawful one. Banding it hands the player a competence score in
  costume, which is the one thing the three-column rule exists to prevent. Use
  church/custom for supply, or decouple the deltas first.
- **`test_session.gd` asserts `not desk.ledger.allow_next_day`**, and
  `allow_next_day` is `day_index + 1 < days.size()`. Adding `day_03` to
  `_order.json` fails that assertion the instant it lands. Update it in the same
  commit.
- **`content_loader._load_days` parses only `case_id`, `requires_ruled`,
  `fallback_case_id`.** Any new `DayCaseSlot` field is SILENTLY IGNORED — no
  error, no test failure, the feature just never fires. This is the same class of
  bug as the `after_case` field: if you add one, parse it.
- **A foreign-hand prior is a party's argument, not the office's settled
  position.** `PrecedentCheck._same_claimant` / `_competing_claimant` fold the
  player's own priors into `Lex.Authority.OFFICE`; R.V.'s must not go the same
  branch. And the distinction needs one authored sentence inside the case that
  uses it — a player who spent Thursday treating the Register as uniformly
  binding will read it as an inconsistency, not a revelation.
- **Decide case_09's verdict model before writing dialogue.** Two incompatible
  shipped patterns exist: fixed `correct_verdict` (case_03) and
  `"DYNAMIC"` + `dynamic_precedent: true` (case_05/06, gated at
  `content_loader.gd:284` and `register_book.gd:133`).
- **`DocketSlip` extends `Draggable`, whose `_process` redraws every frame.** Do
  any Register lookup once in `bind()`, not in `_draw`.
- **`DocketView.content_bottom()` is hand-mirrored against `_draw_face`.** Adding
  a line to one without the other reproduces the overflow bug a third time.

### The twist seeds, planted and unfired

- **R.V.'s tenure does not fit the household book.** Odo Fenne (d. 1208) and
  Isenbard Kliff ("eight years at the desk", d. 1216) are both entered as notary
  at the third desk; R.V. claims eleven years, which begins in 1210 and overlaps
  Kliff by six. Two written records that cannot both be true, findable with three
  books already in the room. **No answer exists in the build. Do not add one
  without deciding what it costs.**
- **The archive at Lenz burnt in '18 and took forty years of oath-rolls with
  it** — R.V.'s own marginal note in the Book of Matrices, and the reason the
  Count of Hallenstein's roll will not come. "Nobody has worked out yet what that
  means for the Nether March. It will not be pretty when they do."
- **The steward's line is ruled and blank.** He enters a man on the day his bed
  is stripped, the bed under the stair has been stripped, and he has no date.

## THE PLAN OF ATTACK

Review it, disagree with it, expand it. It is ordered so that each phase makes
the next one cheaper — do not reorder without a reason.

**Phase 2's named work has landed.** The page turn carries its physical recto and
verso, blind tooling uses the shared `Surface` convention, the magnifier, ledge,
packet sweep, and view transition have landed, and morning has geometry. Judge
further material work from fresh captures instead of treating the historical
list below as unfinished scope.

**Phase 2 is deliberately not split into "the refactor" and "the fun part".** An
earlier draft of this plan did split them, and that was a mistake twice over: a
big-bang migration of ten objects' `_draw` producing no visible change is exactly
when things quietly get worse, because nobody looks at pixels while they are deep
in an abstraction — and it concentrates all the unrewarding work into one block
that a session is tempted to skip. Per-object passes that do material and motion
together are slower to describe and much harder to get wrong.

### Phase 0 — MEASURED. Mostly already done. (an hour)

**Do not spend a day here. The previous session's brief called this a blocker and
then measured it, and it was not.**

A throwaway probe with 19 draggables on the desk and both reference books open,
at 1600x900, reported **5.9 ms/frame — about 169 fps**. There is no performance
problem today.

What was genuinely wrong is fixed: `WaxShape.outline()` was being called from
inside `_draw` by the reference book's matrix and polity plates, so an open book
rebuilt a seeded polygon plus two smoothing passes every frame for as long as it
stayed open. It is memoised now, the probe reports 3 outline builds for a whole
session, and `test_presentation` asserts the memo holds.

What is left is **speculative**: `Draggable._process` calls `queue_redraw()`
unconditionally, twice per object, every frame, with no dirty flag, and so do
`Desk`, `WaxPool` and `ReferenceBook`. At this object count it costs nothing
measurable.

So your actual Phase 0 is:

1. **Re-run the probe and write the number down.** It is about twenty lines —
   instantiate `main.tscn`, open both books, time 240 frames, print the average.
   Delete it afterwards; `tmp_*` is gitignored.
2. **Grep `_draw` and `_process` for allocation** — `RandomNumberGenerator.new()`,
   array building, polygon generation, `%`-formatting. Those are real waste
   regardless of frame time. `Candle` and `WaxShape` are the reference for how to
   cache them.
3. **Leave the dirty flag alone** unless the number says otherwise.

Then measure again after Phase 1. **If a materials pass pushes it past about
10 ms, fix the dirty flag then** — `desk_ledge.gd` has the pattern. Not before.

### Phase 1 — EXTRACT a material helper. Do not design one. (half a day)

The reason the graphics work has not scaled is that every object invents its own
lighting from scratch. `Sheet` has a banded gradient. `ReferenceBook` has
`_lit`/`_toward_light`, a lit lip and a dark trough, board thickness and a
tracking specular. `SignetRing` has an engraved device drawn as two offset
passes. `RingStand` has bone inlay. `WaxShape` has nested silhouettes. **They
share nothing**, so every new prop starts at zero and every existing one drifts.

**Extract the helper from the code that already works — do not invent an API and
then bend ten objects to fit it.** `ReferenceBook._draw` and `SignetRing._draw`
between them already contain most of the vocabulary; lift it out and name it.

A `Material` class beside `WaxShape` and `Ink`, owning roughly:

- `toward(node)` — flame direction in local space, which half these objects
  recompute by hand today
- `lit(node)` — the `light_level x light_strength` product, same clamp everywhere
- `tint(base, lit)` — the warm-near/grey-away response
- `engrave(node, path, toward, lit)` — the lit-lip / dark-trough pair
- `specular(node, at, toward, lit)` — the moving highlight
- `bevel(node, rect, toward, lit)` — a raised or sunken edge

Ship it with **nothing migrated**. The commit should change no pixels. Then:

### Phase 2 — One object at a time, material AND motion together (2–3 days)

**This replaces what was previously two separate phases, and the reason is that
the split was a mistake.** A big-bang refactor that touches ten objects' `_draw`
and produces no visible change is exactly the kind of work that quietly makes
things worse, because nobody is looking at pixels while they are deep in an
abstraction — and it puts all the boring work in one block that a session is
tempted to skip in favour of the visible wins.

So there is no boring phase. Each object gets **one pass that does everything**,
and lands as its own commit:

1. migrate its `_draw` onto `Material`
2. give it whatever the material table in `docs/GRAPHICS.md` §3 says it still owes
3. fix its motion at the same time — phases, easing, variance, audio hooks
4. **capture before and after, and put both in the commit message**
5. add the assertion or the capture frame that would catch a regression

Order by visibility, worst first. A suggested order, which you should challenge:

- **`PressController` + `SignetRing` + `WaxPool`.** The money moment, and
  `feel-critic` has never once been pointed at `press_controller.gd`. Biggest
  single win available.
- **`ReferenceBook`'s page turn.** `_draw_turning_page` is a rectangle whose width
  sweeps across the gutter; its own comment calls it crude. Books are open for
  most of every case.
- **`Ledger`.** It arrives, and writes itself with a sound and no pen. It is the
  last thing a player sees each day.
- **`WaxSpoon` and `Lens`.** Metal that should catch the flame as it moves.
- **`DeskPlaneView` and `DeskLedge`.** The surfaces everything else sits on.
- **`Desk._tick_sweep`.** Papers freed on a flat 1.5 s timer.
- **`ViewController`.** The spring works; nothing in the room reacts to the head
  coming up except parallax.

Re-measure frame time after the third object and again at the end (see Phase 0).

### Phase 3 — Shaders, gated and optional (1 day, exploratory)

The project now has **one localized canvas shader**:
`shaders/lens_refraction.gdshader`. It uses the Compatibility renderer's screen
texture only inside the magnifier aperture and preserves nearest-pixel sampling.
Do not turn it into a full-screen post-process. Confirm renderer support before
adding a second shader family.

Two candidates, both of which would replace a lot of banded-rect faking:
**parchment translucency** (the backlit sheet, the candle's molten cup, the thin
lip of a pool) and **wax subsurface** (the sealing wax and the candle share
`WaxShape`, so one shader serves both).

Do not shader anything that currently looks right. If it fights the pixel-art
anchor, abandon it and write that down in CONTINUITY so nobody tries again.

### Phase 4 — Atmosphere as systems (half a day)

Dust and the shade veil landed. Still open, from a cold `feel-critic` sweep:

- The door has never met the candle — it takes no light at all.
- No depth layer sits nearer the camera than the desk.
- The room's acoustic bed is one flat 3-second loop at −30 dB that never changes
  across a session; the candle is acoustically silent for ~86% of a day.
  `sound-director` has a full layered proposal with generator code that fits
  `tools/make_placeholder_audio.py`'s idiom.
- The day's-end lighting turn has no geometry to turn on.

### Phase 5 — DONE. Kept below only so the decision can be argued with.

**Decided: add a third witness to case_04 — Herbord Gantz, castellan of
Thurnstadt — and one obit putting him dead two years before the grant.** Two data
edits, no code. case_04 turns CONFIRM -> REFER on `witness_dead`, which is the
build's first and only `defect:` tier finding, so the DEFECT -> REFER policy row
now executes in play. Frames 45 and 46 prove both halves are legible on the desk.
The full reasoning, and each rejected alternative with the file that kills it, is
in the commit message. The original brief follows.

### Phase 5 (original) — The Kalendar decision. **Yours to make.** (half a day)

The owner has explicitly handed this one to you. Make the call, do the work, and
say clearly in the commit what you decided and why so they can disagree
afterwards. Do not ask first.

**The problem.** The Kalendar of the Dead has four rolls, thirty-odd obits, its
own model classes, a generated book and one of the four pigeonholes — and no
shipped case turns on it. A player who consults it twice correctly infers it
never matters and stops opening it, which inverts the exact lesson it was built
to teach. Separately, there is not one finding at the `defect:` tier anywhere in
`.tools/derived_findings.json`, so the `DEFECT -> REFER` row of
`data/tuning/verdict_policy.tres` **has never once executed in play**, and REFER
is only ever taught as "two laws disagree" and never as "this is broken, send it
back".

**The obvious fix** is a witness edit on `case_04_second_lion` — a man on its
list who the Thurn chapel's roll records as dead before the charter's date. That
makes the Kalendar decisive exactly once, fires the unused policy row, and turns
the day's acknowledged sag into the case that teaches the third ring. It changes
that case's verdict from CONFIRM to REFER, which means rewriting its three
outcome branches and its `_design` note, and re-checking `PrecedentCheck` on
Thursday.

**Decide it against these, which are the game's actual philosophy:**

- *Everything the ledger says was findable must have been renderable on the desk.*
  Non-negotiable, violated three times, every one treated as critical.
- *An anomaly is not a crime.* Case 1 exists to unteach the denying reflex. Any
  new defect must not make suspicion the correct default.
- *The question is "which authority am I choosing to satisfy", not "is this
  correct".* Verification is the floor, not the ceiling.
- *A system the player correctly concludes never matters is worse than no system*,
  because it also teaches them to stop investigating.
- *Absence is never evidence.* Whatever you do, the Kalendar's silences must stay
  worth nothing — a roll that convicts by omission is the hole this whole
  subsystem was built to close.
- *Soundness, Favour and Craft are three columns and never one number.*
- *The correct answer is often cruel, and that is allowed.* What is not allowed is
  a wrong answer that the desk gave the player no way to avoid.
- *Content is data.* If this needs a code change beyond one `Check`, you have
  probably picked the wrong fix.

Alternatives worth weighing before you take the obvious one: author a ninth case
rather than change a shipped verdict; or put the defect on a Thursday matter that
is already weak instead of case_04. Say which you rejected and why.

## The reviewers

Eleven now, in `.claude/agents/`. **They load at session start**, so anything
added mid-session is not callable until the next one.

Changed this session:

- **`render-critic` is new.** Nothing owned materials, lighting, depth, silhouette
  or pixel-art coherence — `feel-critic` owns motion and `godot-reviewer` owns
  correctness, and the gap between them is exactly where the flat candle and the
  unreadable ring stand lived. It is required to open capture frames and describe
  what it sees before asserting anything.
- **`feel-critic` now has a stated border with it**, plus the two traps that cost
  real time: `ease(x, 0.4)` snapping on the first frame, and comments claiming
  "spring" at damping ratios that overshoot by a tenth of a pixel.
- **`godot-reviewer` gained two standing checks**: `z_index` versus child order
  (which produced a shipped bug), and per-frame allocation.
- **Every read-only reviewer now has to separate *confirmed* from *inferred*.**
  Nine of sixteen findings in one session did not survive an adversarial check.
  The most valuable review this project has had rendered a frame and measured the
  ink bands rather than reading the layout code, and it was right when everyone
  reading the code was wrong.

Run them cold and in parallel before a large pass. The signal worth acting on is
**convergence** — several agents sharing no context naming the same defect. That
is how the arrival path, the dead air between cases, the unreadable ring stand
and the flat candle were all found.

`feel-critic`, `render-critic`, `rules-auditor` and `design-prosecutor` are
deliberately adversarial. Do not soften them.

---

## Known and deliberately not done

Full list with reasoning in CONTINUITY under "Known and deliberately not fixed".
The two that matter beyond Phase 5:

1. **Favour is stored and inert.** `Register.favor_totals()` is written and never
   called. It is the least systemic of the three judgement columns.
2. **Thursday closes on three consecutive "nothing is wrong, confirm it"
   matters**, one of which is Tuesday's matrix lookup with the answer inverted.
   This is the repetition risk, and it is content work.

`WitnessCheck` firing no defect in any shipped case is the same problem as Phase
5 and is solved by it.

---

## How to work here

**Commit as you go**, with messages saying what was wrong and why the fix is the
right *shape*. Live at `github.com/PatheticPants/HREGAME` on `main`.

**Change one thing, re-capture, compare.** The candle took four iterations, each
judged from a frame — including the one where the wax physics were backwards and
only the picture showed it.

**Add the assertion that would have caught it.** Every fix this session shipped
with a test or a capture frame that fails if it regresses.

**Look at the pixels.** Three times now the owner has seen something in a
screenshot that no test could see.

**Decide things.** The owner reviews after, and would rather see a decision made
with the philosophy applied than a question sent back up. Phase 5 is explicitly
yours. Where you do make a judgement call, put the reasoning in the commit
message so it can be argued with rather than reverse-engineered — and record it
in CONTINUITY if it is the kind of thing the next session would otherwise redo.
