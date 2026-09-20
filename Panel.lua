-- Equip Compare Adv: the comparison panel that sits next to an item tooltip.
-- The panel follows GameTooltip (bags, loot, vendors, quests, the auction house...) and ItemRefTooltip
-- (links clicked in chat). The game's own tooltips are never changed, so other tooltip addons keep working.

local ECA = EquipCompareAdv

local GREY = "|cff9d9d9d"
local END = "|r"

local states = {}   -- tooltip name -> { tooltip, panel, equippedSlot, sig, shift, alt }

local SET_METHODS = { "SetBagItem", "SetInventoryItem", "SetLootItem", "SetLootRollItem", "SetMerchantItem",
  "SetBuybackItem", "SetQuestItem", "SetQuestLogItem", "SetAuctionItem", "SetAuctionSellItem",
  "SetTradeSkillItem", "SetCraftItem", "SetTradePlayerItem", "SetTradeTargetItem", "SetInboxItem",
  "SetSendMailItem", "SetHyperlink" }

------------------------------------------------------------------------------------------------------
-- The panel frame
------------------------------------------------------------------------------------------------------

local function GetPanel(state)
  if not state.panel then
    local panel = CreateFrame("GameTooltip", "EquipCompareAdvPanel" .. state.index, UIParent, "GameTooltipTemplate")
    panel:SetFrameStrata("TOOLTIP")
    if panel.SetClampedToScreen then panel:SetClampedToScreen(true) end
    state.panel = panel
  end
  return state.panel
end

local function HidePanel(state)
  if state.panel then state.panel:Hide() end
end

-- Beside the tooltip, on whichever side has room; growing upwards when the tooltip sits low on screen.
-- When the game's own compare tooltips are up (the auction house), they own the sides, so the panel
-- goes underneath instead, or on top when there's no room below.
local function Anchor(state, force)
  local panel, tooltip = state.panel, state.tooltip
  if not panel or not panel:IsShown() then return end
  local side, vert = "LEFT", "TOP"
  if ShoppingTooltip1 and ShoppingTooltip1:IsVisible() then
    local bottom = tooltip:GetBottom()
    side = "UNDER"
    if bottom and bottom * (tooltip:GetScale() or 1) < (panel:GetHeight() or 0) * (panel:GetScale() or 1) then side = "OVER" end
    if force or panel.side ~= side then
      panel.side, panel.vert = side, nil
      panel:ClearAllPoints()
      if side == "UNDER" then
        panel:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 0, 0)
      else
        panel:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", 0, 0)
      end
    end
    return
  end
  local left, right, top = tooltip:GetLeft(), tooltip:GetRight(), tooltip:GetTop()
  if left and right and top then
    local scale = tooltip:GetScale() or 1
    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
    local width = (panel:GetWidth() or 0) * (panel:GetScale() or 1)
    local roomRight = screenW - right * scale
    local roomLeft = left * scale
    if roomRight >= width or roomRight > roomLeft then side = "RIGHT" end
    if top * scale < screenH * 0.45 then vert = "BOTTOM" end
  end
  if force or panel.side ~= side or panel.vert ~= vert then
    panel.side, panel.vert = side, vert
    panel:ClearAllPoints()
    if side == "RIGHT" then
      panel:SetPoint(vert .. "LEFT", tooltip, vert .. "RIGHT", 0, 0)
    else
      panel:SetPoint(vert .. "RIGHT", tooltip, vert .. "LEFT", 0, 0)
    end
  end
end

------------------------------------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------------------------------------

local function NameColor(item)
  if item.r then return item.r, item.g, item.b end
  return 1, 1, 1
end

local function Shorten(text, max)
  if string.len(text) > max then return string.sub(text, 1, max - 3) .. "..." end
  return text
end

local function ScoreText(score)
  return "score " .. ECA.Num(score)
end

