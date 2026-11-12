local _, ns = ...

-- Profession/class trainer defaults (WoW Forever client only).
-- Unticks "Unavailable" and "Already Known" in Blizzard's trainer filter
-- dropdown every time a trainer window opens. The player can still re-tick
-- them from the Settings > Filters menu while the window is open.

local Trainer = {}
ns.Trainer = Trainer

local IS_FOREVER = ns.IS_FOREVER

local HIDDEN_BY_DEFAULT = { "unavailable", "used" }

local function isFilterOn(filterType)
    local v = GetTrainerServiceTypeFilter(filterType)
    return v == true or v == 1
end

-- The value argument has been a number (1/0) in older clients and a boolean
-- in newer ones. Try boolean first, then fall back to a number, and confirm
-- the result each time.
local function turnOff(filterType)
    if not isFilterOn(filterType) then return end
    pcall(SetTrainerServiceTypeFilter, filterType, false)
    if isFilterOn(filterType) then
        pcall(SetTrainerServiceTypeFilter, filterType, 0)
    end
end

function Trainer.ApplyDefaults()
    if not (SetTrainerServiceTypeFilter and GetTrainerServiceTypeFilter) then return end
    if ns.db and ns.db.trainerHideKnown == false then return end
    for _, filterType in ipairs(HIDDEN_BY_DEFAULT) do
        turnOff(filterType)
    end
end

-- Run now, then again after the trainer UI has finished its own OnShow
-- handling (which resets the filters).
local function applySoon()
    Trainer.ApplyDefaults()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, Trainer.ApplyDefaults)
        C_Timer.After(0.2, Trainer.ApplyDefaults)
    end
end

if IS_FOREVER then
    local f = CreateFrame("Frame")
    f:RegisterEvent("TRAINER_SHOW")
    f:SetScript("OnEvent", applySoon)
end
