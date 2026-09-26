containerSettings = nil

local GOLD_POUCH_ID = 23721
local GOLD_POUCH_RESYNC_DELAY = 500
local goldPouchResyncEvents = {}
local CONTAINER_WINDOWS_SETTINGS = 'BaiakContainerWindows'
local CONTAINER_RESTORE_TICK = 400
local CONTAINER_RESTORE_RETRY = 1200
local containerRestoreEvent
local containerSettingsSaveEvent
local containerRestoreNextTry = {}
local containerRestoreAttempts = 0
local pendingContainerPaths = {}
local pendingRewardChestRequests = {}
local REWARD_CHEST_ID = 19250

local function scheduleContainerSettingsSave()
    if containerSettingsSaveEvent then removeEvent(containerSettingsSaveEvent) end
    containerSettingsSaveEvent = scheduleEvent(function()
        containerSettingsSaveEvent = nil
        g_settings.save()
    end, 750)
end

local function getContainerCharacterSettings(create)
    local character = g_game.getCharacterName()
    if not character or character == '' then return nil, nil, nil end

    local allSettings = g_settings.getNode(CONTAINER_WINDOWS_SETTINGS) or {}
    if create and not allSettings[character] then allSettings[character] = {} end
    return allSettings, allSettings[character], character
end

