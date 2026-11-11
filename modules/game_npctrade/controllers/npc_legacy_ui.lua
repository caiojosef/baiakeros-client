local BUY = 1
local SELL = 2
local BLACKLIST = 3

local function isTierlessTradeItem(item)
    return item and (not item.getTier or (item:getTier() or 0) == 0)
end

local CURRENCY = 'gold'
local CURRENCY_DECIMAL = false
local WEIGHT_UNIT = 'oz'
local LAST_INVENTORY = 10
local LARGE_STACK_BUY_NPCS = {
    galuna = true,
    xodet = true
}

local npcWindow = nil
local itemsPanel = nil
local radioTabs = nil
local radioItems = nil
local searchText = nil
local setupPanel = nil
local quantity = nil
local quantityScroll = nil
local nameLabel = nil
local priceLabel = nil
local moneyLabel = nil
local weightDesc = nil
local weightLabel = nil
local capacityDesc = nil
local capacityLabel = nil
local tradeButton = nil
local buyTab = nil
local sellTab = nil
local blacklistTab = nil
local initialized = false

local showWeight = true
local buyWithBackpack = nil
local ignoreCapacity = nil
local ignoreEquipped = nil
local showAllItems = nil
local sellAllButton = nil
local cancelSellAllButton = nil
local sellAllProgress = nil
local sellAllProgressLabel = nil

local playerFreeCapacity = 0
local playerMoney = 0
local tradeItems = {[BUY] = {}, [SELL] = {}}
local playerItems = {}
local selectedItem = nil

local cancelNextRelease = nil

function controllerNpcTrader:legacy_init()
    npcWindow = g_ui.displayUI('/game_npctrade/templates/npctrade_legacy')
    npcWindow:setVisible(false)

    itemsPanel = npcWindow:recursiveGetChildById('itemsPanel')
    searchText = npcWindow:recursiveGetChildById('searchText')

    setupPanel = npcWindow:recursiveGetChildById('setupPanel')
    quantityScroll = setupPanel:getChildById('quantityScroll')
    nameLabel = setupPanel:getChildById('name')
    priceLabel = setupPanel:getChildById('price')
    moneyLabel = setupPanel:getChildById('money')
    weightDesc = setupPanel:getChildById('weightDesc')
    weightLabel = setupPanel:getChildById('weight')
    capacityDesc = setupPanel:getChildById('capacityDesc')
    capacityLabel = setupPanel:getChildById('capacity')
    tradeButton = npcWindow:recursiveGetChildById('tradeButton')

    buyWithBackpack = npcWindow:recursiveGetChildById('buyWithBackpack')
    ignoreCapacity = npcWindow:recursiveGetChildById('ignoreCapacity')
    ignoreEquipped = npcWindow:recursiveGetChildById('ignoreEquipped')
    showAllItems = npcWindow:recursiveGetChildById('showAllItems')
    sellAllButton = npcWindow:recursiveGetChildById('sellAllButton')
    cancelSellAllButton = npcWindow:recursiveGetChildById('cancelSellAllButton')
    sellAllProgress = npcWindow:recursiveGetChildById('sellAllProgress')
    sellAllProgressLabel = npcWindow:recursiveGetChildById('sellAllProgressLabel')

    buyTab = npcWindow:getChildById('buyTab')
    sellTab = npcWindow:getChildById('sellTab')
    blacklistTab = npcWindow:getChildById('blacklistTab')

    radioTabs = UIRadioGroup.create()
    radioTabs:addWidget(buyTab)
    radioTabs:addWidget(sellTab)
    radioTabs:addWidget(blacklistTab)
    radioTabs:selectWidget(buyTab)
    radioTabs.onSelectionChange = onTradeTypeChange

    cancelNextRelease = false

    if g_game.isOnline() then
        playerFreeCapacity = g_game.getLocalPlayer():getFreeCapacity()
    end

    connect(LocalPlayer, {
        onFreeCapacityChange = onFreeCapacityChange,
        onInventoryChange = onInventoryChange
    })

    initialized = true
end

