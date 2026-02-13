local addonName, ns = ...

local configFrame = nil
local minimapButton = nil
local minimapText = nil
local statusIndicator = nil
local barCheckboxes = {}
local E, S  -- ElvUI references, lazy-loaded in SkinFrame()

-- Skin helper: strips Blizzard textures and applies ElvUI template
local function SkinFrame(frame)
    if not ElvUI then return end
    if not E then E = ElvUI[1] end
    if not E then return end
    if not S then S = E:GetModule('Skins') end

    frame:StripTextures()
    frame:SetTemplate('Transparent')

    if frame.CloseButton and S then
        S:HandleCloseButton(frame.CloseButton)
    end
end

-- Helper: build comma-separated string of enabled bar numbers
local function GetEnabledBarString()
    local db = HoldToCastFixDB
    local barList = {}
    if db and db.bars then
        for _, barNum in ipairs(ns.supportedBars) do
            if db.bars[barNum] then
                barList[#barList + 1] = tostring(barNum)
            end
        end
    end
    return #barList > 0 and table.concat(barList, ", ") or "none"
end

-- Minimap button positioning
local function UpdateMinimapButtonPosition()
    if not minimapButton then return end
    local db = HoldToCastFixDB
    if not db or not db.minimap then return end
    local angle = math.rad(db.minimap.angle or 220)
    local radius = 80
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapButton()
    local btn = CreateFrame("Button", "HoldToCastFixMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(21, 21)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("CENTER", 0, 1)

    local text = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetPoint("CENTER", 0, 1)
    text:SetText("HC")
    text:SetTextColor(0.5, 0.5, 0.5) -- starts dim, updated by UpdateActiveState
    minimapText = text

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("ElvUI HoldToCastFix")
        local htcf = ns.HoldToCastFix
        local active = htcf and htcf.bindingsActive
        if active then
            GameTooltip:AddLine("Status: Active", 0, 1, 0)
            GameTooltip:AddLine("Bars: " .. GetEnabledBarString(), 0.8, 0.8, 0.8)
            if htcf.bar1Paged then
                GameTooltip:AddLine("(Bar 1 paged)", 1, 0.7, 0)
            end
        else
            GameTooltip:AddLine("Status: Inactive", 1, 0.4, 0)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click to open config", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click to toggle on/off", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Click handlers
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            ns.ToggleConfig()
        elseif button == "RightButton" then
            local db = HoldToCastFixDB
            if db then
                db.enabled = not db.enabled
                ns.HoldToCastFix:ApplyBindings()
                local state = db.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"
                print("|cff00ff00HoldToCastFix:|r " .. state)
                ns.UpdateActiveState()
            end
        end
    end)

    -- Dragging
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self.isDragging = true
    end)
    btn:SetScript("OnDragStop", function(self)
        self.isDragging = false
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        local db = HoldToCastFixDB
        if db and db.minimap then
            db.minimap.angle = angle
        end
        UpdateMinimapButtonPosition()
    end)
    btn:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.atan2(cy - my, cx - mx)
            local radius = 80
            local x = math.cos(angle) * radius
            local y = math.sin(angle) * radius
            self:ClearAllPoints()
            self:SetPoint("CENTER", Minimap, "CENTER", x, y)
        end
    end)

    minimapButton = btn
    UpdateMinimapButtonPosition()

    local db = HoldToCastFixDB
    if db and db.minimap and db.minimap.show then
        btn:Show()
    else
        btn:Hide()
    end
end

-- Called from Core.lua Initialize after saved vars are loaded
function ns.InitMinimapButton()
    CreateMinimapButton()
end

function ns.SetMinimapButtonShown(show)
    if not minimapButton then return end
    if show then
        minimapButton:Show()
    else
        minimapButton:Hide()
    end
end

-- Updates both minimap icon and config panel to reflect active binding state
function ns.UpdateActiveState()
    local htcf = ns.HoldToCastFix
    local active = htcf and htcf.bindingsActive
    local bar1Paged = htcf and htcf.bar1Paged
    local pendingUpdate = htcf and htcf.pendingUpdate

    -- Minimap icon: gold when active, dim grey when inactive
    if minimapText then
        if active or pendingUpdate then
            minimapText:SetTextColor(1, 0.82, 0)
        else
            minimapText:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    -- Config panel status indicator
    if statusIndicator then
        local db = HoldToCastFixDB
        local barStr = GetEnabledBarString()

        if db and not db.enabled then
            statusIndicator:SetText("|cffff0000Disabled|r")
        elseif active then
            if bar1Paged then
                statusIndicator:SetText("|cff00ff00Active|r - Bars " .. barStr .. "\n|cffffaa00(bar 1 paged)|r")
            else
                statusIndicator:SetText("|cff00ff00Active|r - Bars " .. barStr)
            end
        elseif pendingUpdate and not bar1Paged then
            -- Bar1 returned from paging during combat — bindings restore after combat
            statusIndicator:SetText("|cffffaa00Pending|r - restoring after combat")
        else
            if bar1Paged then
                statusIndicator:SetText("|cffffaa00Inactive|r (bar 1 paged)")
            else
                statusIndicator:SetText("|cffffaa00Inactive|r")
            end
        end
    end
