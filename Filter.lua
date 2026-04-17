local _, ns = ...

local Filter = {}
ns.Filter = Filter

local cache = nil

function Filter.Invalidate()
    cache = nil
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

    if not db then
        cache = result
        return cache
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
                if not db.visibleCategories[cat] then
                    include = false
                elseif db.hideOwned and owned then
                    include = false
                end
            end
        end

        if include then
            result[#result + 1] = i
        end
    end

    cache = result
    return cache
end
