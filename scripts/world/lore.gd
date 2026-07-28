extends Node

## Autoload. Loads data/ once and hands it out.
##
## This is a *read-only* window onto content. The rules layer never touches it —
## checks receive a CheckContext built from this, so they stay runnable headless.
## Presentation is allowed to read it directly, because a paper needs to know its
## polity's colour and threading that through six constructors buys nothing.

signal content_reloaded

var data: LoreData = null


func _ready() -> void:
	reload()


func reload() -> void:
	data = ContentLoader.load_all()
	for e in data.errors:
		push_error("[content] %s" % e)
	if not data.errors.is_empty():
		push_warning("[content] %d problem(s) in data/. The desk will still open; "
			% data.errors.size() + "affected cases may be incomplete.")
	content_reloaded.emit()


# Passthroughs, purely to keep call sites short at the draw layer.

func polity(id: StringName) -> Polity:
	return data.polity(id) if data else null


func reign(id: StringName) -> Reign:
	return data.reign(id) if data else null


func matrix(id: StringName) -> SealMatrix:
	return data.matrix(id) if data else null


func book(id: StringName) -> BookData:
	return data.book(id) if data else null


func present_year() -> int:
	return data.present_year if data else 0


func paper_feel() -> PaperFeel:
	return data.paper_feel if data else PaperFeel.new()


func wax_feel() -> WaxFeel:
	return data.wax_feel if data else WaxFeel.new()


## Heraldic colour for a polity, with a neutral fallback so a typo in content
## produces grey parchment rather than a crash.
func tincture(id: StringName, fallback := Color(0.6, 0.6, 0.6)) -> Color:
	var p := polity(id)
	return p.color if p else fallback
