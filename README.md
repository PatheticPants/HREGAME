# Hand and Seal

A document-inspection game set in a fictionalised Holy Roman Empire. You are a
low-born notary of the Imperial Chancery. People bring you claims to land and
title, and you rule on them, and the ruling is executed in wax.

Two working days, eight matters, five verification types, and a Register that
carries what you did on the first day into the second.

---

## Running it

Open `project.godot` in Godot 4.3 or newer and press F5.

```bash
godot --headless --script tests/test_rules.gd
```

runs the rules layer with no window and no scene tree. It asserts, among other
things, that every case's authored ground truth is what the documents actually
produce — if content and law ever disagree, that test says so.

```bash
python tools/verify_content.py
```

does the same validation **without Godot at all**. It is a deliberately separate
implementation of the same rules; when the two disagree, one of them has a bug.

```bash
godot --headless --fixed-fps 60 --scene res://tests/test_presentation.tscn
```

runs the real desk without a display. It catches the failures a pure rules test
cannot: verdict rings or pendant seals spawning outside the reachable desk, wax
drops failing to land, and a press sequence that no longer reaches resistance,
seat, peel, and commitment.

```bash
godot --headless --fixed-fps 60 --scene res://tests/test_session.tscn
```

plays a whole day through the real `SessionController` at real timings — knock,
arrival, dialogue, ruling, reaction, departure, the next knock, the ledger — and
then plays a second day with the candle set short enough to drown mid-case. Every
other test deliberately freezes the session so it can pose the desk; this is the
only one that proves the loop actually connects end to end.

```bash
godot --path . --resolution 1600x900 --scene res://tests/qa_capture.tscn
```

writes annotated PNGs to `.tools/shot_*.png`: the desk at rest, the candle
carried to two positions, molten and pouring wax, the hot pool before pressing,
a centred versus an off-rim strike at close crop, books in the rack, a note on
the wax tablet, the glass held over both an incoming pendant seal and your own
work, and the candle at fresh / half / guttering / out. Deliberately **not**
headless — Godot cannot render 2D lights with the dummy driver, and lighting is
what these shots exist to check.

## Review agents

`.claude/agents/` holds ten subagent definitions. They load when Claude Code
starts, so a newly added one is not callable until the next session.

| | |
|---|---|
| `loremaster` | canon: polities, houses, customs, names. Keeps a project memory as the bible. |
| `case-writer` | authors new cases as data, with the decisive fact and the path to it stated. |
| `feel-critic` | read-only. Phases, easing, weight, variance, audio hooks, diegetic violations. |
| `godot-reviewer` | read-only. Cross-platform safety first, then separation of concerns and idiom. |
| `rules-auditor` | read-only. Assumes every case is broken until proven otherwise. |
| `campaign-architect` | consequence across days, precedent, faction pressure, progression. |
| `design-prosecutor` | read-only. Is this a game, or beautiful craft over a thin loop. |
| `difficulty-curator` | teaching order, and which axis each case spikes. |
| `player-advocate` | cold first-time-player walkthroughs. |
| `sound-director` | the sonic language, and what sound tells you that nothing else does. |

`feel-critic`, `rules-auditor` and `design-prosecutor` are deliberately
adversarial and their prompts should stay that way — their value is that they
disagree with you.

Running all ten at once against a cold read is worth doing before a large pass.
The signal is **convergence**: when several agents that share no context
independently name the same defect, it is real.

```bash
python tools/make_placeholder_audio.py
```

regenerates the 25 placeholder sounds. Deterministic, so it will not churn the
repo. Standard library only.

---

## Playing it

Everything is an object on a desk. There is no HUD, no menu, and no button that
says Confirm.

| | |
|---|---|
| **Drag** | anything loose. Papers, books, the brass spoon, the glass, the rings. |
| **Click** a book | opens it. Click the outer third of a page to turn it, the middle to close it. |
| **Click** anywhere else | the petitioner keeps talking. |
| **The lens** | a seal's legend is not legible without it, and neither is the closing formula at the foot of a charter. |
| **The flame** | pick a charter up and hold it near the candle. Scraped skin is thinner than the skin around it, so it transmits — and the word somebody took out with a knife comes back through the patch. |
| **The rack** | drop a book, tool or sheet over a pigeonhole on the back rail to put it away. Pick it up to get it back. |
| **The tablet** | take it out of the rack, then move the stylus over the wax to scratch a note. Rest the nib to smooth it out. Nothing reads what you write. |
| **Your attention** | petitioners notice which book you consult and when the glass lingers over their wax. |
| **The candle** | pick it up and put it where you are working. It is the only light in the room, and it is the day's clock. |
| **The wax** | hold the spoon's bowl over the flame until the red resin cake liquefies, lift it clear, then hold it steady over the sheet to pour. It pours where you tip it. |
| **A ring** | hold it *steady* on the pool. It descends, resists, gives, seats. Let go to lift. |

