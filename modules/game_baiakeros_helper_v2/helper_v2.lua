helperV2Window = nil

local selectedTab = 'healing'
local cavebotFloatWindow
local cavebotPanel
local cavebotHomeParent
local cavebotScriptPanel
local cavebotScriptHome
local cavebotWorkspace
local cavebotConfigColumn
local cavebotDivider
local cavebotRankingDivider
local cavebotDetached = false

local function explorerActive()
    return BaiakHelperExplorerV2 and BaiakHelperExplorerV2.isAutoExplorerActive and
        BaiakHelperExplorerV2.isAutoExplorerActive()
end

local function setCavebotCompact(compact)
    if not cavebotFloatWindow or not cavebotDetached then return end
    cavebotFloatWindow:setHeight(compact and 168 or 570)
    cavebotFloatWindow:recursiveGetChildById('v2CavebotFloatSlot'):setVisible(not compact)
    cavebotFloatWindow:recursiveGetChildById('v2CavebotCompactPanel'):setVisible(compact)
    cavebotFloatWindow:recursiveGetChildById('v2CavebotReturnButton'):setVisible(not compact)
    cavebotFloatWindow:recursiveGetChildById('v2CavebotMinimizeButton'):setVisible(not compact)
    cavebotFloatWindow:recursiveGetChildById('v2CavebotExpandButton'):setVisible(compact)
end

function minimizeCavebot()
    setCavebotCompact(true)
end

function expandCavebot()
    setCavebotCompact(false)
end

function updateCavebotCompact(time, percent, color, active)
    if not cavebotFloatWindow then return end
    local get = function(id) return cavebotFloatWindow:recursiveGetChildById(id) end
    get('v2CavebotCompactTime'):setText(time)
    local percentLabel = get('v2CavebotCompactPercent')
    percentLabel:setText(percent .. '%')
    percentLabel:setColor(color)
    local progress = get('v2CavebotCompactProgress')
    progress:setPercent(percent)
    progress:setBackgroundColor(color)
    get('v2CavebotCompactStopButton'):setVisible(active)
    get('v2CavebotReturnButton'):setText(active and 'Open Helper' or 'Back to Helper')
end

function stopFromCompactCavebot()
    if not explorerActive() then return end
    cavebotPanel:recursiveGetChildById('v2CavebotAutoExploringButton').onClick()
end

local function setHelperButtonOn(enabled)
    local helper = modules.game_baiakeros_helper
    if helper and helper.setHelperButtonOn then
        helper.setHelperButtonOn(enabled)
    end
end

local function shortExperience(value)
    local number = tonumber(value) or 0
    if number >= 1000000000 then return string.format('%.1fB XP', number / 1000000000) end
    if number >= 1000000 then return string.format('%.1fM XP', number / 1000000) end
    if number >= 1000 then return string.format('%.1fK XP', number / 1000) end
    return string.format('%d XP', number)
end

function updateCavebotRanking(daily, monthly)
    if not cavebotWorkspace then return end
    for _, group in ipairs({ { 'Daily', daily }, { 'Monthly', monthly } }) do
        for rank = 1, 4 do
            local label = cavebotWorkspace:recursiveGetChildById('v2Cavebot' .. group[1] .. rank)
            local player = group[2][rank]
            if label then
                if player then
                    local name = tostring(player.name or 'Unknown')
                    if #name > 17 then name = name:sub(1, 16) .. '…' end
                    label:setText(rank .. '. ' .. name .. '  -  ' .. shortExperience(player.experience))
                else
                    label:setText(rank .. '. ---')
                end
            end
        end
    end
end

