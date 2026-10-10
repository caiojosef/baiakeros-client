-- Run with: luajit tests/lua/cavebot_lure_spec.lua
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
local playerEvents = {}
LocalPlayer = {}
connect = function(class, callbacks)
    assert(class == LocalPlayer)
    for name, callback in pairs(callbacks) do playerEvents[name] = callback end
end
disconnect = function(class, callbacks)
    assert(class == LocalPlayer)
    for name, callback in pairs(callbacks) do
        assert(playerEvents[name] == callback)
        playerEvents[name] = nil
    end
end
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
        setAutoAttackEnabled = function(value) attackSettings.autoTarget = value;modules.game_baiakeros_helper.autoAttackEnabled=value end,
        setAttackRotationEnabled = function(value) attackSettings.shooter = value;modules.game_baiakeros_helper.attackRotationEnabled=value end,
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

dofile('modules/game_baiakeros_helper_v2/lure_movement.lua')
dofile('modules/game_baiakeros_helper_v2/explorer.lua')
BaiakHelperExplorerV2.init(widget('window'))
saved.lure_test_auto_explorer_v2 = { huntStyle = 'lure', lureDistance = 2, lureCount = 20 }
BaiakHelperExplorerV2.onGameStart()
assert(widget('v2CavebotHuntStyleBox').options[2][1] == 'Distance',
    'the old Lure script value must display as Distance')
click('v2CavebotNodeButton')
position = { x = 101, y = 100, z = 7 }
click('v2CavebotStandButton')
widget('v2CavebotHuntStyleBox').onOptionChange(nil, nil, 'lure')
assert(not widgets.v2CavebotLureCountBox and not widgets.v2CavebotLureCountLabel,
    'the removed monster count controls must never be accessed')

-- Once combat starts, losing the old Stand tile from the map must not make
-- Lure return to it or skip the current fight.
target = monster(104, 100)
monsters = { target }
startAtStand()
advance()
hiddenStand = true
local before = walks
for _ = 1, 7 do advance() end
assert(walks == before + 7 and range() == 2,
    'Lure must keep running at the selected distance when the Stand leaves the map')
assert(saved.lure_test_auto_explorer_v2.waypointIndex == 2)
stop()
hiddenStand = false

-- A spawn from an activated Echo is fought with the same moving strategy.
widget('v2CavebotEchoRaidsBox').onCheckChange(nil, true)
monsters, target, echo, echoWalked = {}, nil, true, false
startAtStand()
advance() -- Find Echo.
advance() -- Walk on Echo.
advance() -- Activate Echo.
assert(echoWalked)
target = monster(103, 100)
monsters = { target }
before = walks
for _ = 1, 4 do advance() end
assert(walks == before + 4 and range() == 2,
    'Lure must run from Echo Raid monsters rather than parking at Stand')
assert(saved.lure_test_auto_explorer_v2.waypointIndex == 2)
monsters, target = {}, nil
advance(400)
advance(400)
for _ = 1, 25 do
    if saved.lure_test_auto_explorer_v2.waypointIndex == 1 then break end
    advance()
end
assert(saved.lure_test_auto_explorer_v2.waypointIndex == 1,
    'Lure must resume the route after the Echo pack dies')
stop()
widget('v2CavebotEchoRaidsBox').onCheckChange(nil, false)

-- Native Chase must not pull the player into melee while Lure owns movement.
chaseMode = ChaseOpponent
target = monster(102, 100)
monsters = { target }
startAtStand()
modules.game_baiakeros_helper.setAutoAttackEnabled(false)
modules.game_baiakeros_helper.setAttackRotationEnabled(false)
advance()
assert(attackSettings.autoTarget and attackSettings.shooter,'running Cavebot restores disabled combat helpers')
assert(chaseMode == DontChase and g_game.getAttackingCreature() == target,
    'Lure must disable native chase without cancelling the attack target')
assert(attackSettings.autoTarget and attackSettings.shooter and
    not shouldHoldExplorerAttack() and preferAreaExplorerAttack())
stop()
assert(chaseMode == ChaseOpponent, 'Stop must restore the previous native chase mode')

