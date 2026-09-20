-- Equip Compare Adv: the stats the addon knows, and reading them out of an item tooltip.
-- The 1.12 client has no API for an item's stats, so everything comes from the tooltip's text. The text
-- patterns cover the vanilla wording plus the extra effects Turtle WoW based servers use.

local ECA = EquipCompareAdv

-- Display order. pct = shown with a % sign.
ECA.STATS = {
  { key = "DPS", name = "Weapon DPS" },
  { key = "RDPS", name = "Ranged DPS" },
  { key = "ARMOR", name = "Armor" },
  { key = "STR", name = "Strength" },
  { key = "AGI", name = "Agility" },
  { key = "STA", name = "Stamina" },
  { key = "INT", name = "Intellect" },
  { key = "SPI", name = "Spirit" },
  { key = "AP", name = "Attack Power" },
  { key = "RAP", name = "Ranged Attack Power" },
  { key = "FERALAP", name = "Feral Attack Power" },
  { key = "CRIT", name = "Crit Chance", pct = true },
  { key = "HIT", name = "Hit Chance", pct = true },
  { key = "HASTE", name = "Attack and Cast Speed", pct = true },
  { key = "WEAPONSKILL", name = "Weapon Skill" },
  { key = "ARMORPEN", name = "Armor Penetration" },
  { key = "SP", name = "Spell Damage and Healing" },
  { key = "HEAL", name = "Healing" },
  { key = "SHADOWDMG", name = "Shadow Damage" },
  { key = "FIREDMG", name = "Fire Damage" },
  { key = "FROSTDMG", name = "Frost Damage" },
  { key = "ARCANEDMG", name = "Arcane Damage" },
  { key = "NATUREDMG", name = "Nature Damage" },
  { key = "HOLYDMG", name = "Holy Damage" },
  { key = "SPELLCRIT", name = "Spell Crit Chance", pct = true },
  { key = "SPELLHIT", name = "Spell Hit Chance", pct = true },
  { key = "SPELLPEN", name = "Spell Penetration" },
  { key = "MP5", name = "Mana per 5 sec" },
  { key = "HP5", name = "Health per 5 sec" },
  { key = "HEALTH", name = "Health" },
  { key = "MANA", name = "Mana" },
  { key = "DEFENSE", name = "Defense" },
  { key = "DODGE", name = "Dodge Chance", pct = true },
  { key = "PARRY", name = "Parry Chance", pct = true },
  { key = "BLOCK", name = "Block Chance", pct = true },
  { key = "BLOCKVALUE", name = "Block Value" },
  { key = "FIRERES", name = "Fire Resistance" },
  { key = "NATURERES", name = "Nature Resistance" },
  { key = "FROSTRES", name = "Frost Resistance" },
  { key = "SHADOWRES", name = "Shadow Resistance" },
  { key = "ARCANERES", name = "Arcane Resistance" },
}

ECA.STAT_BY_KEY = {}
for i = 1, table.getn(ECA.STATS) do
  ECA.STAT_BY_KEY[ECA.STATS[i].key] = ECA.STATS[i]
end

-- 12 -> "12", 12.345 -> "12.3"
function ECA.Num(v)
  local r = math.floor(v * 10 + 0.5) / 10
  if r == math.floor(r) then return string.format("%d", r) end
  return string.format("%.1f", r)
end

-- Stat weights can be tiny (health is worth 0.02 a point): up to three decimals, no trailing zeros.
function ECA.FmtWeight(v)
  local s = string.format("%.3f", v)
  s = string.gsub(s, "0+$", "")
  s = string.gsub(s, "%.$", "")
  return s
end

function ECA.Signed(v)
  if v < 0 then return "-" .. ECA.Num(-v) end
  return "+" .. ECA.Num(v)
end

-- "+12 Strength", "-1% Hit Chance"
function ECA.StatText(key, value)
  local info = ECA.STAT_BY_KEY[key]
  return ECA.Signed(value) .. (info.pct and "% " or " ") .. info.name