-- "Made for" lines: the role, the classes and specs that get the most out of it, and your own spec.
local function AddFitLines(panel, item)
  local fits = ECA.Fits(item)
  if not fits or table.getn(fits) == 0 then return end
  local top = fits[1].raw
  if top < 0.3 then
    panel:AddLine("Made for: no clear role", 0.62, 0.62, 0.62)
    return
  end

  -- roles within a whisker of the best one
  local roles, seenRole = "", {}
  local count = 0
  for i = 1, table.getn(fits) do
    local f = fits[i]
    if f.raw >= top * 0.92 and not seenRole[f.role] and count < 2 then
      seenRole[f.role] = true
      count = count + 1
      if roles ~= "" then roles = roles .. " / " end
      roles = roles .. ECA.ROLE_NAMES[f.role]
    end
  end
  panel:AddDoubleLine("Made for:", roles, 0.62, 0.62, 0.62, 1, 0.82, 0)

  -- best spec of up to three classes
  local seenClass, shown = {}, 0
  for i = 1, table.getn(fits) do
    local f = fits[i]
    if not seenClass[f.class] and shown < 3 and f.raw >= top * 0.6 then
      seenClass[f.class] = true
      shown = shown + 1
      local who = ECA.CLASS_COLORS[f.class] .. ECA.CLASS_NAMES[f.class] .. END
      if f.spec.name ~= ECA.CLASS_NAMES[f.class] then who = who .. GREY .. " " .. f.spec.name .. END end
      panel:AddDoubleLine((shown == 1) and "Best for:" or " ", who .. "  " .. math.floor(f.fit * 100 + 0.5) .. "%",
        0.62, 0.62, 0.62, 1, 1, 1)
    end
  end

  if item.notMyClass then
    panel:AddDoubleLine("Fit for your spec:", "not for your class", 0.62, 0.62, 0.62, 1, 0.35, 0.35)
  elseif item.myFit then
    local r, g, b = 0.3, 1, 0.3
    if item.myFit < 0.35 then r, g, b = 1, 0.35, 0.35 elseif item.myFit < 0.65 then r, g, b = 1, 0.9, 0.2 end
    -- weapon damage isn't part of the fit, only the stats on the weapon
    local label = (item.stats.DPS or item.stats.RDPS) and "Its stats fit your spec:" or "Fit for your spec:"
    panel:AddDoubleLine(label, math.floor(item.myFit * 100 + 0.5) .. "%", 0.62, 0.62, 0.62, r, g, b)
  end
end

local function AddExtras(panel, title, extras, r, g, b)
  for i = 1, table.getn(extras) do
    panel:AddLine(title .. Shorten(extras[i], 90), r, g, b, 1)
  end
end

-- One comparison block: equipped item, scores, changes, verdict.
local function AddComparison(panel, item, comp, detail)
  local eq = comp.equipped
  panel:AddLine(" ")
  if eq.empty then
    panel:AddDoubleLine("Equipped - " .. comp.label, "nothing", 0.62, 0.62, 0.62, 0.62, 0.62, 0.62)
  else
    panel:AddLine("Equipped - " .. comp.label, 0.62, 0.62, 0.62)
    local r, g, b = NameColor(eq)
    panel:AddDoubleLine(Shorten(eq.name, 44), ScoreText(comp.oldScore), r, g, b, 1, 1, 1)
    if detail >= 2 and eq.enchantText then
      panel:AddLine("  Enchant: " .. Shorten(eq.enchantText, 50) ..
        (ECA.db.ignoreEnchants and " (ignored)" or ""), 0.4, 0.8, 0.4)
    end
  end
  panel:AddDoubleLine("This item", ScoreText(comp.newScore), 0.62, 0.62, 0.62, 1, 1, 1)

  if detail >= 2 then
    if table.getn(comp.changes) > 0 then
      panel:AddLine("If you swap:", 0.62, 0.62, 0.62)
    end
    for i = 1, table.getn(comp.changes) do
      local c = comp.changes[i]
      local r, g, b = 0.3, 1, 0.3
      if c.diff < 0 then r, g, b = 1, 0.35, 0.35 end
      local right = ""
      if detail >= 3 then
        local unit = ECA.STAT_BY_KEY[c.key].pct and "%" or ""
        right = ECA.Num(c.old) .. unit .. " > " .. ECA.Num(c.new) .. unit .. "   "
      end
      if ECA.db.showPoints and math.abs(c.points) >= 0.05 then
        right = right .. ECA.Signed(c.points)
      end
      panel:AddDoubleLine("  " .. ECA.StatText(c.key, c.diff), right, r, g, b, 0.62, 0.62, 0.62)
    end
    if item.speed and eq.speed and item.speed ~= eq.speed then
      panel:AddDoubleLine("  Weapon speed", string.format("%.2f > %.2f", eq.speed, item.speed), 1, 1, 1, 0.62, 0.62, 0.62)
    end
  end

  if detail >= 3 then
    -- what stays the same, and what the change really does for this character
    local newStats, oldStats = ECA.ItemStats(item), ECA.ItemStats(eq)
    local same = ""
    for i = 1, table.getn(ECA.STATS) do
      local s = ECA.STATS[i]
      local v = newStats[s.key]
      if v and v == oldStats[s.key] then
        if same ~= "" then same = same .. ", " end
        same = same .. ECA.Num(v) .. (s.pct and "% " or " ") .. s.name
      end
    end
    if same ~= "" then panel:AddLine("  Unchanged: " .. same, 0.62, 0.62, 0.62, 1) end

    local diff = {}
    for i = 1, table.getn(comp.changes) do diff[comp.changes[i].key] = comp.changes[i].diff end
    local parts = ECA.Derived(diff)
    if table.getn(parts) > 0 then
      local line = "  In practice: "
      for i = 1, table.getn(parts) do
        if i > 1 then line = line .. ", " end
        line = line .. parts[i]
      end
      panel:AddLine(line, 0.75, 0.85, 1, 1)
    end
  end

  -- verdict
  local v = comp.verdict
  local numbers = ""
  if v ~= nil and v.text ~= "SAME STATS" then
    numbers = "  " .. ECA.Signed(comp.diff)
    if comp.pct and math.abs(comp.pct) < 1000 then numbers = numbers .. " (" .. ECA.Signed(comp.pct) .. "%)" end
  end
  ECA.Fits(item)   -- fills in item.myFit
  local poorFit = eq.empty and comp.diff > 0 and item.myFit and item.myFit < 0.25
  if poorFit then
    panel:AddLine(">> BETTER THAN NOTHING" .. numbers, 1, 0.9, 0.2)
  else
    panel:AddLine(">> " .. v.text .. numbers, v.r, v.g, v.b)
  end
  if item.red then
    panel:AddLine("For reference only: you can't equip it right now.", 1, 1, 1, 1)
  elseif poorFit then
    panel:AddLine("That slot is empty, but these stats do little for your spec. Keep looking.", 1, 1, 1, 1)
  elseif eq.empty and comp.diff > 0.5 then
    panel:AddLine("Recommended: that slot is empty.", 1, 1, 1, 1)
  else
    panel:AddLine(v.advice, 1, 1, 1, 1)
  end

  if detail >= 2 then
    if comp.bestGain then
      panel:AddDoubleLine("Biggest gain", ECA.StatText(comp.bestGain.key, comp.bestGain.diff), 0.62, 0.62, 0.62, 0.3, 1, 0.3)
    end
    if comp.worstLoss then
      panel:AddDoubleLine("Biggest loss", ECA.StatText(comp.worstLoss.key, comp.worstLoss.diff), 0.62, 0.62, 0.62, 1, 0.35, 0.35)
    end
    if comp.note then panel:AddLine(comp.note, 1, 0.6, 0.2, 1) end
    if eq.setName and eq.setHave and eq.setHave >= 2 and eq.setName ~= item.setName then
      panel:AddLine("Careful: your " .. comp.label .. " is part of " .. eq.setName .. " (" .. eq.setHave .. "/" ..
        eq.setTotal .. " worn). Swapping may cost a set bonus, which isn't in the score.", 1, 0.6, 0.2, 1)
    end
    AddExtras(panel, "You'd lose (not scored): ", eq.extras, 1, 0.6, 0.2)
  end