function controllerNpcTrader:legacy_terminate()
    initialized = false
    if npcWindow then
        npcWindow:destroy()
    end
    npcWindow = nil
    disconnect(LocalPlayer, {
        onFreeCapacityChange = onFreeCapacityChange,
        onInventoryChange = onInventoryChange
    })
end

function controllerNpcTrader:legacy_show()
    if g_game.isOnline() and npcWindow then
        if controllerNpcTrader.rashidTrade then
            radioTabs:selectWidget(sellTab)
        elseif tradeItems[BUY] and #tradeItems[BUY] > 0 then
            radioTabs:selectWidget(buyTab)
        else
            radioTabs:selectWidget(sellTab)
        end

        npcWindow:show()
        npcWindow:raise()
        npcWindow:focus()
    end
end

function controllerNpcTrader:legacy_hide()
    self:resetSellAllState()
    self.isTradeOpen = false
    if npcWindow then
        npcWindow:hide()
    end
end

function onItemBoxChecked(widget)
    if widget:isChecked() then
        local item = widget.item
        selectedItem = item
        refreshItem(item)
        tradeButton:enable()

        if getCurrentTradeType() == SELL then
            quantityScroll:setValue(quantityScroll:getMaximum())
        end
    end
end

function onQuantityValueChange(quantity)
    if selectedItem then
        weightLabel:setText(string.format('%.2f', selectedItem.weight * quantity) .. ' ' .. WEIGHT_UNIT)
        priceLabel:setText(formatCurrency(getItemPrice(selectedItem)))
    end
end

function onTradeTypeChange(radioTabs, selected, deselected)
    local currentTradeType = selected == blacklistTab and BLACKLIST or (selected == buyTab and BUY or SELL)
    tradeButton:setText(currentTradeType == BLACKLIST and tr('Remove') or selected:getText())
    selected:setOn(true)
    deselected:setOn(false)

    buyWithBackpack:setVisible(currentTradeType == BUY)
    ignoreCapacity:setVisible(currentTradeType == BUY)
    ignoreEquipped:setVisible(currentTradeType == SELL)
    showAllItems:setVisible(currentTradeType == SELL)
    sellAllButton:setVisible(controllerNpcTrader.rashidTrade and currentTradeType == SELL)
    cancelSellAllButton:setVisible(controllerNpcTrader.rashidSellActive and currentTradeType == SELL)

    refreshTradeItems()
    refreshPlayerGoods()
end

function onTradeClick()
    if getCurrentTradeType() == BLACKLIST then
        controllerNpcTrader:setRashidItemBlocked(selectedItem.ptr:getId(), false)
    elseif getCurrentTradeType() == BUY then
        g_game.buyItem(selectedItem.ptr, quantityScroll:getValue(), ignoreCapacity:isChecked(),
                       buyWithBackpack:isChecked())
    else
        g_game.sellItem(selectedItem.ptr, quantityScroll:getValue(), ignoreEquipped:isChecked())
    end
end

function onSearchTextChange()
    refreshPlayerGoods()
end

function itemPopup(self, mousePosition, mouseButton)
    if cancelNextRelease then
        cancelNextRelease = false
        return false
    end

    if mouseButton == MouseRightButton then
        local menu = g_ui.createWidget('PopupMenu')
        menu:setGameMenu(true)
        menu:addOption(tr('Look'), function()
            return g_game.inspectNpcTrade(self:getItem())
        end)
        if controllerNpcTrader.rashidTrade then
            local itemId = self:getItem():getId()
            if controllerNpcTrader:isRashidItemBlocked(itemId) then
                menu:addOption(tr('Remove from Blacklist'), function()
                    controllerNpcTrader:setRashidItemBlocked(itemId, false)
                end)
            else
                menu:addOption(tr('Add to Blacklist'), function()
                    controllerNpcTrader:setRashidItemBlocked(itemId, true)
                end)
            end
        end
        menu:display(mousePosition)
        return true
    elseif ((g_mouse.isPressed(MouseLeftButton) and mouseButton == MouseRightButton) or
        (g_mouse.isPressed(MouseRightButton) and mouseButton == MouseLeftButton)) then
        cancelNextRelease = true
        g_game.inspectNpcTrade(self:getItem())
        return true
    end
    return false
