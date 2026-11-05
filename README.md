# DiceGame

A dice-building game of honest promises and well-timed betrayal for 3–6 players (about 30–45 minutes).
Every turn you roll your dice, publicly declare what you will do, secretly plan what you really do, and
then everything resolves in order of cunning. Keep your word and earn renown; break it and catch your
rivals off guard. The highest score after 15 turns wins.

The game is designed to also work as a physical board game; see [DESIGN.md](DESIGN.md) for the full
rules and design intent, and [ROADMAP.md](ROADMAP.md) for what is planned next.

## Playing

- **Play vs bots:** enter a name, press *Play vs bots*, choose 2–5 opponents.
- **Steam (friends):** *Host Steam lobby*, then *Invite friends* (Steam overlay). Friends accept the invite,
  or press *Find friends' lobbies* and join from the list. Steam names are used.
- **Direct IP / LAN:** *Host direct IP* on one machine (port 7777, UDP); others type its IP and *Join*.
- In any lobby the host can add bots to fill seats (3–6 seats) and starts the game.
- If a player disconnects, a bot plays their seat until they rejoin. If the host leaves, the game ends for everyone.
  After the game the host can bring everyone back to the lobby for another round.
- **At the table:** click dice in the tray to choose rerolls; when shopping, click a market face and then
  the face it replaces; click a seat to see that player's dice and trinkets. Space or a click skips
  animations, and Esc opens the menu (online, the game keeps going). *How to play* explains every rule,
  and first-game tips appear the first time you reach each step.
- **Keyboard and controller:** everything can be played without a mouse. Arrow keys, the d-pad or the left stick
  move between controls; Enter or A presses, Esc or B goes back. Esc or Start opens the escape menu, Space or X skips
  animations, 1 to 9 pick dice to reroll (or move onto the dice tray), I or Y opens the player sheets, Q/E or LB/RB
  turn pages, F1 or View opens the rules, Page Up/Down or the right stick scroll the Chronicle. The rules book has a
  Controls page.
- **Languages:** English and German. The language follows the system unless one is chosen in Settings (main menu).
- **Rejoining:** a player who loses the connection keeps the table on screen and reconnects on their own for 90
  seconds while a bot plays their seat. After a crash, the main menu offers *Rejoin your game* for a few hours.
- **Settings:** language, fullscreen, vsync, interface size, four volume sliders, animation speed, reduced motion,
  confirm-before-locking, high-contrast stamps and tips, saved to `user://settings.cfg`.

## How a turn works

1. **Roll** all your dice. One free reroll of any dice; every further reroll costs 1 🧠.
2. **Declare** (lowest cunning first, so the most cunning player declares last): announce an action and
   target, e.g. "Attack Bob", "Attack Rat King", "Attack the boss", "Shop", "Rest".
3. **Plan** in secret, all at once: your real action and target, and how to split your ⚔ between
   attack and guard (blocks damage all turn).
4. **Reveal and resolve**, highest cunning first. Every third word you keep in a row completes an oath
   (+1 ⭐); a broken word resets it. A hit on a player with more ⭐ than you steals 1 ⭐. A player knocked out before their turn
   loses their action.
5. **End of turn:** a surviving boss strikes its attackers; a slain boss drops spoils (picked in order of
   damage dealt, plus one item for a sealed bid open to everyone). Combat and cunning reset; gold, renown
   and score carry over.

| | |
|---|---|
| ❤ HP | 14; at 0 you are knocked out for a turn and return at half HP |
| ⚔ Combat / 🧠 Cunning | from dice, lost at the end of the turn |
| 💰 Gold / ⭐ Renown | spent in the market and on bids (⭐ pays 3 💰); unspent renown counts as score |
| 🏆 Score | mob kills (+1 tier 1, +2 tiers 2–3), +3 per boss kill (each attacker who dealt a quarter of its HP), +1 for a knockout |

