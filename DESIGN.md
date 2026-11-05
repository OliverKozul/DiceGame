# DiceGame — Design

A dice-building game of honest promises and well-timed betrayal for 3–6 players, about 30–45 minutes.
It is built digitally first, but **every rule must work as a physical board game**: dice with swappable
faces, tokens, cards and a screen. Timers, hidden automation and real-time tricks are not part of the rules.

> Status: agreed v1, implemented. Numbers marked *(tune)* are placeholders to be balanced in playtests.
> README.md describes what is implemented today; ROADMAP.md lists what is still open.

## Pillars
1. **Deceit with a price.** Everyone announces what they will do. Keeping your word earns renown; breaking
   it can win you the turn.
2. **Build your dice.** You change the faces of your dice over the game, so your rolls are something you build.
3. **Cunning is tempo.** Cunning decides who declares last and who resolves first, but it disappears at the
   end of every turn and is also the currency for rerolls.
4. **Little waiting.** Most steps are simultaneous. The only sequential steps are short (one announcement each, plus shoppers buying in order).

## Resources
| Resource | From | Kept between turns? | Used for |
|---|---|---|---|
| ❤ HP | start 14 *(tune)* | yes | knocked out at 0 |
| ⚔ Combat | dice | **no**, lost at end of turn | attack, guard |
| 🧠 Cunning | dice | **no**, lost at end of turn | turn order, extra rerolls |
| 💰 Gold | dice | yes | market (faces, upgrades, dice, renown), loot bids |
| ⭐ Renown | completed oaths, theft, the market | yes | spent as **3 💰** each; **unspent renown is score at game end**; a hit from a player with less renown steals 1 |
| 🏆 Score | kills, knockouts, unspent renown | yes | winning |

Spending renown instead of gold is always allowed (each renown pays 3 gold), so you choose between
buying power now and keeping points for the end. Renown you hold can be stolen by any player with less renown who hits you, so
hoarding it makes you a target, and the player in last place cannot be robbed.

## Components (physical version)
- 2 starting D6 per player with swappable face tiles; extra dice from the market.
- Face tiles, trinket cards, mob deck, boss deck, market board.
- Per player: intention tokens (one per action, plus target markers), a plan screen, combat tokens.
- First-player token (rotates every turn; breaks initiative ties).

Starting dice: `[⚔1 ⚔1 ⚔1 💰1 💰1 🧠1]` and `[⚔1 ⚔1 💰1 💰1 💰1 🧠1]`.

## Turn structure
### 1. Roll *(simultaneous)*
- Everyone rolls all their dice.
- Everyone gets **one free reroll** of any subset of their dice.
- After that, each further reroll costs **1 🧠** from this turn's roll *(tune)*. Spending cunning on dice lowers your initiative.
- Then count up ⚔, 💰 and 🧠. Gold goes into your bank; combat and cunning are kept until the end of the turn.

### 2. Initiative
- Order everyone by remaining 🧠, highest first.
- Ties go to the player with **less gold** (catch-up). If still tied, the player closest to the first-player token, going clockwise, wins.

### 3. Declare *(sequential, lowest initiative first)*
- Each player publicly declares an **intention: action + target**, for example "Attack Bob",
  "Attack Rat King", "Attack the boss", "Shop" or "Rest".
- The highest-initiative player declares last and has heard every other claim.

### 4. Plan *(simultaneous, secret)*
Behind a screen, each player locks in:
- **Action + target.** This is your real choice and may differ from your intention.
- **Combat split.** Divide this turn's ⚔ between:
  - **Attack:** used by your action.
  - **Guard:** absorbs damage from any source this turn, including players, mobs and the boss.

### 5. Reveal
- All plans are revealed at once.
- **Oaths.** Everyone whose action and target exactly match their intention moves their public oath marker
  one step. The **3rd** step completes the oath: **+1 ⭐** *(tune)* and the marker returns to 0. Breaking your
  word returns the marker to 0, so a lie costs the most just before an oath completes.

### 6. Resolve *(highest initiative first)*
Each player, in order, performs their action:
   - **Attack player:** damage = Attack − target's remaining Guard. Guard is used up as it absorbs damage.
     If it deals any damage and the target holds more renown than you, you also take **1 ⭐** *(tune)*
     from them: **only the richer can be robbed**.
     A player knocked out before their own resolution **loses their action**.
   - **Attack mob:** if Attack ≥ mob HP, the mob dies: you get its 🏆 (+1 for tier 1, +2 for tiers 2 and 3 *(tune)*)
     and its trinket. Otherwise the mob hits
     you for its damage, minus your Guard. A mob falls **once per turn**: if a faster player already slew it,
     your attack finds it dead and does nothing.
   - **Attack boss:** damage adds to the boss for this turn. You become one of this turn's boss attackers.
   - **Shop:** buy from the market (see below). Shoppers buy in initiative order, so high cunning gets first pick.
   - **Rest:** heal 3 ❤ *(tune)*.

