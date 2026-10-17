# Equip Compare Adv

Gear comparison for Turtle WoW, Octo WoW, Ravencraft and other 1.12.1 servers.

- Hover an item you could equip. A panel next to the tooltip compares it with what you wear.
- Shows the tooltip of what you have equipped, like the game's compare tooltips.
- Shows what the swap does: damage, damage taken, healing, health and mana.
- Lists every stat gained (green) and lost (red), with its score points.
- Scores both items for your class and spec.
- Gives a verdict, from big upgrade to big downgrade.
- Gives a verdict for each role your class can fill (tank, healer, damage).
- Says who the item is made for, and how well it fits your spec.
- Puts a green up or red down arrow on item icons: in your bags, at vendors and in the auction house.
- Warns about what a score can't see: set bonuses, Use and proc effects, items you can't equip yet.
- Never changes the game's own tooltips, so it works with other tooltip addons.

## Start

- Hover an item: in your bags, at a vendor, in loot, at the auction house or in a chat link.
- Hold **Alt** for the detailed view.
- Type `/eca` for the options window.
- Found a bug? See [Reporting bugs](#reporting-bugs).

## Install

- **Launcher** (Turtle WoW launcher, RavenLaunch and similar): paste `https://github.com/notforever-ship-it/EquipCompareAdv` into its GitHub addon installer, or update through your launcher.
- **By hand:** download the zip from the [latest release](https://github.com/notforever-ship-it/EquipCompareAdv/releases/latest).
- Copy the `EquipCompareAdv` folder into `Interface\AddOns\`.
- The path should end in `Interface\AddOns\EquipCompareAdv\EquipCompareAdv.toc`.
- Used **Code > Download ZIP**? Rename the folder `EquipCompareAdv-master` to `EquipCompareAdv`.
- Close the game completely and start it again. `/reload` does not load new addons.
- At character select, click **AddOns** and check Equip Compare Adv is ticked.

## The panel

```
Equip Compare Adv                          Fury

Equipped - Head
Helm of Might                        score 47.1
  Enchant: +8 Stamina
This item                           score 165.7
Overall if you swap:
  Damage                      +9.8 DPS (+6.1%)
  Damage reduction                       -2.4%
  Health                                  -430
Stat by stat:
  +3 Strength                                +6
  -43 Stamina                              -8.6
  +2% Crit Chance                           +64
  +2% Hit Chance                            +60
  -7 Defense                               -1.4
>> BIG UPGRADE  +118.6 (+251.8%)
Recommended: equip it.
By role:
  Damage                    BIG UPGRADE  +251.8%
  Tanking (Protection)       DOWNGRADE  -12.4%
Biggest gain                    +2% Crit Chance
Biggest loss                        -43 Stamina
Careful: your Head is part of Battlegear of Might (3/8 worn)...

Made for:                           DPS (melee)
Best for:                     Warrior Arms 100%
                        Paladin Retribution 98%
Fit for your spec:                         100%
```

### Overall if you swap

Worked out from your character as it is right now.

- **Damage**: change in damage per second.
  - 14 attack power = 1 DPS.
  - Weapon damage counts directly (half in the off hand).
  - Crit, hit and speed add their percent to your auto-attack damage.
  - Strength and Agility become attack power and crit first. Hunters get the same for ranged.
- **Spell damage**: for the schools your spec casts. 3.5 spell damage is about 1 DPS.
- **Damage reduction**: less physical damage taken, from armor, dodge, parry and defense.
  - Against your own level (a level 63 boss at 60 in raid mode).
  - Negative means you take more.
- **Healing power**: change in bonus healing, and about how much per second.
- **Health** and **Mana**: from Stamina and Intellect.

### More on the panel

- **By role**: the same swap judged only as tank, healer or damage.
  - No leveling mix here.
  - Warrior gets 2 lines, paladin 3, druid 4.
  - Rogues, hunters, mages and warlocks get none (damage only).
  - Left out when every role agrees.
  - Off: `/eca roles` or the options window.
- **Equipped tooltip**: sits between the hovered item and the panel, under a "Currently Equipped" tab.
  - Rings, trinkets and weapons can show two.
  - At the auction house the game shows its own, so the addon uses the free side.
- Works with the game's tooltips, chat links, Atlas-CFM (Atlas-TW) and AtlasLoot.
- **Rings, trinkets, one-handers**: compared with both slots. The panel says which to swap.
  - The better swap is in full, the other in two lines. Hold Alt to see both in full.
- **Two-handers**: compared with main hand and off hand together. Off-hand damage counts half.
- **Hover what you wear**: shows its score and your total gear score.
- **Character window**: shows your total gear score under your character.

### Verdicts

| Verdict | Meaning |
| --- | --- |
| BIG UPGRADE | 15% or more better, and moves your total gear score by 2%. Equip it. |
| UPGRADE | 3% to 15% better. Equip it. |
| SLIGHT UPGRADE | A little gained, nothing lost. Equip it. |
| SIDEGRADE | Within 3%. Something gained, something lost. Your pick. |
| SLIGHT DOWNGRADE | A little lost, nothing gained. |
| DOWNGRADE / BIG DOWNGRADE | Worse. Keep what you have. |
| BETTER THAN NOTHING | Empty slot, but the stats do little for your spec. |
| NOTHING FOR YOUR SPEC | No stat your spec counts. Go by the Overall lines. |

### Detail levels

| Level | Shows |
| --- | --- |
| Compact | Scores, overall effect, verdict. |
| Normal | Plus every stat change, warnings, who it is made for. |
| Detailed | Plus before and after numbers, unchanged stats, total gear score change, hit caps. |

- Hold **Alt** for Detailed any time.

## Upgrade arrows

- **Green up arrow**: an upgrade for your spec.
- **Red down arrow**: worse than what you wear.
- **No arrow**: about equal, not gear, or you can't use it.
- Sits in the bottom-left corner of the icon.
- "About equal" = less than 0.5 score, or less than 3% of the slot (the same as SIDEGRADE on the panel).
- Rings, trinkets and one-handers: judged against your weaker slot.
- Never on items you can't use: wrong armor or weapon type, level too high, wrong class.
- Where: the game's own bags, Bagshui, pfUI bags, the bank (while open), vendors (also buyback), the auction house browse list.
- Worked out once per item. Again only when your gear, spec, talents, level or settings change.
- `/eca best` or the **Best in my bags** button: the best upgrade you carry for each slot.
- `/eca off` hides the arrows too.

## How the score works

- Each spec has weights for the stats that matter: attack power, crit, hit, spell damage, healing, health, armor and so on.
- Strength, Agility, Stamina, Intellect and Spirit count as **what they turn into for your class** (1.12 rates):
  - Warrior Strength = 2 attack power. Rogue Strength = 1.
  - Agility = crit and dodge for all. Attack power for rogues, hunters and cat druids. 2 ranged attack power for hunters.
  - 1% crit takes 20 Agility (warrior), 29 (rogue), 53 (hunter).
  - Intellect = 15 mana and spell crit (about 60 for 1%).
  - Spirit = mana regen, counted for the part of a fight it really works.
- Below 60, percent stats (crit, hit, dodge) are worth less. Agility stays about the same.
- Numbers you type in the Stat weights window are used as typed.
- Melee and hunters score in attack power, casters in spell damage, healers in healing, tanks in stamina.
- Only compare scores for the same spec.

### Specs

- Warrior: Arms, Fury, Protection
- Paladin: Holy, Protection, Retribution
- Hunter: Hunter, Survival
- Rogue: Rogue
- Priest: Discipline (damage on Turtle), Holy, Shadow
- Shaman: Elemental, Enhancement, Restoration
- Mage: Arcane, Fire, Frost
- Warlock: Shadow, Fire
- Druid: Balance, Cat, Bear, Restoration
- **Auto**: follows your talents (the tree with most points).
- Feral druids get Cat. Pick Bear by hand when you tank.

### Hit caps

- Hit stops helping once you can't miss.
- Counts the hit on your other gear and your hit talents.
  - Talents: Precision, Surefooted, Nature's Guidance, Elemental Precision, Arcane Focus, Shadow Focus, Suppression.
- Only the useful part of an item's hit counts.
- Past the cap: half value if you dual wield, none otherwise.
- Raid bosses: 9% melee and ranged, 16% spell.
- Your own level: 5% and 3%.
- **Auto** uses raid numbers at level 60.
- Tanks in raid mode value defense less past 440.

### Leveling

- **Healers and tanks** below 60 also count their class's damage spec (Arms, Retribution, Shadow, Enhancement, Cat).
  - Nearly all of it at level 10, none at 60.
  - The panel header shows "+ leveling".
  - Off: `/eca leveling` or the options window.
- **Damage specs and healers** below 60 get a little extra for health and armor. Fades out by 60.
- **Casters** below 60 get a weight for wand damage. Fades out by 60.

### Other rules

- **Enchants** count by default. Tick **Ignore enchants** to compare bare items.
- **Not scored**: set bonuses, Use effects, procs. The panel lists them for you.

### "Made for"

- Checks how the item's stats are spent against every spec that can equip it.
- The spec that wastes the least is who it is made for.
- Stamina only counts towards tanks.
- Tank gear needs tank stats: stamina, defense, dodge, parry or block.

## Options

`/eca` opens the window:

- **Score items for**: Auto, or any spec of your class.
- Switches: comparison, equipped tooltip, Shift only, score points, "made for", role verdicts, gear score, leveling mix, ignore enchants, dark background, upgrade arrows, show worse items too.
- **Detail** and **Hit caps** buttons.
- **Stat weights**: what each stat is worth to your spec.
  - Type a number, press Enter. Changed stats turn gold.
  - Primary stats show their worth on the right. A typed number adds on top.
  - Saved per character and per spec.
  - Also: extra hit you get from elsewhere.
- **Best in my bags**: the best upgrade you carry for each slot, in chat.
- **List my gear**: your gear with scores, in chat.

## Commands

| Command | What it does |
| --- | --- |
| `/eca` | Options window (also `/equipcompare`) |
| `/eca on` · `/eca off` | Comparison on or off |
| `/eca spec auto` · `/eca spec fury` | What to score for |
| `/eca detail 1` · `2` · `3` | Compact, normal or detailed |
| `/eca equipped` | Equipped tooltip on or off |
| `/eca shift` | Only show while Shift is held |
| `/eca caps auto` · `raid` · `leveling` · `off` | How hit caps are judged |
| `/eca roles` | Role verdicts on or off |
| `/eca leveling` | Leveling mix for healers and tanks on or off |
| `/eca enchants` | Count or ignore enchants |
| `/eca dark` | Dark background or the game's tooltip look |
| `/eca arrows` | Upgrade arrows on item icons on or off |
| `/eca worse` | Red arrow on worse items on or off |
| `/eca best` | Best upgrade in your bags for each slot |
| `/eca gear` | List your gear with scores |
| `/eca weights` | List the stat weights |
| `/eca weight CRIT 30` | Change one weight |
| `/eca weight reset` | Weights back to defaults |
| `/eca hit 3` · `/eca spellhit 2` | Extra hit % the addon can't see |
| `/eca scorey 40` | Raise the gear score line on the character window |
| `/eca scorey auto` | Gear score line back under ShaguScore |
| `/eca version` | Show the version |
| `/eca debug` | Last error and last unread tooltip, for bug reports |
| `/eca help` | List the commands in game |

## Changes

**1.6.0**

- Upgrade arrows on item icons: green up = upgrade, red down = worse, none = about equal or not usable.
- Works in the game's own bags, Bagshui, pfUI bags, the bank, vendors (and buyback) and the auction house.
- New options: **Upgrade arrows on item icons** and **Show worse items too**. Both on.
- New `/eca best` and **Best in my bags** button: your best carried upgrade for each slot.
- New commands `/eca arrows` and `/eca worse`.
- Adds a new file: close the game completely and start it again after updating.

**1.5.2**

- The gear score line on the character window now sits right under ShaguScore when you use it (it was far below, on top of the stats when BetterCharacterStats is also loaded). `/eca scorey <pixels>` raises it by hand, `/eca scorey auto` goes back to sitting under ShaguScore.

**1.5.1**

- Checked against Turtle WoW's own class-change posts ([Turtle WoW wiki](https://turtle-wow.fandom.com/wiki/Turtle_WoW_Wiki), one page per class), which Octo follows. Survival is now its own melee Hunter spec (Lightning Reflexes turns Agility into melee attack power), Paladins value Spell Power more (the new Crusader Strike, Holy Strike, Holy Shield and Bulwark of the Righteous scale with it) and Holy Paladins value armor a little (Ironclad), and Arcane mages value haste more (reworked around casting speed). Warriors, Rogues, Shamans and Warlocks needed no change. Turtle's posts are now the only source: the Restoration Druid Spirit bonus added in 1.5.0 came only from Octo's database, which Turtle's posts do not list, so it is removed again.

**1.5.0**

- Octo/Turtle changes, checked against the [OctoWow database](https://octowow.st/db/). Priest is now Discipline (a damage spec: Chastise, Enlighten) and Holy (healer), where it used to be one "Holy / Discipline" healer. Balance druids value armor more (Moonkin Form raises item armor by 360%), Restoration druids value Spirit more (Tree of Life Form turns 20% of it into party healing), and Protection warriors value block value more (Shield Slam). The other classes' Octo spells fit their existing specs. Talent trees and stat conversions are not in the database and are not checked yet.

**1.4.3**

- `/eca debug` now also prints, line by line, the last item tooltip the addon could make nothing of, so a "no panel for this item" report can include exactly what the tooltip said. `/eca version` says which version you have.
- The slot line is matched after trimming spaces and colour codes, whatever its case.

**1.4.2**

- Guns, crossbows and wands get a comparison again. On the Turtle client their tooltip line reads just "Gun" (or "Crossbow", "Wand") with no "Ranged" next to it, and the addon only knew the slot by that word.

**1.4.1**

- Small screens and aux: when the panel has no room next to the tooltip and the game's compare tooltips, it now goes past the compare tooltips like the rest of the row, or under or over the tooltip, and when even that doesn't fit it is drawn shorter (the compact view) instead of being clamped on top of the other frames. Away from the auction house the tooltips of what you're wearing are dropped first, then the panel shortens. Hold Alt for the full panel any time.
- The compare tooltips at aux blink with every list refresh; the panel's place is now decided once per item, so it no longer jumps with them.

**1.3.1**

- Fixed the panel and equipped tooltips jumping between two spots when the hovered tooltip was near the middle of the screen. The layout is now worked out once per item and kept, and tops line up like the game's own compare tooltips unless that would run off the screen.
- Rings, trinkets and one-handers: the better swap is shown in full and the other in two lines, so the panel is much shorter. Alt shows both in full.
- New verdicts **SLIGHT UPGRADE** and **SLIGHT DOWNGRADE** for swaps that only add or only take away, instead of calling plain extra armor a "sidegrade".
- Health and armor count a little more below level 60.
- A red "Two-Hand" (a weapon kind you haven't learned) now shows the "can't use this" warning.
- "Fit for your spec" follows the leveling mix, so it no longer says 0% next to a BIG UPGRADE.

**1.3.0**

- New **By role** lines under the verdict: the same swap judged purely for tanking, for healing and for damage, whichever your class can do.
- Auto spec no longer settles on the first talent tree when the game hasn't handed over your talents yet right after a login or /reload; it looks again until they arrive.

**1.2.1**

- Fixed the **Damage** line ignoring weapon damage when scoring as a healer.
- Leveling healers and tanks now get their class's damage spec mixed into the score, fading out by level 60, so a better weapon reads as an upgrade on a level 11 Holy paladin. The header shows "+ leveling".
- When neither item has anything your spec counts, the verdict says so instead of "sidegrade".

**1.4.0**

- No more blinking at the auction house: the panel keeps its place across the list refreshes that hide and refill the tooltip, and only redraws when the item changes. Settles aux and other addons that set the same tooltip several times a second, too.
- No more overlapping when the game's compare tooltips are up: the panel takes the free side, or goes under or over the tooltip only when that really fits.
- Follows the Atlas-CFM (Atlas-TW) and AtlasLoot loot browser tooltips.
- "Dark background behind the panels" is now a switch in `/eca` (or `/eca dark`). Untick it for the game's own tooltip look.

**1.2.0**

- New **Overall if you swap** block at the top of every comparison: the change in damage per second, damage reduction, healing power, spell damage, health and mana, worked out from your character's current numbers. Strength, Agility and the rest are already folded in.
- The addon's version shows at the bottom of the detailed view.

**1.1.0**

- The equipped item's full tooltip now shows next to the item you hover, like the game's own compare tooltips, with the comparison panel after it. Switch it off in `/eca` or with `/eca equipped`.
- The panel and the equipped tooltips have a darker background, so they stay readable over your bags (a switch since 1.4.0).
- Fairer scores while leveling: crit, hit and the other percent stats are worth less below level 60, and Agility no longer gets inflated at low level.
- "Made for" no longer calls plain Agility or Strength items tank gear.

## Good to know

- Needs the **English** client. The addon reads the tooltip text.
- Stat weights are a starting point, tuned for level 60 PvE.
- Using other numbers (guild, class guide)? Type them in the Stat weights window.
- Custom talents on your server? Adjust the weight. It stays adjusted.

## Reporting bugs

Open an [issue](https://github.com/notforever-ship-it/EquipCompareAdv/issues) with:

- The item you hovered and what you had equipped.
- Your class, level and the spec at the top of the panel.
- What the panel said and what you expected.
- Red error in chat? Type `/eca debug` and copy what it prints.

## For developers

- Addon files sit at the repo root (launcher layout). `tools/` is not in release zips.
- `node tools/check-lua.js .` checks every file as **Lua 5.0** for the 1.12 client.
- `node tools/install.js [path to Interface\AddOns]` copies the addon into a game folder.
- `Stats.lua` reads tooltips, `Profiles.lua` holds weights and "made for", `Compare.lua` scores, `Panel.lua` draws, `Arrows.lua` puts the upgrade arrows on item icons.

## Credits

- Made by stealthzi.

## License

MIT. See [LICENSE](LICENSE).
