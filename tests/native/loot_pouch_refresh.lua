scheduleEvent(function()
    local originalCreate = g_ui.createWidget
    local originalName = g_game.getCharacterName
    local originalFindPanel = modules.game_interface.findContentPanelAvailable
    local panel, latest
    local createdItems = 0
    local ok, errorMessage = pcall(function()
        g_game.getCharacterName = function() return 'Loot Refresh QA' end
        panel = originalCreate('UIMiniWindowContainer', rootWidget)
        panel:setSize('200 600')
        modules.game_interface.findContentPanelAvailable = function() return panel end
        g_ui.createWidget = function(style, parent)
            if style == 'Item' then createdItems = createdItems + 1 end
            return originalCreate(style, parent)
        end
        local pouch = Item.create(23721)
        local function snapshot(count, firstIndex, capacity, itemId)
            local containerItem = itemId and Item.create(itemId) or pouch
            local items = {}
            local value = { firstIndex = firstIndex or 0, capacity = capacity or 32 }
            for slot = 0, value.capacity - 1 do
                if slot < count then
                    items[slot] = Item.create(3031)
                    items[slot]:setCount(count + slot)
                end
            end
            function value:getId() return 7 end
            function value:getContainerItem() return containerItem end
            function value:getName() return 'loot pouch' end
            function value:getCapacity() return self.capacity end
            function value:getFirstIndex() return self.firstIndex end
            function value:getSize() return 80 end
            function value:getItemsCount() return count end
            function value:getItem(slot) return items[slot] end
            function value:getSlotPosition(slot) return { x=65535, y=64+7, z=self.firstIndex+slot } end
            function value:hasParent() return true end
            function value:hasPages() return true end
            function value:isUnlocked() return true end
            return value
        end
        local containers = modules.game_containers
        latest = snapshot(5)
        containers.onContainerOpen(latest)
        local window = latest.window
        local firstCell = latest.itemsPanel:getChildById('item0')
        window:setHeight(180)
        window:lock(true)
        local height = window:getHeight()
        local dragLeave = window.onDragLeave
        local setupCalls = 0
        local originalSetup = window.setup
        window.setup = function(self, ...)
            setupCalls = setupCalls + 1
            return originalSetup(self, ...)
        end
        local before = createdItems
        for index=1,50 do
            local previous = latest
            latest = snapshot(index % 25 + 1)
            containers.onContainerOpen(latest, previous)
            assert(latest.window == window, 'refresh must preserve the window')
            assert(latest.itemsPanel:getChildById('item0'):getItem():getCount() == index % 25 + 1,
                'stack counts must follow every snapshot')
            assert(previous.window == nil and previous.itemsPanel == nil, 'old snapshots must release their window references')
        end
        g_logger.info(string.format('[LootRefreshQA] 50 updates: %d new slots, %d window setups',
            createdItems-before,setupCalls))
        assert(createdItems == before and setupCalls == 0,
            'same pouch refresh must reuse all slots and skip window setup')
        assert(window:getHeight() == height and not window:isDraggable(),
            'loot refresh must preserve manual height and lock state')
        assert(window.onDragLeave == dragLeave,'loot refresh must not repeatedly wrap the drag handler')
        assert(latest.itemsPanel:getChildById('item0') == firstCell,'slot widgets must stay alive')
        assert(firstCell:getItem():getCount() == 1,'latest stack count must reach the reused slot')
        assert(latest.itemsPanel:getChildById('item20'):getItem() == nil,'removed items must clear old slot contents')
        local previous = latest
        latest = snapshot(6,32)
        containers.onContainerOpen(latest,previous)
        assert(firstCell.position.z == 32,'page changes must update item drag/drop positions')
        assert(window:recursiveGetChildById('pageLabel'):getText() == 'Page 2 of 3','pagination must follow the latest snapshot')
        local seekIndex, parentContainer
        local originalSeek, originalParent = g_game.seekInContainer, g_game.openParent
        g_game.seekInContainer = function(_, index) seekIndex=index end
        g_game.openParent = function(container) parentContainer=container end
        window:recursiveGetChildById('nextPageButton').onClick()
        window:getChildById('upButton').onClick()
        g_game.seekInContainer, g_game.openParent = originalSeek, originalParent
        assert(seekIndex == 64 and parentContainer == latest,
            'navigation callbacks must use the latest page and container')
        local closed
        local originalClose = g_game.close
        g_game.close = function(container) closed = container end
        window.onClose()
        g_game.close = originalClose
        assert(closed == latest,'close callback must target the new container, not the first snapshot')
        window:show()
        previous = latest
        before = createdItems
        latest = snapshot(4,0,20,2854)
        containers.onContainerOpen(latest,previous)
        assert(createdItems == before+20 and latest.itemsPanel:getChildCount()==20,
            'replacing the pouch with a different container must rebuild the grid')
    end)
    g_ui.createWidget = originalCreate
    g_game.getCharacterName = originalName
    modules.game_interface.findContentPanelAvailable = originalFindPanel
    if latest and latest.window then latest.window:destroy() end
    if panel then panel:destroy() end
    if ok then
        g_logger.info('[LootRefreshQA] PASS: reused slots, stack counts/removal, height/lock, pagination/positions, current close/up callbacks and replacement container')
    else
        g_logger.error('[LootRefreshQA] FAIL: '..tostring(errorMessage))
    end
    scheduleEvent(function()g_app.exit()end,250)
end,1500)
scheduleEvent(function()g_app.exit()end,30000)
