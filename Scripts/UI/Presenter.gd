class_name Presenter
extends RefCounted
## Turns the host's events into animations on the table. Plays one batch of events (the
## ones that led to a new view) and returns when they are done; the screen then shows the
## new view. Every duration goes through GameScreen.duration(), so animation speed, catch-up
## after lag, reduced motion and skipping all apply.
##
## The language of the table: slashes run from whoever acts to whatever they act on, the
## target takes the blow (flash, punch, sparks, a number), and whatever changes hands flies
## there as an icon. The biggest moments (knockouts, a boss falling) freeze for a beat.

const DAMAGE := Color("ff8a6e")
const HEAL := Color("8fe08f")
const GOLD := Color("f3c94b")
const RENOWN := Color("f6d38a")
const NEUTRAL := Color("f1e4c6")
const SLASH := Color("ffe6b8")
const BLOOD := Color("e2482f")
const AMBUSH := Color("d1301c")
const GUARD := Color("bcd6ff")
const EMBER := Color("ff9a3c")
const ACT_NUMERALS: Array[String] = ["", "I", "II", "III", "IV", "V"]
## How far a slash between two seats bows out over the table, in pixels.
const SEAT_ARC := 150.0

var _screen: GameScreen
## Whether each player kept their word this turn (an attack by someone who broke it is an ambush).
var _kept: Dictionary[int, bool] = {}


func _init(screen: GameScreen) -> void:
	_screen = screen


func play(events: Array, view: GameState) -> void:
	for event: Dictionary in events:
		# The table may have been closed while an animation was playing.
		if not is_instance_valid(_screen) or not _screen.is_inside_tree():
			return
		await _play_event(event, view)


func _seat(pid: int) -> SeatCard:
	return _screen.seat_card(pid)


## Where a seat, or any control, is on the effects layer.
func _at(control: Control) -> Vector2:
	return Juice.center_in(control, _screen.fx) if control else _screen.stage_center()


func _seat_at(pid: int) -> Vector2:
	return _at(_seat(pid))


