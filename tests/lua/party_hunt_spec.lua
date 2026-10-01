-- Run with: luajit tests/lua/party_hunt_spec.lua
North, East, South, West = 0, 1, 2, 3
NorthEast, SouthEast, SouthWest, NorthWest = 4, 5, 6, 7
DontChase, ChaseOpponent = 0, 1
PlayerStates = { Pz = 1 }
dofile('modules/corelib/json.lua')

local clock, scheduled, opcodeCallback = 1000
local widgets, saved, monsters = {}, {}, {}
local position = { x = 100, y = 100, z = 7 }
local target, hiddenStand, obstructedStand, echo, echoWalked, floorTile
local walkingAllowed, health, chaseMode, walks = true, 100, DontChase, 0
local attackSettings = {}
local function widget(id)
    if widgets[id] then return widgets[id] end
    local w = { options = {} }
    for _, field in ipairs({ 'Text', 'Enabled', 'Checked', 'Percent',
        'BackgroundColor', 'Color', 'Tooltip', 'On', 'Visible' }) do
        local name = field:sub(1, 1):lower() .. field:sub(2)
        w['set' .. field] = function(self, value) self[name] = value end
    end
    function w:setCurrentOptionByData(value) self.data = value end
    function w:addOption(text, data) self.options[#self.options + 1] = { text, data } end
    function w:destroyChildren() self.children = {} end
    function w:getHeight() return 200 end
    function w:isVisible() return self.visible == true end
    function w:recursiveGetChildById(child) return widget(child) end
    widgets[id] = w
    return w
end
local rowNumber = 0
g_ui = { createWidget = function(_, parent)
    rowNumber = rowNumber + 1
    local row = widget('row' .. rowNumber)
    parent.children[#parent.children + 1] = row
    return row
end }
g_clock = { millis = function() return clock end }
g_settings = {
    getNode = function(key) return saved[key] end,
    setNode = function(key, value) saved[key] = value end,
    save = function() end
}
ProtocolGame = {
    registerExtendedOpcode = function(_, callback) opcodeCallback = callback end,
    unregisterExtendedOpcode = function() end
}
local protocol = { sendExtendedOpcode = function(_, opcode, message)
    local request = json.decode(message)
    if request.action == 'status' then
        opcodeCallback(nil, opcode, json.encode({ action = 'status', remaining = 3600 }))
    end
end }
local player = {
    getPosition = function() return position end,
    getHealthPercent = function() return health end,
    getDirection = function() return North end,
    getVocation = function() return 12 end,
    isDead = function() return false end,
    hasState = function() return false end,
    isAutoWalking = function() return false end,
    canWalk = function() return walkingAllowed end
}
modules = {
    game_interface = { lastManualWalk = 0, getMapPanel = function()
        return { getSpectators = function() return monsters end }
    end },
    game_baiakeros_helper = {
        playerConfigPrefix = function() return 'lure_test' end,
        getAttackState = function() return attackSettings end,
        setAutoAttackEnabled = function(value) attackSettings.autoTarget = value end,
        setAttackRotationEnabled = function(value) attackSettings.shooter = value end,
        getSelectedExplorerLureSpell = function() return nil end
    },
    game_baiakeros_helper_v2 = { detachCavebot = function() end }
}
local offsets = {
    [North] = { 0, -1 }, [East] = { 1, 0 }, [South] = { 0, 1 }, [West] = { -1, 0 },
    [NorthEast] = { 1, -1 }, [SouthEast] = { 1, 1 },
    [SouthWest] = { -1, 1 }, [NorthWest] = { -1, -1 }
}
g_game = {
    isOnline = function() return true end,
    getLocalPlayer = function() return player end,
    getProtocolGame = function() return protocol end,
    isFollowing = function() return false end,
    getAttackingCreature = function() return target end,
    getChaseMode = function() return chaseMode end,
    setChaseMode = function(mode) chaseMode = mode end,
    walk = function(direction)
        local offset = offsets[direction]
        walks = walks + 1
        position = { x = position.x + offset[1], y = position.y + offset[2], z = 7 }
        if echo and position.x == 102 and position.y == 100 then
            echo, echoWalked = false, true
        end
    end
}
g_map = { getTile = function(p)
    if p.z ~= 7 or p.x < 90 or p.x > 120 or p.y < 90 or p.y > 110 then return nil end
    if hiddenStand and p.x == 101 and p.y == 100 then return nil end
    local occupied = obstructedStand and p.x == 101 and p.y == 100
    return {
        getGround = function() return true end,
        isWalkable = function(_, ignore) return ignore or not occupied end,
        hasCreatures = function() return occupied end,
        hasFloorChange = function()
            return floorTile and floorTile.x == p.x and floorTile.y == p.y
        end,
        hasElevation = function() return false end,
        getItems = function()
            if echo and p.x == 102 and p.y == 100 then
                return { { getId = function() return 54133 end } }
            end
            return {}
        end
    }
end }
scheduleEvent = function(callback) scheduled = callback return callback end
removeEvent = function() scheduled = nil end
local function advance(ms)
    clock = clock + (ms or 50)
    scheduled()
end
local function monster(x, y)
    return {
        isMonster = function() return true end,
        isDead = function() return false end,
        getMasterId = function() return 0 end,
        getHealthPercent = function() return 100 end,
        getPosition = function() return { x = x, y = y, z = 7 } end
    }
end
local function range()
    local p = target:getPosition()
    return math.max(math.abs(position.x - p.x), math.abs(position.y - p.y))
end
local function click(id) widget(id).onClick() end
local function selectStand() widget('v2CavebotWaypointList').children[2].onClick() end
local function stop() click('v2CavebotAutoExploringButton') end
local function startAtStand(x, y)
    selectStand()
    position = { x = x or 101, y = y or 100, z = 7 }
    click('v2CavebotAutoExploringButton')
end


-- Additional fixture capabilities for the native Party Hunt client contract.
local selfId, serverActive, guideActive, guidePhase = 1, false, true, 'travel'
local leaderPosition = { x = 101, y = 100, z = 7 }
local responsesEnabled, transition = true, nil
local opcodeHandlers, requests, events = {}, {}, {}
local baseWidget = widget
widget = function(id)
    local w = baseWidget(id)
    function w:getText() return self.text or '' end
    function w:show() self.visible = true end
    function w:hide() self.visible = false end
    function w:raise() end
    function w:focus() self.focused = true end
    function w:setHeight(value) self.height = value end
    function w:destroy() self.destroyed = true end
    function w:clearOptions() self.options = {} end
    return w
end
g_ui.importStyle = function() end
g_ui.createWidget = function(style, parent)
    if style == 'BaiakerosPartyHuntPanel' then return widget('partyPanel') end
    if style == 'BaiakerosPartyHuntFloat' then return widget('partyFloat') end
    rowNumber = rowNumber + 1
    local row = widget('row' .. rowNumber)
    local remove = widget('remove' .. rowNumber)
    function row:recursiveGetChildById(id)
        if id == 'removeWaypoint' then return remove end
        return widget(id)
    end
    parent.children = parent.children or {}
    parent.children[#parent.children + 1] = row
    return row
end
rootWidget, helperV2Window = widget('root'), widget('helper')
modules.game_walk = { bindMovementKeysToWidget = function() end, unbindMovementKeysFromWidget = function() end }
modules.game_baiakeros_helper_v2.showHelperV2Tab = function(tab) widget('helper').tab = tab end
modules.game_baiakeros_helper_v2.show = function() widget('helper'):show() end
player.getId = function() return selfId end
player.getVocation = function() return selfId == 1 and 11 or 14 end
modules.game_baiakeros_helper.playerConfigPrefix = function() return 'party_test_' .. selfId end
modules.game_baiakeros_helper.setHelperButtonOn = function() end
ProtocolGame.registerExtendedOpcode = function(opcode, callback) opcodeHandlers[opcode] = callback end
ProtocolGame.unregisterExtendedOpcode = function(opcode) opcodeHandlers[opcode] = nil end
g_game.getProtocolGame = function()
    return { sendExtendedOpcode = function(_, opcode, encoded)
        local data = json.decode(encoded)
        requests[#requests + 1] = { opcode = opcode, action = data.action }
        if not responsesEnabled then return end
        if opcode == 92 then
            if data.action == 'status' then
                opcodeHandlers[92](nil, 92, json.encode({ action = 'status', remaining = 3600, active = false }))
            end
            return
        end
        if data.action == 'start' then serverActive = true end
        if data.action == 'stop' then serverActive = false end
        if data.action == 'heartbeat' and selfId == 1 then guidePhase = data.phase end
        opcodeHandlers[93](nil, 93, json.encode({ action = 'status', remaining = 3555, active = serverActive,
            canChooseGuide = selfId == 1, tooMany = false, reason = '', members = {
                { id = 1, guid = 41, name = 'Knight', role = 'knight' },
                { id = 2, guid = 42, name = 'Druid', role = 'druid' }
            }, guide = { id = 1, guid = 41, name = 'Knight', position = leaderPosition,
                active = guideActive, phase = guidePhase, transition = transition } }))
    end }
end
scheduleEvent = function(callback, delay)
    local event = { callback = callback, at = clock + delay }
    events[#events + 1] = event
    return event
end
removeEvent = function(event) event.canceled = true end
advance = function(ms)
    local untilTime = clock + ms
    while true do
        local found, index
        for i, event in ipairs(events) do
            if not event.canceled and event.at <= untilTime and (not found or event.at < found.at) then found, index = event, i end
        end
        if not found then break end
        table.remove(events, index)
        clock = found.at
        found.callback()
    end
    clock = untilTime
end
local floorEntry
local baseTile = g_map.getTile
g_map.getTile = function(p)
    local tile = baseTile({ x = p.x, y = p.y, z = 7 })
    if tile then
        tile.hasFloorChange = function() return floorEntry and p.z == floorEntry.z and p.x == floorEntry.x and p.y == floorEntry.y end
    end
    return tile
end
g_game.walk = function(direction)
    local offset = offsets[direction]
    position = { x = position.x + offset[1], y = position.y + offset[2], z = position.z }
    walks = walks + 1
    if floorEntry and position.z == floorEntry.z and position.x == floorEntry.x and position.y == floorEntry.y then position.z = 6 end
    return true
end
local earth = { words = 'exevo tera hur', profile = { shape = 'directional' }, minEnemies = 1, ready = true, offsets = {
    {0,-1}, {0,-2}, {-1,-3}, {0,-3}, {1,-3}, {-1,-4}, {0,-4}, {1,-4}, {-1,-5}, {0,-5}, {1,-5}
} }
local ice = { words = 'exevo gran frigo hur', profile = { shape = 'directional' }, minEnemies = 1, ready = true, offsets = {
    {0,-1}, {-1,-2}, {0,-2}, {1,-2}, {-1,-3}, {0,-3}, {1,-3}, {-1,-4}, {0,-4}, {1,-4}
} }
local plan = earth
modules.game_baiakeros_helper.getPartyHuntSpellPlan = function() return plan end
local function click(id) widget('party' .. id).onClick() end
dofile('modules/game_baiakeros_helper_v2/lure_movement.lua')
dofile('modules/game_baiakeros_helper_v2/explorer.lua')
dofile('modules/game_baiakeros_helper_v2/party_hunt_movement.lua')
dofile('modules/game_baiakeros_helper_v2/party_hunt.lua')
BaiakHelperExplorerV2.init(widget('window'))
PartyHuntV2.init(widget('window'))
BaiakHelperExplorerV2.onGameStart()
PartyHuntV2.onGameStart()

-- Existing Cavebot scripts are copied, never taken over or persisted as a
-- different character's normal route while the party guide is running.
widget('v2CavebotNodeButton').onClick()
position = { x = 101, y = 100, z = 7 }
widget('v2CavebotStandButton').onClick()
local original = json.encode(BaiakHelperExplorerV2.copyRoute())
click('FromCavebot')
assert(#widget('partyWaypointList').children == 2)
widget('partyJsonEditor'):setText('{"version":1,"waypoints":[{"kind":"node","x":100,"y":100,"z":7},{"kind":"stand","x":101,"y":100,"z":7}]}')
click('ApplyJson')
assert(#saved.party_test_1_party_hunt_v1.waypoints == 2)
widget('partyJsonEditor'):setText('os.execute("do not execute Lua")')
click('ApplyJson')
assert(#saved.party_test_1_party_hunt_v1.waypoints == 2, 'the paste editor must reject executable Lua')
position = { x = 100, y = 100, z = 7 }
click('Start')
assert(PartyHuntV2.isActive() and not isAutoExplorerActive() and
    BaiakHelperExplorerV2.getRouteState().owner == 'party')
assert(widget('partyFloat').visible and not helperV2Window.visible)
monsters = { monster(102, 100) }
advance(1500)
assert(position.x == 101 and BaiakHelperExplorerV2.getRouteState().phase == 'fight',
    'the party EK must follow Nodes, then stop and clear the box at Stand')
for _, request in ipairs(requests) do
    assert(not (request.opcode == 92 and (request.action == 'start' or request.action == 'heartbeat')),
        'Party Hunt must not open or charge a Cavebot timer session')
end
PartyHuntV2.minimize()
assert(widget('partyFloat').height == 168 and not widget('partyFloatDetails').visible)
PartyHuntV2.openHelper()
assert(widget('helper').visible and widget('helper').tab == 'party' and widget('partyFloat').visible,
    'opening Helper must preserve the active floating Party Hunt')
PartyHuntV2.closeFloating()
assert(widget('partyFloat').visible, 'closing the active floating panel must minimize it')
monsters = {}
advance(100)
assert(BaiakHelperExplorerV2.getRouteState().waypoint == 1,
    'after clearing the box the party knight must continue to the next Node')
PartyHuntV2.stop()
assert(json.encode(BaiakHelperExplorerV2.copyRoute()) == original,
    'stopping Party Hunt must restore the untouched normal Cavebot route')
assert(widget('v2CavebotTimerLabel').text == '01:00:00', 'Party Hunt must preserve the Cavebot daily timer')

-- Recording inserts after the selected row and resets its direction.
widget('partyWaypointList').children[1].onClick()
position = { x = 103, y = 101, z = 7 }
widget('partyDirection').onOptionChange(nil, nil, 'north')
click('Stair')
local recorded = saved.party_test_1_party_hunt_v1.waypoints
assert(recorded[2].kind == 'stair' and recorded[2].direction == 'north' and recorded[3].kind == 'stand')
assert(widget('partyDirection').data == 'center')

-- Switch to a separate druid client/profile; no local route is necessary.
PartyHuntV2.onGameEnd()
BaiakHelperExplorerV2.onGameEnd()
selfId, serverActive, guidePhase = 2, false, 'fight'
leaderPosition = { x = 100, y = 100, z = 7 }
position = { x = 100, y = 102, z = 7 }
BaiakHelperExplorerV2.onGameStart()
PartyHuntV2.onGameStart()
assert(#widget('partyWaypointList').children == 0 and widget('partyStart').enabled)
monsters = {}
for x = -1, 1 do for y = -1, 1 do
    if x ~= 0 or y ~= 0 then monsters[#monsters + 1] = monster(100 + x, 100 + y) end
end end
click('Start')
advance(1000)
assert(position.x == 100 and position.y == 104,
    'the druid must reach the widest Earth Wave section facing the eight-monster box')
local allowed, facing = PartyHuntV2.prepareSpell({ words = earth.words })
assert(allowed and facing == North, 'Shooter must receive the box-facing cast direction')
assert(not PartyHuntV2.prepareSpell({ words = ice.words }), 'Party Hunt must respect the configured next Shooter spell')
plan = ice
advance(400)
assert(position.x == 100 and position.y == 103 and PartyHuntV2.prepareSpell({ words = ice.words }),
    'the druid must advance a SQM when the next wave has a shorter wide section')
monsters[#monsters + 1] = monster(101, 103)
local before = walks
advance(300)
assert(walks > before and PartyHuntV2.isActive(), 'an attacker on the ED must trigger escape movement')
monsters[#monsters] = nil
position = { x = 100, y = 104, z = 7 }
health = 90
before = walks
advance(200)
assert(walks > before, 'damage from a distant attacker must trigger escape without disabling Shooter or healing')
health = 100

-- A confirmed guide staircase is the only floor-changing step authorized for ED.
monsters = {}
position = { x = 102, y = 100, z = 7 }
leaderPosition = { x = 104, y = 100, z = 6 }
floorEntry = { x = 103, y = 100, z = 7 }
transition = { entry = floorEntry, exit = leaderPosition, kind = 'stair' }
PartyHuntV2.refresh()
advance(200)
assert(position.z == 6, 'the druid must cross the guide-confirmed Stair instead of remaining on the old floor')
transition, floorEntry = nil, nil

-- A lost connection pauses positioning, then stops, retaining healing settings.
responsesEnabled = false
advance(4200)
before = walks
advance(1000)
assert(walks == before, 'stale party status must pause movement')
advance(4000)
assert(not PartyHuntV2.isActive(), 'an expired server connection must stop Party Hunt')
assert(attackSettings.autoTarget and attackSettings.shooter, 'stopping Party Hunt must not disable independent combat settings')
assert(saved.party_test_2_party_hunt_v1 == nil or saved.party_test_2_party_hunt_v1.remaining == nil,
    'the client must not persist or own daily Party Hunt time')
click('Start')
assert(widget('partyStart').text == 'Starting...')
advance(8100)
assert(not PartyHuntV2.isActive() and widget('partyStart').text == 'Start' and widget('partyStart').enabled,
    'a missing Start acknowledgement must release the button instead of hanging indefinitely')
PartyHuntV2.terminate()
BaiakHelperExplorerV2.terminate()
print('Party Hunt client passed: route reuse/isolation, EK Stand, ED waves/escape, paste safety, float/minimize, stairs, connection timeout')
