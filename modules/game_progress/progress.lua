-- Codex and Tasks live in Cyclopedia; their former shortcut is now Bosses.
local progressButton
local selectedTab = 'tasks'

local function cyclopedia()
    return modules.game_cyclopedia and modules.game_cyclopedia.Cyclopedia
end

function selectTab(tab)
    if tab ~= 'tasks' and tab ~= 'codex' then return end
    local book = cyclopedia()
    if not book or not g_game.isOnline() then return end
    if book.openTab(tab) then
        selectedTab = tab
        if progressButton then progressButton:setOn(true) end
    end
end

function show(tab)
    selectTab(tab or selectedTab)
end

function hide()
    local book = cyclopedia()
    if book and (book.getCurrentTab() == 'tasks' or book.getCurrentTab() == 'codex') then
        modules.game_cyclopedia.hide()
    end
    if progressButton then progressButton:setOn(false) end
end

function toggle(tab)
    local book = cyclopedia()
    local current = book and book.getCurrentTab()
    if book and modules.game_cyclopedia.isVisible() and
            (current == 'tasks' or current == 'codex') and (not tab or tab == current) then
        hide()
    else
        show(tab)
    end
end

function init()
    connect(g_game, { onGameEnd = hide })
    modules.game_mainpanel.reloadMainPanelSizes()
end

function setCyclopediaTab(tab)
    if tab == 'tasks' or tab == 'codex' then selectedTab = tab end
    if progressButton then progressButton:setOn(tab == 'tasks' or tab == 'codex') end
end

function terminate()
    disconnect(g_game, { onGameEnd = hide })
    hide()
    if progressButton then progressButton:destroy(); progressButton = nil end
    modules.game_mainpanel.reloadMainPanelSizes()
end