func _play_event(e: Dictionary, view: GameState) -> void:
	var d := _screen.duration
	var me := _screen.me
	var fx := _screen.fx
	match str(e.type):
		"turn_start":
			_kept.clear()
			for card in _screen.seat_cards():
				card.clear_stamp()
			var p := view.player(me)
			if p and p.is_active():
				_screen.throw_my_dice(PackedInt32Array(range(p.dice.size())), view)
			_screen.show_phase(GameState.Phase.ROLL, e.turn)
			await _screen.banner(_screen.tr("Turn {turn}").format({"turn": e.turn}), d.call(1.3))
			await _screen.wait_for_dice()
		"reroll":
			if e.pid == me:
				await _screen.throw_my_dice(e.dice, view)
			else:
				Audio.play(&"die_hit", -6.0)
				await _pause(d.call(0.15))
		"kept":
			if e.pid == me:
				# Your roll's worth flies from the tray to your seat.
				var flights := 0
				for key: String in ["combat", "gold", "cunning"]:
					if int(e.get(key, 0)) > 0:
						Juice.fly(fx, _at(_screen.tray), _seat_at(me), key, d.call(0.5), 30.0, d.call(0.08) * flights)
						flights += 1
				if flights > 0:
					await _pause(d.call(0.5 + 0.08 * flights))
			var seat := _seat(e.pid)
			if seat and e.gold > 0:
				seat.float_text("+%d {gold}" % e.gold, GOLD, d.call(0.9))
				if e.pid == me:
					Audio.play(&"coins", -4.0)
			if seat and e.renown > 0:
				seat.float_text("+%d {renown}" % e.renown, RENOWN, d.call(0.9))
			await _pause(d.call(0.2))
		"initiative":
			_screen.show_phase(GameState.Phase.DECLARE)
			Audio.play(&"card_slide", -6.0)
			await _pause(d.call(0.2))
		"declare":
			var seat := _seat(e.pid)
			if seat:
				Audio.play(&"card_slide", -4.0)
				Juice.pop(seat, 0.04, d.call(0.3))
				await seat.flip_strip(SeatCard.says(Loc.rich(e.said, 16)), d.call(0.35))
		"locked":
			_screen.show_phase(GameState.Phase.PLAN)
			var seat := _seat(e.pid)
			if seat:
				seat.pulse(Color(1.3, 1.2, 0.9))
				Juice.pop(seat, 0.03, d.call(0.25))
			Audio.play(&"lock", -10.0)
			await _pause(d.call(0.1))
		"reveal":
			await _reveal(e)
		"backstab":
			var seat := _seat(e.pid)
			if seat:
				seat.float_text(_screen.tr("backstab +{amount} {combat}").format({"amount": e.amount}), AMBUSH, d.call(0.9))
			await _pause(d.call(0.2))
		"attack":
			await _attack(e)
		"whiff":
			var seat := _seat(e.pid)
			if seat:
				seat.float_text(_screen.tr("too late"), NEUTRAL, d.call(0.8))
				Juice.wobble(seat, 2.0, d.call(0.3))
			await _pause(d.call(0.3))
		"mob_kill":
			var from := _seat_at(e.pid)
			var row := _screen.mob_row(e.slot)
			var mobs := _at(row)
			Audio.play(&"attack", -4.0)
			await Juice.streak(fx, from, mobs, SLASH, d.call(0.2), 12.0, -60.0)
			Audio.play(&"hit", -4.0)
			Juice.punch(row, 1.0, 0.8, d.call(0.35))
			Juice.burst(fx, mobs, GOLD, 22, 240.0)
			Juice.burst(fx, mobs, EMBER, 18, 160.0, 0.8, -80.0)
			_screen.add_trauma(0.15)
			if row is MobRow:
				(row as MobRow).burn(d.call(0.5))
			await Juice.fly(fx, mobs, from, "score", d.call(0.45))
			var seat := _seat(e.pid)
			if seat:
				Juice.pop(seat, 0.06, d.call(0.3))
				seat.float_text("+%d {score}" % e.get("score", Content.MOB_TIER_SCORE[0]), RENOWN, d.call(1.0), true)
			await _pause(d.call(0.2))
		"mob_fail":
			var from := _seat_at(e.pid)
			var row := _screen.mob_row(e.slot)
			var mobs := _at(row)
			await Juice.streak(fx, from, mobs, SLASH, d.call(0.2), 12.0, -60.0)
			Juice.wobble(row, 3.0, d.call(0.3))
			await Juice.streak(fx, mobs, from, BLOOD, d.call(0.2), 14.0, 60.0)
			_hurt(e.pid, e.damage, d)
			await _pause(d.call(0.35))
		"boss_hit":
			var from := _seat_at(e.pid)
			var boss := _at(_screen.boss_card)
			Audio.play(&"attack", -4.0)
			await Juice.streak(fx, from, boss, SLASH, d.call(0.22), 12.0, -80.0)
			Audio.play(&"hit", -3.0)
			_screen.flash(_screen.boss_card)
			Juice.punch(_screen.boss_card, 1.0, clampf(e.damage / 3.0, 0.5, 1.6), d.call(0.4))
			Juice.burst(fx, boss, EMBER, 10 + 3 * e.damage, 240.0)
			_screen.add_trauma(0.08 * e.damage)
			await _screen.boss_hit(e.pid, e.hp, e.damage, d.call(0.45))
		"boss_slain":
			var boss := _at(_screen.boss_card)
			Audio.play(&"stamp", 0.0)
			_screen.add_trauma(0.9)
			_screen.pulse_edges(EMBER, 0.45, d.call(0.9))
			await Juice.hit_stop(_screen.get_tree(), 0.15)
			Juice.burst(fx, boss, EMBER, 60, 420.0, 1.1, -60.0, 1.6)
			Juice.burst(fx, boss, GOLD, 30, 300.0, 0.9, 200.0)
			await _screen.banner(_screen.tr("The boss falls!"), d.call(1.4))
		"boss_strike":
			var boss := _at(_screen.boss_card)
			var to := _seat_at(e.pid)
			Juice.punch(_screen.boss_card, -1.0, 0.6, d.call(0.3))
			await Juice.streak(fx, boss, to, BLOOD, d.call(0.22), 14.0, 80.0)
			if e.damage > 0:
				_hurt(e.pid, e.damage, d)
			else:
				_blocked(e.pid, d)
			await _pause(d.call(0.35))
		"boss_reward":
			var boss := _at(_screen.boss_card)
			var slayers: Array[int] = []
			slayers.assign(e.pids)
			for i in slayers.size():
				Juice.fly(fx, boss, _seat_at(slayers[i]), "score", d.call(0.55), 30.0, d.call(0.08) * i)
			await _pause(d.call(0.6 + 0.08 * slayers.size()))
			for pid in slayers:
				var seat := _seat(pid)
				if seat:
					Juice.pop(seat, 0.06, d.call(0.3))
					seat.float_text("+%d {score}" % Content.BOSS_KILL_SCORE, RENOWN, d.call(1.0), true)
			await _pause(d.call(0.3))
		"rest", "heal":
			var seat := _seat(e.pid)
			var amount: int = e.get("healed", e.get("amount", 0))
			if seat and amount > 0:
				Juice.burst(fx, _at(seat), HEAL, 14, 120.0, 0.8, -120.0)
				seat.float_text("+%d {heal}" % amount, HEAL, d.call(0.9))
			await _pause(d.call(0.3))
		"steal":
			await _steal(e)
		"knockout":
			var at := _seat_at(e.pid)
			Audio.play(&"knockout", 0.0)
			_screen.add_trauma(0.8)
			_screen.pulse_edges(BLOOD, 0.4, d.call(0.8))
			await Juice.hit_stop(_screen.get_tree(), 0.12)
			Juice.burst(fx, at, BLOOD, 40, 320.0, 0.9, 300.0, 1.3)
			var seat := _seat(e.pid)
			if seat:
				Juice.punch(seat, 1.0, 2.0, d.call(0.5))
				seat.stamp(_screen.tr("Knocked out"), "lied", d.call(0.4))
			await _pause(d.call(0.5))
		"trinket":
			var seat := _seat(e.pid)
			var trinket := Content.trinket(e.trinket)
			if seat and trinket:
				Juice.burst(fx, _at(seat), GOLD, 12, 160.0, 0.6, 100.0)
				seat.float_text("{trinket} %s" % trinket.name_text(), GOLD, d.call(1.2))
			await _pause(d.call(0.4))
		"shop":
			var seat := _seat(e.pid)
			if seat:
				seat.pulse(Color(1.25, 1.15, 0.85))
			Audio.play(&"door_open", -10.0)
			await _pause(d.call(0.2))
		"buy_face":
			Audio.play(&"coins", -4.0)
			if e.pid == me:
				await Juice.fly(fx, _at(_screen.market_card), _at(_screen.tray), Icons.for_kind(Face.kind_of(e.face)), d.call(0.45), 40.0)
				await _screen.present_my_face(e.die, e.index, e.face)
			else:
				await Juice.fly(fx, _at(_screen.market_card), _seat_at(e.pid), Icons.for_kind(Face.kind_of(e.face)), d.call(0.45), 34.0)
			var seat := _seat(e.pid)
			if seat:
				Juice.pop(seat, 0.05, d.call(0.25))
				seat.float_text(Face.label(e.face), GOLD, d.call(0.9))
			await _pause(d.call(0.2))
		"upgrade":
			Audio.play(&"coins", -4.0)
			if e.pid == me:
				Juice.burst(fx, _at(_screen.tray), GOLD, 16, 180.0, 0.6, 80.0)
				await _screen.present_my_face(e.die, e.index, e.face)
			var seat := _seat(e.pid)
			if seat:
				Juice.burst(fx, _at(seat), GOLD, 12, 150.0, 0.6, 80.0)
				seat.float_text("%s → %s" % [Face.label(e.old), Face.label(e.face)], GOLD, d.call(0.9))
			await _pause(d.call(0.3))
		"buy_renown":
			Audio.play(&"coins", -4.0)
			await Juice.fly(fx, _at(_screen.market_card), _seat_at(e.pid), "renown", d.call(0.45))
			var seat := _seat(e.pid)
			if seat:
				seat.float_text("+1 {renown}", RENOWN, d.call(0.9))
			await _pause(d.call(0.15))
		"buy_die", "new_die":
			var seat := _seat(e.pid)
			if seat:
				Juice.pop(seat, 0.05, d.call(0.25))
				seat.float_text("+1 {die}", GOLD, d.call(0.9))
			await _pause(d.call(0.3))
		"refresh":
			Audio.play(&"card_slide", -4.0)
			Juice.wobble(_screen.market_card, 1.5, d.call(0.3))
			await _pause(d.call(0.25))
		"loot":
			_screen.show_phase(GameState.Phase.LOOT)
			await _screen.banner(_screen.tr("Spoils!"), d.call(1.0))
			await _show_spoils(e)
		"auction":
			_screen.show_phase(GameState.Phase.BID)
			await _screen.banner(_screen.tr("Sealed bids"), d.call(1.0))
		"loot_taken", "auction_won":
			Audio.play(&"coins", -4.0)
			await Juice.fly(fx, _at(_screen.boss_card), _seat_at(e.pid), "trinket", d.call(0.55), 36.0)
			await _pause(d.call(0.1))
		"auction_unsold":
			await _pause(d.call(0.3))
		"act":
			await _screen.banner(_screen.tr("Act {act}").format({"act": ACT_NUMERALS[clampi(e.act, 0, ACT_NUMERALS.size() - 1)]}), d.call(1.2))
		"mob_spawn":
			_screen.flash(_screen.mobs_card)
			Juice.pop(_screen.mobs_card, 0.03, d.call(0.25))
			await _pause(d.call(0.15))
		"new_boss":
			var boss := Content.boss(e.boss)
			if boss:
				Juice.pop(_screen.boss_card, 0.08, d.call(0.5))
				await _screen.banner(_screen.tr("The {boss} arrives").format({"boss": boss.name_text()}), d.call(1.3))
		"comeback":
			var seat := _seat(e.pid)
			if seat:
				Juice.burst(fx, _at(seat), HEAL, 18, 140.0, 0.9, -100.0)
				seat.float_text(_screen.tr("back on their feet"), HEAL, d.call(1.0))
			await _pause(d.call(0.3))
		"lost":
			var seat := _seat(e.pid)
			if seat:
				seat.float_text(_screen.tr("action lost"), NEUTRAL, d.call(0.8))
			await _pause(d.call(0.3))
		"left":
			var seat := _seat(e.pid)
			if seat:
				seat.float_text(_screen.tr("connection lost"), NEUTRAL, d.call(1.0))
			await _pause(d.call(0.3))
		"away":
			var seat := _seat(e.pid)
			if seat:
				seat.float_text(_screen.tr("dozed off"), NEUTRAL, d.call(1.0))
			await _pause(d.call(0.3))
		"back", "rejoined":
			var seat := _seat(e.pid)
			if seat:
				Juice.pop(seat, 0.06, d.call(0.3))
				seat.float_text(_screen.tr("back at the table"), HEAL, d.call(1.0))
			await _pause(d.call(0.3))
		"gold":
			var seat := _seat(e.pid)
			if seat:
				seat.float_text("+%d {gold}" % e.amount, GOLD, d.call(0.9))
			Audio.play(&"coins", -8.0)
			await _pause(d.call(0.2))
		"guard":
			var seat := _seat(e.pid)
			if seat:
				Juice.burst(fx, _at(seat), GUARD, 10, 140.0, 0.4, 0.0)
				seat.float_text("+%d {guard}" % e.amount, GUARD, d.call(0.9))
			await _pause(d.call(0.2))
		"thorns":
			Audio.play(&"hit", -6.0)
			await Juice.streak(fx, _seat_at(e.pid), _seat_at(e.target), BLOOD, d.call(0.18), 8.0, SEAT_ARC * 0.5)
			_hurt(e.target, e.damage, d)
			await _pause(d.call(0.3))


