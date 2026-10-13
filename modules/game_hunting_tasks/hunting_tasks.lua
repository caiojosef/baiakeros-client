local OPCODE = 215
local taskWindow
local taskData = { tasks = {}, history = {}, actives = {}, ranking = {} }
local currentFilter = 'available'
local confirmWindow

local function taskWidget(id)
    return taskWindow and taskWindow:recursiveGetChildById(id)
end

local function ensureTaskWindow(parent)
    if taskWindow then return true end
    if not parent then return false end
    local ok, result = pcall(function()
        g_ui.importStyle('hunting_tasks')
        taskWindow = g_ui.createWidget('HuntingTasksPanel', parent)
        taskWidget('availableFilter').onClick = function() selectFilter('available') end
        taskWidget('progressFilter').onClick = function() selectFilter('progress') end
        taskWidget('completedFilter').onClick = function() selectFilter('completed') end
        taskWidget('historyFilter').onClick = function() selectFilter('history') end
        taskWidget('rankingFilter').onClick = function() selectFilter('ranking') end
        selectFilter('available')
    end)
    if not ok then
        if taskWindow then taskWindow:destroy(); taskWindow = nil end
        g_logger.error('[Hunting Tasks] Unable to create window: ' .. tostring(result))
        return false
    end
    return true
end

local difficultyNames = { 'Beginner', 'Intermediate', 'Advanced', 'Elite', 'Boss' }

local function sendRequest(action, extra)
    if not g_game.isOnline() then return end
    local protocol = g_game.getProtocolGame()
    if not protocol then return end
    local request = extra or {}
    request.action = action
    protocol:sendExtendedOpcode(OPCODE, json.encode(request))
end

local function findTask(taskId)
    for _, task in ipairs(taskData.tasks or {}) do
        if task.id == taskId then return task end
    end
end

local function findActive(taskId)
    for _, active in ipairs(taskData.actives or {}) do
        if active.taskId == taskId then return active end
    end
end

local function formatNumber(value)
    local formatted = tostring(math.floor(tonumber(value) or 0))
    while true do
        local result, count = formatted:gsub('^(%-?%d+)(%d%d%d)', '%1,%2')
        formatted = result
        if count == 0 then break end
    end
    return formatted
end

local function closeConfirm()
    if confirmWindow then
        confirmWindow:destroy()
        confirmWindow = nil
    end
end

local function requestAbandon(taskId)
    closeConfirm()
    sendRequest('abandon', { taskId = taskId })
end

local function confirmAbandon(task)
    closeConfirm()
    confirmWindow = displayGeneralBox('Abandon Task',
        'Do you really want to abandon ' .. task.title .. '? All progress in this stage will be lost.', {
            { text = 'Yes', callback = function() requestAbandon(task.id) end },
            { text = 'No', callback = closeConfirm },
            anchor = AnchorHorizontalCenter
        }, nil, closeConfirm)
end

