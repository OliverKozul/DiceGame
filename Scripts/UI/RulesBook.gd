class_name RulesBook
extends Overlay
## How to play: chapters on the left, the page on parchment on the right. The faces, trinkets
## and bestiary pages are generated from the game content, so they never go stale. With keys
## or a pad, moving onto a chapter opens it, Q and E turn the chapters, and Page Up and Page
## Down (or the right stick) scroll the page.

var _chapter_buttons: Array[Button] = []
var _page: RichTextLabel
var _written: Array[Array] = []
var _chapter := 0


## The written chapters: [title, page], translated.
func _chapters() -> Array[Array]:
	return [
		[tr("The goal"), tr("""[font_size=26]The goal[/font_size]

Score the most {score} by the [b]last turn[/b] (15 in a full game). Your final score is {score} plus every {renown} you have not spent.

You earn {score} by slaying mobs ([b]+1[/b] in the first act, [b]+2[/b] later), by dealing a quarter of the boss's health on the turn it falls ([b]+3[/b]) and by knocking out a rival ([b]+1[/b]).

You earn {renown} by keeping your word: every [b]third kept word in a row[/b] completes an oath worth +1 {renown}. Spend {renown} as [b]3 {gold}[/b] each, or keep it for the final count. A hit from a player who holds less {renown} than you steals 1 {renown}.

Every turn you say what you will do. Then you decide, in secret, whether you meant it.""")],
		[tr("A turn"), tr("""[font_size=26]A turn[/font_size]

[b]1. Roll.[/b] Everyone rolls at once, with one free reroll.

[b]2. Declare.[/b] One by one, everyone announces an action and a target.

[b]3. Plan.[/b] Everyone locks a secret plan: the real action, and how to split {combat}.

[b]4. Resolve.[/b] Plans are revealed and play out, most cunning first.

[b]5. End of turn.[/b] The boss strikes back, loot is shared, and {combat} and {cunning} are lost. {gold}, {renown} and {score} stay.""")],
		[tr("Rolling"), tr("""[font_size=26]Rolling[/font_size]

Roll all your dice. You may then reroll any of them once for free. Every further reroll costs [b]1 {cunning}[/b]: better dice, but a worse place in the turn order.

{combat} [b]Combat[/b]: attack and guard. Lost at the end of the turn.
{gold} [b]Gold[/b]: buys faces, upgrades, dice, renown and loot. Kept.
{cunning} [b]Cunning[/b]: sets the turn order and pays for rerolls. Lost at the end of the turn.

Special faces from the market add {guard} guard, {heal} healing, {wild} wild faces, {renown} renown and {double} doubles. See [i]Faces[/i].""")],
		[tr("Initiative"), tr("""[font_size=26]Initiative and declaring[/font_size]

After the roll, players are ranked by {cunning}, highest first. Ties go to the player with less {gold}, then to whoever is closest to the first-player token, which passes left every turn.

[b]Declaring runs backwards:[/b] the least cunning player speaks first, and the most cunning speaks last, having heard every claim.

[b]Resolving runs forwards:[/b] the most cunning player acts first, so their attacks land before slower players can act, and they shop first.""")],
		[tr("Your plan"), tr("""[font_size=26]Your secret plan[/font_size]

Choose what you will really do: attack a player, a mob or the boss, shop, or rest. It may differ from what you declared.

Then split your {combat}:
{combat} [b]Attack[/b]: used by an attack.
{guard} [b]Guard[/b]: blocks damage from anything, all turn.

[b]Keeping your word[/b] means your plan matches your declared action and target. It moves your [b]oath[/b] one step; the third step completes it for [b]+1 {renown}[/b] and starts a new one. Breaking your word starts your oath over, so a lie costs the most just before an oath is complete. Everyone can see how far each oath has come.""")],
		[tr("Resolution"), tr("""[font_size=26]Resolution[/font_size]

Plans resolve in initiative order. On your turn:

[b]Attack a player:[/b] damage is your attack minus their guard. If it deals damage and they hold more {renown} than you, you also take [b]1 {renown}[/b] from them: only the richer can be robbed. A player knocked out before their turn loses their action.
[b]Attack a mob:[/b] with attack at least its {heal}, you slay it. Otherwise it hits back.
[b]Attack the boss:[/b] your attack adds to everyone else's this turn.
[b]Shop:[/b] buy from the market.
[b]Rest:[/b] heal 3 {heal}.""")],
		[tr("Enemies"), tr("""[font_size=26]Mobs, the boss and loot[/font_size]

[b]Mobs[/b] are slain by a single player. Each kill is worth {score} (+1 for tier 1, +2 for tiers 2 and 3) and a {trinket} trinket. A mob falls only once per turn: the first attacker in turn order who meets its {heal} slays it, and later attackers find it dead. The game has three acts (turns 1–5, 6–10, 11–15); each act brings a fresh table of stronger mobs.

[b]The boss[/b] must fall in a single turn; its health resets every turn. If it survives, it strikes every attacker. If it falls, each attacker who dealt at least a quarter of its health gains +3 {score} and a share of its powerful spoils, and a stronger boss arrives.

[b]Loot:[/b] attackers who dealt at least a quarter of the boss's health share the spoils: one item for every two of them, picked one at a time, [b]most damage first[/b]. One more item then goes to a [b]sealed bid[/b] open to every player, in {gold} and {renown} (3 {gold} each): the highest bid wins and pays.""")],
		[tr("The market"), tr("""[font_size=26]The market[/font_size]

Everyone shares one market row. Shoppers buy in initiative order, so the most cunning get first pick.

[b]Buy a face[/b], then choose any face on any of your dice to replace with it. This is how you build your dice.
[b]Upgrade a face[/b] by 1 (up to 5). It costs the new value: raising {combat}2 to {combat}3 costs 3.
[b]Buy a die[/b] to roll more each turn.
[b]Buy renown[/b]: 5 {gold} for 1 {renown}.
[b]Refresh[/b] the row if nothing suits you.

You can pay with {gold}, {renown} (worth 3 {gold} each) or both. The row refills at the end of every turn.""")],
		[tr("Knockouts"), tr("""[font_size=26]Knockouts[/font_size]

At 0 {heal} you are [b]knocked out[/b]: you lose your action this turn, sit out the next turn and cannot be targeted, then return with half your health.

The player who knocked you out gains [b]+1 {score}[/b] and you lose [b]1 {score}[/b]. Falling to a mob or the boss also costs 1 {score}.

Nobody is ever eliminated. The game always lasts all its turns.""")],
	]