**Building your dice:** shop at the shared market (shoppers buy in cunning order) to replace faces on
your dice with stronger ones (⚔3, 💰3, 🛡 guard, ❤ heal, ✦ wild, ⭐ renown, ×2), upgrade a face by 1
(it costs the new value), buy extra dice, or buy renown for 5 💰.
Twelve mobs in three acts grant trinkets (passive effects); bosses come in three stages, two bosses each, and get
stronger after each kill. The rules book's Bestiary and Trinkets pages list them all.

## Development

Open the project with the **GodotSteam 4.6** editor (stock Godot 4.6 also works, without Steam).

```
Scripts/Core      rules engine: GameRules (host-only state machine that also emits events),
                  GameState/PlayerState, Face, Content (all content and tuning numbers), BotBrain
Scripts/Content   Trinket / Mob / Boss resource scripts and the trinket effects
Scripts/Net       Network (connections, lobby, handshake), Session (game channel), SteamService
Scripts/Systems   Settings, Audio (effects, music, ambience), Transition (scene changes, quitting),
                  Loc (translation helpers), Controls (keyboard/controller actions and focus)
Scripts/UI        Menu, GameScreen + Presenter (animations), ActionPanel, SeatCard, DiceTray (3D dice),
                  overlays (settings, how to play, escape menu, player sheet, end screen), Icons, Parchment
Scripts/Dev       Dev: command-line automation for tests and screenshots
Assets            fonts, icons (SVG), shaders, audio (CC0, see CREDITS.md), Theme.tres
Locale            translations: messages.pot (every text) and one .po file per language
Resources         trinket, mob and boss data (.tres)
tests, tools      test suites and helper scripts (not exported)
```

**Look and feel.** The tavern theme is generated by `tools/build_theme.gd`; wood, parchment, candle light
and transitions are shaders in `Assets/Shaders`. Game text uses `{icon}` tokens (`{combat}3`) that
`Icons.rich()` turns into the hand-drawn icons. The host's structured events drive the animations:
`GameScreen` queues each update, `Presenter` plays its events, then the new state is drawn.

The table's motion language lives in `Juice` (pops, punches, wobbles, flashes, counters, hit-stop,
particle bursts, arcing slashes, flying icons); every effect takes its length from `GameScreen.duration()`,
so animation speed, skipping and reduced motion apply everywhere, and moves controls only by scale and
rotation so it is safe inside containers. Effects draw on `GameScreen.fx`, a layer above the table. The
reveal plays on each player's seat (the strip flips from what they said to what they did, and the verdict is
stamped on the card); attacks arc from seat
to seat, blows land with flash, sparks, trauma-based screen shake and (for the big ones) hit-stop, and
whatever changes hands (renown, trophies, gold, faces, loot) flies there. Seats (`SeatCard`) have a ghosting
`HealthBar`, oath pips, and stat chips that tick to new values; the boss has a segmented `BossBar` coloured by
who dealt each wound; mobs are `MobRow`s that burn away when slain; market faces are `MarketTile`s. The 3D
dice throw is choreographed, not simulated (`DiceTray`): dice arc in, bounce on their true corners and settle
exactly on the rolled face. It renders at the screen's real resolution, with a rounded die mesh built in code, and
picks dice with its own ray test, so hover and clicks need no physics.

**Layout.** The table's middle column takes the room left over and can never widen the table: its text and buttons
wrap, and its scroll container takes no width from its content. `--layout-check` reports anything that still asks
for more room than the window has. When a large interface size leaves less than `GameScreen.TABLE_MIN`, the whole
table is drawn smaller rather than cut off, so on a 16:9 screen the table itself stops growing at about 103% (menus and overlays keep growing).

**Translations.** Interface text goes through `tr()` (or `Loc.t()` outside nodes). Text the host writes for
everyone (the Chronicle, refused requests, declarations) travels as a message `{"k": msgid, "a": args}` and each
player's game translates it (`Loc.text()`, `Loc.rich()`); players, mobs, bosses, trinkets and faces are passed as
references so their names are translated by the reader. `python tools/i18n.py update` collects every text into
`Locale/messages.pot` and merges it into each `.po`; `python tools/i18n.py check` fails on a missing translation or a
changed placeholder or BBCode tag. A new language: copy the `.pot` to `Locale/<code>.po`, translate it, and add it to
`project.godot` and `Loc.LANGUAGES`.