## A reveal plays out on the player's seat: the strip flips from what they said to what they
## did, and the verdict is stamped on the card.
func _reveal(e: Dictionary) -> void:
	var d := _screen.duration
	_screen.show_phase(GameState.Phase.RESOLVE)
	# The plan is locked: its controls fade until the table is drawn afresh.
	_screen.focus_stage()
	_kept[e.pid] = e.kept
	var seat := _seat(e.pid)
	if seat == null:
		return
	if e.kept:
		Juice.pop(seat, 0.05, d.call(0.3))
	else:
		Juice.punch(seat, 1.0, 1.0, d.call(0.4))
		_screen.add_trauma(0.25)
	await seat.flip_strip(seat.reveal_line(Loc.rich(e.did, 16), e.kept), d.call(0.3))
	if d.call(1.0) > 0.0:
		seat.stamp(_screen.tr("Word kept") if e.kept else _screen.tr("Liar"), "kept" if e.kept else "lied", d.call(0.18))
	if e.renown > 0:
		seat.float_text(_screen.tr("Oath fulfilled +{amount} {renown}").format({"amount": e.renown}), RENOWN, d.call(1.0), true)
	elif e.kept:
		seat.float_text(_screen.tr("oath {oath}/{length}").format({"oath": e.oath, "length": Content.OATH_LENGTH}), NEUTRAL, d.call(0.8))
	await _pause(d.call(0.55))


