class_name Face
extends RefCounted
## A die face packed into one int: kind * 16 + value. Faces are plain ints so dice copy,
## compare and serialize cheaply. Value is 1..15. Text uses {icon} tokens (see Icons).

enum Kind { NONE, COMBAT, GOLD, CUNNING, GUARD, HEAL, WILD, RENOWN, DOUBLE }

## Kinds a wild face may become.
const WILD_CHOICES: Array[Kind] = [Kind.COMBAT, Kind.GOLD, Kind.CUNNING]

const ICONS: Dictionary = {
	Kind.NONE: "{blank}",
	Kind.COMBAT: "{combat}",
	Kind.GOLD: "{gold}",
	Kind.CUNNING: "{cunning}",
	Kind.GUARD: "{guard}",
	Kind.HEAL: "{heal}",
	Kind.WILD: "{wild}",
	Kind.RENOWN: "{renown}",
	Kind.DOUBLE: "{double}",
}

const NAMES: Dictionary = {
	Kind.NONE: "Blank",
	Kind.COMBAT: "Combat",
	Kind.GOLD: "Gold",
	Kind.CUNNING: "Cunning",
	Kind.GUARD: "Guard",
	Kind.HEAL: "Heal",
	Kind.WILD: "Wild",
	Kind.RENOWN: "Renown",
	Kind.DOUBLE: "Double",
}


static func make(kind: Kind, value: int) -> int:
	return int(kind) * 16 + clampi(value, 0, 15)


static func kind_of(face: int) -> Kind:
	return (face >> 4) as Kind


static func value_of(face: int) -> int:
	return face & 15


static func icon(kind: Kind) -> String:
	return ICONS.get(kind, "?")


static func label(face: int) -> String:
	var kind := kind_of(face)
	if kind == Kind.DOUBLE:
		return "{double}"
	return "%s%d" % [icon(kind), value_of(face)]


static func describe(face: int) -> String:
	var kind := kind_of(face)
	var value := value_of(face)
	match kind:
		Kind.GUARD:
			return "%d combat usable only as guard" % value
		Kind.HEAL:
			return "Heal %d" % value
		Kind.WILD:
			return "%d of combat, gold or cunning (your choice)" % value
		Kind.RENOWN:
			return "Gain %d renown" % value
		Kind.DOUBLE:
			return "Doubles your highest other face"
	return "%d %s" % [value, NAMES.get(kind, "?").to_lower()]
