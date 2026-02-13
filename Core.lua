local addonName, ns = ...

local HoldToCastFix = CreateFrame("Frame", "HoldToCastFixFrame", UIParent)
ns.HoldToCastFix = HoldToCastFix

-- Separate binding frames: bar1 needs its own so the state driver can clear
-- only bar1 bindings when bar1 pages away (vehicles, dragonriding, shapeshift)
-- without wiping other bars' bindings.
local bindingFrameBar1 = CreateFrame("Frame", "HoldToCastFixBindingOwnerBar1", UIParent)
local bindingFrameOthers = CreateFrame("Frame", "HoldToCastFixBindingOwnerOthers", UIParent)
HoldToCastFix.bindingFrameBar1 = bindingFrameBar1
HoldToCastFix.bindingFrameOthers = bindingFrameOthers

-- Secure handler frame for combat-safe paging detection (bar1 only)
local stateFrame = CreateFrame("Frame", "HoldToCastFixStateDriver", UIParent, "SecureHandlerStateTemplate")
stateFrame:SetFrameRef("bindingFrame", bindingFrameBar1)
HoldToCastFix.stateFrame = stateFrame

-- Mapping: ElvUI bar number -> keybind target prefix
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

ns.supportedBars = {1, 3, 4, 5, 6, 13, 14, 15}

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
    bars = { [1] = true },
    minimap = { show = false, angle = 220 },
}

HoldToCastFix.pendingUpdate = false
HoldToCastFix.bindingsActive = false
HoldToCastFix.stateDriverActive = false
HoldToCastFix.bar1Paged = false

-- Debug event log (ring buffer, newest at end)
local DEBUG_LOG_MAX = 40
HoldToCastFix.debugLog = {}

