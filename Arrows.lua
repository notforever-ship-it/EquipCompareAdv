-- Equip Compare Adv: small arrows on item icons. Green up = an upgrade for your spec, red down = worse.
-- Shown in the bags (the game's own bags, Bagshui and pfUI), at vendors and in the auction house.
-- Each item is scored once with the same scorer as the panel and remembered by its link; the scores are
-- only worked out again when your gear, spec, talents, level or the settings change.

local ECA = EquipCompareAdv

local GOLD, GREY, END = "|cffffd100", "|cff9d9d9d", "|r"

local SIZE = 13
local UP_TEXTURE = "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up"
local DOWN_TEXTURE = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up"
local TIP = "EquipCompareAdvArrowTooltip"
local MAX_RESULTS = 1000

local results, resultCount = {}, 0   -- item link + spec -> { dir, diff, slot, label } or false
local tracked = {}                    -- item button -> { kind, a, b }: where its item comes from
local hooked = {}
local gearSig

------------------------------------------------------------------------------------------------------
-- Scoring one item
------------------------------------------------------------------------------------------------------

local scanTip
local function Tip()
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", TIP, nil, "GameTooltipTemplate")
  end
  scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
  scanTip:ClearLines()
  return scanTip
end

local function FillBag(tip, bag, slot)
  if bag == -1 then
    if BankButtonIDToInvSlotID then tip:SetInventoryItem("player", BankButtonIDToInvSlotID(slot)) end
  else
    tip:SetBagItem(bag, slot)
  end
end

local function FillMerchant(tip, index) tip:SetMerchantItem(index) end
local function FillBuyback(tip, index) tip:SetBuybackItem(index) end
local function FillAuction(tip, index) tip:SetAuctionItem("list", index) end

-- Up (1), down (-1) or about equal (0), against the weaker slot for rings, trinkets and one-handers.
-- "About equal" is the panel's own SIDEGRADE band: less than 0.5 score or less than 3% of the slot.
-- Items you can't use (red text in their tooltip, or a type your class never wears) get nothing.
local function Evaluate(link, fill, a, b)
  local spec = ECA.Spec()
  local key = link .. "|" .. ((spec and spec.key) or "")
  local r = results[key]
  if r ~= nil then return r end

  r = false
  local tip = Tip()
  fill(tip, a, b)
  local rejected = ECA.lastRejected   -- /eca debug is about hovered items, not this scan
  local item = ECA.ParseTooltip(TIP, tip:NumLines(), true)
  ECA.lastRejected = rejected
  if item and not item.red and ECA.CanUse(ECA.class, item) then
    local comps = ECA.Compare(item)
    local c = comps.best or comps[1]
    if c then
      local V, v, dir = ECA.VERDICTS, c.verdict, 0
      if v == V.up or v == V.bigup then
        dir = 1
      elseif v == V.down or v == V.bigdown then
        dir = -1
      end
      r = { dir = dir, diff = c.diff, slot = c.slot, label = c.label }
    end
  end

  if resultCount >= MAX_RESULTS then results, resultCount = {}, 0 end
  results[key] = r
  resultCount = resultCount + 1
  return r
end

------------------------------------------------------------------------------------------------------
-- The arrow on a button
------------------------------------------------------------------------------------------------------

local function ArrowOf(button)
  local holder = button.ecaArrow
  if not holder then
    -- A frame of its own, a few levels up, so borders, glows and cooldowns of bag addons stay under it.
    holder = CreateFrame("Frame", nil, button)
    holder:SetWidth(SIZE)
    holder:SetHeight(SIZE)
    holder:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    holder:SetFrameLevel(button:GetFrameLevel() + 6)
    holder.tex = holder:CreateTexture(nil, "OVERLAY")
    holder.tex:SetAllPoints(holder)
    holder.tex:SetTexCoord(0.22, 0.78, 0.22, 0.78)   -- the art sits in the middle of its square
    holder:Hide()
    button.ecaArrow = holder
  end
  return holder
end

local function Paint(button, r)
  local dir = (r and r.dir) or 0
  if dir < 0 and not ECA.db.arrowsShowWorse then dir = 0 end
  if dir == 0 then
    if button.ecaArrow then button.ecaArrow:Hide() end
    return
  end
  local arrow = ArrowOf(button)
  if dir > 0 then
    arrow.tex:SetTexture(UP_TEXTURE)
    arrow.tex:SetVertexColor(0.2, 1, 0.2)
  else
    arrow.tex:SetTexture(DOWN_TEXTURE)
    arrow.tex:SetVertexColor(1, 0.25, 0.25)
  end
  arrow:Show()
end

local function Active()
  return ECA.char and ECA.db and ECA.db.enabled and ECA.db.upgradeArrows
end

local function ItemId(link)
  if type(link) ~= "string" then return nil end
  local _, _, id = string.find(link, "item:(%d+)")
  return id
end

-- Bagshui keeps the bag and slot of each button's item in button.bagshuiData.item. Its buttons can also
-- show another character's bags or a bank that isn't open; those get no arrow.
local function BagshuiSlot(button)
  local info = button.bagshuiData
  if type(info) ~= "table" or type(info.item) ~= "table" then return nil end
  local item = info.item
  if item.emptySlot == 1 or item.emptySlot == true then return nil end
  if type(info.inventory) == "table" and info.inventory.online == false then return nil end
  if type(item.bagNum) ~= "number" or type(item.slotNum) ~= "number" then return nil end
  return item.bagNum, item.slotNum, ItemId(item.itemLink)
end

local function Update(button, kind, a, b)
  if not button then return end
  local src = tracked[button]
  if not src then
    src = {}
    tracked[button] = src
  end
  src.kind, src.a, src.b = kind, a, b
  if not Active() then
    Paint(button, nil)
    return
  end

  local link, fill, x, y
  if kind == "bag" or kind == "bagshui" then
    local bag, slot, expected = a, b, nil
    if kind == "bagshui" then bag, slot, expected = BagshuiSlot(button) end
    if bag then
      link = GetContainerItemLink(bag, slot)
      if expected and ItemId(link) ~= expected then link = nil end   -- not the item Bagshui is showing
      fill, x, y = FillBag, bag, slot
    end
  elseif kind == "merchant" then
    link, fill, x = GetMerchantItemLink(a), FillMerchant, a
  elseif kind == "buyback" then
    if GetBuybackItemLink then link = GetBuybackItemLink(a) end
    fill, x = FillBuyback, a
  elseif kind == "auction" then
    link, fill, x = GetAuctionItemLink("list", a), FillAuction, a
  end

  if not link then
    Paint(button, nil)
    return
  end
  Paint(button, Evaluate(link, fill, x, y))
end

-- Every button seen so far, again. Bag buttons are worked out even while the bags are closed, so the
-- arrows are right the moment they open; vendor and auction buttons only while they are on screen.
local function RefreshAll()
  for button, src in pairs(tracked) do
    if src.kind == "bag" or src.kind == "bagshui" or button:IsVisible() then
      Update(button, src.kind, src.a, src.b)
    end
  end
end

local timer = CreateFrame("Frame")
timer:Hide()
timer.wait = 0
timer:SetScript("OnUpdate", function()
  this.wait = this.wait - arg1
  if this.wait <= 0 then
    this:Hide()
    ECA.Safe(RefreshAll)
  end
end)

local function Schedule(delay)
  if not timer:IsShown() or timer.wait > delay then timer.wait = delay end
  timer:Show()
end

-- Scores changed (settings, spec, talents, level): forget them and redraw the arrows.
function ECA.RefreshArrows()
  results, resultCount = {}, 0
  Schedule(0.1)
end

local function GearSignature()
  local s = ""
  for slot = 1, 19 do s = s .. (GetInventoryItemLink("player", slot) or "-") .. ";" end
  return s
end

------------------------------------------------------------------------------------------------------
-- Where the buttons are
------------------------------------------------------------------------------------------------------

-- The game's own bags: ContainerFrame1..N, buttons ContainerFrameNItemM. Bank bags too.
local function UpdateContainerFrame(frame)
  if type(frame) ~= "table" or not frame.GetID or not frame.GetName then return end
  local name = frame:GetName()
  if not name then return end
  local bag = frame:GetID()
  for j = 1, (frame.size or 0) do
    local button = getglobal(name .. "Item" .. j)
    if button then Update(button, "bag", bag, button:GetID()) end
  end
end

local function UpdateMerchant()
  if not MerchantFrame then return end
  local buyback = (MerchantFrame.selectedTab == 2)
  local perPage = MERCHANT_ITEMS_PER_PAGE or 10
  if buyback then perPage = BUYBACK_ITEMS_PER_PAGE or 12 end
  for i = 1, 12 do
    local button = getglobal("MerchantItem" .. i .. "ItemButton")
    if button then
      if i > perPage then
        Paint(button, nil)
      elseif buyback then
        Update(button, "buyback", i)
      else
        Update(button, "merchant", ((MerchantFrame.page or 1) - 1) * perPage + i)
      end
    end
  end
end

local function UpdateAuction()
  local offset = 0
  if BrowseScrollFrame then offset = FauxScrollFrame_GetOffset(BrowseScrollFrame) end
  for i = 1, (NUM_BROWSE_TO_DISPLAY or 8) do
    local button = getglobal("BrowseButton" .. i .. "Item")
    if button then Update(button, "auction", offset + i) end
  end
end

local function UpdateBagshui(button)
  if type(button) == "table" and button.GetName then Update(button, "bagshui") end
end

local function UpdatePfSlot(bag, slot)
  local b = pfUI and pfUI.bags and pfUI.bags[bag] and pfUI.bags[bag].slots and pfUI.bags[bag].slots[slot]
  if b and b.frame then Update(b.frame, "bag", bag, slot) end
end

-- Run 'after' once the game's own function is done. Only once, and only if the function is there.
local function HookGlobal(name, after)
  if hooked[name] then return end
  local original = getglobal(name)
  if type(original) ~= "function" then return end
  hooked[name] = true
  setglobal(name, function(...)
    local r1, r2, r3, r4 = original(unpack(arg))
    ECA.Safe(after, arg[1])
    return r1, r2, r3, r4
  end)
end

-- Bagshui fills its item buttons through Ui:AssignItemToItemButton(button, item, groupId). Its
-- inventory windows inherit it from Bagshui.prototypes.Ui (InventoryUi is a Ui:New() with Ui as its
-- metatable), so wrapping it where it is defined reaches every Bagshui bag and bank button.
local function HookBagshui()
  if hooked.Bagshui then return end
  if type(Bagshui) ~= "table" or type(Bagshui.prototypes) ~= "table" then return end
  local owner
  local candidates = { Bagshui.prototypes.InventoryUi, Bagshui.prototypes.Ui }
  for i = 1, 2 do
    local t = candidates[i]
    if not owner and type(t) == "table" and type(rawget(t, "AssignItemToItemButton")) == "function" then owner = t end
  end
  if not owner then return end
  local original = owner.AssignItemToItemButton
  hooked.Bagshui = true
  owner.AssignItemToItemButton = function(self, button, item, groupId)
    local r1, r2 = original(self, button, item, groupId)
    ECA.Safe(UpdateBagshui, button)
    return r1, r2
  end
end

-- pfUI's bags fill each button through pfUI.bag:UpdateSlot(bag, slot).
local function HookPfUI()
  if hooked.pfUI then return end
  if type(pfUI) ~= "table" or type(pfUI.bag) ~= "table" or type(pfUI.bag.UpdateSlot) ~= "function" then return end
  local original = pfUI.bag.UpdateSlot
  hooked.pfUI = true
  pfUI.bag.UpdateSlot = function(self, bag, slot)
    local r1, r2 = original(self, bag, slot)
    ECA.Safe(UpdatePfSlot, bag, slot)
    return r1, r2
  end
end

local function InstallHooks()
  HookGlobal("ContainerFrame_Update", UpdateContainerFrame)
  HookGlobal("MerchantFrame_Update", UpdateMerchant)
  HookGlobal("AuctionFrameBrowse_Update", UpdateAuction)   -- only there once the auction house has loaded
  HookBagshui()
  HookPfUI()
end

------------------------------------------------------------------------------------------------------
-- /eca best: the best upgrade in your bags for each slot
------------------------------------------------------------------------------------------------------

function ECA.PrintBest()
  if not ECA.char then return end
  local best = {}
  for bag = 0, 4 do
    for slot = 1, (GetContainerNumSlots(bag) or 0) do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local r = Evaluate(link, FillBag, bag, slot)
        if r and r.dir > 0 and (not best[r.label] or r.diff > best[r.label].diff) then
          best[r.label] = { diff = r.diff, slot = r.slot, label = r.label, link = link }
        end
      end
    end
  end

  local order = {}
  for i = 1, table.getn(ECA.GEAR_SLOTS) do order[ECA.GEAR_SLOTS[i]] = i end
  local list = {}
  for _, entry in pairs(best) do table.insert(list, entry) end
  if table.getn(list) == 0 then
    ECA.Print("No upgrades in your bags.")
    return
  end
  table.sort(list, function(x, y)
    local ox, oy = order[x.slot] or 99, order[y.slot] or 99
    if ox ~= oy then return ox < oy end
    return x.label < y.label
  end)
  ECA.Print("Best upgrades in your bags, scored as " .. GOLD .. ECA.SpecLabel() .. END .. ":")
  for i = 1, table.getn(list) do
    local e = list[i]
    DEFAULT_CHAT_FRAME:AddMessage("  " .. GREY .. e.label .. ":" .. END .. " " .. e.link .. ", " ..
      "|cff66ff66" .. ECA.Signed(e.diff) .. " score" .. END)
  end
end

------------------------------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == "Blizzard_AuctionUI" or arg1 == "Bagshui" or arg1 == "pfUI" then ECA.Safe(InstallHooks) end
  elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    ECA.Safe(InstallHooks)
    gearSig = GearSignature()
  elseif event == "UNIT_INVENTORY_CHANGED" then
    -- Also fires for durability and every arrow a hunter shoots: only a real change of gear counts.
    if arg1 == "player" then
      local sig = GearSignature()
      if sig ~= gearSig then
        gearSig = sig
        results, resultCount = {}, 0
        Schedule(0.2)
      end
    end
  end
end)
