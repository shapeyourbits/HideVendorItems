local _, ns = ...

local Detection = {}
ns.Detection = Detection

local function isToy(itemID)
    if not C_ToyBox or not C_ToyBox.GetToyInfo then return false end
    local id = C_ToyBox.GetToyInfo(itemID)
    return id ~= nil
end

local function toyOwned(itemID)
    return PlayerHasToy and PlayerHasToy(itemID) or false
end

local function petSpecies(itemID)
    if not C_PetJournal or not C_PetJournal.GetPetInfoByItemID then return nil end
    local ok, speciesID = pcall(C_PetJournal.GetPetInfoByItemID, itemID)
    if not ok or type(speciesID) ~= "number" or speciesID <= 0 then return nil end
    return speciesID
end

local function petOwned(speciesID)
    if type(speciesID) ~= "number" or speciesID <= 0 then return false end
    if not C_PetJournal or not C_PetJournal.GetNumCollectedInfo then return false end
    local ok, num = pcall(C_PetJournal.GetNumCollectedInfo, speciesID)
    if not ok then return false end
    return (num or 0) > 0
end

local function mountFromItem(itemID)
    if not C_MountJournal or not C_MountJournal.GetMountFromItem then return nil end
    return C_MountJournal.GetMountFromItem(itemID)
end

local function mountOwned(mountID)
    if not mountID or not C_MountJournal or not C_MountJournal.GetMountInfoByID then
        return false
    end
    local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
    return isCollected or false
end

local function housingLookup(itemID)
    if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
        return C_HousingCatalog.GetCatalogEntryInfoByItem(itemID, true)
    end
    return nil
end

local function housingOwned(info)
    if type(info) ~= "table" then return false end
    if (info.quantity or 0) > 0 then return true end
    if (info.remainingRedeemable or 0) > 0 then return true end
    if (info.numPlaced or 0) > 0 then return true end
    return false
end

local function housingTooltipFallback(itemID)
    if not C_TooltipInfo or not C_TooltipInfo.GetItemByID then return nil end
    local data = C_TooltipInfo.GetItemByID(itemID)
    if not data or type(data.lines) ~= "table" then return nil end

    local isHousing = false
    local owned = false

    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if type(text) == "string" then
            if text:find("Housing Decor", 1, true) then
                isHousing = true
            end
            local n = text:match("Owned:%s*(%d+)")
            if n then
                isHousing = true
                if tonumber(n) > 0 then owned = true end
            end
            if text:find("Placed:", 1, true) or text:find("Storage:", 1, true) then
                isHousing = true
                local placed = text:match("Placed:%s*(%d+)")
                local storage = text:match("Storage:%s*(%d+)")
                if (placed and tonumber(placed) > 0)
                   or (storage and tonumber(storage) > 0) then
                    owned = true
                end
            end
        end
    end

    if isHousing then return owned end
    return nil
end

local function ensembleSetID(itemID)
    if C_TransmogSets and C_TransmogSets.GetSetIDFromItemID then
        return C_TransmogSets.GetSetIDFromItemID(itemID)
    end
    return nil
end

local function ensembleOwned(setID)
    if not setID or not C_TransmogSets then return false end
    local sources = C_TransmogSets.GetSetPrimaryAppearances
        and C_TransmogSets.GetSetPrimaryAppearances(setID)
    if type(sources) ~= "table" or #sources == 0 then
        if C_TransmogSets.IsSetCollected then
            return C_TransmogSets.IsSetCollected(setID) or false
        end
        return false
    end
    for _, source in ipairs(sources) do
        if source and source.collected == false then return false end
    end
    return true
end

local function isEquipmentItem(itemID)
    local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local _, _, _, _, _, classID = getInstant(itemID)
    return classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon
end

local function isRecipeItem(itemID)
    local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local _, _, _, _, _, classID = getInstant(itemID)
    return classID == Enum.ItemClass.Recipe
end

local function itemRecipeSpellID(itemID)
    if C_Item and C_Item.GetItemSpell then
        local _, spellID = C_Item.GetItemSpell(itemID)
        if spellID then return spellID end
    end
    if GetItemSpell then
        local _, spellID = GetItemSpell(itemID)
        return spellID
    end
    return nil
end