-- Combat begins before the free Stand. Reach that SQM only after clearing the
-- entire pack, including a monster on the five-SQM diagonal boundary.
target = monster(98, 100)
monsters = { target }
startAtStand(95, 100)
advance()
assert(range() == 2 and saved.lure_test_auto_explorer_v2.waypointIndex == 2,
    'Lure must engage the target before approaching Stand')
target = monster(position.x + 5, position.y + 5)
monsters = { target }
before = walks
advance()
assert(walks > before and saved.lure_test_auto_explorer_v2.waypointIndex == 2,
    'a live monster five SQM away diagonally must keep the route in combat')
monsters, target = {}, nil
for _ = 1, 40 do
    advance()
    if saved.lure_test_auto_explorer_v2.waypointIndex == 1 then break end
end
assert(saved.lure_test_auto_explorer_v2.waypointIndex == 1 and position.x == 101 and position.y == 100,
    'after the last monster dies Lure must visit Stand before advancing the route')
stop()

-- Each configured range must be reached, then movement must continue there.
for sqm = 1, 4 do
    widget('v2CavebotLureDistanceBox').onOptionChange(nil, nil, sqm)
    target = monster(102, 100)
    monsters = { target }
    startAtStand()
    for _ = 1, 8 do advance() end
    assert(range() == sqm, 'Lure must reach configured distance ' .. sqm)
    before = walks
    for _ = 1, 4 do
        advance()
        assert(range() == sqm, 'Lure must keep configured distance ' .. sqm)
    end
    assert(walks == before + 4, 'Lure must keep moving at distance ' .. sqm)
    stop()
end

-- A moving target and an occupied Stand must not hold Lure at its old anchor.
widget('v2CavebotLureDistanceBox').onOptionChange(nil, nil, 2)
target = monster(101, 100)
monsters, obstructedStand, health = { target }, true, 20
startAtStand(100, 100)
before = walks
advance()
assert(walks > before and isAutoExplorerActive(), 'an occupied Stand must allow an escape step')
obstructedStand = false
target.getPosition = function() return { x = 108, y = 100, z = 7 } end
monsters = { monster(98, 100), target }
for _ = 1, 9 do advance() end
assert(position.x <= 104 and position.x >= 96 and position.y >= 96 and position.y <= 104,
    'a moving target must not pull Lure beyond the frozen travelled corridor')
walkingAllowed = false
before = walks
advance()
assert(walks == before and not widget('v2CavebotStatus').text:find('no free SQM', 1, true),
    'a step cooldown must not be reported as a blocked escape route')
walkingAllowed = true
advance()
assert(walks == before + 1, 'Lure must resume moving after the step cooldown')
monsters, target, health = {}, nil, 100
advance(400)
advance(400)
for _ = 1, 40 do
    advance()
    if saved.lure_test_auto_explorer_v2.waypointIndex == 1 then break end
end
assert(saved.lure_test_auto_explorer_v2.waypointIndex == 1,
    'Lure must return to Stand and then resume Node routing after all visible monsters die')
stop()

-- Escape steps cannot send the player into a hole or staircase.
floorTile = { x = 101, y = 99 }
target = monster(102, 100)
monsters = { target }
startAtStand()
for _ = 1, 8 do
    advance()
    assert(position.x ~= floorTile.x or position.y ~= floorTile.y,
        'Lure must avoid floor transitions while escaping the attack target')
end
stop()
floorTile = nil

-- A walking command that is not acknowledged must not keep pushing against
-- the same apparently walkable tile. The next escape should use another SQM.
local normalWalk = g_game.walk
local rejected, attempted
g_game.walk = function(direction)
    local d = offsets[direction]
    attempted = { x = position.x + d[1], y = position.y + d[2], z = position.z }
    if not rejected then rejected = attempted; return true end
    return normalWalk(direction)
end
target = monster(102, 100)
monsters = { target }
startAtStand()
advance()
assert(rejected and position.x == 101 and position.y == 100)
advance(1000)
assert(attempted and (attempted.x ~= rejected.x or attempted.y ~= rejected.y),
    'an unacknowledged Lure step must choose another escape instead of retrying the wall')
