local showHighlightedUnderline = false
local NPC_DIALOG_HEADER_COLOR = "white"

local function getHighlightedText(text, color, highlightColor)
    color = color or "white"
    highlightColor = highlightColor or "#1f9ffe"
    local firstBrace = text:find("{", 1, true)
    if not firstBrace then
        return string.format("{%s, %s}", text, color)
    end
    local parts = {}
    local lastPos = 1
    for startPos, content, endPos in text:gmatch("()%{([^}]*)%}()") do
        if startPos > lastPos then
            parts[#parts + 1] = string.format("{%s, %s}", text:sub(lastPos, startPos - 1), color)
        end
        local textPart = content:match("([^,]+)") or content
        local trimmed = textPart
        local highlighted = trimmed
        if showHighlightedUnderline then
            highlighted = string.format("[text-event]%s[/text-event]", trimmed)
        else
            highlighted = string.format("[text-event]%s%s[/text-event]", string.char(1), trimmed)
        end
        parts[#parts + 1] = string.format("{%s, %s}", highlighted, highlightColor)
        lastPos = endPos
    end
    if lastPos <= #text then
        parts[#parts + 1] = string.format("{%s, %s}", text:sub(lastPos), color)
    end
    return table.concat(parts)
end

local function createDialogLabel(consoleBuffer, entry)
    local label = g_ui.createWidget('ConsoleLabel', consoleBuffer)
    label:setId("consoleLabel" .. consoleBuffer:getChildCount())

    if entry.coloredData then
        label:setColoredText(entry.coloredData)
        label.coloredData = entry.coloredData
    else
        label:setText(entry.text or "")
    end

    if entry.color then
        label:setColor(entry.color)
    end

    if entry.name then
        label.name = entry.name
    end

    if entry.clickable and not label:hasEventListener(EVENT_TEXT_CLICK) then
        label:setEventListener(EVENT_TEXT_CLICK)
        connect(label, {
            onTextClick = function(w, t)
                controllerNpcTrader:onConsoleTextClicked(w, t)
            end
        })
    end

    return label
end

local function buildTalkingToEntry(npcName, timestamp)
    local prefix = timestamp and (timestamp .. " ") or ""
    return {
        text = prefix .. "talking to " .. npcName,
        color = NPC_DIALOG_HEADER_COLOR
    }
end

local function validNpcName(name)
    return type(name) == "string" and name ~= "" and name ~= "Unknown"
end

-- Resolve only the named NPC, never an arbitrary nearby creature/player.
function controllerNpcTrader:resolveNpcCreature(name, creature, position)
    local function matches(candidate)
        return candidate and candidate:isNpc() and
            (not validNpcName(name) or candidate:getName():lower() == name:lower())
    end
    if matches(creature) then return creature end
    if self.npcCreatureId then
        local known = g_map.getCreatureById(self.npcCreatureId)
        if matches(known) then return known end
    end
    local player = g_game.getLocalPlayer()
    local center = position or (player and player:getPosition())
    if center and validNpcName(name) then
        for _, candidate in ipairs(g_map.getSpectators(center, false)) do
            if matches(candidate) then return candidate end
        end
    end
end

function controllerNpcTrader:updateNpcIdentity(name, creature, position)
    if not validNpcName(name) and creature then name = creature:getName() end
    if not validNpcName(name) then name = self.creatureName end
    if validNpcName(name) and name ~= self.creatureName then
        self.outfit = nil
        self.npcCreatureId = nil
    end
    local npc = self:resolveNpcCreature(name, creature, position)
    if npc then
        name = npc:getName()
        self.npcCreatureId = npc:getId()
        self.outfit = npc:getOutfit()
    end
    self.creatureName = validNpcName(name) and name or "NPC"
    local label = self:findWidget("#npcName")
    if label then
        label:setText(short_text(self.creatureName, 30))
        label:setTooltip(self.creatureName)
    end
    local portrait = self:findWidget("#creatureOutfit")
    local fallback = self:findWidget("#npcPortraitFallback")
    local hasOutfit = type(self.outfit) == "table"
    if portrait then
        portrait:setImageSource("")
        portrait:setVisible(hasOutfit)
        if hasOutfit then portrait:setOutfit(self.outfit) end
    end
    if fallback then fallback:setVisible(not hasOutfit) end
    local buffer = self:findWidget("#consoleBuffer")
    local header = buffer and buffer:getChildByIndex(1)
    if header and header.npcDialogHeaderTime then
        header:setText(buildTalkingToEntry(self.creatureName, header.npcDialogHeaderTime).text)
    end
    return npc
end

function controllerNpcTrader:ensureDialogHeader(consoleBuffer)
    if not consoleBuffer or consoleBuffer:getChildCount() > 0 or not self.creatureName or self.creatureName == "" then
        return
    end

    local timestamp = os.date('%H:%M')
    local header = createDialogLabel(consoleBuffer, buildTalkingToEntry(self.creatureName, timestamp))
    header.npcDialogHeaderTime = timestamp
end

function controllerNpcTrader:onConsoleTextClicked(widget, text)
    if type(widget) == "string" and not text then
        text = widget
        widget = nil
    end

    if not text or text == "" then
        return
    end

    local npcTab = modules.game_console.consoleTabBar:getTab("NPCs")
    if npcTab then
        modules.game_console.sendMessage(text, npcTab)
        onNpcTalk(g_game.getCharacterName(), 0, MessageModes.NpcTo, text)
    end
    if text == "bye" then
        controllerNpcTrader:onCloseNpcTrade()
    end
end

function controllerNpcTrader:cloneConsoleMessages()
    local consoleBuffer = self:findWidget("#consoleBuffer")

    if consoleBuffer then
        consoleBuffer:destroyChildren()
        self:ensureDialogHeader(consoleBuffer)
    end
end

-- temp fix. can't drag the left panel to move the window.
function controllerNpcTrader:setupWindowDragBehavior()
    if not self.ui then
        return
    end
    local dragHandle = self:findWidget("#dragHandle")
    if not dragHandle then
        return
    end
    dragHandle:setDraggable(true)
    dragHandle.onDragEnter = function(widget, mousePos)
        return self.ui:onDragEnter(mousePos)
    end
    dragHandle.onDragMove = function(widget, mousePos, mouseMoved)
        self.ui:onDragMove(mousePos, mouseMoved)
        return true
    end
    dragHandle.onDragLeave = function(widget, droppedWidget, mousePos)
        self.ui:onDragLeave(droppedWidget, mousePos)
        return true
    end
end

function controllerNpcTrader:initNpcWindow(creature, buttons, npcName)
    if self:isLegacyMode() then
        return
    end
    self:connectNpcTalkEvent()
    self.widthConsole = self.DEFAULT_CONSOLE_WIDTH
    self.isTradeOpen = false
    self:updateNpcIdentity(npcName, creature)
    self.buttons = buttons or self.buttons or self.buttonsDefault
    self:updateChatButton()
    if not self.ui or not self.ui:isVisible() then
        self:loadHtml('templates/game_npctrader.html')
    end
    self:setupWindowDragBehavior()
    self:updateNpcIdentity(self.creatureName, creature)
    self:cloneConsoleMessages()
end

function onNpcChatWindow(data)
    if controllerNpcTrader:isLegacyMode() then
        controllerNpcTrader:legacy_show()
        return
    end
    if type(data) ~= "table" or type(data.npcIds) ~= "table" or #data.npcIds == 0 then
        return
    end
    local creature = g_map.getCreatureById(data.npcIds[1])
    if creature then
        controllerNpcTrader:initNpcWindow(creature, data.buttons)
    end
end

function controllerNpcTrader:onConsoleKeyPress(event)
    if event.value == KeyEnter then
        local input = controllerNpcTrader:findWidget(".inputConsole")
        if input then
            local text = input:getText()
            if text and #text > 0 then
                controllerNpcTrader:onConsoleTextClicked(nil, text)
                input:clearText()
            end
        end
    end
end

function onNpcTalk(name, level, mode, text, channelId, creaturePos)
    if mode == MessageModes.NpcFrom or mode == MessageModes.NpcFromStartBlock then
        controllerNpcTrader:updateNpcIdentity(name, nil, creaturePos)
    end
    if not controllerNpcTrader.ui or not controllerNpcTrader.ui:isVisible() then
        return
    end

    if mode == MessageModes.NpcTo or mode == MessageModes.NpcFrom or mode == MessageModes.NpcFromStartBlock then
        local consoleBuffer = controllerNpcTrader:findWidget("#consoleBuffer")
        if consoleBuffer then
            controllerNpcTrader:ensureDialogHeader(consoleBuffer)
            local consoleModule = modules.game_console
            local SpeakTypes = consoleModule and consoleModule.SpeakTypes or {}
            local color = '#5FF7F7'
            if SpeakTypes[mode] and SpeakTypes[mode].color then
                color = SpeakTypes[mode].color
            end
            local fullText = text
            if mode == MessageModes.NpcFrom or mode == MessageModes.NpcFromStartBlock then
                fullText = name .. " says: " .. text
            elseif mode == MessageModes.NpcTo then
                fullText = name .. ": " .. text
            end
            local entry = {
                text = fullText,
                color = color,
                name = mode == MessageModes.NpcTo and g_game.getCharacterName() or name,
                clickable = true
            }
            if getHighlightedText then
                entry.coloredData = getHighlightedText(fullText, color, "#1f9ffe")
            end
            createDialogLabel(consoleBuffer, entry)
        end
    end
end

function controllerNpcTrader:updateChatButton()
    local isChatEnabled = modules.game_console.isChatEnabled()
    self.chatMode = isChatEnabled and tr('Chat On') or tr('Chat Off')
    local inputConsole = self:findWidget(".inputConsole")
    if inputConsole then
        inputConsole:setEnabled(isChatEnabled)
    end
end

function controllerNpcTrader:toggleChatMode()
    modules.game_console.toggleChat()
    self:updateChatButton()
end