end

local function Render(state, item)
  local panel = GetPanel(state)
  local tooltip = state.tooltip
  local detail = ECA.db.detail
  if IsAltKeyDown() then detail = 3 end

  panel:SetOwner(UIParent, "ANCHOR_NONE")
  panel:SetScale(tooltip:GetScale() or 1)
  panel:ClearLines()
  panel:AddDoubleLine("Equip Compare Adv", ECA.Spec().name, 1, 0.82, 0, 0.62, 0.62, 0.62)

  if state.equippedSlot then
    -- hovering something you're wearing
    local slot = state.equippedSlot
    panel:AddLine(" ")
    panel:AddDoubleLine("You have this equipped", ECA.SLOT_LABEL[slot], 0.3, 1, 0.3, 0.62, 0.62, 0.62)
    panel:AddDoubleLine("This item", ScoreText(ECA.SlotScore(slot)), 0.62, 0.62, 0.62, 1, 1, 1)
    panel:AddDoubleLine("All your gear", ScoreText(ECA.TotalScore()), 0.62, 0.62, 0.62, 1, 1, 1)
    if detail >= 2 and table.getn(item.extras) > 0 then
      panel:AddLine("Its Use, proc and special effects aren't in the score.", 0.62, 0.62, 0.62, 1)
    end
  else
    if item.red then
      panel:AddLine("You can't use this right now: " .. Shorten(item.red, 60), 1, 0.25, 0.25, 1)
    end
    local comps = ECA.Compare(item)
    for i = 1, table.getn(comps) do
      AddComparison(panel, item, comps[i], detail)
    end
    if detail >= 3 and table.getn(comps) > 0 then
      -- the swap against everything you're wearing
      local best = comps.best or comps[1]
      local total = ECA.TotalScore()
      if total > 0.5 then
        panel:AddLine(" ")
        panel:AddDoubleLine("All your gear", ECA.Num(total) .. " > " .. ECA.Num(total + best.diff) .. "  (" ..
          ECA.Signed(best.diff / total * 100) .. "%)", 0.62, 0.62, 0.62, 1, 1, 1)
      end
    end
    if comps.best then
      panel:AddLine(" ")
      if comps.best.diff > 0.5 then
        panel:AddLine("Best swap: " .. comps.best.label ..
          ((not comps.best.equipped.empty) and (" (" .. Shorten(comps.best.equipped.name, 36) .. ")") or ""), 0.3, 1, 0.3, 1)
      else
        panel:AddLine("Neither slot gets better with this.", 1, 0.6, 0.2, 1)
      end
    end
    if detail >= 2 then
      AddExtras(panel, "Also has (not scored): ", item.extras, 0.4, 0.8, 1)
      if item.enchantText and ECA.db.ignoreEnchants then
        panel:AddLine("Its enchant is ignored: " .. Shorten(item.enchantText, 50), 0.62, 0.62, 0.62, 1)
      end
    end
    if detail >= 3 and item.speed and ECA.Spec().slowMH and (item.kind == "ONEHAND" or item.kind == "MAINHAND" or item.kind == "TWOHAND") then
      panel:AddLine("Tip: your instant attacks hit harder with a slow main-hand weapon. That isn't in the score.", 0.62, 0.62, 0.62, 1)
    end
  end

  if ECA.db.showFit and detail >= 2 then
    panel:AddLine(" ")
    AddFitLines(panel, item)
  end

  if detail >= 3 then
    local caps = ECA.CapStatus()
    if table.getn(caps) > 0 then panel:AddLine(" ") end
    for i = 1, table.getn(caps) do panel:AddLine(caps[i], 0.62, 0.62, 0.62) end
  elseif detail == 2 then
    panel:AddLine("Hold Alt for more detail", 0.45, 0.45, 0.45)
  end
  if detail >= 3 then
    panel:AddLine("Made by stealthzi", 0.45, 0.45, 0.45)
  end

  panel:Show()
  Anchor(state, true)