stop()
g_game.walk = normalWalk

-- Real server cancellation is an event, not a four-second map obstruction.
-- The next tick must take another exit; attacks and the selected node survive.
rejected, attempted = nil, nil
g_game.walk = function(direction)
    local d = offsets[direction]
    attempted = { x = position.x + d[1], y = position.y + d[2], z = position.z }
    if not rejected then rejected = attempted; return true end
    return normalWalk(direction)
end
startAtStand()
advance()
before = walks
assert(playerEvents.onCancelWalk, 'Distance must subscribe to actual walk cancellation')
playerEvents.onCancelWalk(player, West)
advance()
assert(walks == before + 1 and (attempted.x ~= rejected.x or attempted.y ~= rejected.y),
    'a cancelled step must replan at the next movement opportunity, without a 900-ms pause')
assert(isAutoExplorerActive() and attackSettings.shooter and attackSettings.autoTarget)
stop()
g_game.walk = normalWalk

-- Delayed acknowledgements must not create false walls while native movement
-- is locked. Once the server confirms, continue instead of waiting four seconds.
local queued, queuedCount = nil, 0
player.getStepDuration = function() return 150 end
g_game.getPing = function() return 180 end
g_game.walk = function(direction) queued = direction; queuedCount = queuedCount + 1; return true end
startAtStand()
advance()
local originalDirection = queued
walkingAllowed = false
for _ = 1, 12 do advance() end
assert(queued == originalDirection and queuedCount == 1,
    'a pending native walk must not be interrupted or resent')
normalWalk(queued)
walkingAllowed = true
g_game.walk = normalWalk
before = walks
advance()
assert(walks == before + 1, 'a delayed confirmed step must immediately resume Distance')
stop()

-- A silent rejected packet on a low-ping connection is retried using another
-- safe step promptly, rather than the previous fixed 900-ms wait.
player.getStepDuration = function() return 100 end
g_game.getPing = function() return 8 end
rejected, attempted = nil, nil
g_game.walk = function(direction)
    local d = offsets[direction]
    attempted = { x = position.x + d[1], y = position.y + d[2], z = position.z }
    if not rejected then rejected = attempted; return true end
    return normalWalk(direction)
end
startAtStand()
advance()
before = walks
for _ = 1, 5 do advance() end
assert(walks > before and (attempted.x ~= rejected.x or attempted.y ~= rejected.y),
    'a missing acknowledgement should recover within 250 ms at low ping')
stop()
g_game.walk = normalWalk
player.getStepDuration, g_game.getPing = nil, nil

-- Native pre-walk updates the displayed position before server confirmation.
-- It must not clear pending state or make a cancelled prediction count as
-- route travel. Roll back, deliver the real cancel event and use another exit.
GameAllowPreWalk = 99
local prediction, serverPosition, sentDirection, predictionCount = nil, nil, nil, 0
g_game.getFeature = function(feature) return feature == GameAllowPreWalk end
player.isPreWalking = function() return prediction == true end
player.preWalk = function(_, direction)
    predictionCount = predictionCount + 1
    serverPosition = position
    local d = offsets[direction]
    position = { x = position.x + d[1], y = position.y + d[2], z = position.z }
    prediction, walkingAllowed = true, false
end
g_game.walk = function(direction) sentDirection = direction return true end
startAtStand()
advance()
local predicted = position
assert(prediction and sentDirection)
advance(400)
assert(position == predicted and predictionCount == 1,
    'prediction awaiting acknowledgement must not send another step')
position = serverPosition
prediction, walkingAllowed = false, true
playerEvents.onCancelWalk(player, West)
local cancelledDirection = sentDirection
advance()
assert(prediction and sentDirection ~= cancelledDirection and predictionCount == 2,
    'cancelled prediction must recover via another exit instead of recording phantom progress')
-- Confirm the second prediction without another position-change event, as the
-- native client does when the acknowledged SQM matches its predicted position.
prediction, walkingAllowed = false, true
advance()
assert(prediction and predictionCount == 3, 'a confirmed prediction must allow the next step')
stop()
prediction, walkingAllowed = false, true
player.preWalk, player.isPreWalking, g_game.getFeature, GameAllowPreWalk = nil, nil, nil, nil
g_game.walk = normalWalk

