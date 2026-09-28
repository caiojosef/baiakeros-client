helperV2Window = nil
helperV2Button = nil

local selectedTab = 'healing'
function showHelperV2Tab(tabName)
    if not helperV2Window then return end
    local healingSelected = tabName ~= 'attack'
    selectedTab = healingSelected and 'healing' or 'attack'
    helperV2Window:setText(healingSelected and 'BaiakEros Helper 2 - Healing & Tools'
        or 'BaiakEros Helper 2 - Attack (Preview)')
    local healingPage = helperV2Window:recursiveGetChildById('healingToolsPage')
    local attackPage = helperV2Window:recursiveGetChildById('attackPage')
    local healingTab = helperV2Window:recursiveGetChildById('healingToolsTab')
    local attackTab = helperV2Window:recursiveGetChildById('attackTab')
    healingPage:setVisible(healingSelected)
    attackPage:setVisible(not healingSelected)
    healingTab:setOn(healingSelected)
    healingTab:setEnabled(not healingSelected)
    attackTab:setOn(not healingSelected)
    attackTab:setEnabled(healingSelected)
end

function show()
    if not helperV2Window or not g_game.isOnline() then return end
    showHelperV2Tab(selectedTab)
    helperV2Window:show()
    helperV2Window:raise()
    helperV2Window:focus()
    if helperV2Button then helperV2Button:setOn(true) end
end

function hide()
    if helperV2Window then helperV2Window:hide() end
    if helperV2Button then helperV2Button:setOn(false) end
end

function toggle()
    if not helperV2Window then return end
    if helperV2Window:isVisible() then hide() else show() end
end

local function onGameStart()
    if helperV2Button then return end
    helperV2Button = modules.game_mainpanel.addToggleButton(
        'baiakerosHelperV2Button',
        tr('BaiakEros Helper 2 (Preview)'),
        '/images/options/button_spells',
        toggle,
        false,
        31
    )
    helperV2Button:setOn(false)
end

local function onGameEnd()
    hide()
end

function init()
    g_ui.importStyle('helper_v2')
    helperV2Window = g_ui.createWidget('BaiakerosHelperV2Window', rootWidget)
    showHelperV2Tab('healing')

    BaiakHelperHealingV2.init(helperV2Window)
    BaiakHelperToolsV2.init(helperV2Window)
    BaiakHelperAttackV2.init(helperV2Window)

    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    if g_game.isOnline() then onGameStart() end
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })

    BaiakHelperHealingV2.terminate()

    if helperV2Button then
        helperV2Button:destroy()
        helperV2Button = nil
    end
    if helperV2Window then
        helperV2Window:destroy()
        helperV2Window = nil
    end
end