**Keyboard and controller.** `Controls` (autoload) defines the game's actions, binds A and B to `ui_accept` and
`ui_cancel` (Godot does not), knows whether a mouse or keys/pad are in use, and keeps the focus inside an open
overlay. Each screen puts the focus on the control its step needs (the action panel after every rebuild, the first
control of a menu page or overlay); custom controls (`Stepper`, the dice tray, market tiles, seat cards) take focus and
answer `ui_*` actions.

**Rejoining.** At the start of a game the host gives each remote player a secret token for their seat; the client
saves it to `user://rejoin.cfg`. A player is identified by their seat id (their peer id when the game started), and
the host maps a returning player's new connection to it (`Network.peer_of()` / `pid_of()`). While a seat waits for
its player the room accepts connections, but only with that seat's token.

**Networking model.** The host is the only authority. Clients send small requests
(`Session.submit(op, args)`), the host validates them in `GameRules.apply()`, advances the game and sends
every player their own view of the state (other players' secret plans, loot picks and bids hidden)
plus the events since their last update. Bots are played by the host using the same views a human
would see, and wait for the host's animations so a human at the host can follow.

### Checks

Godot path below is the GodotSteam editor; set `GODOT` to override it in the Python tools.

```sh
# Rules: hundreds of full bot games with invariants, determinism, hidden-info and refusal checks
GodotSteam4.6.exe --headless --path . --script res://tests/test_rules.gd -- 300

# 3D dice: every throw must land flat on exactly the rolled face, with no overlaps
GodotSteam4.6.exe --headless --path . res://tests/test_dice.tscn -- 20

# Every editor warning/error, via Godot's language server (must report 0 problems)
python tools/gdlint.py

# Translations: every text translated, placeholders and BBCode tags intact
python tools/i18n.py check

# End to end: a direct-IP host and 3 clients played by bots; one client loses its connection and
# rejoins, another quits and is restarted to rejoin from its saved ticket, as after a crash
python tools/nettest.py

# A whole game played by keys only (and by controller buttons only), in any language
GodotSteam4.6.exe --headless --path . -- --autohost=offline --bots=3 --bot-delay=0 --keys-test
GodotSteam4.6.exe --headless --path . -- --autohost=offline --bots=3 --bot-delay=0 --keys-test --pad --locale=de

# Balance: play styles against each other on the real rules engine (10 workers, low priority)
python tools/strategy_sim.py                 # 1200 mixed games, ~30 s
python tools/strategy_sim.py --pool all --only mixed field --reads naive suspicious
```

The strategy simulator (`tests/sim/`) plays parameterised bot styles (honest, rational liar, mob farmer,
warlord, engine builder, renown miser, boss hunter, ...) that see only a player's view and remember who broke
their word. It reports each style's score margin over the table with 95% intervals, where points come from,
and which trinkets and faces go with winning. `tests/sim/profile_sim.gd` shows where a simulated game spends
its time.

The `Dev` autoload accepts command-line options after `--` (see `Scripts/Dev/Dev.gd`), for example
`--autohost=offline --bots=4 --autoplay --bot-delay=0 --quit-on-end`, `--menu-shots=DIR` or
`--screenshots=DIR --shot-interval=1`. `tests/balance_report.gd` prints how often each action and
event happens in bot games, for tuning.

### Exporting

`export_presets.cfg` uses the GodotSteam 4.6 export templates (paths point at the Downloads folder).
Export with `GodotSteam4.6.exe --headless --path . --export-release "Windows Desktop" DiceGame.exe`.
Ship `steam_api64.dll` next to the exe. `steam_appid.txt` (App ID 480, Valve's shared test app) is only
for development and testing outside Steam; remove it once the game has its own App ID.
