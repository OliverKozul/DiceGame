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
| ❤ HP | start 20 *(tune)* | yes | knocked out at 0 |
| ⚔ Combat | dice | **no**, lost at end of turn | attack, guard, sabotage |
| 🧠 Cunning | dice | **no**, lost at end of turn | turn order, extra rerolls |
| 💰 Gold | dice | yes | market, loot bids |
| ⭐ Renown | keeping your intention | yes | spent exactly like gold; **unspent renown is score at game end** |
| 🏆 Score | kills, knockouts, unspent renown | yes | winning |

Spending renown instead of gold is always allowed, so you choose between buying power now and keeping
points for the end.

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
  - **Sabotage:** pick one or more players and assign combat to each.

### 5. Reveal
- All plans are revealed at once.
- Everyone whose action and target exactly match their intention gains **+1 ⭐** *(tune)*.

### 6. Resolve *(highest initiative first)*
Each player, in order:
1. **Sabotage.** Each sabotage removes that much combat from the target's plan:
   - from their **Attack** if they have not resolved yet;
   - otherwise from their **Guard**.
2. **Action:**
   - **Attack player:** damage = Attack − target's remaining Guard. Guard is used up as it absorbs damage.
     A player knocked out before their own resolution **loses their action**.
   - **Attack mob:** if Attack ≥ mob HP, the mob dies: you get +1 🏆 and its trinket. Otherwise the mob hits
     you for its damage, minus your Guard.
   - **Attack boss:** damage adds to the boss for this turn. You become one of this turn's boss attackers.
   - **Shop:** buy from the market (see below). Shoppers buy in initiative order, so high cunning gets first pick.
   - **Rest:** heal 3 ❤ *(tune)*.

### 7. End of turn
1. **Boss.** If the boss survived, it hits every attacker for its damage, minus each attacker's Guard.
   If it died, every attacker who dealt ≥ 1 damage gets +2 🏆 *(tune)*, then loot is shared out (below).
2. **Cleanup:**
   - combat and cunning drop to 0;
   - dead mobs are replaced from the mob deck;
   - a slain boss is replaced by the next, stronger boss;
   - the market is refilled;
   - the first-player token passes left.
3. **Knocked-out players return** at half HP (see Knockouts).
4. **Game end.** If this was the last turn, the game ends.

## Market
- The market shows 5 face tiles and 1 extra die *(tune)*. You can buy as many as you can afford, paying with gold, renown or both.
- **Buying a face:** pick one of your dice and one of its faces, then replace that face. The old tile is discarded.
- **Buying a die:** you get a new D6 with plain faces, which you can then build up.
- The market is refilled at the end of the turn. A row refresh costs 1 💰 *(tune)*.

Example faces by tier *(tune)*:
| Tier | Price | Faces |
|---|---|---|
| 1 | 2 | ⚔2, 💰2, 🧠2, 🛡2 (guard-only combat) |
| 2 | 4 | ⚔3, 💰3, ❤2 (heal), ✦1 (wild: choose a type) |
| 3 | 6 | ⚔4, 🧠3, ⭐1 (renown), ×2 (doubles another die) |

## Enemies
- **Mobs.** Three mob slots, filled from a mob deck that gets stronger over the game. Each mob card shows HP,
  damage and a trinket reward. A single player kills a mob alone. Several players may each kill the same mob in one turn
  if each of them meets its HP on their own.
- **Boss.** One boss at a time, from an escalating boss deck: 2, 3, then 4 HP per player *(tune)*. The HP resets at the end of
  every turn, so it has to be killed in a single turn by players who choose to work together.
- **Boss loot.** One item is drawn for every two attackers, rounded up, with no repeats.
  1. Every attacker secretly and simultaneously picks one item.
  2. An item picked by only one player goes to that player.
  3. An item picked by several players goes to a **sealed bid**, paid in gold or renown. The highest bid wins and pays.
     Ties go to higher initiative, then to the first-player token.

## Knockouts
At 0 HP you are **knocked out**:
- your remaining action this turn is lost;
- you skip the next turn and cannot be targeted during it;
- you return at half your maximum HP.

If another player knocked you out, they gain +2 🏆 and you lose 1 🏆 *(tune)*. Being knocked out by a mob or the boss costs 1 🏆.

Nobody is ever eliminated.

## Winning
- The game lasts **15 turns** *(tune by player count)*.
- At the end, score = 🏆 + unspent ⭐.
- Ties are broken by more HP, then more gold.

## Trinkets
Trinkets are permanent passive effects, mostly from mobs and boss loot. Current set (to be reworked for the new rules):
Sharp Tooth, Saboteur Dagger, Coin Magnet, Goblet of Blood, Third Eye, Opportunity.

## Special faces (provisional, a later focus)
| Face | Effect when rolled |
|---|---|
| 🛡 N | N combat that can only be used as Guard |
| ❤ N | heal N |
| ✦ N | wild: counts as N ⚔, 💰 or 🧠 (your choice) |
| ⭐ N | gain N renown |
| ×2 | doubles your highest other face this roll |

## Targeting
Attacks and sabotage can target any player who is not knocked out.

## Digital-only conveniences (not rules)
- **Bots.** Play solo against 2–5 bots, fill online lobbies with bots, and a bot takes over the seat of a player who disconnects.
  Bots only see what a player at the table would see.
- **AFK timeout** (online only, generous). An idle player automatically declares and plans **Rest**.
- **Event log**, automatic arithmetic.

## Decisions log
- There is no early-end trigger. The game always lasts the full number of turns.
- The market is one shared row.
- A bonus beyond renown for keeping an intention will be decided after playtests.
- Special faces are provisional; dice-building depth is a later focus.
