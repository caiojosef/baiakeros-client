local OPCODE = 225
local window, button, refreshEvent, tickEvent, cooldownSyncEvent
local state = { bosses = {} }
local receivedAt = 0
local pendingUntil = 0
local statusMessageUntil = 0
local cards = {}

local function child(id) return window and window:recursiveGetChildById(id) end
local function send(action, bossId)
    if not g_game.isOnline() then return false end
    local protocol = g_game.getProtocolGame()
    if not protocol then return false end
    protocol:sendExtendedOpcode(OPCODE, json.encode({ action = action, bossId = bossId }))
    return true
end

local function ensureWindow()
    if window then return end
    g_ui.importStyle('bosses')
    window = g_ui.createWidget('BossTravelWindow', rootWidget)
end

local function clock(seconds)
    seconds = math.max(0, math.ceil(seconds))
    return string.format('%02d:%02d:%02d', math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

local function remaining(boss)
    return math.max(0, (boss.cooldown or 0) - math.floor((g_clock.millis() - (boss.cooldownAt or receivedAt)) / 1000))
end

local function travelRemaining()
    return math.max(0, (state.travelCooldown or 0) -
        math.floor((g_clock.millis() - (state.travelCooldownAt or receivedAt)) / 1000))
end

local function reason(boss)
    local interval = travelRemaining()
    if interval > 0 then return 'Aguarde ' .. interval .. (interval == 1 and ' segundo' or ' segundos') .. ' para usar outro teleporte de boss.' end
    local seconds = remaining(boss)
    if seconds > 0 then return boss.name .. ' em cooldown: ' .. clock(seconds) .. ' restantes.' end
    if not state.canTravel then return state.reason or 'Use apenas em protection zone.' end
    if not state.vip and (state.used or 0) >= (state.limit or 5) then return 'Limite de 5 teleportes diarios atingido.' end
    if not boss.available then return boss.reason or 'Entrada indisponivel.' end
    if pendingUntil > g_clock.millis() then return 'Aguardando resposta do servidor...' end
    return nil
end

local function updateCards()
    if not window then return end
    local interval = travelRemaining()
    local protection = state.canTravel and 'Protection zone: teleporte permitido.' or
        (state.reason or 'Entre em protection zone para teleportar.')
    if interval > 0 then protection = protection .. ' | Proximo teleporte: ' .. clock(interval) end
    child('protection'):setText(protection)
    child('protection'):setColor(state.canTravel and interval == 0 and '#9fd18a' or '#e0aa78')
    for _, data in ipairs(cards) do
        local boss, card = data.boss, data.widget
        card.waiting:setText('Aguardando: ' .. tostring(boss.waiting or 0) .. ' jogador(es)')
        local seconds = remaining(boss)
        card.cooldown:setText(seconds > 0 and ('Cooldown: ' .. clock(seconds)) or
            (boss.available and 'Disponivel' or 'Indisponivel'))
        card.cooldown:setColor((seconds > 0 or not boss.available) and '#e0aa78' or '#9fd18a')
        local message = reason(boss)
        card.travel:setText(seconds > 0 and 'Em cooldown' or (interval > 0 and ('Aguarde ' .. interval .. 's') or 'Ir a alavanca'))
        card.travel:setEnabled(not message)
        card.travel:setTooltip(message or 'Teleportar ate a area de espera da alavanca.')
        card:setTooltip(message or 'Clique para ir ate a alavanca deste boss.')
    end
end

function filter()
    if not window then return end
    child('list'):destroyChildren()
    cards = {}
    local search = child('search'):getText():lower():trim()
    for _, boss in ipairs(state.bosses or {}) do
        if search == '' or boss.name:lower():find(search, 1, true) then
            local card = g_ui.createWidget('BossTravelCard', child('list'))
            card:setId('boss' .. boss.id)
            card.name:setText(boss.name)
            card.name:setTooltip(boss.name)
            if boss.outfit and (boss.outfit.type or 0) > 0 then card.portrait:setOutfit(boss.outfit) end
            card.waiting:setText('Aguardando: ' .. tostring(boss.waiting or 0) .. ' jogador(es)')
            local click = function() travel(boss.id) end
            card.onClick, card.travel.onClick = click, click
            cards[#cards + 1] = { boss = boss, widget = card }
        end
    end
    child('count'):setText(string.format('%d / %d bosses | Espera atualizada a cada 5s', #cards, #(state.bosses or {})))
    updateCards()
end

function requestSync() send('sync') end

-- The ordinary Bosstiary packet is emitted whenever a boss cooldown changes.
-- Ask our own authoritative catalogue too, including after a rejected travel.
-- A delayed retry covers the server's two-second sync request throttle.
function onBossCooldown()
    if not window or not window:isVisible() then return end
    if cooldownSyncEvent then return end
    requestSync()
    cooldownSyncEvent = scheduleEvent(function()
        cooldownSyncEvent = nil
        if window and window:isVisible() then requestSync() end
    end, 2100)
end

function travel(id)
    for _, boss in ipairs(state.bosses or {}) do
        if boss.id == id then
            local message = reason(boss)
            if message then
                child('status'):setText(message)
                modules.game_textmessage.displayFailureMessage(message)
                if pendingUntil <= g_clock.millis() and travelRemaining() == 0 then onBossCooldown() end
                return false
            end
            pendingUntil = g_clock.millis() + 5000
            if not send('teleport', id) then pendingUntil = 0; return false end
            updateCards()
            return true
        end
    end
    return false
end

local function onOpcode(protocol, opcode, buffer)
    local ok, data = pcall(json.decode, buffer)
    if not ok or type(data) ~= 'table' then return end
    if data.action == 'result' then
        pendingUntil = 0
        statusMessageUntil = g_clock.millis() + 7000
        if window then child('status'):setText(tostring(data.message or '')) end
        if tonumber(data.travelCooldown) then
            state.travelCooldown = math.max(0, tonumber(data.travelCooldown))
            state.travelCooldownAt = g_clock.millis()
        end
        if data.bossId and tonumber(data.cooldown) then
            for _, boss in ipairs(state.bosses or {}) do
                if boss.id == tonumber(data.bossId) then
                    boss.cooldown = math.max(0, tonumber(data.cooldown))
                    boss.cooldownAt = g_clock.millis()
                    if boss.cooldown > 0 then boss.available = false; boss.reason = data.message end
                    break
                end
            end
        end
        if data.success then
            hide()
            local interval = travelRemaining()
            if interval > 0 then
                modules.game_textmessage.displayStatusMessage('Teleporte realizado. Aguarde ' .. interval ..
                    (interval == 1 and ' segundo' or ' segundos') .. ' para usar novamente.')
            end
        else
            updateCards()
            if travelRemaining() == 0 then onBossCooldown() end
        end
    elseif data.action == 'sync' then
        local function signature(entries)
            local values = {}
            for _, entry in ipairs(entries or {}) do values[#values + 1] = entry.id .. ':' .. entry.name end
            return table.concat(values, '|')
        end
        local sameCatalogue = signature(state.bosses) == signature(data.bosses)
        state, receivedAt = data, g_clock.millis()
        if not window or not window:isVisible() then return end
        child('usage'):setText(state.vip and 'VIP - Teleportes ilimitados' or
            string.format('Usos de hoje: %d / %d por personagem', state.used or 0, state.limit or 5))
        if statusMessageUntil <= g_clock.millis() then
            child('status'):setText('Clique no boss disponivel para ir a alavanca. O combate e iniciado pela alavanca normal.')
        end
        if sameCatalogue then
            local byId = {}
            for _, boss in ipairs(state.bosses or {}) do byId[boss.id] = boss end
            for _, card in ipairs(cards) do card.boss = byId[card.boss.id] end
            updateCards()
        else
            filter()
        end
    end
end

local function refreshLoop()
    refreshEvent = nil
    if not window or not window:isVisible() then return end
    requestSync()
    refreshEvent = scheduleEvent(refreshLoop, 5000)
end
local function tickLoop()
    tickEvent = nil
    if not window or not window:isVisible() then return end
    updateCards()
    tickEvent = scheduleEvent(tickLoop, 1000)
end

function show()
    if not g_game.isOnline() then return end
    ensureWindow()
    state = { bosses = {} }
    pendingUntil = 0
    statusMessageUntil = 0
    child('usage'):setText('Carregando bosses...')
    child('status'):setText('Aguardando resposta do servidor...')
    child('search'):setText('')
    filter()
    window:show(); window:raise(); window:focus()
    if button then button:setOn(true) end
    if not refreshEvent then refreshLoop() end
    if not tickEvent then tickLoop() end
end

function hide()
    if cooldownSyncEvent then removeEvent(cooldownSyncEvent); cooldownSyncEvent = nil end
    if refreshEvent then removeEvent(refreshEvent); refreshEvent = nil end
    if tickEvent then removeEvent(tickEvent); tickEvent = nil end
    pendingUntil = 0
    if window then window:hide() end
    if button then button:setOn(false) end
end
function toggle() if window and window:isVisible() then hide() else show() end end
local function offline() hide(); state = { bosses = {} }; cards = {}; if window then child('list'):destroyChildren() end end

function init()
    ProtocolGame.registerExtendedOpcode(OPCODE, onOpcode)
    connect(g_game, { onGameEnd = offline, onBossCooldown = onBossCooldown })
    button = modules.game_mainpanel.addCompactStoreButton('bossesButton', 'Bosses - cooldowns e teleportes', '/images/options/yellow_large', toggle, 2, nil)
    button:setIcon('/images/topbuttons/bosses-native-v1')
    button:setIconClip('0 0 16 16')
    button:setOn(false)
end
function terminate()
    hide()
    disconnect(g_game, { onGameEnd = offline, onBossCooldown = onBossCooldown })
    ProtocolGame.unregisterExtendedOpcode(OPCODE)
    if window then window:destroy(); window = nil end
    if button then button:destroy(); button = nil end
    cards = {}
    modules.game_mainpanel.reloadMainPanelSizes()
end