local function attachCavebot(force)
    if not cavebotDetached or not cavebotPanel then return false end
    if explorerActive() and not force then return false end
    setCavebotCompact(false)
    modules.game_walk.unbindMovementKeysFromWidget(cavebotFloatWindow)
    cavebotConfigColumn:show()
    cavebotWorkspace:show()
    cavebotDivider:show()
    cavebotRankingDivider:show()
    cavebotPanel:setParent(cavebotHomeParent)
    cavebotPanel:breakAnchors()
    cavebotPanel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    cavebotPanel:addAnchor(AnchorRight, 'parent', AnchorRight)
    cavebotPanel:addAnchor(AnchorTop, 'parent', AnchorTop)
    cavebotPanel:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    cavebotPanel:setMarginLeft(6)
    cavebotPanel:setMarginRight(7)
    local runtimeColumn = cavebotPanel:recursiveGetChildById('v2CavebotRuntimeColumn')
    runtimeColumn:breakAnchors()
    runtimeColumn:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    runtimeColumn:addAnchor(AnchorTop, 'parent', AnchorTop)
    runtimeColumn:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    runtimeColumn:setWidth(260)
    cavebotPanel:recursiveGetChildById('v2CavebotAutoExploringButton'):setMarginLeft(-16)
    cavebotPanel:recursiveGetChildById('v2CavebotDetachButton'):show()
    cavebotDetached = false
    cavebotFloatWindow:hide()
    if g_game.isOnline() then modules.game_interface.getRootPanel():focus() end
    return true
end

function detachCavebot()
    if cavebotDetached or not cavebotFloatWindow or not g_game.isOnline() then return end
    local slot = cavebotFloatWindow:recursiveGetChildById('v2CavebotFloatSlot')
    cavebotConfigColumn:hide()
    cavebotWorkspace:hide()
    cavebotDivider:hide()
    cavebotRankingDivider:hide()
    cavebotPanel:setParent(slot)
    cavebotPanel:breakAnchors()
    cavebotPanel:fill('parent')
    cavebotPanel:setMarginLeft(0)
    cavebotPanel:setMarginRight(0)
    local runtimeColumn = cavebotPanel:recursiveGetChildById('v2CavebotRuntimeColumn')
    runtimeColumn:breakAnchors()
    runtimeColumn:fill('parent')
    cavebotPanel:recursiveGetChildById('v2CavebotAutoExploringButton'):setMarginLeft(0)
    cavebotPanel:recursiveGetChildById('v2CavebotDetachButton'):hide()
    cavebotDetached = true
    setCavebotCompact(false)
    helperV2Window:hide()
    setHelperButtonOn(false)
    cavebotFloatWindow:show()
    cavebotFloatWindow:raise()
    modules.game_walk.bindMovementKeysToWidget(cavebotFloatWindow)
    cavebotFloatWindow:focus()
end

function closeDetachedCavebot()
    if explorerActive() then
        minimizeCavebot()
    else
        attachCavebot()
    end
end

function returnCavebotToHelper()
    if not explorerActive() and not attachCavebot() then return end
    showHelperV2Tab('cavebot')
    show()
end

function showHelperV2Tab(tabName)
    if not helperV2Window then return end
    if tabName ~= 'healing' and tabName ~= 'attack' and tabName ~= 'cavebot' then
        tabName = 'healing'
    end
    selectedTab = tabName
    helperV2Window:setText('Baiakeros Helper')
    local healingPage = helperV2Window:recursiveGetChildById('healingToolsPage')
    local attackPage = helperV2Window:recursiveGetChildById('attackPage')
    local cavebotPage = helperV2Window:recursiveGetChildById('cavebotPage')
    local healingTab = helperV2Window:recursiveGetChildById('healingToolsTab')
    local attackTab = helperV2Window:recursiveGetChildById('attackTab')
    local cavebotTab = helperV2Window:recursiveGetChildById('cavebotTab')
    for _, tab in ipairs({
        { name = 'healing', page = healingPage, button = healingTab,
            label = 'Healing & Tools', width = 162 },
        { name = 'attack', page = attackPage, button = attackTab,
            label = 'Attack', width = 116 },
        { name = 'cavebot', page = cavebotPage, button = cavebotTab,
            label = 'Cavebot', width = 116 }
    }) do
        local active = tabName == tab.name
        tab.page:setVisible(active)
        tab.button:setWidth(active and tab.width or 34)
        tab.button:setText(active and tab.label or '')
        tab.button:setOn(active)
        tab.button:setEnabled(not active)
    end
