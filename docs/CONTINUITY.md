# Continuity note

For whoever picks this up next — a fresh session, or a returning one.

**If you are starting a new session, read `docs/NEXT_SESSION.md` first.** It has
the owner's standing priorities, a phased plan of attack, and what changed in the
reviewers. **`docs/GRAPHICS.md` is the rulebook for anything that draws** — the
light model, what a material owes, the animation rules, and the workflow. This
file is the reference underneath both: the things **not inferable from the code**,
and the traps that have already cost time.

`README.md` is how the game works. `docs/HANDOFF_CODEX.md` is the design
rationale.

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
| rules | 107 |
| presentation | 494 |
| the day (full loop) | 138 |
| content + encoding | PASS |

And a fifth, which is the only one that answers a pacing question:

```bash
powershell -File tools/sweep_pacing.ps1 -Dwells "0,8,12,16" -Tag now
```

**`-Dwells` is a COMMA STRING, not an array.** `powershell -File script -Dwells
0,8,16,24` binds all four to one `[int[]]` parameter as the single integer
**81624**, runs one nonsense sweep, and reports nothing wrong.

**There is a fifth thing to run now, and it is the only one that plays the
game.** `tests/play_day.tscn` drives both days end to end through the real input
path — `Input.warp_mouse` plus a synthesised button event, so
`Desk._input -> _begin_press -> _pick -> Draggable.grab` runs exactly as it does
under a hand. It melts, pours, presses and peels through `PressController`'s own
state machine. It is **not** headless, for the same reason the capture harness is
not.

```bash
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --path . --resolution 1600x900 --fixed-fps 60 --scene res://tests/play_day.tscn --session-log=.tools/play.jsonl --dwell=8
```

`--dwell` is seconds of reading given to each document and each consulted leaf;
it is the one quantity a machine cannot supply. `--dwell=0` prices the mechanical
floor alone. It prints candle remaining at the start of the last matter.

The capture harness writes **59** frames. The latest additions are 57 for the
glass on the charter's physical closing formula, 58 for parchment and ink at
inspection scale, and 59 for an open book's guttered shadow under grazing
candlelight. Frames 52-56 still cover the petition packet, intermediate
desk-to-audience poses, and the viscous wax neck.

**Run the rules suite before the Python one.** `tests/test_rules.gd` writes the
finding set it actually derived to `.tools/derived_findings.json`, and
`tools/verify_content.py` asserts its own list matches it case for case, in
order. Without that file the Python still runs — it must, because being runnable
with no Godot at all is the entire reason it is a separate implementation — but
it falls back to comparing only the final verdict, which is a three-valued
summary of a dozen findings and agrees by luck on most divergences.

**It is a git repository now.** `github.com/PatheticPants/HREGAME`, branch `main`.
The previous version of this file said it was not; that was the first thing a
fresh session found to be false, which is the whole reason for the warning at the
bottom of this document.

---

## Look at the pixels

`tests/qa_capture.tscn` writes ~32 annotated PNGs to `.tools/shot_*.png`
(gitignored) and it is the fastest way to find out that something is wrong:

```bash
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --path . --resolution 1600x900 --scene res://tests/qa_capture.tscn
```

Deliberately **not** headless — Godot cannot render 2D lights with the dummy
driver, and lighting is what these exist to check. Several defects fixed in this
pass were invisible in code review and obvious in a frame: parchment that ignored
the candle, a spoon throwing the shadow of a brick, verdict rings whose names
could not be read.

If you change anything visual, capture it. If you add a subsystem, add a shot for
it — the door and the petitioner had none, which is why their two worst defects
survived so long, and the wax had no frame in which anything was ON TOP of it,
which is why it spent months drawing over the entire room.

**Capture the object in the state you are worried about, not in isolation.** Every
frame of the seal showed the seal alone, so "is the wax actually on the
parchment" was never a question any frame could answer. Every frame of the candle
was desk-wide, where it is ninety pixels and no change to it is visible; the 4x
series (36-41) was added specifically because the owner could see it was wrong
and the harness could not.

---

## THE CLOCK WAS RETUNED 2026-08-01. THIS SECTION IS THE CURRENT ONE.

The table further down is the *old* build and is kept only so the change can be
argued with. Run `powershell -File tools/sweep_pacing.ps1 -Dwells "0,8,12,16" -Tag now`
to reproduce any of this.

| dwell | TUESDAY (520 s) | THURSDAY (400 s + stub) | SATURDAY (360 s) |
|---|---|---|---|
| 0 | burn 0.16, last at 88.1% | burn 0.22, last at 82.2% | not offered |
| 8 | burn **0.65**, last at 51.8%, **gutters** | burn **0.82**, last at 33.6%, **gutters** | not offered |
| 12 | burn 0.88, last at 34.0%, gutters | **burnt out, 3 of 5** | burn 0.64, 2 matters |
| 16 | **burnt out, 3 of 4** | burnt out, 2 of 5 | burnt out, 2 of 4 |

**What changed and why.** Tuesday was 1200 s and cost 337 s at dwell 8 — burn
0.28, oversupplied three and a half times over at every reading speed. Three
authored systems had therefore never been rendered in ordinary play: the stub
never slumped, `_output()` is `lerp(1.0, 0.30, ease(burn, 2.2))` so the light
contracted by four per cent, and `GUTTERING_FROM` at 0.86 was crossed only on
days the player LOST. The gutter, the smoke and the audible warning were a death
rattle rather than a warning. `GUTTERING_FROM` is **0.62** now and every day a
competent player completes reaches it.

**The carry ADDS and used to MULTIPLY, and that had to change first.**
`day_seconds = authored * unburnt_fraction` welded the days together: shortening
Tuesday lowered the carry and therefore shortened Thursday, for exactly the
player already drowning on Thursday. It also punished falling behind by making
you fall further behind — the only notary who ever reached Saturday was the one
two candles had already beaten, and the multiplication then took a third off
Saturday too. What carries now is **wax, in seconds, added**, capped at
`SessionController.CARRY_CAP` (0.34) of the receiving day. A day is never
shorter than it is authored to be, which is why `NEXT_DAY_FLOOR` is gone.

