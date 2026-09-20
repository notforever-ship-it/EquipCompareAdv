-- Equip Compare Adv: the /eca window, and the stat weights window behind its "Stat weights" button.

local ECA = EquipCompareAdv

local GOLD, GREY, WHITE, END = "|cffffd100", "|cff9d9d9d", "|cffffffff", "|r"
local WIDTH, HEIGHT = 380, 578

local frame, scoringText, scoreText, detailButton, capsButton
local specButtons, checks = {}, {}

local weightsFrame, weightsTitle, weightsScroll, hitBox, spellHitBox, talentText
local weightRows = {}
local NUM_ROWS, ROW_HEIGHT = 12, 24

local CHECKS = {
  { key = "enabled", label = "Compare items when I hover them",
    tip = "The panel next to item tooltips. Turn it off to keep the addon quiet without disabling it." },
  { key = "showEquipped", label = "Show the tooltip of what I have equipped",
    tip = "The equipped item's own tooltip sits between the item you hover and the comparison panel, like the game's compare tooltips. Rings, trinkets and weapons can show two." },
  { key = "shiftOnly", label = "Only while I hold Shift",
    tip = "Keeps tooltips clean until you ask for the comparison by holding Shift." },
  { key = "showPoints", label = "Show score points next to each stat",
    tip = "How much each gained or lost stat moves the score, so you can see why the verdict came out that way." },
  { key = "showFit", label = "Show who the item is made for",
    tip = "Tank, DPS or healer, the classes and specs that get the most out of the item's stats, and how well it fits your own spec." },
  { key = "showRoles", label = "Show a verdict for each role (tank, healer, damage)",
    tip = "Under the main verdict, the same swap judged purely for tanking, for healing and for damage, whichever of those your class can do. Handy when you tank in one set and quest in another, or your talents don't match how you play." },
  { key = "showCharScore", label = "Show my gear score on the character window",
    tip = "The total score of everything you're wearing, under your character model." },
  { key = "levelingMix", label = "While leveling, healers and tanks count damage too",
    tip = "A level 11 healer still has to kill things. Below level 60, healing and tanking specs get their class's damage spec mixed into the score: nearly all of it at level 10, fading to none at 60. The panel header shows '+ leveling' while it applies." },
  { key = "ignoreEnchants", label = "Ignore enchants (compare bare items)",
    tip = "Off: you see what really changes the moment you swap, including the enchant you'd lose.\n\nOn: both items are judged without enchants, which is fairer when you plan to enchant the new one too." },
}

-- The 1.12 dialog background art is partly see-through; a solid layer underneath keeps text readable.
local function Opaque(f)
  local solid = f:CreateTexture(nil, "BACKGROUND")
  solid:SetTexture(0.05, 0.05, 0.07, 1)
  solid:SetPoint("TOPLEFT", f, "TOPLEFT", 11, -11)
  solid:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -11, 11)
end

