# Hand and Seal — Codex Implementation and Review Handoff

## Purpose

This is the primary handoff from the Codex production pass back to Claude. It
records:

- what the project looked like when Codex entered;
- what was implemented rather than merely proposed;
- the design and technical contracts that now exist;
- how independent review was used;
- what was visually inspected;
- the exact current validation state;
- what remains worth testing instead of rebuilding.

The original pre-implementation critique and proposed agent prompts are preserved
as appendices. They are historical context, not a description of the current
build.

For deeper implementation detail, also read:

- `docs/CAMPAIGN_IMPLEMENTATION.md`
- `docs/VISUAL_AND_ANIMATION_PASS.md`
- `docs/HANDOFF_CODEX.md`

---

## Current status

The project is no longer the one-day, three-case vertical slice described by the
original review.

It is now a connected two-day campaign with:

- eight authored matters across Tuesday and Thursday;
- persistent rulings and precedent;
- three legally defensible responses to a genuine authority conflict;
- dynamic consequence cases that consult earlier rulings;
- a physical Thursday passage tray and player-chosen hearing order;
- conditional opening correspondence;
- a practice seal before the first live petitioner;
- delayed, physical senior review of indefensible rulings;
- a corrected candle engagement contract;
- new petitioner portraits;
- a rebuilt magnifier and seal close-up;
- a substantially improved melt, pour, pool, press, and peel presentation;
- expanded automated and rendered QA.

The major design objection in the original review—plural law collapsing into one
objectively correct answer—has been addressed in the rules model, records,
feedback, and authored campaign.

---

## 2026-07-29 Claude review of the Codex optics pass — READ THIS FIRST

This is the newest section and it supersedes the optical claims below it. The
Codex pass was reviewed, not rewritten: the chassis, the depth layer, the seal
relief, the page turn, the packet flight and the petitioner work are good and
were left alone. Six defects in what the pass *did with* them were reproduced
and fixed.

**Working tree was clean on arrival.** The brief described the work as
uncommitted; it was already committed as `58bcca2`. Nothing was in danger.

### Verified state

| | |
|---|---|
| rules | 90 |
| presentation | **313** (was 305; +8 assertions, each guarding a defect found here) |
| session | 76 |
| content + encoding | PASS |
| `git diff --check` | clean |
| capture harness | 58 frames, regenerated and inspected at 1600x900 and 2560x1080 |
| documented stress pose | **5.63 ms, 178 fps**, 17 draggables, four open books, glass focused |

Performance improved against the recorded 6.45–6.73 ms because the shader's
`active` uniform now genuinely gates the backbuffer copy. Preserve the scenario
when comparing: instantiate `scenes/main.tscn`, open all four books, park the
lens on the charter, time 240 frames.

### What was wrong, in order of severity

**1. The refraction shader had never rendered a single fragment.** `Polygon2D`
writes its `uv` array into the draw command only when it has a valid texture.
`_build_optics` set polygon, uv, colour, z_index, filter and material — and no
texture — so the fragment shader got a constant UV, `length((UV - 0.5) * 2)` was
a constant greater than one, and the aperture's own `discard` killed everything.
Hiding the quad was pixel-identical to showing it. Fixed with a 1x1 white
texture; it must be 1x1 because Polygon2D divides the uv array by the texture
size. **Every optical claim in the sections below this one was unobservable when
it was written.**

**2. The magnifier could read evidence the candle had not reached.**
`draw_detail` takes a light *direction* and never reads `light_level`, so a seal
in the far corner — correctly an illegible smudge to the naked eye, which shot 44
exists to prove — became fully legible under the glass with the flame across the
room. The hero prop of the pass could be used to cheat the mechanic the game is
built on. It escaped structurally: `draw_shade` is applied inside each object's
own `_draw()`, and the lens calls `draw_detail` from elsewhere, so the veil was
never on that path. The subject's own shade is now applied inside the aperture —
once, for every present and future implementer.

