controllerNpcTrader = Controller:new()
controllerNpcTrader.widthConsole = controllerNpcTrader.DEFAULT_CONSOLE_WIDTH
controllerNpcTrader.creatureName = ""
controllerNpcTrader.outfit = nil
controllerNpcTrader.buttons = {}
controllerNpcTrader.isTradeOpen = false
controllerNpcTrader.legacyMode = false
controllerNpcTrader.npcTalkConnected = false
controllerNpcTrader.rashidTrade = false
controllerNpcTrader.rashidBlacklist = {}
controllerNpcTrader.rashidSellConfirmWindow = nil
controllerNpcTrader.rashidSellQueue = nil
controllerNpcTrader.rashidSellEvent = nil
controllerNpcTrader.rashidSellActive = false
controllerNpcTrader.rashidSellSessionId = 0
controllerNpcTrader.rashidSellIndex = 0
controllerNpcTrader.rashidSellTotal = 0

local RASHID_SELL_DELAY = 180

local RASHID_BLACKLIST_SETTINGS = 'RashidTradeBlacklists'

local function safeSettingsPart(value)
    return tostring(value or ''):lower():gsub('[^%w_-]', '_')
end

function controllerNpcTrader:getRashidBlacklistOwner()
    return safeSettingsPart(g_game.getWorldName()) .. ':' .. safeSettingsPart(g_game.getCharacterName())
end

function controllerNpcTrader:loadRashidBlacklist()
    self.rashidBlacklist = {}
    local all = g_settings.getNode(RASHID_BLACKLIST_SETTINGS) or {}
    local saved = all[self:getRashidBlacklistOwner()] or {}
    for _, itemId in pairs(saved) do
        itemId = tonumber(itemId)
        if itemId and itemId > 0 then
            self.rashidBlacklist[itemId] = true
        end
    end
end

function controllerNpcTrader:saveRashidBlacklist()
    local saved = {}
    for itemId, blocked in pairs(self.rashidBlacklist or {}) do
        if blocked then
            table.insert(saved, itemId)
        end
    end
    table.sort(saved)
    local all = g_settings.getNode(RASHID_BLACKLIST_SETTINGS) or {}
    all[self:getRashidBlacklistOwner()] = saved
    g_settings.setNode(RASHID_BLACKLIST_SETTINGS, all)
    g_settings.save()
end

function controllerNpcTrader:isRashidItemBlocked(itemId)
    return self.rashidTrade and self.rashidBlacklist and self.rashidBlacklist[itemId] == true
end

function controllerNpcTrader:isRashidBlacklistId(itemId)
    return self.rashidBlacklist and self.rashidBlacklist[tonumber(itemId)] == true
end

function controllerNpcTrader:setRashidItemBlocked(itemId, blocked)
    itemId = tonumber(itemId)
    if not itemId then
        return
    end
    self.rashidBlacklist[itemId] = blocked and true or nil
    self:saveRashidBlacklist()
    self.selectedItem = nil
    if self:isLegacyMode() then
        if isTradingLegacy and isTradingLegacy() then
            refreshTradeItems()
            refreshPlayerGoods()
        end
    else
        self:updateListSource()
    end
end

function controllerNpcTrader:getRashidSellSummary()
    local itemTypes = 0
    local itemCount = 0
    for _, entry in ipairs(self.sellItems or {}) do
        local itemId = entry.ptr:getId()
        if not self:isRashidItemBlocked(itemId) then
            local quantity = self:getSellQuantity(entry.ptr)
            if quantity > 0 then
                itemTypes = itemTypes + 1
                itemCount = itemCount + quantity
            end
        end
    end
    return itemTypes, itemCount
end

function controllerNpcTrader:confirmRashidSellAll()
    if not self.rashidTrade or self.tradeMode ~= self.SELL or self.rashidSellConfirmWindow then
        return
    end
    local itemTypes, itemCount = self:getRashidSellSummary()
    if itemCount == 0 then
        displayInfoBox('Rashid', 'You have no unblocked items to sell.')
        return
    end

    local function closeConfirmation()
        if self.rashidSellConfirmWindow then
            self.rashidSellConfirmWindow:destroy()
            self.rashidSellConfirmWindow = nil
        end
    end
    local function confirm()
        closeConfirmation()
        self:sellAll(true)
    end
    self.rashidSellConfirmWindow = displayGeneralBox('Sell all to Rashid',
        string.format('Sell %d item(s) from %d type(s)?\nBlacklisted and equipped items will be ignored. Prices are calculated by the server.',
            itemCount, itemTypes), {
            { text = 'Sell', callback = confirm },
            { text = 'Cancel', callback = closeConfirmation },
            anchor = AnchorHorizontalCenter
        }, confirm, closeConfirmation)
