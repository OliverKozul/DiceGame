# Roadmap

What is planned or still open. Implemented rules live in [README.md](README.md); the design is in
[DESIGN.md](DESIGN.md).

## Next
- **Playtest with humans.** Bots play PvP far more timidly than people. Bot numbers after the tuning in
  DESIGN.md (`tests/balance_report.gd`): about 23 player attacks per game averaging 1.5 damage, 0.9
  knockouts, 14 mob kills, a boss slain in about half the games, 2.2 combat per player per turn. If
  knockouts stay rare with humans, the lever is the combat economy (starting dice, combat face prices),
  not HP. Mobs are still the steadiest source of score. Third Eye (+3 cunning per cunning face) is
  probably too strong now that cunning buys rerolls and initiative.
- **Look and feel, next steps:** illustrated mob, boss and trinket cards; carved or inked dice textures
  instead of icon decals; seat figures on the table; an animated intro on the tavern sign; more music
  (one track per act of the game); full keyboard and controller navigation.
- **Dice-building depth** (a main focus): more special faces, die types other than D6, face upgrades
  versus replacements, and making the wild, double and renown faces interesting.

## Content
- More trinkets, mobs and bosses (the current decks are small and repeat).
- Consumables from the original pitch:
  - *Hidden Blade*: secretly add 5 combat to a sabotage.
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
- Localisation: move all text into translation files.

## Online
- Reconnecting to your seat after a disconnect (a bot keeps it warm today).
- Configurable AFK timeout shown in the UI (fixed at 120 s for remote players today).
- Own Steam App ID; then drop `steam_appid.txt` and the 480 test-app tagging.
- Steam rich presence ("In a lobby", "Turn 7 of 15") and join-from-friends-list.
- Spectators.

## Physical version
- Printable components: face tiles, trinket/mob/boss cards, player screens and reference cards.

## Tooling
- Run the rules test, linter and network test in CI.

## Done
- Tavern look and feel (2026-11): animated main menu and lobby, settings, how-to-play book, escape menu,
  end screen, 3D physics dice, animated reveals, music, ambience, sound effects and first-game tips.

## Done (from the original README and todo list)
- Fixed: the old intention-label ordering bug and the networking issues listed in the 2026-11-02 review
  (the networking was rebuilt around host authority).
- Countering became *sabotage*; Lucky Charm's reroll became the core reroll rule; secret loot picks and
  sealed bids are in.
