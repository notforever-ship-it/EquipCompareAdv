-- Equip Compare Adv: what each stat is worth to each spec.
--
-- Every spec has weights for the stats that do the work: attack power, crit, hit, spell damage, health...
-- Strength, Agility, Stamina, Intellect and Spirit get their value from what they turn into for that
-- class (a warrior's Strength is 2 attack power, a rogue's Agility is attack power, crit and dodge), using
-- the 1.12 conversion rates scaled to your level. Melee specs count in attack power, casters in spell
-- damage, healers in healing, tanks in stamina, so scores only compare within one spec.

local ECA = EquipCompareAdv

ECA.ROLE_NAMES = {
  tank = "Tank", melee = "DPS (melee)", ranged = "DPS (ranged)", caster = "DPS (caster)", healer = "Healer",
}
ECA.CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
ECA.CLASS_NAMES = {
  WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
  SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}
ECA.CLASS_COLORS = {
  WARRIOR = "|cffc79c6e", PALADIN = "|cfff58cba", HUNTER = "|cffabd473", ROGUE = "|cfffff569",
  PRIEST = "|cffffffff", SHAMAN = "|cff0070de", MAGE = "|cff69ccf0", WARLOCK = "|cff9482c9", DRUID = "|cffff7d0a",
}

-- How primary stats convert at level 60. agiCrit / agiDodge / intCrit = points needed for 1%.
-- spiMP5 = mana per 5 sec from 1 Spirit while regenerating.
local CONV = {
  WARRIOR = { strAP = 2, agiAP = 0, agiRAP = 0, agiCrit = 20, agiDodge = 20, intCrit = 0, spiMP5 = 0, strBlock = 0.05 },
  PALADIN = { strAP = 2, agiAP = 0, agiRAP = 0, agiCrit = 20, agiDodge = 20, intCrit = 54, spiMP5 = 0.5, strBlock = 0.05 },
  HUNTER = { strAP = 1, agiAP = 1, agiRAP = 2, agiCrit = 53, agiDodge = 26.5, intCrit = 0, spiMP5 = 0.5, strBlock = 0 },
  ROGUE = { strAP = 1, agiAP = 1, agiRAP = 0, agiCrit = 29, agiDodge = 14.5, intCrit = 0, spiMP5 = 0, strBlock = 0 },
  PRIEST = { strAP = 1, agiAP = 0, agiRAP = 0, agiCrit = 20, agiDodge = 20, intCrit = 59.2, spiMP5 = 0.625, strBlock = 0 },
  SHAMAN = { strAP = 2, agiAP = 0, agiRAP = 0, agiCrit = 20, agiDodge = 20, intCrit = 59.5, spiMP5 = 0.5, strBlock = 0.05 },
  MAGE = { strAP = 1, agiAP = 0, agiRAP = 0, agiCrit = 20, agiDodge = 20, intCrit = 59.5, spiMP5 = 0.625, strBlock = 0 },
  WARLOCK = { strAP = 1, agiAP = 0, agiRAP = 0, agiCrit = 20, agiDodge = 20, intCrit = 60.6, spiMP5 = 0.5, strBlock = 0 },
  DRUID = { strAP = 2, agiAP = 0, agiRAP = 0, agiCrit = 20, agiDodge = 20, intCrit = 60, spiMP5 = 0.5, strBlock = 0 },
}

-- Shared weight sets. Melee and ranged count in attack power, casters in spell damage, healers in
-- healing, tanks in stamina.
local function Melee(extra)
  local w = { AP = 1, CRIT = 29, HIT = 28, HASTE = 19, WEAPONSKILL = 11, ARMORPEN = 0.25, DPS = 14,
    HEALTH = 0.02, ARMOR = 0.01, DODGE = 1, PARRY = 1, DEFENSE = 0.2 }
  for k, v in pairs(extra or {}) do w[k] = v end
  return w
end

local function Tank(extra)
  local w = { HEALTH = 0.12, ARMOR = 0.1, DEFENSE = 1.7, DODGE = 12, PARRY = 13, BLOCK = 5, BLOCKVALUE = 0.5,
    AP = 0.35, HIT = 8, CRIT = 5, DPS = 4, WEAPONSKILL = 5, HP5 = 0.5, HASTE = 4,
    FIRERES = 0.15, NATURERES = 0.15, FROSTRES = 0.15, SHADOWRES = 0.15, ARCANERES = 0.15 }
  for k, v in pairs(extra or {}) do w[k] = v end
  return w