end

function show()
    if not helperV2Window or not g_game.isOnline() then return end
    if cavebotDetached and not explorerActive() then attachCavebot() end
    showHelperV2Tab(selectedTab)
    helperV2Window:show()
    helperV2Window:raise()
    helperV2Window:focus()
    setHelperButtonOn(true)
end

function hide()
    if explorerActive() and not cavebotDetached then detachCavebot() end
    if helperV2Window then helperV2Window:hide() end
    setHelperButtonOn(false)
end

local shouldRestoreAfterHealingAssignment = false

function hideForHealingAssignment()
    shouldRestoreAfterHealingAssignment = helperV2Window and helperV2Window:isVisible() or false
    if shouldRestoreAfterHealingAssignment then hide() end
end

function restoreAfterHealingAssignment()
    if not shouldRestoreAfterHealingAssignment then return end
    shouldRestoreAfterHealingAssignment = false
    show()
end

function toggle()
    if not helperV2Window then return end
    if helperV2Window:isVisible() then hide() else show() end
end

local function onGameStart()
    BaiakHelperExplorerV2.onGameStart()
end

local function onGameEnd()
    BaiakHelperExplorerV2.onGameEnd()
    attachCavebot(true)
    hide()
    shouldRestoreAfterHealingAssignment = false
end

function init()
    g_ui.importStyle('healing')
    g_ui.importStyle('helper_v2')
    helperV2Window = g_ui.createWidget('BaiakerosHelperV2Window', rootWidget)
    cavebotFloatWindow = g_ui.createWidget('BaiakerosCavebotFloatWindow', rootWidget)
    cavebotPanel = helperV2Window:recursiveGetChildById('cavebotPanel')
    cavebotHomeParent = cavebotPanel:getParent()
    cavebotScriptPanel = cavebotPanel:recursiveGetChildById('v2CavebotScriptPanel')
    cavebotScriptHome = cavebotPanel:recursiveGetChildById('v2CavebotScriptHomeSlot')
    cavebotWorkspace = cavebotPanel:recursiveGetChildById('v2CavebotWorkspace')
    cavebotConfigColumn = cavebotPanel:recursiveGetChildById('v2CavebotConfigColumn')
    cavebotDivider = cavebotPanel:recursiveGetChildById('v2CavebotMainDivider')
    cavebotRankingDivider = cavebotPanel:recursiveGetChildById('v2CavebotRankingDivider')
    cavebotScriptPanel:setParent(cavebotScriptHome)
    cavebotScriptPanel:breakAnchors()
    cavebotScriptPanel:fill('parent')
    cavebotPanel:recursiveGetChildById('v2CavebotDetachButton').onClick = detachCavebot
    cavebotFloatWindow:recursiveGetChildById('v2CavebotCompactPanel'):hide()
    showHelperV2Tab('healing')

    BaiakHelperHealingV2.init(helperV2Window)
    BaiakHelperTrainingV2.init(helperV2Window)
    BaiakHelperToolsV2.init(helperV2Window)
    BaiakHelperAttackV2.init(helperV2Window)
    BaiakHelperExplorerV2.init(helperV2Window)

    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    if g_game.isOnline() then onGameStart() end
end

function terminate()
    shouldRestoreAfterHealingAssignment = false
    attachCavebot(true)
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    BaiakHelperHealingV2.terminate()
    BaiakHelperTrainingV2.terminate()
    BaiakHelperToolsV2.terminate()
    BaiakHelperAttackV2.terminate()
    BaiakHelperExplorerV2.terminate()

    if cavebotFloatWindow then
        cavebotFloatWindow:destroy()
        cavebotFloatWindow = nil
    end
    cavebotPanel = nil
    cavebotHomeParent = nil
    cavebotScriptPanel = nil
    cavebotScriptHome = nil
    cavebotWorkspace = nil
    cavebotConfigColumn = nil
    cavebotDivider = nil
    cavebotRankingDivider = nil

    setHelperButtonOn(false)
    if helperV2Window then
        helperV2Window:destroy()
        helperV2Window = nil
    end
end


