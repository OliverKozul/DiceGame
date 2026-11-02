class_name Presenter
extends RefCounted
## Turns the host's events into animations on the table. Plays one batch of events (the
## ones that led to a new view) and returns when they are done; the screen then shows the
## new view. Every duration goes through GameScreen.duration(), so animation speed, catch-up
## after lag, reduced motion and skipping all apply.

const DAMAGE := Color("ff8a6e")
const HEAL := Color("8fe08f")
const GOLD := Color("f3c94b")
const RENOWN := Color("f6d38a")
const NEUTRAL := Color("f1e4c6")

var _screen: GameScreen


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


func _name(view: GameState, pid: int) -> String:
	var p := view.player(pid)
	return p.name if p else "?"


func _play_event(e: Dictionary, view: GameState) -> void:
	var d := _screen.duration
	var me := _screen.me
	match str(e.type):
		"turn_start":
			for card in _screen.seat_cards():
				card.clear_stamp()
			var p := view.player(me)
			if p and p.is_active():
				_screen.throw_my_dice(PackedInt32Array(range(p.dice.size())), view)
			await _screen.banner("Turn %d" % e.turn, d.call(1.3))
			await _screen.wait_for_dice()
		"reroll":
			if e.pid == me:
				await _screen.throw_my_dice(e.dice, view)
			else:
				Audio.play(&"die_hit", -6.0)
				await _pause(d.call(0.15))
		"kept":
			var seat := _seat(e.pid)
			if seat and e.gold > 0:
				seat.float_text("+%d {gold}" % e.gold, GOLD, d.call(0.9))
				if e.pid == me:
					Audio.play(&"coins", -4.0)
			await _pause(d.call(0.2))
		"initiative":
			Audio.play(&"card_slide", -6.0)
			await _pause(d.call(0.2))
		"declare":
			var seat := _seat(e.pid)
			if seat:
				Audio.play(&"card_slide", -4.0)
				await seat.flip_strip("Says: [b]%s[/b]" % Icons.rich(e.text, 16), d.call(0.35))
		"locked":
			var seat := _seat(e.pid)
			if seat:
				seat.pulse(Color(1.3, 1.2, 0.9))
			Audio.play(&"lock", -10.0)
			await _pause(d.call(0.1))
		"reveal":
			# Events carry their own text: by the time they play, the view may be a turn later.
			var seat := _seat(e.pid)
			if seat:
				await seat.flip_strip("Did: [b]%s[/b]" % Icons.rich(e.text, 16), d.call(0.4))
				await seat.stamp("Word kept" if e.kept else "Liar", "kept" if e.kept else "lied", d.call(0.3))
				if e.kept and e.renown > 0:
					seat.float_text("+%d {renown}" % e.renown, RENOWN, d.call(1.0))
			await _pause(d.call(0.15))
		"sabotage":
			var target := _seat(e.target)
			if target and e.amount > 0:
				Audio.play(&"hit", -10.0)
				target.float_text("-%d %s" % [e.amount, "{combat}" if e.what == "attack" else "{guard}"], DAMAGE, d.call(0.8))
			await _pause(d.call(0.35))
		"attack":
			Audio.play(&"attack", -4.0)
			await _pause(d.call(0.15))
			var target := _seat(e.target)
			if target:
				if e.damage > 0:
					Audio.play(&"hit", -2.0)
					target.shake(8.0)
					target.float_text("-%d {heal}" % e.damage, DAMAGE, d.call(0.9))
				elif e.blocked > 0:
					target.float_text("blocked {guard}", NEUTRAL, d.call(0.8))
			await _pause(d.call(0.45))
		"whiff":
			var seat := _seat(e.pid)
			if seat:
				seat.float_text("missed", NEUTRAL, d.call(0.7))
			await _pause(d.call(0.25))
		"mob_kill":
			Audio.play(&"attack", -4.0)
			_screen.flash(_screen.mobs_card)
			var seat := _seat(e.pid)
			if seat:
				seat.float_text("+1 {score}", RENOWN, d.call(1.0))
			await _pause(d.call(0.5))
		"mob_fail":
			var seat := _seat(e.pid)
			if seat and e.damage > 0:
				Audio.play(&"hit", -4.0)
				seat.shake(6.0)
				seat.float_text("-%d {heal}" % e.damage, DAMAGE, d.call(0.9))
			await _pause(d.call(0.45))
		"boss_hit":
			Audio.play(&"attack", -4.0)
			_screen.shake_node(_screen.boss_card, 7.0)
			await _screen.animate_boss_hp(e.hp, d.call(0.45))
		"boss_slain":
			Audio.play(&"stamp", 0.0)
			await _screen.banner("The boss falls!", d.call(1.4))
		"boss_strike":
			var seat := _seat(e.pid)
			if seat and e.damage > 0:
				Audio.play(&"hit", -2.0)
				seat.shake(8.0)
				seat.float_text("-%d {heal}" % e.damage, DAMAGE, d.call(0.9))
			elif seat:
				seat.float_text("blocked {guard}", NEUTRAL, d.call(0.8))
			await _pause(d.call(0.4))
		"boss_reward":
			for pid: int in e.pids:
				var seat := _seat(pid)
				if seat:
					seat.float_text("+2 {score}", RENOWN, d.call(1.0))
			await _pause(d.call(0.4))
		"rest", "heal":
			var seat := _seat(e.pid)
			var amount: int = e.get("healed", e.get("amount", 0))
			if seat and amount > 0:
				seat.float_text("+%d {heal}" % amount, HEAL, d.call(0.9))
			await _pause(d.call(0.3))
		"steal":
			var thief := _seat(e.pid)
			var victim := _seat(e.target)
			Audio.play(&"coins", -6.0)
			if victim:
				victim.float_text("-1 {gold}", DAMAGE, d.call(0.8))
			if thief:
				thief.float_text("+1 {gold}", GOLD, d.call(0.8))
			await _pause(d.call(0.3))
		"knockout":
			Audio.play(&"knockout", 0.0)
			_screen.shake_node(_screen.margin, 10.0)
			var seat := _seat(e.pid)
			if seat:
				await seat.stamp("Knocked out", "lied", d.call(0.4))
			await _pause(d.call(0.5))
		"trinket":
			var seat := _seat(e.pid)
			var trinket := Content.trinket(e.trinket)
			if seat and trinket:
				seat.float_text("{trinket} %s" % trinket.display_name, GOLD, d.call(1.2))
			await _pause(d.call(0.4))
		"shop":
			var seat := _seat(e.pid)
			if seat:
				seat.pulse(Color(1.25, 1.15, 0.85))
			Audio.play(&"door_open", -10.0)
			await _pause(d.call(0.2))
		"buy_face":
			Audio.play(&"coins", -4.0)
			var seat := _seat(e.pid)
			if seat:
				seat.float_text(Face.label(e.face), GOLD, d.call(0.9))
			await _pause(d.call(0.35))
		"buy_die", "new_die":
			var seat := _seat(e.pid)
			if seat:
				seat.float_text("+1 {die}", GOLD, d.call(0.9))
			await _pause(d.call(0.3))
		"refresh":
			Audio.play(&"card_slide", -4.0)
			await _pause(d.call(0.25))
		"loot":
			await _screen.banner("Spoils!", d.call(1.0))
		"auction":
			await _screen.banner("Sealed bids", d.call(1.0))
		"loot_taken", "auction_won":
			Audio.play(&"coins", -4.0)
			await _pause(d.call(0.3))
		"mob_spawn":
			_screen.flash(_screen.mobs_card)
			await _pause(d.call(0.15))
		"new_boss":
			var boss := Content.boss(e.boss)
			if boss:
				await _screen.banner("The %s arrives" % boss.display_name, d.call(1.3))
		"comeback":
			var seat := _seat(e.pid)
			if seat:
				seat.float_text("back on their feet", HEAL, d.call(1.0))
			await _pause(d.call(0.3))
		"lost":
			var seat := _seat(e.pid)
			if seat:
				seat.float_text("action lost", NEUTRAL, d.call(0.8))
			await _pause(d.call(0.3))
		"left":
			var seat := _seat(e.pid)
			if seat:
				seat.float_text("left the table", NEUTRAL, d.call(1.0))
			await _pause(d.call(0.3))


func _pause(seconds: float) -> void:
	if seconds > 0.0 and is_instance_valid(_screen) and _screen.is_inside_tree():
		await _screen.get_tree().create_timer(seconds).timeout