end

local function CreateConfigPanel()
    local frame = CreateFrame("Frame", "HoldToCastFixConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(260, 330)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    -- Title (anchored to frame top — works with or without ElvUI skinning)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -6)
    frame.title:SetText("ElvUI HoldToCastFix")

    local db = HoldToCastFixDB

    -- Enable checkbox
    local enableCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -30)
    enableCheck.text:SetText("Enabled")
    enableCheck.text:SetFontObject("GameFontNormal")
    enableCheck:SetChecked(db.enabled)
    enableCheck:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked()
        ns.HoldToCastFix:ApplyBindings()
    end)
    frame.enableCheck = enableCheck

    -- Minimap icon checkbox
    local minimapCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, 2)
    minimapCheck.text:SetText("Show Minimap Icon")
    minimapCheck.text:SetFontObject("GameFontNormal")
    minimapCheck:SetChecked(db.minimap and db.minimap.show or false)
    minimapCheck:SetScript("OnClick", function(self)
        if not db.minimap then db.minimap = {} end
        db.minimap.show = self:GetChecked()
        ns.SetMinimapButtonShown(db.minimap.show)
    end)
    frame.minimapCheck = minimapCheck

    -- Description
    local desc = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 4, -4)
    desc:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    desc:SetJustifyH("LEFT")
    desc:SetTextColor(0.7, 0.7, 0.7)
    desc:SetText("Routes keybinds for the selected bars to Blizzard's native buttons, enabling Press and Hold Casting.")

    -- Bar selection label
    local barsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    barsLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)
    barsLabel:SetText("Fix these bars:")

    -- Bar checkboxes in two-column layout
    for idx, barNum in ipairs(ns.supportedBars) do
        local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        local col = (idx - 1) % 2        -- 0 or 1
        local row = math.floor((idx - 1) / 2)  -- 0, 1, 2, 3

        if col == 0 then
            check:SetPoint("TOPLEFT", barsLabel, "BOTTOMLEFT", 0, -(row * 24) - 2)
        else
            check:SetPoint("TOPLEFT", barsLabel, "BOTTOMLEFT", 120, -(row * 24) - 2)
        end

        check.text:SetText("Bar " .. barNum)
        check.text:SetFontObject("GameFontHighlight")
        check:SetChecked(db.bars and db.bars[barNum] or false)
        check:SetScript("OnClick", function(self)
            if not db.bars then db.bars = {} end
            db.bars[barNum] = self:GetChecked() or nil
        end)
        barCheckboxes[barNum] = check
    end

    -- Status indicator
    statusIndicator = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusIndicator:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 46)
    statusIndicator:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 46)
    statusIndicator:SetJustifyH("CENTER")
    statusIndicator:SetWordWrap(true)

    -- Apply button
    local applyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    applyBtn:SetSize(100, 24)
    applyBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
    applyBtn:SetText("Apply")
    applyBtn:SetScript("OnClick", function()
        ns.HoldToCastFix:ApplyBindings()
        print("|cff00ff00HoldToCastFix:|r Settings applied - Bars " .. GetEnabledBarString() .. " routed to Blizzard buttons")
    end)

    -- Debug button
    local debugBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    debugBtn:SetSize(70, 24)
    debugBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
    debugBtn:SetText("Debug")
    debugBtn:SetScript("OnClick", function()
        ns.ToggleDebug()
    end)

    -- ElvUI Skinning
    SkinFrame(frame)
    if S then
        S:HandleCheckBox(enableCheck)
        S:HandleCheckBox(minimapCheck)
        for _, check in pairs(barCheckboxes) do
            S:HandleCheckBox(check)
        end
        S:HandleButton(applyBtn)
        S:HandleButton(debugBtn)
    end

    frame:SetScript("OnShow", function()
        enableCheck:SetChecked(db.enabled)
        minimapCheck:SetChecked(db.minimap and db.minimap.show or false)
        for barNum, check in pairs(barCheckboxes) do
            check:SetChecked(db.bars and db.bars[barNum] or false)
        end
        ns.UpdateActiveState()
    end)

    return frame
end