local function copyContainerPath(path, depth)
    if not path or not path.segments then return nil end
    local copy = { rootSlot = path.rootSlot, segments = {} }
    for index = 1, math.min(depth or #path.segments, #path.segments) do
        local segment = path.segments[index]
        copy.segments[index] = { itemId = segment.itemId, slot = segment.slot }
    end
    return copy
end

local function containerPathKey(path, depth)
    if not path or not path.rootSlot or not path.segments then return nil end
    local parts = { 'slot' .. tostring(path.rootSlot) }
    for index = 1, math.min(depth or #path.segments, #path.segments) do
        local segment = path.segments[index]
        parts[#parts + 1] = tostring(segment.itemId) .. '@' .. tostring(segment.slot or 0)
    end
    return table.concat(parts, '/')
end

local buildContainerPath
buildContainerPath = function(container, visited)
    if not container then return nil end
    if container.restorePath then return copyContainerPath(container.restorePath) end

    visited = visited or {}
    if visited[container:getId()] then return nil end
    visited[container:getId()] = true

    local containerItem = container:getContainerItem()
    -- The Loot/Gold Pouch is a server-managed container. Depending on how the
    -- session is restored, its container item may arrive without the original
    -- inventory position. Give it a fixed local identity so its panel, order,
    -- height and lock state survive logout/relogin just like a backpack.
    if containerItem and containerItem:getId() == GOLD_POUCH_ID then
        return {
            rootSlot = 0,
            segments = { { itemId = GOLD_POUCH_ID, slot = 0 } }
        }
    end

    local position = containerItem and containerItem:getPosition()
    if not containerItem or not position or position.x ~= 65535 then return nil end

    if position.y >= 64 and position.y < 128 then
        local parentContainer = g_game.getContainer(position.y - 64)
        local parentPath = buildContainerPath(parentContainer, visited)
        if parentPath then
            parentPath.segments[#parentPath.segments + 1] = {
                itemId = containerItem:getId(),
                slot = position.z
            }
            return parentPath
        end
    end

    return {
        rootSlot = position.y,
        segments = { { itemId = containerItem:getId(), slot = 0 } }
    }
end

local function buildContainerPathFromRequest(position, itemId)
    if itemId == GOLD_POUCH_ID then
        return {
            rootSlot = 0,
            segments = { { itemId = GOLD_POUCH_ID, slot = 0 } }
        }
    end

    if not position or position.x ~= 65535 then return nil end

    if position.y >= 64 and position.y < 128 then
        local parentContainer = g_game.getContainer(position.y - 64)
        local parentPath = buildContainerPath(parentContainer)
        if not parentPath then return nil end
        parentPath.segments[#parentPath.segments + 1] = {
            itemId = itemId,
            slot = position.z
        }
        return parentPath
    end

    return {
        rootSlot = position.y,
        segments = { { itemId = itemId, slot = 0 } }
    }
end

local function onOpenContainerRequest(position, itemId, containerId, stackPos)
    if itemId == REWARD_CHEST_ID then
        pendingRewardChestRequests[containerId] = {
            position = position,
            itemId = itemId,
            stackPos = stackPos,
            expiresAt = g_clock.millis() + 5000
        }
    end
    local path = buildContainerPathFromRequest(position, itemId)
    if not path then return end
    pendingContainerPaths[containerId] = {
        path = path,
        expiresAt = g_clock.millis() + 5000
    }
end

local function getSavedContainerState(container)
    local path = container.restorePath or buildContainerPath(container)
    local _, characterSettings = getContainerCharacterSettings(false)
    local key = containerPathKey(path)
    return key and characterSettings and characterSettings[key] or nil, path, key
end

local function saveContainerState(container, open)
    if not container then return end
    local path = container.restorePath or buildContainerPath(container)
    local key = containerPathKey(path)
    local allSettings, characterSettings = getContainerCharacterSettings(true)
    if not key or not characterSettings then return end

    container.restorePath = path
    local state = characterSettings[key] or {}
    state.path = copyContainerPath(path)
    state.open = open ~= false
    state.firstIndex = container:getFirstIndex()

    local window = container.window
    if window then
        local parent = window:getParent()
        if parent then
            state.parentId = parent:getId()
            if parent:getClassName() == 'UIMiniWindowContainer' then
                state.index = parent:getChildIndex(window)
                state.position = nil
            else
                state.position = pointtostring(window:getPosition())
                state.index = nil
            end
        end
        if not window:isOn() then state.height = window:getHeight() end
        state.minimized = window:isOn()
        state.locked = not window:isDraggable()
    end

    characterSettings[key] = state
    g_settings.setNode(CONTAINER_WINDOWS_SETTINGS, allSettings)
    scheduleContainerSettingsSave()
end

local function applySavedContainerState(container, window, state, restorePage)
    if not window or not state then return end

    local parent = state.parentId and rootWidget:recursiveGetChildById(state.parentId) or nil
    -- Side panels can still be transitioning from the login screen when the
    -- server opens its containers. Reparent to the saved column even while it
    -- is temporarily hidden; otherwise the window is permanently left in the
    -- currently selected/default panel.
    if parent then
        window:setParent(parent, true)
        if parent:getClassName() == 'UIMiniWindowContainer' and state.index then
            parent:swapInsert(window, math.max(1, math.min(state.index, parent:getChildCount())))
        elseif state.position then
            window:setPosition(topoint(state.position))
        end
    end

    if state.height and window:isResizeable() then window:setHeight(state.height) end
    if state.minimized then
        if not window:isOn() then window:minimize(true) end
    elseif window:isOn() then
        window:maximize(true)
    end
    if state.locked then window:lock(true) else window:unlock(true) end

    -- Only restore pagination when the container is genuinely reopened. Page
    -- navigation and server-side loot updates replace the Container instance
    -- while keeping the same id; restoring the previous snapshot in that case
    -- makes pages continuously bounce back and forth.
    local savedFirstIndex = state.firstIndex
    if restorePage and savedFirstIndex and savedFirstIndex ~= container:getFirstIndex() and
        savedFirstIndex < container:getSize() then
        scheduleEvent(function()
            if g_game.getContainer(container:getId()) == container then
                g_game.seekInContainer(container:getId(), savedFirstIndex)
            end
        end, 50)
    end
end

local function findOpenContainersByPath()
    local openContainers = {}
    for _, container in pairs(g_game.getContainers()) do
        container.restorePath = container.restorePath or buildContainerPath(container)
        local key = containerPathKey(container.restorePath)
        if key then openContainers[key] = container end
    end
    return openContainers
end

local function findRestoreChild(container, segment)
    if not container or not segment then return nil end
    local item = container:getItem(segment.slot or 0)
    if item and item:getId() == segment.itemId then return item end

    for slot = 0, container:getCapacity() - 1 do
        item = container:getItem(slot)
        if item and item:getId() == segment.itemId then return item end
    end
    return nil
end

local function getRestorableContainerStates()
    local _, characterSettings = getContainerCharacterSettings(false)
    local states = {}
    for _, state in pairs(characterSettings or {}) do
        if state.open and state.path and state.path.rootSlot and state.path.segments and
            #state.path.segments > 0 then
            states[#states + 1] = state
        end
    end
    table.sort(states, function(left, right)
        local leftDepth = #left.path.segments
        local rightDepth = #right.path.segments
        if leftDepth ~= rightDepth then return leftDepth < rightDepth end
        return (left.index or 9999) < (right.index or 9999)
    end)
    return states
end

local function tryRestoreContainer(state, openContainers)
    local path = state and state.path
    local player = g_game.getLocalPlayer()
    if not path or not player then return false, false end

    -- Server-managed pouches are reopened by the server. Their sentinel slot
    -- must never be passed to getInventoryItem while we wait for that packet.
    if path.rootSlot == 0 then return false, false end

    local currentContainer
    for depth, segment in ipairs(path.segments) do
        local prefixKey = containerPathKey(path, depth)
        local alreadyOpen = openContainers[prefixKey]
        if alreadyOpen then
            currentContainer = alreadyOpen
        else
            local item
            if depth == 1 then
                item = player:getInventoryItem(path.rootSlot)
            else
                item = findRestoreChild(currentContainer, segment)
            end

            if not item or item:getId() ~= segment.itemId then return false, false end

            local now = g_clock.millis()
            if not containerRestoreNextTry[prefixKey] or
                containerRestoreNextTry[prefixKey] <= now then
                containerRestoreNextTry[prefixKey] = now + CONTAINER_RESTORE_RETRY
                g_game.open(item)
                return false, true
            end
            return false, false
        end
    end
    return currentContainer ~= nil, false
end

local function runContainerRestore()
    containerRestoreEvent = nil
    if not g_game.isOnline() then return end

    containerRestoreAttempts = containerRestoreAttempts + 1
    local openContainers = findOpenContainersByPath()
    local allRestored = true
    for _, state in ipairs(getRestorableContainerStates()) do
        local restored, requestedOpen = tryRestoreContainer(state, openContainers)
        if not restored then allRestored = false end
        -- Open one level per tick so the server can answer and make nested
        -- container items available before the next path is processed.
        if requestedOpen then break end
    end

    if not allRestored and containerRestoreAttempts < 75 then
        containerRestoreEvent = scheduleEvent(runContainerRestore, CONTAINER_RESTORE_TICK)
    end
end

local function scheduleContainerRestore()
    if containerRestoreEvent then removeEvent(containerRestoreEvent) end
    containerRestoreNextTry = {}
    containerRestoreAttempts = 0
    containerRestoreEvent = scheduleEvent(runContainerRestore, 1000)
end

local function onContainersGameStart()
    pendingContainerPaths = {}
    scheduleContainerRestore()
end

local function snapshotOpenContainers()
    for _, container in pairs(g_game.getContainers()) do
        saveContainerState(container, true)
    end
    g_settings.save()
end

function saveOpenContainerStates()
    snapshotOpenContainers()
end

local function onContainersDeath()
    -- Capture the final geometry before the server starts closing containers.
    -- The following reconnect will reopen the same stable container paths.
    snapshotOpenContainers()
end

local function onContainersGameEnd()
    if containerRestoreEvent then
        removeEvent(containerRestoreEvent)
        containerRestoreEvent = nil
    end
    snapshotOpenContainers()
    pendingContainerPaths = {}
    pendingRewardChestRequests = {}
    clean()
end

local function cancelGoldPouchResync(containerId)
    local event = goldPouchResyncEvents[containerId]
    if event then
        removeEvent(event)
        goldPouchResyncEvents[containerId] = nil
    end
end

local function isGoldPouch(container)
    local containerItem = container and container:getContainerItem()
    return containerItem and containerItem:getId() == GOLD_POUCH_ID
end

local function scheduleGoldPouchResync(container)
    if not isGoldPouch(container) or not container.window then return end

    local containerId = container:getId()
    cancelGoldPouchResync(containerId)
    goldPouchResyncEvents[containerId] = scheduleEvent(function()
        goldPouchResyncEvents[containerId] = nil
        if not g_game.isOnline() then return end

        local currentContainer = g_game.getContainer(containerId)
        if currentContainer ~= container or not currentContainer.window or
            currentContainer:getSize() == 0 then
            return
        end

        -- Gold Pouch updates can arrive as delayed per-item snapshots. Asking
        -- for the current page after the burst settles replaces any stale
        -- local slot order with the server's authoritative container state.
        g_game.seekInContainer(containerId, currentContainer:getFirstIndex())
    end, GOLD_POUCH_RESYNC_DELAY)
end

function init()
    g_ui.importStyle('container')

    -- Initialize container settings
    containerSettings = g_settings.getNode('containers')
    if not containerSettings then
        containerSettings = {}
        -- Set useManualSortMode as default
        containerSettings['useManualSortMode'] = 1
        -- Set default sorting mode to none
        containerSettings['currentSortMode'] = 'none'
        -- Initialize sorting options
        containerSettings['sortContainersFirst'] = 0
        containerSettings['sortNestedContainers'] = 0
        g_settings.setNode('containers', containerSettings)
    end

    -- Ensure all required settings exist
    if containerSettings['sortNestedContainers'] == nil then
        containerSettings['sortNestedContainers'] = 0
    end
    if containerSettings['sortContainersFirst'] == nil then
        containerSettings['sortContainersFirst'] = 0
    end

    connect(Container, {
        onOpen = onContainerOpen,
        onClose = onContainerClose,
        onSizeChange = onContainerChangeSize,
        onUpdateItem = onContainerUpdateItem
    })
    connect(g_game, {
        onGameStart = onContainersGameStart,
        onGameEnd = onContainersGameEnd,
        onBeforeLogout = snapshotOpenContainers,
        onDeath = onContainersDeath,
        onOpenContainerRequest = onOpenContainerRequest
    }, true)

    reloadContainers()
    if g_game.isOnline() then scheduleContainerRestore() end
end

function terminate()
    disconnect(Container, {
        onOpen = onContainerOpen,
        onClose = onContainerClose,
        onSizeChange = onContainerChangeSize,
        onUpdateItem = onContainerUpdateItem
    })
    disconnect(g_game, {
        onGameStart = onContainersGameStart,
        onGameEnd = onContainersGameEnd,
        onBeforeLogout = snapshotOpenContainers,
        onDeath = onContainersDeath,
        onOpenContainerRequest = onOpenContainerRequest
    })
    if containerRestoreEvent then
        removeEvent(containerRestoreEvent)
        containerRestoreEvent = nil
    end
    if containerSettingsSaveEvent then
        removeEvent(containerSettingsSaveEvent)
        containerSettingsSaveEvent = nil
        g_settings.save()
    end
    pendingContainerPaths = {}
    pendingRewardChestRequests = {}
    for containerId, event in pairs(goldPouchResyncEvents) do
        removeEvent(event)
        goldPouchResyncEvents[containerId] = nil
    end
end

function reloadContainers()
    clean()
    for _, container in pairs(g_game.getContainers()) do
        onContainerOpen(container)
    end
end

function clean()
    for containerid, container in pairs(g_game.getContainers()) do
        destroy(container)
    end
end

function destroy(container)
    cancelGoldPouchResync(container:getId())
    if container.window then
        saveContainerState(container, container.manualClose ~= true)
        container.window:destroy()
        container.window = nil
        container.itemsPanel = nil
    end
end

function showContainersContextMenu(widget, mousePos, mouseButton)
    local menu = g_ui.createWidget('ContainersSubMenu')
    if not menu then
        return false
    end
    menu:setGameMenu(true)
    for _, choice in ipairs(menu:getChildren()) do
        local choiceId = choice:getId()
        if choiceId and choiceId ~= 'HorizontalSeparator' then
            local widgetClass = choice:getClassName()
            local isSortingAction = choiceId:find('sortAsc') or choiceId:find('sortDesc')
            local isActionButton = isSortingAction or choiceId == 'moveToObtainContainers'
            if isActionButton then
                choice.onClick = function()
                    onContainersMenuAction(choiceId)
                    menu:destroy()
                end
                choice.onMouseRelease = function(widget, mousePos, mouseButton)
                    if mouseButton == MouseLeftButton then
                        onContainersMenuAction(choiceId)
                        menu:destroy()
                        return true
                    end
                    return false
                end
                if isSortingAction then
                    local currentSortMode = containerSettings and containerSettings['currentSortMode'] or 'none'
                    local isActive = (currentSortMode == choiceId)
                    local isManualSortEnabled = containerSettings and containerSettings['useManualSortMode'] == 1
                    if isManualSortEnabled then
                        choice:setEnabled(false)
                        choice:setColor('#808080')
                    else
                        choice:setEnabled(true)
                        if isActive then
                            choice:setColor('#ffff00')
                        else
                            choice:setColor('#ffffff')
                        end
                    end
                else
                    choice:setEnabled(true)
                    choice:setColor('#ffffff')
                end
            else
                local currentState = getContainerOptionState(choiceId)
                choice:setChecked(currentState)
                local isManualSortEnabled = containerSettings and containerSettings['useManualSortMode'] == 1
                if isManualSortEnabled and (choiceId == 'sortContainersFirst' or choiceId == 'sortNestedContainers') then
                    choice:setEnabled(false)
                    choice:setColor('#808080')
                else
                    choice:setEnabled(true)
                    choice:setColor('#ffffff')
                end
                choice.onCheckChange = function()
                    onContainersMenuAction(choiceId)
                    menu:destroy()
                end
            end
        end
    end
    local buttonPos = widget:getPosition()
    local buttonSize = widget:getSize()
    local menuWidth = menu:getWidth()
    local buttonCenterX = buttonPos.x + buttonSize.width / 2
    local buttonCenterY = buttonPos.y + buttonSize.height / 2
    local menuX = buttonCenterX - menuWidth
    local menuY = buttonCenterY
    menu:display({x = menuX, y = menuY})
    return true
end

function getContainerOptionState(optionId)
    -- Return the current state of container options
    -- These are stored in settings similar to skills module
    if not containerSettings then
        return false
    end
    
    if optionId == 'sortContainersFirst' then
        return containerSettings['sortContainersFirst'] == 1
    elseif optionId == 'sortNestedContainers' then
        return containerSettings['sortNestedContainers'] == 1
    elseif optionId == 'useManualSortMode' then
        return containerSettings['useManualSortMode'] == 1
    elseif optionId == 'moveNestedContainers' then
        return containerSettings['moveNestedContainers'] == 1
    end
    return false
end

function sortContainerItems(container, sortMode)
    if not container or not container.itemsPanel then
        return
    end
    
    -- Don't sort if manual sort mode is enabled
    local isManualSortEnabled = containerSettings and containerSettings['useManualSortMode'] == 1
    if isManualSortEnabled then
        return
    end
    
    -- Check if Sort Nested Containers is enabled when manual sort mode is disabled
    local sortNestedContainers = containerSettings and containerSettings['sortNestedContainers'] == 1
    if sortNestedContainers then
    end
    
    -- Get all items with their slot information (only non-nil items)
    local items = {}
    local totalCapacity = container:getCapacity()
    
    for slot = 0, totalCapacity - 1 do
        local item = container:getItem(slot)
        if item and item:getId() > 0 then -- Check for valid item
            table.insert(items, {
                slot = slot,
                item = item,
                widget = container.itemsPanel:getChildById('item' .. slot)
            })
        end
    end
    
    -- Only sort if we have items
    if #items == 0 then
        return
    end
    
    -- Check if Sort Containers First and Sort Nested Containers are enabled
    local sortContainersFirst = containerSettings and containerSettings['sortContainersFirst'] == 1
    local sortNestedContainers = containerSettings and containerSettings['sortNestedContainers'] == 1
    
    -- Helper function to check if an item is a container
    local function isContainer(item)
        local success, result = pcall(function()
            if item.isContainer and type(item.isContainer) == "function" then
                return item:isContainer()
            end
            return false
        end)
        return success and result
    end
    
    -- Helper function to check if a container has items inside (is nested)
    local function isNestedContainer(item)
        if not isContainer(item) then
            return false
        end
        
        local success, result = pcall(function()
            -- Try to get the container's item count
            if item.getItemsCount and type(item.getItemsCount) == "function" then
                local itemCount = item:getItemsCount()
                return itemCount and itemCount > 0
            end
            
            -- Alternative: Check if container has capacity and items
            if item.getCapacity and type(item.getCapacity) == "function" then
                local capacity = item:getCapacity()
                if capacity and capacity > 0 then
                    -- Check if any slot has an item
                    for slot = 0, capacity - 1 do
                        if item.getItem and type(item.getItem) == "function" then
                            local slotItem = item:getItem(slot)
                            if slotItem and slotItem:getId() > 0 then
                                return true
                            end
                        end
                    end
                end
            end
            
            return false
        end)
        
        if not success then
            return false
        end
        
        return result
    end
    
    -- Helper function for container-first sorting with nested container support
    local function sortWithContainersFirst(items, compareFn)
        local sortContainersFirst = containerSettings and containerSettings['sortContainersFirst'] == 1
        local sortNestedContainers = containerSettings and containerSettings['sortNestedContainers'] == 1
        
        -- Sort Nested Containers feature:
        -- When enabled, containers that have items inside them are prioritized at the top,
        -- followed by empty containers (if Sort Containers First is also enabled),
        -- and finally non-container items.
        -- 
        -- Priority order when both options are enabled:
        -- 1. Nested containers (containers with items inside) - HIGHEST PRIORITY
        -- 2. Empty containers (only if Sort Containers First is enabled)
        -- 3. Non-container items - LOWEST PRIORITY
        -- 
        -- This feature can work together with Sort Containers First but not with Manual Sort Mode.
        
        -- If neither option is enabled, just sort normally
        if not sortContainersFirst and not sortNestedContainers then
            table.sort(items, compareFn)
            return
        end
        
        -- Separate items into categories
        local nestedContainers = {}      -- Containers with items inside
        local emptyContainers = {}       -- Empty containers
        local nonContainers = {}         -- Non-container items
        
        for _, itemData in ipairs(items) do
            if isContainer(itemData.item) then
                if sortNestedContainers and isNestedContainer(itemData.item) then
                    table.insert(nestedContainers, itemData)
                else
                    table.insert(emptyContainers, itemData)
                end
            else
                table.insert(nonContainers, itemData)
            end
        end
        
        -- Sort each group separately
        table.sort(nestedContainers, compareFn)
        table.sort(emptyContainers, compareFn)
        table.sort(nonContainers, compareFn)
        
        -- Merge groups based on enabled options with proper priority order
        local sortedItems = {}
        
        -- Priority 1: Nested containers (if Sort Nested Containers is enabled)
        if sortNestedContainers then
            for _, itemData in ipairs(nestedContainers) do
                table.insert(sortedItems, itemData)
            end
        end
        
        -- Priority 2: Empty containers (if Sort Containers First is enabled)
        -- Note: This comes after nested containers even if both options are enabled
        if sortContainersFirst then
            for _, itemData in ipairs(emptyContainers) do
                table.insert(sortedItems, itemData)
            end
            
            -- Add nested containers here only if sortNestedContainers is not enabled
            if not sortNestedContainers then
                for _, itemData in ipairs(nestedContainers) do
                    table.insert(sortedItems, itemData)
                end
            end
        else
            -- If sortContainersFirst is disabled but sortNestedContainers is disabled too,
            -- add all containers together after nested containers
            if not sortNestedContainers then
                for _, itemData in ipairs(nestedContainers) do
                    table.insert(sortedItems, itemData)
                end
            end
            
            -- Add empty containers without priority
            for _, itemData in ipairs(emptyContainers) do
                table.insert(sortedItems, itemData)
            end
        end
        
        -- Priority 3 (Last): Non-container items
        for _, itemData in ipairs(nonContainers) do
            table.insert(sortedItems, itemData)
        end
        
        -- Replace original items array
        for i = 1, #items do
            items[i] = sortedItems[i]
        end
    end
    
    -- Sort the items based on the sort mode
    if sortMode == 'sortAscByName' then
        sortWithContainersFirst(items, function(a, b) 
            if not a or not a.item or not b or not b.item then 
                return false 
            end
            
            local nameA = ""
            local nameB = ""
            
            -- Use pcall for extra safety and try getName from the item
            local success, result = pcall(function()
                if a.item.getName and type(a.item.getName) == "function" then
                    return a.item:getName() or ""
                end
                -- Try getting name from the item type if direct getName fails
                local itemType = g_things.getThingType(a.item:getId(), ThingCategoryItem)
                if itemType and itemType.getName and type(itemType.getName) == "function" then
                    return itemType:getName() or ""
                end
                return ""
            end)
            if success then nameA = result end
            
            success, result = pcall(function()
                if b.item.getName and type(b.item.getName) == "function" then
                    return b.item:getName() or ""
                end
                -- Try getting name from the item type if direct getName fails
                local itemType = g_things.getThingType(b.item:getId(), ThingCategoryItem)
                if itemType and itemType.getName and type(itemType.getName) == "function" then
                    return itemType:getName() or ""
                end
                return ""
            end)
            if success then nameB = result end
            
            return nameA:lower() < nameB:lower() 
        end)
    elseif sortMode == 'sortDescByName' then
        sortWithContainersFirst(items, function(a, b) 
            if not a or not a.item or not b or not b.item then 
                return false 
            end
            
            local nameA = ""
            local nameB = ""
            
            -- Use pcall for extra safety and try getName from the item
            local success, result = pcall(function()
                if a.item.getName and type(a.item.getName) == "function" then
                    return a.item:getName() or ""
                end
                -- Try getting name from the item type if direct getName fails
                local itemType = g_things.getThingType(a.item:getId(), ThingCategoryItem)
                if itemType and itemType.getName and type(itemType.getName) == "function" then
                    return itemType:getName() or ""
                end
                return ""
            end)
            if success then nameA = result end
            
            success, result = pcall(function()
                if b.item.getName and type(b.item.getName) == "function" then
                    return b.item:getName() or ""
                end
                -- Try getting name from the item type if direct getName fails
                local itemType = g_things.getThingType(b.item:getId(), ThingCategoryItem)
                if itemType and itemType.getName and type(itemType.getName) == "function" then
                    return itemType:getName() or ""
                end
                return ""
            end)
            if success then nameB = result end
            
            return nameA:lower() > nameB:lower() 
        end)
    elseif sortMode == 'sortAscByWeight' then
        -- TODO: Implement functionality to retrieve item weights and sort accordingly
        return
    elseif sortMode == 'sortDescByWeight' then
        -- TODO: Implement weight-based sorting (descending)
        return
    elseif sortMode == 'sortAscByExpiry' then
        sortWithContainersFirst(items, function(a, b) 
            if not a or not a.item or not b or not b.item then return false end
            
            local aExpiry = 0
            local bExpiry = 0
            
            -- Use getDurationTime() for expiry - this exists on Item objects
            local success, result = pcall(function()
                if a.item.getDurationTime and type(a.item.getDurationTime) == "function" then
                    return a.item:getDurationTime() or 0
                end
                return 0
            end)
            if success then aExpiry = result end
            
            success, result = pcall(function()
                if b.item.getDurationTime and type(b.item.getDurationTime) == "function" then
                    return b.item:getDurationTime() or 0
                end
                return 0
            end)
            if success then bExpiry = result end
            
            return aExpiry < bExpiry
        end)
    elseif sortMode == 'sortDescByExpiry' then
        sortWithContainersFirst(items, function(a, b) 
            if not a or not a.item or not b or not b.item then return false end
            
            local aExpiry = 0
            local bExpiry = 0
            
            -- Use getDurationTime() for expiry - this exists on Item objects
            local success, result = pcall(function()
                if a.item.getDurationTime and type(a.item.getDurationTime) == "function" then
                    return a.item:getDurationTime() or 0
                end
                return 0
            end)
            if success then aExpiry = result end
            
            success, result = pcall(function()
                if b.item.getDurationTime and type(b.item.getDurationTime) == "function" then
                    return b.item:getDurationTime() or 0
                end
                return 0
            end)
            if success then bExpiry = result end
            
            return aExpiry > bExpiry
        end)
    elseif sortMode == 'sortAscByStackSize' then
        sortWithContainersFirst(items, function(a, b) 
            if not a or not a.item or not b or not b.item then return false end
            
            local countA = 1
            local countB = 1
            local chargesA = 0
            local chargesB = 0
            
            -- Use getCount() - this exists on Item objects
            local success, result = pcall(function()
                if a.item.getCount and type(a.item.getCount) == "function" then
                    return a.item:getCount() or 1
                end
                return 1
            end)
            if success then countA = result end
            
            success, result = pcall(function()
                if b.item.getCount and type(b.item.getCount) == "function" then
                    return b.item:getCount() or 1
                end
                return 1
            end)
            if success then countB = result end
            
            -- Get charges
            success, result = pcall(function()
                if a.item.getCharges and type(a.item.getCharges) == "function" then
                    return a.item:getCharges() or 0
                end
                return 0
            end)
            if success then chargesA = result end
            
            success, result = pcall(function()
                if b.item.getCharges and type(b.item.getCharges) == "function" then
                    return b.item:getCharges() or 0
                end
                return 0
            end)
            if success then chargesB = result end
            
            -- Use charges if available, otherwise use count
            local valueA = chargesA > 0 and chargesA or countA
            local valueB = chargesB > 0 and chargesB or countB
            
            return valueA < valueB 
        end)
    elseif sortMode == 'sortDescByStackSize' then
        sortWithContainersFirst(items, function(a, b) 
            if not a or not a.item or not b or not b.item then return false end
            
            local countA = 1
            local countB = 1
            local chargesA = 0
            local chargesB = 0
            
            -- Use getCount() - this exists on Item objects
            local success, result = pcall(function()
                if a.item.getCount and type(a.item.getCount) == "function" then
                    return a.item:getCount() or 1
                end
                return 1
            end)
            if success then countA = result end
            
            success, result = pcall(function()
                if b.item.getCount and type(b.item.getCount) == "function" then
                    return b.item:getCount() or 1
                end
                return 1
            end)
            if success then countB = result end
            
            -- Get charges
            success, result = pcall(function()
                if a.item.getCharges and type(a.item.getCharges) == "function" then
                    return a.item:getCharges() or 0
                end
                return 0
            end)
            if success then chargesA = result end
            
            success, result = pcall(function()
                if b.item.getCharges and type(b.item.getCharges) == "function" then
                    return b.item:getCharges() or 0
                end
                return 0
            end)
            if success then chargesB = result end
            
            -- Use charges if available, otherwise use count
            local valueA = chargesA > 0 and chargesA or countA
            local valueB = chargesB > 0 and chargesB or countB
            
            return valueA > valueB 
        end)
    else
        -- No sorting or unknown mode
        return
    end
    
    -- Clear all item widgets first
    for slot = 0, totalCapacity - 1 do
        local itemWidget = container.itemsPanel:getChildById('item' .. slot)
        if itemWidget then
            itemWidget:setItem(nil)
        end
    end
    
    -- Place sorted items back into the container display starting from slot 0
    for i, itemData in ipairs(items) do
        local targetSlot = i - 1 -- Convert to 0-based index
        
        if targetSlot < totalCapacity then
            local itemWidget = container.itemsPanel:getChildById('item' .. targetSlot)
            if itemWidget then
                -- Set the visual item (this doesn't change the actual container data)
                itemWidget:setItem(itemData.item)
                -- Preserve the original slot position for drag-and-drop operations
                itemWidget.position = container:getSlotPosition(itemData.slot)
                
                ItemsDatabase.setRarityItem(itemWidget, itemData.item)
                ItemsDatabase.setTier(itemWidget, itemData.item)
                itemWidget:setShowDuration(g_game.getFeature(GameThingClock) and modules.client_options.getOption('showExpiryInContainers'))
                itemWidget:setShowCharges(g_game.getFeature(GameThingCounter) and modules.client_options.getOption('showExpiryInContainers'))

                local itemName = "unnamed"
                local success, result = pcall(function()
                    if itemData.item.getName and type(itemData.item.getName) == "function" then
                        return itemData.item:getName() or "unnamed"
                    end
                    -- Try getting name from the item type if direct getName fails
                    local itemType = g_things.getThingType(itemData.item:getId(), ThingCategoryItem)
                    if itemType and itemType.getName and type(itemType.getName) == "function" then
                        return itemType:getName() or "unnamed"
                    end
                    return "unnamed"
                end)
                if success then itemName = result end
            else
            end
        else
        end
    end
end

-- Function to determine quick loot category for an item

function onContainersMenuAction(actionId)
    local isToggleOption = actionId == 'sortContainersFirst' or actionId == 'sortNestedContainers' or 
                          actionId == 'useManualSortMode' or actionId == 'moveNestedContainers'
    local isActionButton = actionId == 'moveToObtainContainers' or actionId:find('sortAsc') or actionId:find('sortDesc')
    if isActionButton then
        -- Handle action buttons (non-toggle actions)
        if actionId == 'moveToObtainContainers' then
            -- TODO: Need to create function to use quickloot sorting.
            return
        elseif actionId:find('sortAsc') or actionId:find('sortDesc') then
            -- When a sorting action is selected, automatically disable manual sort mode
            local isManualSortEnabled = containerSettings and containerSettings['useManualSortMode'] == 1
            if isManualSortEnabled then
                containerSettings['useManualSortMode'] = 0
            end
            
            -- Sorting actions - these are mutually exclusive
            containerSettings['currentSortMode'] = actionId
            g_settings.setNode('containers', containerSettings)
            
            -- Apply sorting to all open containers
            for _, container in pairs(g_game.getContainers()) do
                if container.window and container.window:isVisible() then
                    sortContainerItems(container, actionId)
                end
            end
            return
        end
    end
    
    if isToggleOption then
        -- Toggle options
        local currentState = getContainerOptionState(actionId)
        local newState = not currentState
        
        -- Special handling for useManualSortMode
        if actionId == 'useManualSortMode' then
            if newState then
                -- When enabling manual sort mode, clear any active sorting mode and disable other sorting options
                containerSettings['currentSortMode'] = 'none'
                containerSettings['sortContainersFirst'] = 0
                containerSettings['sortNestedContainers'] = 0
            else
                -- When disabling manual sort mode, sorting options become available again
            end
        elseif actionId == 'sortContainersFirst' then
            -- Prevent enabling if manual sort mode is active
            local isManualSortEnabled = containerSettings and containerSettings['useManualSortMode'] == 1
            if newState and isManualSortEnabled then
                return -- Don't change the setting
            end
            
            -- When Sort Containers First is toggled, re-apply current sorting if active
            local currentSortMode = containerSettings and containerSettings['currentSortMode']
            if currentSortMode and currentSortMode ~= 'none' then
                -- Apply sorting to all open containers after toggling
                scheduleEvent(function()
                    for _, container in pairs(g_game.getContainers()) do
                        if container.window and container.window:isVisible() then
                            sortContainerItems(container, currentSortMode)
                        end
                    end
                end, 50) -- Small delay to ensure setting is saved first
            end
        elseif actionId == 'sortNestedContainers' then
            -- Prevent enabling if manual sort mode is active
            local isManualSortEnabled = containerSettings and containerSettings['useManualSortMode'] == 1
            if newState and isManualSortEnabled then
                return -- Don't change the setting
            end
            
            -- When Sort Nested Containers is toggled, re-apply current sorting if active
            local currentSortMode = containerSettings and containerSettings['currentSortMode']
            if currentSortMode and currentSortMode ~= 'none' then
                -- Apply sorting to all open containers after toggling
                scheduleEvent(function()
                    for _, container in pairs(g_game.getContainers()) do
                        if container.window and container.window:isVisible() then
                            sortContainerItems(container, currentSortMode)
                        end
                    end
                end, 50) -- Small delay to ensure setting is saved first
            end
        elseif actionId == 'moveNestedContainers' then
            -- TODO: Implement functionality to automatically move nested containers (containers with items inside)
            -- to specific locations or positions within containers. This feature should work in conjunction
            -- with container sorting and could help organize containers by moving filled containers to
            -- preferred positions (e.g., top of container, specific slots, etc.).
            -- Implementation should consider:
            -- 1. Identify containers that have items inside (nested containers)
            -- 2. Define target positions/rules for where to move them
            -- 3. Handle conflicts with existing sorting modes
            -- 4. Respect manual sort mode settings
            -- 5. Provide user feedback on move operations
            
            -- For now, just toggle the setting - actual move functionality to be implemented
        end
        
        -- Save the new state to settings
        containerSettings[actionId] = newState and 1 or 0
        g_settings.setNode('containers', containerSettings)
    end
end

function refreshContainerItems(container)
    -- Check if we should preserve sorting during refresh
    local currentSortMode = containerSettings and containerSettings['currentSortMode']
    local isManualSortEnabled = containerSettings and containerSettings['useManualSortMode'] == 1
    local shouldSort = currentSortMode and currentSortMode ~= 'none' and not isManualSortEnabled
    
    for slot = 0, container:getCapacity() - 1 do
        local itemWidget = container.itemsPanel:getChildById('item' .. slot)
        itemWidget:setItem(container:getItem(slot))
        ItemsDatabase.setRarityItem(itemWidget, container:getItem(slot))
        ItemsDatabase.setTier(itemWidget, container:getItem(slot))
        itemWidget:setShowDuration(g_game.getFeature(GameThingClock) and modules.client_options.getOption('showExpiryInContainers'))
        itemWidget:setShowCharges(g_game.getFeature(GameThingCounter) and modules.client_options.getOption('showExpiryInContainers'))
    end

    if container:hasPages() then
        refreshContainerPages(container)
    end
    
    -- Apply current sorting if one is set and manual sort mode is disabled
    if shouldSort then
        sortContainerItems(container, currentSortMode)
    end
end

function toggleContainerPages(containerWindow, pages)
    local scrollbar = containerWindow:getChildById('miniwindowScrollBar')
    local pagePanel = containerWindow:getChildById('pagePanel')
    local separator = containerWindow:getChildById('separator')
    local contentsPanel = containerWindow:getChildById('contentsPanel')
    local upButton = containerWindow:getChildById('upButton')
    local contextMenuButton = containerWindow:recursiveGetChildById('contextMenuButton')
    local lockButton = containerWindow:recursiveGetChildById('lockButton')
    local minimizeButton = containerWindow:recursiveGetChildById('minimizeButton')
    
    if pages then
        -- When pages are visible, anchor scrollbar to close button bottom and separator top
        scrollbar:breakAnchors()
        scrollbar:addAnchor(AnchorTop, 'closeButton', AnchorBottom)
        scrollbar:addAnchor(AnchorRight, 'parent', AnchorRight)
        scrollbar:addAnchor(AnchorBottom, 'separator', AnchorTop)
        scrollbar:setMarginTop(2)  -- Small margin from close button
        scrollbar:setMarginRight(3)
        scrollbar:setMarginBottom(2)
        
        -- Content panel anchors to separator when pages are visible
        contentsPanel:breakAnchors()
        contentsPanel:addAnchor(AnchorTop, 'miniwindowTopBar', AnchorBottom)
        contentsPanel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        contentsPanel:addAnchor(AnchorRight, 'miniwindowScrollBar', AnchorLeft)
        contentsPanel:addAnchor(AnchorBottom, 'separator', AnchorTop)
        contentsPanel:setMarginLeft(3)
        contentsPanel:setMarginBottom(1)
        contentsPanel:setMarginTop(-2)
        contentsPanel:setMarginRight(1)
        
        -- When pages are active, move upButton to toggleFilterButton position if it's visible
        if upButton and upButton:isVisible() and contextMenuButton and minimizeButton then
            -- Position upButton where toggleFilterButton was
            upButton:breakAnchors()
            upButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
            upButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
            upButton:setMarginRight(7)
            upButton:setMarginTop(0)
            
            -- Move contextMenuButton to the left of upButton
            contextMenuButton:breakAnchors()
            contextMenuButton:addAnchor(AnchorTop, upButton:getId(), AnchorTop)
            contextMenuButton:addAnchor(AnchorRight, upButton:getId(), AnchorLeft)
            contextMenuButton:setMarginRight(2)
            contextMenuButton:setMarginTop(0)
            
            -- Position lockButton to the left of contextMenu
            if lockButton then
                lockButton:breakAnchors()
                lockButton:addAnchor(AnchorTop, contextMenuButton:getId(), AnchorTop)
                lockButton:addAnchor(AnchorRight, contextMenuButton:getId(), AnchorLeft)
                lockButton:setMarginRight(2)
                lockButton:setMarginTop(0)
            end
        end
    else
        -- When pages are hidden, use normal bottom anchor
        scrollbar:breakAnchors()
        scrollbar:addAnchor(AnchorTop, 'parent', AnchorTop)
        scrollbar:addAnchor(AnchorRight, 'parent', AnchorRight)
        scrollbar:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        scrollbar:setMarginTop(16)
        scrollbar:setMarginRight(3)
        scrollbar:setMarginBottom(3)
        
        -- Content panel extends to bottom when pages are hidden
        contentsPanel:breakAnchors()
        contentsPanel:addAnchor(AnchorTop, 'miniwindowTopBar', AnchorBottom)
        contentsPanel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        contentsPanel:addAnchor(AnchorRight, 'miniwindowScrollBar', AnchorLeft)
        contentsPanel:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        contentsPanel:setMarginLeft(3)
        contentsPanel:setMarginBottom(3)
        contentsPanel:setMarginTop(-2)
        contentsPanel:setMarginRight(1)
        
        -- When pages are not active, reset button positions based on upButton visibility
        if upButton and contextMenuButton and minimizeButton then
            if upButton:isVisible() then
                -- Reset upButton to original position
                upButton:breakAnchors()
                upButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
                upButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
                upButton:setMarginRight(3)
                upButton:setMarginTop(0)
                
                -- Position contextMenuButton to the left of upButton
                contextMenuButton:breakAnchors()
                contextMenuButton:addAnchor(AnchorTop, upButton:getId(), AnchorTop)
                contextMenuButton:addAnchor(AnchorRight, upButton:getId(), AnchorLeft)
                contextMenuButton:setMarginRight(2)
                contextMenuButton:setMarginTop(0)
            else
                -- Position contextMenuButton where toggleFilterButton was
                contextMenuButton:breakAnchors()
                contextMenuButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
                contextMenuButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
                contextMenuButton:setMarginRight(7)
                contextMenuButton:setMarginTop(0)
            end
            
            -- Position lockButton to the left of contextMenu
            if lockButton then
                lockButton:breakAnchors()
                lockButton:addAnchor(AnchorTop, contextMenuButton:getId(), AnchorTop)
                lockButton:addAnchor(AnchorRight, contextMenuButton:getId(), AnchorLeft)
                lockButton:setMarginRight(2)
                lockButton:setMarginTop(0)
            end
        end
    end
    
    pagePanel:setVisible(pages)
    separator:setVisible(pages)
end

function refreshContainerPages(container)
    local window = container and container.window
    if not window then
        return
    end

    local currentPage = 1 + math.floor(container:getFirstIndex() / container:getCapacity())
    local pages = 1 + math.floor(math.max(0, (container:getSize() - 1)) / container:getCapacity())
    window:recursiveGetChildById('pageLabel'):setText(string.format('Page %i of %i', currentPage, pages))

    local prevPageButton = window:recursiveGetChildById('prevPageButton')
    local nextPageButton = window:recursiveGetChildById('nextPageButton')
    
    -- If there's only one page, hide both navigation buttons
    if pages == 1 then
        prevPageButton:setVisible(false)
        nextPageButton:setVisible(false)
    else
        -- Multiple pages logic
        if currentPage == 1 then
            -- Hide the back button when on the first page of multiple pages
            prevPageButton:setVisible(false)
        else
            prevPageButton:setVisible(true)
            prevPageButton:setEnabled(true)
            prevPageButton.onClick = function()
                local currentWindow = container.window
                if not currentWindow then
                    return
                end
                -- Store current height before page change
                local currentHeight = currentWindow:getHeight()
                currentWindow.preservedHeight = currentHeight
                g_game.seekInContainer(container:getId(), container:getFirstIndex() - container:getCapacity())
            end
        end

        if currentPage >= pages then
            nextPageButton:setVisible(false)
        else
            nextPageButton:setVisible(true)
            nextPageButton:setEnabled(true)
            nextPageButton.onClick = function()
                local currentWindow = container.window
                if not currentWindow then
                    return
                end
                -- Store current height before page change
                local currentHeight = currentWindow:getHeight()
                currentWindow.preservedHeight = currentHeight
                g_game.seekInContainer(container:getId(), container:getFirstIndex() + container:getCapacity())
            end
        end
    end
end

function onContainerOpen(container, previousContainer)
    cancelGoldPouchResync(container:getId())
    local pendingRewardRequest = pendingRewardChestRequests[container:getId()]
    pendingRewardChestRequests[container:getId()] = nil
    container.rewardChestRequest =
        (pendingRewardRequest and pendingRewardRequest.expiresAt >= g_clock.millis() and pendingRewardRequest)
        or container.rewardChestRequest
        or (previousContainer and previousContainer.rewardChestRequest)
    local pendingPath = pendingContainerPaths[container:getId()]
    pendingContainerPaths[container:getId()] = nil
    if pendingPath and pendingPath.expiresAt >= g_clock.millis() then
        container.restorePath = copyContainerPath(pendingPath.path)
    else
        container.restorePath = buildContainerPath(container)
        -- Page changes and the "up" button reuse the same server container
        -- id and do not pass through Game::open. Recover their stable path
        -- from the window that is being replaced.
        if not container.restorePath and previousContainer then
            local previousPath = previousContainer.restorePath or buildContainerPath(previousContainer)
            local currentItem = container:getContainerItem()
            local currentItemId = currentItem and currentItem:getId()
            if previousPath and currentItemId then
                for depth = #previousPath.segments, 1, -1 do
                    if previousPath.segments[depth].itemId == currentItemId then
                        container.restorePath = copyContainerPath(previousPath, depth)
                        break
                    end
                end
            end
        end
    end
    local savedState = getSavedContainerState(container)
    local containerWindow
    if previousContainer then
        local previousPath = previousContainer.restorePath or buildContainerPath(previousContainer)
        if containerPathKey(previousPath) ~= containerPathKey(container.restorePath) then
            saveContainerState(previousContainer, false)
        end
        containerWindow = previousContainer.window
        previousContainer.window = nil
        previousContainer.itemsPanel = nil
    else
        containerWindow = g_ui.createWidget('ContainerWindow')
    end
    containerWindow:setId('container' .. container:getId())
    local containerPanel = containerWindow:getChildById('contentsPanel')
    local containerItemWidget = containerWindow:getChildById('containerItemWidget')
    containerWindow.onClose = function()
        container.manualClose = true
        saveContainerState(container, false)
        g_game.close(container)
        containerWindow:hide()
    end

    -- this disables scrollbar auto hiding
    local scrollbar = containerWindow:getChildById('miniwindowScrollBar')
    scrollbar:mergeStyle({
        ['$!on'] = {}
    })
    
    -- Scrollbar positioning will be handled by toggleContainerPages function

    local upButton = containerWindow:getChildById('upButton')
    upButton.onClick = function()
        g_game.openParent(container)
    end
    upButton:setVisible(container:hasParent())

    -- Add minimize/maximize event handlers to manage pagePanel visibility
    containerWindow.onMinimize = function()
        local pagePanel = containerWindow:getChildById('pagePanel')
        if pagePanel and pagePanel:isVisible() then
            pagePanel.wasVisibleBeforeMinimize = true
            pagePanel:setVisible(false)
        end
        saveContainerState(container, true)
    end
    
    containerWindow.onMaximize = function()
        local pagePanel = containerWindow:getChildById('pagePanel')
        if pagePanel and pagePanel.wasVisibleBeforeMinimize then
            pagePanel:setVisible(true)
            pagePanel.wasVisibleBeforeMinimize = nil
        end
        saveContainerState(container, true)
    end

    containerWindow.onLockChange = function()
        saveContainerState(container, true)
    end


    -- UIMiniWindow temporarily reparents itself while being dragged. Save on
    -- the next event-loop turn, after the destination panel accepted the drop,
    -- so the final column is persisted immediately instead of relying only on
    -- the later logout signal.
    local inheritedDragLeave = containerWindow.onDragLeave
    containerWindow.onDragLeave = function(self, droppedWidget, mousePos)
        local result = inheritedDragLeave(self, droppedWidget, mousePos)
        scheduleEvent(function()
            if container.window == self then
                saveContainerState(container, true)
                g_settings.save()
            end
        end, 0)
        return result
    end

    -- Hide toggleFilterButton and adjust button positioning
    local toggleFilterButton = containerWindow:recursiveGetChildById('toggleFilterButton')
    if toggleFilterButton then
        toggleFilterButton:setVisible(false)
        toggleFilterButton:setOn(false)
    end
    
    -- Hide newWindowButton
    local newWindowButton = containerWindow:recursiveGetChildById('newWindowButton')
    if newWindowButton then
        newWindowButton:setVisible(false)
    end
    
    local contextMenuButton = containerWindow:recursiveGetChildById('contextMenuButton')
    local lockButton = containerWindow:recursiveGetChildById('lockButton')
    local minimizeButton = containerWindow:recursiveGetChildById('minimizeButton')
    
    -- Make sure contextMenuButton is visible
    if contextMenuButton then
        contextMenuButton:setVisible(true)
    end
    
    if contextMenuButton and minimizeButton then
        if container:hasParent() then
            -- When upButton is visible, position contextMenuButton to its left
            contextMenuButton:breakAnchors()
            contextMenuButton:addAnchor(AnchorTop, upButton:getId(), AnchorTop)
            contextMenuButton:addAnchor(AnchorRight, upButton:getId(), AnchorLeft)
            contextMenuButton:setMarginRight(2)
            contextMenuButton:setMarginTop(0)
        else
            -- When upButton is not visible, position contextMenuButton where toggleFilterButton was
            contextMenuButton:breakAnchors()
            contextMenuButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
            contextMenuButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
            contextMenuButton:setMarginRight(7)
            contextMenuButton:setMarginTop(0)
        end
        
        -- Position lockButton to the left of contextMenu
        if lockButton then
            lockButton:breakAnchors()
            lockButton:addAnchor(AnchorTop, contextMenuButton:getId(), AnchorTop)
            lockButton:addAnchor(AnchorRight, contextMenuButton:getId(), AnchorLeft)
            lockButton:setMarginRight(2)
            lockButton:setMarginTop(0)
        end
        
        -- Add onClick handler for context menu
        contextMenuButton.onClick = function(widget, mousePos, mouseButton)
            return showContainersContextMenu(widget, mousePos, mouseButton)
        end
    end

    local name = container:getName()
    -- The quiver amount is already rendered over its item icon. Newer
    -- protocols may also prefix the container title (for example
    -- "145 Quiver"), which duplicates the same information.
    name = name:gsub('^%s*%d+%s+([Qq]uiver.*)$', '%1')
    name = name:sub(1, 1):upper() .. name:sub(2)

    if name:len() > 14 then
        name = name:sub(1, 14) .. "..."
    end

    -- Set the title in the new miniwindowTitle element
    local titleWidget = containerWindow:getChildById('miniwindowTitle')
    if titleWidget then
        titleWidget:setText(name)
    else
        -- Fallback to old method if miniwindowTitle doesn't exist
        containerWindow:setText(name)
    end

    containerItemWidget:setItem(container:getContainerItem())
    -- Content counters belong on the actual quiver icon (equipment or a
    -- backpack slot), not on the tiny decorative icon in the window header.
    -- Keeping count drawing disabled here also prevents "45 Quiver" when the
    -- server already supplies the clean container name.
    containerItemWidget:setShowCount(false)
    containerItemWidget:setPhantom(true)

    containerPanel:destroyChildren()
    for slot = 0, container:getCapacity() - 1 do
        local itemWidget = g_ui.createWidget('Item', containerPanel)
        itemWidget:setId('item' .. slot)
        itemWidget:setItem(container:getItem(slot))
        ItemsDatabase.setRarityItem(itemWidget, container:getItem(slot))
        ItemsDatabase.setTier(itemWidget, container:getItem(slot))
        itemWidget:setShowDuration(g_game.getFeature(GameThingClock) and modules.client_options.getOption('showExpiryInContainers'))
        itemWidget:setShowCharges(g_game.getFeature(GameThingCounter) and modules.client_options.getOption('showExpiryInContainers'))
        itemWidget:setMargin(0)
        itemWidget.position = container:getSlotPosition(slot)

        if not container:isUnlocked() then
            itemWidget:setBorderColor('red')
        end
    end

    container.window = containerWindow
    container.itemsPanel = containerPanel

    toggleContainerPages(containerWindow, container:hasPages())
    local collectAllButton = containerWindow:getChildById('collectAllButton')
    local chestItem = container:getContainerItem()
    local isRewardChest = chestItem and chestItem:getId() == REWARD_CHEST_ID
    collectAllButton:setVisible(isRewardChest and true or false)
    if isRewardChest then
        collectAllButton:setEnabled(container.rewardChestRequest ~= nil)
        collectAllButton.onClick = function()
            local request = container.rewardChestRequest
            if request then
                g_game.collectRewardChest(request.position, request.itemId, request.stackPos)
            end
        end
        containerPanel:breakAnchors()
        containerPanel:addAnchor(AnchorTop, 'collectAllButton', AnchorBottom)
        containerPanel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        containerPanel:addAnchor(AnchorRight, 'miniwindowScrollBar', AnchorLeft)
        containerPanel:addAnchor(AnchorBottom, container:hasPages() and 'separator' or 'parent',
            container:hasPages() and AnchorTop or AnchorBottom)
        containerPanel:setMarginLeft(3)
        containerPanel:setMarginBottom(container:hasPages() and 1 or 3)
        containerPanel:setMarginTop(2)
        containerPanel:setMarginRight(1)
    end
    refreshContainerPages(container)

    local layout = containerPanel:getLayout()
    local cellSize = layout:getCellSize()
    local step = cellSize.height + layout:getCellSpacing()
    local numLines = math.max(layout:getNumLines(), 1)
    local chromeHeight = (container:hasPages() and 55 or 31) + (isRewardChest and 24 or 0)
    containerWindow:setContentMinimumHeight(cellSize.height)

    local resizeBorder = containerWindow:getChildById('bottomResizeBorder')
    if resizeBorder then
        resizeBorder:setMinimum(step + chromeHeight)
        resizeBorder:setMaximum(numLines * step + chromeHeight)
    end
    -- On Drop: When an item is dropped, it is placed at the nearest valid parent location, such as in a grid.
    containerWindow.onDrop = function(container, widget, mousePos)
        if containerPanel:getChildByPos(mousePos) then
            return false
        end
        local child = containerPanel:getNearestChild(mousePos)
        if child then
            child:onDrop(widget, mousePos, true)
        end
    end

    if not previousContainer then
        local panel = modules.game_interface.findContentPanelAvailable(containerWindow, cellSize.height)
        panel:addChild(containerWindow)
    end

    if not previousContainer or previousContainer:getCapacity() >= container:getCapacity() then
        -- Always set the content height based on the current container's content, with a minimum of one row
        local minRows = 1
        if modules.client_options.getOption('openMaximized') then
            local numLines = math.max(layout:getNumLines(), minRows)
            containerWindow:setContentHeight(numLines * step + chromeHeight)
        else
            local numColumns = math.max(layout:getNumColumns(), 1)
            local filledLines = math.max(math.ceil(container:getItemsCount() / numColumns), minRows)
            containerWindow:setContentHeight(filledLines * step + chromeHeight)
        end
    end

    containerWindow:setup()
    -- A previous instance means this is a page response or a live container
    -- refresh. Preserve the page sent by the server instead of restoring the
    -- stale page stored before the response arrived.
    applySavedContainerState(container, containerWindow, savedState, not previousContainer)
    saveContainerState(container, true)
    containerWindow.onGeometryChange = function()
        if container.window == containerWindow then
            saveContainerState(container, true)
        end
    end
    
    -- Apply current sorting mode if one is active and manual sort mode is disabled
    local currentSortMode = containerSettings and containerSettings['currentSortMode']
    local isManualSortEnabled = containerSettings and containerSettings['useManualSortMode'] == 1
    if currentSortMode and currentSortMode ~= 'none' and not isManualSortEnabled then
        sortContainerItems(container, currentSortMode)
    end
end

function onContainerClose(container)
    destroy(container)
end

function onContainerChangeSize(container, size)
    if not container.window then
        return
    end

    -- Item removal must never collapse an open backpack row by row. Preserve
    -- the user's current window height for ordinary updates as well as page
    -- navigation; a manual resize simply becomes the next preserved height.
    local window = container.window
    local stableHeight = window.preservedHeight or window:getHeight()

    refreshContainerItems(container)
    scheduleGoldPouchResync(container)

    window:setHeight(stableHeight)
    window.preservedHeight = nil
    scheduleEvent(function()
        if container.window == window then
            window:setHeight(stableHeight)
        end
    end, 0)
end

function onContainerUpdateItem(container, slot, item, oldItem)
    if not container.window then
        return
    end
    local itemWidget = container.itemsPanel:getChildById('item' .. slot)
    itemWidget:setItem(item)
    ItemsDatabase.setRarityItem(itemWidget, item)
    ItemsDatabase.setTier(itemWidget, item)
    itemWidget:setShowDuration(g_game.getFeature(GameThingClock) and modules.client_options.getOption('showExpiryInContainers'))
    itemWidget:setShowCharges(g_game.getFeature(GameThingCounter) and modules.client_options.getOption('showExpiryInContainers'))
    scheduleGoldPouchResync(container)
    
    -- Note: Removed automatic re-sorting to prevent interference with manual item movement
    -- Sorting should only happen when explicitly requested by the user
end
