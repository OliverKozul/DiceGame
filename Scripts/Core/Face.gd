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

## English kind names for tools and logs; players see kind_name().
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


## A kind's name in the player's language.
static func kind_name(kind: Kind) -> String:
	match kind:
		Kind.COMBAT:
			return Loc.t("Combat")
		Kind.GOLD:
			return Loc.t("Gold")
		Kind.CUNNING:
			return Loc.t("Cunning")
		Kind.GUARD:
			return Loc.t("Guard")
		Kind.HEAL:
			return Loc.t("Heal")
		Kind.WILD:
			return Loc.t("Wild")
		Kind.RENOWN:
			return Loc.t("Renown")
		Kind.DOUBLE:
			return Loc.t("Double")
	return Loc.t("Blank")


## What a face does, in the player's language.
static func describe(face: int) -> String:
	var kind := kind_of(face)
	var value := value_of(face)
	match kind:
		Kind.COMBAT:
			return Loc.t("{value} combat").format({"value": value})
		Kind.GOLD:
			return Loc.t("{value} gold").format({"value": value})
		Kind.CUNNING:
			return Loc.t("{value} cunning").format({"value": value})
		Kind.GUARD:
			return Loc.t("{value} combat usable only as guard").format({"value": value})
		Kind.HEAL:
			return Loc.t("Heal {value}").format({"value": value})
		Kind.WILD:
			return Loc.t("{value} of combat, gold or cunning (your choice)").format({"value": value})
		Kind.RENOWN:
			return Loc.t("Gain {value} renown").format({"value": value})
		Kind.DOUBLE:
			return Loc.t("Doubles your highest other face")
	return Loc.t("Blank")
