# Graphics, lighting and animation — the standing rules

The reference document for how this game is allowed to look, and how to work on
it. Read before touching anything that draws.

`docs/CONTINUITY.md` is the traps. `docs/NEXT_SESSION.md` is what to build next.
This is the *how*.

---

## The one sentence

**Pixel-art anchored, lit by one carried flame, and every surface has to tell you
what it is made of.** Not photoreal. Not smooth. Not decorated.

### Current rendered state — 2026-07-28 return pass

The latest pass closed the most visible remaining motion and material gaps:

- a turning leaf now carries its authored recto and verso through the whole
  projection instead of becoming a blank parchment rectangle;
- the petition packet has a staggered gather, lift, arcing carry, and arrival
  settle; cleanup happens only after every sheet reaches the petitioner;
- the desk-to-audience move preserves prop relief and the registered far desk
  edge at intermediate poses, not only at its endpoints;
- the magnifier is clearer crown glass with candle-relative reflections,
  transmitted subject parallax, a lit inner bezel, and a material-responsive
  handle;
- molten wax leaves the spoon as a curved, tapering viscous neck and oriented
  bead rather than two straight lines;
- the candle's terminal wax stays outside the authored stub instead of painting
  a pale disc over it;
- the pigeonhole rack is now directional oak rather than fixed-colour geometry;
- cold morning light has a distinct colour and directional shutter bands across
  both room and desk planes.

These are rendered and covered by the 56-shot capture harness. The presentation
suite is now 288 checks. The pass added no shader and no new raster plate: the
authored pixel art remains the anchor.

---

## 1. Look at the pixels. Always.

Every serious visual defect found in this project so far was invisible in code
review and obvious in a frame:

| Defect | How long it survived | What found it |
|---|---|---|
| Ink never darkened, so the candle changed the colour of the desk but not what could be **read** | since the light rig was written | a screenshot |
| The wax drew on top of the entire room | months | the owner, playing |
| The candle's melt painted lighter than the brass it sits in | since it was written | the owner, and then a 4× capture |
| A round spoon casting a rectangular shadow | months | a screenshot |
| Verdict ring names at ~9 effective pixels, brown on brown | since the ring stand was written | a screenshot |
| A page turned as a blank rectangle while its ink stayed behind | since the first page-turn animation | three staged page-turn frames |
| The petition packet waited, then disappeared instead of travelling | since the sweep was authored | a mid-flight frame plus an arrival assertion |
| Terminal candle wax painted a pale disc over the authored stub | since the late melt was added | the 4× guttering capture |

```bash
.tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --path . --resolution 1600x900 --scene res://tests/qa_capture.tscn
```

56 frames into `.tools/shot_*.png` (gitignored). Deliberately **not** headless —
Godot cannot render 2D lights with the dummy driver.

**Three rules about captures, each of which was learned the hard way:**

1. **Capture the object in the state you are worried about, not in isolation.**
   Every frame of the seal showed the seal alone, so "is the wax actually *on*
   the parchment" was a question no frame could answer. Shot 43 exists now
   because of that.
2. **Capture at a size where the thing can be seen.** The candle was only ever
   framed desk-wide, where it is ninety pixels and no change to it is legible.
   The 4× series (36–41) was added only after the owner said it looked flat.
3. **If you add a subsystem, add a shot for it.** The door and the petitioner had
   none, which is why their two worst defects survived so long.

---

## 2. The light model

One carried flame. Three `PointLight2D`s sharing one flicker value — a tight
core, a shadow-casting key, a wide dim bounce — over a low, slightly blue
`CanvasModulate` ambient. Falloff is a **generated inverse-square curve**, not a
painted radial; a linear gradient reads as a flat disc with a visible rim and no
amount of energy tuning fixes it.

Every object is fed three values per frame by `Desk._update_lighting`:

- `light_position` — where the flame is, in world space
- `light_strength` — the shared flicker, so the whole desk pulses together
- `light_level` — how much of the flame reaches **this** object, on the same
  inverse-square curve the renderer uses

