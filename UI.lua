local _, ns = ...

if ns.CATEGORIES and ns.CATEGORY_LABELS then
    table.sort(ns.CATEGORIES, function(a, b)
        return (ns.CATEGORY_LABELS[a] or a) < (ns.CATEGORY_LABELS[b] or b)
    end)
end

local function getElvUI()
    if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ElvUI")) then
        return nil, nil
    end
    if not _G.ElvUI then return nil, nil end
    local E = unpack(_G.ElvUI)
    local S = E and E.GetModule and E:GetModule("Skins", true)
    return E, S
end

local function hideKnownLabel()
    if ns.db and ns.db.hideOwned and ns.Filter and ns.Filter.GetHiddenOwnedCount then
        local n = ns.Filter.GetHiddenOwnedCount()
        if n > 0 then
            return ("Hide Known (%d)"):format(n)
        end
    end
    return "Hide Known"
end

function ns.RefreshLabels()
    local check = _G.HVIHideOwnedCheck
    if not check then return end
    local label = hideKnownLabel()
    if check.Text then check.Text:SetText(label) end
    if check.text then check.text:SetText(label) end
end

local function getSelectionText()
    if not (ns.db and ns.db.visibleCategories and ns.CATEGORIES) then return nil end
    local selected = {}
    for _, key in ipairs(ns.CATEGORIES) do
        if ns.db.visibleCategories[key] then
            selected[#selected + 1] = ns.CATEGORY_LABELS[key]
        end
    end
    if #selected == 0 then return nil end
    return table.concat(selected, ", ")
end

local function refreshDropdownLabel()
    local d = _G.HVICategoryDropdown
    if not d or not d.initialize then return end
    local selection = getSelectionText()
    local label
    if selection then
        label = (#selection > 15) and (selection:sub(1, 12) .. "...") or selection
    else
        label = "Show Only"
    end
    if UIDropDownMenu_SetText then UIDropDownMenu_SetText(d, label) end
    d.hviTooltipText = selection
end

local function onSettingChanged()
    if ns.Filter then ns.Filter.Invalidate() end
    ns.FireSettingsChanged()
    if ns.Vendor and ns.Vendor.Refresh then ns.Vendor.Refresh() end
    refreshDropdownLabel()
end

local function buildUI()
    if not MerchantFrame or _G.HVIHideOwnedCheck or _G.HVIHeader then return end

    local E, S = getElvUI()

    local header
    if E then
        header = CreateFrame("Frame", "HVIHeader", MerchantFrame)
    else
        header = CreateFrame("Frame", "HVIHeader", MerchantFrame, "BackdropTemplate")
    end
    local headerYOffset = E and 0 or -8
    header:SetPoint("BOTTOMLEFT", MerchantFrame, "TOPLEFT", 10, headerYOffset)
    header:SetPoint("BOTTOMRIGHT", MerchantFrame, "TOPRIGHT", -10, headerYOffset)
    header:SetHeight(44)
    header:SetFrameStrata(MerchantFrame:GetFrameStrata())
    header:SetFrameLevel(MerchantFrame:GetFrameLevel() + 1)
    if E and header.SetTemplate then
        header:SetTemplate("Transparent")
    else
        header:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
    end

    local check = CreateFrame("CheckButton", "HVIHideOwnedCheck", header, "UICheckButtonTemplate")
    check:SetPoint("LEFT", header, "LEFT", 40, 0)
    check:SetSize(22, 22)
    check.text = check.text or check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    if check.Text then
        check.Text:SetText("Hide Known")
    else
        check.text:SetPoint("LEFT", check, "RIGHT", 2, 0)
        check.text:SetText("Hide Known")
    end
    check:SetScript("OnShow", function(self)
        if ns.db then self:SetChecked(ns.db.hideOwned) end
    end)
    check:SetScript("OnClick", function(self)
        if not ns.db then return end
        ns.db.hideOwned = self:GetChecked() and true or false
        onSettingChanged()
    end)
    if S and S.HandleCheckBox then
        S:HandleCheckBox(check)
    end

    local dropdown
    if DropdownButtonMixin and not E then
        dropdown = CreateFrame("DropdownButton", "HVICategoryDropdown", header, "WowStyle1DropdownTemplate")
        dropdown:SetPoint("RIGHT", header, "RIGHT", -10, -2)
        dropdown:SetWidth(120)
        dropdown:SetDefaultText("Show Only")
        dropdown:SetupMenu(function(_, root)
            for _, key in ipairs(ns.CATEGORIES) do
                root:CreateCheckbox(
                    ns.CATEGORY_LABELS[key],
                    function() return ns.db and ns.db.visibleCategories[key] end,
                    function()
                        if not ns.db then return end
                        ns.db.visibleCategories[key] = not ns.db.visibleCategories[key]
                        onSettingChanged()
                    end
                )
            end
        end)
        if dropdown.OpenMenu then
            local origOpenMenu = dropdown.OpenMenu
            dropdown.OpenMenu = function(self, ...)
                local result = origOpenMenu(self, ...)
                local f = EnumerateFrames and EnumerateFrames()
                while f do
                    if f ~= self and f:IsShown() and f.GetNumPoints and f:GetNumPoints() > 0 then
                        local _, relativeTo = f:GetPoint(1)
                        if relativeTo == self and f.AdjustPointsOffset then
                            f:AdjustPointsOffset(5, 5)
                            return result
                        end
                    end
                    f = EnumerateFrames(f)
                end
                return result
            end
        end
    else
        dropdown = CreateFrame("Frame", "HVICategoryDropdown", header, "UIDropDownMenuTemplate")
        dropdown:SetPoint("RIGHT", header, "RIGHT", 0, -2)
        UIDropDownMenu_SetWidth(dropdown, 120)
        UIDropDownMenu_SetText(dropdown, "Show Only")
        if UIDropDownMenu_SetAnchor then
            UIDropDownMenu_SetAnchor(dropdown, 20, 10, "TOPLEFT", dropdown, "BOTTOMLEFT")
        end
        if UIDropDownMenu_JustifyText then
            UIDropDownMenu_JustifyText(dropdown, "LEFT")
        end
        dropdown:EnableMouse(true)
        dropdown:SetScript("OnEnter", function(self)
            if self.hviTooltipText then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(self.hviTooltipText, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        dropdown:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        UIDropDownMenu_Initialize(dropdown, function(self, level)
            if not ns.db then return end
            for _, key in ipairs(ns.CATEGORIES) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = E and ("   " .. ns.CATEGORY_LABELS[key]) or ns.CATEGORY_LABELS[key]
                info.isNotRadio = true
                info.keepShownOnClick = true
                info.checked = ns.db.visibleCategories[key]
                info.func = function(_, _, _, checked)
                    ns.db.visibleCategories[key] = checked and true or false
                    onSettingChanged()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
    end

    refreshDropdownLabel()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("MERCHANT_SHOW")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "MERCHANT_SHOW" then
        buildUI()
        if _G.HVIHideOwnedCheck and ns.db then
            _G.HVIHideOwnedCheck:SetChecked(ns.db.hideOwned)
        end
    end
end)
