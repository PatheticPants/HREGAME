class_name PaperFeel
extends Resource

## Every constant in the drag simulation, in one place, editable while the game
## runs. Open data/tuning/paper_feel.tres in the inspector with the project
## playing and drag the sliders — the solver reads this resource every step.
##
## Read drag_solver.gd alongside this. The names map one-to-one.

@export_group("Spring")
## How hard the grab point is pulled toward the cursor. Higher = the sheet keeps
## up with you; lower = it trails and feels heavy. This is the first dial to move.
@export_range(20.0, 900.0, 1.0) var stiffness: float = 210.0
## Opposes velocity while held. Too low and the sheet oscillates around the
## cursor; too high and it stops feeling like an object with mass.
@export_range(2.0, 60.0, 0.1) var damping: float = 21.0

@export_group("Rotation")
## Scales the torque produced by pulling off-centre. 0 disables lean entirely and
## the sheet slides flat. This is the dial that makes paper read as paper.
@export_range(0.0, 6.0, 0.01) var torque_gain: float = 1.35
## Stand-in for 1/moment-of-inertia. Higher = the sheet swings more eagerly.
@export_range(0.000005, 0.0006, 0.000001) var inverse_inertia: float = 0.000085
@export_range(0.0, 40.0, 0.1) var angular_damping: float = 9.5
## Hard limit on lean away from the sheet's resting angle. Without this a fast
## flick can spin a charter like a propeller, which is funny once.
@export_range(1.0, 45.0, 0.5) var max_lean_deg: float = 15.0

@export_group("Release")
## Per-second velocity retention after release. 0.02 means 2% of speed survives
## one second — applied as pow(x, dt) so it is frame-rate independent.
@export_range(0.0001, 0.6, 0.0001) var release_damping: float = 0.012
@export_range(0.0001, 0.6, 0.0001) var release_angular_damping: float = 0.004
## Pull back toward the resting angle after release. Keep this small: sheets
## should settle roughly square, never perfectly square.
@export_range(0.0, 120.0, 0.5) var settle_spring: float = 26.0
@export_range(1.0, 200.0, 1.0) var sleep_speed: float = 9.0
@export_range(0.01, 4.0, 0.01) var sleep_spin: float = 0.22

@export_group("Desk edges")
## Soft walls. A paper may overhang the desk rim but is pushed back — a hard
## clamp reads as an invisible wall, a spring reads as the sheet catching.
@export_range(0.0, 60.0, 0.5) var edge_spring: float = 15.0
@export_range(0.0, 400.0, 1.0) var edge_allowance: float = 120.0

@export_group("Pickup")
## Scale-up on pickup. Small — this is a lift, not a zoom.
@export_range(1.0, 1.2, 0.001) var pickup_scale: float = 1.035
@export_range(0.0, 40.0, 0.5) var pickup_scale_speed: float = 14.0
## Extra shadow throw while held, in desk units. Most of the "I lifted this off
## the pile" feeling lives here, not in the scale.
@export_range(0.0, 60.0, 0.5) var pickup_shadow_lift: float = 22.0

@export_group("Shadow")
@export_range(0.0, 40.0, 0.5) var shadow_base_throw: float = 5.0
## Additional throw per sheet of stack height beneath this one.
@export_range(0.0, 6.0, 0.05) var shadow_throw_per_layer: float = 0.9
@export_range(0.0, 1.0, 0.01) var shadow_alpha: float = 0.34
@export_range(1, 8, 1) var shadow_layers: int = 4

@export_group("Audio")
## Speed above which the paper-slide loop is audible, and the speed at which it
## reaches full volume.
@export_range(1.0, 400.0, 1.0) var slide_audible_speed: float = 55.0
@export_range(50.0, 2500.0, 5.0) var slide_full_speed: float = 850.0
