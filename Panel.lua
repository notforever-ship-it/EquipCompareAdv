-- Equip Compare Adv: the comparison panel that sits next to an item tooltip, with the tooltip of what
-- you're wearing in between, like the game's own compare tooltips.
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
-- The frames: the panel, and the tooltips of what you're wearing
------------------------------------------------------------------------------------------------------

-- Tooltip art is see-through, which makes small text hard to read over bags; a dark layer fixes that.
-- It can be switched off for the game's normal look.
local function Darken(tip)
  local solid = tip:CreateTexture(nil, "BACKGROUND")
  solid:SetTexture(0, 0, 0, 0.75)
  solid:SetPoint("TOPLEFT", tip, "TOPLEFT", 4, -4)
  solid:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -4, 4)
  tip.ecaSolid = solid
  if ECA.db and ECA.db.darkBackground == false then solid:Hide() end
end

local allTips = {}

local function NewTip(name)
  local tip = CreateFrame("GameTooltip", name, UIParent, "GameTooltipTemplate")
  tip:SetFrameStrata("TOOLTIP")
  if tip.SetClampedToScreen then tip:SetClampedToScreen(true) end
  Darken(tip)
  table.insert(allTips, tip)
  return tip
end

-- Dark layer on or off, on every panel and equipped-item tooltip the addon has made.
function ECA.ApplyLook()
  local dark = not (ECA.db and ECA.db.darkBackground == false)
  for i = 1, table.getn(allTips) do
    local tip = allTips[i]
    if tip.ecaSolid then
      if dark then tip.ecaSolid:Show() else tip.ecaSolid:Hide() end
    end
    if tip.tab then tip.tab:SetBackdropColor(0, 0, 0, dark and 0.95 or 0.7) end
  end
end

local function GetPanel(state)
  if not state.panel then state.panel = NewTip("EquipCompareAdvPanel" .. state.index) end
  return state.panel
end

-- Up to two tooltips of equipped items (both rings, main hand and off hand), like the game's own compare.
local function GetEquippedTip(state, n)
  if not state.equippedTips then state.equippedTips = {} end
  if not state.equippedTips[n] then
    local tip = NewTip("EquipCompareAdvEquipped" .. state.index .. "_" .. n)
    -- A "Currently Equipped" tab on top. The tooltip itself stays exactly as the game filled it in.
    local tab = CreateFrame("Frame", nil, tip)
    tab:SetHeight(22)
    tab:SetWidth(140)
    tab:SetPoint("BOTTOMLEFT", tip, "TOPLEFT", 0, -3)
    tab:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    tab:SetBackdropColor(0, 0, 0, 0.95)
    tab:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    tip.tabText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tip.tabText:SetPoint("CENTER", tab, "CENTER", 0, 0)
    tip.tabText:SetTextColor(0.6, 0.6, 0.6)
    tip.tab = tab
    state.equippedTips[n] = tip
  end
  return state.equippedTips[n]
end

local function HideEquippedTips(state, from)
  if not state.equippedTips then return end
  for n = from or 1, table.getn(state.equippedTips) do state.equippedTips[n]:Hide() end
end

local function HidePanel(state)
  if state.panel then state.panel:Hide() end
  HideEquippedTips(state)
  state.sig = nil
  state.hideAt = nil
end

-- Fill the equipped-item tooltips for these inventory slots. They are filled whenever the setting is
-- on; whether they show is decided when the row is laid out, because the game's own compare tooltips
-- (the auction house shows them on hover) already do the same job and take the space.
local function ShowEquippedTips(state, slots)
  local shown = 0
  if ECA.db.showEquipped then
    for i = 1, table.getn(slots) do
      if shown < 2 then
        local tip = GetEquippedTip(state, shown + 1)
        tip:SetOwner(UIParent, "ANCHOR_NONE")
        tip:SetScale(state.tooltip:GetScale() or 1)
        if tip:SetInventoryItem("player", slots[i]) then
          tip.tabText:SetText("Currently Equipped - " .. (ECA.SLOT_LABEL[slots[i]] or ""))
          tip.tab:SetWidth((tip.tabText:GetStringWidth() or 130) + 18)
          tip:Show()
          shown = shown + 1
        else
          tip:Hide()
        end
      end
    end
  end
  HideEquippedTips(state, shown + 1)
  state.equippedCount = shown
  state.layout = nil
end

local function ReshowEquippedTips(state)
  if not state.equippedTips then return end
  for n = 1, state.equippedCount or 0 do
    if not state.equippedTips[n]:IsShown() then state.equippedTips[n]:Show() end
  end
