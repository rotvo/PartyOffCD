local _, PartyOffCDCore = ...
PartyOffCDCore = PartyOffCDCore or _G.PartyOffCDCore

local PartyOffCD = _G.PartyOffCD
assert(PartyOffCD, "PartyOffCD: frame missing before loading ConfigUI.lua")
assert(PartyOffCDCore, "PartyOffCD: core missing before loading ConfigUI.lua")

local CLASS_ORDER = PartyOffCDCore.CLASS_ORDER
local SPELLS = PartyOffCDCore.SPELLS
local DB_DEFAULTS = PartyOffCDCore.DEFAULTS
local PREFIX = PartyOffCDCore.PREFIX
local MINIMAP_RADIUS = PartyOffCDCore.MINIMAP_RADIUS

local DebugPrint = PartyOffCDCore.DebugPrint
local SafeGetSpellInfo = PartyOffCDCore.SafeGetSpellInfo
local GetNextSpellType = PartyOffCDCore.GetNextSpellType
local CreateCheckbox = PartyOffCDCore.CreateCheckbox
local CreateNumericEditBox = PartyOffCDCore.CreateNumericEditBox

function PartyOffCD:CreateConfigPanel()
    if self.configPanel then
        return
    end

    local frame = CreateFrame("Frame", "PartyOffCDConfigPanel", UIParent)
    frame:SetSize(420, 470)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = selfFrame:GetPoint(1)
        PartyOffCD.db.configPoint = point
        PartyOffCD.db.configRelativePoint = relativePoint
        PartyOffCD.db.configX = x
        PartyOffCD.db.configY = y
    end)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.06, 0.92)

    local borderTop = frame:CreateTexture(nil, "BORDER")
    borderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borderTop:SetHeight(2)
    borderTop:SetColorTexture(0.2, 0.7, 0.95, 0.9)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    title:SetText("PartyOffCD Configuration")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -34)
    subtitle:SetText("Configure cooldowns, interrupts, and missing buffs.")

    local tabDefs = {
        { id = "cds", label = "Cooldowns" },
        { id = "interrupts", label = "Interrupts" },
        { id = "buffs", label = "Missing Buffs" },
    }
    frame.tabs = {}
    for index, tabDef in ipairs(tabDefs) do
        local tab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        tab:SetSize(110, 20)
        tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 12 + ((index - 1) * 114), -56)
        tab:SetText(tabDef.label)
        tab.id = tabDef.id
        tab:SetScript("OnClick", function(selfTab)
            frame.activeTab = selfTab.id
            PartyOffCD:RefreshConfigPanel()
        end)
        frame.tabs[#frame.tabs + 1] = tab
    end

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instructions:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -82)
    instructions:SetText("")
    frame.instructions = instructions

    local scrollFrame = CreateFrame("ScrollFrame", "PartyOffCDConfigScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -104)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 12)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(360, 1)
    scrollFrame:SetScrollChild(content)

    frame.scrollFrame = scrollFrame
    frame.content = content
    frame.activeTab = "cds"
    frame:Hide()

    local db = self.db or DB_DEFAULTS
    frame:SetPoint(db.configPoint or DB_DEFAULTS.configPoint, UIParent, db.configRelativePoint or DB_DEFAULTS.configRelativePoint, db.configX or DB_DEFAULTS.configX, db.configY or DB_DEFAULTS.configY)

    self.configPanel = frame
    self:RefreshConfigPanel()
end

function PartyOffCD:RefreshConfigPanel()
    if not self.configPanel then
        return
    end

    local frame = self.configPanel
    local content = frame.content

    for _, widget in ipairs(self.configRows) do
        widget:Hide()
        widget:SetParent(UIParent)
    end
    wipe(self.configRows)

    local y = -4
    local activeTab = frame.activeTab or "cds"

    for _, tab in ipairs(frame.tabs or {}) do
        local isActive = tab.id == activeTab
        tab:SetEnabled(not isActive)
        tab:SetAlpha(isActive and 1 or 0.7)
    end

    if activeTab == "interrupts" then
        if frame.instructions then
            frame.instructions:SetText("Interrupt window controls.")
        end

        local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        header:SetText("Interrupts")
        self.configRows[#self.configRows + 1] = header
        y = y - 26

        local showHide = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        showHide:SetSize(78, 20)
        showHide:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        showHide:SetText((self.db.interruptHidden and "Show") or "Hide")
        showHide:SetScript("OnClick", function()
            PartyOffCD:SetInterruptHidden(not PartyOffCD.db.interruptHidden)
            PartyOffCD:RefreshConfigPanel()
        end)
        self.configRows[#self.configRows + 1] = showHide

        local lock = CreateCheckbox(nil, content, "Lock")
        lock:SetPoint("LEFT", showHide, "RIGHT", 14, 0)
        lock:SetChecked(self.db.interruptLocked == true)
        lock:SetScript("OnClick", function(selfCheck)
            PartyOffCD:SetInterruptLocked(selfCheck:GetChecked())
        end)
        self.configRows[#self.configRows + 1] = lock
        y = y - 24

        local hint = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        hint:SetText("Locked: no frame background/title, only interrupt bars.")
        self.configRows[#self.configRows + 1] = hint

        content:SetHeight(88)
        return
    end

    if activeTab == "buffs" then
        if frame.instructions then
            frame.instructions:SetText("Missing buffs window controls.")
        end

        local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        header:SetText("Missing Buffs")
        self.configRows[#self.configRows + 1] = header
        y = y - 26

        local showHide = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        showHide:SetSize(78, 20)
        showHide:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        showHide:SetText((self.db.missingBuffsHidden and "Show") or "Hide")
        showHide:SetScript("OnClick", function()
            PartyOffCD:SetMissingBuffsHidden(not PartyOffCD.db.missingBuffsHidden)
            PartyOffCD:RefreshConfigPanel()
        end)
        self.configRows[#self.configRows + 1] = showHide

        local lock = CreateCheckbox(nil, content, "Lock")
        lock:SetPoint("LEFT", showHide, "RIGHT", 14, 0)
        lock:SetChecked(self.db.missingBuffsLocked == true)
        lock:SetScript("OnClick", function(selfCheck)
            PartyOffCD:SetMissingBuffsLocked(selfCheck:GetChecked())
        end)
        self.configRows[#self.configRows + 1] = lock
        y = y - 24

        local hint = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        hint:SetText("Locked: no frame background/title, only buff icons + MISSING.")
        self.configRows[#self.configRows + 1] = hint

        content:SetHeight(88)
        return
    end

    if frame.instructions then
        frame.instructions:SetText("Use + to add a spell to that class. Edit/Save changes your personal CD and syncs it automatically.")
    end

    for _, classToken in ipairs(CLASS_ORDER) do
        local spellList = {}
        for spellID, meta in pairs(SPELLS) do
            if meta.class == classToken then
                spellList[#spellList + 1] = spellID
            end
        end

        if #spellList > 0 then
            table.sort(spellList, function(a, b)
                local aName = SafeGetSpellInfo(a)
                local bName = SafeGetSpellInfo(b)
                aName = aName or tostring(a)
                bName = bName or tostring(b)
                return aName < bName
            end)

            local classCheck = CreateCheckbox(nil, content, "")
            classCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            classCheck:SetChecked(self.db.classEnabled[classToken] ~= false)
            classCheck:SetScript("OnClick", function(selfCheck)
                PartyOffCD:SetClassEnabled(classToken, selfCheck:GetChecked())
            end)
            self.configRows[#self.configRows + 1] = classCheck

            local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header:SetPoint("LEFT", classCheck, "RIGHT", 6, 0)
            header:SetText(self:GetClassLabel(classToken))
            self.configRows[#self.configRows + 1] = header

            local addButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            addButton:SetSize(22, 18)
            addButton:SetPoint("TOPLEFT", content, "TOPLEFT", 230, y + 1)
            addButton:SetText(self.classAddEditorState[classToken] and "-" or "+")
            addButton:SetScript("OnClick", function()
                PartyOffCD.classAddEditorState[classToken] = not PartyOffCD.classAddEditorState[classToken]
                PartyOffCD:RefreshConfigPanel()
            end)
            self.configRows[#self.configRows + 1] = addButton

            y = y - 26

            if self.classAddEditorState[classToken] then
                local spellIDBox = CreateNumericEditBox(nil, content, 52, 8)
                spellIDBox:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
                spellIDBox:SetText("")
                self.configRows[#self.configRows + 1] = spellIDBox

                local spellIDLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                spellIDLabel:SetPoint("LEFT", spellIDBox, "RIGHT", 4, 0)
                spellIDLabel:SetText("ID")
                self.configRows[#self.configRows + 1] = spellIDLabel

                local cdBox = CreateNumericEditBox(nil, content, 38, 5)
                cdBox:SetPoint("LEFT", spellIDLabel, "RIGHT", 10, 0)
                cdBox:SetText("90")
                self.configRows[#self.configRows + 1] = cdBox

                local cdLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                cdLabel:SetPoint("LEFT", cdBox, "RIGHT", 4, 0)
                cdLabel:SetText("CD")
                self.configRows[#self.configRows + 1] = cdLabel

                local typeButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                typeButton:SetSize(42, 18)
                typeButton:SetPoint("LEFT", cdLabel, "RIGHT", 10, 0)
                typeButton:SetText("OFF")
                typeButton.currentType = "OFF"
                typeButton:SetScript("OnClick", function(selfButton)
                    selfButton.currentType = GetNextSpellType(selfButton.currentType)
                    selfButton:SetText(selfButton.currentType)
                end)
                self.configRows[#self.configRows + 1] = typeButton

                local saveNewButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                saveNewButton:SetSize(42, 18)
                saveNewButton:SetPoint("LEFT", typeButton, "RIGHT", 6, 0)
                saveNewButton:SetText("Save")
                saveNewButton:SetScript("OnClick", function()
                    if PartyOffCD:AddCustomSpell(classToken, spellIDBox:GetText(), cdBox:GetText(), typeButton.currentType) then
                        PartyOffCD.classAddEditorState[classToken] = false
                        PartyOffCD:RefreshConfigPanel()
                    end
                end)
                self.configRows[#self.configRows + 1] = saveNewButton

                y = y - 24
            end

            for _, spellID in ipairs(spellList) do
                local spellName, texture = SafeGetSpellInfo(spellID)
                local meta = self:GetDisplayMeta(spellID) or SPELLS[spellID]

                local spellCheck = CreateCheckbox(nil, content, "")
                spellCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
                spellCheck:SetChecked(self:IsSpellEnabled(spellID))
                spellCheck:SetEnabled(self.db.classEnabled[classToken] ~= false)
                spellCheck:SetScript("OnClick", function(selfCheck)
                    PartyOffCD:SetSpellEnabled(spellID, selfCheck:GetChecked())
                end)
                self.configRows[#self.configRows + 1] = spellCheck

                local icon = content:CreateTexture(nil, "ARTWORK")
                icon:SetSize(18, 18)
                icon:SetPoint("LEFT", spellCheck, "RIGHT", 2, 0)
                icon:SetTexture(texture or 134400)
                self.configRows[#self.configRows + 1] = icon

                local label = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
                local playerOverride = self:GetPlayerOverride(spellID, self:GetPlayerCanonical())
                local customSuffix = meta.custom and ", custom" or ""
                local overrideSuffix = playerOverride and ", override" or ""
                label:SetWidth(155)
                label:SetJustifyH("LEFT")
                label:SetText(string.format("%s (%ss, id %d%s%s)", spellName or ("Spell " .. spellID), meta.cd, spellID, customSuffix, overrideSuffix))
                if self.db.classEnabled[classToken] == false then
                    label:SetTextColor(0.55, 0.55, 0.55)
                else
                    label:SetTextColor(0.9, 0.9, 0.9)
                end
                self.configRows[#self.configRows + 1] = label

                local editButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                editButton:SetSize(40, 18)
                editButton:SetPoint("TOPLEFT", content, "TOPLEFT", 215, y + 1)
                editButton:SetText("Edit")
                self.configRows[#self.configRows + 1] = editButton

                local editBox = CreateNumericEditBox(nil, content, 34, 5)
                editBox:SetPoint("TOPLEFT", content, "TOPLEFT", 259, y)
                editBox:SetText(tostring(meta.cd))
                editBox:Hide()
                self.configRows[#self.configRows + 1] = editBox

                local saveButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                saveButton:SetSize(42, 18)
                saveButton:SetPoint("TOPLEFT", content, "TOPLEFT", 299, y + 1)
                saveButton:SetText("Save")
                saveButton:Hide()
                self.configRows[#self.configRows + 1] = saveButton

                editButton:SetScript("OnClick", function()
                    editBox:SetText(tostring((PartyOffCD:GetDisplayMeta(spellID) or meta).cd))
                    editBox:Show()
                    saveButton:Show()
                end)

                saveButton:SetScript("OnClick", function()
                    local newCooldown = tonumber(editBox:GetText())
                    if not newCooldown or newCooldown <= 0 then
                        DebugPrint("Enter a valid CD in seconds.")
                        return
                    end

                    if PartyOffCD:AddCustomSpell(meta.class, spellID, newCooldown, meta.type) then
                        editBox:Hide()
                        saveButton:Hide()
                    end
                end)

                y = y - 22
            end

            y = y - 8
        end
    end

    content:SetHeight(math.max(1, -y + 8))
end

function PartyOffCD:ToggleConfigPanel()
    self:CreateConfigPanel()
    if self.configPanel:IsShown() then
        self.configPanel:Hide()
    else
        self:RefreshConfigPanel()
        self.configPanel:Show()
    end
end

function PartyOffCD:UpdateMinimapButtonPosition()
    if not self.minimapButton then
        return
    end

    local angle = self.db.minimap.angle or 220
    local radians = math.rad(angle)
    local x = math.cos(radians) * MINIMAP_RADIUS
    local y = math.sin(radians) * MINIMAP_RADIUS
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function PartyOffCD:RefreshMinimapButton()
    if not self.minimapButton then
        return
    end

    self.minimapButton:Show()
    self:UpdateMinimapButtonPosition()
end

function PartyOffCD:CreateMinimapButton()
    if self.minimapButton then
        return
    end

    local button = CreateFrame("Button", "PartyOffCDMinimapButton", Minimap)
    button:SetSize(30, 30)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.85)
    button.bg = bg

    local border = button:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    border:SetHeight(1)
    border:SetColorTexture(0.95, 0.82, 0.2, 0.95)
    button.border = border

    local texture = button:CreateTexture(nil, "ARTWORK")
    texture:SetSize(18, 18)
    texture:SetPoint("CENTER", button, "CENTER", 0, 0)
    texture:SetTexture(136116)
    button.icon = texture

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnClick", function()
        PartyOffCD:ToggleConfigPanel()
    end)

    button:SetScript("OnDragStart", function()
        button.isDragging = true
    end)

    button:SetScript("OnDragStop", function()
        button.isDragging = false
    end)

    button:SetScript("OnUpdate", function(selfButton)
        if not selfButton.isDragging then
            return
        end

        local mx, my = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = Minimap:GetCenter()
        local dx = (mx / scale) - cx
        local dy = (my / scale) - cy
        local angle = math.deg(math.atan2(dy, dx))
        PartyOffCD.db.minimap.angle = angle
        PartyOffCD:UpdateMinimapButtonPosition()
    end)

    button:SetScript("OnEnter", function(selfButton)
        GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
        GameTooltip:AddLine("PartyOffCD")
        GameTooltip:AddLine("Click: configuration", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: move icon", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.minimapButton = button
    self:RefreshMinimapButton()
end

function PartyOffCD:RunTest()
    local samples = { 31884, 97462, 190319 }
    for _, spellID in ipairs(samples) do
        if self:IsSpellEnabled(spellID) then
            self:ReportSpellUse(spellID, true)
        end
    end
    DebugPrint("Test triggered with sample local timers.")
end

function PartyOffCD:PrintConfig()
    local channel = self:GetTargetChannel() or "NONE"
    local inGroup = (IsInGroup() or IsInRaid()) and "yes" or "no"
    local configShown = (self.configPanel and self.configPanel:IsShown()) and "shown" or "hidden"
    local minimapShown = "shown"

    DebugPrint("Prefix: " .. PREFIX .. " | Channel: " .. channel .. " | InGroup: " .. inGroup)
    DebugPrint("Active spells: " .. tostring(self:GetEnabledSpellCount()) .. "/" .. tostring(self:GetSupportedSpellCount()))
    DebugPrint("Config: " .. configShown .. " | Minimap: " .. minimapShown)
    DebugPrint("Commands: /pocd use <spellID>, /pocd timer <spellID> <sec>, /pocd test, /pocd config, /pocd buffs, /pocd interrupts")
    DebugPrint("UI: Use + per class to add spells, and Edit/Save per row to keep your personal CD.")
end

function PartyOffCD:GetSupportedSpellCount()
    local count = 0
    for _ in pairs(SPELLS) do
        count = count + 1
    end
    return count
end

function PartyOffCD:GetEnabledSpellCount()
    local count = 0
    for spellID in pairs(SPELLS) do
        if self:IsSpellEnabled(spellID) then
            count = count + 1
        end
    end
    return count
end

function PartyOffCD:HandleSlashCommand(input)
    local command, rest = strsplit(" ", (input or ""), 2)
    command = string.lower(command or "")
    rest = rest and strtrim(rest) or ""

    if command == "use" then
        local spellID = tonumber(rest)
        if not spellID then
            DebugPrint("Usage: /pocd use <spellID>")
            return
        end

        self:ReportSpellUse(spellID)
        return
    end

    if command == "test" then
        self:RunTest()
        return
    end

    if command == "timer" then
        local spellIDText, remainingText = strsplit(" ", rest, 2)
        local spellID = tonumber(spellIDText)
        local remaining = tonumber(remainingText)
        if not spellID or remaining == nil then
            DebugPrint("Usage: /pocd timer <spellID> <remainingSeconds>")
            return
        end

        local playerKey = self:GetPlayerCanonical()
        if not playerKey then
            DebugPrint("Could not identify your character.")
            return
        end

        if not self:SetRemainingCooldown(playerKey, spellID, remaining) then
            DebugPrint("Could not adjust that timer.")
        end
        return
    end

    if command == "buffs" then
        self:SetMissingBuffsHidden(not self.db.missingBuffsHidden)
        if self.db.missingBuffsHidden then
            DebugPrint("Missing buffs window hidden.")
        else
            DebugPrint("Missing buffs window shown.")
        end
        return
    end

    if command == "interrupts" then
        self:SetInterruptHidden(not self.db.interruptHidden)
        if self.db.interruptHidden then
            DebugPrint("Interrupts window hidden.")
        else
            DebugPrint("Interrupts window shown.")
        end
        return
    end

    if command == "config" or command == "" then
        self:PrintConfig()
        self:ToggleConfigPanel()
        return
    end

    DebugPrint("Unknown command: " .. tostring(command))
    self:PrintConfig()
end

