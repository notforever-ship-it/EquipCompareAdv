# Equip Compare Adv

Gear comparison for Turtle WoW, Octo WoW, Ravencraft and other 1.12.1 servers. Hover any item you could equip and a panel next to the tooltip tells you:

- **What you have equipped** in that slot, by name, with its score.
- **Every stat you'd gain and lose**, green and red, with how many score points each one is worth.
- **A score for both items**, worked out for your class and spec.
- **A verdict**: big upgrade, upgrade, sidegrade, downgrade or big downgrade, and whether equipping it is recommended.
- **Who the item is made for**: tank, DPS or healer, the classes and specs that get the most out of it, and how well it fits your own spec.

It also warns you about the things a score can't see: a set bonus you'd break, a Use or proc effect you'd lose, an item you can't equip yet.

The game's own tooltips are never changed, so it works alongside other tooltip addons.

## Quick start

1. **Download** the zip from the [latest release](https://github.com/notforever-ship-it/EquipCompareAdv/releases/latest). Copy the `EquipCompareAdv` folder inside it into `Interface\AddOns\` in your game folder, then fully restart the game. [Full install steps](#install).
2. **Hover an item** in your bags, at a vendor, in the loot window, on the auction house or in a chat link.
3. **Hold Alt** for the detailed view.
4. **Type `/eca`** for the options window.

Found a bug? See [Reporting bugs](#reporting-bugs).

## Install

**With an addon launcher** (the Turtle WoW launcher, RavenLaunch and similar): paste this repo's address, `https://github.com/notforever-ship-it/EquipCompareAdv`, into its GitHub addon installer. The addon files sit at the top level of the repo, which is the layout launchers expect.

**By hand:**

1. Download the zip from the [latest release](https://github.com/notforever-ship-it/EquipCompareAdv/releases/latest). It contains a ready-made `EquipCompareAdv` folder. (If you use **Code → Download ZIP** instead, the folder inside is called `EquipCompareAdv-master`; rename it to `EquipCompareAdv` or the game won't load it.)
2. Copy that folder into `World of Warcraft\Interface\AddOns\`. The path should end in `Interface\AddOns\EquipCompareAdv\EquipCompareAdv.toc`.
3. Fully restart the game. `/reload` doesn't pick up newly added addons.
4. On the character select screen, click **AddOns** and make sure Equip Compare Adv is ticked.

## What the panel shows

```
Equip Compare Adv                          Fury

Equipped - Head
Helm of Might                        score 47.1
  Enchant: +8 Stamina
This item                           score 165.7
If you swap:
  +3 Strength                                +6
  -43 Stamina                              -8.6
  +2% Crit Chance                           +64
  +2% Hit Chance                            +60
  -7 Defense                               -1.4
>> BIG UPGRADE  +118.6 (+251.8%)
Recommended: equip it.
Biggest gain                    +2% Crit Chance
Biggest loss                        -43 Stamina
Careful: your Head is part of Battlegear of Might (3/8 worn)...

Made for:                           DPS (melee)
Best for:                     Warrior Arms 100%
                        Paladin Retribution 98%
Fit for your spec:                         100%
```

- **Rings, trinkets and one-handed weapons** are compared with both slots, and the panel says which one to swap.
- **Two-handers** are compared with your main hand and off hand together. An off-hand weapon's damage counts half, as it does in game.
- **Hovering something you're wearing** shows its score and your total gear score instead.
- The **character window** shows your total gear score under your character.

### Verdicts

| Verdict | Meaning |
| --- | --- |
| BIG UPGRADE | 15% or more better than what you have. Equip it. |
| UPGRADE | 3% to 15% better. Equip it. |
| SIDEGRADE | Within 3%. Pick the stats you like more. |
| DOWNGRADE / BIG DOWNGRADE | Worse. Keep what you have. |
| BETTER THAN NOTHING | The slot is empty, but the item's stats do little for your spec. |

### Detail levels

| Level | Shows |
| --- | --- |
| Compact | Both scores, the verdict and the recommendation. |
| Normal | Plus every stat change, warnings and who the item is made for. |
| Detailed | Plus before and after numbers, unchanged stats, what the change does in practice (attack power, crit, health...), the effect on your total gear score, and where you stand on hit caps. |

Holding **Alt** shows Detailed at any time.

## How the score works

Every spec has a weight for the stats that do the work: attack power, crit, hit, spell damage, healing, health, armor and so on. Strength, Agility, Stamina, Intellect and Spirit are worth **what they turn into for your class**, using the 1.12 conversion rates:

- A warrior's Strength is 2 attack power; a rogue's is 1.
- Agility is crit and dodge for everyone, attack power for rogues, hunters and cat druids, and 2 ranged attack power for hunters. It takes 20 Agility for 1% crit on a warrior, 29 on a rogue, 53 on a hunter.
- Intellect is 15 mana and spell crit (about 60 Intellect for 1%).
- Spirit is mana regeneration, counted for the share of a fight it really works in.

The conversions scale with your level, so crit from Agility is worth more on a level 30 than on a level 60.

Melee and hunter scores count in attack power, caster scores in spell damage, healer scores in healing and tank scores in stamina. A score only means something next to another score for the same spec.

**Specs:** Arms, Fury, Protection · Holy, Protection, Retribution · Hunter · Rogue · Holy/Discipline, Shadow · Elemental, Enhancement, Restoration · Arcane, Fire, Frost · Shadow and Fire warlock · Balance, Cat, Bear, Restoration. **Auto** follows your talents: the tree with the most points picks the spec. Feral druids get Cat; pick Bear by hand when you tank.

**Hit caps.** Hit stops helping once you can't miss. The addon adds up the hit on the rest of your gear and the hit talents you've taken (Precision, Surefooted, Nature's Guidance, Elemental Precision, Arcane Focus, Shadow Focus, Suppression), and only counts the part of an item's hit that still does something. Past the cap, hit keeps half its value if you dual wield and none otherwise. Caps are 9% melee and ranged and 16% spell against raid bosses, 5% and 3% against things your own level; **Auto** uses the raid numbers at level 60. Tanks in raid mode also value defense less past 440.

**Leveling casters** get a weight for wand damage that fades to nothing by level 60.

**Enchants** on your gear are counted by default, so you see what really changes the moment you swap. Tick **Ignore enchants** to compare bare items instead.

**Not in the score:** set bonuses, Use effects, procs and other special effects. The panel lists them so you can judge them yourself.

### "Made for"

The addon looks at how an item's stat budget is spent and checks it against every spec of every class that can equip it (armor type, weapon skills, class restrictions). The spec that wastes the least of the budget is who the item is made for. Stamina is on nearly everything, so it only counts towards tanks.

## Options

`/eca` opens the options window:

- **Score items for**: Auto, or any spec of your class.
- Switches for the comparison, Shift-only mode, score points, the "made for" lines, the character window score and ignoring enchants.
- **Detail** and **Hit caps** buttons.
- **Stat weights**: a window listing what every stat is worth to your spec. Type a new number and press Enter to change it; changed stats turn gold. Strength and the other primary stats show what they're worth on the right, and a number typed there is added on top. Your changes are saved per character and per spec. You can also tell the addon about hit you get from somewhere it can't see.
- **List my gear**: everything you have equipped, with scores, in chat.

### Commands

| Command | What it does |
| --- | --- |
| `/eca` | Open the options window |
| `/eca on` · `/eca off` | Switch the comparison on or off |
| `/eca spec auto` · `/eca spec fury` | What to score for |
| `/eca detail 1` · `2` · `3` | Compact, normal or detailed |
| `/eca shift` | Only show while Shift is held |
| `/eca caps auto` · `raid` · `leveling` · `off` | How hit caps are judged |
| `/eca enchants` | Count or ignore enchants |
| `/eca gear` | List your equipped gear with scores |
| `/eca weights` | List the stat weights |
| `/eca weight CRIT 30` | Change one weight; `/eca weight reset` puts them back |
| `/eca hit 3` · `/eca spellhit 2` | Extra hit % from buffs or talents the addon can't see |
| `/eca help` | List the commands in game |

## Good to know

- The 1.12 client doesn't tell addons what stats an item has, so the addon reads the tooltip text. It needs the **English** client.
- Stat weights are a starting point, not gospel. They're tuned for level 60 PvE; if your guild or a class guide uses different numbers, type them into the Stat weights window.
- Servers with custom talents can change what a stat is worth. If a verdict looks wrong for your server, adjust the weight and it stays adjusted.

## Reporting bugs

Open an [issue](https://github.com/notforever-ship-it/EquipCompareAdv/issues) and include:

- The item you hovered and what you had equipped.
- Your class, level and the spec shown at the top of the panel.
- What the panel said and what you expected.
- If a red error appeared in chat, type `/eca debug` and copy the line it prints.

## For developers

- The addon files live at the repo root, which is the layout launchers expect; `tools/` is development only and left out of release zips.
- `node tools/check-lua.js` parses every file as **Lua 5.0** and flags things the 1.12 client doesn't have.
- `node tools/install.js [path to Interface\AddOns]` copies the addon into a game folder.
- `Stats.lua` reads tooltips, `Profiles.lua` holds the spec weights and the "made for" judgement, `Compare.lua` scores and compares, `Panel.lua` draws.

## Credits

Made by stealthzi.

## License

MIT. See [LICENSE](LICENSE).