end

function onBuyWithBackpackChange()
    if selectedItem then
        refreshItem(selectedItem)
    end
end

function onIgnoreCapacityChange()
    refreshPlayerGoods()
end

function onIgnoreEquippedChange()
    refreshPlayerGoods()
end

function cancelRashidSellAllLegacy()
    controllerNpcTrader:cancelRashidSellQueue('Selling cancelled.', false)
end

function onShowAllItemsChange()
    refreshPlayerGoods()
end

function setCurrency(currency, decimal)
    CURRENCY = currency
    CURRENCY_DECIMAL = decimal
end

function setShowWeight(state)
    showWeight = state
    weightDesc:setVisible(state)
    weightLabel:setVisible(state)
end

function setShowYourCapacity(state)
    capacityDesc:setVisible(state)
    capacityLabel:setVisible(state)
    ignoreCapacity:setVisible(state)
end

function clearSelectedItem()
    nameLabel:clearText()
    weightLabel:clearText()
    priceLabel:clearText()
    tradeButton:disable()
    quantityScroll:setMinimum(0)
    quantityScroll:setMaximum(0)
    if selectedItem then
        radioItems:selectWidget(nil)
        selectedItem = nil
    end
end

function getCurrentTradeType()
    local selected = radioTabs and radioTabs:getSelectedWidget()
    if selected == blacklistTab then
        return BLACKLIST
    elseif selected == buyTab then
        return BUY
    else
        return SELL
    end
end

function getItemPrice(item, single)
    local amount = 1
    local single = single or false
    if not single then
        amount = quantityScroll:getValue()
    end
    if getCurrentTradeType() == BUY then
        if buyWithBackpack:isChecked() then
            if item.ptr:isStackable() then
                return item.price * amount + 20
            else
                return item.price * amount + math.ceil(amount / 20) * 20
            end
        end
    end
    return item.price * amount
end

function getSellQuantityLegacy(item)
    if not item or not playerItems[item:getId()] then
        return 0
    end
    local removeAmount = 0
    if ignoreEquipped:isChecked() then
        local localPlayer = g_game.getLocalPlayer()
        for i = 1, LAST_INVENTORY do
            local inventoryItem = localPlayer:getInventoryItem(i)
            if inventoryItem and inventoryItem:getId() == item:getId() and
                    (not controllerNpcTrader.rashidTrade or not inventoryItem.getTier or (inventoryItem:getTier() or 0) == 0) then
                removeAmount = removeAmount + inventoryItem:getCount()
            end
        end
        -- equipped items with an active imbuement are not part of the server goods count
        removeAmount = math.max(0, removeAmount - controllerNpcTrader:getEquippedImbuedCount(item:getId()))
    end
    return math.max(0, playerItems[item:getId()] - removeAmount)
end

function canTradeItemLegacy(item)
    if getCurrentTradeType() == BLACKLIST then
        return true
    elseif getCurrentTradeType() == BUY then
        return
            (ignoreCapacity:isChecked() or (not ignoreCapacity:isChecked() and playerFreeCapacity >= item.weight)) and
                playerMoney >= getItemPrice(item, true)
    else
        return getSellQuantityLegacy(item.ptr) > 0
    end
end

function refreshItem(item)
    nameLabel:setText(item.name)

    if getCurrentTradeType() == BUY then
        local capacityMaxCount = math.floor(playerFreeCapacity / item.weight)
        if ignoreCapacity:isChecked() then
            capacityMaxCount = 65535
        end
        local priceMaxCount = math.floor(playerMoney / getItemPrice(item, true))
        local finalCount = math.max(0,
            math.min(getMaxAmount(item), priceMaxCount, capacityMaxCount))
        quantityScroll:setMinimum(1)
        quantityScroll:setMaximum(finalCount)
    else
        quantityScroll:setMinimum(1)
        quantityScroll:setMaximum(math.max(0,
            math.min(getMaxAmount(item), getSellQuantityLegacy(item.ptr))))
    end

    onQuantityValueChange(quantityScroll:getValue())

    setupPanel:enable()