Picking a ring up *is* the ruling. There is no confirmation step and no undo.

## The loop

One petitioner is one full turn of it:

1. **A knock.** The door opens, someone comes in and puts a packet down.
2. **Read the docket** — who they are and what they want. It stays on the desk,
   so the claim survives being buried.
3. **Investigate.** Read the charter. Get the glass onto the seal to read its
   legend. Open the Book of Matrices, find the die, compare four things. Open the
   Almanac, find the reign, reduce the date. Get the glass onto the *foot* of the
   charter to find out which chancery drew it, because that decides what the date
   even means. Decide which house would have had a witness, turn to that hand in
   the Kalendar of the Dead, and scan its years — remembering that the roll is
   silent about a great many living men and about every man it does not cover.
   And if something about the parchment is wrong in a way you cannot name, lift
   it into the candle.
4. **Fight the desk.** Two open books and a charter do not fit. The candle is not
   where you are reading. Something has to go on the rack, and something has to
   come back off it.
5. **Rule.** Melt the cake over the flame, lift the spoon clear, pour, choose a
   ring, press it and hold it. Where you press is where the die lands.
6. **Live with it.** They react, take their papers, and go. A few crumbs of wax
   stay on the blotter.

Then the door again, twice more, and the ledger.

## The candle is the day

One candle is one working day. When it drowns, the day is over wherever it has
got to — anyone still in the passage goes home unheard, and the ledger records
them by name with a blank where the ruling should be.

It burns **only during WORKING**: while somebody is standing at the desk waiting
on a ruling and you are deciding. Never while they are speaking, never between
callers, never while the ledger is open. The clock measures deliberation and
nothing else, which is the only version of this that is fair.

The important part is that the light **contracts** rather than merely dimming.
Reach is scaled harder than energy, so the pool of usable light pulls in around
the wick as the day goes: the desk you can actually read shrinks, the saucer
floods with wax, the flame gets small and mean, and the last stretch guts audibly.
Carrying the candle starts as a convenience and ends as the only way to work.

When it goes out the warm light is replaced by a cold morning through the
shutter — flat, directional, uniform, the exact opposite of a flame. The ledger
stays readable, and the warm-to-cold turn is the visual full stop on the day.

Finish all three yourself and the notary snuffs it himself, which is a different
ending from having it snuffed for him.

`day_seconds` in `data/world/world.json` is the pacing dial: 1200 by default.
**Drop it to 90 to watch the whole arc in one sitting.**

The pressure is never a stopwatch on screen. It is that everything you need takes
up room, the room runs out, and so does the light.

## The tablet

A boxwood tablet of blackened wax and a bronze stylus. It starts racked; the
memorandum tells you it's there.

**The game never reads a mark you make.** Not one. There is no parser, no
validation, no "correct note". You scratch whatever notation you invent — a
year, a tick, a cross, the shape of a lion — and the only thing that ever
interprets it is you, twenty minutes later, when you've forgotten why you wrote
it.

That is the whole reason it works. A notebook the game grades is a quiz. A
notebook the game ignores is a tool.

The verbs are the ones the desk already taught:

- **move** the stylus over the wax → it scratches
- **rest** the stylus on the wax → it warms and smooths the marks back flat

Resting is telegraphed by a dimple that grows under the nib for well over half a
second before anything is lost, so nobody smooths a page by pausing to think.
Smoothing through the middle of a line leaves both ends behind.

Every alternative to this was software — a text box, a checklist, a journal
screen — and any of them would have been the first thing in this game that
admitted it was a computer program.

## The Kalendar of the Dead

A dead man cannot witness a charter. That was checked, for a while, by reading the
death off the charter's own witness list — which meant the one document under
suspicion was also the only source for the fact that would have condemned it. A
forger who declined to write *obiit* defeated the check by omission.

