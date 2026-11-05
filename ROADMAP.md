# Roadmap

What is planned or still open. Implemented rules live in [README.md](README.md); the design is in
[DESIGN.md](DESIGN.md).

## Next
- **Playtest the 2026-11-03 rules.** In: oaths, renown theft and spending, upgrades, damage-order spoils,
  knockout +1, boss share and +3, softer boss ladder, stronger boss items, mob acts, once-per-turn mobs and
  tier scoring, and only the richer can be robbed. Simulator (smart bots): play styles within about 1.6
  points, about 0.8 boss kills, 5 mob kills and 20 player attacks per game. Open, for humans to decide:
  whether 20 attacks a game feels right; theft only on ambushes (halves theft but sinks honest play in the
  simulator); whether the boss needs more (bots ignore its strike, so lowering its damage only matters to
  people); 4 mob slots for more PvE.
- **Playtest with humans.** Bots play PvP far more timidly than people. Bot numbers after the tuning in
  DESIGN.md (`tests/balance_report.gd`): about 23 player attacks per game averaging 1.5 damage, 0.9
  knockouts, 14 mob kills, a boss slain in about half the games, 2.2 combat per player per turn. If
  knockouts stay rare with humans, the lever is the combat economy (starting dice, combat face prices),
  not HP. Mobs are still the steadiest source of score. Third Eye (+3 cunning per cunning face) is
  probably too strong now that cunning buys rerolls and initiative.
- **Playtest the new content with humans.** Six mobs, three bosses, eleven trinkets and three face tiles were
  added and tuned in the simulator (see the tuning log in DESIGN.md); Thorned Mail, Smoke Bomb and Liar's Mask
  change how betrayal feels and need people to judge.
- **Look and feel, next steps:** illustrated mob, boss and trinket art in the new card slots; carved or inked
  dice textures instead of icon decals; sealed-bid envelopes opening one by one at the auction; the main
  menu (wooden plaque buttons, real candle models, a swinging sign); the rules book page flip; seat figures
  on the table; more music (one track per act); a visible fast-forward button; controller button prompts
  (glyphs) next to buttons; Steam Deck checks (the on-screen keyboard for the name field).
- **Dice-building depth** (a main focus): more special faces, die types other than D6, face upgrades
  versus replacements, and making the wild, double and renown faces interesting.

## Content
- Boss abilities beyond HP and damage (all bosses are stat cards today).
- Consumables from the original pitch:
  - *Hidden Blade*: secretly add 5 combat to an attack.
  - *Warp Token*: swap initiative with another player for a turn.
  - *Bandage Wraps*: heal 3 at once.
- Original pitch ideas to revisit under the new rules:
  - *Thief's Die*: use one face of another player's roll.
  - *Mind's Eye*: peek at one player's secret plan.
  - *Abyssal Pact*: +3 combat for −1 cunning.
  - *Warped Die*: a boss die with mixed faces.
- Whether keeping your intention should give a bonus beyond renown (decide after playtests).

## Accessibility and polish
- Colour-blind check of seat colours (high-contrast stamps exist; seats could add patterns).
- More languages (copy `Locale/messages.pot`; see README). The German translation should get a native read-through.
  Languages with other scripts need a fallback font (Cloister Black and Lora cover Latin only).
- Remappable controls.

## Online
- The host leaving still ends the game (host migration, or saving and resuming a game).
- Configurable AFK timeout shown in the UI (fixed at 120 s for remote players today).
- Own Steam App ID; then drop `steam_appid.txt` and the 480 test-app tagging.
- Steam rich presence ("In a lobby", "Turn 7 of 15") and join-from-friends-list.
- Spectators.

## Physical version
- Printable components: face tiles, trinket/mob/boss cards, player screens and reference cards.

## Tooling
- Run the rules test, linter and network test in CI.

## Done
- Content, rejoining, keyboard and controller, localisation (2026-11-03): six mobs, three bosses (drawn per stage),
  eleven trinkets and three face tiles, tuned against the old content in the simulator; rejoining after a lost
  connection or a crash, tested end to end in `tools/nettest.py`; full keyboard and controller play, tested by
  `--keys-test` and `--keys-test --pad`; every text translatable, a German translation, and `tools/i18n.py`.
- Visual overhaul (2026-11-03): a shared `Juice` motion kit and effects layer; arcing slashes, impacts, ambush and knockout effects, hit-stop and screen shake; flying renown,
  trophies, faces and loot; seat cards with ghosting health bars, oath pips and ticking stats; a segmented
  boss bar coloured by attacker; mob rows that burn away; ivory market tiles; spoils fanned out on the table;
  an animated end screen; a choreographed dice throw with rounded dice; fixes for a lagging phase header,
  overlapping floating text, container-fighting shakes, cut-off chronicle lines and a corner smudge.
- Strategy simulator (2026-11): play styles on the real engine, reputation-aware bots, parallel runner and
  report (`tools/strategy_sim.py`). It drove the 2026-11-03 rule changes in DESIGN.md.
- Tavern look and feel (2026-11): animated main menu and lobby, settings, how-to-play book, escape menu,
  end screen, 3D physics dice, animated reveals, music, ambience, sound effects and first-game tips.

## Done (from the original README and todo list)
- Fixed: the old intention-label ordering bug and the networking issues listed in the 2026-11-02 review
  (the networking was rebuilt around host authority).
- Countering became *sabotage*; Lucky Charm's reroll became the core reroll rule; secret loot picks and
  sealed bids are in.
