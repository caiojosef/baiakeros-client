local progressWindow
local progressButton
local panels = {}
local selectedTab = 'tasks'

local function ensureWindow()
    if progressWindow and panels.tasks and panels.codex then return true end
    if not progressWindow then
        g_ui.importStyle('progress')
        progressWindow = g_ui.createWidget('BaiakerosProgressWindow', rootWidget)
    end
    local container = progressWindow:getChildById('contentContainer')
    panels.tasks = modules.game_hunting_tasks.createPanel(container)
    panels.codex = modules.game_codex.createPanel(container)
    if not panels.tasks or not panels.codex then
        g_logger.error('[Progresso] Unable to create Tasks or Codex panel')
        return false
    end
    return true
end

function selectTab(tab)
    if tab ~= 'tasks' and tab ~= 'codex' then return end
    if not ensureWindow() then return end
    if selectedTab == 'tasks' and tab ~= 'tasks' then
        modules.game_hunting_tasks.onTabHidden()
    end
    selectedTab = tab
    for name, panel in pairs(panels) do
        panel:setVisible(name == tab)
        progressWindow:getChildById('navigationBar'):getChildById(name .. 'Tab'):setOn(name == tab)
    end
    if tab == 'tasks' then
        modules.game_hunting_tasks.refreshFromServer()
    else
        modules.game_codex.refreshFromServer()
    end
end

function show(tab)
    if not g_game.isOnline() or not ensureWindow() then return end
    selectTab(tab or selectedTab)
    progressWindow:show()
    progressWindow:raise()
    progressWindow:focus()
    progressButton:setOn(true)
end

function hide()
    modules.game_hunting_tasks.onTabHidden()
    if progressWindow then progressWindow:hide() end
    if progressButton then progressButton:setOn(false) end
end

function toggle(tab)
    if progressWindow and progressWindow:isVisible() and (not tab or tab == selectedTab) then
        hide()
    else
        show(tab)
    end
end

function init()
    progressButton = modules.game_mainpanel.addCompactStoreButton('progressButton',
        'Codex - Tasks e Codex', '/images/options/yellow_large', toggle, 2,
        nil)
    progressButton:show()
    progressButton:setOn(false)
    local highlight = progressButton:getChildById('highlight')
    if highlight then highlight:show() end
    connect(g_game, { onGameEnd = hide })
    modules.game_mainpanel.reloadMainPanelSizes()
end

function terminate()
    disconnect(g_game, { onGameEnd = hide })
    hide()
    -- Panels belong to their original modules and must outlive the hub on reload.
    for _, panel in pairs(panels) do
        panel:hide()
        panel:breakAnchors()
        panel:setParent(rootWidget)
    end
    panels = {}
    if progressWindow then progressWindow:destroy(); progressWindow = nil end
    if progressButton then progressButton:destroy(); progressButton = nil end
    modules.game_mainpanel.reloadMainPanelSizes()
end