-- Nodes are also suspended by Lure combat; they are visited after the pack dies.
widget('v2CavebotWaypointList').children[1].onClick()
position = { x = 100, y = 100, z = 7 }
target = monster(102, 100)
monsters = { target }
click('v2CavebotAutoExploringButton')
for _ = 1, 6 do advance() end
assert(saved.lure_test_auto_explorer_v2.waypointIndex == 1,
    'Lure must not advance a Node while its combat pack remains alive')
monsters, target = {}, nil
for _ = 1, 35 do
    advance()
    if saved.lure_test_auto_explorer_v2.waypointIndex == 2 then break end
end
assert(position.x == 100 and position.y == 100 and saved.lure_test_auto_explorer_v2.waypointIndex == 2,
    'Lure must resume and visit its original Node when combat clears')
stop()

-- The Lure style clears its pack before executing even an explicit stair.
local originalRoute = BaiakHelperExplorerV2.copyRoute()
assert(BaiakHelperExplorerV2.replaceRoute({ waypoints = {
    { kind = 'stair', x = 101, y = 100, z = 7, direction = 'north' },
    { kind = 'node', x = 105, y = 100, z = 7, direction = 'center' }
} }))
floorTile = { x = 101, y = 99 }
position = { x = 101, y = 100, z = 7 }
target = monster(103, 100)
monsters = { target }
click('v2CavebotAutoExploringButton')
for _ = 1, 8 do
    advance()
    assert(position.x ~= 101 or position.y ~= 99, 'Lure must not enter Stair before clearing monsters')
end
monsters, target = {}, nil
local enteredStair = false
for _ = 1, 35 do
    advance()
    if position.x == 101 and position.y == 99 then enteredStair = true; break end
end
assert(enteredStair, 'Lure must execute the recorded Stair after the final monster dies')
stop()
floorTile = nil
assert(BaiakHelperExplorerV2.replaceRoute(originalRoute))

-- Travel while empty, then suspend Node movement for even one monster. Old
-- settings containing a count of twenty must not impose a hidden threshold.
assert(saved.lure_test_auto_explorer_v2.lureCount == nil)
assert(BaiakHelperExplorerV2.replaceRoute({ waypoints = {
    { kind = 'node', x = 110, y = 100, z = 7 },
    { kind = 'stand', x = 115, y = 100, z = 7 }
} }))
position = { x = 100, y = 100, z = 7 }
monsters, target = {}, nil
click('v2CavebotAutoExploringButton')
for _ = 1, 4 do advance(300) end
assert(position.x == 104 and position.y == 100,
    'an empty screen must allow Node travel')
assert(attackSettings.autoTarget and attackSettings.shooter and not shouldHoldExplorerAttack())
monsters = { monster(position.x + 6, position.y + 1), monster(103, 102), monster(102, 102), monster(103, 103) }
monsters[2].isDead = function() return true end
monsters[3].getMasterId = function() return 1 end
monsters[4].getPosition = function() return { x = 103, y = 103, z = 6 } end
advance(300)
assert(position.x == 105, 'dead, summoned, other-floor and distant monsters must not trigger Distance')
target = monster(position.x + 5, position.y + 5)
monsters = { target }
advance(300)
assert(widget('v2CavebotStatus').text:find('Distance:', 1, true),
    'one living monster on the diagonal boundary must trigger Distance')
for _ = 1, 80 do
    advance(300)
    assert(position.x >= 96 and position.x <= 109 and position.y >= 96 and position.y <= 104,
        'kiting steps must never expand the travelled route corridor')
    assert(saved.lure_test_auto_explorer_v2.waypointIndex == 1,
        'a single remaining monster must hold the route in combat until the pack clears')
end
monsters, target = {}, nil
for _ = 1, 60 do
    advance(300)
    if saved.lure_test_auto_explorer_v2.waypointIndex == 2 then break end
