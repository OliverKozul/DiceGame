class_name RulesBook
extends Overlay
## How to play: chapters on the left, the page on parchment on the right. The face and
## trinket pages are generated from the game content, so they never go stale.

const CHAPTERS: Array[Array] = [
	["The goal", """[font_size=26]The goal[/font_size]

Score the most {score} over [b]15 turns[/b]. Your final score is {score} plus every {renown} you have not spent.

You earn {score} by slaying mobs ([b]+1[/b]), by wounding the boss on the turn it falls ([b]+2[/b]) and by knocking out a rival ([b]+2[/b]).

You earn {renown} by keeping your word. Spend it like {gold}, or keep it for the final count.

Every turn you say what you will do. Then you decide, in secret, whether you meant it."""],
	["A turn", """[font_size=26]A turn[/font_size]

[b]1. Roll.[/b] Everyone rolls at once, with one free reroll.

[b]2. Declare.[/b] One by one, everyone announces an action and a target.

[b]3. Plan.[/b] Everyone locks a secret plan: the real action, and how to split {combat}.

[b]4. Resolve.[/b] Plans are revealed and play out, most cunning first.

[b]5. End of turn.[/b] The boss strikes back, loot is shared, and {combat} and {cunning} are lost. {gold}, {renown} and {score} stay."""],
	["Rolling", """[font_size=26]Rolling[/font_size]

Roll all your dice. You may then reroll any of them once for free. Every further reroll costs [b]1 {cunning}[/b]: better dice, but a worse place in the turn order.

{combat} [b]Combat[/b]: attack, guard and sabotage. Lost at the end of the turn.
{gold} [b]Gold[/b]: buys faces, dice and loot. Kept.
{cunning} [b]Cunning[/b]: sets the turn order and pays for rerolls. Lost at the end of the turn.

Special faces from the market add {guard} guard, {heal} healing, {wild} wild faces, {renown} renown and {double} doubles. See [i]Faces[/i]."""],
	["Initiative", """[font_size=26]Initiative and declaring[/font_size]

After the roll, players are ranked by {cunning}, highest first. Ties go to the player with less {gold}, then to whoever is closest to the first-player token, which passes left every turn.

[b]Declaring runs backwards:[/b] the least cunning player speaks first, and the most cunning speaks last, having heard every claim.

[b]Resolving runs forwards:[/b] the most cunning player acts first, so their attacks and sabotage land before slower players can act."""],
	["Your plan", """[font_size=26]Your secret plan[/font_size]

Choose what you will really do: attack a player, a mob or the boss, shop, or rest. It may differ from what you declared.

Then split your {combat}:
{combat} [b]Attack[/b]: used by an attack.
{guard} [b]Guard[/b]: blocks damage from anything, all turn.
{sabotage} [b]Sabotage[/b]: removes combat from another player.

[b]Keeping your word[/b] means your plan matches your declared action and target. It earns [b]+1 {renown}[/b]. Breaking it earns nothing but surprise."""],
	["Resolution", """[font_size=26]Resolution[/font_size]

Plans resolve in initiative order. On your turn:

[b]Sabotage[/b] lands first. It removes combat from the target's attack if they have not acted yet, otherwise from their guard.

[b]Attack a player:[/b] damage is your attack minus their guard. A player knocked out before their turn loses their action.
[b]Attack a mob:[/b] with attack at least its {heal}, you slay it. Otherwise it hits back.
[b]Attack the boss:[/b] your attack adds to everyone else's this turn.
[b]Shop:[/b] buy from the market.
[b]Rest:[/b] heal 3 {heal}."""],
	["Enemies", """[font_size=26]Mobs, the boss and loot[/font_size]

[b]Mobs[/b] are slain by a single player. Each kill is worth +1 {score} and a {trinket} trinket. Slain mobs are replaced by stronger ones.

[b]The boss[/b] must fall in a single turn; its health resets every turn. If it survives, it strikes every attacker. If it falls, each attacker who wounded it gains +2 {score}, and a stronger boss arrives.

[b]Loot:[/b] one item for every two attackers. Each picks one in secret. An item picked by several players goes to a [b]sealed bid[/b] in {gold} and {renown}: the highest bid wins and pays."""],
	["The market", """[font_size=26]The market[/font_size]

Everyone shares one market row. Shoppers buy in initiative order, so the most cunning get first pick.

[b]Buy a face[/b], then choose any face on any of your dice to replace with it. This is how you build your dice.
[b]Buy a die[/b] to roll more each turn.
[b]Refresh[/b] the row if nothing suits you.

You can pay with {gold}, {renown} or both. The row refills at the end of every turn."""],
	["Knockouts", """[font_size=26]Knockouts[/font_size]

At 0 {heal} you are [b]knocked out[/b]: you lose your action this turn, sit out the next turn and cannot be targeted, then return with half your health.

The player who knocked you out gains [b]+2 {score}[/b] and you lose [b]1 {score}[/b]. Falling to a mob or the boss also costs 1 {score}.

Nobody is ever eliminated. The game always lasts all 15 turns."""],
]

var _chapter_buttons: Array[Button] = []
var _page: RichTextLabel


func _init() -> void:
	panel_size = Vector2(940, 580)


func _make_panel() -> PanelContainer:
	return Parchment.new()


func _build() -> void:
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := add_label(header, "How to play", &"InkHeading")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button(header, "Close", close)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	var chapters := VBoxContainer.new()
	chapters.custom_minimum_size = Vector2(190, 0)
	chapters.add_theme_constant_override("separation", 6)
	body.add_child(chapters)
	var group := ButtonGroup.new()
	var titles: Array[String] = []
	for chapter in CHAPTERS:
		titles.append(chapter[0])
	titles.append_array(["Faces", "Trinkets"])
	for i in titles.size():
		var button := Button.new()
		button.text = titles[i]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0, 36)
		button.pressed.connect(_show.bind(i))
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
	var text := ""
	if index < CHAPTERS.size():
		text = CHAPTERS[index][1]
	elif index == CHAPTERS.size():
		text = _faces_page()
	else:
		text = _trinkets_page()
	_page.text = Icons.rich(text, 22, false)
	_page.scroll_to_line(0)


func _faces_page() -> String:
	var lines := PackedStringArray(["[font_size=26]Faces[/font_size]", "", "Every face in the market, with its price in {gold} or {renown}.", ""])
	var table := "[table=3]"
	for entry: Array in Content.FACE_CATALOG:
		var face := Face.make(entry[0], entry[1])
		table += "[cell]%s  [/cell][cell][b]%d[/b] {gold}   [/cell][cell]%s[/cell]" % [Face.label(face), entry[2], Face.describe(face)]
	lines.append(table + "[/table]")
	lines.append("")
	lines.append("A new die costs [b]%d[/b] and starts with basic faces. Refreshing the row costs [b]%d[/b]." % [Content.DIE_PRICE, Content.REFRESH_PRICE])
	return "\n".join(lines)


func _trinkets_page() -> String:
	var lines := PackedStringArray(["[font_size=26]Trinkets[/font_size]", "", "Permanent effects won from mobs and bosses.", ""])
	for trinket in Content.trinkets():
		lines.append("{trinket} [b]%s[/b]: %s" % [trinket.display_name, trinket.description])
	return "\n".join(lines)
