-- Equip Compare Adv: saved settings, events and the /eca command.
-- Settings are kept for the whole account; the spec, custom stat weights and extra hit are per character.

EquipCompareAdv = {}
local ECA = EquipCompareAdv
ECA.VERSION = "1.3.0"

local GOLD, GREY, WHITE, RED, END = "|cffffd100", "|cff9d9d9d", "|cffffffff", "|cffff4040", "|r"

local DEFAULTS = {
  enabled = true,
  shiftOnly = false,       -- only show the comparison while Shift is held
  detail = 2,              -- 1 compact, 2 normal, 3 detailed (holding Alt always shows detailed)
  showEquipped = true,     -- the tooltip of the equipped item, next to the hovered one
  showPoints = true,       -- score points next to each stat change
  showFit = true,          -- the "made for" line: role and classes the item suits
  showRoles = true,        -- a verdict for each role the class can fill (tanking, healing, damage)
  showCharScore = true,    -- total gear score on the character window
  ignoreEnchants = false,  -- compare bare items, leaving enchants out
  levelingMix = true,      -- below 60, healers and tanks also count their class's damage stats
  capMode = "auto",        -- hit caps: auto / raid / leveling / off
}

ECA.DETAIL_NAMES = { "Compact", "Normal", "Detailed" }
ECA.CAP_MODES = { "auto", "raid", "leveling", "off" }
ECA.CAP_SHORT = { auto = "Auto", raid = "Raid", leveling = "Leveling", off = "Off" }
ECA.CAP_NAMES = { auto = "Auto (by level)", raid = "Raid bosses", leveling = "Dungeons and leveling", off = "Ignore caps" }