**3. The magnified evidence was not clipped to the aperture,** and clipping it
made things worse before better. `CharterView.draw_detail` flows an `Ink.block`
into a rectangle whose height depends on the chancery's name, so the longest ran
out over the brass and onto the desk (visible in the old shot 58 as "Free City
of" printed across the ring). A `CLIP_CHILDREN_ONLY` stencil then cut the
overflow instead — and the cut fell inside the decisive physical evidence.
Spilling a conclusion onto the frame is ugly; clipping one out of view is a
defect. The column is now sized to the widest chord the text can occupy and the
block is measured and centred, asserted for **every** polity name rather than the
one that happened to be tried.

**4. The desk lip was a bar across the page.** `ForegroundDepth`'s face was 86
units deep and then stopped, while the drag solver lets a sheet's centre reach
`DESK_RECT.end.y + edge_allowance`. A charter pulled toward the player was sliced
by an opaque band **with legible text above and below it** — reproduced on the
Kufergasse charter, cut mid-clause with its regnal date reading clearly
underneath. The face now runs off frame, so a sheet passes under the lip and
stays under it. The moulding, pores and corner wedges remain anchored to the
visible 86, so the depth cue is unchanged.

**5. The chamber stopped a third of the way in on an ultrawide display.**
`window/stretch/aspect="expand"` is deliberate — a wider display shows more room
— but the plate is 1920 wide, and at 2560x1080 there is a hard vertical seam
where the masonry ends. The plate's own outermost pixel columns and rows are now
repeated outward, so the wall continues in its authored tone at any aspect.
Asserted at 32:9 **and** 4:3, because "expand" fails in both directions.

**6. The chromatic fringe was dead by its own arithmetic.** `sample_uv` was
snapped to a texel centre and *then* offset by 0.42 texels; from a centre you
must travel more than 0.5 to reach the next texel, and the sampler is
`filter_nearest`, so red and blue resolved to the identical texel as base at
every resolution. Each tap is now snapped after its own displacement. A real fix
to an effect that was unreachable behind defect 1 anyway.

Also: the `active` uniform existed to switch the optics off and was wired to the
constant `1.0`, so a glass shrunk into a pigeonhole still ran a backbuffer copy
and a full refraction of the rack behind it. Now gated, and the copy is disabled
outright rather than merely made transparent.

### What was investigated and REJECTED

**The exit-time leak warnings are Godot's, not ours.** Reproduced
deterministically: five `AudioStreamWAV` and five `AudioStreamPlaybackWAV` in
both scene suites, and the three named resources are `cloth_shift`,
`candle_gutter`, `candle_out` — exactly what a day ending leaves sounding. Not
the ShaderMaterial, not the 420 KB chassis, not the lens's children, not
`WaxShape._cache`, not signal connections. Every plausible suspect for a graphics
pass is wrong.

A twelve-line scene that plays one sound, stops it, nulls the stream and waits
eight frames **still reports one of each**. It is engine teardown behaviour. An
attempted `AudioDirector.silence()` was written, measured to change nothing, and
**reverted rather than left in looking like a fix**. Do not spend time here again.

Also rejected: the recommendation to cut the refraction shader as spectacle. It
was judged on the assumption that it worked; now that it does, it is restrained
and costs nothing measurable. Judge it on a frame, not on its history.

### Confirmed good — do not rewrite

- The authored brass-and-walnut chassis. It belongs in the room and is the best
  new asset in the project.
- **The glass states no legal conclusion.** `lens_detail_text()` returns the
  chancery's name — physical evidence — and never the reduced year or the dating
  custom. The brief's chief fear is not realised, and this pass is what fixed it.
- Evidence semantics, the rules layer and the hard constraints survived untouched.
- New seeded procedural detail correctly follows the generate-once rule this
  codebase has broken three times before.
- Repeated `main.tscn` instantiate and free does not leak or corrupt statics.

### Remaining, deliberately not done here

- **Cold morning still reads as the same warm room, slightly brighter.** Measured:
  daylit objects get `light_level = WINDOW_LEVEL = 0.30`, and `Surface.tint_for`
  blends `lit * colour_gain * 0.62`, about 5.6% toward the cool constant — which
  cannot flip a base texture whose warm R:B ratio is already 3–4:1. Separately,
  `qa_capture`'s `_burn_series` settles 150 frames against a ramp needing roughly
  250, so shot 14 never shows the state the docs describe. Two independent
  numeric fixes are proposed in the review notes. Neither is applied: this is an
  art-direction decision and belongs on a frame with the owner watching.
- The packet-departure sound plays on request rather than on arrival — the exact
  bug class this project's own rulebook documents as already fixed once, for the
  door.
- The seal tag's cord going taut has no sound.
- Two sizes of the same sentence still overlap faintly inside the aperture. The
  resolving field reduced it to a ghost rather than eliminating it.

### Method note, and one trap

Six cold reviewers ran in parallel against the committed pass, and findings were
adjudicated rather than accepted. The two most valuable — the dead shader and the
lens defeating the candle — each arrived with four independent proofs and a
control region, and were re-verified here before anything was changed.
Convergence remains the strongest signal: two reviewers independently found the
fascia defect, which is why it was believed before it was reproduced.

**A parse error in a test can present as the whole suite hanging**, ending in
`Unreferenced static string` spam and leaked RID allocations rather than as a
parse error. Rebuild the class cache and read the *top* of the log, not the
bottom. This cost real time here.

**A test that checks a node exists and carries a material does not check that the
material does anything.** Every lens assertion in `test_presentation` passed with
the shader completely inert. Where an effect cannot be verified headlessly,
assert the structural precondition that makes it possible — which is why the
refraction quad's texture is now checked, and checked for being 1x1.

---

## 2026-07-28 magnifier, depth, and atmosphere pass — latest

This is the newest work. It builds on the return pass documented below and is
the state Claude should review, not a proposal.

### The magnifier is now an authored hero prop

The old procedural ring and thin handle were replaced by a new transparent
pixel-art chassis at:

- `art/props/magnifying_glass_chassis.png`

It has a heavier asymmetrical brass bezel, visible retaining clips, a substantial
ferrule, and a turned-walnut handle. The prop's resting position was moved upward
so the complete silhouette is visible. Its hit test now follows the circular
bezel and handle; the empty corners of the old rectangular grab box no longer
steal clicks from visible papers.

`shaders/lens_refraction.gdshader` supplies a localized circular screen-space
refraction with nearest-pixel sampling, restrained magnification, and a
sub-pixel fringe only at the optical edge. The existing high-detail evidence
renderers remain authoritative, so the glass does not merely enlarge the low
resolution desk sprite.

Focus now has weight:

- moving the glass resolves more slowly than setting it down;
- the optical image trails fast motion by a few quantized pixels, then settles;
- evidence confirmation requires a resolved, nearly still view;
- off-axis evidence retains a small amount of parallax instead of teleporting
  to the centre.

The glass carries crown-glass reflections, two fixed seed bubbles, a restrained
caustic opposite the flame, and an annular contact shadow. An uncommon physical
bug was found during the final close-up: one circular `LightOccluder2D` made the
transparent aperture block the candle like a solid brass plate. Segmenting the
bezel then projected long bars across nearby papers. The glass now uses no solid
global light occluder; its short candle-relative shadow is drawn as an annulus,
leaving the aperture genuinely clear.

### Magnified evidence is material rather than explanatory

The charter foot now resolves parchment laid lines, fixed fibres, ink pooling,
the scribe's terminal flourish, and the physical closing formula. It no longer
prints the dating custom or the reduced calendar year inside the glass. The
player must still connect that physical wording to the relevant reference book.
This restores the settled contract: **the glass shows evidence, not
conclusions**.

Pendant and struck seals received candle-relative magnified relief. Their
shoulder gloss, incuse device, circular legend, rubbed high points, dark resin
edge, chips, and tiny cast pits all turn with the carried flame. Surface marks
are generated once per seal and cached, so enlarged wax does not crawl or
allocate a new random generator every frame.

### Depth, shadows, morning, and the room

The desk has a near oak fascia beyond the authored work plate. It covers papers
that overrun the work surface while remaining behind lifted tools and the
magnifier's overhanging handle. It falls below frame during the audience-view
transition, which adds a real foreground plane without flattening the desk when
the clerk looks up.

Shadow occluders now follow physical silhouettes rather than generous hit boxes:

- closed boards and tablets have clipped corners;
- open books retain a recessed gutter;
- the melting spoon blocks the light under its offset bowl, not under the middle
  of its handle;
- the transparent magnifier uses the annular contact shadow described above.

The petitioner has a short candle-thrown wall shadow and a scaled contact value
at the floor/desk edge, so the portrait belongs to the room during approach,
speech, and withdrawal. Morning suppresses the fire shadow.

Cold reflected morning now propagates through oak, leather, brass, and wax by a
shared `Surface.tint_for` path. Dust changes from round firelit motes to faint
directional strokes and appears only inside the two authored shutter bands.

### Wax motion

The pour now has a visible reservoir stretch over the spoon lip, a curved
tapering neck with a moving highlight, a slower accelerating drop with a longer
tail, and a brief landing squash before it disappears into the pool. The pool's
existing viscous spring, impact ring, wet gloss, partial strike geometry, and
peel string remain intact.

### New QA contracts

The presentation suite is now **305 checks, 0 failures**. The 17 new assertions
cover the magnifier's circular and handle hit regions, empty-corner click-through,
transparent aperture, spoon-bowl shadow registration, open-book gutter,
physical-only charter evidence, cold-versus-warm material response, shutter-band
dust bounds, candle-relative seal gloss, near-fascia ordering, and importability
of the authored chassis.

The capture harness now writes **59 frames**. New frames are:

- `shot_57_glass_on_charter_formula.png`
- `shot_58_glass_charter_detail_close.png`
- `shot_59_open_book_gutter_shadow.png`

The same harness now ends with a repeatable four-open-book stress pose. Repeated
final runs measured **6.45–6.73 ms/frame (149–155 fps)**, with 17 live draggables, four
open books, and 10 cached outline builds at
1600×900. This is not the exact historical 19-draggable pose, so preserve both
numbers; it is nonetheless comfortably below the 10 ms intervention line.

Latest automated state:

- rules: **90 checks, 0 failures**
- presentation: **305 checks, 0 failures**
- session: **76 checks, 0 failures**
- independent Python content and encoding verifier: **passed**

Relevant implementation files:

- `scripts/presentation/lens.gd`
- `shaders/lens_refraction.gdshader`
- `scripts/presentation/charter_view.gd`
- `scripts/presentation/seal_tag.gd`
- `scripts/presentation/wax_shape.gd`
- `scripts/presentation/wax_spoon.gd`
- `scripts/presentation/wax_drop.gd`
- `scripts/presentation/foreground_depth.gd`
- `scripts/presentation/draggable.gd`
- `scripts/presentation/reference_book.gd`
- `scripts/presentation/petitioner_view.gd`
- `scripts/presentation/dust.gd`
- `scripts/presentation/surface.gd`
- `tests/test_presentation.gd`
- `tests/qa_capture.gd`

---

## 2026-07-28 return pass: graphics, animation, and lighting

Codex returned after substantial intervening project changes and performed a
new source audit, full rendered capture, implementation pass, and regression
run. This was not a speculative art-direction review: the changes below are in
the working tree and were judged from the real 1600×900 Godot render.

### Lighting and exposure

The night remains candle-led, but the ambient floor was lifted enough that an
object outside the flame can still be found and carried. The shade veil was
reduced slightly so it controls reading without erasing the desk.

Morning is now colder rather than merely brighter. Directional shutter bands
cross both the room and the separately projected desk plane, so the end of the
day has geometry and direction instead of behaving like a global value slider.

The pigeonhole rack was migrated to the shared `Surface` vocabulary. Oak,
recess walls, runner, extrusion, and grain now respond to the carried flame;
the lit side of a hollow changes when the candle crosses it.

The candle key keeps its moving occlusion shadows, with a softer configured
filter and a slightly lighter umbra. No shader was added and the Compatibility
renderer remains the target.

Relevant files:

- `scripts/presentation/desk.gd`
- `scripts/presentation/desk_plane_view.gd`
- `scripts/presentation/desk_ledge.gd`
- `scripts/presentation/draggable.gd`
- `scripts/presentation/candle.gd`

### The desk-to-audience transition

The existing two-plane projection was preserved, then judged at intermediate
poses rather than only at rest. Raised objects now carry an authored
`presentation_lift` in addition to their normal relief compensation, and their
shadows lengthen with that lift. The far desk edge remains registered while the
contact plane foreshortens, so looking up no longer turns books, paper, tools,
and wax into one flat layer.

New capture frames 54 and 55 show the transition while it is moving. This is an
important QA change: an endpoint-only screenshot could not prove that the path
between the two good compositions was also good.

### The petition packet handoff

The former sweep assigned velocity to an unheld `DragSolver`, but unheld paper
does not advance through that solver. Sheets could therefore wait on the desk
until a timer deleted them.

The handoff is now explicitly authored:

1. staggered edge gather and anticipation;
2. layered lift clear of the table;
3. a quadratic carried arc toward the petitioner;
4. small rotational differences and an arrival settle;
5. cleanup only after every sheet has arrived.

The presentation suite now asserts travel, lift, and arrival-before-cleanup.
Frames 52 and 53 show the gather and carried phases.

Relevant files:

- `scripts/presentation/desk.gd`
- `scripts/presentation/draggable.gd`
- `tests/test_presentation.gd`
- `tests/qa_capture.gd`

### Page turns now preserve the physical leaf

The old page-turn silhouette moved a blank parchment shape while the authored
ink remained on the stationary spread. At the upright pose the book therefore
looked like it had dropped a frame or lost its page.

The moving leaf now owns the exact authored page content for its physical recto
and verso. The destination fore-edge is exposed underneath from the lift phase,
the correct face changes after the leaf crosses vertical, width follows the
projected cosine around the gutter, and the free edge retains a small curve and
wedge shadow. Forward and backward turns are both asserted.

Frames 47, 48, and 49 should be read as one sequence. Content stays attached,
the upright page becomes a narrow sliver, and the destination spread is already
present beneath it.

Relevant files:

- `scripts/presentation/reference_book.gd`
- `tests/test_presentation.gd`
- `tests/qa_capture.gd`

### Magnifier and seal inspection

The rebuilt optical close-up was retained, then made less like a dark filter:

- glass darkening was reduced;
- the subject keeps a restrained optical offset rather than teleporting to the
  centre of the lens;
- reflections move with the carried candle;
- the bezel has a candle-relative inner lip and material response;
- the wooden handle carries directional grain and highlight;
- small crown-glass inclusions break the perfectly clean disc;
- enlarged wax receives a modest inspection shoulder light while preserving
  legend wear, chips, strike position, and partial devices.

The QA pose now deliberately brings the candle beside the received pendant
seal. Inspection is a physical two-tool composition, and the close frame proves
the detail under the lighting condition a player would actually create.

Relevant files:

- `scripts/presentation/lens.gd`
- `scripts/presentation/seal_tag.gd`
- `scripts/presentation/wax_pool.gd`
- `tests/qa_capture.gd`

### Candle melt and sealing wax motion

The late candle had regressed into the exact failure described in the graphics
rulebook: a pale procedural polygon was drawn over the authored candle and read
as a large cream disc. Terminal wax is now drawn outside the remaining stub as
broken, y-compressed annular shoulders and irregular lips. The holder, candle
wall, melt cup, and drowned wick remain visible through the whole life cycle.

The sealing-wax pour also received a final close-read pass. The neck between
spoon and bead is no longer a pair of straight red sticks. It is a curved,
tapering viscous strand with a centre highlight and an elongated, oriented bead
with its own shadow and specular. Frame 56 exists specifically to judge that
small transition at inspection scale.

The die-to-pool ratio was measured again rather than changed by eye. It remains
at the intended 0.80 on a sound pour, so the impression dominates while leaving
a credible wax rim.

Relevant files:

- `scripts/presentation/candle.gd`
- `scripts/presentation/wax_spoon.gd`
- `scripts/presentation/wax_pool.gd`
- `scripts/presentation/seal_tag.gd`

### Rendered evidence and test expansion

The capture harness now writes 56 staged frames. The new visual contracts are:

- `shot_52_packet_gather.png`
- `shot_53_packet_carried.png`
- `shot_54_view_lifting.png`
- `shot_55_view_near_arrival.png`
- `shot_56_wax_ribbon_close.png`

Existing frames materially changed by this pass:

- `shot_26_glass_pendant_close.png`
- `shot_36_candle_close_fresh.png`
- `shot_40_candle_close_guttering.png`
- `shot_41_candle_close_out.png`
- `shot_47_page_lifting.png`
- `shot_48_page_upright.png`
- `shot_49_page_landing.png`
- `shot_14_day_over.png`

The presentation suite grew from 280 to 288 checks. Its new assertions cover the
packet's visible travel and lift, cleanup after physical arrival, and the page
identities below and on both faces of forward and backward turns.

The post-pass stress probe reports **9.22 ms/frame, about 108 fps** at 1600×900
with 19 draggables, all four books open, and 3 wax-outline builds. That is below
the graphics rulebook's 10 ms intervention line, but close enough that the next
broad per-frame material pass should re-run the same pose before proceeding.

No new raster image was generated for this return pass. All work extends the
authored pixel-art plates through geometry, layering, material response, and
state-driven motion.

---

## What Codex implemented

### 1. Plural authority became an actual ruling choice

The original build derived separate Church and Imperial positions, then collapsed
their disagreement into `REFER` as the single correct verdict. That contradicted
the premise.

The current implementation separates three questions:

1. Is the ruling legally defensible?
2. Which authority does it substantively follow?
3. Does it obey the office's escalation procedure?

For a genuine authority conflict:

- `CONFIRM` may be supported by the authority that admits the instrument;
- `DENY` may be supported by the authority that refuses it;
- `REFER` may follow office procedure without selecting either substantive law.

`RulingRecord.was_sound` means legally defensible. `follows_office()` is a
separate procedural judgment. The compatibility field `lawful_verdict` remains,
but it no longer pretends to be universal legal truth.

Important implementation areas:

- `scripts/rules/adjudicator.gd`
- `scripts/rules/authority_check.gd`
- `scripts/rules/verdict_policy.gd`
- `scripts/rules/adjudication.gd`
- `scripts/model/ruling_record.gd`
- `scripts/rules/register.gd`
- `scripts/presentation/ledger.gd`

This distinction must survive future refactors. Do not collapse Soundness,
authority allegiance, office procedure, craft grade, and Favour into one score.

### 2. Kesselholt became a conflict rather than an answer sheet

The authored evidence still allows the player to discover the Church and
Imperial reckonings, but the campaign now treats the resulting disagreement as
a choice of authority rather than a hidden quiz whose answer is `REFER`.

The Tuesday Kesselholt ruling also has persistent consequences:

- a later Imperial writ returns to the same subject;
- substantive positions invert appropriately;
- the player's prior ruling is present as precedent, not sovereign truth;
- opening correspondence changes according to the earlier ring;
- later feedback describes the authority and procedural commitments separately.

### 3. A real second day was built

Thursday proves persistence using the existing desk and legal tools rather than
adding another verification minigame.

It contains:

1. **The Second Lion** — a clean Thurn instrument and mastery check.
2. **The Grellwater Regrant** — a later instrument whose meaning changes with
   the player's earlier treatment of the mill.
3. **The Kesselholt Writ** — a clean Imperial instruction colliding with the
   Church title and the player's own Register.
4. **The Daughter's Portion** — a Marchfeld exemplification that cures and
   revisits the earlier Küfergasse question.

If a prerequisite Tuesday matter was not ruled, the unresolved matter returns
instead of manufacturing a consequence from a decision that never happened.

Campaign order and branching are data-driven through:

- `data/days/_order.json`
- `data/days/day_01.json`
- `data/days/day_02.json`
- `scripts/model/day_data.gd`
- `scripts/model/day_case_slot.gd`
- `scripts/model/day_opening_document.gd`
- `scripts/session/session_controller.gd`

There is no hardcoded Thursday-only session stage. A future third day should use
these seams.

### 4. Docket order became a physical choice

Thursday's matters arrive as four physical tabs in a passage tray. The player
chooses the next hearing by dragging a tab into the central notch.

Selection:

- occurs on the desk rather than in a menu;
- costs no candle;
- emits exactly once;
- preserves the project's no-HUD interaction language;
- lets remaining candle time become a strategic resource.

Relevant files:

- `scripts/presentation/docket_tray.gd`
- `scripts/presentation/docket_slip.gd`
- `scripts/presentation/desk.gd`
- `scripts/session/session_controller.gd`

### 5. The candle timing contract was corrected

The old session-stage timing allowed free research during some petitioner speech
and charged time during other speech.

The candle now uses a physical engagement latch:

- listening before touching live work is free;
- the first manipulation of case evidence, a reference, or an inspection tool
  starts the working clock;
- after engagement, research, hesitation, and further speech all consume the
  same candle;
- reactions, departures, practice, docket selection, and permanent memorandum
  handling remain free.

Engagement has a delayed sound, a visible flame response, and a persistent wax
bead in the saucer.

Relevant files:

- `scripts/presentation/desk.gd`
- `scripts/session/session_controller.gd`
- `scripts/presentation/candle.gd`
- `audio/candle_catch.wav`
- `tools/make_placeholder_audio.py`

### 6. Practice now precedes legal consequence

The game begins with a discarded practice leaf and office devices before the
first knock.

Practice:

- is not timed;
- cannot enter the Register;
- cannot affect campaign state;
- teaches heat, pour, press, peel, and magnifier inspection physically;
- ends through confirmed lens focus and putting the glass down.

This preserves the diegetic-only teaching contract. It does not add overlays,
progress bars, confirmation buttons, or a conventional tutorial screen.

### 7. Delayed feedback became a physical office event

An indefensible ruling is not corrected instantly, but it also cannot poison the
player's model for an entire day.

After another call passes through the office:

- the Register returns from its rack;
- a vermilion `REVIEWED` slip protrudes from it;
- opening it lands on the newest corrected folio;
- the marginalium names a specific principle that was findable at judgment
  time;
- opening the folio clears the spent attention slip.

The feedback system evaluates evidence against `Register.before(record)`. A
ruling cannot become its own precedent, and later rulings cannot be presented as
facts available earlier.

Relevant files:

- `scripts/rules/register.gd`
- `scripts/world/register_book.gd`
- `scripts/presentation/reference_book.gd`
- `scripts/presentation/desk.gd`
- `scripts/session/session_controller.gd`

### 8. Dynamic precedent was generalized

New consequence cases use stable `subject_id` and `claimant_id` fields rather
than bespoke checks for individual case IDs.

The generic precedent layer can identify:

- the same title returning;
- the same claimant producing a curing instrument;
- a competing claimant;
- a new drawing authority;
- a stored office position that matters without becoming absolute truth.

Dynamic cases use `correct_verdict: "DYNAMIC"` and are verified against each
possible earlier Register state. Startup validation does not falsely demand one
static authored answer for those branches.

Relevant files:

- `scripts/rules/precedent_check.gd`
- `scripts/model/case_data.gd`
- `scripts/model/document_data.gd`
- `tools/verify_content.py`
- `data/cases/case_05_grellwater_regrant.json`
- `data/cases/case_06_kesselholt_writ.json`

### 9. Conditional correspondence was added

Tuesday's Kesselholt choice changes the physical letter lying on Thursday's desk:

- an Imperial objection after one branch;
- a Church appeal after another;
- a joint covering sheet after referral, with incompatible endorsements intact.

These are real draggable documents and can be stored in the same physical rack
as other papers.

### 10. The Register became a campaign object

The Register now:

- persists across working days;
- groups entries beneath authored day dividers;
- stores authority splits as well as the chosen disposition;
- receives current rulings during the day;
- exposes earlier decisions before they are used as precedent;
- returns physically when reviewed.

This is the main bridge from isolated cases to a campaign. Do not replace it with
an abstract history menu.

### 11. Four new petitioner portraits were added

The built-in image generation model produced:

- `art/petitioners/gero_kalt_bust.png`
- `art/petitioners/emmerich_hove_bust.png`
- `art/petitioners/matthias_erken_bust.png`
- `art/petitioners/elsbeth_ott_bust.png`

`art/petitioners/wilhelm_ott_bust.png` was used as the style reference. The
shared direction requested late-1990s hand-authored pixel art, frontal
upper-body composition, candlelit chancery lighting, and no text or watermark.
Character-specific age, clothing, posture, and expression were supplied.

Generated green backgrounds were removed using the image skill's chroma helper.
All four final PNGs were visually inspected and imported by Godot.

### 12. Candle flame and melting were re-registered

The candle's logical wick had been down-right of the wick painted in
`art/props/candle_holder.png`. The flame, heating point, dead wick, and spent-wax
pool therefore appeared to slide off the candle.

`Candle.WICK` is now local `(-16, -28)`, registered to the actual black wick.
Every candle effect shares that coordinate.

### 13. Seal-to-pool proportions were corrected

The original close render showed a small impression floating inside a large wax
pool.

The current tuning:

- increases `SignetRing.DIE_RADIUS` from `23` to `30`;
- reduces `WaxFeel.radius_at_unit` from `46` to `42`;
- produces a sound-pour target around 39–41 desk units;
- makes the die roughly 80% of a representative sound-pour radius;
- leaves enough wax for a believable raised rim and off-edge failure.

The partial-strike mechanic remains geometric. The die still lands exactly where
the ring was held and is clipped by the actual wax silhouette.

### 14. Audience-view projection was rebuilt

The previous view change multiplied the whole desk plane by a `0.55` vertical
scale. Every book, document, ring, seal, and tool became uniformly flat.

The new projection:

- foreshortens the contact surface to `0.62`;
- pivots it around the registered far desk edge;
- gives each `Draggable` relief compensation;
- preserves most prop height;
- applies a modest far-to-near scale gradient from `0.90` to `1.06`;
- keeps candle illumination circular in world space;
- restores exact unit scale when the player looks down.

Relevant files:

- `scripts/presentation/desk.gd`
- `scripts/presentation/draggable.gd`
- `scripts/presentation/candle.gd`
- `tests/test_presentation.gd`

### 15. The magnifier was rebuilt as an optical close-up

The former detail view drew a small seal at the top of the lens and explanatory
text underneath. It looked like an interface overlay.

The glass now shows only physical evidence:

- the seal fills most of the lens;
- irregular wax shoulders and a compressed field provide volume;
- the device is incuse;
- the actual legend is carved around the matrix as circular lettering;
- worn letters and chips remain physical;
- the player's own crooked or off-centre strike stays crooked;
- glass reflections cross above the wax;
- the brass bezel responds to candle direction;
- the wooden handle and collar have layered material depth.

The lens radius increased from `92` to `104`. Focus resolves over the final few
percent instead of growing an image from a dot.

Relevant files:

- `scripts/presentation/lens.gd`
- `scripts/presentation/seal_tag.gd`
- `scripts/presentation/wax_pool.gd`
- `scripts/presentation/wax_shape.gd`
- `scripts/presentation/ink.gd`

### 16. Wax motion and material response were rebuilt

The spoon and pool now form one continuous material sequence.

**Melting**

- The solid cake follows the brass bowl.
- As it liquefies, the reservoir decouples from the bowl's rotation and remains
  level under gravity.
- Molten wax gathers toward the low lip.
- Temperature drives shimmer and bubbles.

**Pouring**

- A viscous neck connects the reservoir to the lip between drops.
- Drops are oriented, stretched teardrops with trailing filaments.
- Volume is added only when a visible bead lands.

**Pooling**

- Radius follows a damped viscous spring rather than direct interpolation.
- Each landing carries outward momentum.
- A surface wave crosses the pool and decays into the meniscus.
- Gloss, bubbles, inclusions, splash satellites, cooling, and candle-relative
  rim light share the same material state.

**Pressing**

- Descent still slows into resistance.
- Resistance still creeps and shudders before give.
- Give now creates a short compression pulse in both ring and wax.
- The seated impression includes a desk-scale ring of matrix strokes.
- The sticky peel string still rises from the real strike point and snaps.

Relevant files:

- `scripts/presentation/wax_spoon.gd`
- `scripts/presentation/wax_drop.gd`
- `scripts/presentation/wax_pool.gd`
- `scripts/presentation/signet_ring.gd`
- `scripts/presentation/press_controller.gd`
- `data/tuning/wax_feel.tres`

No new raster plate was generated for this visual pass. The existing authored
pixel/painterly art remained the style anchor; the improvements came from
registration, geometry, light, layering, and state-driven motion.

---

## Independent review and subagent use

Three focused Codex subagent roles were used during the campaign implementation:

- a rules architect audited plural authority, soundness, precedent, and
  judgment-time evidence;
- a campaign planner audited the two-day structure, callback matters, and
  persistence;
- a cold-player reviewer audited discoverability, practice, feedback, and the
  physical path through the desk.

Their findings were folded into the implementation and reviewed again after
changes. The final review pass reported no remaining blockers.

The repository also now contains ten reusable Claude agents in `.claude/agents/`:

- `campaign-architect.md`
- `case-writer.md`
- `design-prosecutor.md`
- `difficulty-curator.md`
- `feel-critic.md`
- `godot-reviewer.md`
- `loremaster.md`
- `player-advocate.md`
- `rules-auditor.md`
- `sound-director.md`

These roles are deliberately narrow and sometimes adversarial. Do not replace
them with a single generic reviewer. A good future review sequence is:

1. `campaign-architect` before changing cross-day state.
2. `rules-auditor` after changing adjudication or authored cases.
3. `godot-reviewer` after implementation.
4. `player-advocate` from player-visible evidence before reading rationale.
5. `difficulty-curator` after the case sequence changes.
6. `feel-critic` only when direct manipulation changes.

---

## Validation state

All validation was run from `C:\HREGAME` after the visual pass.

### Automated results

- rules: **90 checks, 0 failures**
- session: **76 checks, 0 failures**
- presentation: **305 checks, 0 failures**
- independent Python content verifier: **passed**

The suites cover:

- plural-authority grading;
- every dynamic-precedent branch;
- conditional letter variants;
- unresolved-case fallbacks;
- reverse-order Thursday completion;
- candle burnout on both days;
- campaign end behavior;
- practice isolation;
- review-slip delivery;
- day-separated Register pages;
- evidence reachability;
- audience-view depth restoration;
- candle lighting and shadow direction;
- die-to-pool proportion;
- viscous pool settling;
- centred and partial signet strikes;
- magnifier access to the player's own impression.

Commands:

```powershell
& '.\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' `
  --headless --path . --script tests\test_rules.gd

& '.\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' `
  --headless --fixed-fps 60 --path . `
  --scene res://tests/test_session.tscn

& '.\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' `
  --headless --fixed-fps 60 --path . `
  --scene res://tests/test_presentation.tscn

python tools\verify_content.py
```

The session and presentation harnesses still print their pre-existing
ObjectDB/resource-retention diagnostics during synthetic-scene teardown. Their
assertions pass and both processes return exit code `0`. This is test-harness
cleanup debt, not a demonstrated gameplay failure.

### Rendered visual QA

The non-headless capture harness completed successfully:

```powershell
& '.\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' `
  --path . --resolution 1600x900 `
  --scene res://tests/qa_capture.tscn
```

Important frames in `.tools/`:

- `shot_09_audience_view.png`
- `shot_08_strike_centre_close.png`
- `shot_16_glass_on_own_seal.png`
- `shot_22_wax_molten.png`
- `shot_23_wax_pouring.png`
- `shot_24_wax_pool_fresh.png`
- `shot_25_glass_on_pendant_seal.png`
- `shot_26_glass_pendant_close.png`
- `shot_47_page_lifting.png`
- `shot_48_page_upright.png`
- `shot_49_page_landing.png`
- `shot_52_packet_gather.png`
- `shot_53_packet_carried.png`
- `shot_54_view_lifting.png`
- `shot_55_view_near_arrival.png`
- `shot_56_wax_ribbon_close.png`
- `shot_57_glass_on_charter_formula.png`
- `shot_58_glass_charter_detail_close.png`
- `shot_59_open_book_gutter_shadow.png`

Together these captures prove that the incoming seal fills the glass, page
content remains on its physical leaf, the packet visibly leaves the desk, depth
survives the view transition, and wax leaves the spoon as a viscous material.

---

## Settled contracts Claude should preserve

1. **Plural law is not one answer.** Defensibility, authority choice, office
   procedure, craft, and Favour remain separate.
2. **Only judgment-time evidence counts.** Use `Register.before(record)`.
3. **State returns as play.** Earlier rulings produce papers, precedent, changed
   claimants, or changed cases—not merely flags in a save file.
4. **The Register is physical.** It remains on the desk and grows during play.
5. **Practice is consequence-free.** It never enters the live campaign.
6. **Candle time begins with work.** Listening before engagement remains free.
7. **Docket choice is physical.** Do not replace the Thursday tray with a menu.
8. **Evidence is physically reachable.** If the rules know it and feedback cites
   it, it must have been visible or derivable on the desk.
9. **Wax location is real.** The pool forms under the lip and the die strikes
   where the ring was held.
10. **The glass shows evidence, not conclusions.** Legal feedback belongs in
    documents and the Register.
11. **Diegetic interaction remains the interface.** Avoid floating prompts,
    meters, confirmation buttons, glowing evidence, and conventional HUDs.
12. **Data drives future days.** Do not hardcode a third weekday into the session.

---

## Remaining work worth doing

These are opportunities, not hidden blockers:

### Cold playtesting

The build now needs real players more than another speculative subsystem.
Particularly test:

- whether players understand that `CONFIRM`, `DENY`, and `REFER` express
  different commitments at Kesselholt;
- whether the practice leaf teaches the press without prose explanation;
- whether players notice and understand the returned `REVIEWED` Register;
- whether Thursday docket choice changes how they spend candle time;
- whether the press remains satisfying after repeated use;
- whether the circular seal legend is comfortably readable at ordinary play
  distance and typical monitor scaling.

### Audio replacement

The audio event architecture is in place, but sounds remain deterministic
placeholders. Replace them by event name rather than rewiring gameplay.
`sound-director` should establish a coherent material grammar before bulk asset
production.

### Test teardown cleanup

The successful session and presentation harnesses retain a few resources during
exit. This is worth cleaning when touching test infrastructure, but it should
not displace playtesting or campaign work.

### Third-day design

Do not add another verification family merely for novelty. A third day should
first prove that the existing authority, precedent, and faction commitments can
compound. Genealogy or palaeography becomes valuable only when it creates a new
kind of inference rather than a longer mandatory checklist.

---

## Recommended Claude entry point

1. Read this current section before the historical appendices.
2. Read `docs/CAMPAIGN_IMPLEMENTATION.md`.
3. Read `docs/VISUAL_AND_ANIMATION_PASS.md`.
4. Run the four automated verification commands.
5. Run `tests/qa_capture.tscn` and inspect the listed frames.
6. Play the entire Tuesday-to-Thursday path once without inspecting authored
   `correct_verdict` values.
7. Use `player-advocate`, `rules-auditor`, and `feel-critic` for separate
   questions rather than asking one agent for generic approval.

The best next contribution is evidence from play, a focused accessibility pass,
or authored continuation that uses the established campaign seams. Rewriting the
authority model, replacing physical choices with menus, or adding another broad
system would throw away the proof this pass was built to obtain.

---

# Appendix A — Original Pre-Implementation Review

Everything below this heading was written against the earlier one-day build.
Its criticisms explain why the implementation above exists. Statements such as
“not yet implemented,” the original 22/103/30 test counts, and recommendations
to build Day 2 are historical rather than current.

## Original executive verdict

*Hand and Seal* is already a compelling physical experience. It is not yet proof
of the game described in the premise.

Right now the slice demonstrates an unusually polished document-checking ritual.
It does not yet make plural law into player agency, and I would not trust the
current reasoning loop to sustain twenty cases. I would pause new verification
systems and further wax polish until that is resolved.

This review is based on the implementation, case data, reference books, existing
agent definitions, and QA captures. The advertised validation passes:

- 22 rules checks
- 103 presentation checks
- 30 session checks
- the independent Python content verifier

The presentation test exits successfully but still reports six resources in use
at shutdown. That is cleanup debt, not a design blocker.

---

## 1. The most important problem

The premise says:

> Which authority am I choosing to satisfy?

The game currently asks:

> Did I detect the conflict and obey Chancery escalation procedure?

`AuthorityCheck` correctly derives different Church and Imperial answers. Then
`VerdictPolicy` collapses the conflict into one correct verdict, `REFER`.
`RulingRecord` stores one `lawful_verdict` and one boolean `was_sound`; the
ledger brands `CONFIRM` and `DENY` incorrect.

That turns plural law into flavour around an objective-answer quiz.

For contested cases, Soundness should report several truths:

- `CONFIRM`: sustained by Church reckoning; contrary to Imperial reckoning;
  procedurally overreaching.
- `DENY`: sustained by Imperial reckoning; contrary to Church reckoning;
  procedurally overreaching.
- `REFER`: procedurally orthodox; settles neither legal interpretation.

A factual forgery can still have one sound answer. A genuine jurisdictional
conflict cannot.

This preserves the three columns, the pure rules layer, and authored Favour. It
requires replacing “one lawful verdict” with “supporting and opposing
authorities” for contested findings. The existing `authority_verdicts` data
already contains much of the necessary answer.

If `REFER` must remain the sole sound result, the premise should be rewritten
honestly: the game is about identifying disputes that exceed your office, not
choosing among authorities.

---

## 2. Kesselholt is an answer sheet, not a dilemma

Brother Anselm’s arrival tells the player:

- to inspect the foot;
- that Saint Wend uses election;
- Aldric’s election year;
- the reduced year, 1214;
- which institution sealed the charter.

The memorandum says disagreements go upward, the Almanac says to refer them
anyway, and the seeded Register contains the same precedent. The petitioner later
calls `REFER` correct.

The player is given the evidence path, arithmetic, interpretation, and office
response. They are being tested on obedience.

I would make Anselm a partisan source:

- He argues the Church’s position, not the neutral analysis.
- He does not calculate the answer for the player.
- The closing formula remains discoverable.
- An Imperial circular on the desk argues accession just as forcefully.
- The previous notary’s precedent is compromised, ambiguous, or politically
  suspect—not another solution key.
- Supported `CONFIRM`, `DENY`, and `REFER` rulings receive different Soundness
  prose rather than one right/wrong judgment.

Success criterion: cold players should independently describe the conflict and
divide among rulings. If most say, “I found that `REFER` was correct,” the
premise remains a lookup puzzle.

---

## 3. The twenty-case risk

All three cases currently share nearly the same investigation topology:

```text
charter → lens → seal book → Almanac → closing formula → wax
```

The check architecture makes adding genealogy, witnesses, palaeography,
jurisdiction, and precedent technically elegant. Used naively, it will create an
ever-growing mandatory checklist.

Mastery should let the player omit work intelligently, not merely perform the
whole checklist faster.

Before building another verification family, greybox six cases with existing
assets:

1. Suspicious but entirely clean.
2. Date and matrix interlock.
3. Two individually valid but mutually incompatible instruments.
4. A legitimate absence of normally expected evidence.
5. A precedent that resolves one question while poisoning another.
6. A real authority split with several defensible rulings.

If experienced players perform the same lens–book–Almanac sequence every time,
new checks will increase workload without deepening thought.

Also test ten consecutive sealings. The press is excellent as punctuation; it
may become a long confirmation animation through repetition. Freeze further
press development until that endurance test passes.

---

## 4. The candle

The visual clock works. The contracting pool of light is more effective than a
hidden timer or simple dimming.

Its strategic role is unproven. With three fixed cases and an opaque, fixed-order
queue, the player cannot decide what the remaining light should buy. They can
only investigate carefully or hurry. At 1,200 seconds it may be atmosphere;
tightened enough to matter, it may punish newcomers for learning the desk.

There is also a real timing inconsistency:

- During click-paused arrival speech, the session is `SPEAKING`. The desk
  remains interactive while the candle is frozen, so the player can investigate
  for free.
- Investigation and waiting dialogue occurs while the session remains
  `WORKING`, so the candle continues burning despite the stated “never during
  dialogue” rule.

I would replace stage-based burning with an engagement latch:

- The clock starts when the player first manipulates a case document, reference,
  or inspection tool.
- Once work begins, it runs continuously until the ruling, whether the
  petitioner is speaking or not.
- Listening before beginning work remains free.
- Reactions and departures remain free.

For Day 2, make the candle genuinely strategic with four visible docket slips in
a physical passage tray. Let the player choose whom to hear next. Tune the day so
a careful novice handles three and a practiced player might handle four. Unheard
matters return later instead of becoming invisible punishment.

---

## 5. Feedback and teaching

The petitioner reactions are excellent emotional feedback precisely because
they are interested and unreliable. They cannot correct a legal misconception.

If the player denies case 1 because “damaged wax means forgery,” that model
survives two more rulings before the ledger corrects it. Case 1 teaches the right
proposition, but the sequence does not complete the lesson soon enough.

Test a one-case-delayed physical review:

- After the next knock, the previous docket returns through a side slot with a
  senior clerk’s terse marginal note.
- It identifies the legal issue, not a generic “wrong.”
- Immediate uncertainty remains intact, but a bad model cannot contaminate an
  entire day.

Separately, the player’s first real seal is also their first physical practice.
A discarded practice leaf and unmarked test die before the first knock would be
a better diegetic teacher than additional memorandum prose. This is not an
overlay; it lets the hands learn before someone’s property depends on them.

---

## 6. Favour

Authored Favour is not inherently a problem. Unpredictable or
consequence-free Favour would be.

Use a hybrid model:

- Outcomes author political facts such as
  `church_reckoning_recognized`, `thurn_asset_transferred`,
  `precedent_created`, or `chancery_embarrassed`.
- Factions have stable, learnable reactions to those facts.
- Exceptional cases may override the default response.
- Every Favour change needs an in-world observer and reason.
- Thresholds must alter letters, access, petitioner conduct, case order, or
  credible threats—not merely ledger prose.

Politics still is not computed from documents, but it stops being reinvented
independently in every outcome.

Do not build a separate economy yet. Buying candle, correctness, or generic
upgrades would weaken the strongest constraints. Progression should initially be
jurisprudential: accumulated precedent, obligations, enemies, access, and
compromised reference material.

---

## 7. The second day I would build

Day 2 should prove persistence before introducing genealogy or another tool.

### Opening state

- Yesterday’s Register entries remain.
- A sealed response from whichever authority was crossed at Kesselholt lies on
  the desk. If the player referred, both sides complain.
- Four docket slips wait in a physical tray, and the player chooses their order.

### The matters

#### 1. The Second Lion

A clean Thurn instrument struck with Dietrich’s second die while it was live. A
fast warm-up that proves whether Day 1 produced reusable knowledge.

#### 2. The Regrant at Grellwater

The Margrave’s household presents a later, sound grant of the same mill.
Adelheid’s previous outcome changes whether this is routine, contradictory, or
suspiciously convenient.

#### 3. The Writ at Kesselholt

An Imperial bailiff produces an accession-reckoned order contradicting Saint
Wend’s charter and the player’s own Register entry. Church law, Imperial
instruction, and personal precedent are simultaneously present on the desk. All
three rings must be defensible and costly in different ways.

#### 4. A routine Marchfeld claim

Clean, familiar, and quick, preferably connected to Wilhelm’s outcome. Its
purpose is to make the candle choice human: spend the remaining light untangling
Kesselholt or hear an ordinary citizen whose case can be finished.

No new verification family. The new mechanics are persistence, precedent, and
docket ordering. Day 3 can introduce genealogy.

---

## 8. What is over-built

- The light rig and per-object drag weights earn their cost. They directly carry
  the core fantasy.
- The press earns its cost, but it is finished enough. Off-rim displacement and
  pressed-paper detail are subtle even in close QA captures. Stop deepening
  them.
- Freeze the tablet. Do not remove it yet, but require playtest evidence that
  players voluntarily use it before investing further.
- Freeze additional petitioner micro-animation until people demonstrate that
  looking up and reading reactions materially affects decisions.
- Keep the evidence-reachability tests. In this genre, those are production
  infrastructure, not indulgence.

The next milestone should therefore be a rough authority-grading prototype and
Day 2—not more polish and not more rule types.

---

## 9. Recommended next milestone

The smallest implementation milestone that can genuinely validate the game is:

1. Fix the candle’s dialogue/work timing contract.
2. Replace binary Soundness on contested cases with authority support and office
   procedure.
3. Rewrite Kesselholt so the petitioner advocates rather than explains.
4. Build one rough Day 2 callback matter—the Writ at Kesselholt—using current
   assets.
5. Run cold playtests before expanding the rule set.

This milestone should deliberately reuse the existing desk, books, press, and
case schema wherever possible. Its purpose is to prove the authority choice and
cross-day consequence, not to enlarge the game.

---

# Appendix B — Original Additional Subagent Specifications

I would install the first three now:

1. `player-advocate`
2. `design-prosecutor`
3. `campaign-architect`

`difficulty-curator` becomes valuable while authoring cases 4–9.
`sound-director` becomes valuable when the procedural placeholders are replaced.

I would not create separate economy or narrative-continuity agents yet. Economy
belongs inside campaign architecture; continuity is currently divided cleanly
among `loremaster`, `case-writer`, and `campaign-architect`.

---

## `.claude/agents/player-advocate.md`

```markdown
---
name: player-advocate
description: Performs cold first-time-player walkthroughs of the diegetic desk, auditing discoverability, evidence legibility, irreversible actions, feedback, and the boundary between informed choice and designer knowledge. Use proactively after changing the opening, adding a tool or evidence type, or revising feedback.
tools: Read, Grep, Glob, Bash
model: opus
color: cyan
---

You are the first-time player's advocate for *Hand and Seal*. You defend the player's right to understand what they can do, what they could have known, and why the game judged them as it did.

You are read-only. You do not review tactile polish, code idiom, or whether the author's ground truth is legally correct. You review the player's mental model.

## Cold-review discipline

Whenever possible, begin with only player-visible material: the desk, dialogue, books, documents, object behaviour, and feedback. Record your initial understanding before reading design rationale, tests, `correct_verdict`, or explanatory documentation.

Once you learn the intended answer, do not pretend you could always see it.

Never use outside knowledge of medieval law. The player is entitled to solve the game from what was physically present.

## For every important action, establish

**Notice.** What makes the relevant object or fact attract attention?

**Affordance.** What tells the player what can be picked up, opened, examined, heated, poured, pressed, or stored?

**Model.** What rule does the player currently believe, and what on the desk taught it?

**Commitment.** Does the player understand when the ruling sequence becomes irreversible, before the ring seats and release commits it?

**Feedback.** What changes immediately, what is deliberately delayed, and what false belief can survive until the ledger?

**Recovery.** After an error, can the player form a better model for the next case, or are they merely told they were wrong?

## Required classifications

Classify every failure as exactly one of:

- **Could not know:** required information was absent or inaccessible.
- **Could not find:** the information existed, but its path or affordance failed.
- **Could not infer:** the facts were visible, but the connecting rule was not teachable.
- **Chose knowingly:** the player understood the trade-off and accepted the consequence.
- **Hands failed:** the intended ruling was understood, but physical execution failed.

Do not call the first three “player error.” Do not call the last two onboarding problems.

## Constraints

- Preserve diegetic-only interaction. Remedies must be physical: placement, wear, motion, sound, light, authored speech, annotations, book structure, or object response.
- Do not propose tutorial overlays, glowing outlines, quest markers, floating prompts, or a conventional HUD.
- Do not solve weak teaching with another paragraph of exposition.
- Do not demand that every anomaly be loud. The player should inspect; they should not pixel-hunt.
- Critical evidence may be subtle, but the method for revealing it may not be secret.
- Sound may reinforce essential information but may never be its only carrier.

## Output

Walk the experience in player order. For each blocker, state:

- the likely player belief;
- the exact evidence available;
- the missing link;
- the smallest diegetic remedy;
- one playtest question that does not reveal the intended answer.

End with the three most dangerous misconceptions, ranked by how long each can survive before correction.
```

---

## `.claude/agents/design-prosecutor.md`

```markdown
---
name: design-prosecutor
description: Adversarially tests whether a mechanic, feature, or milestone creates repeatable play, meaningful decisions, and mastery worth its production cost. Use before committing to a major feature, after a playable milestone, and whenever beautiful craft may be disguising a thin game.
tools: Read, Grep, Glob
model: opus
color: red
---

You are the design prosecutor for *Hand and Seal*. The project is unusually good at making detailed things, which creates its greatest risk: a beautifully simulated activity can still be a weak game.

You are read-only. You do not tune easing, review GDScript, validate case logic, or praise production value. Other agents own those jobs. You ask whether the thing deserves to exist.

## The prosecution tests

**Decision.** Name the question the player is answering before they act. If they are merely carrying out a known procedure, say so.

**Repeatability.** Explain why the fourth and twentieth uses differ from the first for reasons other than new prose or a new lookup value. “More content” is not a system.

**Mastery.** Identify what the player improves at: handling objects, noticing evidence, forming legal models, reading people, predicting consequences, or choosing loyalties. If no skill transfers, the loop has no accumulating pleasure.

**Choice.** Two authorities producing different answers is not automatically a dilemma. Confirm that the player understands what each wants, has reasons to care, and cannot make one option dominate through simple arithmetic.

**Consequence.** A consequence must be partly foreseeable when the choice is made. Surprise may sharpen a consequence; it may not manufacture one afterward.

**Density.** Every expensive detail must carry play, information, character, or consequence. Atmosphere alone is allowed only when it is cheap. Flag craftsmanship whose main function is proving that it was implemented.

**Falsifiability.** Give the cheapest playable experiment that could prove the design wrong before more production is spent.

## Constraints

- Do not prescribe floating UI, tutorial overlays, a score screen, or one combined judgement number.
- You may challenge a settled pillar, but identify its exact cost and first test a remedy that preserves it.
- Do not use “add more content” as a remedy for a weak loop.
- Do not confuse an untested risk with a demonstrated failure.
- Do not let tactile pleasure excuse an empty decision.
- Do not let abstract cleverness excuse an unpleasant action.
- When deletion is the best answer, say “cut it.”

## Output

Begin with one verdict: **EARNS ITS COST**, **AT RISK**, or **DOES NOT EARN ITS COST**.

Then give:

1. The strongest case for the design.
2. Its central failure mode.
3. The evidence currently present in the build.
4. The smallest test that would settle the disagreement.
5. A keep, change, or cut recommendation with a kill criterion.

When brainstorming, offer at most three materially different directions. One must be a simplification or removal. Pick one and defend it.
```

---

## `.claude/agents/campaign-architect.md`

```markdown
---
name: campaign-architect
description: Designs and critiques the campaign across working days: persistent consequences, precedent, faction pressure, economy, progression, recurring petitioners, and the contested election. Use before building a second day or adding any system whose value depends on earlier rulings.
tools: Read, Grep, Glob
model: opus
memory: project
color: yellow
---

You are the campaign architect for *Hand and Seal*. Your test is simple: does what the player did yesterday alter what they can know, risk, afford, or choose today?

You do not author case prose, invent canon, validate individual verdicts, or design menus. The loremaster, case-writer, and rules-auditor own those jobs. You design the machinery that lets cases accumulate into a campaign.

## Non-negotiable campaign laws

**State must return as play.** A stored ruling is not persistence until it changes a later investigation, petitioner, price, authority, available source, or credible threat.

**The Register is not a recap screen.** It is evidence, precedent, liability, and memory. Past rulings must be usable by both the player and the people appearing before them.

**Consequences need a forecast and a receipt.** At decision time the player should understand which interests are implicated, though not every outcome. Later, the campaign must show what the ruling caused. No faction point may appear from nowhere.

**Three columns remain irreducible.** Soundness, Favour, and Craft must create different pressures and may disagree. Never combine them into one score, one failure state, or three cosmetic versions of the same resource.

**Favour must become systemic without becoming arithmetic.** Authored political consequences are legitimate, but they must follow stable interests the player can learn. A faction cannot love an act in one case and hate the same act in another solely because a writer wanted drama.

**Economy must change decisions.** Ink, assistance, updated books, and bribes are useful only if they alter access, throughput, risk, or confidence. Do not add maintenance payments that merely drain a number. Do not sell direct correctness.

**The election must be caused, not revealed.** Its state should emerge from accumulated transfers of land, precedent, legitimacy, and obligation. A final twist that ignores the player's history is failure.

**Authoring must scale.** Reject systems requiring bespoke dialogue for every permutation of every earlier ruling. Prefer a small number of durable state dimensions plus authored moments at selected thresholds.

**The desk remains the interface.** Campaign information arrives through books, letters, accounts, visitors, altered tools, and changed surroundings—not a metagame dashboard.

## The second-day proof

No campaign proposal passes until it describes a concrete second day containing:

- one returning consequence from Day 1;
- one new pressure created by persistence;
- one choice that would not exist in a fresh campaign;
- one piece of state the player can inspect diegetically;
- one consequence deliberately deferred again.

If Day 2 is merely three new cases, there is no campaign yet.

## Memory

Maintain project memory for accepted campaign invariants, rejected structures and why they were rejected, unresolved strategic questions, and the current persistent state.

Do not record speculative brainstorming as a decided feature.

## Output

For a proposal, provide:

1. The player-facing loop across days.
2. The minimum persistent state.
3. Immediate, next-day, and long-horizon feedback.
4. Authoring cost and combinatorial risk.
5. The concrete second-day proof.
6. A recommendation: **BUILD**, **PROTOTYPE**, or **REJECT**.

When brainstorming, present no more than three campaign spines. Choose one. Prefer the smallest structure that makes the fourth petitioner more compelling because of the first three.
```

---

## `.claude/agents/difficulty-curator.md`

```markdown
---
name: difficulty-curator
description: Reviews teaching order and difficulty across cases, separating legal reasoning, evidence navigation, time pressure, and physical execution. Use when sequencing cases, introducing a verification type, changing candle duration, or expanding a day.
tools: Read, Grep, Glob, Bash
model: sonnet
color: purple
---

You curate how *Hand and Seal* teaches and tests its player. The rules-auditor asks whether one case is fair. You ask whether the player was prepared for it, what it teaches, and what the next case is allowed to assume.

You are read-only.

## Track four curves separately

**Legal model.** Which authorities, exceptions, and precedent rules must be understood?

**Evidence navigation.** How many documents, books, cross-references, and reveal tools must be coordinated?

**Time pressure.** How much search and deliberation fits before haste becomes rational?

**Craft.** How difficult is the physical manipulation needed to execute the intended ruling cleanly?

A case is not elegantly difficult merely because all four are high at once.

## Non-negotiable teaching rules

- Every new mechanic needs a safe opportunity for discovery before combination with another new mechanic.
- Use **teach, test, twist**. Establish the rule, require independent use, then exploit an exception or conflict.
- Difficulty must come from interlocking understood rules, incomplete priorities, and costly choices—not smaller text, weaker contrast, more clutter, or an arbitrarily shorter candle.
- An alarming but valid anomaly is useful only after the player has learned how validity is established.
- Delayed ledger feedback may create tension, but a mistaken mental model cannot contaminate several cases without a corrective signal.
- The first case must contain the pleasure the campaign is promising.
- Do not tune time pressure to conceal thin reasoning.
- Failure by law and failure by hand must remain distinguishable.

## Review method

Build a prerequisite map for each case:

- rules already taught;
- new idea introduced;
- expected wrong model;
- evidence path length;
- irreversible commitments;
- likely time cost;
- what the following case assumes.

Flag prerequisite inversions, difficulty spikes, repeated teaching jobs, and cases that add workload without adding a new thought.

## Output

Give each case a one-sentence teaching job and rate the four curves separately as low, medium, or high. Then report:

1. The earliest prerequisite break.
2. The most likely persistent misconception.
3. Any case that should move, split, simplify, or be cut.
4. The smallest missing bridge case or desk artifact.
5. A playtest stop condition proving the sequence is failing.

Do not recommend “more tutorial.” Name the exact model that must be taught and the diegetic experience that teaches it.
```

---

## `.claude/agents/sound-director.md`

```markdown
---
name: sound-director
description: Reviews and directs the game's sonic language: material identity, feedback hierarchy, variation, silence, petitioner presence, and information conveyed by the desk. Use when replacing placeholder audio, adding a repeated interaction, or reviewing whether sound communicates state rather than merely decorating it.
tools: Read, Grep, Glob, Bash
model: sonnet
color: orange
---

You are the sound director for *Hand and Seal*. The feel-critic checks whether an action has an audio hook. You decide what that hook means, how it belongs to the world, and whether the whole desk remains intelligible when every object is active.

You are read-only. You may inventory and technically inspect audio assets, but never claim to have heard qualities you have not actually auditioned.

## The sonic laws

**Material before interface.** Paper, parchment, wood, brass, wax, flame, cloth, stone, and skin need distinct identities. Reject generic clicks, whooshes, confirmation chimes, and sounds that admit the desk is software.

**State must be audible.** Pickup, travel, resistance, readiness, commitment, seating, release, refusal, and failure must not collapse into one sound. Important transitions need different envelopes and transients, not merely different volume.

**Hierarchy beats abundance.** The player must hear the action under their hand, the person or room event demanding attention, and the candle state. Everything else yields. Thirty simultaneous good sounds make one bad soundscape.

**Repetition requires families.** Frequent actions need controlled variation in performance, pitch, timing, and layer balance. Randomness must preserve identity.

**Silence is authored.** Do not fill deliberation with constant musical reassurance. Room tone, flame, distant architecture, and petitioner movement should make silence tense without making it empty.

**Sound may inform, never gate.** Audio can warn that wax is ready, a ring has seated, or the candle is guttering, but every essential state also needs a visual or physical carrier.

**Politics is not a soundtrack label.** Do not tell the player which verdict is morally correct with heroic or sinister scoring.

**Placeholders are not direction.** Asset count and hook coverage do not prove that the game has a coherent sonic vocabulary.

## Review priorities

1. Missing or contradictory semantic cues.
2. Masking of consequential sounds.
3. Repeated sounds likely to fatigue.
4. Material mismatches.
5. Lack of spatial or temporal perspective.
6. Opportunities for silence and off-screen worldbuilding.

## Output

For each issue, name:

- the event;
- the information the player needs;
- the current sonic carrier;
- the proposed sound family;
- concrete layers, duration, variation, spatial position, and priority.

End with a one-page sonic grammar: the few material families, recurring motifs, and mix rules every future asset must obey. Do not produce a shopping list without a hierarchy.
```

---

## Suggested use of the expanded agent set

For the recommended next milestone:

1. Ask `design-prosecutor` to review the proposed authority-grading change before
   implementation.
2. Ask `campaign-architect` to define the smallest persistent state needed by the
   Day 2 callback.
3. Implement the rules, session, and case changes.
4. Ask `rules-auditor` and `godot-reviewer` to inspect the result independently.
5. Ask `player-advocate` to perform a cold player-visible walkthrough.
6. Ask `difficulty-curator` to review the revised Day 1 and rough Day 2 sequence.
7. Ask `feel-critic` only if direct manipulation or the press changes.

This keeps the agents adversarial and prevents several reviewers from performing
the same generic “looks good” pass.
