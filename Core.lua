local addonName, ns = ...

local HoldToCastFix = CreateFrame("Frame", "HoldToCastFixFrame", UIParent)
ns.HoldToCastFix = HoldToCastFix

-- Binding owner frame (separate so ClearOverrideBindings only clears ours)
local bindingFrame = CreateFrame("Frame", "HoldToCastFixBindingOwner", UIParent)
HoldToCastFix.bindingFrame = bindingFrame

-- Mapping: ElvUI bar number -> keybind target prefix (matches ElvUI barDefaults.bindButtons)
local barToBindTarget = {
    [1]  = "ACTIONBUTTON",
    [3]  = "MULTIACTIONBAR3BUTTON",
    [4]  = "MULTIACTIONBAR4BUTTON",
    [5]  = "MULTIACTIONBAR2BUTTON",
    [6]  = "MULTIACTIONBAR1BUTTON",
    [13] = "MULTIACTIONBAR5BUTTON",
    [14] = "MULTIACTIONBAR6BUTTON",
    [15] = "MULTIACTIONBAR7BUTTON",
}
ns.barToBindTarget = barToBindTarget

-- Supported bar numbers for the config UI
ns.supportedBars = {1, 3, 4, 5, 6, 13, 14, 15}

-- Blizzard button prefix (for display/status only)
ns.barToBlizzButton = {
    [1]  = "ActionButton",
    [3]  = "MultiBarBottomRightButton",
    [4]  = "MultiBarRightButton",
    [5]  = "MultiBarBottomLeftButton",
    [6]  = "MultiBarLeftButton",
    [13] = "MultiBar5Button",
    [14] = "MultiBar6Button",
    [15] = "MultiBar7Button",
}

local defaults = {
    enabled = true,
    bar = 1,
}

HoldToCastFix.pendingUpdate = false
HoldToCastFix.barPaged = false
HoldToCastFix.recheckTimer = nil

-- Check if bar1 is paged away from its default page.
local function IsBarPaged(barNum)
    if barNum ~= 1 then return false end

    return HasVehicleActionBar()
        or HasOverrideActionBar()
        or (IsPossessBarVisible and IsPossessBarVisible())
        or HasTempShapeshiftActionBar()
        or HasBonusActionBar()
        or (GetActionBarPage and GetActionBarPage() ~= 1)
end

function HoldToCastFix:SetBindings()
    local db = HoldToCastFixDB
    if not db or not db.enabled then return end

    local barNum = db.bar
    if not barNum then return end

    local bindPrefix = barToBindTarget[barNum]
    if not bindPrefix then return end

    for i = 1, 12 do
        local bindCommand = bindPrefix .. i
        local keys = {GetBindingKey(bindCommand)}
        for _, key in ipairs(keys) do
            if key and key ~= "" then
                SetOverrideBinding(bindingFrame, true, key, bindCommand)
            end
        end
    end
end

function HoldToCastFix:UpdateState()
    if InCombatLockdown() then
        self.pendingUpdate = true
        return
    end

    local db = HoldToCastFixDB
    if not db or not db.enabled then
        ClearOverrideBindings(bindingFrame)
        self.barPaged = false
        return
    end

    local isPaged = IsBarPaged(db.bar)

    if isPaged then
        -- Bar is paged: clear our bindings, let ElvUI/Blizzard handle it
        ClearOverrideBindings(bindingFrame)
        self.barPaged = true
    else
        -- Bar is on default page: apply our native bindings for hold-to-cast
        ClearOverrideBindings(bindingFrame)
        self:SetBindings()
        self.barPaged = false
    end
end

-- Alias for the ElvUI hook
function HoldToCastFix:ApplyBindings()
    self:UpdateState()
end

-- Schedule a delayed recheck. When dismounting, multiple events fire but
-- the API state (HasBonusActionBar, GetActionBarPage, etc.) may not update
-- immediately. A short delay ensures we catch the final settled state.
function HoldToCastFix:ScheduleRecheck()
    if self.recheckTimer then
        self.recheckTimer:Cancel()
    end
    self.recheckTimer = C_Timer.NewTimer(0.2, function()
        self.recheckTimer = nil
        self:UpdateState()
    end)
end

-- Called on any bar state change event
function HoldToCastFix:OnBarStateChanged()
    -- Immediate check (handles transitions where the API is already updated)
    self:UpdateState()
    -- Delayed recheck (handles transitions where the API lags behind the event)
    self:ScheduleRecheck()
end

function HoldToCastFix:Initialize()
    if not HoldToCastFixDB then
        HoldToCastFixDB = {}
    end
    for k, v in pairs(defaults) do
        if HoldToCastFixDB[k] == nil then
            HoldToCastFixDB[k] = v
        end
    end

    -- Hook ElvUI's HandleBinds so we re-apply after ElvUI updates its bindings
    if ElvUI then
        local E = ElvUI[1]
        if E then
            local AB = E:GetModule("ActionBars", true)
            if AB and AB.HandleBinds then
                hooksecurefunc(AB, "HandleBinds", function()
                    HoldToCastFix:UpdateState()
                end)
            end
        end
    end

    self:UpdateState()

    -- Combat end: apply deferred updates
    self:RegisterEvent("PLAYER_REGEN_ENABLED")

    -- Bar paging events: vehicle, override, possess
    self:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
    self:RegisterEvent("UPDATE_POSSESS_BAR")
    self:RegisterEvent("VEHICLE_UPDATE")
    self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
    self:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
    self:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")

    -- Bonus bar (dragonriding/skyriding) and bar page changes
    self:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    self:RegisterEvent("ACTIONBAR_PAGE_CHANGED")

    -- Shapeshift forms
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
end

HoldToCastFix:RegisterEvent("PLAYER_LOGIN")
HoldToCastFix:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        self:Initialize()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if self.pendingUpdate then
            self.pendingUpdate = false
            self:UpdateState()
        end
    else
        self:OnBarStateChanged()
    end
end)

-- Slash command to open config
SLASH_HOLDTOCASTFIX1 = "/holdtocast"
SLASH_HOLDTOCASTFIX2 = "/htcf"
SlashCmdList["HOLDTOCASTFIX"] = function()
    if ns.ToggleConfig then
        ns.ToggleConfig()
    end
end
