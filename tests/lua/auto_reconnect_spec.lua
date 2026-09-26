local values = {
    ['last-used-character'] = 'Teste Rp',
    ['baiakeros_helper_teste_rp_auto_reconnect'] = true
}
local now = 100000
local scheduled
local loginAttempts = 0
local callbacks = {}

g_settings = {
    getString = function(key, default)
        return values[key] or default
    end,
    getBoolean = function(key, default)
        if values[key] == nil then return default == true end
        return values[key] == true
    end
}
g_clock = { millis = function() return now end }
g_game = {}
g_ui = { importStyle = function() end }
G = {}
connect = function(_, handlers)
    for name, callback in pairs(handlers) do callbacks[name] = callback end
end
scheduleEvent = function(callback, delay)
    scheduled = { callback = callback, delay = delay }
    return scheduled
end
removeEvent = function(event) event.cancelled = true end
destroyCreateAccount = function() end

dofile('modules/client_entergame/characterlist.lua')
CharacterList.init()
CharacterList.showAgain = function() scheduleAutoReconnect() end
CharacterList.doLogin = function() loginAttempts = loginAttempts + 1 end

local function disconnect()
    scheduled = nil
    callbacks.onGameStart()
    now = now + 1000
    callbacks.onGameEnd()
end

disconnect()
assert(scheduled and scheduled.delay == 2500, 'Helper-enabled disconnect must schedule Enter')
scheduled.callback()
assert(loginAttempts == 1, 'Helper-enabled disconnect must retry the selected character')

scheduled = nil
callbacks.onGameStart()
callbacks.onBeforeLogout()
now = now + 1000
callbacks.onGameEnd()
assert(not scheduled, 'manual logout must not reconnect')

values['baiakeros_helper_teste_rp_auto_reconnect'] = false
disconnect()
assert(not scheduled, 'disabled Helper option must not reconnect')

values['baiakeros_helper_teste_rp_current_preset'] = 'hunt'
values['baiakeros_helper_teste_rp_preset_hunt_auto_reconnect'] = true
disconnect()
assert(scheduled, 'enabled named Helper preset must reconnect')

values['baiakeros_helper_teste_rp_preset_hunt_auto_reconnect'] = nil
values.autoReconnect = true
disconnect()
assert(not scheduled, 'new named preset must default to off')

values['baiakeros_helper_teste_rp_current_preset'] = 'default'
values['baiakeros_helper_teste_rp_auto_reconnect'] = nil
disconnect()
assert(scheduled, 'legacy character-list setting must remain supported')

print('Helper reconnect settings, disconnect retry, and manual logout verified')