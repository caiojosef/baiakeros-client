local calls, handlers, events, count = {}, {}, {}, 0
local function check(value, message) count = count + 1; assert(value, message) end
g_game = {isOnline = function() return true end}
g_settings = {getString = function() return '' end}
KEY_DOWN = 1
Keybind = {new = function() end, bind = function(_, action, binding) handlers[action] = binding[1].callback end}
removeEvent = function(event) event.cancelled = true end
scheduleEvent = function(callback, delay) local e={callback=callback,delay=delay}; events[#events+1]=e;return e end
g_effects = {fadeIn=function() end,fadeOut=function(widget) widget.faded=true end}
dofile('modules/game_baiakeros_helper/helper.lua')
helperNotification = {
    setText = function(_, value) calls.text=value;calls.colored=nil end,
    setColoredText = function(_, value) calls.colored=value end,
    setColor = function(_, value) calls.color=value end,
    setBorderColor = function() error('notification must never set a frame color') end,
    setOpacity = function() end,show=function() end,raise=function() end,
}
setHealingEnabled = function(value) healingEnabled=value end
setAutoAttackEnabled = function(value) autoAttackEnabled=value end
setAttackRotationEnabled = function(value) attackRotationEnabled=value end
local function upvalue(fn, name)
    for i=1,100 do local key,value=debug.getupvalue(fn,i);if not key then break end;if key==name then return value end end
    error('missing '..name)
end
upvalue(init,'registerHelperHotkeys')()
local function expected(label, enabled)
    local state = enabled and 'Enable' or 'Disable'
    local color = enabled and '#79ef8b' or '#ff7777'
    check(calls.colored==label..' {'..state..', '..color..'}','exact short notification and status-only color')
    check(calls.color=='#ffffff','action name remains white')
    check(not calls.colored:find('Preset:',1,true) and not calls.colored:find('Spells:',1,true),'toggle excludes preset metadata')
end
for _,spec in ipairs({
    {'Toggle Healing','Healing','healingEnabled'},
    {'Toggle Auto Target','Target','autoAttackEnabled'},
    {'Toggle Shooter','Spell Shooter','attackRotationEnabled'},
}) do
    _G[spec[3]]=false
    handlers[spec[1]]();expected(spec[2],true)
    local pending=events[#events]
    handlers[spec[1]]();expected(spec[2],false)
    check(pending.cancelled,'new notification replaces pending fade-out')
end
for _,state in ipairs({{false,false},{true,false},{false,true},{true,true}}) do
    autoAttackEnabled,attackRotationEnabled=state[1],state[2]
    handlers['Toggle Auto Target + Shooter']()
    local enabled=not(state[1]and state[2])
    check(autoAttackEnabled==enabled and attackRotationEnabled==enabled,'combined toggle retains its behavior')
    expected('Target + Spell Shooter',enabled)
end
showHelperNotification('Helper Preset: Custom',true)
check(calls.text=='Helper Preset: Custom' and not calls.colored and calls.color=='#ffffff','preset hotkey notices remain plain white')
showHelperNotification('Wait for the combat style cooldown to finish.',false)
check(calls.text=='Wait for the combat style cooldown to finish.' and calls.color=='#ffffff','informational notices remain plain white')
local before=#events
g_game.isOnline=function()return false end
for _,action in ipairs({'Toggle Healing','Toggle Auto Target','Toggle Shooter','Toggle Auto Target + Shooter'})do handlers[action]()end
check(#events==before,'offline hotkeys do not emit a message')
events[#events].callback()
check(helperNotification.faded,'notification expires normally')
print('PASS: '..count..' helper notification checks')