**Use all three.** An object that reads only `light_level` gets brighter and
darker but never gains a direction. An object that reads none of them is a
sticker. The most common failure in this codebase has been drawing a fixed
colour and calling it a material.

### The shade veil

`Draggable.shade_alpha()` / `draw_shade()`. One translucent cold veil over the
**finished face** of anything with readable content — substrate, ink, rubric and
seal together — because that is what a page out of the light actually does.

It exists because the substrate used to warm and cool with the flame while the
writing did not, so a charter across the desk from the only light in the room was
exactly as legible as one under the wick. That quietly cost the game its central
claim.

- It goes **last**, above `_draw_face`, so a new document type cannot forget it.
- It switches **off** under `ambient_daylight` — cold morning is uniform and
  directional, so nothing is in shadow relative to anything else, and the ledger
  is read after the candle dies.
- It is never quite opaque. A sheet you cannot see at all is a lost sheet, and
  digging for a buried charter has to stay a mechanic rather than a chore.

Anything with a readable face needs it. Four objects were missed on the first
pass (pendant seal, docket slips, wax tablet, ledger) and each one was a hole in
the claim that the candle controls what can be read.

---

## 3. Materials

**A material is at minimum: a base that responds to `light_level`, a lit edge and
a dark edge derived from `light_position`, and something that only appears when
the flame is near.** Below that it is a coloured rectangle.

What each surface owes:

| Surface | Must have |
|---|---|
| Parchment | warm amber near the flame, grey away; deckled edge; laid lines; contact shadow; follicles when backlit |
| Leather boards | board thickness on the side turned from the flame; raised spine cords; blind tooling with a lit lip and dark trough; gilt that is only bright when the flame is near |
| Brass / bronze / iron | a **moving** specular that tracks the flame; three metals far enough apart to tell at a glance in a dark room |
| Wax | irregular smoothed silhouette (`WaxShape`), never a polygon; a raised rim; a gloss that moves; **molten is darker than set** |
| Oak | grain; a dished hollow with a lit far wall and shaded near wall |
| Blackened wax (tablet) | pale boxwood showing through the scratch, with a dark lip on the thrown side |

### Two physics facts that were both wrong in shipped code

- **Molten wax is DARKER than set wax.** Set wax is pale because it is full of
  microcrystals that scatter light; melted, it goes clear and you see the shaded
  bottom of the cup. Drawing liquid brighter than solid turns a candle into a
  poached egg — and that is precisely why it read as flat, because there was no
  dark anywhere on it.

  **This was recorded as fixed and was only fixed on the candle.** The poured
  pool and the melting spoon — the two objects the press actually runs on — still
  had it inverted, measured at 0.280 molten against 0.176 set. Fixed 2026-07-28
  and now asserted on every wax surface in the game. If you write a third one,
  the assertion is in `test_presentation` under "wax physics".
- **A flame has a dark cone.** Directly above the wick sits unburnt vapour that
  has not reached oxygen yet, and it is darker than the luminous sheath around
  it. Without it a flame is a bright lozenge with no inside.

### And a third: which way up the flame is

`atan2` takes `(y, x)`. `candle.gd` passed `atan2(lean.x, -8.0)`, and a negative
second argument returns an angle near pi — so the whole luminous body was drawn
rotated through **147 to 180 degrees in every frame the candle was ever lit**.
The authored apex at local `(0,-10)` landed at `y = +8.4 to +10.0`: tip in the
wax, blue base at the top.

It survived the entire life of the project, including four rounds of judging this
exact object from frames and the addition of the 4x close series. At ship scale
the flame is nine pixels by thirteen, and **an upside-down teardrop still reads
as "a flame is there"**. That is the lesson: at pixel-art sizes a silhouette can
be completely wrong and still parse as the thing it depicts. Assert on where a
drawn point *ends up*, not on the angle you fed the transform.

### The material helper

