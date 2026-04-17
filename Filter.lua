local _, ns = ...

local Filter = {}
ns.Filter = Filter

local cache = nil
local hiddenOwned = 0

function Filter.Invalidate()
    cache = nil
end

function Filter.GetHiddenOwnedCount()
    return hiddenOwned
end

local function itemIDFromLink(link)
    if not link then return nil end
    local id = link:match("item:(%d+)")
    return id and tonumber(id) or nil
end

function Filter.Build()
    if cache then return cache end

    local db = ns.db
    local result = {}
    hiddenOwned = 0

    if not db then
        cache = result
        return cache
    end

    local anyCategoryTicked = false
    for _, key in ipairs(ns.CATEGORIES) do
        if db.visibleCategories[key] then
            anyCategoryTicked = true
            break
        end
    end

    local n = GetMerchantNumItems() or 0
    for i = 1, n do
        local link = GetMerchantItemLink(i)
        local itemID = itemIDFromLink(link)
        if not itemID and GetMerchantItemID then
            itemID = GetMerchantItemID(i)
        end

        local include = true

        if itemID then
            local cat, owned = ns.Detection.Classify(itemID, link)
            if cat then
                if anyCategoryTicked and not db.visibleCategories[cat] then
                    include = false
                elseif db.hideOwned and owned then
                    include = false
                    hiddenOwned = hiddenOwned + 1
                end
            elseif anyCategoryTicked then
                include = false
            end
        end

        if include then
            result[#result + 1] = i
        end
    end

    cache = result
    return cache
end
