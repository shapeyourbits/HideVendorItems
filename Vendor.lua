local _, ns = ...

local Vendor = {}
ns.Vendor = Vendor

local filtered = {}
local active = false
local inRefresh = false
local lastRawCount = -1

local orig = {
    GetMerchantNumItems     = GetMerchantNumItems,
    GetMerchantItemInfo     = GetMerchantItemInfo,
    GetMerchantItemLink     = GetMerchantItemLink,
    GetMerchantItemCostInfo = GetMerchantItemCostInfo,
    GetMerchantItemCostItem = GetMerchantItemCostItem,
    GetMerchantItemMaxStack = GetMerchantItemMaxStack,
    GetMerchantItemID       = GetMerchantItemID,
    GetMerchantItemTexture  = GetMerchantItemTexture,
    CanAffordMerchantItem   = CanAffordMerchantItem,
    BuyMerchantItem         = BuyMerchantItem,
    PickupMerchantItem      = PickupMerchantItem,
    CMF_GetItemInfo         = C_MerchantFrame and C_MerchantFrame.GetItemInfo or nil,
    CTI_GetMerchantItem     = C_TooltipInfo and C_TooltipInfo.GetMerchantItem or nil,
}

local function isRemapActive()
    if not active then return false end
    if not MerchantFrame or not MerchantFrame:IsShown() then return false end
    return MerchantFrame.selectedTab == 1
end

local function wrap1(name)
    local o = orig[name]
    if not o then return end
    _G[name] = function(i, ...)
        if isRemapActive() then
            local r = filtered[i]
            if not r then return nil end
            return o(r, ...)
        end
        return o(i, ...)
    end
end

local function installWrappers()
    _G.GetMerchantNumItems = function()
        if isRemapActive() then return #filtered end
        return orig.GetMerchantNumItems()
    end

    wrap1("GetMerchantItemInfo")
    wrap1("GetMerchantItemLink")
    wrap1("GetMerchantItemCostInfo")
    wrap1("GetMerchantItemMaxStack")
    wrap1("GetMerchantItemID")
    wrap1("GetMerchantItemTexture")
    wrap1("CanAffordMerchantItem")
    wrap1("BuyMerchantItem")
    wrap1("PickupMerchantItem")

    _G.GetMerchantItemCostItem = function(i, ...)
        if isRemapActive() then
            local r = filtered[i]
            if not r then return nil end
            return orig.GetMerchantItemCostItem(r, ...)
        end
        return orig.GetMerchantItemCostItem(i, ...)
    end

    if C_MerchantFrame and orig.CMF_GetItemInfo then
        C_MerchantFrame.GetItemInfo = function(i, ...)
            if isRemapActive() then
                local r = filtered[i]
                if not r then return nil end
                return orig.CMF_GetItemInfo(r, ...)
            end
            return orig.CMF_GetItemInfo(i, ...)
        end
    end

    if C_TooltipInfo and orig.CTI_GetMerchantItem then
        C_TooltipInfo.GetMerchantItem = function(i, ...)
            if isRemapActive() then
                local r = filtered[i]
                if not r then return nil end
                return orig.CTI_GetMerchantItem(r, ...)
            end
            return orig.CTI_GetMerchantItem(i, ...)
        end
    end

    local function wrapTooltipSetMerchant(tooltip)
        if not tooltip or not tooltip.SetMerchantItem or tooltip.HVI_wrappedSetMerchantItem then return end
        local o = tooltip.SetMerchantItem
        tooltip.HVI_wrappedSetMerchantItem = true
        tooltip.SetMerchantItem = function(self, i, ...)
            if isRemapActive() then
                local r = filtered[i]
                if r then i = r end
            end
            return o(self, i, ...)
        end
    end
    wrapTooltipSetMerchant(GameTooltip)
    wrapTooltipSetMerchant(ItemRefTooltip)
    wrapTooltipSetMerchant(EmbeddedItemTooltip)
end

local emptyOverlay

local function ensureOverlay()
    if emptyOverlay then return emptyOverlay end
    local frame = CreateFrame("Frame", nil, MerchantFrame)
    frame:SetAllPoints(MerchantFrame)
    frame:SetFrameStrata(MerchantFrame:GetFrameStrata())
    frame:SetFrameLevel(MerchantFrame:GetFrameLevel() + 10)
    frame:EnableMouse(false)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    text:SetPoint("CENTER", MerchantFrame, "CENTER", 0, 40)
    text:SetText("No matching items")
    frame:Hide()
    emptyOverlay = frame
    return emptyOverlay
end