function ECA.Print(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Equip Compare Adv:|r " .. msg)
  end
end

-- Run one of the addon's own functions without letting an error break the game's tooltips. The first
-- error is printed once; /eca debug shows the last one.
function ECA.Safe(fn, a, b, c)
  local ok, err = pcall(fn, a, b, c)
  if not ok then
    ECA.lastError = tostring(err)
    if not ECA.errorShown then
      ECA.errorShown = true
      ECA.Print(RED .. "something went wrong: " .. END .. tostring(err))
      ECA.Print("Please report it. " .. GOLD .. "/eca off" .. END .. " turns the addon off until then.")
    end
  end
  return ok
end

local function InitDB()
  if type(EquipCompareAdvDB) ~= "table" then EquipCompareAdvDB = {} end
  local db = EquipCompareAdvDB
  for k, v in pairs(DEFAULTS) do
    if db[k] == nil then db[k] = v end
  end
  if type(db.chars) ~= "table" then db.chars = {} end
  ECA.db = db
end

local function InitChar()
  if not ECA.db then InitDB() end
  local realm = (GetRealmName and GetRealmName()) or "realm"
  local key = (UnitName("player") or "player") .. "-" .. realm
  local chars = ECA.db.chars
  if type(chars[key]) ~= "table" then chars[key] = {} end
  local char = chars[key]
  if type(char.spec) ~= "string" then char.spec = "auto" end
  if type(char.custom) ~= "table" then char.custom = {} end
  if type(char.extraHit) ~= "number" then char.extraHit = 0 end
  if type(char.extraSpellHit) ~= "number" then char.extraSpellHit = 0 end
  ECA.char = char
  local _, class = UnitClass("player")
  ECA.class = class or "WARRIOR"
end

-- Anything that changes how items are scored goes through here, so every cached number is rebuilt.
function ECA.SettingsChanged()
  if ECA.InvalidateProfiles then ECA.InvalidateProfiles() end
  if ECA.ClearGearCache then ECA.ClearGearCache() end
  if ECA.RefreshPanels then ECA.RefreshPanels() end
  if ECA.UpdateCharText then ECA.UpdateCharText() end
  if ECA.RefreshOptions then ECA.RefreshOptions() end
end

local function SetSpec(arg)
  arg = string.lower(arg or "")
  if arg == "" or arg == "auto" then
    ECA.char.spec = "auto"
  else
    local found
    local specs = ECA.SPECS[ECA.class] or {}
    for i = 1, table.getn(specs) do
      local s = specs[i]
      if s.key == arg or string.lower(s.name) == arg then found = s.key end
    end
    if not found then
      local names = "auto"
      for i = 1, table.getn(specs) do names = names .. ", " .. specs[i].key end
      ECA.Print("Unknown spec. Choose one of: " .. names)
      return
    end
    ECA.char.spec = found
  end
  ECA.SettingsChanged()
  ECA.Print("Scoring as " .. GOLD .. ECA.SpecLabel() .. END .. ".")
end

local function SetWeight(rest)
  local _, _, stat, value = string.find(rest or "", "^(%S+)%s+(%S+)$")
  if rest == "reset" then
    ECA.ResetWeights()
    ECA.Print("Stat weights for " .. ECA.SpecLabel() .. " are back to the defaults.")
    return
  end
  stat = stat and string.upper(stat)
  local number = tonumber(value)
  if not stat or not number or not ECA.STAT_BY_KEY[stat] then
    ECA.Print("Use: /eca weight <STAT> <points>, for example /eca weight CRIT 30. /eca weights lists them.")
    return
  end
  ECA.SetWeight(stat, number)
  ECA.Print(ECA.STAT_BY_KEY[stat].name .. " is now worth " .. number .. " per point for " .. ECA.SpecLabel() .. ".")
end

local function ListWeights()
  local weights = ECA.Weights()
  ECA.Print("Stat weights for " .. GOLD .. ECA.SpecLabel() .. END .. " (points per 1 of the stat):")
  local line = ""
  for i = 1, table.getn(ECA.STATS) do
    local s = ECA.STATS[i]
    local w = weights[s.key]
    if w and w ~= 0 then
      line = line .. s.key .. "=" .. ECA.FmtWeight(w) .. "  "
      if string.len(line) > 90 then
        DEFAULT_CHAT_FRAME:AddMessage("  " .. line)
        line = ""
      end
    end
  end
  if line ~= "" then DEFAULT_CHAT_FRAME:AddMessage("  " .. line) end
end

local function Help()
  ECA.Print("v" .. ECA.VERSION .. ". Hover any item you could equip to compare it with what you're wearing.")
  local lines = {
    "/eca" .. GREY .. "  open the options window" .. END,
    "/eca on | off" .. GREY .. "  switch the comparison on or off" .. END,
    "/eca spec auto | <name>" .. GREY .. "  what to score for (auto follows your talents)" .. END,
    "/eca detail 1 | 2 | 3" .. GREY .. "  compact, normal or detailed (hold Alt for detailed any time)" .. END,
    "/eca equipped" .. GREY .. "  show or hide the tooltip of the item you have equipped" .. END,
    "/eca shift" .. GREY .. "  only show while Shift is held" .. END,
    "/eca caps auto | raid | leveling | off" .. GREY .. "  how hit caps are judged" .. END,
    "/eca roles" .. GREY .. "  show or hide the verdict for each role your class can fill" .. END,
    "/eca leveling" .. GREY .. "  below 60, healers and tanks also count damage stats (on by default)" .. END,
    "/eca enchants" .. GREY .. "  count or ignore enchants" .. END,
    "/eca gear" .. GREY .. "  list what you have equipped, with scores" .. END,
    "/eca weights" .. GREY .. "  list the stat weights;  " .. END .. "/eca weight <STAT> <n>" .. GREY .. "  change one;  " .. END .. "/eca weight reset",
    "/eca hit <n>" .. GREY .. " and " .. END .. "/eca spellhit <n>" .. GREY .. "  extra hit % from buffs or talents the addon can't see" .. END,
  }
  for i = 1, table.getn(lines) do DEFAULT_CHAT_FRAME:AddMessage("  " .. GOLD .. lines[i]) end
end

local function Slash(msg)
  if not ECA.char then return end   -- typed before the character finished loading
  local _, _, cmd, rest = string.find(msg or "", "^%s*(%S*)%s*(.-)%s*$")
  cmd = string.lower(cmd or "")
  if cmd == "" or cmd == "options" or cmd == "config" then
    ECA.ToggleOptions()
  elseif cmd == "help" or cmd == "?" then
    Help()
  elseif cmd == "on" or cmd == "off" then
    ECA.db.enabled = (cmd == "on")
    ECA.SettingsChanged()
    ECA.Print("Comparison is " .. (ECA.db.enabled and "on." or "off."))
  elseif cmd == "spec" then
    SetSpec(rest)
  elseif cmd == "detail" then
    local n = tonumber(rest)
    if n and n >= 1 and n <= 3 then
      ECA.db.detail = math.floor(n)
      ECA.SettingsChanged()
      ECA.Print("Detail: " .. ECA.DETAIL_NAMES[ECA.db.detail] .. ".")
    else
      ECA.Print("Use /eca detail 1, 2 or 3.")
    end
  elseif cmd == "shift" then
    ECA.db.shiftOnly = not ECA.db.shiftOnly
    ECA.SettingsChanged()
    ECA.Print(ECA.db.shiftOnly and "Shown only while Shift is held." or "Shown on every hover.")
  elseif cmd == "equipped" then
    ECA.db.showEquipped = not ECA.db.showEquipped
    ECA.SettingsChanged()
    ECA.Print(ECA.db.showEquipped and "The equipped item's tooltip is shown next to the one you hover." or "The equipped item's tooltip is hidden.")
  elseif cmd == "caps" then
    rest = string.lower(rest or "")
    if ECA.CAP_NAMES[rest] then
      ECA.db.capMode = rest
      ECA.SettingsChanged()
      ECA.Print("Hit caps: " .. ECA.CAP_NAMES[rest] .. ".")
    else
      ECA.Print("Use /eca caps auto, raid, leveling or off.")
    end
  elseif cmd == "roles" then
    ECA.db.showRoles = not ECA.db.showRoles
    ECA.SettingsChanged()
    ECA.Print(ECA.db.showRoles and "A verdict for each role your class can fill is shown." or "The verdicts by role are hidden.")
  elseif cmd == "leveling" then
    ECA.db.levelingMix = not ECA.db.levelingMix
    ECA.SettingsChanged()
    ECA.Print(ECA.db.levelingMix and "Below level 60, healers and tanks also count their class's damage stats." or
      "Healers and tanks are scored purely for healing and tanking at every level.")
  elseif cmd == "enchants" then
    ECA.db.ignoreEnchants = not ECA.db.ignoreEnchants
    ECA.SettingsChanged()
    ECA.Print(ECA.db.ignoreEnchants and "Enchants are ignored: bare items are compared." or "Enchants are counted.")
  elseif cmd == "gear" then
    ECA.PrintGear()
  elseif cmd == "weights" then
    ListWeights()
  elseif cmd == "weight" then
    SetWeight(rest)
  elseif cmd == "hit" or cmd == "spellhit" then
    local n = tonumber(rest)
    if not n then
      ECA.Print("Use /eca " .. cmd .. " <percent>, for example /eca " .. cmd .. " 3.")
    else
      if cmd == "hit" then ECA.char.extraHit = n else ECA.char.extraSpellHit = n end
      ECA.SettingsChanged()
      ECA.Print("Extra " .. (cmd == "hit" and "melee and ranged" or "spell") .. " hit set to " .. n .. "%.")
    end
  elseif cmd == "debug" then
    ECA.Print("Last error: " .. (ECA.lastError or "none"))
  else
    Help()
  end
end

SLASH_EQUIPCOMPAREADV1 = "/eca"
SLASH_EQUIPCOMPAREADV2 = "/equipcompare"
SlashCmdList["EQUIPCOMPAREADV"] = Slash

local events = CreateFrame("Frame")
events:RegisterEvent("VARIABLES_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:RegisterEvent("CHARACTER_POINTS_CHANGED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    InitDB()
  elseif event == "PLAYER_LOGIN" then
    InitChar()
    ECA.Safe(ECA.InstallHooks)
    ECA.Safe(ECA.SetupCharText)
  elseif not ECA.char then
    return
  elseif event == "PLAYER_ENTERING_WORLD" then
    ECA.SettingsChanged()
    if not ECA.greeted then
      ECA.greeted = true
      ECA.Print("v" .. ECA.VERSION .. " by |cffabd473stealthzi|r loaded, scoring as " .. GOLD .. ECA.SpecLabel() .. END ..
        ". " .. GOLD .. "/eca" .. END .. " for options.")
    end
  elseif event == "UNIT_INVENTORY_CHANGED" then
    if arg1 == "player" then
      ECA.ClearGearCache()
      ECA.RefreshPanels()
      ECA.UpdateCharText()
      if ECA.RefreshOptions then ECA.RefreshOptions() end
    end
  else
    -- talents or level changed
    ECA.SettingsChanged()
  end
end)