local function Explain(widget, title, text)
  widget:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(title)
    GameTooltip:AddLine(text, 1, 1, 1, 1)
    GameTooltip:Show()
  end)
  widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Window(name, width, height)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetWidth(width)
  f:SetHeight(height)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  Opaque(f)
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:Hide()
  table.insert(UISpecialFrames, name)
  local close = CreateFrame("Button", name .. "Close", f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
  return f
end

local function Button(name, parent, width, text)
  local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
  b:SetWidth(width)
  b:SetHeight(22)
  b:SetText(text)
  return b
end

local function NextIn(list, current)
  for i = 1, table.getn(list) do
    if list[i] == current then
      if i == table.getn(list) then return list[1] end
      return list[i + 1]
    end
  end
  return list[1]
end

------------------------------------------------------------------------------------------------------
-- Stat weights window
------------------------------------------------------------------------------------------------------

local function CommitWeight(box)
  local key = box.statKey
  if not key or not ECA.char then return end
  local current = ECA.Weights()[key] or 0
  local number = tonumber(box:GetText())
  if number and math.abs(number - current) > 0.0001 then
    ECA.SetWeight(key, number)
  else
    box:SetText(ECA.FmtWeight(current))
  end
end

local function CommitHit(box, field)
  if not ECA.char then return end
  local number = tonumber(box:GetText())
  if number and number ~= ECA.char[field] then
    ECA.char[field] = number
    ECA.SettingsChanged()
  else
    box:SetText(ECA.FmtWeight(ECA.char[field]))
  end
end

local function UpdateWeightRows()
  if not weightsFrame or not weightsFrame:IsShown() then return end
  local total = table.getn(ECA.STATS)
  FauxScrollFrame_Update(weightsScroll, total, NUM_ROWS, ROW_HEIGHT)
  local offset = FauxScrollFrame_GetOffset(weightsScroll)
  local weights, defaults, units = ECA.Weights(), ECA.DefaultWeights(), ECA.Units()

  weightsTitle:SetText(GREY .. "for " .. END .. GOLD .. ECA.SpecLabel() .. END)
  for i = 1, NUM_ROWS do
    local row = weightRows[i]
    local stat = ECA.STATS[i + offset]
    if stat then
      local w, d = weights[stat.key] or 0, defaults[stat.key] or 0
      local changed = math.abs(w - d) > 0.0001
      row.label:SetText((changed and GOLD or WHITE) .. stat.name .. END)
      row.box.statKey = stat.key
      row.box:SetText(ECA.FmtWeight(w))
      local note = ""
      if changed then note = "default " .. ECA.FmtWeight(d) end
      local u = units[stat.key] or 0
      if math.abs(u - w) > 0.0001 then
        -- Strength and friends: their worth comes from what they convert into
        note = "= " .. ECA.FmtWeight(u) .. " a point"
      end
      row.note:SetText(GREY .. note .. END)
      row.label:Show()
      row.box:Show()
      row.note:Show()
    else
      row.box.statKey = nil
      row.label:Hide()
      row.box:Hide()
      row.note:Hide()
    end
  end

  local melee, spell = ECA.TalentHit()
  talentText:SetText(GREY .. "Hit from your talents, already counted: " .. melee .. "% melee/ranged, " .. spell ..
    "% spell. Hit caps: " .. ECA.CAP_NAMES[ECA.db.capMode] .. "." .. END)
  hitBox:SetText(ECA.FmtWeight(ECA.char.extraHit))
  spellHitBox:SetText(ECA.FmtWeight(ECA.char.extraSpellHit))
end

local function BuildWeights()
  local f = Window("EquipCompareAdvWeights", 380, 520)
  weightsFrame = f
  f:SetPoint("CENTER", UIParent, "CENTER", 200, 20)
  f:SetScript("OnShow", function() UpdateWeightRows() end)

  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -18)
  title:SetText("Stat weights")

  weightsTitle = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  weightsTitle:SetPoint("TOP", title, "BOTTOM", 0, -4)

  local intro = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  intro:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -58)
  intro:SetWidth(332)
  intro:SetJustifyH("LEFT")
  intro:SetText("Score points for 1 of each stat. Type a number and press Enter. Strength, Agility, Stamina, " ..
    "Intellect and Spirit are worth what they turn into for your class (shown on the right); a number " ..
    "typed there is added on top.")

  weightsScroll = CreateFrame("ScrollFrame", "EquipCompareAdvWeightsScroll", f, "FauxScrollFrameTemplate")
  weightsScroll:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -112)
  weightsScroll:SetWidth(312)
  weightsScroll:SetHeight(NUM_ROWS * ROW_HEIGHT)
  weightsScroll:SetScript("OnVerticalScroll", function()
    for i = 1, NUM_ROWS do weightRows[i].box:ClearFocus() end
    FauxScrollFrame_OnVerticalScroll(ROW_HEIGHT, UpdateWeightRows)
  end)

  for i = 1, NUM_ROWS do
    local y = -112 - (i - 1) * ROW_HEIGHT
    local label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", f, "TOPLEFT", 26, y - 6)
    label:SetWidth(150)
    label:SetJustifyH("LEFT")

    local box = CreateFrame("EditBox", "EquipCompareAdvWeightBox" .. i, f, "InputBoxTemplate")
    box:SetWidth(52)
    box:SetHeight(18)
    box:SetPoint("TOPLEFT", f, "TOPLEFT", 186, y - 2)
    box:SetAutoFocus(false)
    box:SetFrameLevel(weightsScroll:GetFrameLevel() + 2)
    box:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    box:SetScript("OnEscapePressed", function()
      if this.statKey then this:SetText(ECA.FmtWeight(ECA.Weights()[this.statKey] or 0)) end
      this:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function() CommitWeight(this) end)

    local note = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", f, "TOPLEFT", 246, y - 6)
    note:SetWidth(90)
    note:SetJustifyH("LEFT")

    weightRows[i] = { label = label, box = box, note = note }
  end

  local y = -112 - NUM_ROWS * ROW_HEIGHT - 12
  local hitLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hitLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 26, y - 4)
  hitLabel:SetText("Extra hit % I get elsewhere:   melee")

  hitBox = CreateFrame("EditBox", "EquipCompareAdvHitBox", f, "InputBoxTemplate")
  hitBox:SetWidth(34)
  hitBox:SetHeight(18)
  hitBox:SetPoint("TOPLEFT", f, "TOPLEFT", 218, y)
  hitBox:SetAutoFocus(false)
  hitBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  hitBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  hitBox:SetScript("OnEditFocusLost", function() CommitHit(this, "extraHit") end)
  Explain(hitBox, "Extra melee and ranged hit", "Hit % from buffs, racials or talents the addon can't see. " ..
    "It counts towards the hit cap, so hit on gear is worth less once you're close to it.")

  local spellLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  spellLabel:SetPoint("LEFT", hitBox, "RIGHT", 10, 0)
  spellLabel:SetText("spell")

  spellHitBox = CreateFrame("EditBox", "EquipCompareAdvSpellHitBox", f, "InputBoxTemplate")
  spellHitBox:SetWidth(34)
  spellHitBox:SetHeight(18)
  spellHitBox:SetPoint("LEFT", spellLabel, "RIGHT", 10, 0)
  spellHitBox:SetAutoFocus(false)
  spellHitBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  spellHitBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  spellHitBox:SetScript("OnEditFocusLost", function() CommitHit(this, "extraSpellHit") end)
  Explain(spellHitBox, "Extra spell hit", "Spell hit % from buffs or talents the addon can't see.")

  talentText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  talentText:SetPoint("TOPLEFT", f, "TOPLEFT", 26, y - 28)
  talentText:SetWidth(330)
  talentText:SetJustifyH("LEFT")

  local reset = Button("EquipCompareAdvWeightsReset", f, 150, "Back to defaults")
  reset:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 20)
  reset:SetScript("OnClick", function()
    for i = 1, NUM_ROWS do weightRows[i].box.statKey = nil end   -- nothing half-typed gets saved
    ECA.ResetWeights()
  end)
  Explain(reset, "Back to defaults", "Forget every change you made to this spec's weights.")

  local done = Button("EquipCompareAdvWeightsDone", f, 80, "Done")
  done:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 20)
  done:SetScript("OnClick", function() weightsFrame:Hide() end)