end

------------------------------------------------------------------------------------------------------
-- Slots
------------------------------------------------------------------------------------------------------

-- What the tooltip's slot line means: a single inventory slot number, or a kind that needs thought.
local SLOT_BY_TEXT = {}
local function Slot(globalName, fallback, kind)
  SLOT_BY_TEXT[getglobal(globalName) or fallback] = kind
end
Slot("INVTYPE_HEAD", "Head", 1)
Slot("INVTYPE_NECK", "Neck", 2)
Slot("INVTYPE_SHOULDER", "Shoulder", 3)
Slot("INVTYPE_CHEST", "Chest", 5)
Slot("INVTYPE_ROBE", "Chest", 5)
Slot("INVTYPE_WAIST", "Waist", 6)
Slot("INVTYPE_LEGS", "Legs", 7)
Slot("INVTYPE_FEET", "Feet", 8)
Slot("INVTYPE_WRIST", "Wrist", 9)
Slot("INVTYPE_HAND", "Hands", 10)
Slot("INVTYPE_FINGER", "Finger", "FINGER")
Slot("INVTYPE_TRINKET", "Trinket", "TRINKET")
Slot("INVTYPE_CLOAK", "Back", 15)
Slot("INVTYPE_WEAPON", "One-Hand", "ONEHAND")
Slot("INVTYPE_2HWEAPON", "Two-Hand", "TWOHAND")
Slot("INVTYPE_WEAPONMAINHAND", "Main Hand", "MAINHAND")
Slot("INVTYPE_WEAPONOFFHAND", "Off Hand", "OFFHAND")
Slot("INVTYPE_SHIELD", "Off Hand", "OFFHAND")
Slot("INVTYPE_HOLDABLE", "Held In Off-hand", "OFFHAND")
Slot("INVTYPE_RANGED", "Ranged", "RANGED")
Slot("INVTYPE_RANGEDRIGHT", "Ranged", "RANGED")
Slot("INVTYPE_THROWN", "Thrown", "RANGED")
Slot("INVTYPE_RELIC", "Relic", "RANGED")

