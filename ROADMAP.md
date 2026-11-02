# Roadmap

What is planned or still open. Implemented rules live in [README.md](README.md); the design is in
[DESIGN.md](DESIGN.md).

## Next
- **Look and feel pass:** transitions, animations, dice visuals, menus and theme (direction to be chosen).
- **Playtest and balance.** Numbers marked *(tune)* in DESIGN.md are placeholders. Findings from bot games
  (300 games, `tests/test_rules.gd`):
  - Mobs dominate scoring (about 16 kills per game) while bosses fall in only about 30% of games, even
    after lowering boss HP to 2/3/4 per player.
  - Knockouts are rare (about 0.5 per game): 20 HP is a lot against early combat values.
  - Third Eye (+3 🧠 per cunning face) is probably too strong now that cunning buys rerolls and initiative.
- **Dice-building depth** (a main focus): more special faces, die types other than D6, face upgrades
  versus replacements, and making the ✦ wild / ×2 / ⭐ faces interesting.

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

## Done (from the original README and todo list)
- Fixed: the old intention-label ordering bug and the networking issues listed in the 2026-11-02 review
  (the networking was rebuilt around host authority).
- Countering became *sabotage*; Lucky Charm's reroll became the core reroll rule; secret loot picks and
  sealed bids are in.