### 7. End of turn
1. **Boss.** If the boss survived, it hits every attacker for its damage, minus each attacker's Guard.
   If it died, every attacker who dealt at least **a quarter of its HP** (rounded up) *(tune)* is a slayer and
   gets +3 🏆 *(tune)*; then the spoils are shared out (below).
2. **Cleanup:**
   - combat and cunning drop to 0;
   - dead mobs are replaced from the mob deck;
   - a slain boss is replaced by the next, stronger boss;
   - the market is refilled;
   - the first-player token passes left.
3. **Knocked-out players return** at half HP (see Knockouts).
4. **Game end.** If this was the last turn, the game ends.

## Market
- The market shows 5 face tiles and 1 extra die *(tune)*. You can buy as many as you can afford, paying with gold,
  renown (3 💰 each) or both.
- **Buying a face:** pick one of your dice and one of its faces, then replace that face. The old tile is discarded.
- **Upgrading a face:** raise one of your ⚔, 💰, 🧠, 🛡 or ❤ faces by 1, up to 5 *(tune)*. It costs the new value
  (⚔2 → ⚔3 costs 3). Physically: flip or swap the tile for the next value.
- **Buying a die:** you get a new D6 with plain faces, which you can then build up.
- **Buying renown:** 5 💰 *(tune)* for 1 ⭐, as often as you like. Gold therefore never ends the game worthless.
- The market is refilled at the end of the turn. A row refresh costs 1 💰 *(tune)*.

Example faces by tier *(tune)*:
| Tier | Price | Faces |
|---|---|---|
| 1 | 2 | ⚔2, 💰2, 🧠2, 🛡2 (guard-only combat) |
| 2 | 4 | ⚔3, 💰3, 🛡3, ❤2 (heal), ✦1 (wild: choose a type) |
| 3 | 6 | ⚔4, 💰4, 🧠3, ✦2, ⭐1 (renown), ×2 (doubles another die) |

## Enemies
- **Mobs.** Three mob slots. The game has **three acts** (turns 1–5, 6–10, 11–15 in a 15-turn game); each act
  has its own mob deck of that tier, and at the start of acts 2 and 3 every mob on the table is replaced from
  the new deck. Slain mobs are replaced from the current act's deck. Each mob card shows HP, damage and a
  trinket reward. A single player kills a mob alone, and only the first (in initiative order) each turn.
- **Boss.** One boss at a time, from an escalating boss deck in three stages. The first boss is drawn from stage 1, the
  next from stage 2 and every later one from stage 3 *(tune)*:

  | Stage | Boss | HP | Damage |
  |---|---|---|---|
  | 1 | Red Dragon | 2 + 1 per player | 3 |
  | 1 | Troll King | 2 + 1 per player | 2 |
  | 2 | Eldritch Horror | 3 + 1 per player | 4 |
  | 2 | Bone Colossus | 3 + 1 per player | 3 |
  | 3 | Ancient Wyrm | 4 + 2 per player | 5 |
  | 3 | Demon Prince | 2 + 2 per player | 6 |

  The HP resets at the end of every turn, so it has to be killed in a single turn by players who choose to work together.