end

function controllerNpcTrader:isRashidShopStillOpen(expectedNpcName, legacyMode)
    if not g_game.isOnline() or not self.isTradeOpen or not self.rashidTrade then
        return false
    end
    if self.shopNpcName ~= expectedNpcName or expectedNpcName ~= 'Rashid' then
        return false
    end
    if legacyMode then
        return isTradingLegacy and isTradingLegacy() or false
    end
    return self.ui and self.ui:isVisible() or false
end

function controllerNpcTrader:updateRashidSellProgress(state, message)
    if state and state.updateProgress then
        state.updateProgress(state.index - 1, state.total, message, self.rashidSellActive)
    end
end

function controllerNpcTrader:resetSellAllState()
    if self.rashidSellEvent then
        removeEvent(self.rashidSellEvent)
        self.rashidSellEvent = nil
    end
    if self.sellAllWithDelayEvent then
        removeEvent(self.sellAllWithDelayEvent)
        self.sellAllWithDelayEvent = nil
    end
    self.rashidSellSessionId = (self.rashidSellSessionId or 0) + 1
    self.rashidSellQueue = nil
    self.rashidSellActive = false
    self.rashidSellIndex = 0
    self.rashidSellTotal = 0

    if resetRashidSellAllLegacy then resetRashidSellAllLegacy() end
    if self.resetRashidSellAllModern then self:resetRashidSellAllModern() end
end

function controllerNpcTrader:cancelRashidSellQueue(message, silent)
    local wasActive = self.rashidSellActive
    self:resetSellAllState()
    if wasActive and not silent and modules.game_textmessage then
        modules.game_textmessage.displayStatusMessage(message or 'Selling cancelled.')
    end
end

function controllerNpcTrader:finishRashidSellQueue()
    local state = self.rashidSellQueue
    if not state then return end
    self:resetSellAllState()
    if state.legacyMode then
        if refreshPlayerGoods then refreshPlayerGoods() end
    elseif self.refreshPlayerGoods then
        self:refreshPlayerGoods(true)
    end
    if modules.game_textmessage then
        modules.game_textmessage.displayStatusMessage('Selling complete.')
    end
end

function controllerNpcTrader:processRashidSellQueue(expectedSessionId)
    self.rashidSellEvent = nil
    local state = self.rashidSellQueue
    if not self.rashidSellActive or not state or expectedSessionId ~= self.rashidSellSessionId or
            state.sessionId ~= expectedSessionId then return end

    if not self:isRashidShopStillOpen(state.npcName, state.legacyMode) then
        self:cancelRashidSellQueue('Selling cancelled.', true)
        return
    end

    local entry = state.entries[state.index]
    if not entry then
        self:finishRashidSellQueue()
        return
    end

    local currentAmount = math.max(0, tonumber(state.getQuantity(entry.ptr)) or 0)
    local remaining = math.max(0, tonumber(entry.remaining) or 0)
    if currentAmount <= 0 or remaining <= 0 or self:isRashidItemBlocked(entry.itemId) then
        state.index = state.index + 1
        self.rashidSellIndex = state.index
        self:updateRashidSellProgress(state, string.format('Selling %d/%d...',
            math.min(state.index, state.total), state.total))
        self.rashidSellEvent = scheduleEvent(function()
            self:processRashidSellQueue(expectedSessionId)
        end, RASHID_SELL_DELAY)
        return
    end

    local maximum = g_game.getFeature(GameDoubleShopSellAmount) and 10000 or 100
    local amount = math.min(currentAmount, remaining, maximum, 65535)
    self:updateRashidSellProgress(state, string.format('Selling %d/%d...', state.index, state.total))
    g_game.sellItem(entry.ptr, amount, state.getIgnoreEquipped())

    -- Keep large stacks on the same item type until the snapshotted amount has
    -- been processed. The live quantity still caps every individual request.
    entry.remaining = remaining - amount
    if entry.remaining <= 0 then
        state.index = state.index + 1
        self.rashidSellIndex = state.index
    end
    self.rashidSellEvent = scheduleEvent(function()
        self:processRashidSellQueue(expectedSessionId)
    end, RASHID_SELL_DELAY)
