-- Equip Compare Adv: what you're wearing, scoring, and working out the comparison for a hovered item.

local ECA = EquipCompareAdv

local EMPTY = { empty = true, stats = {}, enchantStats = {}, extras = {} }

------------------------------------------------------------------------------------------------------
-- Equipped gear
------------------------------------------------------------------------------------------------------

local gear = {}        -- slot -> parsed item or EMPTY
local gearTotals       -- every equipped stat added up

function ECA.ClearGearCache()
  gear = {}
  gearTotals = nil
  if ECA.InvalidateCaps then ECA.InvalidateCaps() end
end

local scanTip
local function ScanTooltip()
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "EquipCompareAdvScanTooltip", nil, "GameTooltipTemplate")
  end
  scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
  return scanTip
end

function ECA.Equipped(slot)
  if not gear[slot] then
    local tip = ScanTooltip()
    tip:ClearLines()
    local hasItem = tip:SetInventoryItem("player", slot)
    local item
    if hasItem then
      item = ECA.ParseTooltip("EquipCompareAdvScanTooltip", tip:NumLines(), false)
    end
    if item then
      item.slot = slot
      item.link = GetInventoryItemLink("player", slot)
      -- The tooltip can't tell a ranged slot from any other; the slot number can.
      if slot == 18 and item.stats.DPS then item.stats.RDPS, item.stats.DPS = item.stats.DPS, nil end
    end
    gear[slot] = item or EMPTY
  end
  return gear[slot]
end

function ECA.IsDualWielding()
  local off = ECA.Equipped(17)
  return (not off.empty) and off.stats.DPS ~= nil
end

-- The off hand swings for half damage, so its weapon DPS counts half.
local function DpsScale(slot)
  if slot == 17 then return 0.5 end
  return nil
end

local function GearTotals()
  if not gearTotals then
    local totals = {}
    for i = 1, table.getn(ECA.GEAR_SLOTS) do
      local stats = ECA.ItemStats(ECA.Equipped(ECA.GEAR_SLOTS[i]))
      for k, v in pairs(stats) do totals[k] = (totals[k] or 0) + v end
    end
    gearTotals = totals
  end
  return gearTotals
end

------------------------------------------------------------------------------------------------------
-- Scoring
------------------------------------------------------------------------------------------------------

-- How much of 'value' still counts when the rest of your gear already gives 'other' towards a cap.
local function Capped(value, cap, other)
  if value <= 0 then return value end
  local room = cap.cap - other
  if room < 0 then room = 0 end
  if value <= room then return value end
  return room + (value - room) * cap.over
end

-- 'other' = the capped stats coming from the gear that stays on.
function ECA.Score(stats, other, dpsScale)
  local units, caps = ECA.Units(), ECA.Caps()
  local total = 0
  for k, v in pairs(stats) do
    local u = units[k]
    if u and u ~= 0 then
      if k == "DPS" and dpsScale then v = v * dpsScale end
      if caps[k] then v = Capped(v, caps[k], other and other[k] or 0) end
      total = total + v * u
    end
  end
  return total
end

-- Points one stat's change is worth, caps included.
local function Contribution(key, newValue, oldValue, other, dpsScale)
  local u = ECA.Units()[key]
  if not u or u == 0 then return 0 end
  local cap = ECA.Caps()[key]
  if cap then
    local o = other and other[key] or 0
    return (Capped(newValue, cap, o) - Capped(oldValue, cap, o)) * u
  end
  local diff = newValue - oldValue
  if key == "DPS" and dpsScale then diff = diff * dpsScale end
  return diff * u
end

-- Capped stats from everything except the listed items.
local function OtherGear(a, b)
  local other = {}
  local totals = GearTotals()
  for k, _ in pairs(ECA.Caps()) do
    local v = totals[k] or 0
    if a then v = v - (ECA.ItemStats(a)[k] or 0) end
    if b then v = v - (ECA.ItemStats(b)[k] or 0) end
    other[k] = v
  end
  return other
end

------------------------------------------------------------------------------------------------------
-- Comparisons
------------------------------------------------------------------------------------------------------

local VERDICTS = {
  bigup = { text = "BIG UPGRADE", advice = "Recommended: equip it.", r = 0.1, g = 1, b = 0.1 },
  up = { text = "UPGRADE", advice = "Recommended: equip it.", r = 0.4, g = 1, b = 0.4 },
  side = { text = "SIDEGRADE", advice = "Not a real upgrade: about equal, pick the stats you prefer.", r = 1, g = 0.9, b = 0.2 },
  down = { text = "DOWNGRADE", advice = "Not recommended: keep what you have.", r = 1, g = 0.5, b = 0.2 },
  bigdown = { text = "BIG DOWNGRADE", advice = "Not recommended: keep what you have.", r = 1, g = 0.25, b = 0.25 },
  same = { text = "SAME STATS", advice = "Identical to what you're wearing.", r = 0.8, g = 0.8, b = 0.8 },
  none = { text = "NOTHING FOR YOUR SPEC", advice = "None of these stats count for the spec being scored. Go by the Overall lines, or score for another spec in /eca.", r = 0.8, g = 0.8, b = 0.8 },
}