Death now comes from a book the forger never had. **The Chancery keeps no
necrology of its own**; it keeps a bound volume of extracts returned by the houses
that do. Four hands return: the cathedral chapter of Saint Wend, the Margrave's
chapel at Thurnstadt, the city book of Marchfeld, and the Chancery's own
household. Three houses return nothing, for three different reasons, and the book
says so on a page of its own.

**The design is in the limits.** A complete imperial register of the dead would be
an oracle and would end the game. Every roll is partial three ways at once: it
covers one house, it is written up only so far, and it reckons in its own house's
style — the Saint Wend chapter counts from election like the rest of the Church,
so a clerk who reduces its obits as an imperial notary would gets a number three
years wrong. The roll states its reckoning on its own front page, which is what
makes that a trap rather than a cheat.

So the rule the check obeys above all others is that **absence from the rolls is
never evidence of life.** Silence produces a finding that names which roll was
consulted and where its knowledge stops, and never a defect. What to do about a
witness list nobody can verify stays with the notary, which is the entire point.

## Rasura, and what the candle is for

The commonest real medieval forgery was not a fabricated charter. It was a genuine
one improved after the fact: scrape the nap off the vellum with a knife, let it
dry, and write the year you would rather it said. The seal is real, the die was
alive, the witnesses were in the room, and the instrument is false.

No other check can see it, because every other check reads what the parchment says
and this is about what it used to say.

Detection is physical. Scraped skin is thinner than the skin around it, so **pick
the charter up and hold it near the flame**: the thin place transmits, the patch
goes amber, and the word somebody took out feathers back through it. At rest the
scrape is only a difference in the nap — present, findable, and meaningless on its
own, because scribes correct themselves and a rule that convicted on the mere
presence of an erasure would convict most genuine charters in Europe.

This is the fourth investigative verb and the first one that is not a lookup. It
also gives the candle a second job: until now the flame was pressure — light, and
a clock — and every second spent carrying it was a second spent. It is now an
instrument, which is the strongest argument the clock has for existing.

## The rack

Four pigeonholes on the back rail. Drop a book, a tool or a sheet over one and it
goes in, shrunk and out of the way; pick it up and it comes back out. Shelved
books close themselves. An occupied hole refuses a second thing.

This is what makes the cramped desk a decision rather than an annoyance — you
choose, one object at a time, what you are not using, and you pay for it by
having to fetch it again. It is emphatically not a tidy button: nothing arranges
itself and there is no "put everything away".

The desk is deliberately too small, and that is now something you can act on.

---

## What the game is about

Imperial law counts an emperor's years from his **accession**. The Church counts
from his **election**, which happened while his predecessor was still alive. Both
are ancient, both are correct, and they do not produce the same number.

So a charter can be impossible and unremarkable at the same time, depending on
who is reading it — and the question stops being "is this correct?" and becomes
"which authority am I choosing to satisfy?"

The three cases walk that idea:

1. **Küfergasse** — teaches the verbs, and teaches that an anomaly is not a
   crime. The seal is rubbed half to nothing and a witness died the same year;
   both are alarming and both are fine.
2. **Grellwater** — a forgery. Denying it is correct and cruel. Confirming it out
   of pity does not save her; it turns her charter into evidence against her.
3. **Kesselholt** — two laws read one date and reach two ends. Confirm serves the
   Church, Deny serves the Empire, Refer serves nobody and is the only honest
   answer.

Ruling on case 2 is written into the Register, and the petitioner in case 3
quotes it back at you. Correctly.

The people across the desk also watch the investigation. Research is not a
private checklist: the cooper remembers which side of the chest got wet when
your lens reaches the worn rim; the widow learns there were two Thurn dies when
you open the matrix book; the monk corrects which institution's seal you are
looking at. Each response is authored as data and fires once, so the petitioner
becomes a fallible source of evidence without becoming a hint dispenser.

They also fill silences. Work without touching anything for long enough and the
person across the desk says something — twice, at widening intervals, and then
they let you get on with it. The cooper apologises for taking your morning; the
widow asks you to tell her now if you are going to tell her; the monk notices
your candle is going. Doing anything at all resets the clock, so a player who is
actively working the packet is never prompted as though they had fallen asleep.