end

local function Caster(extra)
  local w = { SP = 1, SPELLCRIT = 10, SPELLHIT = 12, SPELLPEN = 0.3, HASTE = 10, MP5 = 1, MANA = 0.02,
    HEALTH = 0.01, ARMOR = 0.005 }
  for k, v in pairs(extra or {}) do w[k] = v end
  return w
end

local function Healer(extra)
  local w = { HEAL = 1, SPELLCRIT = 4, HASTE = 8, MP5 = 3, MANA = 0.035, HEALTH = 0.01, ARMOR = 0.005 }
  for k, v in pairs(extra or {}) do w[k] = v end
  return w
end

-- tabs = talent trees that pick this spec when "auto" is on. spirit = share of Spirit regeneration that
-- really happens in a fight. feral = "attack power in forms" counts. wand = wand DPS matters while
-- leveling. no2H / noShield = two-handers / shields are never "made for" this spec.
ECA.SPECS = {
  WARRIOR = {
    { key = "arms", name = "Arms", role = "melee", tabs = { 1 }, noShield = true, w = Melee({ CRIT = 30, HIT = 30 }), slowMH = true },
    { key = "fury", name = "Fury", role = "melee", tabs = { 2 }, noShield = true, w = Melee({ CRIT = 32, HIT = 30, HASTE = 21 }), slowMH = true },
    { key = "prot", name = "Protection", role = "tank", tabs = { 3 }, no2H = true, w = Tank() },
  },
  PALADIN = {
    { key = "holy", name = "Holy", role = "healer", tabs = { 1 }, spirit = 0.1,
      w = Healer({ SPELLCRIT = 12, MANA = 0.04 }) },
    { key = "prot", name = "Protection", role = "tank", tabs = { 2 }, no2H = true,
      w = Tank({ SP = 0.5, MANA = 0.015, BLOCKVALUE = 0.6, MP5 = 1 }) },
    { key = "ret", name = "Retribution", role = "melee", tabs = { 3 }, slowMH = true, noShield = true,
      w = Melee({ CRIT = 27, HIT = 26, HASTE = 18, WEAPONSKILL = 10, SP = 0.35, SPELLCRIT = 2, MANA = 0.01 }) },
  },
  HUNTER = {
    { key = "hunter", name = "Hunter", role = "ranged", tabs = { 1, 2, 3 },
      w = { RAP = 1, AP = 0.05, CRIT = 30, HIT = 30, HASTE = 15, RDPS = 14, DPS = 0.3, MP5 = 1.5, MANA = 0.01,
        HEALTH = 0.02, ARMOR = 0.01, WEAPONSKILL = 2 } },
  },
  ROGUE = {
    { key = "rogue", name = "Rogue", role = "melee", tabs = { 1, 2, 3 }, slowMH = true,
      w = Melee({ CRIT = 28, HIT = 28, HASTE = 20, WEAPONSKILL = 12 }) },
  },
  PRIEST = {
    { key = "holy", name = "Holy / Discipline", role = "healer", tabs = { 1, 2 }, spirit = 0.35, wand = true,
      w = Healer() },
    { key = "shadow", name = "Shadow", role = "caster", tabs = { 3 }, spirit = 0.25, wand = true,
      w = Caster({ SHADOWDMG = 1, SPELLCRIT = 5, HOLYDMG = 0.1 }) },
  },
  SHAMAN = {
    { key = "ele", name = "Elemental", role = "caster", tabs = { 1 }, spirit = 0.1,
      w = Caster({ NATUREDMG = 1, FIREDMG = 0.15, FROSTDMG = 0.15, SPELLCRIT = 11, MP5 = 1.2, MANA = 0.025 }) },
    { key = "enh", name = "Enhancement", role = "melee", tabs = { 2 }, slowMH = true, noShield = true,
      w = Melee({ CRIT = 28, HIT = 26, HASTE = 18, WEAPONSKILL = 10, SP = 0.3, MANA = 0.01 }) },
    { key = "resto", name = "Restoration", role = "healer", tabs = { 3 }, spirit = 0.1,
      w = Healer({ SPELLCRIT = 5 }) },
  },
  MAGE = {
    { key = "arcane", name = "Arcane", role = "caster", tabs = { 1 }, spirit = 0.3, wand = true,
      w = Caster({ ARCANEDMG = 1, FIREDMG = 0.3, FROSTDMG = 0.3, SPELLCRIT = 9, MANA = 0.03 }) },
    { key = "fire", name = "Fire", role = "caster", tabs = { 2 }, spirit = 0.2, wand = true,
      w = Caster({ FIREDMG = 1, FROSTDMG = 0.2, ARCANEDMG = 0.2, SPELLCRIT = 11 }) },
    { key = "frost", name = "Frost", role = "caster", tabs = { 3 }, spirit = 0.2, wand = true,
      w = Caster({ FROSTDMG = 1, FIREDMG = 0.2, ARCANEDMG = 0.2, SPELLCRIT = 9 }) },
  },
  WARLOCK = {
    { key = "shadow", name = "Shadow", role = "caster", tabs = { 1, 2, 3 }, spirit = 0.05, wand = true,
      w = Caster({ SHADOWDMG = 1, FIREDMG = 0.15, SPELLCRIT = 9, HEALTH = 0.03, MP5 = 0.5 }) },
    { key = "fire", name = "Fire", role = "caster", tabs = {}, spirit = 0.05, wand = true,
      w = Caster({ FIREDMG = 1, SHADOWDMG = 0.3, SPELLCRIT = 10, HEALTH = 0.03, MP5 = 0.5 }) },
  },
  DRUID = {
    { key = "balance", name = "Balance", role = "caster", tabs = { 1 }, spirit = 0.2,
      w = Caster({ ARCANEDMG = 0.7, NATUREDMG = 0.6, MP5 = 1.2, MANA = 0.025 }) },
    { key = "cat", name = "Feral (Cat)", role = "melee", tabs = { 2 }, feral = true, agiAP = 1,
      w = Melee({ CRIT = 28, HIT = 24, HASTE = 15, DPS = 0, WEAPONSKILL = 0, MANA = 0.005 }) },
    { key = "bear", name = "Feral (Bear)", role = "tank", tabs = {}, feral = true,
      w = Tank({ ARMOR = 0.3, DEFENSE = 1.2, PARRY = 0, BLOCK = 0, BLOCKVALUE = 0, DPS = 0, WEAPONSKILL = 0 }) },
    { key = "resto", name = "Restoration", role = "healer", tabs = { 3 }, spirit = 0.35,
      w = Healer({ SPELLCRIT = 3 }) },
  },
}