local function Verdict(newScore, oldScore, empty, identical, changed)
  if identical then return VERDICTS.same end
  if changed and math.abs(newScore) < 0.05 and math.abs(oldScore) < 0.05 then return VERDICTS.none end
  local diff = newScore - oldScore
  if empty then
    if diff > 0.5 then return VERDICTS.bigup end
    return VERDICTS.side
  end
  local pct
  if oldScore > 0.5 then pct = diff / oldScore * 100 end
  if math.abs(diff) < 0.5 or (pct and math.abs(pct) < 3) then return VERDICTS.side end
  if diff > 0 then
    if not pct or pct >= 15 then return VERDICTS.bigup end
    return VERDICTS.up
  end
  if pct and pct <= -15 then return VERDICTS.bigdown end
  return VERDICTS.down
end

-- Two equipped items that would both come off (a two-hander replacing main hand and off hand).
local function Combine(a, b)
  if b.empty then return a end
  if a.empty then return b end
  local c = { name = a.name .. " + " .. b.name, r = a.r, g = a.g, b = a.b, stats = {}, enchantStats = {},
    extras = {}, speed = a.speed, kind = a.kind }
  for k, v in pairs(a.stats) do c.stats[k] = v end
  for k, v in pairs(a.enchantStats) do c.enchantStats[k] = v end
  for k, v in pairs(b.stats) do
    if k == "DPS" then v = v * 0.5 end
    c.stats[k] = (c.stats[k] or 0) + v
  end
  for k, v in pairs(b.enchantStats) do
    if k == "DPS" then v = v * 0.5 end
    c.enchantStats[k] = (c.enchantStats[k] or 0) + v
  end
  for i = 1, table.getn(a.extras) do table.insert(c.extras, a.extras[i]) end
  for i = 1, table.getn(b.extras) do table.insert(c.extras, b.extras[i]) end
  c.enchantText = a.enchantText or b.enchantText
  c.setName, c.setHave, c.setTotal = a.setName, a.setHave, a.setTotal
  if not c.setName then c.setName, c.setHave, c.setTotal = b.setName, b.setHave, b.setTotal end
  return c
end

local function SameStats(a, b)
  for k, v in pairs(a) do if (b[k] or 0) ~= v then return false end end
  for k, v in pairs(b) do if (a[k] or 0) ~= v then return false end end
  return true
end

------------------------------------------------------------------------------------------------------
-- The headline: what the swap does to your damage, the damage you take, and your healing
------------------------------------------------------------------------------------------------------

local PARRY_CLASSES = { WARRIOR = true, PALADIN = true, ROGUE = true, HUNTER = true }
local HEALING_CLASSES = { PALADIN = true, PRIEST = true, SHAMAN = true, DRUID = true }
local NO_MANA = { WARRIOR = true, ROGUE = true }

-- Auto-attack damage per second right now, and whether both hands swing.
local function CurrentDps(ranged)
  if ranged then
    local speed, lo, hi = UnitRangedDamage("player")
    if speed and speed > 0 and lo and hi then return (lo + hi) / 2 / speed, false end
    return 0, false
  end
  local lo, hi, offLo, offHi = UnitDamage("player")
  local speed, offSpeed = UnitAttackSpeed("player")
  local dps, both = 0, false
  if lo and hi and speed and speed > 0 then dps = (lo + hi) / 2 / speed end
  if offSpeed and offSpeed > 0 and offLo and offHi and offHi > 0 then
    dps = dps + (offLo + offHi) / 2 / offSpeed
    both = true
  end
  return dps, both
end

