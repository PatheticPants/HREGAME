class_name Check
extends RefCounted

## Base class for a verification. Subclasses read the context and return findings.
##
## The contract is narrow on purpose: no state, no side effects, no knowledge of
## any particular case. A check that needs to know which case it is running on is
## a check that has hardcoded content, and is wrong.

func id() -> StringName:
	return &"check"


func label() -> String:
	return "Check"


func run(_ctx: CheckContext) -> Array[Finding]:
	return []