------------------------------------------------------------------------------------------------------
-- Which spec, and its numbers
------------------------------------------------------------------------------------------------------

local cache = {}

function ECA.InvalidateProfiles()
  cache = {}
end

-- The hit cap depends on whether you're dual wielding, so new gear means a fresh look.
function ECA.InvalidateCaps()
  cache.caps = nil
end

local function Level()
  local level = UnitLevel("player") or 60
  if level < 1 then level = 60 end
  return level
end

local function FindSpec(class, key)
  local specs = ECA.SPECS[class]
  for i = 1, table.getn(specs) do
    if specs[i].key == key then return specs[i] end
  end
  return nil
end

-- The talent tree with the most points picks the spec.
local function DetectSpec(class)
  local specs = ECA.SPECS[class]
  local bestTab, bestPoints = nil, 0
  if GetNumTalentTabs then
    for tab = 1, (GetNumTalentTabs() or 0) do
      local _, _, points = GetTalentTabInfo(tab)
      if points and points > bestPoints then bestTab, bestPoints = tab, points end
    end
  end
  if bestTab then
    for i = 1, table.getn(specs) do
      local tabs = specs[i].tabs
      for j = 1, table.getn(tabs) do
        if tabs[j] == bestTab then return specs[i] end
      end
    end
  end
  return specs[1]
end

-- The spec being scored for, and whether it came from the talents.
function ECA.Spec()
  if not cache.spec then
    local class = ECA.class
    local spec = ECA.char.spec ~= "auto" and FindSpec(class, ECA.char.spec)
    if spec then
      cache.spec, cache.specAuto = spec, false
    else
      cache.spec, cache.specAuto = DetectSpec(class), true
    end
  end
  return cache.spec, cache.specAuto
end

