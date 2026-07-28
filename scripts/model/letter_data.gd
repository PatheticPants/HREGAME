class_name LetterData
extends DocumentData

## Political correspondence that arrives between working days. It can be read,
## moved, buried, and kept beside the Register, but no verification check treats
## a demand from a powerful office as proof.

@export var sender: String = ""
@export var recipient: String = ""
@export_multiline var body: String = ""
@export var closing: String = ""
@export var endorsements: Array[String] = []