end

local function addLegacyTradeItem(item)
    local itemBox = g_ui.createWidget('NPCItemBox', itemsPanel)
    itemBox.item = item

    if controllerNpcTrader.rashidTrade then
        itemBox:setText(tostring(getSellQuantityLegacy(item.ptr)))
    else
        local text = item.name
        if showWeight then
            local weight = string.format('%.2f', item.weight) .. ' ' .. WEIGHT_UNIT
            text = text .. '\n' .. weight
        end
        text = text .. '\n' .. formatCurrency(item.price)
        itemBox:setText(text)
    end

    local itemWidget = itemBox:getChildById('item')
    itemWidget:setItem(item.ptr)
    itemWidget.onMouseRelease = itemPopup
    radioItems:addWidget(itemBox)
end

function refreshTradeItems()
    local layout = itemsPanel:getLayout()
    layout:disableUpdates()

    clearSelectedItem()
    searchText:clearText()
    setupPanel:disable()
    itemsPanel:destroyChildren()

    if radioItems then
        radioItems:destroy()
    end
    radioItems = UIRadioGroup.create()

    local currentTradeType = getCurrentTradeType()
    local currentTradeItems = tradeItems[currentTradeType == BLACKLIST and SELL or currentTradeType]
    for _, item in pairs(currentTradeItems) do
        local blocked = controllerNpcTrader:isRashidItemBlocked(item.ptr:getId())
        local includeItem = not ((currentTradeType == BLACKLIST and not blocked) or
            (controllerNpcTrader.rashidTrade and currentTradeType == SELL and blocked))
        if includeItem then
            addLegacyTradeItem(item)
        end
    end

    layout:enableUpdates()
    layout:update()
end

function refreshPlayerGoods()
    if not initialized then
        return
    end

    checkSellAllTooltip()

    moneyLabel:setText(formatCurrency(playerMoney))
    capacityLabel:setText(string.format('%.2f', playerFreeCapacity) .. ' ' .. WEIGHT_UNIT)

    local currentTradeType = getCurrentTradeType()
    local searchFilter = searchText:getText():lower()
    local foundSelectedItem = false

    local items = itemsPanel:getChildCount()
    for i = 1, items do
        local itemWidget = itemsPanel:getChildByIndex(i)
        local item = itemWidget.item

        if controllerNpcTrader.rashidTrade then
            itemWidget:setText(tostring(getSellQuantityLegacy(item.ptr)))
        end

        local canTrade = canTradeItemLegacy(item)
        itemWidget:setOn(canTrade)
        itemWidget:setEnabled(canTrade)

        local searchCondition = (searchFilter == '') or
                                    (searchFilter ~= '' and string.find(item.name:lower(), searchFilter) ~= nil)
        local showAllItemsCondition = (currentTradeType == BUY) or (showAllItems:isChecked()) or
                                          (currentTradeType == SELL and not showAllItems:isChecked() and canTrade)
        itemWidget:setVisible(searchCondition and showAllItemsCondition)

        if selectedItem == item and itemWidget:isEnabled() and itemWidget:isVisible() then
            foundSelectedItem = true
        end
    end

    if not foundSelectedItem then
        clearSelectedItem()
    end

    if selectedItem then
        refreshItem(selectedItem)
    end
end