function ECA.SpecLabel()
  local spec, auto = ECA.Spec()
  local label = spec.name
  if label ~= ECA.CLASS_NAMES[ECA.class] then label = ECA.CLASS_NAMES[ECA.class] .. " - " .. label end
  if auto then label = label .. " (auto)" end
  return label
end

local PERCENT_STATS = { "CRIT", "HIT", "HASTE", "SPELLCRIT", "SPELLHIT", "DODGE", "PARRY", "BLOCK" }

-- A spec's weights with the player's own changes on top.
local function BuildWeights(class, spec, custom, level)
  local w = {}
  for k, v in pairs(spec.w) do w[k] = v end
  -- 1% of a level 20's damage is a much smaller number than 1% of a level 60's, so the percent stats
  -- shrink with level. It also keeps Agility honest: a point gives more crit at low level, but each
  -- percent is worth less, and the two cancel out.
  if level < 60 then
    local f = level / 60
    if f < 0.2 then f = 0.2 end
    for i = 1, table.getn(PERCENT_STATS) do
      local k = PERCENT_STATS[i]
      if w[k] then w[k] = w[k] * f end
    end
  end
  -- A wand is most of a leveling caster's damage and none of a level 60's.
  if spec.wand and level < 60 then w.RDPS = 4 * (1 - level / 60) end
  if custom then
    for k, v in pairs(custom) do w[k] = v end
  end
  return w
end

-- Points for 1 of each stat as it appears on an item.
local function BuildUnits(class, spec, w, level)
  local c = CONV[class]
  local f = level / 60
  if f < 0.2 then f = 0.2 elseif f > 1 then f = 1 end
  local function W(k) return w[k] or 0 end

  local u = {}
  for k, v in pairs(w) do u[k] = v end

  local agiAP = spec.agiAP or c.agiAP
  u.STR = W("STR") + c.strAP * W("AP") + c.strBlock * W("BLOCKVALUE")
  u.AGI = W("AGI") + agiAP * W("AP") + c.agiRAP * W("RAP") + W("CRIT") / (c.agiCrit * f) +
    W("DODGE") / (c.agiDodge * f) + 2 * W("ARMOR")
  u.STA = W("STA") + 10 * W("HEALTH")
  u.INT = W("INT") + 15 * W("MANA")
  if c.intCrit > 0 then u.INT = u.INT + W("SPELLCRIT") / (c.intCrit * f) end
  u.SPI = W("SPI") + c.spiMP5 * (spec.spirit or 0.15) * W("MP5")
  u.AP = W("AP") + W("RAP")               -- attack power on gear is ranged attack power too
  u.FERALAP = W("FERALAP")
  if spec.feral then u.FERALAP = u.FERALAP + W("AP") end
  u.SP = W("SP") + W("HEAL")              -- "damage and healing" is healing too
  return u
end

function ECA.Weights()
  if not cache.weights then
    local spec = ECA.Spec()
    cache.weights = BuildWeights(ECA.class, spec, ECA.char.custom[spec.key], Level())
  end
  return cache.weights
end

function ECA.DefaultWeights()
  return BuildWeights(ECA.class, ECA.Spec(), nil, Level())
end

function ECA.Units()
  if not cache.units then
    cache.units = BuildUnits(ECA.class, ECA.Spec(), ECA.Weights(), Level())
  end
  return cache.units
end