local function recipeKnown(itemID)
    local spellID = itemRecipeSpellID(itemID)
    if spellID and C_TradeSkillUI then
        if C_TradeSkillUI.IsRecipeKnown then
            return C_TradeSkillUI.IsRecipeKnown(spellID) or false
        end
        if C_TradeSkillUI.GetRecipeInfo then
            local info = C_TradeSkillUI.GetRecipeInfo(spellID)
            if info and info.learned ~= nil then return info.learned end
        end
    end
    return false
end

local RECIPE_NAME_PREFIXES = {
    "Plans:", "Technique:", "Design:", "Formula:",
    "Pattern:", "Schematic:", "Recipe:",
}

local function itemName(itemID)
    if C_Item and C_Item.GetItemNameByID then
        local n = C_Item.GetItemNameByID(itemID)
        if n then return n end
    end
    if GetItemInfo then
        return (GetItemInfo(itemID))
    end
    return nil
end

local function tooltipSaysAlreadyKnown(itemID)
    if not itemID or not C_TooltipInfo or not C_TooltipInfo.GetItemByID then return false end
    local data = C_TooltipInfo.GetItemByID(itemID)
    if not data or type(data.lines) ~= "table" then return false end
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if type(text) == "string" then
            if text:find("Already Known", 1, true)
               or text:find("Already known", 1, true) then
                return true
            end
        end
    end
    return false
end

local function looksLikeRecipeByName(itemID)
    local name = itemName(itemID)
    if type(name) ~= "string" then return false end
    for _, prefix in ipairs(RECIPE_NAME_PREFIXES) do
        if name:sub(1, #prefix) == prefix then return true end
    end
    return false
end

local function spellKnown(spellID, itemID)
    if spellID then
        if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
        if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellID) then return true end
        if IsSpellKnown and IsSpellKnown(spellID) then return true end
    end
    if tooltipSaysAlreadyKnown(itemID) then return true end
    return false
end

local function equipmentOwned(itemLink)
    if not itemLink then return false end
    if C_TransmogCollection and C_TransmogCollection.PlayerHasTransmogByItemInfo then
        return C_TransmogCollection.PlayerHasTransmogByItemInfo(itemLink) or false
    end
    return false
end

function Detection.Classify(itemID, itemLink)
    if not itemID then return nil, false end

    if isRecipeItem(itemID) or looksLikeRecipeByName(itemID) then
        local known = recipeKnown(itemID)
        if not known then known = tooltipSaysAlreadyKnown(itemID) end
        return "recipes", known
    end

    if isToy(itemID) then
        local owned = toyOwned(itemID)
        if not owned and tooltipSaysAlreadyKnown(itemID) then owned = true end
        return "toys", owned
    end

    local species = petSpecies(itemID)
    if species then
        local owned = petOwned(species)
        if not owned and tooltipSaysAlreadyKnown(itemID) then owned = true end
        return "pets", owned
    end

    local mount = mountFromItem(itemID)
    if mount then
        local owned = mountOwned(mount)
        if not owned and tooltipSaysAlreadyKnown(itemID) then owned = true end
        return "mounts", owned
    end

    local decor = housingLookup(itemID)
    if decor then
        if housingOwned(decor) then
            return "housing", true
        end
        local fromTooltip = housingTooltipFallback(itemID)
        if fromTooltip ~= nil then
            return "housing", fromTooltip
        end
        return "housing", false
    end

    local housingFallback = housingTooltipFallback(itemID)
    if housingFallback ~= nil then
        return "housing", housingFallback
    end

    local setID = ensembleSetID(itemID)
    if setID then
        return "costume", ensembleOwned(setID)
    end

    if isEquipmentItem(itemID) then
        local ownedAsCostume = false
        if C_TransmogCollection and C_TransmogCollection.PlayerHasTransmog then
            ownedAsCostume = C_TransmogCollection.PlayerHasTransmog(itemID) or false
        end
        if ownedAsCostume then
            return "costume", true
        end
        return "equipment", equipmentOwned(itemLink)
    end

    local spellID = itemRecipeSpellID(itemID)
    if spellID then
        local known = spellKnown(spellID, itemID)
        local name = itemName(itemID)
        if name and name:lower():find("ensemble", 1, true) then
            return "costume", known
        end
        return "recipes", known
    end

    return nil, false
end