-- How much less physical damage you'd take, in percent: armor against something your own level (a
-- level 63 boss in raid mode), plus dodge, parry and what defense adds to them.
local function DamageReduction(n, diff)
  local _, armor = UnitArmor("player")
  armor = armor or 0
  local attacker = ECA.PlayerLevel()
  if attacker >= 60 and ECA.CapMode() == "raid" then attacker = 63 end
  local function FromArmor(a)
    if a < 0 then a = 0 end
    local r = a / (a + 400 + 85 * attacker)
    if r > 0.75 then r = 0.75 end
    return r
  end

  local parries = PARRY_CLASSES[ECA.class]
  local avoid = 5   -- everything misses you 5% of the time
  if GetDodgeChance then avoid = avoid + (GetDodgeChance() or 0) else avoid = avoid + 5 end
  if parries and GetParryChance then avoid = avoid + (GetParryChance() or 0) end
  local defense = diff.DEFENSE or 0
  local avoidNew = avoid + n.dodge + defense * (parries and 0.12 or 0.08)
  if parries then avoidNew = avoidNew + (diff.PARRY or 0) end
  if avoid > 95 then avoid = 95 end
  if avoidNew > 95 then avoidNew = 95 elseif avoidNew < 0 then avoidNew = 0 end

  local before = (1 - FromArmor(armor)) * (1 - avoid / 100)
  local after = (1 - FromArmor(armor + n.armor)) * (1 - avoidNew / 100) * (1 - defense * 0.0004)
  if before <= 0 then return 0 end
  return (1 - after / before) * 100
end

-- The lines of the "Overall" block: { label, text, value } with value > 0 good, < 0 bad.
local function Overall(newStats, oldStats, other, slot)
  local diff = {}
  for k, v in pairs(newStats) do diff[k] = v - (oldStats[k] or 0) end
  for k, v in pairs(oldStats) do
    if newStats[k] == nil then diff[k] = -v end
  end
  local n = ECA.DerivedNumbers(diff)
  local role = ECA.Spec().role
  local caps = ECA.Caps()
  local function CappedDiff(key)
    local new, old = newStats[key] or 0, oldStats[key] or 0
    if caps[key] then
      local o = other and other[key] or 0
      return Capped(new, caps[key], o) - Capped(old, caps[key], o)
    end
    return new - old
  end

  local lines = {}
  local function Line(label, text, value)
    if math.abs(value) < 0.05 then text, value = "no change", 0 end
    table.insert(lines, { label = label, text = text, value = value })
  end

  -- Damage from attacks: 14 attack power is 1 damage per second, weapon damage counts directly, and
  -- crit, hit and speed each add their percent on top.
  local physical = (role ~= "caster" and role ~= "healer")
  local ranged = (role == "ranged")
  local weapon = 0
  if ranged then
    weapon = diff.RDPS or 0
  elseif not ECA.Spec().feral then
    weapon = diff.DPS or 0
    if slot == 17 then weapon = weapon * 0.5 end
  end
  local base, both = CurrentDps(ranged)
  local flat = (ranged and n.rap or n.ap) / 14 * (both and 1.5 or 1) + weapon
  local pct = n.crit + CappedDiff("HIT") + (diff.HASTE or 0)
  local dps = flat + (base + flat) * pct / 100
  if physical or math.abs(dps) >= 0.05 then
    local text = ECA.Signed(dps) .. " DPS"
    if base > 0 then text = text .. " (" .. ECA.Signed(dps / base * 100) .. "%)" end
    Line("Damage", text, dps)
  end

  -- Spells: a full-coefficient spell turns 3.5 spell damage into 1 damage per second of casting.
  if role == "caster" or (role ~= "healer" and math.abs(n.spell) >= 0.5) then
    Line("Spell damage", ECA.Signed(n.spell) .. " (about " .. ECA.Signed(n.spell / 3.5) .. " DPS)", n.spell)
  end
  if role == "caster" then
    local spellPct = n.spellCrit * 0.5 + CappedDiff("SPELLHIT") + (diff.HASTE or 0)
    if math.abs(spellPct) >= 0.05 then
      Line("Spell crit, hit, speed", ECA.Signed(spellPct) .. "% damage", spellPct)
    end
  end

  local reduction = DamageReduction(n, diff)
  if role == "tank" or math.abs(reduction) >= 0.05 then
    Line("Damage reduction", ECA.Signed(reduction) .. "%", reduction)
  end

  if role == "healer" or (HEALING_CLASSES[ECA.class] and math.abs(n.healing) >= 0.5) then
    Line("Healing power", ECA.Signed(n.healing) .. " (about " .. ECA.Signed(n.healing / 3.5) .. " a second)", n.healing)
  end

  if math.abs(n.health) >= 1 then Line("Health", ECA.Signed(n.health), n.health) end
  if math.abs(n.mana) >= 1 and not NO_MANA[ECA.class] then Line("Mana", ECA.Signed(n.mana), n.mana) end
  return lines
end