end

-- Are the game's own compare tooltips up? At the auction house they come and go a frame apart from the
-- main tooltip on every list refresh, so "seen within the last half second" counts as up. Without that
-- the row jumped between two layouts several times a second, which looked like blinking.
local function ShoppingUp(state)
  if (ShoppingTooltip1 and ShoppingTooltip1:IsVisible()) or (ShoppingTooltip2 and ShoppingTooltip2:IsVisible()) then
    state.shoppingSeen = GetTime()
    return true
  end
  return state.shoppingSeen ~= nil and GetTime() - state.shoppingSeen < 0.5
end

-- Room around the tooltip, in screen pixels: to its left and right, under it and over it.
local function Room(tooltip)
  local scale = tooltip:GetScale() or 1
  local left, right, top, bottom = tooltip:GetLeft(), tooltip:GetRight(), tooltip:GetTop(), tooltip:GetBottom()
  if not (left and right and top and bottom) then return nil end
  return {
    LEFT = left * scale, RIGHT = UIParent:GetWidth() - right * scale,
    UNDER = bottom * scale, OVER = UIParent:GetHeight() - top * scale,
    top = top * scale,
  }
end

local function Width(frame)
  return (frame:GetWidth() or 0) * (frame:GetScale() or 1)
end

local function Height(frame)
  return (frame:GetHeight() or 0) * (frame:GetScale() or 1)
end

-- The game's compare tooltips: the side of the tooltip they sit on and their width together.
-- Remembered, because at aux they come and go with every list refresh.
local function ShoppingRow(state, tooltip)
  local s1, s2 = ShoppingTooltip1, ShoppingTooltip2
  if s1 and s1:IsVisible() and s1:GetLeft() and tooltip:GetLeft() then
    state.shoppingSide = (s1:GetLeft() < tooltip:GetLeft()) and "LEFT" or "RIGHT"
    state.shoppingWidth = Width(s1)
    if s2 and s2:IsVisible() then state.shoppingWidth = state.shoppingWidth + Width(s2) end
  end
  return state.shoppingSide or "RIGHT", state.shoppingWidth or 0
end

-- frame goes next to anchor, on its left or right, tops or bottoms lined up. gap is extra room between.
local function Beside(frame, anchor, where, vert, gap)
  frame:ClearAllPoints()
  gap = (gap or 0) / (frame:GetScale() or 1)
  if where == "RIGHT" then
    frame:SetPoint(vert .. "LEFT", anchor, vert .. "RIGHT", gap, 0)
  else
    frame:SetPoint(vert .. "RIGHT", anchor, vert .. "LEFT", -gap, 0)
  end
end

local function TooltipName(tooltip)
  local first = getglobal(tooltip:GetName() .. "TextLeft1")
  return first and first:GetText() or ""
end

-- Where the panel goes while the game's own compare tooltips are up (the auction house, aux): past
-- them on their side, like the rest of the row, else on the other side, else under or over the tooltip.
-- Nothing fits at all: a shorter panel is drawn (state.wantCompact) and this runs again. The choice is
-- made once per item and kept, so the compare tooltips blinking can't move the panel.
local function AnchorWithShopping(state, force)
  local panel, tooltip = state.panel, state.tooltip
  HideEquippedTips(state)
  local room = Room(tooltip)
  if not room then return end
  local shopSide, shopWidth = ShoppingRow(state, tooltip)
  local free = (shopSide == "RIGHT") and "LEFT" or "RIGHT"
  local pw, ph = Width(panel), Height(panel)
  local name = TooltipName(tooltip)

  local plan = state.shopPlan
  if plan and (plan.name ~= name or plan.compact ~= state.compact) then plan = nil end
  if not plan or force then
    plan = { name = name, compact = state.compact, width = shopWidth }
    if room[shopSide] >= shopWidth + pw then
      plan.layout = "AFTER"
    elseif room[free] >= pw then
      plan.layout = "SIDE"
    elseif room.UNDER >= ph then
      plan.layout = "UNDER"
    elseif room.OVER >= ph then
      plan.layout = "OVER"
    elseif not state.compact then
      state.wantCompact = true
      return
    elseif room[shopSide] - shopWidth >= room[free] then
      plan.layout = "AFTER"
    else
      plan.layout = "SIDE"
    end
    plan.vert = "TOP"
    if (plan.layout == "AFTER" or plan.layout == "SIDE") and room.top - ph < 0 then plan.vert = "BOTTOM" end
    state.shopPlan = plan
  end

  local key = "shop" .. plan.layout .. shopSide .. plan.vert .. math.floor(plan.width)
  if not force and state.layout == key then return end
  state.layout = key
  if plan.layout == "UNDER" then
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 0, 0)
  elseif plan.layout == "OVER" then
    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", 0, 0)
  elseif plan.layout == "AFTER" then
    -- anchored to the tooltip, not to the compare tooltips, which may be hidden at this instant
    Beside(panel, tooltip, shopSide, plan.vert, plan.width)
  else
    Beside(panel, tooltip, free, plan.vert)
  end