func _init() -> void:
	panel_size = Vector2(940, 580)


func _make_panel() -> PanelContainer:
	return Parchment.new()


func _build() -> void:
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := add_label(header, tr("How to play"), &"InkHeading")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button(header, tr("Close"), close)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	var chapters := VBoxContainer.new()
	chapters.custom_minimum_size = Vector2(190, 0)
	chapters.add_theme_constant_override("separation", 4)
	body.add_child(chapters)
	var group := ButtonGroup.new()
	_written = _chapters()
	var titles: Array[String] = []
	for chapter in _written:
		titles.append(chapter[0])
	titles.append_array([tr("Faces"), tr("Trinkets"), tr("Bestiary"), tr("Controls")])
	for i in titles.size():
		var button := Button.new()
		button.text = titles[i]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0, 32)
		button.pressed.connect(_show.bind(i))
		# Keys and pads open a chapter by moving onto it.
		button.focus_entered.connect(func() -> void:
			if Controls.using_keys and not button.button_pressed:
				button.button_pressed = true
				_show(i))
		chapters.add_child(button)
		_chapter_buttons.append(button)

	_page = RichTextLabel.new()
	_page.bbcode_enabled = true
	_page.theme_type_variation = &"InkRich"
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.add_theme_font_size_override("normal_font_size", 18)
	_page.add_theme_font_size_override("bold_font_size", 18)
	body.add_child(_page)
	_page.focus_mode = Control.FOCUS_NONE
	_chapter_buttons[0].button_pressed = true
	_show(0)


func open() -> void:
	Audio.play(&"book_open", -4.0)
	super.open()


func close() -> void:
	Audio.play(&"book_close", -4.0)
	await super.close()


func _show(index: int) -> void:
	if visible:
		Audio.play(&"page", -6.0)
	_chapter = index
	var text := ""
	match index - _written.size():
		0:
			text = _faces_page()
		1:
			text = _trinkets_page()
		2:
			text = _bestiary_page()
		3:
			text = _controls_page()
		_:
			text = _written[index][1]
	_page.text = Icons.rich(text, 22, false)
	_page.scroll_to_line(0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"prev_tab") or event.is_action_pressed(&"next_tab"):
		var next := posmod(_chapter + (-1 if event.is_action_pressed(&"prev_tab") else 1), _chapter_buttons.size())
		_chapter_buttons[next].button_pressed = true
		_show(next)
		Controls.focus(_chapter_buttons[next])
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"scroll_up", true) or event.is_action_pressed(&"scroll_down", true):
		var bar := _page.get_v_scroll_bar()
		bar.value += bar.page * 0.5 * (-1.0 if event.is_action_pressed(&"scroll_up", true) else 1.0)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _faces_page() -> String:
	var lines := PackedStringArray(["[font_size=26]%s[/font_size]" % tr("Faces"), "",
		tr("Every face in the market, with its price in {gold} ({renown} pays 3 {gold})."), ""])
	var table := "[table=3]"
	for entry: Array in Content.FACE_CATALOG:
		var face := Face.make(entry[0], entry[1])
		table += "[cell]%s  [/cell][cell][b]%d[/b] {gold}   [/cell][cell]%s[/cell]" % [Face.label(face), entry[2], Face.describe(face)]
	lines.append(table + "[/table]")
	lines.append("")
	lines.append(tr("A new die costs [b]{die}[/b] and starts with basic faces. Refreshing the row costs [b]{refresh}[/b].").format({
		"die": Content.DIE_PRICE, "refresh": Content.REFRESH_PRICE}))
	lines.append(tr("Upgrading {combat} {gold} {cunning} {guard} or {heal} faces by 1 costs the new value, up to [b]{max}[/b]. One {renown} costs [b]{price}[/b] {gold}.").format({
		"max": Content.UPGRADE_MAX, "price": Content.RENOWN_PRICE}))
	return "\n".join(lines)


