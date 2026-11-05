# Steamworks setup

The game's code for these features is done. They only work fully once the game has its own App ID,
because each one also needs settings on the Steamworks site. None of this has been tried on a real
App ID yet; Spacewar (480) has no achievements, rich presence tokens or cloud space of ours.

## App ID
1. Replace `APP_ID` in `Scripts/Net/SteamService.gd` and the number in `steam_appid.txt`.
2. Keep `steam_appid.txt` out of the depot: it is only for running outside Steam.
3. Change `GAME_TAG` there when the game has its real name. Lobbies are found by that tag.

## Achievements
Add these under *Stats & Achievements > Achievements*. The API names must match exactly. Each needs
an unlocked and a locked icon (256 x 256 is a good size to draw at).

| API name | Name | Description |
|---|---|---|
| ACH_FIRST_GAME | A Seat at the Table | Play a game to the end. |
| ACH_FIRST_WIN | Toast of the Tavern | Win a game. |
| ACH_BEAT_HARD | Nobody's Fool | Win a solo game against Hard bots. |
| ACH_WIN_ONLINE | Among Friends | Win a game with at least two other people at the table. |
| ACH_WORD_IS_BOND | My Word Is My Bond | Keep your word at least 9 times in a game and never break it. |
| ACH_FAITHLESS | Faithless | Win a game after breaking your word more often than you kept it. |
| ACH_THREE_OATHS | Thrice Sworn | Complete three oaths in one game. |
| ACH_AMBUSH_KO | Knife in the Dark | Knock out a player with an attack you did not declare. |
| ACH_BOSS_SLAIN | Boss Slayer | Be one of the slayers of a boss. |
| ACH_LAST_BOSS | Bane of the Ancients | Be one of the slayers of a boss of the last stage. |
| ACH_WINNING_BID | Going, Going, Gone | Win a sealed bid. |
| ACH_FIVE_DICE | A Fistful of Dice | End a game with five dice. |
| ACH_MASTER_SMITH | Master Smith | End a game with a face of value 5. |
| ACH_COLLECTOR | Magpie | End a game with five trinkets. |
| ACH_COMEBACK | Back from the Floor | Win a game in which you were knocked out. |
| ACH_ROBBER | Highway Robbery | Steal 5 renown in one game. |

The game keeps what was earned in `user://profile.cfg` and sends it to Steam when it can. A game
played before these exist on Steamworks is sent again on the next start.

## Rich presence
Upload `steam/rich_presence.vdf` under *Community > Rich Presence*. It holds the status text friends
see. "Join game" on a friend works while they wait at a table with a Steam lobby.

## Steam Cloud
Under *Application > Steam Cloud*, give a quota (1 MB is plenty) and add two Auto-Cloud paths:

| Root | Subdirectory | Pattern | OS |
|---|---|---|---|
| WinAppDataRoaming | DiceGame | settings.cfg | Windows |
| WinAppDataRoaming | DiceGame | profile.cfg | Windows |

Add a Linux root override if a Linux build ships (Godot uses `~/.local/share/DiceGame`). The folder
name comes from `config/custom_user_dir_name` in `project.godot`; it does not have to change with the
game's title, and changing it after release would strand players' files.

Deliberately not synced: `display.cfg` (one machine's window and scale), `rejoin.cfg` (one machine's
seat in a running game) and `logs/`.

## Public tables
Nothing to set up. A host switches *Who can join* to *Public*, and others find the table on the online
page. Lobbies are filtered by `GAME_TAG` and the network protocol.

## What to test on a real App ID
With two accounts on two machines: host and join a friends-only and a public table, invite from the
overlay, join from the friends list both with the game closed and while on the main menu, remove a
player, lose the connection and rejoin, unlock an achievement, and check cloud files arrive on the
second machine. `tools/nettest.py` and `tools/lobbytest.py` only cover direct IP.
