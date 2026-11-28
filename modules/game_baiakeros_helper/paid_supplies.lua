PaidSupplies = {}

local OPCODE = 226
local RETRY_DELAY = 8000
local vip
local enabled = false
local unavailableUntil = {}
local initialRefresh
local refreshEvent

local function settingKey()
    return playerConfigPrefix() .. '_paid_supplies'
end

local function refreshUI()
    local ui = modules.game_baiakeros_helper_v2
    if ui and ui.refreshPaidSupplies then ui.refreshPaidSupplies() end
end

local function send(message)
    local protocol = g_game.getProtocolGame()
    if not protocol or not g_game.isOnline() then return false end
    protocol:sendExtendedOpcode(OPCODE, message)
    return true
end

local function receive(_, _, message)
    if not g_game.isOnline() then return end
    if message == 'vip' or message == 'free' then
        vip = message == 'vip'
        enabled = vip and g_settings.getBoolean(settingKey(), false)
        refreshUI()
        return
    end

    local item = tonumber(message:match('^poor:(%d+)$'))
    if not item or not enabled then return end
    unavailableUntil[item] = g_clock.millis() + RETRY_DELAY
    local text = 'Helper VIP: saldo insuficiente para este item.'
    if modules.game_textmessage then modules.game_textmessage.displayFailureMessage(text) end
end

function PaidSupplies.init()
    ProtocolGame.registerExtendedOpcode(OPCODE, receive)
end

function PaidSupplies.sync()
    send('sync')
end

function PaidSupplies.online()
    if refreshEvent then return end
    -- The game-start callback runs while the server is still accepting login.
    initialRefresh = scheduleEvent(function()
        initialRefresh = nil
        PaidSupplies.sync()
    end, 1200)
    refreshEvent = cycleEvent(PaidSupplies.sync, 15000)
end

function PaidSupplies.offline()
    if initialRefresh then removeEvent(initialRefresh); initialRefresh = nil end
    if refreshEvent then removeEvent(refreshEvent); refreshEvent = nil end
    vip, enabled, unavailableUntil = nil, false, {}
    refreshUI()
end

function PaidSupplies.terminate()
    PaidSupplies.offline()
    ProtocolGame.unregisterExtendedOpcode(OPCODE)
end

function PaidSupplies.state()
    return vip, enabled
end

function PaidSupplies.setEnabled(checked)
    if not vip then return end
    enabled = checked == true
    g_settings.set(settingKey(), enabled)
    g_settings.save()
    unavailableUntil = {}
    refreshUI()
end

function PaidSupplies.use(itemId, target)
    if not enabled then
        g_game.useInventoryItemWith(itemId, target, -1)
        return true
    end
    if g_clock.millis() < (unavailableUntil[itemId] or 0) then return false end
    return send(string.format('use:%d:%d', itemId, target:getId()))
end