## The spoils fan out on the middle of the table: the items for the slayers to pick, and the
## one going to a sealed bid.
func _show_spoils(e: Dictionary) -> void:
	var d := _screen.duration
	if d.call(1.0) <= 0.0:
		return
	var items: Array = e.items.duplicate()
	if e.get("auction", &"") != &"":
		items.append(e.auction)
	if items.is_empty():
		return
	_screen.focus_stage()
	var cards: Array[Control] = []
	var center := _screen.stage_center()
	for i in items.size():
		var trinket := Content.trinket(items[i])
		if trinket == null:
			continue
		var card := Parchment.new()
		card.edge_burn = 0.5
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.custom_minimum_size = Vector2(150, 120)
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.theme_type_variation = &"InkRich"
		label.add_theme_font_size_override("normal_font_size", 13)
		label.add_theme_font_size_override("bold_font_size", 15)
		var sealed: bool = i >= e.items.size()
		label.text = "[center]%s\n[b]%s[/b]\n%s%s[/center]" % [Icons.bb("trinket", 28), Icons.rich(trinket.name_text()),
			Icons.rich(trinket.description_text(), 13), "\n[color=#9b2416]%s[/color]" % _screen.tr("sealed bid") if sealed else ""]
		var margin := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 10)
		margin.add_child(label)
		card.add_child(margin)
		_screen.fx.add_child(card)
		cards.append(card)
	await _screen.get_tree().process_frame
	var spread := 165.0
	for i in cards.size():
		var card := cards[i]
		var offset := (i - (cards.size() - 1) / 2.0)
		card.pivot_offset = card.size / 2.0
		card.position = center - card.size / 2.0 + Vector2(0, 60)
		card.modulate.a = 0.0
		card.rotation_degrees = 0.0
		var tween := card.create_tween().set_parallel()
		tween.tween_interval(d.call(0.08) * i)
		tween.chain().tween_property(card, "position", center - card.size / 2.0 + Vector2(offset * spread, 0), d.call(0.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(card, "rotation_degrees", offset * 4.0, d.call(0.35))
		tween.parallel().tween_property(card, "modulate:a", 1.0, d.call(0.2))
		Audio.play(&"card_slide", -6.0)
	await _pause(d.call(1.6 + 0.08 * cards.size()))
	for card in cards:
		var out := card.create_tween()
		out.tween_property(card, "modulate:a", 0.0, d.call(0.25))
		out.tween_callback(card.queue_free)
	await _pause(d.call(0.25))


## A player attacks a player: the slash, then the blow or the block. Attacks by someone who
## broke their word are ambushes, and look like it.
func _attack(e: Dictionary) -> void:
	var d := _screen.duration
	var from := _seat_at(e.pid)
	var to := _seat_at(e.target)
	var ambush: bool = not _kept.get(e.pid, true)
	if ambush:
		_screen.pulse_edges(AMBUSH, 0.35, d.call(0.7))
		var attacker := _seat(e.pid)
		if attacker:
			attacker.float_text(_screen.tr("AMBUSH!"), AMBUSH, d.call(0.9), true)
		await _pause(d.call(0.2))
	Audio.play(&"attack", -4.0)
	await Juice.streak(_screen.fx, from, to, AMBUSH if ambush else SLASH, d.call(0.24), 15.0 if ambush else 11.0, SEAT_ARC)
	if e.damage > 0:
		_hurt(e.target, e.damage, d)
		if e.damage >= 4:
			await Juice.hit_stop(_screen.get_tree(), 0.06)
	elif e.blocked > 0:
		_blocked(e.target, d)
	await _pause(d.call(0.4))


## Renown or gold changes hands: it flies from the victim's seat to the thief's.
func _steal(e: Dictionary) -> void:
	var d := _screen.duration
	var from := _seat_at(e.target)
	var to := _seat_at(e.pid)
	var icon := "{%s}" % e.what
	var color := RENOWN if e.what == "renown" else GOLD
	Audio.play(&"coins", -4.0)
	var victim := _seat(e.target)
	if victim:
		victim.float_text("-%d %s" % [e.amount, icon], DAMAGE, d.call(0.8))
	await Juice.fly(_screen.fx, from, to, e.what, d.call(0.45), 32.0)
	var thief := _seat(e.pid)
	if thief:
		Juice.pop(thief, 0.05, d.call(0.25))
		Juice.burst(_screen.fx, to, color, 10, 140.0, 0.5, 120.0)
		thief.float_text("+%d %s" % [e.amount, icon], color, d.call(0.8))
	await _pause(d.call(0.15))


## The blow lands on a seat: a red flash, a punch, sparks and the number, all scaled by damage.
func _hurt(pid: int, damage: int, d: Callable) -> void:
	var seat := _seat(pid)
	if seat == null:
		return
	Audio.play(&"hit", -2.0)
	Juice.flash(seat, Color(2.0, 0.9, 0.8), d.call(0.4))
	Juice.punch(seat, 1.0, clampf(damage / 3.0, 0.6, 2.0), d.call(0.45))
	Juice.burst(_screen.fx, _at(seat), BLOOD, 8 + 4 * damage, 200.0 + 30.0 * damage)
	_screen.add_trauma(0.08 * damage)
	seat.float_text("-%d {heal}" % damage, DAMAGE, d.call(1.0), damage >= 4)


## Guard holds: a pale spark ring and a small bump instead of a blow.
func _blocked(pid: int, d: Callable) -> void:
	var seat := _seat(pid)
	if seat == null:
		return
	Audio.play(&"die_hit", -2.0)
	Juice.burst(_screen.fx, _at(seat), GUARD, 14, 180.0, 0.4, 0.0)
	Juice.pop(seat, 0.04, d.call(0.25))
	seat.float_text(_screen.tr("blocked {guard}"), GUARD, d.call(0.8))


func _pause(seconds: float) -> void:
	if seconds > 0.0 and is_instance_valid(_screen) and _screen.is_inside_tree():
		await _screen.get_tree().create_timer(seconds).timeout