`scripts/presentation/surface.gd` — `Surface`, beside `Ink` and `WaxShape`. It
was **extracted** from `ReferenceBook._draw` and `SignetRing._draw` rather than
designed, because nine scripts were computing a direction to the flame by hand in
four coordinate conventions and five were clamping the `light_level x
light_strength` product five different ways.

Use `Surface.toward(node, light_position)` and `Surface.lit(level, strength)`
rather than rolling your own. **It is `Material` in the older plan; that name does
not compile, because `Material` is a Godot built-in.**

**The cut-line convention lives there and is not obvious.** A groove's far wall
faces back toward the flame and catches it, so the **lit lip is displaced AWAY
from the light** and the dark trough toward it. `SignetRing` had this right;
`ReferenceBook` originally had it inverted, so the boards' stamped borders read
as raised rather than impressed. Its migration to `Surface` fixed that and added
the shared assertion. Extracting the two into one file is what revealed they
disagreed.

### Cheap techniques that are already proven here

- **Banded rects for a gradient.** Eight strips read as smooth falloff at this
  size and cost eight `draw_rect`s instead of a shader. See `Sheet._draw_light_gradient`.
- **Stacked offset rects for a blur.** `Draggable.draw_soft_shadow`, layer count
  is a tuning knob rather than a magic number.
- **Two offset passes for an engraved line.** A lit lip and a dark trough, offset
  along `toward_light`. One flat outline reads as printed; two read as cut.
- **Three nested silhouettes for wax.** `WaxShape.draw_body`.
- **A seeded speckle generated once.** Grain, scuffs, follicles. Generate in
  `_ready` or `bind`, never in `_draw` — a surface whose pores move between
  frames is not a surface. This rule has been broken three times.

---

## 4. Animation

**Three phases and a settle, or it is a lerp wearing a costume.**

Every physical action needs a distinguishable start, middle and end, and the
**end is an event**. The press resists, gives, seats and peels. The rack arms,
slides and lands. The door shoves, swings, arrives and rocks.

- **Nothing moves linearly.** Springs where there is mass, eased curves where
  there is not.
- **The event is the arrival, not the request.** Both door sounds used to fire on
  the frame the target was set, half a second before the leaf had moved — so the
  thud of it shutting played while it stood wide open. Emit on arrival.
- **`ease(x, c)` for `c < 1` is ease-OUT, and the warning that used to be here
  was wrong.** This document previously said `ease(x, 0.4)` has an infinite
  derivative at zero and "snaps on the first frame". **Measured, in Godot 4.6:
  it does not.** Godot computes `1 - (1-x)^(1/c)` for `0 < c < 1`, whose slope at
  zero is `1/c` — finite. `ease(1/60, 0.4)` returns **0.041**, so the first frame
  of a one-second move covers 4% of the distance. That is not a snap.

  The real hazard is the one worth knowing: it starts at **2.5x average speed**
  and decelerates. That is right for something released under tension — a page
  falling, a ring peeling off wax — and wrong for anything with mass starting
  from rest, which should begin slowly. For those use a two-sided smoothstep
  `t*t*(3-2t)`. Reach for the curve that matches the physics, not the one that
  avoids a bug that was never there.
- **Check your zeta.** A spring at ζ=0.86 overshoots by 0.47%, which after
  clamping is a tenth of a pixel — a comment claiming a spring where there is
  none. ζ≈0.6–0.8 gives an overshoot you can actually see.
- **Variance.** Anything that repeats must vary. Per-caller timing, per-press
  rotation, per-pour opacity.
- **Motion at rest.** When the player does nothing, something must still move:
  the flame wanders, dust drifts, a bead swells on the candle's lip, the
  petitioner breathes and shifts.
- **A verb must answer every time it is used.** Holding a *sound* charter to the
  flame returned nothing, so the player learned the gesture was broken rather
  than that the parchment was clean. "Nothing here" is a result and must be drawn.

---

## 5. Hard constraints

- **Diegetic only.** No HUD, no floating UI, no screen-space anything. Exactly
  one screen-space element exists (`view_hint.gd`) and each of its two captions
  retires when the player has actually visited the plane it describes.