function onOpenNpcTrade(items, currencyId, currencyName, npcName)
    controllerNpcTrader:resetSellAllState()
    tradeItems[BUY] = {}
    tradeItems[SELL] = {}

    local effectiveNpcName = npcName and npcName ~= '' and npcName or controllerNpcTrader.creatureName
    local previousNpcName = controllerNpcTrader.shopNpcName
    if controllerNpcTrader.rashidSellActive and previousNpcName ~= effectiveNpcName then
        controllerNpcTrader:cancelRashidSellQueue('Selling cancelled.', true)
    end
    controllerNpcTrader.shopNpcName = effectiveNpcName or ''
    controllerNpcTrader.rashidTrade = controllerNpcTrader.shopNpcName == 'Rashid'
    controllerNpcTrader.isTradeOpen = true
    local itemLayout = itemsPanel:getLayout()
    if itemLayout and itemLayout:isUIGridLayout() then
        itemLayout:setCellWidth(controllerNpcTrader.rashidTrade and 64 or 160)
        itemLayout:setCellHeight(controllerNpcTrader.rashidTrade and 64 or 95)
    end
    if controllerNpcTrader.rashidTrade then
        controllerNpcTrader:loadRashidBlacklist()
        buyTab:setVisible(false)
        sellTab:setVisible(true)
        sellTab:setText(tr('Sell'))
        sellTab:removeAnchor(AnchorLeft)
        sellTab:removeAnchor(AnchorRight)
        sellTab:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        sellTab:addAnchor(AnchorRight, 'parent', AnchorHorizontalCenter)
        sellTab:setMarginLeft(0)
        sellTab:setMarginRight(5)
        blacklistTab:setVisible(true)
    else
        buyTab:setVisible(true)
        sellTab:setVisible(true)
        sellTab:setText(tr('Sell'))
        sellTab:removeAnchor(AnchorLeft)
        sellTab:removeAnchor(AnchorRight)
        sellTab:addAnchor(AnchorLeft, 'parent', AnchorHorizontalCenter)
        sellTab:addAnchor(AnchorRight, 'parent', AnchorRight)
        sellTab:setMarginLeft(5)
        sellTab:setMarginRight(0)
        blacklistTab:setVisible(false)
    end

    for key, item in pairs(items) do
        if controllerNpcTrader.rashidTrade then
            local price = item[5] > 0 and item[5] or item[4]
            if price > 0 and isTierlessTradeItem(item[1]) then
                table.insert(tradeItems[SELL], {
                    ptr = item[1], name = item[2], weight = item[3] / 100, price = price
                })
            end
        else
            if item[4] > 0 then
                local newItem = {}
                newItem.ptr = item[1]
                newItem.name = item[2]
                newItem.weight = item[3] / 100
                newItem.price = item[4]
                table.insert(tradeItems[BUY], newItem)
            end

            if item[5] > 0 and isTierlessTradeItem(item[1]) then
                local newItem = {}
                newItem.ptr = item[1]
                newItem.name = item[2]
                newItem.weight = item[3] / 100
                newItem.price = item[5]
                table.insert(tradeItems[SELL], newItem)
            end
        end
    end

    refreshTradeItems()
    addEvent(function()
        controllerNpcTrader:legacy_show()
    end) -- player goods has not been parsed yet
end

function closeNpcTradeLegacy()
    g_game.closeNpcTrade()
    controllerNpcTrader:legacy_hide()
end

function controllerNpcTrader:onCloseNpcTradeLegacy()
    controllerNpcTrader:legacy_hide()
end

function onPlayerGoods(money, items)
    playerMoney = money

    playerItems = {}
    for key, item in pairs(items) do
        local id = item[1]:getId()
        if not playerItems[id] then
            playerItems[id] = item[2]
        else
            playerItems[id] = playerItems[id] + item[2]
        end
    end

    refreshPlayerGoods()
end

function onFreeCapacityChange(localPlayer, freeCapacity, oldFreeCapacity)
    playerFreeCapacity = freeCapacity

    if npcWindow:isVisible() then
        refreshPlayerGoods()
    end
end

function onInventoryChange(inventory, item, oldItem)
    refreshPlayerGoods()
end

function getTradeItemData(id, type)
    if table.empty(tradeItems[type]) then
        return false
    end

    if type then
        for key, item in pairs(tradeItems[type]) do
            if item.ptr and item.ptr:getId() == id then
                return item
            end
        end
    else
        for _, items in pairs(tradeItems) do
            for key, item in pairs(items) do
                if item.ptr and item.ptr:getId() == id then
                    return item
                end
            end
        end
    end
    return false
end

