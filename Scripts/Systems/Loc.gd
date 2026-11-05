class_name Loc
extends RefCounted
## Translation. Interface text goes through tr() in nodes, or Loc.t() where there is no node.
## Text the host writes for everyone (the Chronicle, refused requests, what a player declared)
## travels as a message, {"k": msgid, "a": {name: value}}, and every player's game translates
## it into their own language when it is shown.
##
## In a msgid, {name} is a placeholder when the message has an argument of that name; the
## icon names ({combat}, {gold}, ...) are icon tokens, so no argument may use one of them.
## An argument is an int, a String shown as it is, a nested message, or a reference that is
## named in the reader's language: Loc.player(), Loc.mob(), Loc.boss(), Loc.trinket(), Loc.face().
##
## tools/i18n.py collects every msgid from tr(), Loc.t(), Loc.msg() and log_event() calls, the
## scenes and the content resources into Locale/messages.pot, and checks the translations.

## Languages with a translation in Locale/, by locale code, with their own name for themselves.
const LANGUAGES: Dictionary[String, String] = {"en": "English", "de": "Deutsch"}

static var _placeholder := RegEx.create_from_string("\\{([a-z_0-9]+)\\}")


static func t(msgid: String) -> String:
	return String(TranslationServer.translate(msgid))


## Marks text for translation without translating it: for msgids that are stored or sent
## and translated where they are shown.
static func n(msgid: String) -> String:
	return msgid


static func msg(key: String, args: Dictionary = {}) -> Dictionary:
	return {"k": key, "a": args}


static func player(p: PlayerState) -> Dictionary:
	return {"player": p.name, "seat": p.seat}


static func mob(id: StringName) -> Dictionary:
	return {"mob": id}


static func boss(id: StringName) -> Dictionary:
	return {"boss": id}


static func trinket(id: StringName) -> Dictionary:
	return {"trinket": id}


static func face(value: int) -> Dictionary:
	return {"face": value}


## The language to use: the player's choice, else the system language if there is a
## translation for it, else English.
static func resolve_language(choice: String) -> String:
	if LANGUAGES.has(choice):
		return choice
	var system := OS.get_locale_language()
	return system if LANGUAGES.has(system) else "en"


## A message as plain text, with {icon} tokens left in for Icons.rich() or Icons.plain().
static func text(message: Dictionary) -> String:
	if message.is_empty():
		return ""
	var template := t(str(message.get("k", "")))
	var args: Dictionary = message.get("a", {})
	var out := ""
	var last := 0
	for found in _placeholder.search_all(template):
		var key := found.get_string(1)
		if not args.has(key):
			continue
		out += template.substr(last, found.get_start() - last) + _plain(args[key])
		last = found.get_end()
	return out + template.substr(last)


## A message as BBCode with icons. Players' names are escaped, and drawn bold in their seat
## colour when `colour_names` is set.
static func rich(message: Dictionary, icon_size: int = 20, colour_names: bool = false) -> String:
	if message.is_empty():
		return ""
	var template := t(str(message.get("k", "")))
	var args: Dictionary = message.get("a", {})
	var out := ""
	var last := 0
	for found in _placeholder.search_all(template):
		var key := found.get_string(1)
		if not args.has(key):
			continue
		out += Icons.rich(template.substr(last, found.get_start() - last), icon_size)
		out += _rich(args[key], icon_size, colour_names)
		last = found.get_end()
	return out + Icons.rich(template.substr(last), icon_size)


static func _plain(value: Variant) -> String:
	if value is Dictionary:
		var ref: Dictionary = value
		if ref.has("k"):
			return text(ref)
		if ref.has("player"):
			return str(ref.player)
		return _content_name(ref)
	return str(value)


static func _rich(value: Variant, icon_size: int, colour_names: bool) -> String:
	if value is Dictionary:
		var ref: Dictionary = value
		if ref.has("k"):
			return rich(ref, icon_size, colour_names)
		if ref.has("player"):
			var shown := Icons.rich(str(ref.player), icon_size)
			if not colour_names:
				return shown
			var colour := SeatStyle.color(int(ref.get("seat", 0))).darkened(0.35).to_html(false)
			return "[color=#%s][b]%s[/b][/color]" % [colour, shown]
		return Icons.rich(_content_name(ref), icon_size)
	return Icons.rich(str(value), icon_size)


static func _content_name(ref: Dictionary) -> String:
	if ref.has("mob"):
		var found_mob := Content.mob(ref.mob)
		return found_mob.name_text() if found_mob else "?"
	if ref.has("boss"):
		var found_boss := Content.boss(ref.boss)
		return found_boss.name_text() if found_boss else "?"
	if ref.has("trinket"):
		var found_trinket := Content.trinket(ref.trinket)
		return found_trinket.name_text() if found_trinket else "?"
	if ref.has("face"):
		return Face.label(int(ref.face))
	return "?"
