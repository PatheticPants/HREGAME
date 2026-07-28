class_name VerdictRule
extends Resource

## "If any finding of this severity is present, the ruling is that."
##
## Rules are evaluated in order, so the array in verdict_policy.tres is the whole
## adjudication doctrine, editable without opening a script. Reordering these two
## lines changes what the Chancery is for.

@export var severity: int = Lex.Severity.FATAL
@export var verdict: int = Lex.Verdict.DENY

## Shown in the ledger as the grounds. Keep it in the voice of the office.
@export var grounds: String = ""