end

function ECA.ToggleWeights()
  if not weightsFrame then BuildWeights() end
  if weightsFrame:IsShown() then weightsFrame:Hide() else weightsFrame:Show() end
end

------------------------------------------------------------------------------------------------------
-- Main window
------------------------------------------------------------------------------------------------------

local function Build()
  frame = Window("EquipCompareAdvOptions", WIDTH, HEIGHT)
  frame:SetPoint("CENTER", UIParent, "CENTER", -120, 30)
  frame:SetScript("OnShow", function() ECA.RefreshOptions() end)

  local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", frame, "TOP", 0, -18)
  title:SetText("Equip Compare Adv")

  scoringText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  scoringText:SetPoint("TOP", title, "BOTTOM", 0, -6)

  scoreText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  scoreText:SetPoint("TOP", scoringText, "BOTTOM", 0, -4)

  local specHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  specHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -84)
  specHeader:SetText("Score items for")

  -- "Auto" plus every spec of this class, three to a row
  local specs = ECA.SPECS[ECA.class]
  local entries = { { key = "auto", name = "Auto (talents)" } }
  for i = 1, table.getn(specs) do table.insert(entries, specs[i]) end
  for i = 1, table.getn(entries) do
    local b = Button("EquipCompareAdvSpec" .. i, frame, 108, entries[i].name)
    local col = math.mod(i - 1, 3)
    local rowIndex = math.floor((i - 1) / 3)
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", 20 + col * 116, -104 - rowIndex * 26)
    b.specKey = entries[i].key
    b:SetScript("OnClick", function()
      ECA.char.spec = this.specKey
      ECA.SettingsChanged()
    end)
    if entries[i].key == "auto" then
      Explain(b, "Auto", "Follows your talents: the tree with the most points decides the spec.")
    end
    specButtons[i] = b
  end
  local y = -104 - (math.floor((table.getn(entries) - 1) / 3) + 1) * 26 - 12

  for i = 1, table.getn(CHECKS) do
    local c = CHECKS[i]
    local name = "EquipCompareAdvCheck" .. c.key
    local check = CreateFrame("CheckButton", name, frame, "UICheckButtonTemplate")
    check:SetWidth(24)
    check:SetHeight(24)
    check:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, y)
    local text = getglobal(name .. "Text")
    if text then text:SetText(c.label) end
    check.key = c.key
    Explain(check, c.label, c.tip)
    check:SetScript("OnClick", function()
      ECA.db[this.key] = this:GetChecked() and true or false
      ECA.SettingsChanged()
    end)
    checks[i] = check
    y = y - 26
  end

  y = y - 10
  detailButton = Button("EquipCompareAdvDetail", frame, 164, "")
  detailButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, y)
  detailButton:SetScript("OnClick", function()
    ECA.db.detail = ECA.db.detail + 1
    if ECA.db.detail > 3 then ECA.db.detail = 1 end
    ECA.SettingsChanged()
  end)
  Explain(detailButton, "How much the panel shows", "Compact: scores and the verdict.\nNormal: every stat gained " ..
    "and lost, warnings, and who the item is made for.\nDetailed: also before and after numbers, what the " ..
    "change does in practice, and where you stand on hit caps.\n\nHolding Alt shows Detailed at any time.")

  capsButton = Button("EquipCompareAdvCaps", frame, 164, "")
  capsButton:SetPoint("LEFT", detailButton, "RIGHT", 12, 0)
  capsButton:SetScript("OnClick", function()
    ECA.db.capMode = NextIn(ECA.CAP_MODES, ECA.db.capMode)
    ECA.SettingsChanged()
  end)
  Explain(capsButton, "Hit caps", "Hit on gear stops helping once you can't miss.\n\nRaid bosses: 9% melee and " ..
    "ranged, 16% spell.\nDungeons and leveling: 5% and 3%.\nAuto picks raid at level 60.\n\nHit from your " ..
    "talents is counted for you. Tanks in raid mode also stop valuing defense as much past 440.")

  local weightsButton = Button("EquipCompareAdvWeightsButton", frame, 110, "Stat weights")
  weightsButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 40)
  weightsButton:SetScript("OnClick", function() ECA.ToggleWeights() end)
  Explain(weightsButton, "Stat weights", "See and change what every stat is worth to your spec, and tell the " ..
    "addon about hit you get from elsewhere.")

  local gearButton = Button("EquipCompareAdvGearButton", frame, 110, "List my gear")
  gearButton:SetPoint("LEFT", weightsButton, "RIGHT", 8, 0)
  gearButton:SetScript("OnClick", function() ECA.PrintGear() end)
  Explain(gearButton, "List my gear", "Prints everything you have equipped to chat, with each item's score.")

  local done = Button("EquipCompareAdvDone", frame, 80, "Done")
  done:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 40)
  done:SetScript("OnClick", function() frame:Hide() end)

  local credit = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  credit:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)
  credit:SetText(GREY .. "Made by " .. END .. "|cffabd473stealthzi" .. END .. GREY .. "   v" .. ECA.VERSION .. END)
end

function ECA.RefreshOptions()
  if not ECA.char then return end
  if frame and frame:IsShown() then
    scoringText:SetText(GREY .. "Scoring as " .. END .. GOLD .. ECA.SpecLabel() .. END)
    scoreText:SetText(GREY .. "Your gear score: " .. END .. WHITE .. ECA.Num(ECA.TotalScore()) .. END)
    for i = 1, table.getn(specButtons) do
      local b = specButtons[i]
      if b.specKey == ECA.char.spec then b:LockHighlight() else b:UnlockHighlight() end
    end
    for i = 1, table.getn(checks) do
      checks[i]:SetChecked(ECA.db[checks[i].key] and 1 or nil)
    end
    detailButton:SetText("Detail: " .. ECA.DETAIL_NAMES[ECA.db.detail])
    capsButton:SetText("Hit caps: " .. ECA.CAP_SHORT[ECA.db.capMode])
  end
  UpdateWeightRows()
end

function ECA.ToggleOptions()
  if not frame then Build() end
  if frame:IsShown() then frame:Hide() else frame:Show() end
end