ECA.SLOT_LABEL = {
  [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
  [9] = "Wrist", [10] = "Hands", [11] = "Ring 1", [12] = "Ring 2", [13] = "Trinket 1", [14] = "Trinket 2",
  [15] = "Back", [16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged",
}
-- Every slot that counts towards the gear score (shirt and tabard don't).
ECA.GEAR_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

-- Armor and weapon types, as the tooltip shows them on the right of the slot line.
local SUBTYPES = {
  Cloth = "armor", Leather = "armor", Mail = "armor", Plate = "armor", Shield = "armor",
  Axe = "weapon", Sword = "weapon", Mace = "weapon", Dagger = "weapon", ["Fist Weapon"] = "weapon",
  Polearm = "weapon", Staff = "weapon", Bow = "weapon", Gun = "weapon", Crossbow = "weapon",
  Thrown = "weapon", Wand = "weapon", Libram = "relic", Idol = "relic", Totem = "relic",
}

------------------------------------------------------------------------------------------------------
-- Text patterns (matched against lower-case text)
------------------------------------------------------------------------------------------------------

local SCHOOL_DMG = {
  shadow = "SHADOWDMG", fire = "FIREDMG", frost = "FROSTDMG",
  arcane = "ARCANEDMG", nature = "NATUREDMG", holy = "HOLYDMG",
}

-- The text after "Equip: ". { pattern, stat } ; "SCHOOL" and "SKILL" are handled by hand.
local EQUIP_PATTERNS = {
  { "^%+(%d+) attack power in cat", "FERALAP" },
  { "^%+(%d+) ranged attack power%.?$", "RAP" },
  { "^%+(%d+) attack power%.?$", "AP" },
  { "^increases attack power by (%d+)%.?$", "AP" },
  { "^improves your chance to get a critical strike with spells by (%d+)%%", "SPELLCRIT" },
  { "^improves your chance to get a critical strike by (%d+)%%", "CRIT" },
  { "^improves your chance to hit with spells by (%d+)%%", "SPELLHIT" },
  { "^improves your chance to hit by (%d+)%%", "HIT" },
  { "^increases your chance to dodge an attack by (%d+)%%", "DODGE" },
  { "^increases your chance to parry an attack by (%d+)%%", "PARRY" },
  { "^increases your chance to block attacks with a shield by (%d+)%%", "BLOCK" },
  { "^increases the block value of your shield by (%d+)", "BLOCKVALUE" },
  { "^increased defense %+(%d+)", "DEFENSE" },
  { "^increases damage and healing done by magical spells and effects by up to (%d+)", "SP" },
  { "^increases healing done by spells and effects by up to (%d+)", "HEAL" },
  { "^increases damage done by (%a+) spells and effects by up to (%d+)", "SCHOOL" },
  { "^increases spell power by (%d+)", "SP" },
  { "^increases your spell power by (%d+)", "SP" },
  { "^increases healing power by (%d+)", "HEAL" },
  { "^restores (%d+) mana per 5 sec", "MP5" },
  { "^restores (%d+) mana every 5 sec", "MP5" },
  { "^restores (%d+) health per 5 sec", "HP5" },
  { "^restores (%d+) health every 5 sec", "HP5" },
  { "^decreases the magical resistances of your spell targets by (%d+)", "SPELLPEN" },
  { "^increases your attack and casting speed by (%d+)%%", "HASTE" },
  { "^increases your attack speed by (%d+)%%", "HASTE" },
  { "^your attacks ignore (%d+) of the target's armor", "ARMORPEN" },
  { "^increased ([%a%- ]+) %+(%d+)", "SKILL" },
}

-- "+N <name>" and "<name> +N" lines: white base stats, random suffixes and enchants.
local NAME_TO_STAT = {
  ["strength"] = "STR", ["agility"] = "AGI", ["stamina"] = "STA", ["intellect"] = "INT", ["spirit"] = "SPI",
  ["armor"] = "ARMOR", ["reinforced armor"] = "ARMOR",
  ["attack power"] = "AP", ["ranged attack power"] = "RAP",
  ["healing spells"] = "HEAL", ["healing"] = "HEAL",
  ["damage and healing spells"] = "SP", ["spell damage and healing"] = "SP", ["healing and spell damage"] = "SP",
  ["spell damage"] = "SP", ["spell power"] = "SP",
  ["shadow spell damage"] = "SHADOWDMG", ["fire spell damage"] = "FIREDMG", ["frost spell damage"] = "FROSTDMG",
  ["arcane spell damage"] = "ARCANEDMG", ["nature spell damage"] = "NATUREDMG", ["holy spell damage"] = "HOLYDMG",
  ["defense"] = "DEFENSE", ["health"] = "HEALTH", ["hp"] = "HEALTH", ["mana"] = "MANA",
  ["fire resistance"] = "FIRERES", ["nature resistance"] = "NATURERES", ["frost resistance"] = "FROSTRES",
  ["shadow resistance"] = "SHADOWRES", ["arcane resistance"] = "ARCANERES",
}
local ALL_STATS = { "STR", "AGI", "STA", "INT", "SPI" }
local ALL_RES = { "FIRERES", "NATURERES", "FROSTRES", "SHADOWRES", "ARCANERES" }

local function Add(stats, key, value)
  stats[key] = (stats[key] or 0) + value
end

local function StripColors(text)
  text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = string.gsub(text, "|r", "")
  return text
end

local function Trim(text)
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")
  return text
end

-- The part of an "Equip:" line after the prefix. True when it was understood.
local function ParseEquip(stats, s)
  for i = 1, table.getn(EQUIP_PATTERNS) do
    local p = EQUIP_PATTERNS[i]
    local _, _, c1, c2 = string.find(s, p[1])
    if c1 then
      if p[2] == "SCHOOL" then
        local key = SCHOOL_DMG[c1]
        if not key then return false end
        Add(stats, key, tonumber(c2))
      elseif p[2] == "SKILL" then
        Add(stats, "WEAPONSKILL", tonumber(c2))
      else
        Add(stats, p[2], tonumber(c1))
      end
      return true
    end
  end
  return false
end

-- A "+N name" / "name +N" pair. True when the name is a stat the addon knows.
local function AddNamed(stats, name, value)
  name = Trim(name)
  if name == "all stats" or name == "stats" then
    for i = 1, 5 do Add(stats, ALL_STATS[i], value) end
    return true
  elseif name == "all resistances" or name == "resist all" then
    for i = 1, 5 do Add(stats, ALL_RES[i], value) end
    return true
  end
  local key = NAME_TO_STAT[name]
  if key then
    Add(stats, key, value)
    return true
  end
  return false
end

-- A line that isn't an Equip/Use/Set line. Returns true when it carried a stat.
-- 'item' collects the weapon speed and flat weapon damage, which aren't plain stats.
local function ParseBase(item, stats, s, tipName, index)
  local _, _, v = string.find(s, "^(%d+) armor$")
  if v then Add(stats, "ARMOR", tonumber(v)) return true end

  _, _, v = string.find(s, "^(%d+) block$")
  if v then Add(stats, "BLOCKVALUE", tonumber(v)) return true end

  _, _, v = string.find(s, "^%(([%d%.]+) damage per second%)$")
  if v then Add(stats, "DPS", tonumber(v) or 0) return true end

  if string.find(s, "^%d+ %- %d+ [%a ]*damage$") then
    local right = getglobal(tipName .. "TextRight" .. index)
    local text = right and right:GetText()
    if text then
      local _, _, speed = string.find(text, "([%d%.]+)")
      item.speed = tonumber(speed)
    end
    return false
  end

  _, _, v = string.find(s, "^%+(%d+) mana every 5 sec")
  if v then Add(stats, "MP5", tonumber(v)) return true end
  _, _, v = string.find(s, "^%+(%d+) health every 5 sec")
  if v then Add(stats, "HP5", tonumber(v)) return true end
  _, _, v = string.find(s, "^mana regen (%d+) per 5 sec")
  if v then Add(stats, "MP5", tonumber(v)) return true end

  _, _, v = string.find(s, "^%+(%d+) weapon damage%.?$")
  if not v then _, _, v = string.find(s, "^weapon damage %+(%d+)%.?$") end
  if v then item.weaponDamage = (item.weaponDamage or 0) + tonumber(v) return true end

  local sign, num, name
  _, _, sign, num, name = string.find(s, "^([%+%-])(%d+) ([%a ]+)%.?$")
  if not num then
    _, _, name, sign, num = string.find(s, "^([%a ]+) ([%+%-])(%d+)%.?$")
  end
  if num then
    local value = tonumber(num)
    if sign == "-" then value = -value end
    return AddNamed(stats, name, value)
  end
  return false
end

local function IsRed(r, g, b)
  return r and r > 0.9 and g < 0.25 and b < 0.25
end

local function IsGreen(r, g, b)
  return r and r < 0.15 and g > 0.9 and b < 0.15
end

-- Read an item out of a tooltip that is already filled in. 'live' is true for a tooltip on screen,
-- where red text (can't use it) is worth looking for.
-- Returns nil when the tooltip isn't showing something you can equip.
function ECA.ParseTooltip(tipName, numLines, live)
  local first = getglobal(tipName .. "TextLeft1")
  local name = first and first:GetText()
  if not name or name == "" or numLines < 2 then return nil end

  -- The slot line sits in the first few lines: name, binding, unique, then the slot.
  local kind, slotLine
  local limit = numLines
  if limit > 7 then limit = 7 end
  for i = 2, limit do
    local fs = getglobal(tipName .. "TextLeft" .. i)
    local text = fs and fs:GetText()
    if text then
      if SLOT_BY_TEXT[text] then
        kind, slotLine = SLOT_BY_TEXT[text], i
        break
      end
      if string.find(text, "^Requires") or string.find(text, "^Use:") or string.find(text, "^Equip:") then break end
    end
  end
  if not kind then return nil end

  local item = { name = name, kind = kind, stats = {}, enchantStats = {}, extras = {} }
  if first.GetTextColor then item.r, item.g, item.b = first:GetTextColor() end

  local right = getglobal(tipName .. "TextRight" .. slotLine)
  if right and right.IsShown and not right:IsShown() then right = nil end   -- hidden = stale text
  if right then
    local sub = right:GetText()
    if sub and SUBTYPES[sub] then item.subType, item.subKind = sub, SUBTYPES[sub] end
  end
  -- Rings, trinkets and necklaces have no type; anything left over there is stale text.
  if kind == "FINGER" or kind == "TRINKET" or kind == 2 then item.subType, item.subKind = nil, nil end

  for i = 2, numLines do
    local fs = getglobal(tipName .. "TextLeft" .. i)
    local raw = fs and fs:GetText()
    if raw and raw ~= "" and i ~= slotLine then
      local text = Trim(StripColors(raw))
      local s = string.lower(text)
      local r, g, b
      if fs.GetTextColor then r, g, b = fs:GetTextColor() end

      if live and not item.red and IsRed(r, g, b) and not string.find(s, "^durability") then
        item.red = text
      end

      local _, e = string.find(s, "^equip: ")
      if e then
        if not ParseEquip(item.stats, string.sub(s, e + 1)) then
          table.insert(item.extras, text)
        end
      elseif string.find(s, "^use: ") or string.find(s, "^chance on hit: ") then
        table.insert(item.extras, text)
      elseif string.find(s, "^set: ") or string.find(s, "^%(%d+%) set: ") then
        -- set bonuses belong to the set, not to this item
      elseif string.find(s, "^classes: ") then
        item.classes = string.sub(s, 10)
      else
        local _, _, setName, have, total = string.find(text, "^(.+) %((%d+)/(%d+)%)$")
        if setName then
          item.setName, item.setHave, item.setTotal = setName, tonumber(have), tonumber(total)
        elseif IsGreen(r, g, b) and not string.find(s, "^%d+ armor$") and not string.find(s, "^<") then
          -- A green line with no prefix is an enchant (green "N Armor" is bonus armor, "<Made by>" a signature).
          ParseBase(item, item.enchantStats, s, tipName, i)
          item.enchantText = text
        else
          ParseBase(item, item.stats, s, tipName, i)
        end
      end
    end
  end

  -- Red text on the right of the slot line: an armor or weapon type you can't use. Says more than a
  -- red "Requires Level", so it wins.
  if live and right and right.GetTextColor then
    local r, g, b = right:GetTextColor()
    if IsRed(r, g, b) then item.red = (right:GetText() or "this type") .. " isn't something you can equip" end
  end

  -- "+N Weapon Damage" is worth N / speed in DPS.
  if item.weaponDamage and item.stats.DPS then
    Add(item.enchantStats, "DPS", item.weaponDamage / (item.speed or 2.5))
  end

  -- Ranged weapons keep their DPS apart: it is worth a lot to a hunter and nothing to a warrior.
  if kind == "RANGED" then
    if item.stats.DPS then item.stats.RDPS, item.stats.DPS = item.stats.DPS, nil end
    if item.enchantStats.DPS then item.enchantStats.RDPS, item.enchantStats.DPS = item.enchantStats.DPS, nil end
  end

  return item
end

-- The stats to score an item by: with its enchant, or bare when enchants are ignored.
function ECA.ItemStats(item)
  if ECA.db.ignoreEnchants then return item.stats end
  if not item.full then
    local full = {}
    for k, v in pairs(item.stats) do full[k] = v end
    for k, v in pairs(item.enchantStats) do full[k] = (full[k] or 0) + v end
    item.full = full
  end
  return item.full
end