**Soundness scales the stub, and that is the counterweight.** A tight day rewards
skipping the books that cannot answer this packet — which is the actual skill,
and the books teach it themselves — but it rewards GUESSING exactly as much
unless being wrong costs something, and being wrong cost one ledger line and a
favour tally nothing reads. `Register.sound_fraction_for_day` scales what you
carry. **Cap first, then scale**: the reverse looks equivalent and is not, because
three quarters of Tuesday's 183 s remainder is 137 s which still clips to the
same 136 s cap, so one wrong ruling in four would have cost nothing at all.

**The degradation is graceful now, which it was not.** At dwell 12 a player hears
4 + 3 + 2 = all nine matters across three days. At dwell 16 they hear 7 of 9 and
the last ledger names the two who never got in. Before the change a slow player
simply lost matters to a compounding candle.

**Do not tune any of this from one point on the curve.** That is how you get a
retune that is exactly wrong for everybody except the imaginary player you
measured, and it is why `tools/sweep_pacing.ps1` exists.

---

## What a working day actually costs — the OLD build, kept to argue with

The first playthroughs this project has ever had. `tests/play_day.tscn` plays
every authored day through the real input path; `--dwell` is the seconds of
reading given to each document and each consulted leaf, which is the one
quantity a machine cannot supply. So the answer is reported as a curve against
it rather than as a single figure that silently encodes one guess about a
stranger.

Numbers are candle-seconds. `_burn_the_day` runs ONLY while `_work_engaged` and
only in ENTERING/SPEAKING/WORKING, so arrivals, departures, dialogue before the
first touch, the ledger and choosing from the tray are all free.

| dwell | s/matter | TUESDAY (1200 s) | THURSDAY (720 x carry) | SATURDAY |
|---|---|---|---|---|
| 0 | 22 | burn 0.07, last matter **94.6%** | 666 s, burn 0.14, last **89.5%** | not offered |
| 4 | 54 | burn 0.18, last matter **86.5%** | 589 s, burn 0.38, last **71.9%** | not offered |
| 8 | 85 | burn 0.28, last matter **78.8%** | 515 s, burn 0.67, last **50.0%** | not offered |
| 16 | 148 | burn 0.49, last matter **63.4%** | 368 s, **BURNT OUT**, 2 of 4 | 270 s, burnt out, 1 of 2 |
| 24 | 209 | burn 0.70, last matter **48.0%** | 324 s, **BURNT OUT**, 1 of 4 | 270 s, burnt out, 1 of 3 |

**1. Tuesday never becomes tight at any pace.** At 209 seconds a matter — three
and a half minutes of reading per charter — it still ends with 48% in the dish.
There is no reading speed at which Tuesday's clock is a constraint, short of one
that drowns you.

**2. Thursday goes off a cliff between dwell 8 and 16**, and the cliff is
carry-forward compounding, not Thursday being short. A player 1.9x slower needs
1.7x more time AND is issued 1.4x less of it (515 s becomes 368 s), because the
carry multiplies what the slowness already cost. Those two multiply into a 2.4x
swing across one doubling of reading speed. **So shortening TUESDAY does not fix
this and makes it worse** — a shorter Tuesday means a lower carry means a shorter
Thursday for exactly the player already drowning. Anyone tempted by the
one-number retune should read this row first.

**3. Guttering is not a warning. It is the death rattle.** `GUTTERING_FROM` is
0.86, and everything the candle does to say the light is going lives above it.
On every day a player COMPLETES, burn ends at 0.70 or less and the flame is
still at 69% of full or better. The threshold is only ever crossed on days that
burn out. Between "the desk looks like morning" and "the day is over" there is
no legible middle, at any pace.

**4. Saturday is correctly invisible until it is earned.** Never offered at dwell
0-8; real at 16 and 24, with no override. The `requires_unruled` gate works.

**5. The reference books are not a trap, and half the floor is not digging.**
Opening all four every matter, including fetching two out of the rack, fits
inside the 22 s mechanical floor. The seal ritual — melt, pour, press, peel — is
about 5 s of it. Of ~20 pick-ups per matter, ~16 are the four book consults;
evidence handling is four. CONTINUITY used to say "digging a buried charter out
of a pile is a mechanic here" as though it described the cost. It describes
about a fifth of it.

**What is NOT known, and would settle the rest:** where a human actually sits on
this curve. `--dwell` is a stand-in. One person, Tuesday, `--session-log` on,
twenty minutes.

---

## Review claims that did NOT survive adjudication (2026-07-29)

Recorded so nobody re-raises them. Both came from strong reviews that were
right about other things.

- **"The petitioners' two waiting lines can never fire."** True that a busy
  player never hears them — `_work_time` resets on every `_on_case_work_engaged`
  and every `_on_investigation_performed`, and a measured playthrough shows
  0.67–2.30 s of silence before each ruling. But both resets carry explicit
  design comments saying so: *"Doing something resets the silence. A player
  actively working the packet should not be prompted as though they had gone to
  sleep."* It is the stated intent, and the measurement came from a harness that
  never pauses. A human who puts a charter down and thinks for a minute hears
  them. **Working as designed.**
- **"The presentation suite is flaky — 4, 3 and 5 failures across three runs."**
  Not reproducible: three consecutive clean runs, deliberately with a
  playthrough sweep running concurrently. Every test it named was
  animation-timed, and the reviewer was rendering its own probes at the time.
  **Contention, not flakiness** — but worth knowing that this suite can be made
  to fail by loading the machine, so do not run it against a busy GPU and then
  believe the result.

---

## Traps that have already cost time

**DRIVING THE REAL INPUT PATH TAKES BOTH HALVES.** A pushed
`InputEventMouseMotion` reaches `_input` but does **not** move the viewport's
mouse — and `Desk._begin_press` reads `surface.get_local_mouse_position()`, so
it kept picking whatever was under the real desktop cursor. `Input.warp_mouse`
alone does not deliver a button press. You need the warp *and* the pushed event.
Note the three coordinate spaces: `get_viewport_transform()` maps canvas to
**window** (1600x900), `warp_mouse` takes window, and the viewport reports the
result back in its own stretched space (1920x1080).