end

-- Tooltip, then what you're wearing, then the panel, in a row on whichever side has room. If the row is
-- too long for one side the panel takes the other; too long for the screen, and the tooltips of what
-- you're wearing go, then the panel is drawn shorter. The layout is worked out once for the item under
-- the mouse and then kept: other addons add lines to the tooltip a moment after it appears, and the
-- game refreshes some tooltips several times a second, so deciding again each time made the frames
-- jump between two spots when the numbers were close.
local function Anchor(state, force)
  local panel, tooltip = state.panel, state.tooltip
  if not panel or not panel:IsShown() then return end
  if ShoppingUp(state) then
    AnchorWithShopping(state, force)
    return
  end

  local name = TooltipName(tooltip)
  local count = state.equippedCount or 0
  local plan = state.plan
  if plan and (plan.name ~= name or plan.count ~= count or plan.alt ~= state.alt or plan.compact ~= state.compact) then
    plan = nil
  end
  if not plan then
    local room = Room(tooltip)
    if not room then return end
    local tipsWidth, tipsHeight = 0, 0
    for n = 1, count do
      local tip = state.equippedTips[n]
      tipsWidth = tipsWidth + Width(tip)
      if Height(tip) > tipsHeight then tipsHeight = Height(tip) end
    end
    local pw, ph = Width(panel), Height(panel)
    local big, small = "LEFT", "RIGHT"
    if room.RIGHT >= room.LEFT then big, small = "RIGHT", "LEFT" end
    -- the right is where the game puts things, so it wins whenever the whole row fits there
    local function Choose(tw)
      if room.RIGHT >= tw + pw then return "RIGHT", "RIGHT" end
      if room[big] >= tw + pw then return big, big end
      if room[big] >= tw and room[small] >= pw then return big, small end
      if room[small] >= tw and room[big] >= pw then return small, big end
      return nil
    end
    plan = { name = name, count = count, alt = state.alt, compact = state.compact, dropTips = false }
    local side, panelSide = Choose(tipsWidth)
    if not side and tipsWidth > 0 then
      plan.dropTips = true
      tipsWidth, tipsHeight = 0, 0
      side, panelSide = Choose(0)
    end
    if not side then
      if not state.compact then
        state.wantCompact = true
        return
      end
      side, panelSide = big, big
    end
    plan.side, plan.panelSide = side, panelSide
    -- tops line up, like the game's own compare tooltips, unless that would run off the bottom
    plan.tipVert, plan.panelVert = "TOP", "TOP"
    if room.top - tipsHeight < 0 then plan.tipVert = "BOTTOM" end
    if room.top - ph < 0 then plan.panelVert = "BOTTOM" end
    state.plan = plan
  end

  local tips = {}
  if plan.dropTips then
    HideEquippedTips(state)
  else
    ReshowEquippedTips(state)
    for n = 1, count do table.insert(tips, state.equippedTips[n]) end
  end

  local layout = plan.side .. plan.panelSide .. plan.tipVert .. plan.panelVert .. table.getn(tips)
  if not force and state.layout == layout then return end
  state.layout = layout
  local last = tooltip
  for n = 1, table.getn(tips) do
    Beside(tips[n], last, plan.side, plan.tipVert)
    last = tips[n]
  end
  if plan.panelSide == plan.side then
    Beside(panel, last, plan.side, plan.panelVert)
  else
    Beside(panel, tooltip, plan.panelSide, plan.panelVert)
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