- **`z_index` breaks the desk's stacking rule.** Draw order is child order in
  `surface`, full stop — except that a higher `z_index` draws above *all* lower-z
  siblings whatever the tree says, and `z_as_relative` is on by default. If you
  are reaching for `z_index` to get one thing above another, you want child
  order. Legitimate uses are transient and self-cancelling: a ring while in the
  hand or in the wax, a falling bead, the lens.
- **`scripts/rules/` never touches a node, a signal or the scene tree.**
- **The authored raster plates are the style anchor.** `art/` is hand-made pixel
  work; procedural drawing extends it and must never paint over it. The candle's
  melt did exactly that for months and obliterated the best-looking object on the
  desk.
- **`gl_compatibility`, not Forward+.** Runs on anything, starts fast, avoids
  Metal/MoltenVK differences between the two dev machines.

---

## 6. Performance — measured, not assumed

**Measured 2026-07-28: 5.9 ms/frame at 1600x900 with 19 draggables on the desk
and both reference books open. About 169 fps.** There is no performance problem
today, and the previous version of this section claiming the redraw pattern was a
"blocker" was speculation. It is written down here so the next person does not
inherit the assumption.

**Re-measured after the materials work later the same day: 6.07 ms, 165 fps**,
same 19 draggables, four open books, 3 outline builds. The materials pass cost
essentially nothing, and the memo still holds.

**Re-measured after the return lighting/animation pass: 9.22 ms, 108 fps** at
1600×900 with the same 19 draggables, all four books open, and 3 outline builds.
That remains under the 10 ms intervention line below, but no longer by a wide
margin. Re-run this exact stress pose before adding another broad per-frame
material layer.

**Know what the probe actually covers before you lean on the number.** The probe
lays out a packet and opens the books; it never strikes a seal, so nothing it
measures has `impressed = true`. Anything on the struck-pool path is *unpriced*
rather than *proven cheap*. When a measured number is used to wave a finding
away, check the scenario that produced it first.

What *was* real and is now fixed: `WaxShape.outline()` was being called from
inside `_draw` by the reference book's matrix and polity plates, so an open book
rebuilt a seeded polygon plus two smoothing passes every frame. It is memoised
now — the same probe reports 3 outline builds for a whole session, and the
presentation suite asserts the memo holds.

What remains, and is **speculative until somebody measures it**:
`Draggable._process` calls `queue_redraw()` unconditionally, twice per object,
every frame, with no dirty flag. So do `Desk`, `WaxPool` (four child CanvasItems)
and `ReferenceBook`. At 19 objects the current stress pose remains within
budget, but the 9.22 ms return-pass measurement means its headroom is now small
enough to watch.

**So: re-run the probe before optimising, and again after.** The current number
to beat is 9.22 ms. If a materials pass pushes it past about 10 ms, fix the dirty flag then —
`desk_ledge.gd` has the pattern to copy. Do not spend a day on it in advance of a
number.

The project has **zero `.gdshader` files and zero `CanvasItemMaterial`s.**
`gl_compatibility` supports canvas shaders; a single cheap one for parchment
translucency or wax subsurface would replace a lot of banded-rect faking. Confirm
the available feature set with `godot-reviewer` before committing to it.

## 7. The workflow that works

1. **Run the four suites.** Know that green is green before you start.
2. **Capture, and open the frames.** Form your opinion from pixels.
3. **Fan out the reviewers cold**, in parallel, before a large pass. The signal
   worth acting on is **convergence** — several agents sharing no context naming
   the same defect.
4. **Adversarially verify anything you are about to act on.** Nine of sixteen
   review claims in one session were wrong on inspection. The one that was most
   right rendered a frame and measured the ink bands.
5. **Change one thing. Re-capture. Compare.** The candle took four iterations and
   each one was judged from a frame, including the one where I had the wax
   physics backwards.
6. **Add the assertion that would have caught it**, then commit with a message
   that says what was wrong and why the fix is the right *shape*.
