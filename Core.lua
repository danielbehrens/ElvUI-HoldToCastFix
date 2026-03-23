local addonName, ns = ...

local HoldToCastFix = CreateFrame("Frame", "HoldToCastFixFrame", UIParent)
ns.HoldToCastFix = HoldToCastFix

-- Separate binding frames: bar1 needs its own so the state driver can clear
-- only bar1 bindings when bar1 pages away (vehicles, dragonriding)
-- without wiping other bars' bindings.
-- bar1 frame MUST be secure (SecureFrameTemplate) so ClearBindings() works
-- in the restricted execution environment of secure handlers during combat.
local bindingFrameBar1 = CreateFrame("Frame", "HoldToCastFixBindingOwnerBar1", UIParent, "SecureFrameTemplate")
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
HoldToCastFix.bar1Page = 1
HoldToCastFix.housingMode = false
HoldToCastFix.zoneTimer = nil

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

-- Transform modifier-only paging conditions to use negative page numbers.
-- This lets the secure handler distinguish modifier-based page changes
-- (which the engine doesn't track) from engine-side page changes
-- (bonus bar, shapeshift, bar switching) where ACTIONBUTTON fires correctly.
--
-- Example: "[mod:shift]4" becomes "[mod:shift] -4"
-- But "[bonusbar:1,stealth]13" stays unchanged.
local function NegateModifierPages(paging)
    return paging:gsub("(%[([^%]]-)%])%s*(%d+)", function(bracket, inner, pageStr)
        -- Only negate if the condition contains a modifier qualifier
        -- AND does not contain engine-side conditions (bonusbar, bar, shapeshift)
        if inner:find("mod:")
           and not inner:find("bonusbar")
           and not inner:find("bar:")
           and not inner:find("shapeshift")
           and not inner:find("overridebar")
           and not inner:find("vehicleui")
           and not inner:find("possessbar") then
            return bracket .. " -" .. pageStr
        end
    end)
end

-- Build paging condition string for bar1 state driver.
-- Returns actual page numbers matching ElvUI's bar1 paging.
-- Vehicle/override/possess return 0 (bindings cleared, let ElvUI handle).
-- Modifier-only paging returns NEGATIVE page numbers (bindings cleared,
-- let ElvUI handle — ACTIONBUTTON can't fire the correct paged slot
-- because the engine's internal page doesn't change for modifier paging).
-- Form paging returns positive page numbers for tracking; the engine-side
-- page is updated by ActionBarController so ACTIONBUTTON bindings fire correctly.
local function GetPagingConditions()
    local conditions = ""

    -- Vehicle/override/possess: return 0 (clear bindings for these)
    if GetOverrideBarIndex then
        conditions = conditions .. "[overridebar] 0; "
    end
    if GetVehicleBarIndex then
        conditions = conditions .. "[vehicleui] 0; [possessbar] 0; "
    end

    -- Class-specific paging from ElvUI config (produces actual page numbers)
    -- e.g. Druid: "[bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 8; ..."
    -- Modifier-only conditions get negated so the state handler can clear bindings.
    if ElvUI then
        local E = ElvUI[1]
        if E and E.db and E.db.actionbar and E.db.actionbar.bar1
           and E.db.actionbar.bar1.paging then
            local classPaging = E.db.actionbar.bar1.paging[E.myclass]
            if classPaging and classPaging ~= "" then
                classPaging = classPaging:gsub("[\n\r]", "")
                classPaging = NegateModifierPages(classPaging)
                conditions = conditions .. classPaging .. " "
            end
        end
    end

    -- Temp shapeshift bar (quest transformations, etc.)
    if GetTempShapeshiftBarIndex then
        conditions = conditions .. format("[shapeshift] %d; ", GetTempShapeshiftBarIndex())
    end

    -- Manual bar switching
    conditions = conditions .. "[bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; "

    -- Rogue Shadow Dance / special bonusbar:5
    conditions = conditions .. "[bonusbar:5] 11; "

    -- Default: page 1
    conditions = conditions .. "1"

    DebugLog("PagingConditions: " .. conditions)
    return conditions
end

-- Secure handler: manages bar1 paging.
-- For vehicle/override (page == 0) and modifier-paged (page < 0), clears
-- bindings and lets ElvUI handle.
-- For form paging (page >= 1), bindings stay active — the engine-side page
-- is updated by ActionBarController so ACTIONBUTTON bindings fire correctly.
stateFrame:SetAttribute("_onstate-htcfpage", [[
    local page = tonumber(newstate)

    if not page or page <= 0 then
        -- Vehicle/override/possess (0) or modifier-paged (negative):
        -- clear bindings, let ElvUI handle
        local bf = self:GetFrameRef("bindingFrame")
        if bf then
            bf:ClearBindings()
        end
    end

    self:CallMethod("OnSecureStateChanged")
]])

-- Lua callback: handles bar1 paging state changes.
-- page == 0: vehicle/override — bindings cleared by secure handler
-- page < 0:  modifier-paged — bindings cleared by secure handler
--            (ACTIONBUTTON can't fire correct paged slot; the engine's
--            internal page doesn't change for modifier-based paging)
-- page >= 1: normal or form — bindings stay active, engine handles paging
function stateFrame:OnSecureStateChanged()
    local page = tonumber(self:GetAttribute("state-htcfpage")) or 0
    DebugLog("StateChanged: page=" .. tostring(page) .. " combat=" .. tostring(InCombatLockdown()))

    HoldToCastFix.bar1Page = math.abs(page)

    if page <= 0 then
        -- Vehicle/override/possess (0) or modifier-paged (negative):
        -- bindings cleared by secure handler, let ElvUI handle
        HoldToCastFix.bar1Paged = true
        HoldToCastFix.bindingsActive = HasAnyNonBar1Enabled()
        if page == 0 then
            DebugLog("  -> bar1Paged=true (vehicle/override), active=" .. tostring(HoldToCastFix.bindingsActive))
        else
            DebugLog("  -> bar1Paged=true (modifier page " .. math.abs(page) .. "), hold-to-cast paused")
        end
    else
        if HoldToCastFix.bar1Paged then
            -- Returning from vehicle/override/modifier paging — restore bar1 bindings
            HoldToCastFix.bar1Paged = false
            if InCombatLockdown() then
                HoldToCastFix.pendingUpdate = true
                HoldToCastFix.bindingsActive = HasAnyNonBar1Enabled()
                DebugLog("  -> returning from paged, DEFERRED (combat), page=" .. page)
            else
                ClearOverrideBindings(bindingFrameBar1)
                HoldToCastFix:SetBar1Bindings()
                DebugLog("  -> returning from paged, bindings restored, page=" .. page)
            end
        else
            -- Normal form switch: bindings stay active, engine pages ACTIONBUTTON
            HoldToCastFix.bindingsActive = true
            DebugLog("  -> page=" .. page .. ", hold-to-cast active")
        end
    end

    if ns.UpdateActiveState then ns.UpdateActiveState() end
end

-- Apply bindings for bar1 only (used when bar1 returns from vehicle/override)
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
    self.bar1Page = 1

    local db = HoldToCastFixDB
    if not db or not db.enabled then
        self:DisableStateDriver()
        DebugLog("ApplyBindings: disabled, done")
        if ns.UpdateActiveState then ns.UpdateActiveState() end
        return
    end

    -- Housing plot: disable completely — players are pacified and the
    -- housing editor needs keybinds (1-4) that our overrides would eat.
    if C_Housing and C_Housing.IsInsidePlot and C_Housing.IsInsidePlot() then
        self.housingMode = true
        self:DisableStateDriver()
        DebugLog("ApplyBindings: housing plot, bindings disabled")
        if ns.UpdateActiveState then ns.UpdateActiveState() end
        return
    end
    self.housingMode = false

    -- Always teardown/rebuild state driver to pick up fresh conditions
    self:DisableStateDriver()
    self:SetBindings()
    self:EnableStateDriver()
    DebugLog("ApplyBindings: done, active=" .. tostring(self.bindingsActive) .. " page=" .. tostring(self.bar1Page))
end

function HoldToCastFix:EnableStateDriver()
    local db = HoldToCastFixDB
    if not db or not db.enabled then return end

    if HasBar1Enabled() then
        self.stateDriverActive = true
        local conds = GetPagingConditions()
        DebugLog("EnableStateDriver: registering")
        RegisterStateDriver(stateFrame, "htcfpage", conds)
        -- RegisterStateDriver fires _onstate- immediately, which handles
        -- the initial state.
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

-- Re-register action bar events on Blizzard's ActionBarController.
-- ElvUI disables these in DisableBlizzard(), but the engine needs them to
-- update its internal action bar page for Druid forms, Skyriding dismount,
-- override bar transitions (entering a dungeon while flying), etc.
-- Without them, ACTIONBUTTON bindings fire the wrong slot.
--
-- IMPORTANT: Event registration does NOT taint ActionBarController's handler.
-- When these events fire, ActionBarController's OnEvent runs in Blizzard's
-- secure context (dispatched by the engine), so it can safely call protected
-- functions like ChangeActionBarPage().  We must NEVER call those functions
-- directly from our addon code — that causes ADDON_ACTION_BLOCKED.
local function EnableBlizzardBarEvents()
    local controller = _G.ActionBarController
    if not controller then return end
    controller:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    controller:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    controller:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
    DebugLog("EnableBlizzardBarEvents: registered on ActionBarController")
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

    -- Let ActionBarController handle engine-side bar paging so
    -- ACTIONBUTTON bindings fire the correct paged action slot
    EnableBlizzardBarEvents()

    if ns.InitMinimapButton then
        ns.InitMinimapButton()
    end

    self:ApplyBindings()
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Housing plot detection: disable bindings while on a housing plot
    -- so the housing editor's keybinds (1-4) work correctly.
    if C_Housing then
        self:RegisterEvent("HOUSE_PLOT_ENTERED")
        self:RegisterEvent("HOUSE_PLOT_EXITED")
    end

    self.initialized = true
end

HoldToCastFix:RegisterEvent("PLAYER_LOGIN")
HoldToCastFix:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        self:Initialize()
        DebugLog("PLAYER_LOGIN: initialized")
    elseif event == "PLAYER_ENTERING_WORLD" then
        if self.initialized then
            DebugLog("PLAYER_ENTERING_WORLD: re-applying bindings")
            EnableBlizzardBarEvents()
            self:ApplyBindings()
            -- Safety-net: re-apply after a short delay to handle late
            -- bar transitions (e.g. Skyriding dismount during loading
            -- screen where engine page update events may be lost).
            if self.zoneTimer then self.zoneTimer:Cancel() end
            self.zoneTimer = C_Timer.NewTimer(1, function()
                self.zoneTimer = nil
                if not self.initialized then return end
                DebugLog("ZoneTimer: delayed re-apply")
                EnableBlizzardBarEvents()
                self:ApplyBindings()
            end)
        end
    elseif event == "HOUSE_PLOT_ENTERED" then
        DebugLog("HOUSE_PLOT_ENTERED: disabling bindings")
        self:ApplyBindings()
    elseif event == "HOUSE_PLOT_EXITED" then
        DebugLog("HOUSE_PLOT_EXITED: restoring bindings")
        self:ApplyBindings()
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