-- The same swap judged purely for each role the class can fill: a paladin sees tanking, healing and
-- damage. Hit caps are left out here; they matter to the main verdict, not to a second opinion.
local function RoleVerdicts(item, newStats, oldStats, slot, empty, identical, changed)
  local roles = ECA.RoleSpecs()
  if table.getn(roles) < 2 then return {} end
  local list, best = {}, 0
  for i = 1, table.getn(roles) do
    local units = ECA.UnitsFor(roles[i].spec)
    local function Total(stats)
      local total = 0
      for k, v in pairs(stats) do
        if k == "DPS" and slot == 17 then v = v * 0.5 end
        total = total + v * (units[k] or 0)
      end
      return total
    end
    local entry = { label = roles[i].label, spec = roles[i].spec, new = Total(newStats), old = Total(oldStats) }
    if entry.new > best then best = entry.new end
    if entry.old > best then best = entry.old end
    table.insert(list, entry)
  end
  for i = 1, table.getn(list) do
    local entry = list[i]
    if entry.spec.no2H and item.kind == "TWOHAND" then
      entry.verdict, entry.text = VERDICTS.bigdown, "no: needs a shield"
    elseif changed and entry.new < best * 0.2 and entry.old < best * 0.2 then
      -- worth next to nothing to this role either way: +80% of nearly nothing isn't an upgrade
      entry.verdict = VERDICTS.none
    else
      entry.verdict = Verdict(entry.new, entry.old, empty, identical, changed)
      if entry.old > 0.5 then entry.pct = (entry.new - entry.old) / entry.old * 100 end
    end
  end
  return list
end

-- One hovered item against one equipped item (or pair).
local function Build(item, slot, label, equipped, removedA, removedB, note)
  local dpsScale = DpsScale(slot)
  local other = OtherGear(removedA, removedB)
  local newStats, oldStats = ECA.ItemStats(item), ECA.ItemStats(equipped)
  local comp = {
    slot = slot, label = label, equipped = equipped, note = note, slots = {},
    newScore = ECA.Score(newStats, other, dpsScale),
    oldScore = ECA.Score(oldStats, other, dpsScale),
    changes = {},
  }
  -- the inventory slots that would be emptied, for showing their tooltips
  if removedA and not removedA.empty then table.insert(comp.slots, removedA.slot) end
  if removedB and not removedB.empty then table.insert(comp.slots, removedB.slot) end
  comp.diff = comp.newScore - comp.oldScore
  if comp.oldScore > 0.5 then comp.pct = comp.diff / comp.oldScore * 100 end

  for i = 1, table.getn(ECA.STATS) do
    local key = ECA.STATS[i].key
    local new, old = newStats[key] or 0, oldStats[key] or 0
    if new ~= old then
      local points = Contribution(key, new, old, other, dpsScale)
      table.insert(comp.changes, { key = key, diff = new - old, new = new, old = old, points = points })
      if points > 0 and (not comp.bestGain or points > comp.bestGain.points) then
        comp.bestGain = comp.changes[table.getn(comp.changes)]
      elseif points < 0 and (not comp.worstLoss or points < comp.worstLoss.points) then
        comp.worstLoss = comp.changes[table.getn(comp.changes)]
      end
    end
  end

  local identical = (not equipped.empty) and equipped.name == item.name and SameStats(newStats, oldStats)
  comp.verdict = Verdict(comp.newScore, comp.oldScore, equipped.empty, identical, table.getn(comp.changes) > 0)
  comp.roles = RoleVerdicts(item, newStats, oldStats, slot, equipped.empty, identical, table.getn(comp.changes) > 0)
  comp.other = other
  comp.overall = Overall(newStats, oldStats, other, slot)
  return comp
end

local TWO_HAND_NOTE = "You're using a two-hander, so this takes its place and leaves the other hand empty."