When a ruling is finished, a few crumbs of wax remain on the blotter. By the
third petitioner the desk has become a physical record of the day's irreversible
choices. The final Register also includes the authored aftermath of each branch
in a later hand: not only whether the law agreed, but what the wax caused after
the person left the room.

---

## Architecture

```
scripts/
  model/         Resource definitions. Schema, not content.
  rules/         Is this claim valid. No scene tree, no autoloads, no nodes.
  presentation/  Drag physics, wax, audio, drawing. Knows nothing about law.
  world/         Loads data/ into memory.
  session/       The shape of one day.
data/
  cases/         One JSON per case. Author new ones without touching a script.
  world/         Polities, reigns, seal matrices, the books, the Register seed.
  tuning/        .tres — live-editable in the inspector while the game runs.
```

**`scripts/rules/` never touches a node.** That single restriction is what makes
the rules runnable headless, and what makes adding the remaining verification
types (genealogy, palaeography, jurisdiction) a matter of writing one `Check`
subclass and appending it to a list in `adjudicator.gd`. Nothing else in the
project changes — the witness check and the erasure check were both added exactly
that way, and neither touched the policy, the ledger or any existing case file.

### How validation works

```
CheckContext { documents, matrices, reigns, polities, necrology, register, present_year }
       ↓
[ErasureCheck, SealCheck, DateCheck, WitnessCheck, AuthorityCheck, PrecedentCheck]
       ↓
Array[Finding]  →  VerdictPolicy  →  verdict
```

Order is doctrine. `ErasureCheck` runs first because every other check reads what
the parchment says, and if the parchment has been altered since it was sealed then
the reading they are all working from is the forger's. `SealCheck` outranks
`WitnessCheck` because the seal is authenticity and the witness list is formality.
`DateCheck` outranks `WitnessCheck` because the witness arithmetic is derived from
the date.

Checks never decide anything; they report `Finding`s with a severity. The policy
turns findings into a ruling and lives in `data/tuning/verdict_policy.tres`, so
"a defective instrument is referred rather than refused" is a line in a file
rather than a line in a script.

**There is no `is_forged` field anywhere in the data.** A forgery is *derived* by
asking whether any die that existed on the charter's date could have produced the
impression in front of you. Storing the answer would hardcode the rules into the
content, and every future check type would need its own boolean.

`CaseData.correct_verdict` still exists — but only as your assertion of intent,
checked against the derived verdict at startup and in the test. When they
disagree, the case is broken and you are told which.

### Why JSON for content and .tres for tuning

Content is JSON because a case is authored by hand in a text editor, diffs like
prose in a pull request, and carries no resource UIDs to desync between your two
machines. Every field is validated in `content_loader.gd` with the file and key
named in the error.

Tuning is `.tres` because the entire value of a tuning resource is dragging a
slider in the inspector while the game is running, and JSON cannot do that.

---

## Tuning the feel

Open the project, press F5, then open these with the game still running:

**`data/tuning/paper_feel.tres`** — the drag solver.

A sheet is a spring-driven body with the spring attached *at the point you
grabbed it*, not at its centre. Pulling off-centre applies a torque as well as a
force, which is why grabbing a charter by the corner makes it swing and grabbing
it in the middle makes it slide flat. One cross product, no special cases.

- `stiffness` — first dial to move. Lower = heavier, trails your hand more.
- `torque_gain` — the lean. Set it to 0 and paper becomes a decal.
- `max_lean_deg` — hard limit, so a fast flick can't spin a sheet like a propeller.
- `shadow_throw_per_layer` — how much a sheet floats above the pile below it.

Integrated in fixed 1/120s substeps, so it feels identical on the 60 Hz laptop
and the 144 Hz desktop.

**`data/tuning/wax_feel.tres`** — the melt, pour, and press.

The whole sequence runs on one verb: *hold still*. Hold the brass bowl over the
flame to melt a pre-pigmented beeswax-and-resin cake, carry it while it is hot,
hold over the blank foot to pour, then hold the ring through resistance. That
makes the drag solver load-bearing rather than decorative.

- `heat_time` / `melt_time` / `carry_cool_time` — how the solid tablet sweats,
  slumps, bubbles, and eventually skins over away from the flame.
- `resistance_time` / `resistance_creep` — the give. The money moment. Too short
  and it isn't felt; too long and it reads as a bug. Creep is never zero, or the
  player thinks the input was dropped.