end

------------------------------------------------------------------------------------------------------
-- Following the tooltips
------------------------------------------------------------------------------------------------------

local function Signature(tooltip)
  local first = getglobal(tooltip:GetName() .. "TextLeft1")
  return (first and first:GetText() or "") .. "#" .. (tooltip:NumLines() or 0)
end

function ECA.UpdateTooltip(tooltip)
  local state = states[tooltip:GetName()]
  if not state or not ECA.char then return end
  state.sig = Signature(tooltip)
  state.shift, state.alt = IsShiftKeyDown(), IsAltKeyDown()
  if not ECA.db.enabled or not tooltip:IsShown() or (ECA.db.shiftOnly and not state.shift) then
    HidePanel(state)
    return
  end
  local item = ECA.ParseTooltip(tooltip:GetName(), tooltip:NumLines(), true)
  if not item then
    HidePanel(state)
    return
  end
  Render(state, item)
end

function ECA.RefreshPanels()
  for _, state in pairs(states) do
    if state.tooltip:IsVisible() then
      ECA.Safe(ECA.UpdateTooltip, state.tooltip)
    else
      HidePanel(state)
    end
  end
end

local function HookMethod(tooltip, method)
  local original = tooltip[method]
  if type(original) ~= "function" then return end
  tooltip[method] = function(self, ...)
    local state = states[self:GetName()]
    if state then
      state.equippedSlot = nil
      if method == "SetInventoryItem" and arg[1] == "player" and type(arg[2]) == "number" and ECA.SLOT_LABEL[arg[2]] then
        state.equippedSlot = arg[2]
      end
    end
    local r1, r2, r3, r4 = original(self, unpack(arg))
    if state then ECA.Safe(ECA.UpdateTooltip, self) end
    return r1, r2, r3, r4
  end
end

local function Follow(tooltip, index)
  if not tooltip or states[tooltip:GetName()] then return end
  local state = { tooltip = tooltip, index = index }
  states[tooltip:GetName()] = state

  for i = 1, table.getn(SET_METHODS) do
    HookMethod(tooltip, SET_METHODS[i])
  end

  -- A child frame is shown and hidden with the tooltip, which catches every way a tooltip can be filled.
  local watcher = CreateFrame("Frame", nil, tooltip)
  watcher.elapsed = 0
  watcher:SetScript("OnShow", function() ECA.Safe(ECA.UpdateTooltip, state.tooltip) end)
  watcher:SetScript("OnHide", function()
    state.equippedSlot = nil
    HidePanel(state)
  end)
  watcher:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + arg1
    if this.elapsed < 0.15 then return end
    this.elapsed = 0
    if not ECA.char then return end
    if state.sig ~= Signature(state.tooltip) or state.shift ~= IsShiftKeyDown() or state.alt ~= IsAltKeyDown() then
      ECA.Safe(ECA.UpdateTooltip, state.tooltip)
    else
      Anchor(state, false)
    end
  end)
end

function ECA.InstallHooks()
  Follow(GameTooltip, 1)
  Follow(ItemRefTooltip, 2)
end