-- Every comparison worth showing for the hovered item.
function ECA.Compare(item)
  local kind = item.kind
  local comps = {}
  if type(kind) == "number" then
    local eq = ECA.Equipped(kind)
    table.insert(comps, Build(item, kind, ECA.SLOT_LABEL[kind], eq, eq))
  elseif kind == "FINGER" or kind == "TRINKET" then
    local first = (kind == "FINGER") and 11 or 13
    for slot = first, first + 1 do
      local eq = ECA.Equipped(slot)
      table.insert(comps, Build(item, slot, ECA.SLOT_LABEL[slot], eq, eq))
    end
  elseif kind == "RANGED" then
    local eq = ECA.Equipped(18)
    table.insert(comps, Build(item, 18, ECA.SLOT_LABEL[18], eq, eq))
  else
    local main, off = ECA.Equipped(16), ECA.Equipped(17)
    local mainIsTwoHand = (main.kind == "TWOHAND")
    if kind == "TWOHAND" then
      if off.empty then
        table.insert(comps, Build(item, 16, ECA.SLOT_LABEL[16], main, main))
      else
        table.insert(comps, Build(item, 16, "Main Hand + Off Hand", Combine(main, off), main, off,
          "A two-hander replaces both of these."))
      end
    elseif kind == "MAINHAND" then
      table.insert(comps, Build(item, 16, ECA.SLOT_LABEL[16], main, main, nil, mainIsTwoHand and TWO_HAND_NOTE or nil))
    elseif kind == "ONEHAND" then
      table.insert(comps, Build(item, 16, ECA.SLOT_LABEL[16], main, main, nil, mainIsTwoHand and TWO_HAND_NOTE or nil))
      if (not off.empty) and off.stats.DPS then
        table.insert(comps, Build(item, 17, ECA.SLOT_LABEL[17], off, off))
      end
    else   -- OFFHAND: shields, held items, off-hand weapons
      if mainIsTwoHand then
        table.insert(comps, Build(item, 16, ECA.SLOT_LABEL[16], main, main, nil,
          "You're using a two-hander: this needs a one-handed weapon next to it, and that isn't counted here."))
      else
        table.insert(comps, Build(item, 17, ECA.SLOT_LABEL[17], off, off))
      end
    end
  end

  -- With two candidate slots, say which one to swap.
  if table.getn(comps) == 2 then
    local best = comps[1]
    if comps[2].diff > best.diff then best = comps[2] end
    comps.best = best
  end
  return comps
end

-- Score of one equipped slot, judged against the rest of the gear.
function ECA.SlotScore(slot)
  local eq = ECA.Equipped(slot)
  if eq.empty then return 0 end
  return ECA.Score(ECA.ItemStats(eq), OtherGear(eq), DpsScale(slot))
end

function ECA.TotalScore()
  local total = 0
  for i = 1, table.getn(ECA.GEAR_SLOTS) do
    total = total + ECA.SlotScore(ECA.GEAR_SLOTS[i])
  end
  return total
end

-- Where the capped stats stand, for the detailed view: "Hit 6% of 9%".
function ECA.CapStatus()
  local lines = {}
  local totals = GearTotals()
  for key, cap in pairs(ECA.Caps()) do
    local info = ECA.STAT_BY_KEY[key]
    local unit = info.pct and "%" or ""
    table.insert(lines, info.name .. ": " .. ECA.Num(totals[key] or 0) .. unit .. " from gear, cap " ..
      ECA.Num(cap.cap) .. unit)
  end
  return lines
end

------------------------------------------------------------------------------------------------------
-- /eca gear and the character window
------------------------------------------------------------------------------------------------------

function ECA.PrintGear()
  ECA.Print("What you have equipped, scored as |cffffd100" .. ECA.SpecLabel() .. "|r:")
  for i = 1, table.getn(ECA.GEAR_SLOTS) do
    local slot = ECA.GEAR_SLOTS[i]
    local eq = ECA.Equipped(slot)
    local label = "|cff9d9d9d" .. ECA.SLOT_LABEL[slot] .. ":|r "
    if eq.empty then
      DEFAULT_CHAT_FRAME:AddMessage("  " .. label .. "|cff9d9d9d(empty)|r")
    else
      DEFAULT_CHAT_FRAME:AddMessage("  " .. label .. (eq.link or eq.name) .. "  |cffffd100" ..
        ECA.Num(ECA.SlotScore(slot)) .. "|r")
    end
  end
  DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100Total gear score: " .. ECA.Num(ECA.TotalScore()) .. "|r")
  local caps = ECA.CapStatus()
  for i = 1, table.getn(caps) do DEFAULT_CHAT_FRAME:AddMessage("  |cff9d9d9d" .. caps[i] .. "|r") end
end

local charText

function ECA.SetupCharText()
  if charText or not CharacterModelFrame then return end
  local holder = CreateFrame("Frame", nil, CharacterModelFrame)
  holder:SetAllPoints(CharacterModelFrame)
  charText = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  charText:SetPoint("BOTTOM", holder, "BOTTOM", 0, 6)
  holder:SetScript("OnShow", function() ECA.UpdateCharText() end)
end

function ECA.UpdateCharText()
  if not charText or not ECA.char then return end
  if not ECA.db.showCharScore or not ECA.db.enabled then
    charText:SetText("")
    return
  end
  if not CharacterModelFrame:IsVisible() then return end
  local ok = ECA.Safe(function()
    charText:SetText("Gear score " .. ECA.Num(ECA.TotalScore()) .. "  |cff9d9d9d" .. ECA.SpecShort() .. "|r")
  end)
  if not ok then charText:SetText("") end
end