-- =============================================================
-- Debug Panel
-- =============================================================
local debugFrame = nil
local debugText = nil
local debugScrollChild = nil

local function GetBindingCount(frame)
    local count = 0
    if frame and GetOverrideBindingForFrame then
        -- No direct API to count; we check our known bindings
        for _, barNum in ipairs(ns.supportedBars) do
            local prefix = ns.barToBindTarget[barNum]
            if prefix then
                for i = 1, 12 do
                    local keys = {GetBindingKey(prefix .. i)}
                    for _, key in ipairs(keys) do
                        if key and key ~= "" then
                            count = count + 1
                        end
                    end
                end
            end
        end
    end
    return count
end

local function FormatState(val)
    if val == nil then return "|cff888888nil|r" end
    if val == true then return "|cff00ff00true|r" end
    if val == false then return "|cffff4444false|r" end
    return "|cffffffff" .. tostring(val) .. "|r"
end

-- Generates debug info lines. When plain=true, strips color codes for clipboard.
local function BuildDebugLines(plain)
    local htcf = ns.HoldToCastFix
    if not htcf then return {"(no data)"} end

    local lines = {}
    local function L(text) lines[#lines + 1] = text end

    local function S(val) -- format state value
        if plain then return tostring(val) end
        return FormatState(val)
    end

    -- Version & ElvUI info
    local version = C_AddOns.GetAddOnMetadata("HoldToCastFix", "Version") or "?"
    L("HoldToCastFix v" .. version)
    if ElvUI then
        local E = ElvUI[1]
        L("ElvUI v" .. (E and E.version or "?"))
    end
    L("")

    -- Core states
    L("=== Core State ===")
    L("enabled:           " .. S(HoldToCastFixDB and HoldToCastFixDB.enabled))
    L("bindingsActive:    " .. S(htcf.bindingsActive))
    L("bar1Paged:         " .. S(htcf.bar1Paged))
    L("pendingUpdate:     " .. S(htcf.pendingUpdate))
    L("stateDriverActive: " .. S(htcf.stateDriverActive))
    L("InCombatLockdown:  " .. S(InCombatLockdown()))
    L("")

    -- State driver attribute
    local sf = htcf.stateFrame
    if sf then
        local raw = sf:GetAttribute("state-htcfpage")
        L("=== State Driver ===")
        L("state-htcfpage:    " .. S(raw) .. "  type=" .. type(raw))
        L("tostring:          " .. S(tostring(raw)))
    end
    L("")

    -- Enabled bars
    L("=== Enabled Bars ===")
    local db = HoldToCastFixDB
    if db and db.bars then
        for _, barNum in ipairs(ns.supportedBars) do
            local enabled = db.bars[barNum] and true or false
            L("  Bar " .. barNum .. ": " .. S(enabled))
        end
    end
    L("")

    -- Binding frames
    L("=== Binding Frames ===")
    local bf1 = htcf.bindingFrameBar1
    local bfO = htcf.bindingFrameOthers
    if bf1 then
        L("bar1 owner:   " .. (bf1:GetName() or "anon"))
    end
    if bfO then
        L("others owner: " .. (bfO:GetName() or "anon"))
    end

    -- Sample bar1 bindings: check first 4 ACTIONBUTTON slots
    L("")
    L("=== Bar1 Bindings (sample) ===")
    for i = 1, 4 do
        local cmd = "ACTIONBUTTON" .. i
        local keys = {GetBindingKey(cmd)}
        local keyStr = #keys > 0 and table.concat(keys, ", ") or "none"
        local action = GetBindingAction(keys[1] or "", true) or ""
        local overrideInfo = ""
        if keys[1] and action ~= "" then
            overrideInfo = " -> " .. action
        end
        L("  " .. cmd .. ": [" .. keyStr .. "]" .. overrideInfo)
    end
    L("")

    -- Event log
    L("=== Event Log ===")
    local log = htcf.debugLog or {}
    if #log == 0 then
        L("  (empty)")
    else
        for i = 1, #log do
            L("  " .. log[i])
        end
    end

    return lines
end

-- Colorize a plain line for display (adds section header colors etc.)
local function ColorizeLine(line)
    if line:match("^===") then
        return "|cffffcc00" .. line .. "|r"
    end
    -- Colorize true/false values in display
    line = line:gsub("(%s)(true)(%s*)", "%1|cff00ff00%2|r%3")
    line = line:gsub("(%s)(true)$", "%1|cff00ff00%2|r")
    line = line:gsub("(%s)(false)(%s*)", "%1|cffff4444%2|r%3")
    line = line:gsub("(%s)(false)$", "%1|cffff4444%2|r")
    line = line:gsub("(%s)(nil)(%s*)", "%1|cff888888%2|r%3")
    line = line:gsub("(%s)(nil)$", "%1|cff888888%2|r")
    return line
end

function ns.RefreshDebugPanel()
    if not debugFrame or not debugFrame:IsShown() then return end

    local lines = BuildDebugLines(false)
    local colorized = {}
    for i, line in ipairs(lines) do
        colorized[i] = ColorizeLine(line)
    end

    debugText:SetText(table.concat(colorized, "\n"))
    debugScrollChild:SetHeight(debugText:GetStringHeight() + 20)
end

-- Copy popup: shows an editable text box with plain-text debug info
local copyFrame = nil

local function ShowCopyPopup()
    if not copyFrame then
        local f = CreateFrame("Frame", "HoldToCastFixCopyFrame", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(480, 400)
        f:SetPoint("CENTER")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("FULLSCREEN_DIALOG")

        -- Title
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        f.title:SetPoint("TOP", f, "TOP", 0, -6)
        f.title:SetText("Copy Debug Info")

        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -26)
        hint:SetTextColor(0.7, 0.7, 0.7)
        hint:SetText("Press Ctrl+A then Ctrl+C to copy")

        local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -42)
        scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 10)

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(true)
        editBox:SetFontObject("GameFontHighlightSmall")
        editBox:SetWidth(scrollFrame:GetWidth() - 10)
        editBox:SetScript("OnEscapePressed", function() f:Hide() end)
        scrollFrame:SetScrollChild(editBox)

        f.editBox = editBox

        -- ElvUI Skinning
        SkinFrame(f)
        if S then
            if scrollFrame.ScrollBar then
                S:HandleScrollBar(scrollFrame.ScrollBar)
            end
        end

        copyFrame = f
    end

    local lines = BuildDebugLines(true)
    local text = table.concat(lines, "\n")

    copyFrame.editBox:SetText(text)
    copyFrame:Show()
    copyFrame.editBox:HighlightText()
    copyFrame.editBox:SetFocus()
