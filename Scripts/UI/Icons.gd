class_name Icons
extends RefCounted
## The hand-drawn icon set. Game text uses tokens such as "{combat}3"; rich() turns them into
## inline images for RichTextLabels, texture() gives the icon for buttons and TextureRects.

const DIR := "res://Assets/Icons/"
const NAMES: Array[String] = [
	"combat", "gold", "cunning", "guard", "heal", "renown", "wild", "double", "blank",
	"score", "die", "trinket", "lock", "crown", "knockout", "sabotage",
]

static var _token := RegEx.create_from_string("\\{([a-z]+)\\}")


static func texture(icon_name: String) -> Texture2D:
	return load(DIR + icon_name + ".svg") if NAMES.has(icon_name) else null


static func bb(icon_name: String, size: int = 20) -> String:
	return "[img=%d]%s%s.svg[/img]" % [size, DIR, icon_name]


static func for_kind(kind: Face.Kind) -> String:
	match kind:
		Face.Kind.COMBAT:
			return "combat"
		Face.Kind.GOLD:
			return "gold"
		Face.Kind.CUNNING:
			return "cunning"
		Face.Kind.GUARD:
			return "guard"
		Face.Kind.HEAL:
			return "heal"
		Face.Kind.WILD:
			return "wild"
		Face.Kind.RENOWN:
			return "renown"
		Face.Kind.DOUBLE:
			return "double"
	return "blank"


## BBCode for text from the game: escapes brackets, then turns {icon} tokens into images.
static func rich(text: String, size: int = 20) -> String:
	var escaped := text.replace("[", "[lb]")
	var out := ""
	var last := 0
	for match_result in _token.search_all(escaped):
		out += escaped.substr(last, match_result.get_start() - last)
		var icon_name := match_result.get_string(1)
		out += bb(icon_name, size) if NAMES.has(icon_name) else match_result.get_string()
		last = match_result.get_end()
	return out + escaped.substr(last)


## Plain text with tokens replaced by words, for places that cannot show images.
static func plain(text: String) -> String:
	var out := text
	for icon_name in NAMES:
		out = out.replace("{%s}" % icon_name, icon_name + " ")
	return out
