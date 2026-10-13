local OPCODE = 216
local codexWindow
local codexData = { collections = {}, categories = {}, bonuses = {}, completed = 0, total = 0 }
local selectedCategory = 'beginner'

local categoryButtonIds = {
    beginner = 'categoryBeginner',
    intermediate = 'categoryIntermediate',
    advanced = 'categoryAdvanced',
    elite = 'categoryElite',
    boss = 'categoryBoss'
}

local function child(id)
    return codexWindow and codexWindow:recursiveGetChildById(id)
end

local function sendRequest(action, extra)
    if not g_game.isOnline() then return end
    local protocol = g_game.getProtocolGame()
    if not protocol then return end
    local request = extra or {}
    request.action = action
    protocol:sendExtendedOpcode(OPCODE, json.encode(request))
end

local function ensureWindow(parent)
    if codexWindow then return true end
    if not parent then return false end
    local ok, result = pcall(function()
        g_ui.importStyle('codex')
        codexWindow = g_ui.createWidget('CodexPanel', parent)
        codexWindow:hide()
    end)
    if not ok then
        if codexWindow then codexWindow:destroy(); codexWindow = nil end
        g_logger.error('[Codex] Unable to create window: ' .. tostring(result))
        return false
    end
    return true
end

local function deposit(collectionId, itemId)
    sendRequest('deposit', { collectionId = collectionId, itemId = itemId })
end

local function addCollectionCard(collection)
    local card = g_ui.createWidget('CodexCollection', child('collectionList'))
    card:getChildById('title'):setText(collection.title .. '  Reward: ' .. tostring(collection.reward or ''))
    local unlocked = collection.unlocked ~= false
    local status = collection.completed and 'COMPLETED' or (unlocked and 'IN PROGRESS' or 'LOCKED')
    card:getChildById('status'):setText(status)
    card:getChildById('status'):setColor(collection.completed and '#73d673' or (unlocked and '#bdbdbd' or '#d98a8a'))
    local description = table.concat(collection.monsters or {}, ', ')
    if not unlocked and collection.lockedReason and collection.lockedReason ~= '' then
        description = description .. '  |  ' .. collection.lockedReason
    end
    card:getChildById('monsters'):setText(description)

    local holder = card:getChildById('requirements')
    for index, requirement in ipairs(collection.requirements or {}) do
        local widget = g_ui.createWidget('CodexRequirement', holder)
        widget:setId('requirement' .. index)
        local column = (index - 1) % 4
        local row = math.floor((index - 1) / 4)
        widget:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        widget:addAnchor(AnchorTop, 'parent', AnchorTop)
        widget:setMarginLeft(column * 126)
        widget:setMarginTop(row * 116)

        local item = widget:getChildById('item')
        item:setItemId(requirement.itemId)
        item:setTooltip(requirement.name)
        local owned = tonumber(requirement.available) or 0
        local delivered = tonumber(requirement.delivered) or 0
        local needed = tonumber(requirement.required) or 0
        item:setOpacity((owned > 0 or delivered >= needed) and 1.0 or 0.28)
        widget:getChildById('amount'):setText(string.format('%d / %d', delivered, needed))
        widget:getChildById('available'):setText(string.format('Have: %d', owned))
        local button = widget:getChildById('deposit')
        button:setEnabled(unlocked and not collection.completed and delivered < needed and owned > 0)
        button.onClick = function() deposit(collection.id, requirement.serverId) end
    end
end

local function selectCategory(categoryId)
    selectedCategory = categoryId
    refresh()
end

local function refreshCategories()
    for _, category in ipairs(codexData.categories or {}) do
        local button = child(categoryButtonIds[category.id])
        if button then
            local prefix = category.unlocked == false and '[LOCKED] ' or ''
            button:setText(string.format('%s%s (%d/%d)', prefix, category.title or category.id,
                tonumber(category.completed) or 0, tonumber(category.total) or 0))
            button:setColor(category.id == selectedCategory and '#f0d48a' or (category.unlocked == false and '#8a8a8a' or '#c8c8c8'))
            button:setTooltip(category.unlocked == false and tostring(category.lockedReason or '') or '')
            button.onClick = function() selectCategory(category.id) end
        end
    end
end

function refresh()
    if not codexWindow then return end
    refreshCategories()
    local selectedTitle = selectedCategory
    for _, category in ipairs(codexData.categories or {}) do
        if category.id == selectedCategory then selectedTitle = category.title end
    end
    child('heading'):setText(tostring(selectedTitle) .. ' Codex')
    child('points'):setText('Active global bonuses')
    child('completed'):setText(string.format('Collections: %d / %d', codexData.completed or 0, codexData.total or 0))
    local bonuses = codexData.bonuses or {}
    child('preview'):setText(string.format('Attack / Damage: +%.2f%%\nHealing: +%.2f%%\nDefense: +%.2f%%\n\nOnslaught: +%.2f%%\nRuse: +%.2f%%\nMomentum: +%.2f%%\nTranscendence: +%.2f%%\nAmplification: +%.2f%%\n\nBonuses are global and cumulative.',
        tonumber(bonuses.damage) or 0, tonumber(bonuses.healing) or 0, tonumber(bonuses.defense) or 0,
        tonumber(bonuses.onslaught) or 0, tonumber(bonuses.ruse) or 0, tonumber(bonuses.momentum) or 0,
        tonumber(bonuses.transcendence) or 0, tonumber(bonuses.amplification) or 0))
    local list = child('collectionList')
    list:destroyChildren()
    for _, collection in ipairs(codexData.collections or {}) do
        if collection.category == selectedCategory then
            local ok, message = pcall(addCollectionCard, collection)
            if not ok then g_logger.error('[Codex] Unable to render collection ' .. tostring(collection.id) .. ': ' .. tostring(message)) end
        end
    end
end

local function onExtendedOpcode(protocol, opcode, buffer)
    local ok, decoded = pcall(json.decode, buffer)
    if not ok or type(decoded) ~= 'table' or decoded.action ~= 'sync' then
        g_logger.error('[Codex] Invalid server payload: ' .. tostring(buffer))
        return
    end
    codexData = decoded
    refresh()
end

local function online()
    scheduleEvent(function() sendRequest('sync') end, 1200)
end

local function offline()
    codexData = { collections = {}, categories = {}, bonuses = {}, completed = 0, total = 0 }
    hide()
end

function createPanel(parent)
    if not ensureWindow(parent) then return nil end
    codexWindow:setParent(parent)
    codexWindow:breakAnchors()
    codexWindow:fill('parent')
    codexWindow:hide()
    refresh()
    return codexWindow
end

function show()
    if modules.game_progress then modules.game_progress.show('codex') end
end

function hide()
    if modules.game_progress then modules.game_progress.hide() end
end

function toggle()
    if modules.game_progress then modules.game_progress.toggle('codex') end
end

function refreshFromServer()
    sendRequest('sync')
end

function init()
    ProtocolGame.registerExtendedOpcode(OPCODE, onExtendedOpcode)
    connect(g_game, { onGameStart = online, onGameEnd = offline })
    if g_game.isOnline() then online() end
end

function terminate()
    disconnect(g_game, { onGameStart = online, onGameEnd = offline })
    ProtocolGame.unregisterExtendedOpcode(OPCODE)
    if codexWindow then codexWindow:destroy(); codexWindow = nil end
end