end

function controllerNpcTrader:startRashidSellQueue(entries, legacyMode, getQuantity, getIgnoreEquipped,
                                                   updateProgress, onFinish)
    if self.rashidSellActive or not self.rashidTrade or self.shopNpcName ~= 'Rashid' then
        return false
    end

    local snapshot = {}
    for _, entry in ipairs(entries or {}) do
        if entry and entry.ptr and (not entry.ptr.getTier or (entry.ptr:getTier() or 0) == 0) and
                not self:isRashidItemBlocked(entry.ptr:getId()) then
            local amount = math.max(0, tonumber(getQuantity(entry.ptr)) or 0)
            if amount > 0 then
                table.insert(snapshot, {
                    ptr = entry.ptr,
                    itemId = entry.ptr:getId(),
                    subType = entry.ptr:getSubType(),
                    remaining = amount
                })
            end
        end
    end

    if #snapshot == 0 then
        return false
    end

    self.rashidSellActive = true
    local sessionId = self.rashidSellSessionId
    self.rashidSellIndex = 1
    self.rashidSellTotal = #snapshot
    self.rashidSellQueue = {
        entries = snapshot,
        index = 1,
        total = #snapshot,
        npcName = self.shopNpcName,
        legacyMode = legacyMode == true,
        getQuantity = getQuantity,
        getIgnoreEquipped = getIgnoreEquipped,
        updateProgress = updateProgress,
        onFinish = onFinish,
        sessionId = sessionId
    }
    self:updateRashidSellProgress(self.rashidSellQueue,
        string.format('Selling 1/%d...', #snapshot))
    self:processRashidSellQueue(sessionId)
    return true
end

function controllerNpcTrader:isLegacyMode()
    return self.legacyMode
end

function controllerNpcTrader:onInit()

end

function controllerNpcTrader:onGameStart()
    self:loadRashidBlacklist()
    self.legacyMode = not g_game.getFeature(GameNpcWindowRedesign)
    -- The legacy window is also reused as Rashid's detailed Sell All view.
    self:legacy_init()

    self:registerEvents(g_game, {
        onNpcChatWindow = function(data)
            onNpcChatWindow(data)
        end,
        onOpenNpcTrade = function(...)
            self:resetSellAllState()
            self:startEquippedImbuementsTracking()
            if self:isLegacyMode() then
                self.isTradeOpen = true
                onOpenNpcTrade(...)
            else
                local items, currencyId, currencyName, npcName = ...
                self:onOpenNpcTrade(items, currencyId, currencyName, npcName)
                if self.rashidTrade then
                    onOpenNpcTrade(items, currencyId, currencyName, npcName, true)
                end
            end
        end,
        onPlayerGoods = function(money, items)
            if self:isLegacyMode() then
                onPlayerGoods(money, items)
            else
                self:onPlayerGoods(money, items)
                if self.rashidTrade then
                    onPlayerGoods(money, items)
                end
            end
        end,
        onUpdateImbuementTracker = function(items)
            self:onUpdateEquippedImbuements(items)
        end,
        onNpcChatWindowClose = function()
            self:stopEquippedImbuementsTracking()
            if self:isLegacyMode() then
                self.isTradeOpen = false
                self:cancelRashidSellQueue('Selling cancelled.', true)
                self:legacy_hide()
            else
                self:onCloseNpcTrade()
            end
        end,
        onCloseNpcTrade = function()
            self:stopEquippedImbuementsTracking()
            if self:isLegacyMode() then
                self.isTradeOpen = false
                self:cancelRashidSellQueue('Selling cancelled.', true)
                self:legacy_hide()
            else
                self:onCloseNpcTrade()
            end
        end
    })
end

function isRashidBlacklisted(itemId)
    return controllerNpcTrader:isRashidBlacklistId(itemId)
end

function addRashidBlacklistItem(itemId)
    controllerNpcTrader:setRashidItemBlocked(itemId, true)
end

function removeRashidBlacklistItem(itemId)
    controllerNpcTrader:setRashidItemBlocked(itemId, false)
end

function controllerNpcTrader:connectNpcTalkEvent()
    if self:isLegacyMode() or self.npcTalkConnected then
        return
    end

    connect(g_game, {
        onTalk = onNpcTalk
    })
    self.npcTalkConnected = true
end

function controllerNpcTrader:disconnectNpcTalkEvent()
    if not self.npcTalkConnected then
        return
    end

    disconnect(g_game, {
        onTalk = onNpcTalk
    })
    self.npcTalkConnected = false
end

function controllerNpcTrader:onTerminate()
    self:resetSellAllState()
    if not self:isLegacyMode() then
        self:onCloseNpcTrade()
    end
    self:legacy_terminate()
end

function controllerNpcTrader:onGameEnd()
    self:resetSellAllState()
    if self:isLegacyMode() then
        self:legacy_hide()
    else
        self:onCloseNpcTrade()
    end
end

function controllerNpcTrader:onCloseNpcTrade()
    self:resetSellAllState()
    if self:isLegacyMode() then
        self:legacy_hide()
    else
        self:legacy_hideOverlay()
        self:disconnectNpcTalkEvent()
        if controllerNpcTrader.ui and controllerNpcTrader.ui:isVisible() then
            controllerNpcTrader:unloadHtml()
        end
        controllerNpcTrader.isTradeOpen = false
        if controllerNpcTrader.sellAllWithDelayEvent then
            removeEvent(controllerNpcTrader.sellAllWithDelayEvent)
            controllerNpcTrader.sellAllWithDelayEvent = nil
        end
        -- Clean up state
        controllerNpcTrader.buyItems = {}
        controllerNpcTrader.sellItems = {}
        controllerNpcTrader.playerItems = {}
        controllerNpcTrader.playerMoney = nil
        controllerNpcTrader.selectedItem = nil
        controllerNpcTrader.tradeItems = {}
        controllerNpcTrader.currentList = {}
        controllerNpcTrader.allTradeItems = {}
        controllerNpcTrader.rashidTrade = false
        controllerNpcTrader.rashidBlacklist = {}
        if controllerNpcTrader.rashidSellConfirmWindow then
            controllerNpcTrader.rashidSellConfirmWindow:destroy()
            controllerNpcTrader.rashidSellConfirmWindow = nil
        end
    end
end

function sellAll(...) -- Vbot Call
    if controllerNpcTrader:isLegacyMode() then
        sellAllLegacy(...)
    else
        controllerNpcTrader:sellAll(...)
    end
end

function isTrading(...) -- Vbot Call
    if controllerNpcTrader:isLegacyMode() then
        return isTradingLegacy(...)
    end

    return controllerNpcTrader.isTradeOpen == true
end

function getSellItems(...) -- Vbot Call
    if controllerNpcTrader:isLegacyMode() then
        return getSellItemsLegacy(...)
    end

    return controllerNpcTrader.sellItems or {}
end

function getBuyItems(...) -- Vbot Call
    if controllerNpcTrader:isLegacyMode() then
        return getBuyItemsLegacy(...)
    end

    return controllerNpcTrader.buyItems or {}
end

function getSellQuantity(item) -- Vbot Call
    if controllerNpcTrader:isLegacyMode() then
        return getSellQuantityLegacy(item)
    end

    if type(item) == 'number' then
        item = Item.create(item)
    end

    return controllerNpcTrader:getSellQuantity(item)
end

function canTradeItem(item) -- Vbot Call
    if controllerNpcTrader:isLegacyMode() then
        return canTradeItemLegacy(item)
    end

    if type(item) == 'number' then
        item = Item.create(item)
    end

    local tradeEntry = item
    if item and not item.ptr then
        for _, entry in ipairs(controllerNpcTrader.sellItems or {}) do
            if entry.ptr:getId() == item:getId() and entry.ptr:getSubType() == item:getSubType() then
                tradeEntry = entry
                break
            end
        end

        if tradeEntry == item then
            for _, entry in ipairs(controllerNpcTrader.buyItems or {}) do
                if entry.ptr:getId() == item:getId() and entry.ptr:getSubType() == item:getSubType() then
                    tradeEntry = entry
                    break
                end
            end
        end
    end

    if not tradeEntry or not tradeEntry.ptr then
        return false
    end

    return controllerNpcTrader:canTradeItem(tradeEntry)
end

function closeNpcTrade(...) -- Vbot Call
    if controllerNpcTrader:isLegacyMode() then
        return closeNpcTradeLegacy(...)
    end

    return g_game.closeNpcTrade()
end