func _trinkets_page() -> String:
	var lines := PackedStringArray(["[font_size=26]%s[/font_size]" % tr("Trinkets"), "",
		tr("Permanent effects won from mobs and bosses. Boss spoils are the strongest."), ""])
	lines.append("[b]%s[/b]" % tr("From mobs"))
	var boss_items: Array[Trinket] = []
	for trinket in Content.trinkets():
		if Content.BOSS_LOOT.has(trinket.id):
			boss_items.append(trinket)
		else:
			lines.append("{trinket} [b]%s[/b]: %s" % [_escaped(trinket.name_text()), trinket.description_text()])
	lines.append("")
	lines.append("[b]%s[/b]" % tr("From bosses"))
	for trinket in boss_items:
		lines.append("{trinket} [b]%s[/b]: %s" % [_escaped(trinket.name_text()), trinket.description_text()])
	return "\n".join(lines)


## Every mob by act and every boss by stage, with what they drop.
func _bestiary_page() -> String:
	var lines := PackedStringArray(["[font_size=26]%s[/font_size]" % tr("Bestiary"), ""])
	for act in Content.MOB_ACTS:
		lines.append("[b]%s[/b]" % tr("Act {act} mobs ({score} +{amount} each)").format({"act": act + 1, "amount": Content.MOB_TIER_SCORE[act]}))
		for mob in Content.mobs():
			if mob.tier != act + 1:
				continue
			var drops := PackedStringArray()
			for reward in mob.rewards:
				drops.append(_escaped(reward.name_text()))
			lines.append("[b]%s[/b]  {heal}%d {combat}%d  [i]%s[/i]\n      {trinket} %s" % [
				_escaped(mob.name_text()), mob.hp, mob.damage, _escaped(mob.description_text()), ", ".join(drops)])
		lines.append("")
	lines.append("[b]%s[/b]" % tr("Bosses"))
	lines.append(tr("The first boss comes from stage 1, the next from stage 2, every later one from stage 3. Health is shown for 4 players."))
	for stage in range(1, Content.BOSS_STAGES + 1):
		for boss in Content.bosses_of_stage(stage):
			var hp_rule := tr("{base} + {per} per player").format({"base": boss.base_hp, "per": boss.hp_per_player})
			lines.append("%s:  [b]%s[/b]  {heal}%d (%s)  {combat}%d  [i]%s[/i]" % [tr("Stage {stage}").format({"stage": stage}),
				_escaped(boss.name_text()), boss.max_hp(4), hp_rule, boss.damage, _escaped(boss.description_text())])
	return "\n".join(lines)


func _controls_page() -> String:
	var rows: Array[Array] = [
		[tr("Move between controls"), tr("Arrow keys"), tr("D-pad or left stick")],
		[tr("Press, choose"), tr("Enter"), "A"],
		[tr("Back, close"), "Esc", "B"],
		[tr("Escape menu"), "Esc", "Start / Menu"],
		[tr("Skip animations"), tr("Space"), "X"],
		[tr("How to play"), "F1", "View / Back"],
		[tr("Player sheets"), "I", "Y"],
		[tr("Turn pages, other players"), "Q / E", "LB / RB"],
		[tr("Scroll the Chronicle and this book"), "Page Up / Page Down", tr("Right stick")],
		[tr("Pick dice to reroll"), tr("1 to 9, or move onto the tray"), tr("Move onto the tray, left and right, A")],
	]
	var table := "[table=3][cell][b]%s[/b]   [/cell][cell][b]%s[/b]   [/cell][cell][b]%s[/b][/cell]" % [tr("Action"), tr("Keyboard"), tr("Controller")]
	for row in rows:
		table += "[cell]%s   [/cell][cell]%s   [/cell][cell]%s[/cell]" % row
	table += "[/table]"
	return "\n".join(PackedStringArray(["[font_size=26]%s[/font_size]" % tr("Controls"), "",
		tr("Everything can be played with a mouse, a keyboard or a controller."), "", table]))


## Content names in BBCode pages: escaped, as they come from data files.
static func _escaped(text: String) -> String:
	return text.replace("[", "[lb]")
