# Dungeon Quest Pickup

A **WoW Forever** addon that lists every dungeon quest available to your character, color coded by status, with world map pins for the quests you can pick up right now.

By **CrownedFoxxy**.

*Formerly named "Dungeon Quest Tracker" (1.0.x).*

> ⚠ **Horde and Skyborne are untested.** The addon has only been tested on Alliance characters so far. Quest data and colors may be wrong on Horde or Skyborne characters. Please report anything that looks off.

## Features

- All dungeons that have quests for your faction, race and class, including the 9 new Forever dungeons.
- Quests are color coded:

  | Color | Meaning |
  |---|---|
  | Green | In your quest log |
  | Yellow | Available to pick up now |
  | Blue | A prerequisite is missing, and you can work on it now |
  | Red | Level too low, or the prerequisite chain is level-locked |
  | *(hidden)* | Completed |

- Each row shows where the next step happens: `[Zone]`, `[INSIDE]` (starts inside the dungeon), or a red `!` when the quest giver is unknown. Blue rows show the prerequisite: `Quest -> Prerequisite [Zone]`.
- **Click** a yellow quest to open the world map at the quest giver (and set a waypoint). Click a blue quest to see where its prerequisite starts.
- **World map pins** for every yellow quest and for the first open prerequisite of every blue quest.
- **Right-click** a quest: *Hide this quest* or *WoWHead link* (copyable link). Right-click a dungeon: *Hide this dungeon*. Hidden entries go to the collapsed **Ignored** section, where you can un-ignore them.
- Share icon on quests that can be shared with your party.

## Usage

| Command | Action |
|---|---|
| `/dqp` | Toggle the window (also: minimap button, addon compartment) |
| `/dqp pins` | Toggle world map pins (minimap button right-click does the same) |
| `/dqp minimap` | Show/hide the minimap button |
| `/dqp waypoint` | Toggle setting a waypoint when you click a quest |

## Known limitations

- Horde and Skyborne characters are untested (see above).
- Some new Forever dungeon quests have no quest giver data yet (red `!`). Shaper's Terrace has no quests listed yet.
- Level ranges for the classic dungeons are recommendations, not official values.
- Quest names are in English.

## About AI usage

**This addon is my design.** I came up with the idea and decided every rule and behavior:

- how a quest's status is determined, and in what order
- how prerequisite chains are handled (blue when you can work on them, red when they're level-locked)
- what gets pinned on the map and what clicking does
- the `[Zone]`, `[INSIDE]` and red `!` markers, the Ignored section and the right-click menu
- where the quest data comes from and which requirements count as hard prerequisites

When something behaved wrong in game, I found it, figured out what the correct behavior should be, and had it fixed. All testing and every release decision is mine.

I used **Claude** (Anthropic's AI) as a coding tool. It wrote the Lua code and the data scripts from my specifications. I'm the architect; Claude did the typing.

*- CrownedFoxxy*

## Credits

- **Classic dungeon quest data** is derived from [QuestieDB](https://github.com/Questie/QuestieDB) by the Questie team, licensed under GPLv3. Thank you to the Questie team.
- **Quest data for the new WoW Forever dungeons** was compiled from [Wowhead](https://www.wowhead.com/forever).

## License

Dungeon Quest Pickup is licensed under the **GNU General Public License v3.0**. See [LICENSE](LICENSE).