end

ns.ShowCopyPopup = ShowCopyPopup

local function CreateDebugPanel(parent)
    local frame = CreateFrame("Frame", "HoldToCastFixDebugFrame", parent, "BasicFrameTemplateWithInset")
    frame:SetSize(360, parent:GetHeight())
    frame:SetPoint("TOPLEFT", parent, "TOPRIGHT", -1, 0)
    frame:SetMovable(false)
    frame:EnableMouse(true)
    frame:SetFrameStrata("DIALOG")

    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -6)
    frame.title:SetText("Debug")

    -- Buttons first, so scroll frame can anchor above them
    -- Copy button at bottom-left
    local copyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    copyBtn:SetSize(70, 22)
    copyBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
    copyBtn:SetText("Copy")
    copyBtn:SetScript("OnClick", function() ns.ShowCopyPopup() end)

    -- Refresh button at bottom-right
    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(70, 22)
    refreshBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function() ns.RefreshDebugPanel() end)

    -- Scroll frame, anchored above buttons
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -26)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 36)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() - 4)
    scrollChild:SetHeight(1) -- will be resized by content
    scrollFrame:SetScrollChild(scrollChild)
    debugScrollChild = scrollChild

    local text = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 4, -4)
    text:SetPoint("RIGHT", scrollChild, "RIGHT", -4, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    text:SetSpacing(2)
    debugText = text

    -- ElvUI Skinning
    SkinFrame(frame)
    if S then
        S:HandleButton(copyBtn)
        S:HandleButton(refreshBtn)
        if scrollFrame.ScrollBar then
            S:HandleScrollBar(scrollFrame.ScrollBar)
        end
    end

    -- Auto-refresh on show
    frame:SetScript("OnShow", function()
        frame:SetHeight(parent:GetHeight())
        scrollChild:SetWidth(scrollFrame:GetWidth() - 4)
        ns.RefreshDebugPanel()
    end)

    -- Live-update timer while visible
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= 0.5 then
            self.elapsed = 0
            ns.RefreshDebugPanel()
        end
    end)

    return frame
end

function ns.ToggleDebug()
    if not configFrame then
        configFrame = CreateConfigPanel()
    end
    if not debugFrame then
        debugFrame = CreateDebugPanel(configFrame)
        debugFrame:Hide()
    end
    if debugFrame:IsShown() then
        debugFrame:Hide()
    else
        if not configFrame:IsShown() then
            configFrame:Show()
        end
        debugFrame:Show()
    end
end

function ns.ToggleConfig()
    if not configFrame then
        configFrame = CreateConfigPanel()
    end
    if configFrame:IsShown() then
        configFrame:Hide()
        if debugFrame then debugFrame:Hide() end
    else
        configFrame:Show()
    end
end