-- One comparison block: equipped item, scores, changes, verdict. detail 0 is the two-line version used
-- for the second ring, trinket or weapon slot.
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
  if detail >= 1 then
    panel:AddDoubleLine("This item", ScoreText(comp.newScore), 0.62, 0.62, 0.62, 1, 1, 1)
  end

  -- the headline: what the swap does to your damage, the damage you take and your healing
  if detail >= 1 and table.getn(comp.overall) > 0 then
    panel:AddLine("Overall if you swap:", 1, 0.82, 0)
    for i = 1, table.getn(comp.overall) do
      local o = comp.overall[i]
      local r, g, b = 0.62, 0.62, 0.62
      if o.value > 0 then r, g, b = 0.3, 1, 0.3 elseif o.value < 0 then r, g, b = 1, 0.35, 0.35 end
      panel:AddDoubleLine("  " .. o.label, o.text, 1, 1, 1, r, g, b)
    end
  end

  if detail >= 2 then
    if table.getn(comp.changes) > 0 then
      panel:AddLine("Stat by stat:", 0.62, 0.62, 0.62)
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

  end

  -- verdict
  local v = comp.verdict
  local numbers = ""
  if v ~= nil and v.text ~= "SAME STATS" and v.text ~= "NOTHING FOR YOUR SPEC" then
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
  if detail < 1 then
    -- the short version stops at the verdict
  elseif item.red then
    panel:AddLine("For reference only: you can't equip it right now.", 1, 1, 1, 1)
  elseif poorFit then
    panel:AddLine("That slot is empty, but these stats do little for your spec. Keep looking.", 1, 1, 1, 1)
  elseif eq.empty and comp.diff > 0.5 then
    panel:AddLine("Recommended: that slot is empty.", 1, 1, 1, 1)
  else
    panel:AddLine(v.advice, 1, 1, 1, 1)
  end

  -- a second opinion for every role the class can fill
  -- plain armor is worth the same to everyone: when every role agrees with the verdict above, say nothing
  local rolesAgree = true
  for i = 1, table.getn(comp.roles) do
    if comp.roles[i].text or comp.roles[i].verdict ~= comp.roles[1].verdict then rolesAgree = false end
  end
  if detail >= 2 and ECA.db.showRoles and table.getn(comp.roles) > 0 and not rolesAgree then
    panel:AddLine("By role:", 0.62, 0.62, 0.62)
    for i = 1, table.getn(comp.roles) do
      local role = comp.roles[i]
      local rv = role.verdict
      local text = role.text or rv.text
      if role.text then
        -- said in its own words
      elseif text == "NOTHING FOR YOUR SPEC" then
        text = "little in it either way"
      elseif text ~= "SAME STATS" and role.pct and math.abs(role.pct) < 1000 then
        text = text .. "  " .. ECA.Signed(role.pct) .. "%"
      end
      panel:AddDoubleLine("  " .. role.label, text, 1, 1, 1, rv.r, rv.g, rv.b)
    end
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
  if IsAltKeyDown() then
    detail = 3
  elseif state.compact then
    detail = 1   -- the full panel had no room on screen
  end

  panel:SetOwner(UIParent, "ANCHOR_NONE")
  panel:SetScale(tooltip:GetScale() or 1)
  panel:ClearLines()
  panel:AddDoubleLine("Equip Compare Adv", ECA.SpecShort(), 1, 0.82, 0, 0.62, 0.62, 0.62)

  local equippedSlots = {}
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
    -- With two slots to choose from, the better swap is shown in full and the other in two lines, so the
    -- panel stays a sensible height. Alt shows both in full.
    local first, second = comps[1], comps[2]
    if comps.best and comps.best == second then first, second = second, first end
    if first then AddComparison(panel, item, first, detail) end
    if second then
      local brief = detail
      if comps.best and detail < 3 then brief = 0 end
      AddComparison(panel, item, second, brief)
    end
    for i = 1, table.getn(comps) do
      for j = 1, table.getn(comps[i].slots) do table.insert(equippedSlots, comps[i].slots[j]) end
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
  elseif state.compact then
    panel:AddLine("Shortened to fit the screen. Hold Alt for the full panel.", 0.45, 0.45, 0.45)
  end
  if detail >= 3 then
    panel:AddLine("Made by stealthzi   v" .. ECA.VERSION, 0.45, 0.45, 0.45)
  end

  panel:Show()
  ShowEquippedTips(state, equippedSlots)
  Anchor(state, true)
  -- Nowhere to put the full panel: draw it again, shorter. Once; Alt shows the full one anyway.
  if state.wantCompact then
    state.wantCompact = nil
    if not state.compact and not IsAltKeyDown() then
      state.compact = true
      Render(state, item)
    end
  end
end

------------------------------------------------------------------------------------------------------
-- Following the tooltips
------------------------------------------------------------------------------------------------------

