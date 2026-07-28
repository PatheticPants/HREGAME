class_name ImpressionRecord
extends Resource

## What the player's hands actually did during one signet press.
##
## Craft is the third axis, alongside soundness and favour. The brief did not ask
## for it; it is here because if the press is the money moment then it has to be
## possible to do it well or badly, and to be told which. A ruling that is legally
## right and physically botched still goes into the ledger as a botched seal.

@export var grade: int = Lex.Grade.GOOD

## Raw measurements, kept so the grading thresholds can be retuned without
## replaying anything.
@export var wax_amount: float = 0.0
@export var seat_depth: float = 0.0
@export var drift: float = 0.0
@export var ring_rotation_deg: float = 0.0
@export var shape_seed: int = 0

## True if the pool ran over the written text. Cosmetic, but the ledger notices.
@export var obscured_text: bool = false


func describe() -> String:
	match grade:
		Lex.Grade.FINE: return "a clean seal, well centred"
		Lex.Grade.GOOD: return "a sound seal"
		Lex.Grade.THIN: return "thin wax; the device barely took"
		Lex.Grade.BLOTTED: return "over-poured; the wax ran"
		Lex.Grade.SMEARED: return "smeared — the ring moved before it set"
		Lex.Grade.SHALLOW: return "pressed shallow; the impression is faint"
		_: return "a seal"