local function rebuild()
    if not ns.db then
        active = false
        filtered = {}
        return
    end
    active = false
    ns.Filter.Invalidate()
    local ok, result = pcall(ns.Filter.Build)
    if ok then
        filtered = result or {}
    else
        print("|cffff5555HVI|r Build error: " .. tostring(result))
    end
    active = true
end

function Vendor.DebugDump(onlyIndex)
    local n = orig.GetMerchantNumItems and orig.GetMerchantNumItems() or 0
    print(("|cff99ccffHVI|r state: active=%s  shown=%s  tab=%s  #filtered=%d  hideOwned=%s"):format(
        tostring(active),
        tostring(MerchantFrame and MerchantFrame:IsShown()),
        tostring(MerchantFrame and MerchantFrame.selectedTab),
        #filtered,
        tostring(ns.db and ns.db.hideOwned)
    ))
    if ns.db and ns.db.visibleCategories then
        local parts = {}
        for k, v in pairs(ns.db.visibleCategories) do
            parts[#parts + 1] = k .. "=" .. tostring(v)
        end
        print("  visibleCategories: " .. table.concat(parts, ", "))
    end
    print(("|cff99ccffHVI|r: %d unfiltered merchant items"):format(n))
    for i = 1, n do
        if not onlyIndex or onlyIndex == i then
            local link = orig.GetMerchantItemLink and orig.GetMerchantItemLink(i)
            local itemID = link and tonumber(link:match("item:(%d+)")) or nil
            if not itemID and orig.GetMerchantItemID then
                itemID = orig.GetMerchantItemID(i)
            end
            local cat, owned
            if ns.Detection and itemID then
                cat, owned = ns.Detection.Classify(itemID, link)
            end
            print(("  [%d] id=%s cat=%s owned=%s  %s"):format(
                i, tostring(itemID), tostring(cat), tostring(owned), tostring(link)
            ))
            if onlyIndex and itemID and C_TooltipInfo and C_TooltipInfo.GetItemByID then
                local data = C_TooltipInfo.GetItemByID(itemID)
                if data and type(data.lines) == "table" then
                    for li, line in ipairs(data.lines) do
                        print(("    tip[%d] L=%q  R=%q"):format(
                            li, tostring(line.leftText or ""), tostring(line.rightText or "")
                        ))
                    end
                else
                    print("    (no tooltip data)")
                end
                if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
                    local decor = C_HousingCatalog.GetCatalogEntryInfoByItem(itemID, true)
                    print("    C_HousingCatalog.GetCatalogEntryInfoByItem =", tostring(decor))
                    if type(decor) == "table" then
                        for k, v in pairs(decor) do
                            print(("      .%s = %s"):format(tostring(k), tostring(v)))
                        end
                    end
                end
            end
        end
    end
end

function Vendor.Refresh()
    if inRefresh then return end
    inRefresh = true
    rebuild()
    lastRawCount = orig.GetMerchantNumItems and orig.GetMerchantNumItems() or 0
    local itemsPerPage = MERCHANT_ITEMS_PER_PAGE or 10
    local numPages = math.max(1, math.ceil(#filtered / itemsPerPage))
    if MerchantFrame then
        MerchantFrame.page = MerchantFrame.page or 1
        if MerchantFrame.page > numPages then
            MerchantFrame.page = numPages
        end
    end
    if MerchantFrame and MerchantFrame:IsShown() then
        if MerchantFrame_UpdateMerchantInfo then
            MerchantFrame_UpdateMerchantInfo()
        end
        MerchantFrame_Update()
    end
    inRefresh = false
end

local function onMerchantUpdate()
    if not (MerchantFrame and MerchantFrame:IsShown()
            and MerchantFrame.selectedTab == 1 and active) then
        if emptyOverlay then emptyOverlay:Hide() end
        return
    end

    if not inRefresh then
        local currentRaw = orig.GetMerchantNumItems and orig.GetMerchantNumItems() or 0
        if currentRaw ~= lastRawCount then
            Vendor.Refresh()
            return
        end
    end

    ensureOverlay()
    if #filtered == 0 then
        emptyOverlay:Show()
    else
        emptyOverlay:Hide()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_UPDATE")
f:RegisterEvent("MERCHANT_CLOSED")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        installWrappers()
        hooksecurefunc("MerchantFrame_Update", onMerchantUpdate)
        ns.OnSettingsChanged(Vendor.Refresh)
    elseif event == "MERCHANT_SHOW" then
        Vendor.Refresh()
    elseif event == "MERCHANT_UPDATE" then
        Vendor.Refresh()
    elseif event == "MERCHANT_CLOSED" then
        active = false
        ns.Filter.Invalidate()
        filtered = {}
        if emptyOverlay then emptyOverlay:Hide() end
    end
end)