**A HELD OBJECT MUST BE PLACED AND LEFT ALONE, NOT CHASED.** Correcting toward a
target every frame feeds `DragSolver`'s lag back in as velocity: the wax spoon
ended 234 units from a flame it had already reached. Move once, wait ~16 frames
for the spring, re-measure. And do not creep — a sub-pixel `warp_mouse` moves
nothing while the synthesised event claims it did, so the two disagree about
where the mouse is and the object walks. Holding still means not touching the
mouse.

**THE DESK IS INERT WHILE THE HEAD IS UP, AND ONLY THE WHEEL BRINGS IT DOWN.**
Every knock calls `view.look_up()`, and while `_view_amount > 0.06`
`Desk._input` returns early — every click goes to the petitioner. Normally
`_on_case_work_engaged` puts the head back down, but **that signal comes FROM
the desk**, so it cannot fire while the desk is not answering. Mouse wheel down,
or S, or Down. Nothing in the codebase exercised that path until a playthrough
did.

**THERE ARE PLACES ON THIS DESK WHERE A DOCUMENT CANNOT BE SEALED.** Rings,
spoon and sheets are all clamped to `DESK_RECT`, whose y stops at 410. A tall
charter (585 units) parked at y=330 puts its own wax slot at y=586, and the die
stalls ~70 units short of wax it is sitting next to, with no feedback whatever.
When something must be worked on, aim at the **wax slot's** position, not the
sheet's.

**Never rewrite a source file with PowerShell `Set-Content` / `-replace`.** It
round-trips through cp1252 and silently mangles every non-ASCII character — seven
em dashes in `candle.gd` each became three bytes of Latin-1 gibberish (an
a-circumflex, a euro sign and a quote) and the file still ran. Use the editor
tooling. `tools/verify_content.py` checks every text file for this on every run;
it also catches BOMs and CRLF.

**A new `class_name` is invisible until the class cache is rebuilt.** Adding a
script with `class_name` from the CLI breaks every file that references it until:

```bash
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path . --editor --quit
```

The error you get is a *parse error in an unrelated file* — usually
`Could not resolve class "ContentLoader"` — so it looks like you broke something
else. You did not. Rebuild the cache.

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

**`String.capitalize()` title-cases every word and splits snake_case.** Use
`Lex.sentence()` for prose.

**`z_index` breaks the desk's stacking rule, silently and permanently.** Draw
order on this desk is child order in `surface`, full stop — except that any
CanvasItem with a higher `z_index` draws above ALL lower-z siblings whatever the
tree says, and `z_as_relative` is on by default so a child's z is added to its
parent's. The poured wax carried `z_index = 1` for months and therefore floated
above every other paper on the desk once struck, while the spoon that poured it
(z=4 while held, 0 once set down) slid underneath it. If you find yourself
reaching for `z_index` to get something above something else, you almost
certainly want child order instead. The legitimate uses are transient and
self-cancelling: a ring while it is in the hand or in the wax, a falling bead,
the lens.

**NOTHING IN THIS GAME CLIPS ITS OWN TEXT.** `Ink.block` passes `max_lines = -1`,
the only `clip_children` in the project is `wax_pool.gd`, and the shade veil
covers boards rather than content. So text that overruns its surface is not
truncated — it is drawn onto whatever is underneath, unlit, and silently lost.
Four surfaces were doing it: the Almanac's ring-doctrine page (~150 px, taking
the whole FALSE-versus-DEFECTIVE doctrine with it), the books' marginalia, the
Kalendar's front matter, and three of the eight dockets. There are now fit
assertions for both families — `ReferenceBook.page_bottom()` and
`DocketView.content_bottom()`, each kept deliberately adjacent to the `_draw`
they mirror. **If you add a flowed text surface, add its fit check.**