-- What the tooltip is showing: its first line, how many lines, and whether it is one of your equipped
-- slots. The same signature twice in a row means nothing to redraw.
local function Signature(state)
  local tooltip = state.tooltip
  local first = getglobal(tooltip:GetName() .. "TextLeft1")
  return (first and first:GetText() or "") .. "#" .. (tooltip:NumLines() or 0) .. "#" .. tostring(state.equippedSlot)
end

function ECA.UpdateTooltip(tooltip)
  local state = states[tooltip:GetName()]
  if not state or not ECA.char then return end
  local sig = Signature(state)
  local shift, alt = IsShiftKeyDown(), IsAltKeyDown()
  if state.hiddenAt and GetTime() - state.hiddenAt > 0.3 then
    state.plan = nil
    state.shopPlan = nil
  end
  local name = TooltipName(tooltip)
  if state.compactName ~= name then
    state.compactName = name
    state.compact = nil
  end
  state.hiddenAt = nil
  state.hideAt = nil
  if not ECA.db.enabled or not tooltip:IsShown() or (ECA.db.shiftOnly and not shift) then
    HidePanel(state)
    return
  end
  -- The auction house and some addons set the same item again several times a second. Same item,
  -- same panel: only its place is checked.
  if state.sig == sig and state.shift == shift and state.alt == alt and state.panel and state.panel:IsShown() then
    Anchor(state, false)
    return
  end
  state.sig, state.shift, state.alt = sig, shift, alt
  local item = ECA.ParseTooltip(tooltip:GetName(), tooltip:NumLines(), true)
  if not item then
    HidePanel(state)
    return
  end
  Render(state, item)
end

function ECA.RefreshPanels()
  for _, state in pairs(states) do
    state.sig = nil
    if state.tooltip:IsVisible() then
      ECA.Safe(ECA.UpdateTooltip, state.tooltip)
    else
      HidePanel(state)
    end
  end
  ECA.ApplyLook()
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

local nextIndex = 0

-- The tooltip hid: the panel goes a moment later, unless the tooltip is back by then with the same item.
-- The auction house hides and refills its tooltip on every list refresh; hiding the panel each time
-- made it blink.
local hider = CreateFrame("Frame")
hider:SetScript("OnUpdate", function()
  for _, state in pairs(states) do
    if state.hideAt and GetTime() - state.hideAt > 0.15 then
      state.hideAt = nil
      if not state.tooltip:IsShown() then
        state.equippedSlot = nil
        state.hiddenAt = GetTime()
        HidePanel(state)
      end
    end
  end
end)

local function Follow(tooltip)
  if not tooltip or not tooltip.GetName or not tooltip:GetName() or states[tooltip:GetName()] then return end
  nextIndex = nextIndex + 1
  local state = { tooltip = tooltip, index = nextIndex }
  states[tooltip:GetName()] = state

  for i = 1, table.getn(SET_METHODS) do
    HookMethod(tooltip, SET_METHODS[i])
  end

  -- A child frame is shown and hidden with the tooltip, which catches every way a tooltip can be filled.
  local watcher = CreateFrame("Frame", nil, tooltip)
  watcher.elapsed = 0
  watcher:SetScript("OnShow", function()
    state.hideAt = nil
    ECA.Safe(ECA.UpdateTooltip, state.tooltip)
  end)
  watcher:SetScript("OnHide", function()
    if not state.hideAt then state.hideAt = GetTime() end
  end)
  watcher:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + arg1
    if this.elapsed < 0.15 then return end
    this.elapsed = 0
    if not ECA.char then return end
    if state.sig ~= Signature(state) or state.shift ~= IsShiftKeyDown() or state.alt ~= IsAltKeyDown() then
      ECA.Safe(ECA.UpdateTooltip, state.tooltip)
    else
      Anchor(state, false)
    end
  end)
end

-- Item tooltips that other addons draw themselves, followed when they exist. Atlas-CFM (Atlas-TW) shows
-- its loot browser's items in the first two; the old AtlasLoot in the other two.
local OTHER_TOOLTIPS = { "AtlasCFMLootTooltip", "AtlasCFMLootTooltip2", "AtlasLootTooltip", "AtlasLootTooltip2" }

function ECA.InstallHooks()
  Follow(GameTooltip)
  Follow(ItemRefTooltip)
  for i = 1, table.getn(OTHER_TOOLTIPS) do
    local tip = getglobal(OTHER_TOOLTIPS[i])
    if type(tip) == "table" and tip.SetHyperlink and tip.NumLines then Follow(tip) end
  end
end