local function DebugLog(msg)
    local log = HoldToCastFix.debugLog
    local ts = format("%.1f", GetTime() % 10000) -- compact timestamp
    log[#log + 1] = ts .. "  " .. msg
    if #log > DEBUG_LOG_MAX then
        table.remove(log, 1)
    end
    if ns.RefreshDebugPanel then ns.RefreshDebugPanel() end
end
ns.DebugLog = DebugLog

local function HasBar1Enabled()
    local db = HoldToCastFixDB
    return db and db.bars and db.bars[1] or false
end

local function HasAnyNonBar1Enabled()
    local db = HoldToCastFixDB
    if not db or not db.bars then return false end
    for _, barNum in ipairs(ns.supportedBars) do
        if barNum ~= 1 and db.bars[barNum] then return true end
    end
    return false
end

-- Paging condition string for bar1 state driver.
-- ElvUI disables Blizzard's ActionBarController, so Blizzard's native
-- ActionButton frames do NOT page for vehicle/override/bonusbar/shapeshift.
-- We must detect all paging states and clear our bar1 bindings so ElvUI's
-- own bindings (which DO page correctly) take over.
local function GetPagingConditions()
    local conditions = ""
    if GetOverrideBarIndex then
        conditions = conditions .. "[overridebar] 0; "
    end
    if GetVehicleBarIndex then
        conditions = conditions .. "[vehicleui] 0; [possessbar] 0; "
    end
    conditions = conditions .. "[bonusbar:5] 0; "
    if GetTempShapeshiftBarIndex then
        conditions = conditions .. "[shapeshift] 0; "
    end
    conditions = conditions .. "[bar:2] 0; [bar:3] 0; [bar:4] 0; [bar:5] 0; [bar:6] 0; "
    conditions = conditions .. "1"
    return conditions
end

-- Secure handler: clears bar1 bindings when bar1 pages away.
-- Runs in restricted environment so it works during combat lockdown.
-- Only affects bindingFrameBar1 — other bars on bindingFrameOthers are untouched.
stateFrame:SetAttribute("_onstate-htcfpage", [[
    -- tostring() because state driver values may arrive as numbers (1 vs "1")
    if tostring(newstate) ~= "1" then
        local bf = self:GetFrameRef("bindingFrame")
        if bf then
            bf:ClearBindings()
        end
    end
    self:CallMethod("OnSecureStateChanged")
]])

-- Lua callback: handles bar1 paging state changes.
-- When bar1 pages away, only bar1 bindings are cleared (by the secure handler above).
-- Other bars remain active on their separate binding frame.
-- When bar1 returns from paging during combat, we can't restore bindings until
-- combat ends (WoW API limitation), so we defer via pendingUpdate.
function stateFrame:OnSecureStateChanged()
    local page = tostring(self:GetAttribute("state-htcfpage"))
    DebugLog("StateChanged: page=" .. page .. " combat=" .. tostring(InCombatLockdown()))
    if page ~= "1" then
        HoldToCastFix.bar1Paged = true
        HoldToCastFix.bindingsActive = HasAnyNonBar1Enabled()
        DebugLog("  -> bar1Paged=true, active=" .. tostring(HoldToCastFix.bindingsActive))
    else
        HoldToCastFix.bar1Paged = false
        if InCombatLockdown() then
            -- Can't call SetOverrideBinding during combat; defer to PLAYER_REGEN_ENABLED.
            -- Bar1 hold-to-cast is unavailable until combat ends, but ElvUI's own
            -- bindings still work (spells fire, just without hold-to-cast).
            HoldToCastFix.pendingUpdate = true
            DebugLog("  -> bar1Paged=false, DEFERRED (combat)")
        else
            ClearOverrideBindings(bindingFrameBar1)
            HoldToCastFix:SetBar1Bindings()
            DebugLog("  -> bar1Paged=false, bindings restored")
        end
    end
    if ns.UpdateActiveState then ns.UpdateActiveState() end
end

-- Apply bindings for bar1 only (used when bar1 returns from paging)
function HoldToCastFix:SetBar1Bindings()
    local db = HoldToCastFixDB
    if not db or not db.enabled or not db.bars or not db.bars[1] then return end

    local bindPrefix = barToBindTarget[1]
    if not bindPrefix then return end

    for i = 1, 12 do
        local bindCommand = bindPrefix .. i
        local keys = {GetBindingKey(bindCommand)}
        for _, key in ipairs(keys) do
            if key and key ~= "" then
                SetOverrideBinding(bindingFrameBar1, true, key, bindCommand)
            end
        end
    end
    self.bindingsActive = true
    if ns.UpdateActiveState then ns.UpdateActiveState() end
end

-- Apply bindings for all enabled bars
function HoldToCastFix:SetBindings()
    local db = HoldToCastFixDB
    if not db or not db.enabled or not db.bars then return end

    local anyActive = false

    for _, barNum in ipairs(ns.supportedBars) do
        if db.bars[barNum] then
            local bindPrefix = barToBindTarget[barNum]
            if bindPrefix then
                local bf = (barNum == 1) and bindingFrameBar1 or bindingFrameOthers
                for i = 1, 12 do
                    local bindCommand = bindPrefix .. i
                    local keys = {GetBindingKey(bindCommand)}
                    for _, key in ipairs(keys) do
                        if key and key ~= "" then
                            SetOverrideBinding(bf, true, key, bindCommand)
                        end
                    end
                end
                anyActive = true
            end
        end
    end

    self.bindingsActive = anyActive
    if ns.UpdateActiveState then ns.UpdateActiveState() end
end

function HoldToCastFix:ApplyBindings()
    if InCombatLockdown() then
        self.pendingUpdate = true
        DebugLog("ApplyBindings: DEFERRED (combat)")
        return
    end

    DebugLog("ApplyBindings: clearing all")
    ClearOverrideBindings(bindingFrameBar1)
    ClearOverrideBindings(bindingFrameOthers)
    self.bindingsActive = false
    self.bar1Paged = false

    local db = HoldToCastFixDB
    if not db or not db.enabled then
        self:DisableStateDriver()
        DebugLog("ApplyBindings: disabled, done")
        if ns.UpdateActiveState then ns.UpdateActiveState() end
        return
    end

    self:SetBindings()
    self:EnableStateDriver()
    DebugLog("ApplyBindings: done, active=" .. tostring(self.bindingsActive) .. " paged=" .. tostring(self.bar1Paged))
end

function HoldToCastFix:EnableStateDriver()
    local db = HoldToCastFixDB
    if not db or not db.enabled then return end

    if HasBar1Enabled() then
        if not self.stateDriverActive then
            self.stateDriverActive = true
            DebugLog("EnableStateDriver: registering (first time)")
            RegisterStateDriver(stateFrame, "htcfpage", GetPagingConditions())
            -- RegisterStateDriver fires _onstate- immediately, which handles
            -- the initial state. No further action needed here.
        else
            -- State driver already active — re-check current state so that
            -- ApplyBindings() + EnableStateDriver() stays consistent after
            -- the paging flags were reset in ApplyBindings().
            local page = tostring(stateFrame:GetAttribute("state-htcfpage") or "")
            DebugLog("EnableStateDriver: already active, page=" .. page)
            if page ~= "1" then
                self.bar1Paged = true
                ClearOverrideBindings(bindingFrameBar1)
                self.bindingsActive = HasAnyNonBar1Enabled()
            end
            if ns.UpdateActiveState then ns.UpdateActiveState() end
        end
    else
        self:DisableStateDriver()
    end
end

function HoldToCastFix:DisableStateDriver()
    if self.stateDriverActive then
        UnregisterStateDriver(stateFrame, "htcfpage")
        self.stateDriverActive = false
    end
end

function HoldToCastFix:Initialize()
    if not HoldToCastFixDB then
        HoldToCastFixDB = {}
    end
    local DB = HoldToCastFixDB

    -- Migrate from old single-bar format to multi-bar
    if DB.bar ~= nil then
        if DB.bars == nil then
            DB.bars = { [DB.bar] = true }
        end
        DB.bar = nil
    end

    -- Apply defaults for missing keys
    for k, v in pairs(defaults) do
        if DB[k] == nil then
            if type(v) == "table" then
                DB[k] = CopyTable(v)
            else
                DB[k] = v
            end
        end
    end

    if ElvUI then
        local E = ElvUI[1]
        if E then
            local AB = E:GetModule("ActionBars", true)
            if AB and AB.HandleBinds then
                hooksecurefunc(AB, "HandleBinds", function()
                    DebugLog("Hook: AB:HandleBinds fired")
                    HoldToCastFix:ApplyBindings()
                end)
            end
        end
    end

    if ns.InitMinimapButton then
        ns.InitMinimapButton()
    end

    self:ApplyBindings()
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

HoldToCastFix:RegisterEvent("PLAYER_LOGIN")
HoldToCastFix:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        self:Initialize()
        DebugLog("PLAYER_LOGIN: initialized")
    elseif event == "PLAYER_REGEN_ENABLED" then
        DebugLog("REGEN_ENABLED: pending=" .. tostring(self.pendingUpdate))
        if self.pendingUpdate then
            self.pendingUpdate = false
            self:ApplyBindings()
        end
    end
end)

SLASH_HOLDTOCASTFIX1 = "/holdtocast"
SLASH_HOLDTOCASTFIX2 = "/htcf"
SlashCmdList["HOLDTOCASTFIX"] = function()
    if ns.ToggleConfig then
        ns.ToggleConfig()
    end
end
