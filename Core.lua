local addonName, ns = ...

HideVendorItems = ns
ns.name = addonName

ns.CATEGORIES = { "equipment", "pets", "mounts", "costume", "toys", "housing", "recipes" }
ns.CATEGORY_LABELS = {
    equipment = "Equipment",
    pets      = "Pets",
    mounts    = "Mounts",
    costume   = "Costume",
    toys      = "Toys",
    housing   = "Housing",
    recipes   = "Crafting Recipes",
}

local DEFAULTS = {
    hideOwned = true,
    visibleCategories = {
        equipment = false,
        pets      = false,
        mounts    = false,
        costume   = false,
        toys      = false,
        housing   = false,
        recipes   = false,
    },
}

local function applyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            applyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

local callbacks = {}
function ns.OnSettingsChanged(fn)
    table.insert(callbacks, fn)
end
function ns.FireSettingsChanged()
    for _, fn in ipairs(callbacks) do fn() end
end

SLASH_HIDEVENDORITEMS1 = "/HVI"
SlashCmdList["HIDEVENDORITEMS"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = msg:match("^(%S+)%s*(%S*)$")
    if cmd == "debug" then
        if ns.Vendor and ns.Vendor.DebugDump then
            local idx = tonumber(arg)
            ns.Vendor.DebugDump(idx)
        end
    else
        print("HVI commands:")
        print("  /HVI debug       - dump classification for every merchant slot")
        print("  /HVI debug <n>   - dump slot n plus its full tooltip data")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        HideVendorItemsDB = HideVendorItemsDB or {}
        applyDefaults(HideVendorItemsDB, DEFAULTS)
        ns.db = HideVendorItemsDB
    end
end)
