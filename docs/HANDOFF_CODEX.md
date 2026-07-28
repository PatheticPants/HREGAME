# Hand and Seal — handoff for a fresh reviewer

You are being brought onto a project that already exists and works. Nothing here
is a greenfield brief. What is wanted from you is **fresh eyes**: think outside
the box, challenge the design and gameplay choices, and tell us where they are
wrong or timid.

Read the whole document before responding. There is a specific request at the
bottom about subagents.

---

## 1. What the game is

**Hand and Seal.** A *Papers, Please*-style document-inspection game set in a
fictionalised Holy Roman Empire. Godot 4, GDScript, desktop, single player.

You are a low-born notary of the Imperial Chancery. Petitioners bring claims to
land and title — charters, wax seals, witness lists, genealogies — and you verify
each claim against a body of law and then rule on it.

**The premise that makes it not-Papers-Please:** the Empire's legal authorities
overlap and disagree. Imperial law, regional custom and church law can each say
something different about the same document. So the player's question is usually
not *"is this correct?"* but **"which authority am I choosing to satisfy?"**

The long campaign builds toward a contested imperial election in which every
ruling has quietly shifted land and votes between the great houses. **None of
that is built.** What exists is a vertical slice: one working day, three
petitioners.

### The concrete mechanic that carries the premise

A regnal date — *"in the fourteenth year of Emperor Aldric"* — is not a date
until you know **which chancery wrote it down**, because chanceries count from
different events:

- Imperial notaries count from **accession** (the day the last emperor died)
- The Church counts from **election** (the day he was chosen King of the Romans,
  which happens *in his predecessor's lifetime* and can precede accession by years)
- Some older instruments count from **coronation at Rome**, later still

Aldric was elected 1201, acceded 1204, crowned 1206, died 1215. So "the
fourteenth year of Aldric" is **1217** (impossible — he was two years dead) *and*
**1214** (unremarkable). Both readings are ancient and correct.

The second mechanic ties to the first: **a seal matrix is defaced when its holder
dies**, so a seal can be visually perfect and still void — and you can only
establish that by converting the date first. Neither verification is soluble
alone. That interlock is deliberate.

---

## 2. The design pillars

These are load-bearing. Argue with them if you think they're wrong — that is
what you're here for — but understand them before you do.

**Game feel is the deliverable, not features.** Two documents that feel excellent
beat eight that feel like UI. If dragging paper and pressing the signet don't
feel good in isolation, nothing else matters.

**Diegetic only.** No floating HUD, no menus over the world, no health-bar
meters. The rulebook is a physical book. The seal reference is a physical book.
The candle, the lens, the wax spoon, the rings, the note tablet are objects you
drag. Everything the player uses takes up desk space. There is currently exactly
**one** screen-space element in the entire game (a keyboard hint that permanently
retires itself a few seconds after first use).

**The desk is deliberately too small.** Papers overlap and get buried. Digging
for the one you need is a mechanic, not a bug. There is no "tidy desk" button and
no auto-arrange. (There *is* a storage rack — see below — but you carry one
object to one hole, by hand.)

**Content is data, not code.** Cases, documents, seal matrices and the regnal
table live in JSON under `data/`. New cases are authored without touching a
script.

**Presentation and rules are separated absolutely.** `scripts/rules/` never
touches a node, a signal or the scene tree. It takes an explicit context object
and returns findings. This is what lets the entire rules layer run headless.

**There is no `is_forged` field anywhere in the data.** A forgery is *derived* by
asking whether any die that existed on the charter's date could have produced the
impression in front of you. Storing the answer would hardcode the rules into the
content and every future check type would need its own boolean.

**Three columns of judgement, never combined into one number.** Soundness (did
you follow the law), Favour (who is pleased with you), and Craft (how your hands
did). They are allowed to disagree, and they do. Merging them into a score would
ruin the game.

**Everything the player is told was findable must actually have been on the
desk.** This is the genre's non-negotiable contract. It has been violated twice
in development and both were treated as critical defects.

---

## 3. What is actually built

### The day

One candle is one working day. Knock → petitioner enters and sets down a packet →
they speak → you investigate → you rule in wax → they react and leave → next
knock. Three petitioners, then the ledger.

**The candle is the only clock.** It burns *only* while somebody is at the desk
waiting on a ruling and you are deciding — never during dialogue, arrivals,
departures or the ledger. The clock measures deliberation and nothing else. When
it drowns, the day ends wherever it has got to; anyone still in the passage is
recorded by name with a blank where the ruling should be, and the one who was
standing at the desk gets a *different, worse* entry: "Heard, not ruled."

`day_seconds` in `data/world/world.json` is the pacing dial (1200 default; drop
to ~90 to watch the whole arc quickly).

### The light

The candle is carried. Moving it relights the entire desk. Three lights on one
shared flicker value (tight core, shadow-casting key, wide dim bounce), with
falloff generated as a true inverse-square curve rather than a painted gradient.
Flicker modulates energy, reach, colour temperature **and the flame's position**
together — the position wander is what makes every shadow swim.

As the candle burns down the light **contracts** rather than merely dimming:
reach is scaled harder than energy, so the readable desk shrinks and carrying the
flame goes from convenience to necessity. When it dies, warm light is replaced by
cold directional morning through a shutter so the ledger stays readable.

Only objects with height occlude the light. Paper does not — a sheet is a tenth
of a millimetre thick, and giving it an occluder threw a hard wedge of darkness
across the desk. Papers get a contact shadow whose density tracks how much light
actually reaches them.

### The press (the "money moment")

Melt a vermilion resin cake in a brass spoon over the flame → lift it clear →
carry it hot → hold steady over the sheet to pour → choose one of three signet
rings → hold it steady on the pool → it descends, meets **resistance**, gives,
seats → let go and it peels and strings and snaps.

Every phase runs on one verb: **hold still**. That makes the drag solver
load-bearing rather than decorative — stopping a momentum-carrying object exactly
where you want it is a skill you acquire in the first thirty seconds of handling
paper, and the press cashes it in.

**The die strikes where the ring was.** Not the centre of the pool. Press the rim
and the device is clipped by the material and simply stops at the edge of the
wax; the pool bulges away from the strike because displaced material has to go
somewhere; the parchment keeps a faint pressed ring where metal met paper instead
of wax; and coverage below 55% is graded a botched seal regardless of whether the
ruling was lawful.

Wax pours where you tip it, not at a magnet point. Seal across the witness list
and the ledger records that the writing was fouled.

**Picking up a ring IS the ruling.** No confirmation step, no undo.

### The drag

Paper is a spring-driven body with the spring attached at the exact point you
grabbed it, not at its centre — so pulling off-centre applies a torque as well as
a force, and grabbing a charter by the corner makes it swing while grabbing it in
the middle makes it slide flat. One cross product, no special cases. Integrated
in fixed 1/120s substeps so it feels identical at 60 and 144 Hz.

Objects have per-object `weight` (ring 1.65, candle 0.55) so a signet does not
drag like a charter.

### Storage

Four pigeonholes on the back rail. Drop a book, tool or sheet over one and it
slides in, shrunk and out of the way; pick it up and it comes back. Shelved books
close themselves. An occupied hole refuses a second thing. The hole warms as you
carry something toward it, so the action telegraphs before it commits.

### The note tablet

Boxwood tablet of blackened wax and a bronze stylus. **Move** the stylus over the
wax and it scratches; **rest** it and the wax warms and smooths back flat
(telegraphed for 0.6s so nobody erases a page by pausing to think).

**The game never reads a mark you make.** No parser, no validation, no "correct
note". A notebook the game grades is a quiz; a notebook the game ignores is a
tool. Every alternative considered (text box, checklist, journal screen) would
have been the first thing in the game that admitted it was software.

### The lens

A seal's legend is not legible without it. Neither is the closing formula at the
foot of a charter — set at 7pt and faded, because that line names **which
chancery drew the document**, which decides what the date means. Under the glass
it spells out the chancery, its reckoning, and the reduced year. You can also
hold the glass over a seal *you* struck and be told what your hands did.

### The Register

The previous notary's rulings, on the desk as a physical book, growing during the
day with your own. It is the campaign's third source of law: a petitioner can
quote your own precedent back at you and be right to. One seeded entry is a
recorded bribe, in the same hand as the helpful ones.

### The people

Frontal pixel-art portraits with restrained breathing, blinking and weight
shifts. They react to what your hands do — the cooper remembers which side of the
chest got wet when your lens reaches the worn rim; the widow learns there were two
Thurn dies when you open the matrix book; the monk corrects which institution's
seal you are looking at. Each fires once. They also fill long silences twice, at
widening intervals, and doing anything resets that clock.

### The two-view camera

Default shows ~70% desk. `W`/`Up`/wheel-up looks toward the petitioner and
foreshortens the whole desk plane around its far edge; `S`/`Down`/wheel-down
returns. Desk interaction is gated while looking up.

---

## 4. The three cases

Deliberate arc: **learn the job → the job is cruel → the job is impossible.**

1. **The Plot on Küfergasse** — Wilhelm Ott, a nervous cooper. Everything checks
   out. Two anomalies (a seal rubbed until four letters of the legend are gone, a
   witness who died the same year as the charter) are both alarming and both
   fine. **CONFIRM.** The lesson is that an anomaly is not a crime — a player who
   denies this has learned the wrong reflex.

2. **The Mill at Grellwater** — Adelheid Vesser, a widow. Her charter burnt in a
   real fire and she paid a man four marks to draw it again; he sealed it from an
   old impression of a die defaced six years before the charter's date. **DENY**
   — and it is correct and cruel. Confirming it out of pity does not save her; it
   turns her charter into evidence and she is called to answer for it.

3. **The Woodland of Kesselholt** — Brother Anselm, serene and certain. The date
   is impossible under imperial reckoning and unremarkable under the church's,
   and the chancery that drew it is named in the small hand at the foot. Confirm
   serves the Church, Deny serves the Empire, **REFER** serves nobody and is the
   only honest answer. He also quotes your ruling on the widow back at you, with
   three authored variants depending on what you did and whether you were right.

---

## 5. Architecture

```
scripts/
  model/         19 files. Resource definitions. Schema, not content.
  rules/         12 files. Is this claim valid. No nodes, no scene tree, ever.
  presentation/  28 files. Drag physics, wax, light, audio, drawing.
  world/         Loads data/ into memory.
  session/       The shape of one day.
data/
  cases/         One JSON per case.
  world/         Polities, reigns, matrices, the books, the Register seed.
  tuning/        3 .tres — live-editable in the inspector while running.
art/             19 authored pixel-art PNGs.
audio/           31 procedurally generated placeholder wavs (tools/ regenerates).
.claude/agents/  5 subagent definitions.
```

**Validation pipeline:**

```
CheckContext { documents, matrices, reigns, polities, register, present_year }
        ↓
[SealCheck, DateCheck, AuthorityCheck]  →  Array[Finding]  →  VerdictPolicy  →  verdict
```

Checks never decide anything; they report `Finding`s with a severity. The policy
turns findings into a ruling and lives in a `.tres`, so "a defective instrument
is referred rather than refused" is a line in a file. Adding a verification type
is: write one `Check` subclass, append it to a list. Nothing else changes.

`CaseData.correct_verdict` is the author's *assertion of intent*, checked against
the derived verdict at startup and in tests. When they disagree the case is
broken and you are told which.

**Why JSON for content and .tres for tuning:** JSON has no resource UIDs to
desync between the two dev machines (Mac + Windows on one repo), diffs like prose
in a PR, and is validated in one place with the file and key named in the error.
Tuning stays .tres because its whole value is dragging a slider while the game
runs.

---

## 6. Test and tooling state

Everything below currently passes.

| | |
|---|---|
| `tests/test_rules.gd` | **22 checks** — headless, no scene tree. Regnal arithmetic, worn-legend matching, every case's ground truth vs derived verdict, policy ordering. |
| `tests/test_presentation.tscn` | **103 checks** — real desk, headless. Reachability, the two-view transition, candle light and shadow direction, storage, the tablet, the press through all phases, the ledger, evidence-reachability. |
| `tests/test_session.tscn` | **30 checks** — the whole day through the real controller at real timings, plus a second day where the candle drowns mid-case. |
| `tools/verify_content.py` | Independent Python re-implementation of the rules, plus an encoding guard (UTF-8 / no BOM / LF / no cp1252 round-trip damage) over 87 text files. |
| `tests/qa_capture.tscn` | Writes annotated screenshots. **Not** headless — Godot can't render 2D lights with the dummy driver. |

Godot 4.6.3 is vendored at `.tools/` (gitignored). `project.godot` declares 4.3
in `config/features` deliberately — a project declaring an older version opens
with a mild notice in a newer editor, whereas the reverse can genuinely break.
Renderer is `gl_compatibility`.

**Known caveat:** dialogue only advances on a click, so any automation that
doesn't click will hang.

---

## 7. Where fresh eyes are most wanted

Be blunt. These are the places we are least confident.

1. **Is the loop actually fun, or just well-made?** Three cases is a slice. Does
   the investigate → rule → live-with-it cycle have enough pull to sustain
   twenty cases? What is missing that would make someone want the fourth one?

2. **Is "which authority" legible in play, or only on paper?** The premise is
   strong in a design doc. We are not certain a player *feels* the dilemma rather
   than solving a lookup puzzle.

3. **The candle as the only clock.** Real stakes, or an annoyance dressed as
   atmosphere? It currently cannot be replaced, refilled or bought.

4. **No feedback until the ledger.** The player learns whether they were right
   only at end of day. Deliberate (the petitioner's reaction is the immediate,
   emotional feedback). Is the delay building tension or hiding the game?

5. **Favour is authored per case, not derived.** Politics can't be computed from
   documents. But that makes it the least systemic of the three columns. Is that
   a problem at campaign scale?

6. **What is the second day?** The Register survives and `RulingRecord` carries
   everything, but nothing yet spans sessions. This is the biggest unbuilt thing
   and the campaign premise depends on it.

7. **Difficulty and teaching.** There is no tutorial — a memorandum from the
   previous notary sits on the desk and the reference books explain themselves.
   Is that enough, and does case 1 teach the right reflex?

8. **What have we over-built?** Genuinely useful answer. Some of the detail work
   (wax displacement, three-light rigs, per-object drag weight) may be effort
   that would have been better spent on content.

**Please do not** propose: a settings menu, a save system, a tutorial overlay, a
score screen, floating UI of any kind, or combining the three judgement columns
into one number. Those are settled.

---

## 8. Request: subagents

We use Claude Code with specialised subagents defined as markdown files with YAML
frontmatter in `.claude/agents/`. Five exist:

| name | role |
|---|---|
| `loremaster` | Canon: polities, houses, customs, names. Keeps a persistent project memory as the bible. Hard cap of 6–9 polities. |
| `case-writer` | Authors cases as data. Must state the decisive fact and the exact inspection path to it. |
| `feel-critic` | Read-only. Phases, easing, weight, variance, audio hooks, diegetic violations. Deliberately adversarial. |
| `godot-reviewer` | Read-only. Cross-platform safety first, then separation of concerns and idiom. |
| `rules-auditor` | Read-only. Assumes every case is broken until proven otherwise. Hunts for *second solutions* — sound reasoning that reaches the wrong verdict. |

**What we want from you:** propose **additional** subagents that would help you
brainstorm ideas and review design choices — roles that are missing from the five
above. For each, give us the complete file: YAML frontmatter (`name`,
`description`, `tools`, `model`, optionally `memory: project` and `color`) and
the system prompt as the markdown body.

Make them opinionated and give them non-negotiable constraints, the way the five
above have them. A reviewer that agrees with everything is worthless. Say plainly
which ones you would actually reach for and which are nice-to-have.

Roles we have wondered about but not written: a player-advocate / first-time-user
agent, a pacing-and-difficulty-curve agent, an economy-and-progression agent, an
audio-direction agent, a narrative-continuity agent. Take or leave those — your
own suggestions are more valuable than confirmation of ours.

---

## 9. The bar

Every suggestion, feature and critique should be measured against four things:

- **Thoughtful detail.** The reason to care about this game is that somebody
  clearly thought about what a chancery desk is like. Detail that is merely
  decorative is not the same as detail that carries meaning.
- **Fun.** It has to be a game, not a simulation with good prose.
- **Interesting concepts.** Prefer the idea nobody else has done to the
  well-executed familiar one.
- **Satisfying.** Physical, tactile, consequential. The press, the strike, the
  weight of paper, the sound of a book going into its hole.

If something fails those, say so and say why — including anything described above
as settled. Being talked out of a bad decision is worth more to us than
agreement.
