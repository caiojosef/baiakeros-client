-- Run from the repository root: luajit tests/lua/client_event_screenshots_test.lua
-- Exercise the actual screenshot controller without creating image files.
local version, enabled, captures = 1525, true, {}
local widget = {
    isChecked = function() return enabled end,
    setChecked = function() end,
    disable = function() end,
    isDestroyed = function() return false end,
    destroy = function() end
}
local panel = {
    Opciones3 = {enableScreenshots = widget},
    allCheckBox = {},
    recursiveGetChildById = function() return widget end
}
g_game = {
    getClientVersion = function() return version end,
    getLocalPlayer = function()
        return {getName = function() return 'Test' end, getLevel = function() return 100 end}
    end
}
g_resources = {getWriteDir = function() return '/tmp' end, directoryExists = function() return true end}
g_settings = {getBoolean = function() return true end}
g_ui = {
    loadUI = function() return panel end,
    createWidget = function() return {text = {setText = function() end}, enabled = {setChecked = function() end}} end
}
modules = {client_options = {getPanel = function() end, addButton = function() end}}
LocalPlayer = {}
local localPlayerEvents
notificationsController = {registerEvents = function(self, object, events)
    assert(object == LocalPlayer)
    localPlayerEvents = events
end}
dofile('modules/game_notifications/controllers/screenshot.lua')
takeScreenshot = function(name) captures[#captures + 1] = name end
screenshot_onGameStart()

local function expect(label, callback)
    local before = #captures
    callback()
    assert(#captures == before + 1, 'missing/duplicate screenshot: ' .. label)
    assert(captures[#captures]:find('_' .. label .. '_', 1, true), 'wrong screenshot: ' .. label)
end
local legacy = {'Achievement', 'BestiaryEntryCompleted', 'BestiaryEntryUnlocked', 'BossDefeated',
    'DeathPvE', 'DeathPvP', 'LevelUp', 'PlayerKillAssist', 'PlayerKill', 'PlayerAttacking',
    'TreasureFound', 'SkillUp', 'HighestDamageDealt', 'HighestHealingDone', 'LowHealth', 'GiftofLifeTriggered'}
version = 1511
for id, label in ipairs(legacy) do
    expect(label, function() localPlayerEvents.onTakeScreenshot(g_game.getLocalPlayer(), id) end)
end
version = 1525
for id, label in ipairs({'BossDefeated', 'DeathPvE', 'DeathPvP', 'PlayerKillAssist', 'PlayerKill',
    'PlayerAttacking', 'TreasureFound', 'GiftofLifeTriggered'}) do
    expect(label, function() localPlayerEvents.onTakeScreenshot(g_game.getLocalPlayer(), id) end)
end
expect('Achievement', function() screenshot_onClientEvent(2, 'Castlemania') end)
expect('LevelUp', function() screenshot_onClientEvent(4, 100) end)
expect('SkillUp', function() screenshot_onClientEvent(5, 3, 20) end)
expect('BestiaryEntryUnlocked', function() screenshot_onClientEvent(6, 1, 1) end)
expect('BestiaryEntryCompleted', function() screenshot_onClientEvent(6, 1, 3) end)
local before = #captures
screenshot_onClientEvent(6, 1, 2) -- Intermediate progress is not a completion.
screenshot_onClientEvent(3, 'Title')
onScreenShot(9) -- Popup-only simple event.
enabled = false
onScreenShot(2)
screenshot_onClientEvent(4, 101)
assert(#captures == before, 'unrequested screenshot')
version = 1511
enabled = true
screenshot_onClientEvent(4, 102)
assert(#captures == before, 'modern bridge must not run for legacy protocols')
print('PASS: 29 legacy/modern screenshots, filtering, disabled settings and legacy isolation')
