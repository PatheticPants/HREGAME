class_name PetitionerData
extends Resource

@export var id: StringName = &""
@export var name: String = ""
@export var style: String = ""
@export var polity_id: StringName = &""
@export_file("*.png") var portrait_path: String = ""

## Presentation scale. Height and build still differ per petitioner, but the
## authored sprite supplies their face, clothing and silhouette.
@export var height: float = 250.0
@export var build: float = 92.0
@export var cloth: Color = Color(0.35, 0.32, 0.30)

## How restless they are while waiting, 0..1. Drives the idle sway and how often
## they shift their weight. A nervous cooper and a serene monk should not stand
## the same way.
@export var restlessness: float = 0.5