function checkSellAllTooltip()
    sellAllButton:setEnabled(not controllerNpcTrader.rashidSellActive)
    sellAllButton:removeTooltip()

    if not controllerNpcTrader.rashidTrade then
        sellAllButton:setEnabled(false)
        return
    end

    local info = ''
    local first = true

    for key, amount in pairs(playerItems) do
        local data = getTradeItemData(key, SELL)
        if data then
            amount = getSellQuantityLegacy(data.ptr)
            if amount > 0 then
                if data and amount > 0 then
                    info = info .. (not first and '\n' or '') .. amount .. ' ' .. data.name

                    if first then
                        first = false
                    end
                end
            end
        end
    end
    if info ~= '' then
        info = info .. '\nPrices are calculated by the server.'
        sellAllButton:setTooltip(info)
    else
        sellAllButton:setEnabled(false)
    end
end

function formatCurrency(amount)
    if CURRENCY_DECIMAL then
        return string.format('%.02f', amount / 100.0) .. ' ' .. CURRENCY
    else
        return amount .. ' ' .. CURRENCY
    end
end

function getMaxAmount(item)
    local tradeType = getCurrentTradeType()
    if tradeType == SELL and g_game.getFeature(GameDoubleShopSellAmount) then
        return 10000
    end

    if tradeType == BUY and item and item.ptr and item.ptr:isStackable() then
        local npcName = tostring(controllerNpcTrader.shopNpcName or ''):lower()
        if LARGE_STACK_BUY_NPCS[npcName] then
            return 10000
        end
    end
    return 100
end

function isTradingLegacy()
    return npcWindow and npcWindow:isVisible() or false
end

function getSellItemsLegacy()
    return tradeItems[SELL] or {}
end

function getBuyItemsLegacy()
    return tradeItems[BUY] or {}
end

function updateRashidSellProgressLegacy(done, total, message, active)
    if sellAllProgress then
        sellAllProgress:setVisible(true)
        sellAllProgress:setPercent(total > 0 and math.floor((done / total) * 100) or 0)
    end
    if sellAllProgressLabel then
        sellAllProgressLabel:setVisible(true)
        sellAllProgressLabel:setText(message or '')
    end
    if sellAllButton then
        sellAllButton:setEnabled(not active)
    end
    if cancelSellAllButton then
        cancelSellAllButton:setVisible(active)
        cancelSellAllButton:setEnabled(active)
    end
end

function resetRashidSellAllLegacy()
    if sellAllProgress then
        sellAllProgress:setPercent(0)
        sellAllProgress:setVisible(false)
    end
    if sellAllProgressLabel then
        sellAllProgressLabel:setText('')
        sellAllProgressLabel:setVisible(false)
    end
    if sellAllButton then sellAllButton:setEnabled(true) end
    if cancelSellAllButton then
        cancelSellAllButton:setEnabled(false)
        cancelSellAllButton:setVisible(false)
    end
end

function finishRashidSellAllLegacy(completed, silent, message)
    if sellAllButton then
        sellAllButton:setEnabled(true)
    end
    if cancelSellAllButton then
        cancelSellAllButton:setVisible(false)
    end
    if not silent and sellAllProgressLabel then
        sellAllProgressLabel:setText(message or (completed and 'Selling complete.' or 'Selling cancelled.'))
    end
    refreshPlayerGoods()
end

function sellAllLegacy()
    if not controllerNpcTrader.rashidTrade or getCurrentTradeType() ~= SELL then
        return
    end

    -- Copy only the offers currently displayed by the active filters.
    local visibleEntries = {}
    for i = 1, itemsPanel:getChildCount() do
        local itemBox = itemsPanel:getChildByIndex(i)
        if itemBox:isVisible() and itemBox.item and getSellQuantityLegacy(itemBox.item.ptr) > 0 then
            table.insert(visibleEntries, itemBox.item)
        end
    end

    local started = controllerNpcTrader:startRashidSellQueue(visibleEntries, true,
        function(item) return getSellQuantityLegacy(item) end,
        function() return ignoreEquipped:isChecked() end,
        updateRashidSellProgressLegacy,
        finishRashidSellAllLegacy)

    if not started then
        updateRashidSellProgressLegacy(0, 0, 'Nothing to sell.', false)
    end
end