end
assert(position.x == 110 and position.y == 100 and saved.lure_test_auto_explorer_v2.waypointIndex == 2,
    'after clearing combat, visit the suspended Node before advancing')
stop()
assert(BaiakHelperExplorerV2.replaceRoute(originalRoute))

-- Every pack before Stand must be fought while running, even three monsters.
target = monster(103, 100)
monsters = { target, monster(104, 102), monster(103, 103) }
startAtStand(100, 100)
before = walks
for _ = 1, 5 do advance() end
assert(walks == before + 5 and saved.lure_test_auto_explorer_v2.waypointIndex == 2,
    'three monsters before Stand must start continuous kiting')
monsters = { target }
before = walks
for _ = 1, 12 do advance() end
assert(walks == before + 12 and saved.lure_test_auto_explorer_v2.waypointIndex == 2,
    'the final monster must still be fought while running, without visiting or advancing Stand')
monsters, target = {}, nil
for _ = 1, 45 do
    advance(300)
    if saved.lure_test_auto_explorer_v2.waypointIndex == 1 then break end
end
assert(position.x == 101 and position.y == 100 and saved.lure_test_auto_explorer_v2.waypointIndex == 1,
    'visit Stand and advance only after the smaller pack is fully cleared')
stop()
target = monster(103, 100)
monsters = { target, monster(104, 102), monster(103, 103) }
startAtStand()
before = walks
for _ = 1, 5 do advance() end
assert(walks == before + 5 and saved.lure_test_auto_explorer_v2.waypointIndex == 2,
    'starting directly on Stand with three monsters must immediately run, never fight stationary')
stop()
monsters, target = {}, nil
-- JSON Save/Load must round-trip distance and ignore the removed quantity, using the
-- existing asynchronous dialog callback without opening a real Windows dialog.
local routeFile, routeTick = nil, scheduled
g_platform = {
    startJsonFileDialog = function() return true end,
    isJsonFileDialogPending = function() return false end,
    takeJsonFileDialogResult = function() return 'test-route.json' end,
    writeUserFile = function(_, contents) routeFile = contents return true end,
    readUserFile = function() return routeFile end
}
widget('v2CavebotLureDistanceBox').onOptionChange(nil, nil, 4)
click('v2CavebotSaveRouteButton')
scheduled()
assert(json.decode(routeFile).lureCount == nil and json.decode(routeFile).lureDistance == 4)
local legacyFile = json.decode(routeFile)
legacyFile.lureCount = 20
routeFile = json.encode(legacyFile)
widget('v2CavebotLureDistanceBox').onOptionChange(nil, nil, 1)
click('v2CavebotLoadRouteButton')
scheduled()
assert(widget('v2CavebotLureDistanceBox').data == 4 and saved.lure_test_auto_explorer_v2.lureCount == nil,
    'loading an old JSON route must restore Distance and discard the old monster threshold')
scheduled = routeTick
BaiakHelperExplorerV2.onGameEnd()
BaiakHelperExplorerV2.onGameStart()
assert(widget('v2CavebotLureDistanceBox').data == 4, 'reconnecting must restore the selected distance')

-- The stationary and native-chase styles retain their own Stand behaviour.
for _, style in ipairs({ 'lure_stop', 'stop', 'chase' }) do
    widget('v2CavebotHuntStyleBox').onOptionChange(nil, nil, style)
    chaseMode = DontChase
    target = monster(102, 100)
    monsters = { target }
    startAtStand()
    before = walks
    for _ = 1, 3 do advance() end
    assert(walks == before and saved.lure_test_auto_explorer_v2.waypointIndex == 2,
        style .. ' must keep fighting at Stand instead of starting Lure escape steps')
    assert(chaseMode == (style == 'chase' and ChaseOpponent or DontChase),
        style .. ' must retain its own native chase behaviour')
    stop()
    assert(chaseMode == DontChase, 'stopping Chase must restore the original mode')
end
BaiakHelperExplorerV2.terminate()
assert(not playerEvents.onCancelWalk, 'terminating the Helper must unregister movement events')
print('Cavebot Lure regression passed: Stand, Echo, target distance 1-4, chase, cooldown, route resume, stairs, other hunt styles')