- `good_low` / `good_high` / `blot_at` — the pour window. Wax spreads by *area*,
  so radius goes as √volume; over-pouring creeps up on you rather than being
  obvious.
- `ring_jitter_deg`, `opacity_jitter`, `seat_time_jitter` — no two impressions
  are identical.
- `blob_points` / `blob_jitter` — the silhouette. Below about thirty points the
  pool reads as a polygon rather than as something that flowed.

### The strike lands where the ring was

The die is recorded at the instant the wax gives, in the pool's own space, and
never recomputed. Press the middle of the pool and you get a whole device. Press
the rim and the metal hangs over the edge of the material, so:

- the device is **clipped to the wax** and simply stops where the wax stops
- the pool **bulges away from the strike**, because material squeezed out from
  under the die has to go somewhere
- the parchment keeps a faint pressed ring where the die met paper instead of wax
- `strike_coverage()` falls below 1.0, and a strike under 55% is graded as a
  botched seal in the ledger regardless of whether the ruling was lawful

Wax also pours wherever you tip the spoon, not at a magnet point. Seal across the
witness list and the ledger records that the writing was fouled.

The four authored wax plates are used for the cold crumbs left on the blotter,
not for the live pool — each plate has a rim and a sunken centre painted into it,
which is a centred impression baked in, and that is the one thing the pool must
not assert before the player has chosen where to strike.

### The candle

It is carried. Move it and the whole desk relights: shadows swing round and
lengthen, parchment near the flame goes amber, the far corner goes dark, and the
person across the desk comes out of the shadow when you bring the light forward.

Three lights share one flicker value so they never beat against each other — a
tight core, a shadow-casting key, and a wide dim bounce that keeps the room from
reading as a spotlight in a void. Falloff is generated as a true inverse-square
curve rather than painted; a linear radial gradient reads as a flat disc of
brightness with a visible rim and no amount of energy tuning fixes it.

Flicker moves energy, reach, colour temperature **and the flame's position**
together. The position wander is the one that matters: it makes every shadow on
the desk swim very slightly, and it is the strongest single cue that the light is
fire rather than a lamp.

Only objects with height occlude the light. A sheet of parchment is a tenth of a
millimetre thick — giving it an occluder threw a hard wedge of darkness across
the desk that read instantly as a bug. Papers get a contact shadow whose density
tracks how much light actually reaches them; books, rings, the lens and the spoon
get both.

`data/tuning/paper_feel.tres` still owns the contact shadows: `shadow_alpha`,
`shadow_layers`, `shadow_base_throw`, `shadow_throw_per_layer`. The ambient floor
is `Desk._ambient` — raise it if the far corners are too dark to hunt in, but
every point of ambient is contrast the flame no longer has.

---

## Three columns, never one number

The ledger at the end of the day reports:

- **Soundness** — did you follow the law
- **Favour** — who is pleased with you (derived from nothing; politics is authored)
- **Craft** — how your hands did. Thin, blotted, smeared, shallow, or fine.

They are allowed to disagree, and they do. Combining them into a score would be
the fastest possible way to ruin this.

---

## Cross-machine notes

`.gitattributes` normalises line endings to LF. Without it you get whole-file
diffs every time you switch between the Mac and the Windows desktop.

**Commit the `*.uid` files.** Godot 4.4+ writes a `.gd.uid` next to every script;
if those are missing, the other machine generates different UIDs and every scene
shows as modified. `.gitignore` deliberately does not exclude them.

`project.godot` declares `config/features = ("4.3", "GL Compatibility")`. A
project declaring an *older* version opens with a mild notice in a newer editor;
one declaring a *newer* version can genuinely break in an older one, so it is
pinned low on purpose. Change that one line to match your exact version if you
prefer.

Renderer is `gl_compatibility` rather than Forward+: this is flat 2D, it runs on
anything including an old Mac, it starts faster, and it avoids Metal/MoltenVK
driver differences between your two machines.

The repository lives at `github.com/PatheticPants/HREGAME`, on `main`.

---

## Not built, on purpose

No settings menu, no save system, no tutorial overlay, no score screen, no extra
case document types, and no fourth case. The onboarding that exists is the
movable memorandum R.V. left on the desk. The Register and the separate
soundness/favour/craft judgements are deliberately present because this day
depends on them; the economy and the remaining verification types still have a
place in the schema and nothing more.