local function chooseReward(task)
    closeConfirm()
    confirmWindow = g_ui.createWidget('MessageBoxWindow', rootWidget)
    confirmWindow:setWidth(430)
    local rewardChoices = task.rewardChoices or {}
    confirmWindow:setHeight(#rewardChoices > 3 and 202 or 142)
    confirmWindow:getChildById('title'):setText('Choose Your Reward')

    local content = confirmWindow:getChildById('content')
    content:setText(task.rewardText or 'Choose one reward:')
    content:setWidth(400)
    content:resizeToText()

    local imbuementIcons = {
        strike = '/images/game/imbuing/icons/3',
        vampirism = '/images/game/imbuing/icons/48',
        void = '/images/game/imbuing/icons/51'
    }
    local exerciseItems = {
        sword = 35285,
        axe = 35286,
        club = 35287,
        bow = 35288,
        rod = 35289,
        wand = 35290
    }
    local holder = confirmWindow:getChildById('holder')
    for index, choice in ipairs(rewardChoices) do
        local selectedChoice = choice
        local button = g_ui.createWidget('TaskRewardChoiceButton', holder)
        button:setId('rewardChoice' .. index)
        local choiceIcon = button:getChildById('choiceIcon')
        local choiceItem = button:getChildById('choiceItem')
        local itemId = selectedChoice.itemId or exerciseItems[selectedChoice.key]
        if itemId and itemId > 0 then
            choiceIcon:hide()
            choiceItem:setItemId(itemId)
            choiceItem:show()
        else
            choiceIcon:setImageSource(imbuementIcons[selectedChoice.key] or '/images/game/imbuing/icons/0')
        end
        button:getChildById('choiceLabel'):setText(selectedChoice.name)
        if index > 3 then
            button:addAnchor(AnchorTop, 'rewardChoice' .. (index - 3), AnchorBottom)
            button:setMarginTop(8)
        else
            button:addAnchor(AnchorTop, 'parent', AnchorTop)
        end
        if (index - 1) % 3 ~= 0 then
            button:addAnchor(AnchorLeft, 'prev', AnchorRight)
            button:setMarginLeft(8)
        else
            button:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        end
        button.onClick = function()
            closeConfirm()
            sendRequest('claim', { taskId = task.id, choice = selectedChoice.key })
        end
    end
    confirmWindow.onEscape = closeConfirm
    confirmWindow:raise()
    confirmWindow:focus()
end

local function acceptTask(task)
    if (task.unlockCost or 0) <= 0 then
        sendRequest('accept', { taskId = task.id })
        return
    end
    closeConfirm()
    confirmWindow = displayGeneralBox('Unlock Stage 3',
        string.format('Stage 3 of %s costs %s gold. The server will use money from your inventory and bank. This payment is not refunded if you abandon the task. Continue?', task.title, formatNumber(task.unlockCost)), {
            { text = 'Pay & Accept', callback = function() closeConfirm(); sendRequest('accept', { taskId = task.id }) end },
            { text = 'Cancel', callback = closeConfirm },
            anchor = AnchorHorizontalCenter
        }, nil, closeConfirm)
end

local function taskAction(task, mode)
    if task.locked then return end
    if mode == 'available' then
        acceptTask(task)
    elseif mode == 'progress' then
        confirmAbandon(task)
    elseif mode == 'completed' then
        if task.rewardChoices and #task.rewardChoices > 0 then chooseReward(task)
        else sendRequest('claim', { taskId = task.id }) end
    end
end

local function formatMonsterNames(monsters)
    local text = table.concat(monsters or {}, ', ')
    if #text > 150 then text = text:sub(1, 147) .. '...' end
    return text
end

local function setupCreature(widget, outfit)
    if outfit and outfit.lookType and outfit.lookType > 0 then
        widget:setOutfit(outfit)
        widget:show()
    else
        widget:hide()
    end
end

local function addTaskCard(task, mode)
    local list = taskWidget('taskList')
    local card = g_ui.createWidget('TaskCard', list)
    card.titleLabel:setText(string.format('%s - Stage %d/%d', task.title, task.stage or 1, task.maxStage or 3))
    card.difficultyLabel:setText(difficultyNames[task.difficulty] or ('Tier ' .. task.difficulty))
    card.monstersLabel:setText(formatMonsterNames(task.monsters))
    card.monstersLabel:setTooltip(table.concat(task.monsters or {}, '\n'))
    card.rewardLabel:setText('Reward: ' .. (task.rewardText or task.rewardType))
    if task.locked and task.lockReason and task.lockReason ~= '' then
        card.rewardLabel:setText('Reward: ' .. (task.rewardText or task.rewardType) .. '\nLocked: ' .. task.lockReason)
        card.rewardLabel:setColor('#d7a36a')
    end
    for index = 1, 3 do
        setupCreature(card.creaturePanel:getChildById('creature' .. index), task.outfits and task.outfits[index])
    end

    local progress = 0
    local active = findActive(task.id)
    if active then
        progress = active.progress or 0
    end
    card.progressBar:setMinimum(0)
    card.progressBar:setMaximum(task.amount)
    card.progressBar:setValue(progress)
    card.progressBar:setText(progress .. ' / ' .. task.amount)

    local buttonText = mode == 'available' and 'Accept' or (mode == 'progress' and 'Abandon' or 'Claim')
    if mode == 'available' and (task.unlockCost or 0) > 0 then buttonText = 'Unlock' end
    if mode == 'available' and task.locked then buttonText = 'Locked' end
    card.actionButton:setText(buttonText)
    card.actionButton:setEnabled(not task.locked)
    card.actionButton.onClick = function() taskAction(task, mode) end
end

local function addHistoryCard(entry)
    local card = g_ui.createWidget('TaskHistoryCard', taskWidget('taskList'))
    local task = findTask(entry.taskId)
    card.titleLabel:setText((task and task.title or entry.taskId) .. ' - Stage ' .. tostring(entry.stage or 1))
    card.rewardLabel:setText('Reward: ' .. (entry.reward or ''))
    card.dateLabel:setText(os.date('%d/%m/%Y %H:%M', entry.claimedAt or 0))
end

local function addRankingCard(entry)
    local card = g_ui.createWidget('TaskRankingCard', taskWidget('taskList'))
    card.positionLabel:setText('#' .. tostring(entry.position or '-'))
    card.playerLabel:setText(entry.name or 'Unknown')
    card.completedLabel:setText(string.format('%d completed stage(s)', entry.completed or 0))
    card.linesLabel:setText(string.format('%d task line(s)', entry.lines or 0))
end

local function setFilterButtons()
    for name, id in pairs({ available = 'availableFilter', progress = 'progressFilter', completed = 'completedFilter', history = 'historyFilter', ranking = 'rankingFilter' }) do
        taskWidget(id):setOn(name == currentFilter)
    end
end

function refresh()
    if not taskWindow then return end
    taskWidget('taskList'):destroyChildren()
    setFilterButtons()
    local actives = taskData.actives or {}
    if #actives > 0 then
        local working, completed = 0, 0
        for _, active in ipairs(actives) do
            if active.state == 1 then completed = completed + 1 else working = working + 1 end
        end
        taskWidget('activeSummary'):setText(string.format('Active tasks: %d\nIn progress: %d\nRewards ready: %d', #actives, working, completed))
    else
        taskWidget('activeSummary'):setText('No active tasks.\n\nYou can accept multiple different tasks.')
    end

    local titles = { available = 'Available Tasks', progress = 'Task In Progress', completed = 'Completed Task', history = 'Reward History', ranking = 'Task High Score' }
    taskWidget('sectionTitle'):setText(titles[currentFilter])
    local count = 0
    if currentFilter == 'history' then
        for _, entry in ipairs(taskData.history or {}) do addHistoryCard(entry); count = count + 1 end
    elseif currentFilter == 'ranking' then
        for _, entry in ipairs(taskData.ranking or {}) do addRankingCard(entry); count = count + 1 end
    else
        for _, task in ipairs(taskData.tasks or {}) do
            local active = findActive(task.id)
            local isActive = active ~= nil
            local visible = (currentFilter == 'available' and not isActive and not task.completedAll)
                or (currentFilter == 'progress' and isActive and active.state == 0)
                or (currentFilter == 'completed' and isActive and active.state == 1)
            if visible then addTaskCard(task, currentFilter); count = count + 1 end
        end
    end
    if count == 0 then
        local empty = g_ui.createWidget('Label', taskWidget('taskList'))
        empty:setHeight(60)
        empty:setText(currentFilter == 'history' and 'No rewards claimed yet.' or
            (currentFilter == 'ranking' and 'No completed tasks in the ranking yet.' or 'There are no tasks in this category.'))
        empty:setTextAlign(AlignCenter)
        empty:setColor('#a8a8a8')
    end
    taskWidget('statusLabel'):setText(string.format('%d task(s) shown', count))
end

function selectFilter(filterName)
    currentFilter = filterName
    refresh()
end

local function onExtendedOpcode(protocol, opcode, buffer)
    local ok, decoded = pcall(json.decode, buffer)
    if not ok or type(decoded) ~= 'table' or decoded.action ~= 'sync' then
        g_logger.error('[Hunting Tasks] Invalid server payload: ' .. tostring(decoded))
        return
    end
    taskData.tasks = decoded.tasks or {}
    taskData.history = decoded.history or {}
    taskData.actives = decoded.actives or (decoded.active and { decoded.active }) or {}
    taskData.ranking = decoded.ranking or {}
    if #taskData.actives > 0 then
        local hasCompleted = false
        for _, active in ipairs(taskData.actives) do if active.state == 1 then hasCompleted = true; break end end
        currentFilter = hasCompleted and 'completed' or 'progress'
    end
    refresh()
end

local function online()
    scheduleEvent(function() sendRequest('sync') end, 800)
end

local function offline()
    closeConfirm()
    taskData = { tasks = {}, history = {}, actives = {}, ranking = {} }
    hide()
end

function createPanel(parent)
    if not ensureTaskWindow(parent) then return nil end
    taskWindow:setParent(parent)
    taskWindow:breakAnchors()
    taskWindow:fill('parent')
    taskWindow:hide()
    refresh()
    return taskWindow
end

function refreshFromServer()
    sendRequest('sync')
end

function onTabHidden()
    closeConfirm()
end

function show()
    if modules.game_progress then modules.game_progress.show('tasks') end
end

function hide()
    closeConfirm()
    if modules.game_progress then modules.game_progress.hide() end
end

function toggle()
    if modules.game_progress then modules.game_progress.toggle('tasks') end
end

function init()
    ProtocolGame.registerExtendedOpcode(OPCODE, onExtendedOpcode)
    connect(g_game, { onGameStart = online, onGameEnd = offline })

    if g_game.isOnline() then online() end
end

function terminate()
    closeConfirm()
    disconnect(g_game, { onGameStart = online, onGameEnd = offline })
    ProtocolGame.unregisterExtendedOpcode(OPCODE)
    if taskWindow then taskWindow:destroy(); taskWindow = nil end
    modules.game_mainpanel.reloadMainPanelSizes()
end
