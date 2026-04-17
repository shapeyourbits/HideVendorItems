local _, ns = ...

local function onSettingChanged()
    if ns.Filter then ns.Filter.Invalidate() end
    ns.FireSettingsChanged()
    if ns.Vendor and ns.Vendor.Refresh then ns.Vendor.Refresh() end
end

local function buildUI()
    if not MerchantFrame or _G.WHTHideOwnedCheck or _G.WHTHeader then return end

    local header = CreateFrame("Frame", "WHTHeader", MerchantFrame, "BackdropTemplate")
    header:SetPoint("BOTTOMLEFT", MerchantFrame, "TOPLEFT", 10, -8)
    header:SetPoint("BOTTOMRIGHT", MerchantFrame, "TOPRIGHT", -10, -8)
    header:SetHeight(32)
    header:SetFrameStrata(MerchantFrame:GetFrameStrata())
    header:SetFrameLevel(MerchantFrame:GetFrameLevel() + 1)
    header:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })

    local check = CreateFrame("CheckButton", "WHTHideOwnedCheck", header, "UICheckButtonTemplate")
    check:SetPoint("LEFT", header, "LEFT", 40, 0)
    check:SetSize(22, 22)
    check.text = check.text or check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    if check.Text then
        check.Text:SetText("Hide owned")
    else
        check.text:SetPoint("LEFT", check, "RIGHT", 2, 0)
        check.text:SetText("Hide owned")
    end
    check:SetScript("OnShow", function(self)
        if ns.db then self:SetChecked(ns.db.hideOwned) end
    end)
    check:SetScript("OnClick", function(self)
        if not ns.db then return end
        ns.db.hideOwned = self:GetChecked() and true or false
        onSettingChanged()
    end)

    local dropdown
    if WowStyle1DropdownTemplate then
        dropdown = CreateFrame("DropdownButton", "WHTCategoryDropdown", header, "WowStyle1DropdownTemplate")
        dropdown:SetPoint("LEFT", check.Text or check.text, "RIGHT", 12, 0)
        dropdown:SetWidth(160)
        dropdown:SetDefaultText("Categories")
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
    else
        dropdown = CreateFrame("Frame", "WHTCategoryDropdown", header, "UIDropDownMenuTemplate")
        dropdown:SetPoint("LEFT", check.Text or check.text, "RIGHT", 0, -2)
        UIDropDownMenu_SetWidth(dropdown, 140)
        UIDropDownMenu_SetText(dropdown, "Categories")
        UIDropDownMenu_Initialize(dropdown, function(self, level)
            if not ns.db then return end
            for _, key in ipairs(ns.CATEGORIES) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = ns.CATEGORY_LABELS[key]
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
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("MERCHANT_SHOW")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "MERCHANT_SHOW" then
        buildUI()
        if _G.WHTHideOwnedCheck and ns.db then
            _G.WHTHideOwnedCheck:SetChecked(ns.db.hideOwned)
        end
    end
end)
