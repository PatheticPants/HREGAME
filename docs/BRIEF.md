# Claude Code Kickoff Prompt — *Hand and Seal*

> Paste everything below the line into Claude Code as your first message. Keep this file in the repo as `docs/BRIEF.md` afterward.

---

I'm building a desktop game in **Godot 4 (GDScript)** and I want you to help me build the first vertical slice. Read this whole brief before writing any code. Working title: **Hand and Seal**.

## What the game is

A *Papers, Please*-style document inspection game set in a fictionalized Holy Roman Empire. The player is a low-born notary of the Imperial Chancery. Petitioners bring claims to land and title — charters, wax seals, witness lists, genealogies — and the player must verify each claim against a body of law, then rule on it.

The Empire's overlapping legal authorities are the point: imperial law, regional custom, and church law can each say something different about the same claim, so the player often isn't asking "is this correct?" but "which authority am I choosing to satisfy?"

The long campaign builds toward a contested imperial election, where every ruling has quietly shifted land and votes between the great houses. **None of that is in scope for this slice.** It's context so your architecture doesn't paint me into a corner.

## Scope of this slice — build ONLY this

A single playable session containing:

1. One desk scene. One petitioner arrives, presents a claim packet, waits.
2. The packet contains **two documents**: a charter (body text, a date, a witness list) and an attached wax seal impression.
3. **Two verification checks** are possible:
   - **Seal check** — compare the impression against a reference book of known seal matrices.
   - **Date check** — the charter is dated by regnal year ("in the ninth year of Emperor Aldric"); convert it using a reference table and confirm it's consistent with the other facts in the packet.
4. Three verdicts: **Confirm**, **Deny**, **Refer**.
5. The verdict is executed by dripping wax from a candle onto the document and pressing a signet ring into it.
6. Feedback on whether the ruling was correct, then the session ends.

Three hand-authored cases is enough content: one clean, one with a forged seal, one with an impossible date.

## The thing that actually matters

**Game feel is the deliverable here, not features.** If dragging a piece of paper and pressing the signet doesn't feel good in isolation, the project is dead, so I'd rather have two documents that feel excellent than eight that feel like UI. Specifically:

**Paper handling**
- Documents are physical objects dragged with the mouse. They carry momentum and rotate slightly toward the drag direction, then settle.
- Real z-ordering: picking a document up brings it to the top and it stays there. Drop shadows that respond to stacking.
- **The desk is deliberately too small.** Papers overlap and get buried, and digging for the one you need is a mechanic, not a bug. Do not add a "tidy desk" button or auto-arrange.

**The signet press** — this is the money moment, so break it into distinct phases with separate feedback on each:
- Tilt the candle; wax drips and pools with a slight spread.
- Press the ring; brief resistance before it seats.
- Lift; the ring peels away.
- Randomize pool shape, wax opacity, and one to two degrees of ring rotation on **every** press. No two impressions should be identical.

**Diegetic only.** No floating HUD, no menus over the world, no health-bar-style meters. The rulebook is a physical book on the desk that opens and flips. The seal reference is a physical book. The candle and lens are objects you drag. Everything the player uses takes up desk space.

**Audio.** Stub in placeholder sounds but wire the hooks properly from the start: paper slide, paper pickup, book page turn, wax drip, ring press, ring lift, door knock. Sound is most of what "feels good" means and retrofitting it is miserable.

## Technical requirements

- **Godot 4.x, GDScript.** No C#, no third-party addons unless you tell me why and I approve it.
- **Content must be data, not code.** Cases, documents, seal matrices, and the regnal-year table live in `.tres` Resources or JSON under `data/`. I need to author new cases without touching a script.
- Define a `Case` resource that owns its documents, its ground-truth correct verdict, and the reason it's correct. The validation logic reads the data; it does not hardcode case specifics.
- Separate **presentation** (drag physics, wax rendering, audio) from **rules** (is this claim valid). They will change at completely different rates.
- I work across a **Mac laptop and a Windows desktop over GitHub**, so: proper Godot `.gitignore`, no absolute paths, case-sensitive filenames handled consistently, and confirm the project opens clean on both.
- Placeholder art is fine and expected — flat colored rectangles with legible labels. Do not spend effort on art. Do make sure the *motion* is right, because that's what I'm evaluating.

## How I want you to work

- **Start by proposing the scene tree and the data schema, and stop for my approval before implementing.** Don't write the whole slice in one pass.
- Build in this order: paper dragging → signet press → reference books → case data → validation → verdict feedback. Feel first, rules last.
- **Do not add anything not listed above.** No settings menu, no save system, no tutorial, no extra document types, no score screen, no additional cases beyond the three. If you think something is missing, say so and let me decide.
- Keep functions short and comment the non-obvious parts of the drag and wax code specifically, since I'll be tuning those by hand.
- After each milestone, tell me what to look at and what specifically to judge.

Start with the scene tree and data schema proposal.

---

## Appendix — design context (for later milestones, not this slice)

Not to be built now. Included so architectural decisions account for it.

**Additional verification types planned:** genealogy and degrees of consanguinity; witness lists cross-referenced against known deaths, imprisonments, and absences; palaeography (two scribal hands in one document indicating interpolation); scraped-and-rewritten parchment revealed by candlelight; jurisdiction (whether this court has authority at all).

**The Register.** The player's own past rulings become a third reference source alongside imperial law and regional custom. Petitioners can cite the player's own precedent back at them, correctly. The case validation architecture should be able to consult a ruling history, not just static law.

**Two meters, not one.** *Correctness* (did you follow the law) and *Favor* (are you useful to power), pulling in opposite directions. Both must stay above water.

**The economy.** The office pays its own costs — ink, parchment, a clerk, and above all access to updated reference books. Bribes are tempting because taking them is how the player affords to do the job properly.

**Setting constraints.** Cap the Empire at six to nine named polities, each with a heraldic color, a distinct succession custom, and a seal design. Learnability is the whole game.

**Narrative hooks.** A predecessor's annotations in the Register, partly helpful and partly a coded record of payments. Retroactive legality via church dispensation, so an invalid claim can become valid weeks later. A regional archive fire that removes a whole class of verification mid-campaign. One recurring sympathetic claimant whose fate traces back to the player's rulings.