-- What a set of stat changes really does for this character, in words: "+28 attack power, +0.6% crit".
function ECA.Derived(d)
  local spec = ECA.Spec()
  local c = CONV[ECA.class]
  local f = Level() / 60
  if f < 0.2 then f = 0.2 elseif f > 1 then f = 1 end
  local function D(k) return d[k] or 0 end

  local ap = D("AP") + D("STR") * c.strAP + D("AGI") * (spec.agiAP or c.agiAP)
  if spec.feral then ap = ap + D("FERALAP") end
  local rap = D("AP") + D("RAP") + D("AGI") * c.agiRAP
  local crit = D("CRIT") + D("AGI") / (c.agiCrit * f)
  local dodge = D("DODGE") + D("AGI") / (c.agiDodge * f)
  local armor = D("ARMOR") + D("AGI") * 2
  local health = D("HEALTH") + D("STA") * 10
  local mana = D("MANA") + D("INT") * 15
  local spellCrit = D("SPELLCRIT")
  if c.intCrit > 0 then spellCrit = spellCrit + D("INT") / (c.intCrit * f) end
  local spell = D("SP")
  local healing = D("SP") + D("HEAL")

  local role = spec.role
  local parts = {}
  local function Part(value, label, pct)
    if math.abs(value) >= 0.05 then
      table.insert(parts, ECA.Signed(value) .. (pct and "% " or " ") .. label)
    end
  end
  if role == "melee" then
    Part(ap, "attack power") Part(crit, "crit", true) Part(D("HIT"), "hit", true) Part(health, "health")
  elseif role == "ranged" then
    Part(rap, "ranged attack power") Part(crit, "crit", true) Part(D("HIT"), "hit", true) Part(health, "health")
  elseif role == "tank" then
    Part(health, "health") Part(armor, "armor") Part(dodge, "dodge", true) Part(D("DEFENSE"), "defense") Part(ap, "attack power")
  elseif role == "caster" then
    Part(spell, "spell damage") Part(spellCrit, "spell crit", true) Part(D("SPELLHIT"), "spell hit", true)
    Part(mana, "mana") Part(health, "health")
  else
    Part(healing, "healing") Part(spellCrit, "spell crit", true) Part(mana, "mana") Part(D("MP5"), "mana per 5")
  end
  return parts
end

function ECA.SetWeight(stat, value)
  local spec = ECA.Spec()
  local custom = ECA.char.custom
  if type(custom[spec.key]) ~= "table" then custom[spec.key] = {} end
  custom[spec.key][stat] = value
  ECA.SettingsChanged()
end

function ECA.ResetWeights()
  ECA.char.custom[ECA.Spec().key] = nil
  ECA.SettingsChanged()
end