- **Boss spoils.** Only the slayers (at least a quarter of the boss's HP dealt) share the spoils. One item is drawn for every two of them, rounded up, plus one more, with no repeats.
  1. They pick one item each, in order of **damage dealt** (most first; ties go to higher initiative).
     Only the top half of them get an item.
  2. The extra item goes to a **sealed bid open to every player** still in the game, paid in gold and renown
     (3 💰 each). The highest bid of at least 1 wins and pays; ties go to whoever dealt the boss more damage,
     then to higher initiative. If nobody bids, the item is lost.

Mob deck *(tune)*, three copies of each card:

| Act | Mob | HP | Damage | Trinkets (one at random) |
|---|---|---|---|---|
| 1 | Rat King | 2 | 1 | Sharp Tooth, Backstab Dagger |
| 1 | Goblin Thief | 4 | 1 | Coin Magnet |
| 1 | Giant Bats | 2 | 1 | Fox Mask, Hunter's Horn |
| 1 | Highwayman | 3 | 2 | Lucky Coin, Sharp Tooth |
| 2 | Vampire Lord | 5 | 2 | Goblet of Blood |
| 2 | Cave Troll | 6 | 2 | Sharp Tooth, Goblet of Blood |
| 2 | Werewolf | 5 | 3 | Thorned Mail, Hunter's Horn |
| 2 | Swamp Witch | 6 | 2 | Herbal Pouch, Smoke Bomb, Bone Dice |
| 3 | Wraith | 6 | 3 | Backstab Dagger, Coin Magnet |
| 3 | Ogre Chief | 7 | 3 | Sharp Tooth, Backstab Dagger, Goblet of Blood |
| 3 | Stone Golem | 7 | 2 | Thorned Mail, Herbal Pouch, Silver Tongue |
| 3 | Lich | 6 | 3 | Smoke Bomb, Silver Tongue, Bone Dice |

## Knockouts
At 0 HP you are **knocked out**:
- your remaining action this turn is lost;
- you skip the next turn and cannot be targeted during it;
- you return at half your maximum HP.

If another player knocked you out, they gain +1 🏆 and you lose 1 🏆 *(tune)*. Being knocked out by a mob or the boss costs 1 🏆.

Nobody is ever eliminated.

## Winning
- The game lasts **15 turns** *(tune by player count)*.
- At the end, score = 🏆 + unspent ⭐.
- Ties are broken by more HP, then more gold.

## Trinkets
Trinkets are permanent passive effects from mobs and boss loot. Every effect is something a player can track at a table.
- **From mobs:** Sharp Tooth (+1 ⚔ per combat face), Backstab Dagger (+2 attack when you attack a player you did not
  declare), Coin Magnet (a hit on a player also steals 1 💰), Goblet of Blood (heal when your attacks deal damage),
  Lucky Coin (+1 💰 per gold face), Fox Mask (+1 🧠 every turn and +1 per cunning face), Bone Dice (the second reroll
  each turn is free too), Herbal Pouch (rest heals 2 more), Hunter's Horn (+2 attack against mobs), Silver Tongue
  (+1 💰 whenever you keep your word), Smoke Bomb (+2 🛡 on a turn you break your word), Thorned Mail (a player whose
  attack damages you takes 1 damage; a knockout this way counts as yours).
- **From bosses** (stronger, to make the shared fight worth the risk): Opportunity (an extra die with
  ⚔2 ⚔2 💰2 💰2 🧠1 🧠1), Crown of Honor (+2 ⭐ per completed oath), Third Eye (+2 🧠 every turn, +2 more and heal 1 per
  cunning face), Golden Idol (+2 💰 every turn), Dragonscale (+2 🛡 every turn), War Banner (+1 attack on every
  attack), Wyrm Heart (+4 max ❤, heal to full), Liar's Mask (breaking your word does not reset your oath), Phoenix
  Feather (return from a knockout at full ❤), Merchant's Seal (faces, upgrades and dice cost 1 💰 less, never below 1).

## Special faces (provisional, a later focus)
| Face | Effect when rolled |
|---|---|
| 🛡 N | N combat that can only be used as Guard |
| ❤ N | heal N |
| ✦ N | wild: counts as N ⚔, 💰 or 🧠 (your choice) |
| ⭐ N | gain N renown |
| ×2 | doubles your highest other face this roll |

## Targeting
Attacks can target any player who is not knocked out.

## Digital-only conveniences (not rules)
- **Bots.** Play solo against 2–5 bots, fill online lobbies with bots, and a bot takes over the seat of a player who disconnects.
  Bots only see what a player at the table would see. Three difficulties: Easy (simple heuristics), Normal (play styles,
  believe every declaration) and Hard (stronger builders that discount each player's word by their record of lies).
- **AFK timeout** (online only, set by the host, the last 30 seconds counted down). An idle player automatically declares
  and plans **Rest**; after two timeouts in a row a bot plays their seat until they take it back. The host is no exception.
- **Table options** (digital only): the host picks the length (12 or 15 turns), the difficulty, the time to act and
  who may join, and can remove a player from the room.
- **The story of the game**: at the end, the betrayal of the night and titles for the most broken words, kept words and so on.
- **Event log** (the Chronicle), automatic arithmetic, animations that can be sped up or skipped,
  first-game tips and an illustrated rules book.

## Tuning log
Changed after bot playtests (`tests/balance_report.gd`, 200–300 games):
- **Starting HP 20 → 14.** Attacks average about 1.5 damage, so at 20 HP knockouts almost never happened.
- **Boss HP is now base + per player** (Red Dragon 2 + 1 per player, Eldritch Horror 4 + 2, Ancient Wyrm 6 + 3) instead of
  2/3/4 per player. A kill needs about three committed players, not the whole table; bots now slay a boss in about half of
  their games instead of a quarter.
- **Goblin Thief HP 3 → 4**, so the first mob deck is less of a free buffet.
- Bots now go after a leader who is pulling away, so solo games have real betrayal.

Changed 2026-11-03 after the strategy simulator (`tools/strategy_sim.py`, thousands of games between play styles):
- **Honesty no longer floods the score.** +1 ⭐ for every kept word made honesty ~75% of everyone's score and
  made lying a losing move, even against bots that react to threats. It is now one oath per three kept words.
- **Hits steal renown**, so ambushes pay and hoarded renown is at risk.
- **Renown spends as 3 💰**, face upgrades and buying renown (5 💰) give gold a use all game; bots used to finish
  with 6–13 unspendable gold.
- **Boss spoils go by damage**, with a minimum share, so chipping in 1 damage no longer wins loot.
- **Sabotage is gone.** Bots used it on 0.5% of turns; its attack-or-guard rule cost more than it gave.
- **Knockouts give +1 🏆, not +2.** With hits stealing renown, knockouts tripled and a +2/−1 swing decided
  games where the average score is about 7.
- **Boss ladder softened** (Eldritch Horror 4 + 2 → 3 + 1, Ancient Wyrm 6 + 3 → 4 + 2 per player) and only a real
  share of the damage scores: 93% of boss kills were the first boss, and 1-damage attackers took +2 each.
- **Mobs score their tier (1/2/2) and boss kills score +3**, and boss spoils are stronger (Opportunity, Crown of
  Honor and Third Eye upgraded; Golden Idol, Dragonscale, War Banner and Wyrm Heart added). With bots that
  bluff and trust boss coalitions only as far as each player's record, mobs faded after act 1 (every mob was
  +1) and the boss fell 0.3 times a game. Now tier-2/3 mobs are fought 2–3× as often and boss kills more
  than doubled, without widening the gap between play styles (about 1.7 points).
- **Only the richer can be robbed** (a hit steals renown only from a player holding more than the attacker).
  Every hit stealing made the game a brawl: about 29 player attacks per game, with more renown stolen than
  oaths create. Now about 20, aimed at the leaders, knockouts fall from 1.6 to 0.65 per game, bosses and mobs
  get a little more play, and play styles stay within about 1.6 points. It is also a catch-up rule.
- **Theft is not limited to ambushes.** Theft only on ambushes halves theft and calms the brawl, but sinks
  honest play (−1.6 points for an always-honest style); decide in human playtests.
- **Mobs come in acts** and fall once per turn; Wraith 8 → 6 HP, Ogre Chief 10 → 7. The deck used to escalate
  only when mobs died, so tier 3 almost never appeared (0.09 kills per game) and several players farmed the
  same Rat King every turn.

Changed 2026-11-03, more content (`tools/strategy_sim.py`, 1200 mixed games, against the same games with only the old
content in a copy of the project):
- **Six new mobs, three new bosses, eleven new trinkets, three new face tiles.** Bosses are now drawn at random from
  their stage, so the first boss is not always the same.
- The first draft had fewer boss kills (0.42 against 0.82 a game) and fewer mob kills (3.6 against 5.0). The cause was a
  cascade: the old act-1 mobs mostly dropped Sharp Tooth, which feeds combat for the rest of the game, and half of the
  old act-1 deck was the 2 HP Rat King. Giant Bats are now 2 HP, the new act-1 mobs drop combat trinkets (Hunter's
  Horn, Sharp Tooth), the Troll King has the Red Dragon's HP and the Stone Golem and Lich lost 1 HP each.
- After tuning: 0.79 boss kills and 5.6 mob kills a game (act 2 and 3 kills as before), 21 player attacks (22 before),
  mean score 7.15 (7.19), and play styles within 1.3 points (1.7 before). New boss items win about as often as the old
  ones; Fox Mask was the weakest trinket and gained +1 cunning every turn.

## Decisions log
- There is no early-end trigger. The game always lasts the full number of turns.
- The market is one shared row.
- A bonus beyond renown for keeping an intention will be decided after playtests.
- Special faces are provisional; dice-building depth is a later focus.
- Sabotage was removed (2026-11-03). Secret simultaneous loot picks became picks in damage order plus one
  open sealed-bid item.