**A FIXED RESERVATION IS THE BUG, NOT THE TEXT.** Both families failed the same
way: a hole of constant height (54 px for book marginalia, 30 px for the
doorkeeper's note) with a variable-length note pinned into it. The existing
`maxf` guards only stopped two blocks colliding; they said nothing about the note
being taller than its own reservation. **Diagnostic worth keeping: if shortening
the text does not change the measured overflow, the text is not what is
overflowing.** Trimming prose twice produced the identical 14 px and 34 px before
that landed.

**AN INVISIBLE OBJECT WAS ANSWERING CLICKS.** `Draggable.contains_point` checked
`draggable_enabled` and not `visible`. The Ledger sits in `surface` from
construction with `visible = false` all day, `z_index = 6`, and the biggest hit
rectangle on the desk — so it absorbed clicks meant for the lens, the rings, the
spoon and the candle wherever their rectangles overlapped it. Fixed.

**`_pick` sorts by z_index now, then child order.** The renderer sorts by z
first, so child-order-only hit testing could return something other than the
object visibly on top — the lens (permanent `z_index = 2`) lost to any sheet
picked up after it. This does NOT relax the stacking rule: child order still
decides everything within a z level, and later-child-still-wins at equal z.

**WRITING THE ASSERTION IS A SECOND SEARCH OF THE SAME GROUND.** It happened
three times in one session: the leaf-fit check found the Kalendar overflow after
only the Almanac had been fixed, the lens hit-test assertion uncovered the
invisible Ledger, and the docket check found two more overflowing dockets plus
the fixed-reservation cause. Budget for it; it is not paperwork that follows a
fix.

**`class_name Material` does not compile — `Material` is a Godot built-in.** The
shared lighting helper is `Surface` (`scripts/presentation/surface.gd`) for that
reason and no other. Before adding any `class_name`, check it against
`ClassDB.class_exists()` rather than against your memory of the engine.

**A pixel-art silhouette can be completely wrong and still read as the thing.**
The candle's flame was drawn upside down for the life of the project — apex in
the wax, blue base at the top — and survived four rounds of deliberately judging
that object from capture frames. At ship scale it is nine pixels by thirteen, and
an inverted teardrop still parses as "a flame is there". When you assert on
drawn geometry, assert on **where a point ends up**, not on the angle you handed
the transform: 148 degrees is a plausible-looking number to read past.

**Measure before believing your own eyes on a colour change.** Comparing spoon
frames after the wax fix, the new one looked *brighter* and was in fact 18%
darker — washed orange `(204,58,30)` had become deep crimson `(190,40,18)`.
Saturation reads as brightness. `PIL` is available; diff the two frames, take the
bounding box of pixels that actually changed, and compare luminance only over
those. Desk-wide frames are useless for this because the flame's flicker is not
deterministic between capture runs and swamps the signal — only the 4x series
could see it.

**Identity in the necrology is matched on `person_id`, never on name.** Two men
are called Hugo Wend. The cost is that a typo does not error — the man is simply
never found, the roll reports itself silent, and a witness who should have been
caught walks. `verify_content.py` catches a name known under two different ids,
which is the only shape of that bug that is detectable; nothing catches an id
that is wrong in both places.

---

## Conventions that are decisions, not habits

- `scripts/rules/` never touches a node, a signal or the scene tree. This is what
  lets the rules run headless. Do not relax it.
- No `is_forged` flag anywhere in the data. Forgery is derived.
- Content is JSON under `data/`; tuning is `.tres` (live-editable while running).
- Soundness, Favour and Craft are three columns and are never combined.
- Everything the ledger says was findable must have been renderable on the desk.
  This has been violated three times and every one was treated as critical. The
  most recent: an obit roll longer than a page silently dropped its tail, so
  `WitnessCheck` could convict on a name that was not on any leaf.
- One screen-space element exists in the whole game (`view_hint.gd`), and each of
  its two captions retires when the player has actually visited the plane it
  describes — **not** on any input, which used to delete the tutorial before it
  had been read.
- Every new `Check` must be written **twice**: once in `scripts/rules/` and once,
  independently, in `tools/verify_content.py`. When the two disagree, one has a
  bug. They had silently disagreed about `date_sound` for months because only the
  final verdict was ever compared.
- **`content_loader._load_days` parses exactly three slot keys, and a fourth is
  silently ignored.** No error, no warning, no test failure — the JSON looks
  correct and does nothing. Any new `DayCaseSlot` field must land in the same
  commit as its loader line, its validator row and its `verify_content.py` entry.
  The same shape of silence applies to every other `_load_*` in that file.

- **The instruments cannot be staged across days.** Verified against
  `.tools/derived_findings.json`: every one of the eight shipped matters emits a
  `SealCheck`, a `DateCheck` AND a `WitnessCheck` finding, and case 01's
  `note:witness_died_that_year` and `clean:witness_roll_silent` both come from the
  necrology. So the Book of Matrices, the Almanac and the Kalendar are all
  load-bearing on day one, and withholding any of them breaks
  findable-must-be-renderable. Do not build a curriculum file to sequence them;
  there is nothing to sequence.

  **The memorandum was the front-loaded thing, and it is staged now
  (2026-07-29).** Twenty-two sentences became nine. Four moved onto leaves
  delivered by `day_01`'s `after_case` / `after_investigation` channels; four
  were RETIRED to books that already carry them.

  **Retiring and deferring are not interchangeable, and the difference is
  mechanical.** `lay_out_day_documents` frees every `day_papers` entry at the
  next dawn, so a delivered slip does **not** survive the day. Where a book
  already holds the sentence permanently, deferring it makes it *less* available
  than leaving it alone. Check the books before staging anything.

  Two more facts that shaped the split: delivered slips are **not** exempt from
  `case_work_engaged` the way `desk_note` is (`desk.gd`'s `_begin_press` names
  only the note), so a slip picked up mid-hearing costs candle while the
  memorandum never does — prefer `after_case`, which lands in the gap where the
  clock is stopped. And the candle rule itself cannot be deferred by any channel
  that exists: `after_investigation` requires stage WORKING, by which time the
  clock is already running.

- ~~**Tuesday teaches a false rule about witnesses, twice, with no exception.**~~
  **Fixed 2026-07-29.** Gozwin, third witness on case 03, is now in the Saint Wend
  roll at Aldric I 14 with nothing on the parchment, so Tuesday shows one death
  that lives only in the book before Thursday makes one decisive. It reduces to
  1214 under the roll's own election reckoning, which is the charter's year
  exactly, so `WitnessCheck` emits `witness_died_that_year` — a NOTE — and case
  03 stays REFER with all three verdicts defensible.

  **The lever is narrow and worth knowing.** A roll hit that lands EARLIER than
  the charter is `defect:witness_dead`, and a DEFECT here would leave the verdict
  at REFER while silently collapsing `defensible_verdicts()` to `{REFER}` through
  `is_pure_authority_contest()`'s `has_factual_objection()`. The verdict would
  look untouched and every player who chose a law would be marked unsound.
  `died == year` is the only shape that is a NOTE.

  **And the obit's `note` must stay empty.** `KalendarBook` paginates on a flat
  six NAMES per leaf regardless of their height, so a leaf is as tall as however
  many of its six carry a note, and the first Saint Wend leaf clears its folio
  number by under 5 px. `_test_every_leaf_fits` now covers obit leaves and fails
  on printing through the folio number as well as on running off the board; it
  was proved to bite at 16 px before being trusted.

  Still open, deliberately: case 03 has no `consult_kalendar` beat, so nothing
  rewards opening the book there. That is a petitioner line, and prose waits.

- **The campaign is short on purpose. Scaffold now, prose last.** Eight matters
  across two days is a decision, not a gap: content authored against systems that
  are still moving has to be re-authored, and the writing is the one thing in this
  project that cannot be regenerated. So the SHAPE of a campaign — which days
  exist, what each is allowed to teach, which existing matter carries it, what is
  on the desk yet — is cheap and may be built freely. The docket, the charter
  body, the petitioner's lines and the outcome branches are expensive and wait
  until the mechanics have stopped changing. Test pacing by RE-SEQUENCING the
  eight matters that exist, never by writing new ones; `DayData.case_slots`,
  `requires_ruled` and `fallback_case_id` already allow a matter heard on Thursday
  to be a matter not heard on Tuesday.

  The corollary is a new way to break the oldest contract here. Once books start
  arriving on different days, a day's findings can depend on a book that day does
  not have — and "everything the ledger says was findable must have been
  renderable on the desk" has been violated three times already and treated as
  critical each time. When the curriculum becomes data, that has to be **enforced
  by `tools/verify_content.py`, not remembered.**

- **Humour is rationed: six to eight dry beats per working day, and never two in
  one matter.** The voice is flat declarative, past tense, the joke in a
  subordinate clause, and it always carries information — `matrices.json`'s
  "Ulrich seals a great deal and reads very little of it" is the register, and a
  line that would still be funny with its facts removed is the wrong line. At
  least three of the day's beats live inside a book the player has to open, so
  the office is funny when investigated rather than funny at the player.

  FORBIDDEN ABSOLUTELY: every `outcomes[].aftermath`; anything Adelheid Vesser
  says or that is said about her; case_08's `hold_to_light` and `waiting_long`
  lines; every DENY and REFER `reaction`; `burnt_out_text` and the ledger's
  "Heard, not ruled" and "Not heard" blocks; and any `Finding` text in
  `scripts/rules/`. The doorkeeper may be contemptuous about a person but never
  about a ruling — his note is written at the door, before the wax, and a docket
  that comments on the outcome is the game winking. What makes Grellwater land is
  that nothing anywhere near it is trying to be liked.

---

## What is actually built

**Three days.** Tuesday (fixed order, four matters), Thursday (a tray you choose
from), and **Saturday, which exists only if the week left somebody in the
passage.** Every slot on `day_03` is gated `requires_unruled` on itself, so it
holds exactly the arrears and nothing else; `SessionController._tick_closing`
offers the next-day corner only when that day resolves to somebody, so a notary
who cleared his week is never called in. Eight cases across three days.

That is why the existing assertion "the campaign ends without inventing a
third-day corner" still passes unedited — for a completed campaign it is still
true. **Do not "fix" it by deleting it.**

A docket records when a matter was RECEIVED, not when it was heard, which is what
makes arrears free: an unheard Thursday matter arriving on Saturday still says
"Called from the Thursday tray" and is telling the truth. **Re-sequencing matters
BETWEEN Tuesday and Thursday is not free** and was designed and rejected — every
docket's `received_note` names its day in player-visible prose, and three of
case_06's arrival lines open "On Tuesday you admitted". Six cases' shipped prose,
to move one matter.

A portrait constrains scheduling: Reimbold Zant reuses Gero Kalt's bust because
no new art exists, so the two of them cannot be heard on the same day. That is
why the knife is a Tuesday matter.

Checks that fire on shipped content: `ErasureCheck`, `SealCheck`, `DateCheck`,
`WitnessCheck`, `AuthorityCheck`, `PrecedentCheck`. Still unwritten:
`GenealogyCheck`, `PalaeographyCheck`, `JurisdictionCheck`.

Four books on the desk: the Almanac, the Book of Matrices, the Register (grows
during the day), and the Kalendar of the Dead (generated from
`data/world/necrology.json`, so it cannot drift from the law).

**Three of four pigeonholes are occupied before the first knock** — the tablet,
the Kalendar and the Register. One hole is left. The next person to add a book is
spending it, and should say so out loud rather than discovering it in a playtest.

The four investigative verbs are: read it, put the glass on it, look it up in a
book, and **hold it up to the flame**. The last is the newest and is the only one
that is not a lookup. It answers on every sheet — a sound skin transmits evenly
with its laid lines and follicles coming up, a scraped one shows a bright patch
with the removed words feathering back — because a verb that sometimes does
nothing is a verb the player concludes is broken.

**The candle carries over.** What is left of Tuesday's is what Thursday is given,
floored at 45%. `Candle.carry_forward()` -> `Desk.last_candle_remaining` ->
`SessionController.day_seconds()`. The Tuesday ledger says so before the
consequence lands, because a scarcity you only discover by having lost it is a
trap rather than a decision.

**Humour is budgeted at six to eight dry beats a working day**, with a written
forbidden list — see the conventions above. The register is flat declarative,
past tense, joke in a subordinate clause, always carrying information.

---

## The subagents

Eleven, in `.claude/agents/`. **They load at session start** — a newly added one
is not callable until the next session.

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
| `render-critic` | read-only; materials, lighting, depth, silhouette, pixel-art coherence |

`render-critic` is required to open capture frames and describe what it sees
before asserting anything, and every read-only reviewer now has to separate what
it **confirmed** from what it **inferred** — nine of sixteen findings in one
session did not survive an adversarial check.

They are the main lever for a large task: each one starts with a cold context, so
the heavy reading happens in *their* window rather than the main one. Use them
before the main context fills, not after.

`feel-critic`, `render-critic`, `rules-auditor` and `design-prosecutor` are
deliberately adversarial. Do not soften their prompts — their value is that they
disagree.

Running all ten at once against a cold read of the codebase is worth doing before
a large pass. The signal is **convergence**: when four agents with no shared
context independently name the same defect, it is real. That is how the arrival
path, the dead air between cases and the unreadable ring stand were all found.

---

## ASKED FOR ON 2026-08-02 AND NOT DONE. Read this before planning.

Three of the owner's requests are not in the build. None was refused; all three
are real work and saying so is more use than a half-built version.

1. **Stage the reference books across the days.** "We should not have every book
   available at the start." Wanted, and it collides with a contract that has been
   broken three times and treated as critical every time: *everything the ledger
   says was findable must have been renderable on the desk.* Every shipped matter
   emits a SealCheck, a DateCheck AND a WitnessCheck finding, so all four books
   are load-bearing on day one as the content stands.
   **The way through is arrival, not withholding.** `DayOpeningDocument` already
   delivers objects mid-day through `after_case` and `after_investigation`, and
   `Desk.reveal_register_review` already puts a book on the desk as a physical
   event. A book that ARRIVES before the matter that needs it satisfies both —
   Tuesday could open with the charter, the glass and the Matrices, and the
   Almanac could come up the stair when the first regnal date appears. That needs
   a per-day furniture manifest, which `Desk._build_fixtures` cannot read today
   because it runs before `session.begin()`. Start there.

2. **Heating the wax should be over the flame.** "Right now you just hover over
   the wax area, which does not make much sense." The code already requires the
   spoon's bowl to be inside a 108x60 box above the wick
   (`PressController._update_spoon`, `heat_radius` 54) — so what is wrong is not
   the rule but that NOTHING SAYS THE RULE IS BEING MET. There is a `wax_melt`
   loop and no visual whatever: no glow on the brass, no change in the cake, no
   cue when you enter or leave the zone. Give the bowl a heat response before
   moving any geometry; the complaint is legibility wearing a mechanics costume.

3. **Events that use the burning.** The mechanic shipped; nothing in the content
   asks for it yet. The obvious ones, in order of cheapness: a letter that orders
   its own destruction (the R.V. thread already has the tone for it), a matter
   where the petitioner asks you to lose their document, and Thursday's
   `letter_aue_recall`, which already says "No ruling is required of you. The
   file is closed either way" — a player who confirmed the forgery is handed the
   evidence of it back with nothing to do about it, and a candle.

## THE LIGHTING BUGS, 2026-08-02 — five found, four fixed, one reverted

The model here is a HYBRID and every one of these lived in the seam: real
`PointLight2D`s and occluders do the room, while each object *also* shades itself
by hand from a single `light_level` the desk writes once per frame. Both halves
are good. What goes wrong is one of them not being told something.

**Where to look first, next time.** `Desk._update_lighting` walks
`surface.get_child_count()` and then names five more objects individually. Any
object that is not a `surface` child and is not on that list gets nothing, and
any light field an object does not DECLARE cannot be set even if the desk tries.

1. **Everything arrived fully lit for one frame.** `Draggable.light_level`
   starts at 1.0 and `_update_lighting` runs from `Desk._process` — but the
   session is a CHILD of the desk, so its `_process` runs *after*. A packet laid
   out on a knock was created after that frame's lighting pass and before that
   frame's draw. Measured against the unfixed code with the flame in the far
   corner: `light_level` 1.000 where it should be 0.030. One frame of white paper
   on every arrival, in a game whose whole look is one small pool of light. All
   four object-creating entry points now light before returning.

2. **The day's-end turn popped.** Every per-object value keyed off the boolean
   `is_spent`, so on one frame every `light_level` snapped to `WINDOW_LEVEL` and
   every `light_position` jumped 2600 units to the shutter — swinging every
   gradient, specular and engraved lip through most of a half-turn — underneath a
   `CanvasModulate` that takes two seconds to cross. `_morning_amount` already
   existed and already ramped; it was driving the shutter geometry and nothing
   else. Position, level and strength blend along it now. The MODEL switch
   (`ambient_daylight`) cannot blend and flips at the midpoint, where the two are
   least far apart.

3. **The ring stand never flickered and never saw the morning.** It did not
   declare `light_strength` or `ambient_daylight`, so the desk could not set
   them: the one object naming the three irreversible choices sat perfectly still
   while every other surface breathed, and went on warming its oak toward brown
   in a cold grey room.

4. **The struck seal was lit from the middle of the page.** `WaxPool` is a child
   of the sheet, not of `surface`, so it inherited the sheet's single value —
   sampled at the sheet's origin, up to 290 units from the blank foot the wax
   sits in. `Draggable.illumination_at` is the general fix and is now available
   to anything that is bigger than the point it was measured at.

5. **An open book is 640 units wide and was lit at one point.** The candle beside
   the left leaf lit the right leaf identically, so the two largest silhouettes
   in the room reported the flame's position by their highlight direction and
   contradicted it with their brightness. Measured after: 0.751 against 0.119,
   and it swaps when the candle is carried across.

**AND ONE REVERTED, WHICH IS THE USEFUL ONE.** The same per-band sampling was
applied to `Sheet._draw_light_gradient` and it MOVED NOTHING — four thirds of the
charter and the memorandum changed by 0.0 to 0.2 out of means of 22 to 44. A
430-unit sheet is small enough that inverse-square falloff across it is nearly
linear, so the fixed ramp was already right; books break the approximation
because they are 640 wide and hinged around a gutter. The falloff you can see
across a sheet in a capture comes from the actual `PointLight2D` and is correct.
Do not do it again.

## THE MAGNIFIER. FIXED 2026-08-02, AND THE DIAGNOSIS WAS HALF WRONG.

Every cause was **a hard yes/no edge with a human hand on it.** `_find_subject`
answers across three boundaries — a reach radius, a containment test and a burial
test — and `_settle` across a fourth, a speed. A held object is driven by a spring
attached to a hand, so it does not sit still on any of them: it crosses them,
repeatedly, and each crossing used to reassign `_focus` and slam `_focus_amount`
to 0.0 on the same line. That single frame does three things at once — the opaque
field that hides the small source glyphs vanishes, the screen magnification jumps
from 0 back to generic, and the authored plate disappears. A cut between two
completely different pictures, over and over, for as long as the hand shakes.

**The fixes.**

- `_focus` (what the aperture is SHOWING) is now separate from `_want` (what the
  glass is over). They disagree during a crossfade and `_focus` only changes when
  there is nothing on screen to change. One fade instead of a cut.
- A null result must persist for `SUBJECT_GRACE` before the subject is dropped,
  so a one-frame dropout at a rim does not tear the image down. `_lost_for`
  resets on any non-null frame, which is exactly what makes an alternating
  tremor hold and a genuine departure release.
- The containment test returns a DISTANCE (`_lens_gap`) rather than a boolean,
  because a distance can carry hysteresis and a boolean cannot. Acquire within
  `CONTACT_SLOP`, release only past `CONTACT_SLOP + HOLD_SLOP`.
- `_settle` gets two thresholds, 45 to enter and 95 to leave. It IS the generic
  magnification, so a hand hovering near the old single 60 swung the entire
  screen image between 0.16x and 1x.
- `optical_magnification()` is locked to the same `ease(_focus_amount, 0.55)` the
  opaque field uses. It used the raw value while the field used the eased one, so
  for the whole of every fade the aperture showed a partly-magnified copy of the
  source under a partly-opaque cover under the enlarged plate — the same words at
  two sizes, which is the exact defect the field was added to prevent, surviving
  in the transition it had only ever been measured at the endpoints of.

**WHERE THE OLD DIAGNOSIS WAS WRONG, which is the useful part.** It said the two
range tests "disagree over most of a charter" and to fix the others first. In
fact `reach` (98.6 units from `detail_centre`) is almost never the binding
constraint — for a pendant seal forty units across, containment binds first, and
containment was the test with no tolerance at all. The first attempt put the
hysteresis on `reach` and the new assertion reported the image torn down at every
single sample. **Find which test actually binds before adding tolerance to one.**

It also called `optical_magnification`'s coupling to `_focus_amount` a bug of two
systems "wired in opposition". It is not: authored detail REPLACES the screen
copy rather than overlaying it, or the same sentence prints at two sizes. The
coupling is correct and the curve was wrong.

**A risk the crossfade introduced, and the assertion that covers it.** `_focus`
outliving `_want` means it can hold a reference to something freed mid-fade —
parchment burns, packets are swept when the candle drowns, a pendant tag goes
with its sheet. A freed Object is NOT null in GDScript, so every `_focus != null`
guard passes and the next `get_instance_id()` faults. Cleared explicitly at the
top of `_process`.

## What the owner found by PLAYING it, 2026-08-02 — six reports, six real defects

That is the third session running in which the highest-value findings came from a
human playing rather than from a reviewer reading. Every one was reproduced in
pixels or in a number before anything was changed, and one of them was introduced
by the previous commit.

1. **The type was point-sampled at a fractional scale.** Viewport 1920x1080,
   window 1600x900, `stretch/mode="canvas_items"` — the canvas is scaled by
   0.8333, and `Desk._ready` sets `TEXTURE_FILTER_NEAREST`, which every child
   inherits. Glyph atlases sampled NEAREST at 0.833 drop or double rows: stems
   one pixel here and two there, baselines wobbling along a line. One line in
   `Draggable._ready`, and it is safe there **only because every object that
   draws an authored plate re-pins NEAREST on itself afterwards** — check that
   list before touching it. **MSDF was tried first and does nothing:** that
   project setting applies to a default theme font and everything here draws
   through `ThemeDB.fallback_font`. Measured pixel for pixel; noted in
   `project.godot`.

2. **Headings ran across the gutter onto the facing page.** `Ink.heading()` took
   a `width` and used it for the rule underneath and nothing else; the heading
   went through `Ink.line()`, whose width defaults to -1, and `draw_string` with
   -1 neither wraps nor clips. **Every fit assertion in this suite measured
   HEIGHT** — a whole axis was unguarded, which is why the leaf-fit test that
   caught four vertical overflows walked past four horizontal ones. Headings and
   generated single lines are SET TO FIT now (`Ink.fitted_size`, `Ink.line_fit`),
   and the band a heading reserves stays the size it asked for: `page_bottom()`
   and `content_bottom()` are hand-mirrored against these draws, so a heading
   that shrank *and moved what was under it* would invalidate every vertical
   check in the file.

3. **The ring stand was eating its own words.** One loop drawing recess-then-word
   buried each word under the next socket, and at `SLOT_GAP` 92 there were twelve
   units of clear wood for 21 units of type anyway. Two passes, gap 104.

4. **A ring put back quickly floated off the block** — 81 units off, measured
   against the unfixed code. `DragSolver._step_free` keeps a released body's
   velocity and only bleeds it. `home_position` had existed since the first
   commit and was read by nothing but the tests. It seats into its **own** hollow
   only, with a catch smaller than half the slot gap; a ring genuinely left
   elsewhere still stays there, and that is asserted.

5. **The opening asked for fourteen things at once.** Not too little explanation
   — SIMULTANEITY: six sentences on the memorandum, five on the practice slip,
   three paragraphs on the leaf, none saying which to do first.
   `SessionController.PRACTICE_STEPS` is the fix and is where that prose lives
   now; the JSON holds only its first frame.

6. **There was no music.** `tools/make_music.py` and `_drive_music`. The rule is
   that **the melody plays while the candle is being spent and at no other
   time** — the same rule as the flame. Placeholder; the file names are the whole
   contract for replacing it.

**And I mangled two docs with PowerShell while writing this up**, exactly as the
trap below says, and `verify_content.py` did not catch it because it does not
scan `.md`. `git checkout` and redo with the editor tooling. The rule is not
"be careful with `-replace`", it is **do not use it on a file at all**.

## Four things the 2026-08-01 pass found, all of which were invisible to every suite

Recorded because each is a *shape* of defect this project keeps producing, not
just four bugs.

1. **The tutorial was a softlock.** `PRACTICE_REVIEW` had no branch in
   `_process`, so the only exit was the glass on your own impression followed by
   releasing it — and the only sentence in the game that said so lived in the
   practice docket's `doorkeeper_note`. This project had already measured that
   hand at 0.211 Michelson contrast against 0.557 for the upright one, already
   written down that it "is never authoritative", and already moved the candle
   rule out of it for exactly that reason. **The shape: a register the game
   trains you to discount was carrying load-bearing text, again.**

2. **The content loader forbade the content two authored FATALs exist to catch.**
   It rejected any seal whose `claims_owner` is not in the Book of Matrices — and
   a house that keeps no dies has no owner in that book *by definition*, so
   `seal_where_none_used` was unauthorable and so is `matrix_unknown`.
   `tools/verify_content.py` had it right and printed a note. **The shape: the
   two rule implementations disagreed and only the stricter one blocked, so the
   disagreement read as content being wrong.**

3. **Pagination was deciding content.** `ReferenceBook` pairs `(spread*2,
   spread*2+1)`, so `thurn_dietrich_i` at page 5 and `thurn_dietrich_ii` at page 6
   fell on different spreads and could never be seen together — the one
   comparison two shipped cases turn on. Fixing it with ONE leaf silently
   un-paired the abbey from the chapter, which is the comparison case_03 turns
   on, and every test still passed. `_test_facing_pages` is the guard. **The
   shape: an invariant that lives in the parity of a list and is asserted
   nowhere.**

4. **Clicking a racked book opened it 292 units above the desk.** `grab()`
   unstows on the press, `_end_press` returns after `on_click` for a click, so
   `_try_rack` — the only caller of `DeskLedge.release` — never ran, and the
   ledge went on refusing that hole to everything else. The memorandum names the
   Kalendar as "the green book in the rack", so this is a very likely first
   interaction. **The shape: a bug in the seam between two handlers, on a path
   no capture frame and no harness ever took.**

## Known and deliberately not fixed

These are recorded so the next person does not think they are undiscovered.

- **`Draggable._process` redraws unconditionally every frame**, twice per object,
  with no dirty flag, as do `Desk` and `WaxPool`. The original 2026-07-28 probe
  measured 5.9 ms/frame; the return graphics pass now measures **9.22 ms/frame,
  about 108 fps, with 19 draggables and all four books open**. It remains below
  the 10 ms intervention line. The permanent capture-harness probe added by the
  magnifier pass measures **6.45–6.73 ms/frame, 149–155 fps, with 17 live
  draggables and all four books open**. Because those poses differ, neither
  number replaces the other; preserve the scenario and keep measuring before
  another broad material layer.
  `ReferenceBook`'s half of this — a seeded wax outline rebuilt per frame per open
  plate — WAS real and is fixed: `WaxShape.outline` is memoised and the
  presentation suite asserts the memo holds.
- **Favour is REPORTED and still has no downstream consequence.**
  `Register.favor_totals()` is finally CALLED (2026-08-01) — the campaign's last
  page prints the week's cumulative standing, which the day-local tally never
  could. But standing still changes nothing about the desk. The supply-line plan
  is in `docs/NEXT_SESSION.md`; the gating half of it (`requires_favor_below` on
  `DayOpeningDocument`, re-gating Thursday's letters on accumulated favour rather
  than on one verdict) is the obvious next slice and is deliberately not built.
  **`Register.impression_grades()` is still called by nothing at all** — Craft
  reaches the ledger as one sentence and the blotter as crumbs, and that is the
  whole of it. The plan for making it a supply line rather than a
  score is in `docs/NEXT_SESSION.md`, along with the reason IMPERIAL favour must
  not be the one banded.

  **It was deferred deliberately on 2026-07-29, against the measurement.** The
  supply line was gated on the working day being genuinely tight. Measured, it
  is tight on Thursday (67% of the candle at a competent pace) and loose on
  Tuesday (28%) — so the lever the plan names, a shorter issued candle, would
  compound on the day that already bites and do nothing to the day that is
  decoration. Retune Tuesday first, re-measure with `play_day`, and only then
  decide whether standing should also move the candle. The Kalendar-gathering
  and worse-resin levers do not have this problem and could go first.
- ~~**Thursday is three consecutive "nothing is wrong, confirm it" matters.**~~
  **Half fixed 2026-07-28.** case_04 now produces the build's first and only
  `defect:` tier finding, so `verdict_policy`'s DEFECT -> REFER row executes in
  play and REFER is taught as "this is broken, send it back" as well as "two laws
  disagree". Thursday is no longer three consecutive confirms. What remains true
  is that case_04 was Tuesday's matrix lookup inverted; it now *starts* that way
  and then turns on something else, which is the point.
- ~~**The Kalendar convicts nobody.**~~ **Fixed 2026-07-28**, see the commit
  "Phase 5: the Kalendar convicts one man". Herbord Gantz, castellan of
  Thurnstadt, is on case_04's witness list and in the Margrave's chapel roll as
  dead two years before the grant. The reasoning, and the three alternatives
  rejected and why, are in that commit message — argue with it there.
- **Two of Thursday's four matters cannot be ruled wrongly**, because a pure
  precedent contest marks every ring defensible.
- ~~**`WitnessCheck` fires no defect in any shipped case.**~~ Fixed by the same
  edit. It now fires exactly once, on a positive roll entry rather than a
  silence.
- **No shipped case springs the reckoning trap.** The Thurn chapel reckons by
  accession, the same style as case_04's charter, so the game's one decisive
  Kalendar lookup is a direct comparison of two regnal years and costs no
  cross-reckoning arithmetic. The Saint Wend chapter counts from *election* and
  a clerk who reduces its obits as an imperial notary gets a number three years
  wrong — and nothing a player is ever handed exercises that. This was left
  deliberately: case_04 already teaches a new book, a new finding tier and a new
  meaning for a ring, and a fourth new thing in one matter is bad teaching. It is
  the obvious next case and it should be a *different* case.
- **`data/world/books/almanac.json`'s ring-doctrine page contradicts the engine.**
  It tells the player that an unlookuppable name is a referable defect; the engine
  holds that silence is worth nothing and only ever emits a NOTE. Latent while
  nothing turned on the Kalendar, and now one page away from a case that does.
  Either the page or the doctrine should move.
- **`ReferenceBook`'s blind tooling is lit inside out.** A groove's lit lip
  belongs on the side AWAY from the flame; the book draws it toward, so the
  boards' stamped borders read as raised rather than impressed and swing the
  wrong way as the candle passes. `SignetRing` has it right. The convention and
  the physics are written down in `Surface` and asserted; the book itself is
  waiting on its own pass, with a before/after frame.
- **A witness's claimed house is never rendered on the parchment.** The rules
  read `house` to decide which roll would have had a man; the charter shows only
  his name and style. A player can infer the house from the style most of the
  time, which is the intended lookup — but where they cannot, the ledger knows
  something the desk never said.

---

## If you are a fresh session

Do not trust any summary of the codebase, including this one, over the files. The
project has roughly doubled in content three times now, and each time the previous
session's mental model went stale in ways that were not obvious — including this
file's own claim that there was no git repository.

Read the actual files for anything you intend to change, and run the capture
harness for anything you intend to look at.