------------------------------------------------------------------------------------------------------
-- Caps: hit (and a tank's defense) stops being worth much once you have enough of it
------------------------------------------------------------------------------------------------------

local MELEE_HIT_TALENTS = { ["Precision"] = 1, ["Surefooted"] = 1, ["Nature's Guidance"] = 1 }
local SPELL_HIT_TALENTS = { ["Elemental Precision"] = 2, ["Arcane Focus"] = 2, ["Shadow Focus"] = 2,
  ["Suppression"] = 2, ["Nature's Guidance"] = 1 }

-- Hit % from talents: melee/ranged, spell (the best single spell talent, as they cover one school each).
function ECA.TalentHit()
  if not cache.talentHit then
    local melee, spell = 0, 0
    if GetNumTalentTabs and GetNumTalents and GetTalentInfo then
      for tab = 1, (GetNumTalentTabs() or 0) do
        for i = 1, (GetNumTalents(tab) or 0) do
          local name, _, _, _, rank = GetTalentInfo(tab, i)
          if name and rank and rank > 0 then
            if MELEE_HIT_TALENTS[name] then melee = melee + rank * MELEE_HIT_TALENTS[name] end
            if SPELL_HIT_TALENTS[name] and rank * SPELL_HIT_TALENTS[name] > spell then
              spell = rank * SPELL_HIT_TALENTS[name]
            end
          end
        end
      end
    end
    cache.talentHit = { melee = melee, spell = spell }
  end
  return cache.talentHit.melee, cache.talentHit.spell
end

function ECA.CapMode()
  local mode = ECA.db.capMode
  if mode == "auto" then
    if Level() >= 60 then mode = "raid" else mode = "leveling" end
  end
  return mode
end

-- { STAT = { cap = from gear, over = share of the value kept past the cap } }
function ECA.Caps()
  if not cache.caps then
    local caps = {}
    local mode = ECA.CapMode()
    if mode ~= "off" then
      local role = ECA.Spec().role
      local raid = (mode == "raid")
      local meleeTalents, spellTalents = ECA.TalentHit()
      if role == "caster" then
        local cap = (raid and 16 or 3) - spellTalents - ECA.char.extraSpellHit
        if cap < 0 then cap = 0 end
        caps.SPELLHIT = { cap = cap, over = 0 }
      elseif role ~= "healer" then
        -- Special attacks cap at 9% against a raid boss, 5% against things your own level. Past that, hit
        -- only helps the white swings of someone dual wielding.
        local cap = (raid and 9 or 5) - meleeTalents - ECA.char.extraHit
        if cap < 0 then cap = 0 end
        local over = 0
        if role ~= "ranged" and ECA.IsDualWielding and ECA.IsDualWielding() then over = 0.5 end
        caps.HIT = { cap = cap, over = over }
      end
      if role == "tank" and raid then
        caps.DEFENSE = { cap = 140, over = 0.5 }   -- 440 defense: no more crushing crits from bosses
      end
    end
    cache.caps = caps
  end
  return cache.caps
end

------------------------------------------------------------------------------------------------------
-- Who is this item made for?
------------------------------------------------------------------------------------------------------

-- Roughly what each stat costs out of an item's budget in 1.12 itemization. Weapon DPS and armor come
-- with the slot rather than the budget, so they stay out.
local BUDGET = {
  STR = 1, AGI = 1, STA = 1, INT = 1, SPI = 1, AP = 0.5, RAP = 0.4, FERALAP = 0.15, CRIT = 14, HIT = 10, SPELLCRIT = 14,
  SPELLHIT = 8, DODGE = 12, PARRY = 20, BLOCK = 5, BLOCKVALUE = 0.65, DEFENSE = 1.5, SP = 0.86, HEAL = 0.45,
  SHADOWDMG = 0.7, FIREDMG = 0.7, FROSTDMG = 0.7, ARCANEDMG = 0.7, NATUREDMG = 0.7, HOLYDMG = 0.7,
  MP5 = 2.5, HP5 = 1, HEALTH = 0.07, MANA = 0.07, HASTE = 10, SPELLPEN = 0.8, WEAPONSKILL = 1.2, ARMORPEN = 0.1,
  FIRERES = 1, NATURERES = 1, FROSTRES = 1, SHADOWRES = 1, ARCANERES = 1,
}
-- The everyday stats a spec's "best case" is measured against.
local NORM_STATS = { "STR", "AGI", "STA", "INT", "SPI", "AP", "RAP", "CRIT", "HIT", "SPELLCRIT", "SPELLHIT",
  "DODGE", "PARRY", "BLOCKVALUE", "DEFENSE", "SP", "HEAL", "SHADOWDMG", "FIREDMG", "FROSTDMG", "ARCANEDMG",
  "NATUREDMG", "MP5" }

-- Stats that mark an item as tank gear (with Stamina, which is counted apart).
local TANK_STATS = { DEFENSE = true, DODGE = true, PARRY = true, BLOCK = true, BLOCKVALUE = true, HEALTH = true,
  HP5 = true, FIRERES = true, NATURERES = true, FROSTRES = true, SHADOWRES = true, ARCANERES = true }

local ARMOR_RANK = { Cloth = 1, Leather = 2, Mail = 3, Plate = 4 }
local CLASS_ARMOR = { WARRIOR = 4, PALADIN = 4, HUNTER = 3, SHAMAN = 3, ROGUE = 2, DRUID = 2, PRIEST = 1, MAGE = 1, WARLOCK = 1 }
local SHIELD_CLASSES = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local DUAL_WIELD = { WARRIOR = true, ROGUE = true, HUNTER = true }
local RELIC_CLASS = { Libram = "PALADIN", Idol = "DRUID", Totem = "SHAMAN" }
local WEAPONS = {
  WARRIOR = { Axe = 2, Sword = 2, Mace = 2, Dagger = 1, ["Fist Weapon"] = 1, Polearm = 2, Staff = 2, Bow = 1, Gun = 1, Crossbow = 1, Thrown = 1 },
  PALADIN = { Axe = 2, Sword = 2, Mace = 2, Polearm = 2 },
  HUNTER = { Axe = 2, Sword = 2, Dagger = 1, ["Fist Weapon"] = 1, Polearm = 2, Staff = 2, Bow = 1, Gun = 1, Crossbow = 1, Thrown = 1 },
  ROGUE = { Sword = 1, Mace = 1, Dagger = 1, ["Fist Weapon"] = 1, Bow = 1, Gun = 1, Crossbow = 1, Thrown = 1 },
  PRIEST = { Mace = 1, Dagger = 1, Staff = 2, Wand = 1 },
  SHAMAN = { Axe = 2, Mace = 2, Dagger = 1, ["Fist Weapon"] = 1, Staff = 2 },
  MAGE = { Sword = 1, Dagger = 1, Staff = 2, Wand = 1 },
  WARLOCK = { Sword = 1, Dagger = 1, Staff = 2, Wand = 1 },
  DRUID = { Mace = 2, Dagger = 1, ["Fist Weapon"] = 1, Staff = 2 },
}   -- 1 = one-handed only, 2 = two-handed as well

local function CanUse(class, item)
  if item.classes and not string.find(item.classes, string.lower(ECA.CLASS_NAMES[class]), 1, true) then
    return false
  end
  local sub = item.subType
  if not sub then return true end
  if ARMOR_RANK[sub] then return ARMOR_RANK[sub] <= CLASS_ARMOR[class] end
  if sub == "Shield" then return SHIELD_CLASSES[class] or false end
  if RELIC_CLASS[sub] then return RELIC_CLASS[sub] == class end
  local skill = WEAPONS[class][sub]
  if not skill then return false end
  if item.kind == "TWOHAND" and skill < 2 then return false end
  if item.kind == "OFFHAND" and not DUAL_WIELD[class] then return false end
  return true
end

-- Units and the "best case" value per budget point for any class and spec, at the player's level.
local function FitProfile(class, spec)
  local key = "fit" .. class .. spec.key
  if not cache[key] then
    local level = Level()
    local units = BuildUnits(class, spec, BuildWeights(class, spec, nil, level), level)
    local top = {}
    for i = 1, table.getn(NORM_STATS) do
      local k = NORM_STATS[i]
      table.insert(top, (units[k] or 0) / BUDGET[k])
    end
    table.sort(top, function(a, b) return a > b end)
    local norm = (top[1] + top[2] + top[3]) / 3
    if norm <= 0 then norm = 1 end
    cache[key] = { units = units, norm = norm }
  end
  return cache[key]
end

-- How well the item's stat budget is spent for every spec that can use it, best first.
-- Stamina is on nearly everything, so it only counts for tanks; for everyone else it is left out of both
-- sides. Returns nil for items with no real stats to judge (white weapons, plain armor).
-- Also sets item.myFit (0..1) for the player's own spec, or item.notMyClass when the class can't use it.
function ECA.Fits(item)
  if item.fits ~= nil then return item.fits or nil end
  item.fits = false
  local stats = item.stats
  local budget, stamina, tankBudget = 0, 0, 0
  for k, v in pairs(stats) do
    if k == "STA" then
      stamina = math.abs(v)
    elseif BUDGET[k] then
      budget = budget + math.abs(v) * BUDGET[k]
      if TANK_STATS[k] then tankBudget = tankBudget + math.abs(v) * BUDGET[k] end
    end
  end
  if budget + stamina < 3 then return nil end

  local mainArmor = type(item.kind) == "number" and item.subType and ARMOR_RANK[item.subType]
  local mySpec = ECA.Spec()
  local fits = {}
  if not CanUse(ECA.class, item) then item.notMyClass = true end
  for c = 1, table.getn(ECA.CLASS_ORDER) do
    local class = ECA.CLASS_ORDER[c]
    if CanUse(class, item) then
      local specs = ECA.SPECS[class]
      for i = 1, table.getn(specs) do
        local spec = specs[i]
        local suits = not ((spec.no2H and item.kind == "TWOHAND") or (spec.noShield and item.subType == "Shield"))
        local profile = FitProfile(class, spec)
        local tank = (spec.role == "tank")
        local value, cost = 0, budget
        for k, v in pairs(stats) do
          if BUDGET[k] and (tank or k ~= "STA") then value = value + v * (profile.units[k] or 0) end
        end
        if tank then cost = cost + stamina end
        local raw = 0
        if suits and cost > 0 then raw = value / (cost * profile.norm) end
        -- A tank can use Agility or Strength, but gear is only made for tanks when it carries tank
        -- stats: stamina, defense, dodge, parry, block.
        if tank and cost > 0 then raw = raw * (0.55 + 0.45 * (tankBudget + stamina) / cost) end
        -- Classes mostly want their own armor type: plate wearers skip leather unless it is special.
        if mainArmor and mainArmor < CLASS_ARMOR[class] then raw = raw * 0.88 end
        local fit = raw
        if fit > 1 then fit = 1 elseif fit < 0 then fit = 0 end
        if class == ECA.class and spec == mySpec then item.myFit = fit end
        if raw > 0 then
          table.insert(fits, { class = class, spec = spec, role = spec.role, fit = fit, raw = raw })
        end
      end
    end
  end
  table.sort(fits, function(a, b) return a.raw > b.raw end)
  item.fits = fits
  return fits
end
