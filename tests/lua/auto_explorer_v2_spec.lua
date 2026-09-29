-- Run with: luajit tests/lua/auto_explorer_v2_spec.lua
North, East, South, West = 0, 1, 2, 3
NorthEast, SouthEast, SouthWest, NorthWest = 4, 5, 6, 7
PlayerStates = { Pz = 1 }
DontChase, ChaseOpponent = 0, 1

local clock = 1000
local scheduled
local widgets = {}
local settings = {}
local files = {}
local nextSavePath
local nextLoadPath
local monsters = {}
local attackingCreature
local playerPosition = { x = 100, y = 100, z = 7 }
local attacks = { autoTarget = false, shooter = false }
local walks = 0
local stairsOnly = false
local routeMap = false
local corridorMap = false
local diagonalMap = false
local wallMap = false
local huntMap = false
local huntStandOccupied = false
local passageOccupied = false
local passageWall = false
local doorClosed = true
local uses = 0
local doorOpenAfterUses = 1
local echoPresent = false
local echoWalked = false
local echoSecondPresent = false
local echoSecondWalked = false
local echoPersistentFirst = false
local vocation = 11
local lureCasts = {}
local lureDirections = {}
local levitateCasts = {}
local selectedLureSpell
local noFreeAdjacent = false
local detachedStarts = 0
local manualAutoWalking = false
local playerDirection = North
local lastWalkDirection
local healthPercent = 100
local chaseMode = DontChase

local function widget(id)
    if widgets[id] then return widgets[id] end
    local value = { id = id, options = {} }
    function value:setText(text) self.text = text end
    function value:getText() return self.text or '' end
    function value:setEnabled(enabled) self.enabled = enabled end
    function value:setChecked(checked) self.checked = checked end
    function value:setCurrentOptionByData(data) self.data = data end
    function value:addOption(text, data) self.options[#self.options + 1] = { text = text, data = data } end
    function value:clearOptions() self.options = {} end
    function value:setPercent(percent) self.percent = percent end
    function value:setBackgroundColor(color) self.color = color end
    function value:setColor(color) self.textColor = color end
    function value:setTooltip(tooltip) self.tooltip = tooltip end
    function value:setOn(on) self.on = on end
    function value:setVisible(visible) self.visible = visible end
    function value:setMarginTop(margin) self.marginTop = margin end
    function value:recursiveGetChildById(childId) return widget(childId) end
    function value:destroyChildren() self.children = {} end
    function value:getHeight() return 96 end
    widgets[id] = value
    return value
end

local window = { recursiveGetChildById = function(_, id) return widget(id) end }
local waypointRowCounter = 0
g_ui = { createWidget = function(_, parent)
    waypointRowCounter = waypointRowCounter + 1
    local row = widget('testWaypointRow' .. waypointRowCounter)
    row.removeButton = widget('testWaypointRemove' .. waypointRowCounter)
    row.recursiveGetChildById = function(self, childId)
        return childId == 'removeWaypoint' and self.removeButton or widget(childId)
    end
    parent.children = parent.children or {}
    parent.children[#parent.children + 1] = row
    return row
end }
local player = {
    getName = function() return 'Explorer Test' end,
    getPosition = function() return playerPosition end,
    getHealthPercent = function() return healthPercent end,
    getVocation = function() return vocation end,
    getDirection = function() return playerDirection end,
    isDead = function() return false end,
    hasState = function() return false end,
    canWalk = function() return true end,
    isAutoWalking = function() return manualAutoWalking end
}

modules = {
    game_interface = {
        lastManualWalk = 0,
        getMapPanel = function()
            return { getSpectators = function() return monsters end }
        end
    },
    game_baiakeros_helper = {
        playerConfigPrefix = function() return 'explorer_test' end,
        getAttackState = function() return attacks end,
        setAutoAttackEnabled = function(enabled) attacks.autoTarget = enabled end,
        setAttackRotationEnabled = function(enabled) attacks.shooter = enabled end,
        getSelectedExplorerLureSpell = function()
            return selectedLureSpell and { name = selectedLureSpell } or nil
        end,
        tryCastExplorerLureSpell = function(name, direction)
            lureCasts[#lureCasts + 1] = name
            lureDirections[#lureDirections + 1] = direction
            return true
        end,
        tryCastExplorerLevitate = function(level, direction)
            if playerDirection ~= direction then
                playerDirection = direction
                return false
            end
            levitateCasts[#levitateCasts + 1] = { level = level, direction = direction }
            playerPosition = { x = playerPosition.x, y = playerPosition.y,
                z = level == 'up' and playerPosition.z - 1 or playerPosition.z + 1 }
            return true
        end
    }
}
modules.game_baiakeros_helper_v2 = {
    detachCavebot = function() detachedStarts = detachedStarts + 1 end
}
g_clock = { millis = function() return clock end }
g_settings = {
    getNode = function(name) return settings[name] end,
    setNode = function(name, value) settings[name] = value end,
    save = function() end
}
g_platform = {
    chooseJsonFile = function(save)
        if save then
            local path = nextSavePath
            nextSavePath = nil
            return path or ''
        end
        local path = nextLoadPath
        nextLoadPath = nil
        return path or ''
    end,
    readUserFile = function(path) return files[path] or '' end,
    writeUserFile = function(path, contents)
        files[path] = contents
        return true
    end
}
json = dofile('modules/corelib/json.lua')
g_game = {
    isOnline = function() return true end,
    isFollowing = function() return false end,
    getLocalPlayer = function() return player end,
    getAttackingCreature = function() return attackingCreature end,
    getChaseMode = function() return chaseMode end,
    setChaseMode = function(mode) chaseMode = mode end,
    cancelAttack = function() end,
    turn = function(direction) playerDirection = direction end,
    use = function()
        uses = uses + 1
        doorClosed = uses < doorOpenAfterUses
    end,
    walk = function(direction)
        walks = walks + 1
        lastWalkDirection = direction
        local offsets = { [North] = { 0, -1 }, [East] = { 1, 0 },
            [South] = { 0, 1 }, [West] = { -1, 0 },
            [NorthEast] = { 1, -1 }, [SouthEast] = { 1, 1 },
            [SouthWest] = { -1, 1 }, [NorthWest] = { -1, -1 } }
        local offset = offsets[direction]
        playerPosition = {
            x = playerPosition.x + offset[1],
            y = playerPosition.y + offset[2],
            z = playerPosition.z
        }
        if echoPresent and playerPosition.x == 101 and playerPosition.y == 100 then
            if not echoPersistentFirst then echoPresent = false end
            echoWalked = true
        end
        if echoSecondPresent and playerPosition.x == 101 and playerPosition.y == 101 then
            echoSecondPresent = false
            echoSecondWalked = true
        end
        if stairsOnly and playerPosition.x == 101 and playerPosition.y == 100 then
            playerPosition.z = 6
        end
    end
}
g_map = {
    findPath = function(startPosition, goal, _, flags)
        if not corridorMap then return nil end
        if passageWall or (passageOccupied and flags ~= 20) then return nil end
        if startPosition.y ~= 100 or goal.y ~= 100 or
            startPosition.x > goal.x then return nil end
        local path = {}
        for _ = startPosition.x + 1, goal.x do path[#path + 1] = East end
        return path
    end,
    getTile = function(position)
        if huntMap then
            if position.z ~= 7 or position.x < 95 or position.x > 115 or
                position.y < 97 or position.y > 103 then return nil end
            return {
                getGround = function() return true end,
                isWalkable = function(_, ignoreCreatures)
                    return not (huntStandOccupied and position.x == 101 and
                        position.y == 100) or ignoreCreatures
                end,
                hasCreatures = function()
                    return huntStandOccupied and position.x == 101 and
                        position.y == 100
                end,
                hasFloorChange = function() return false end,
                hasElevation = function() return false end,
                getItems = function() return {} end
            }
        end
        if wallMap then
            if position.z ~= 7 or math.abs(position.x - 100) > 1 or
                position.y < 98 or position.y > 101 then return nil end
            local wall = position.x == 100 and position.y == 98
            return {
                getGround = function() return true end,
                isWalkable = function() return not wall end,
                hasFloorChange = function() return false end,
                hasElevation = function() return false end
            }
        end
        if diagonalMap then
            if position.z ~= 7 or not (
                position.x == 100 and position.y == 100 or
                position.x == 101 and position.y == 99 or
                position.x == 102 and position.y == 100 or
                position.x == 101 and position.y == 100) then return nil end
            local occupied = position.x == 101 and position.y == 100
            return {
                getGround = function() return true end,
                isWalkable = function(_, ignoreCreatures)
                    return not occupied or ignoreCreatures
                end,
                hasCreatures = function() return occupied end,
                hasFloorChange = function() return false end,
                hasElevation = function() return false end
            }
        end
        if corridorMap then
            if position.z ~= 7 or position.y ~= 100 or
                position.x < 100 or position.x > 102 then return nil end
            local occupied = position.x == 101 and passageOccupied
            local wall = position.x == 101 and passageWall
            return {
                getGround = function() return true end,
                isWalkable = function(_, ignoreCreatures)
                    return not wall and (ignoreCreatures or not occupied)
                end,
                hasCreatures = function() return occupied end,
                hasFloorChange = function() return false end,
                hasElevation = function() return false end
            }
        end
        if routeMap then
            if position.z ~= 7 or position.y ~= 100 or
                position.x < 100 or position.x > 102 then return nil end
            return {
                getGround = function() return true end,
                isWalkable = function() return position.x ~= 102 or not doorClosed end,
                hasFloorChange = function() return false end,
                hasElevation = function() return false end,
                getItems = function() return {} end,
                getTopUseThing = function()
                    if position.x ~= 102 then return nil end
                    return { isItem = function() return true end }
                end
            }
        end
        if stairsOnly then
            if position.x ~= 100 and position.x ~= 101 or position.y ~= 100 or
                position.z ~= 7 and position.z ~= 6 then return nil end
            return {
                getGround = function() return true end,
                isWalkable = function() return true end,
                hasFloorChange = function() return position.x == 101 end,
                hasElevation = function() return false end
            }
        end
        if position.z ~= 7 or math.abs(position.x - 100) > 1 or
            math.abs(position.y - 100) > 1 then return nil end
        return {
            getGround = function() return true end,
            isWalkable = function()
                return not noFreeAdjacent or position.x == 100 and position.y == 100
            end,
            hasFloorChange = function() return false end,
            hasElevation = function() return false end,
            getItems = function()
                if echoPresent and position.x == 101 and position.y == 100 then
                    return { { getId = function() return 54133 end } }
                end
                if echoSecondPresent and position.x == 101 and position.y == 101 then
                    return { { getId = function() return 54133 end } }
                end
                return {}
            end
        }
    end
}
scheduleEvent = function(callback)
    scheduled = callback
    return callback
end
removeEvent = function() scheduled = nil end

local function advance(milliseconds)
    clock = clock + milliseconds
    local callback = scheduled
    assert(callback, 'explorer tick was not scheduled')
    callback()
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

dofile('modules/game_baiakeros_helper_v2/explorer.lua')
BaiakHelperExplorerV2.init(window)
BaiakHelperExplorerV2.onGameStart()
assert(widget('v2CavebotTimerLabel').text == '01:00:00')
assert(widget('v2CavebotProgress').percent == 100)
assert(widget('v2CavebotAutoExploringButton').enabled == false,
    'Start must be disabled without waypoints')
widget('v2CavebotAutoExploringButton').onClick()
assert(not isAutoExplorerActive(), 'Start must reject an empty route even if invoked directly')

-- The selected row is the next target, including after Stop or a manual walk.
widget('v2CavebotNodeButton').onClick() -- 100,100
assert(widget('v2CavebotAutoExploringButton').enabled == true,
    'adding a waypoint must enable Start')
playerPosition = { x = 101, y = 100, z = 7 }
widget('v2CavebotNodeButton').onClick() -- 101,100
playerPosition = { x = 100, y = 100, z = 7 }
widget('v2CavebotStandButton').onClick() -- 100,100
assert(#settings.explorer_test_auto_explorer_v2.waypoints == 3)
local list = widget('v2CavebotWaypointList')
list.children[2].onClick()
assert(list.children[2].on == true)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2)
widget('v2CavebotAutoExploringButton').onClick()
assert(detachedStarts == 1 and widget('v2CavebotAutoExploringButton').text == 'Stop',
    'Start must open the compact Cavebot window with a Stop button')
assert(not attacks.autoTarget and not attacks.shooter,
    'starting Cavebot must not enable Auto Target or Shooter Helper')
advance(50)
assert(playerPosition.x == 101, 'Start must follow the selected second waypoint')
advance(50)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 3,
    'finishing a waypoint must persist the next target')
modules.game_interface.lastManualWalk = clock + 1
playerPosition = { x = 101, y = 101, z = 7 }
advance(50)
assert(isAutoExplorerActive() and
    settings.explorer_test_auto_explorer_v2.waypointIndex == 3,
    'manual movement must preserve the active route and waypoint')
advance(250)
assert(isAutoExplorerActive(), 'the bot must resume routing after manual movement')
manualAutoWalking = true
advance(50)
assert(isAutoExplorerActive(), 'manual click-to-walk must not stop the bot')
manualAutoWalking = false
advance(50)
assert(isAutoExplorerActive(),
    'routing must continue after click-to-walk finishes')
widget('v2CavebotAutoExploringButton').onClick()
widget('v2CavebotWaypointList').children[3].onClick()
playerPosition = { x = 101, y = 100, z = 7 } -- character moved while stopped
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
assert(playerPosition.x == 100,
    'Start must route from the current SQM toward the saved target')
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 3)
list = widget('v2CavebotWaypointList')
list.children[1].onClick()
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 1,
    'clicking the first row while running restarts the cycle')
widget('v2CavebotAutoExploringButton').onClick()

-- Deletion belongs to each row and keeps the target index valid.
list = widget('v2CavebotWaypointList')
list.children[2].removeButton.onClick()
assert(#settings.explorer_test_auto_explorer_v2.waypoints == 2)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 1)

local routeFile = 'C:\\Routes\\Dragon Cave.json'
nextSavePath = routeFile
widget('v2CavebotSaveRouteButton').onClick()
assert(#json.decode(files[routeFile]).waypoints == 2)
list = widget('v2CavebotWaypointList')
list.children[1].removeButton.onClick()
assert(#settings.explorer_test_auto_explorer_v2.waypoints == 1)
nextLoadPath = routeFile
widget('v2CavebotLoadRouteButton').onClick()
assert(#settings.explorer_test_auto_explorer_v2.waypoints == 2)
assert(widget('v2CavebotAutoExploringButton').enabled == true,
    'loading a nonempty route must enable Start')

-- Selecting a support spell in the shooter is the only lure control.
attacks.shooter = true
playerPosition = { x = 100, y = 100, z = 7 }
monsters = { monster(105, 100) }
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
assert(#lureCasts == 0, 'an unassigned Lure Spell must never cast')
selectedLureSpell = 'Chivalrous Challenge'
advance(50)
advance(50)
assert(#lureCasts == 0, 'Cavebot must never cast the selected Shooter lure spell')
widget('v2CavebotAutoExploringButton').onClick()
monsters = {}

vocation = 5
selectedLureSpell = 'Balanced Brawl'
playerPosition = { x = 100, y = 100, z = 7 }
monsters = { monster(105, 100) }
widget('v2CavebotAutoExploringButton').onClick()
advance(2200)
advance(800)
assert(#lureCasts == 0,
    'Monk lure spell must also be owned by Shooter Helper')
widget('v2CavebotAutoExploringButton').onClick()
monsters = {}
vocation = 11
selectedLureSpell = nil

-- An Echo is activated by walking on item 54133 after the Stand is clear.
list = widget('v2CavebotWaypointList')
list.children[2].removeButton.onClick()
list.children[1].removeButton.onClick()
playerPosition = { x = 100, y = 100, z = 7 }
widget('v2CavebotStandButton').onClick()
playerPosition = { x = 101, y = 100, z = 7 }
widget('v2CavebotNodeButton').onClick()
playerPosition = { x = 100, y = 100, z = 7 }
widget('v2CavebotWaypointList').children[1].onClick()
widget('v2CavebotEchoRaidsBox').onCheckChange(nil, true)
-- An empty Stand advances immediately even when Echo Raids are enabled.
echoPresent = false
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2,
    'an empty Stand must advance without waiting for an Echo to appear')
widget('v2CavebotAutoExploringButton').onClick()
widget('v2CavebotWaypointList').children[1].onClick()

-- Once a box is cleared, the Stand checks the visible screen once and moves on.
monsters = { monster(101, 99) }
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
monsters = {}
advance(50)
advance(350)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2,
    'a cleared box with no visible Echo must advance to the next Node')
widget('v2CavebotAutoExploringButton').onClick()
widget('v2CavebotWaypointList').children[1].onClick()

echoPresent = true
widget('v2CavebotAutoExploringButton').onClick()
advance(600)
advance(600)
advance(50)
advance(50)
assert(echoWalked, 'Echo Raid must be activated by stepping onto its tile')
assert(isAutoExplorerActive())
monsters = { monster(101, 99) }
advance(6000)
assert(isAutoExplorerActive(), 'the bot must wait during the Echo Raid spawn')
assert(not shouldHoldExplorerAttack(), 'the shooter must fight Echo Raid monsters')
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 1,
    'the bot must not leave the Stand while raid monsters remain')
monsters = {}
advance(7000)
assert(isAutoExplorerActive(), 'the bot must resume only after the raid clears')
local advancedAfterRaid = false
for _ = 1, 8 do
    advance(500)
    advancedAfterRaid = advancedAfterRaid or
        settings.explorer_test_auto_explorer_v2.waypointIndex == 2
end
assert(advancedAfterRaid,
    'the bot must continue to the next waypoint after the raid')
widget('v2CavebotAutoExploringButton').onClick()

-- Two visible Echoes must be activated one after the other at the same Stand.
widget('v2CavebotWaypointList').children[1].onClick()
playerPosition = { x = 100, y = 100, z = 7 }
echoPresent, echoSecondPresent = true, true
echoPersistentFirst = true -- The first item remains drawn after activation.
echoWalked, echoSecondWalked = false, false
widget('v2CavebotAutoExploringButton').onClick()
advance(50) -- Find the first Echo.
advance(50) -- Step onto it.
advance(50) -- Mark it activated.
assert(echoWalked and not echoSecondWalked)
monsters = { monster(101, 99) }
advance(50)
monsters = { monster(110, 110) } -- An unrelated distant monster remains visible.
advance(50)
advance(350)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 1,
    'the Stand must remain active while another Echo is visible')
advance(50)
assert(echoSecondWalked,
    'a distant monster must not prevent the bot from reaching a second Echo')
advance(50) -- Activate the second Echo.
monsters = { monster(101, 102) }
advance(50)
monsters = {}
advance(50)
advance(350)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2,
    'after every visible Echo is handled, the bot must resume the route')
widget('v2CavebotAutoExploringButton').onClick()
echoPresent, echoSecondPresent, echoPersistentFirst = false, false, false

BaiakHelperExplorerV2.onGameStart()
assert(settings.explorer_test_auto_explorer_v2.echoRaids == true)
assert(#widget('v2CavebotWaypointList').children == 2)
widget('v2CavebotAutoExploringButton').onClick()
widget('v2CavebotWaypointList').children[2].removeButton.onClick()
assert(isAutoExplorerActive(), 'deleting one row must keep a nonempty route running')
widget('v2CavebotWaypointList').children[1].removeButton.onClick()
assert(not isAutoExplorerActive(), 'deleting the final row must stop the bot')
assert(widget('v2CavebotAutoExploringButton').enabled == false,
    'deleting the final waypoint must disable Start again')

-- Without a selected Lure Spell, distant monsters cannot hold a Stand or slow routing.
playerPosition = { x = 100, y = 100, z = 7 }
widget('v2CavebotStandButton').onClick()
playerPosition = { x = 101, y = 100, z = 7 }
widget('v2CavebotNodeButton').onClick()
playerPosition = { x = 100, y = 100, z = 7 }
widget('v2CavebotWaypointList').children[1].onClick()
monsters = { monster(105, 100) }
widget('v2CavebotAutoExploringButton').onClick()
local castsWithoutLure = #lureCasts
advance(50)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2,
    'a distant monster must not hold a Stand without a Lure Spell')
advance(50)
assert(playerPosition.x == 101,
    'a distant monster must not slow travel to the next waypoint')
assert(#lureCasts == castsWithoutLure,
    'no Lure Spell must be cast when the slot is empty')
widget('v2CavebotAutoExploringButton').onClick()
widget('v2CavebotWaypointList').children[1].onClick()
playerPosition = { x = 100, y = 100, z = 7 }
monsters = { monster(101, 100) }
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 1,
    'a nearby monster must still be cleared at a Stand')
monsters = { monster(105, 100) }
advance(400)
advance(350)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2,
    'combat must release the Stand once only distant monsters remain')
widget('v2CavebotAutoExploringButton').onClick()
monsters = {}

-- exeta res taunts adjacent creatures but ignores distant ones on the route.
selectedLureSpell = 'Challenge'
widget('v2CavebotWaypointList').children[1].onClick()
playerPosition = { x = 100, y = 100, z = 7 }
monsters = { monster(102, 100) }
widget('v2CavebotAutoExploringButton').onClick()
local castsBeforeChallenge = #lureCasts
advance(50)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2 and
    #lureCasts == castsBeforeChallenge,
    'exeta res must ignore distant monsters and advance to the next waypoint')
widget('v2CavebotAutoExploringButton').onClick()
widget('v2CavebotWaypointList').children[1].onClick()
monsters = { monster(101, 100) }
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
assert(#lureCasts == 0,
    'Cavebot must leave adjacent exeta res casts to Shooter Helper')
widget('v2CavebotAutoExploringButton').onClick()

-- exeta amp res pulls distant monsters only if a surrounding SQM is free.
selectedLureSpell = 'Chivalrous Challenge'
widget('v2CavebotWaypointList').children[1].onClick()
monsters = { monster(105, 100) }
noFreeAdjacent = true
widget('v2CavebotAutoExploringButton').onClick()
local castsBeforeNoSpace = #lureCasts
advance(2200)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2 and
    #lureCasts == castsBeforeNoSpace,
    'exeta amp res must wait for a free adjacent SQM before casting')
widget('v2CavebotAutoExploringButton').onClick()
noFreeAdjacent = false
widget('v2CavebotWaypointList').children[1].onClick()
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
assert(#lureCasts == 0 and
    settings.explorer_test_auto_explorer_v2.waypointIndex == 1,
    'an assigned lure spell may hold the Stand, but Cavebot must not cast it')
widget('v2CavebotAutoExploringButton').onClick()
selectedLureSpell = nil
assert(attacks.shooter, 'stopping Cavebot must not disable Shooter Helper')

-- A Center Stand can move against a nearby wall and face away from it.
wallMap = true
monsters = {}
playerPosition = { x = 100, y = 100, z = 7 }
playerDirection = North
widget('v2CavebotHugWallBox').onCheckChange(nil, true)
assert(settings.explorer_test_auto_explorer_v2.hugWall == true)
widget('v2CavebotWaypointList').children[1].onClick()
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
assert(playerPosition.y == 99 and settings.explorer_test_auto_explorer_v2.waypointIndex == 1,
    'Hug Wall must move beside the solid wall before leaving the Stand')
advance(50)
assert(playerDirection == South and settings.explorer_test_auto_explorer_v2.waypointIndex == 2,
    'Hug Wall must face away from the wall before advancing')
widget('v2CavebotAutoExploringButton').onClick()
widget('v2CavebotHugWallBox').onCheckChange(nil, false)
wallMap = false
list = widget('v2CavebotWaypointList')
list.children[2].removeButton.onClick()
list.children[1].removeButton.onClick()

-- An occupied passage must keep the current Stand and retry until it opens.
corridorMap = true
passageOccupied = true
monsters = { monster(101, 100), monster(100, 101) }
selectedLureSpell = 'Chivalrous Challenge'
playerPosition = { x = 102, y = 100, z = 7 }
widget('v2CavebotStandButton').onClick()
playerPosition = { x = 100, y = 100, z = 7 }
widget('v2CavebotAutoExploringButton').onClick()
local walksBeforePassage = walks
advance(50)
assert(not shouldHoldExplorerAttack() and preferAreaExplorerAttack(),
    'an occupied passage with monsters must release the shooter for area attacks')
local castsBeforeBlockedPassage = #lureCasts
advance(50)
assert(#lureCasts == castsBeforeBlockedPassage,
    'exeta amp res must not cast in a blocked passage without a free adjacent SQM')
advance(3000)
assert(isAutoExplorerActive() and walks == walksBeforePassage,
    'a creature in a narrow passage must make the bot wait, not stop')
assert(widget('v2CavebotStatus').text:find('Passage occupied'),
    'the status must explain why the route is waiting')
passageOccupied = false
monsters = {}
selectedLureSpell = nil
attacks.shooter = false
advance(50)
assert(shouldHoldExplorerAttack(),
    'after the passage opens the shooter must return to route-gather mode')
advance(50)
assert(playerPosition.x == 102,
    'the bot must continue toward the same Stand when the passage opens')
widget('v2CavebotAutoExploringButton').onClick()

-- The fallback path finder may skirt an occupied straight tile diagonally.
corridorMap = false
diagonalMap = true
playerPosition = { x = 100, y = 100, z = 7 }
monsters = { monster(101, 100) }
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
assert(playerPosition.x == 101 and playerPosition.y == 99,
    'the bot must try a walkable diagonal around the occupied tile')
assert(shouldHoldExplorerAttack(),
    'monsters on the way to a Stand should be lured rather than stop the route')
advance(200)
assert(playerPosition.x == 102 and playerPosition.y == 100,
    'the diagonal detour must still reach the selected Stand')
widget('v2CavebotAutoExploringButton').onClick()
diagonalMap = false
monsters = {}
corridorMap = true

-- A permanent wall skips the missed waypoint but leaves the route active.
passageWall = true
playerPosition = { x = 100, y = 100, z = 7 }
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
advance(2200)
assert(isAutoExplorerActive() and
    widget('v2CavebotStatus').text:find('Skipped waypoint'),
    'a permanent wall must skip the waypoint without stopping the loop')
widget('v2CavebotAutoExploringButton').onClick()
passageWall = false
corridorMap = false

-- Nodes only guide the route; Chase and Stop engage at the Stand.
list = widget('v2CavebotWaypointList')
list.children[1].removeButton.onClick()
huntMap = true
playerPosition = { x = 100, y = 100, z = 7 }
widget('v2CavebotNodeButton').onClick()
playerPosition = { x = 101, y = 100, z = 7 }
widget('v2CavebotStandButton').onClick()
local styleBox = widget('v2CavebotHuntStyleBox')
styleBox.onOptionChange(nil, nil, 'chase')
assert(settings.explorer_test_auto_explorer_v2.huntStyle == 'chase')
assert(not widget('v2CavebotLureDistanceBox').visible,
    'distance controls must stay hidden outside Lure')
widget('v2CavebotWaypointList').children[1].onClick()
playerPosition = { x = 100, y = 100, z = 7 }
monsters = { monster(104, 100) }
widget('v2CavebotAutoExploringButton').onClick()
assert(not shouldHoldExplorerAttack() and not preferAreaExplorerAttack(),
    'Chase must fire single-target rotation while pursuing')
assert(isSingleTargetExplorerHunt(), 'Chase must restrict the shooter to single-target attacks')
local walksBeforeChase = walks
advance(50)
advance(50)
assert(walks > walksBeforeChase and playerPosition.x == 101 and
    chaseMode == DontChase,
    'Chase must traverse the Node before engaging at the Stand')
monsters = { monster(103, 100) }
advance(50)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2 and
    chaseMode == ChaseOpponent,
    'Chase must stop and follow-attack monsters at the Stand')
monsters = {}
advance(50)
assert(chaseMode == DontChase and
    settings.explorer_test_auto_explorer_v2.waypointIndex == 1,
    'Chase must restore the prior combat mode and leave the Stand after the last kill')
widget('v2CavebotAutoExploringButton').onClick()

styleBox.onOptionChange(nil, nil, 'stop')
widget('v2CavebotWaypointList').children[1].onClick()
playerPosition = { x = 100, y = 100, z = 7 }
monsters = { monster(104, 100) }
widget('v2CavebotAutoExploringButton').onClick()
local walksBeforeStop = walks
advance(50)
advance(50)
assert(walks > walksBeforeStop and playerPosition.x == 101,
    'Stop must follow the Node despite a visible distant monster')
advance(50)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2,
    'Stop must wait at the Stand for a visible distant monster')
monsters = { monster(102, 100) }
advance(50)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2 and
    not shouldHoldExplorerAttack(),
    'Stop must fight when the monster reaches the Stand')
monsters = {}
advance(50)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 1,
    'Stop must leave the Stand immediately after clearing the monster')
widget('v2CavebotAutoExploringButton').onClick()

styleBox.onOptionChange(nil, nil, 'lure')
local lureDistanceBox = widget('v2CavebotLureDistanceBox')
assert(lureDistanceBox.visible and lureDistanceBox.enabled and
    #lureDistanceBox.options == 4,
    'Lure must expose a 1-4 SQM distance selector')
lureDistanceBox.onOptionChange(nil, nil, 4)
assert(settings.explorer_test_auto_explorer_v2.lureDistance == 4,
    'the selected Lure distance must be saved for the character')
lureDistanceBox.onOptionChange(nil, nil, 2)
widget('v2CavebotWaypointList').children[2].onClick()
playerPosition = { x = 101, y = 100, z = 7 }
monsters = { monster(102, 100) }
widget('v2CavebotAutoExploringButton').onClick()
assert(not shouldHoldExplorerAttack() and preferAreaExplorerAttack(),
    'Lure must allow area spells while travelling')
assert(not isSingleTargetExplorerHunt(), 'Lure must allow area spells and runes')
advance(50)
local kiteStart = { x = playerPosition.x, y = playerPosition.y }
advance(50)
assert(playerPosition.x ~= kiteStart.x or playerPosition.y ~= kiteStart.y,
    'Lure must keep moving while attacking')
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2)
playerPosition = { x = 101, y = 100, z = 7 }
local distantTarget = monster(108, 100)
attackingCreature = distantTarget
monsters = { monster(99, 100), distantTarget }
for _ = 1, 5 do advance(50) end
assert(playerPosition.x >= 105 and settings.explorer_test_auto_explorer_v2.waypointIndex == 2,
    'Lure must follow the attack target beyond the old Stand radius')
assert(math.max(math.abs(playerPosition.x - 108), math.abs(playerPosition.y - 100)) == 2,
    'Lure must reach the selected 2 SQM distance from its attack target')
local beforeTargetMoved = playerPosition.x
distantTarget = monster(111, 100)
attackingCreature = distantTarget
monsters = { distantTarget }
for _ = 1, 3 do advance(50) end
assert(playerPosition.x > beforeTargetMoved,
    'Lure must keep its distance from a moving target instead of returning to Stand')
assert(math.max(math.abs(playerPosition.x - 111), math.abs(playerPosition.y - 100)) == 2,
    'Lure must restore the selected distance after the target moves')
lureDistanceBox.onOptionChange(nil, nil, 4)
advance(50)
advance(50)
assert(math.max(math.abs(playerPosition.x - 111), math.abs(playerPosition.y - 100)) == 4,
    'changing Lure distance must make the bot reposition around the target')
monsters = {}
attackingCreature = nil
advance(400)
advance(350)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 1,
    'Lure must continue to the next waypoint after combat')
widget('v2CavebotAutoExploringButton').onClick()
lureDistanceBox.onOptionChange(nil, nil, 2)

-- An adjacent pack may leave no tile at the preferred SQM range. Lure
-- should still take a free escape step as soon as the Stand is reached.
widget('v2CavebotWaypointList').children[2].onClick()
playerPosition = { x = 101, y = 100, z = 7 }
monsters = { monster(100, 100), monster(102, 100) }
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
assert(playerPosition.y ~= 100 and not attacks.autoTarget and not attacks.shooter,
    'Lure must kite from a crowded Stand without changing Helper combat toggles')
assert(not widget('v2CavebotStatus').text:find('no free SQM', 1, true),
    'a free adjacent SQM must not be rejected solely for being close to monsters')
widget('v2CavebotAutoExploringButton').onClick()

-- A monster on the Stand must trigger target-based kiting rather than waiting
-- for the occupied tile. Low health must not stop Lure or Helper combat.
widget('v2CavebotWaypointList').children[2].onClick()
playerPosition = { x = 100, y = 100, z = 7 }
monsters = { monster(101, 100) }
huntStandOccupied = true
healthPercent = 20
local walksBeforeOccupiedStand = walks
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
assert(isAutoExplorerActive() and walks > walksBeforeOccupiedStand and
    lastWalkDirection <= West and not attacks.autoTarget and not attacks.shooter,
    'Lure must move around an occupied Stand without forcing Helper combat on')
advance(50)
assert(isAutoExplorerActive() and walks > walksBeforeOccupiedStand + 1,
    'Lure must continue moving while the Stand stays occupied')
huntStandOccupied = false
local targetAfterOpening = monster(108, 100)
attackingCreature = targetAfterOpening
monsters = { targetAfterOpening }
for _ = 1, 8 do advance(50) end
assert(playerPosition.x >= 105,
    'Lure must follow the target when the Stand opens rather than returning to it')
widget('v2CavebotAutoExploringButton').onClick()
healthPercent = 100
monsters = {}
attackingCreature = nil

-- An occupied Stand must not park the bot even when the character is still
-- several SQMs away from it.
widget('v2CavebotWaypointList').children[2].onClick()
playerPosition = { x = 96, y = 100, z = 7 }
monsters = { monster(101, 100) }
huntStandOccupied = true
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
assert(isAutoExplorerActive() and playerPosition.x > 96,
    'Lure must approach the area around an occupied Stand instead of waiting far away')
widget('v2CavebotAutoExploringButton').onClick()
huntStandOccupied = false
monsters = {}

local huntRouteFile = 'C:\\Routes\\Mage Hunt.json'
nextSavePath = huntRouteFile
widget('v2CavebotSaveRouteButton').onClick()
assert(json.decode(files[huntRouteFile]).huntStyle == 'lure',
    'saving a route must preserve its hunt style')
assert(json.decode(files[huntRouteFile]).lureDistance == 2,
    'saving a route must preserve its Lure distance')
lureDistanceBox.onOptionChange(nil, nil, 4)
styleBox.onOptionChange(nil, nil, 'chase')
nextLoadPath = huntRouteFile
widget('v2CavebotLoadRouteButton').onClick()
assert(settings.explorer_test_auto_explorer_v2.huntStyle == 'lure',
    'loading a route must restore its hunt style')
assert(settings.explorer_test_auto_explorer_v2.lureDistance == 2 and
    lureDistanceBox.data == 2,
    'loading a route must restore its Lure distance')
huntMap = false
monsters = {}

-- A directed Stand must face the stair, step onto it and wait for a real
-- floor transition before advancing to the waypoint on the upper floor.
local function clearRoute()
    local rows = widget('v2CavebotWaypointList').children
    while rows and #rows > 0 do
        rows[1].removeButton.onClick()
        rows = widget('v2CavebotWaypointList').children
    end
end
clearRoute()
stairsOnly = true
playerPosition = { x = 100, y = 100, z = 7 }
playerDirection = North
widget('v2CavebotDirectionBox').onOptionChange(nil, nil, 'east')
widget('v2CavebotStandButton').onClick()
playerPosition = { x = 101, y = 100, z = 6 }
widget('v2CavebotNodeButton').onClick()
playerPosition = { x = 100, y = 100, z = 7 }
widget('v2CavebotWaypointList').children[1].onClick()
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
assert(playerDirection == East and playerPosition.z == 7,
    'the directed Stand must face the stair before walking')
advance(200)
assert(playerPosition.x == 101 and playerPosition.z == 6,
    'the directed Stand must walk onto the recorded stair')
advance(50)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2 and
    isAutoExplorerActive(),
    'a confirmed floor transition must advance to the upper-floor waypoint')
widget('v2CavebotAutoExploringButton').onClick()

-- If the recorded waypoint itself is a stair tile, the explicit goal is
-- allowed even though automatic floor exploration is disabled.
clearRoute()
playerPosition = { x = 101, y = 100, z = 7 }
widget('v2CavebotDirectionBox').onOptionChange(nil, nil, 'center')
widget('v2CavebotStandButton').onClick()
playerPosition = { x = 101, y = 100, z = 6 }
widget('v2CavebotNodeButton').onClick()
playerPosition = { x = 100, y = 100, z = 7 }
widget('v2CavebotWaypointList').children[1].onClick()
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
advance(50)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2 and
    playerPosition.z == 6,
    'an explicit stair waypoint must not be skipped or loop below the stairs')
widget('v2CavebotAutoExploringButton').onClick()

-- Hur Up/Down use the chosen cardinal facing after combat and only advance
-- when the server reports the new floor.
clearRoute()
playerPosition = { x = 100, y = 100, z = 7 }
widget('v2CavebotHurUpButton').onClick()
assert(#settings.explorer_test_auto_explorer_v2.waypoints == 0,
    'Hur Up must require a cardinal direction')
widget('v2CavebotDirectionBox').onOptionChange(nil, nil, 'east')
widget('v2CavebotHurUpButton').onClick()
playerPosition = { x = 100, y = 100, z = 6 }
widget('v2CavebotDirectionBox').onOptionChange(nil, nil, 'west')
widget('v2CavebotHurDownButton').onClick()
playerPosition = { x = 100, y = 100, z = 7 }
widget('v2CavebotWaypointList').children[1].onClick()
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
advance(50)
advance(50)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2 and
    playerPosition.z == 6 and levitateCasts[1].level == 'up' and
    levitateCasts[1].direction == East,
    'Hur Up must face East and wait for the upper-floor arrival')
advance(50)
advance(50)
advance(50)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 1 and
    playerPosition.z == 7 and levitateCasts[2].level == 'down' and
    levitateCasts[2].direction == West,
    'Hur Down must face West and wait for the lower-floor arrival')
widget('v2CavebotAutoExploringButton').onClick()
stairsOnly = false

-- The selected route wraps after its last Stand. Falling to a floor without
-- recorded waypoints must pause navigation, then resume when back on-route.
clearRoute()
huntMap = true
styleBox.onOptionChange(nil, nil, 'lure_stop')
widget('v2CavebotDirectionBox').onOptionChange(nil, nil, 'center')
playerPosition = { x = 100, y = 100, z = 7 }
widget('v2CavebotNodeButton').onClick()
playerPosition = { x = 101, y = 100, z = 7 }
widget('v2CavebotStandButton').onClick()
playerPosition = { x = 100, y = 100, z = 7 }
widget('v2CavebotWaypointList').children[1].onClick()
monsters = { monster(102, 100) }
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
advance(50)
advance(50)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2 and
    playerPosition.x == 101,
    'the Node must lead to the Stand without stopping for monsters')
advance(50)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 2,
    'the Stand must keep its waypoint while monsters remain')
monsters = {}
advance(200)
assert(settings.explorer_test_auto_explorer_v2.waypointIndex == 1,
    'clearing the Stand must wrap to the first waypoint')
advance(50)
assert(playerPosition.x == 100 and isAutoExplorerActive(),
    'the route must walk back toward its first Node and stay active')
playerPosition = { x = 100, y = 100, z = 6 }
advance(50)
assert(isAutoExplorerActive() and
    widget('v2CavebotStatus').text:find('Waiting for a route waypoint'),
    'falling to an unrecorded floor must keep the script alive')
playerPosition = { x = 100, y = 100, z = 7 }
advance(650)
assert(isAutoExplorerActive() and
    settings.explorer_test_auto_explorer_v2.waypointIndex >= 1,
    'the route must resume automatically when a recorded floor is reached')
widget('v2CavebotAutoExploringButton').onClick()
huntMap = false

-- A missed waypoint advances to the next entry, and the final entry wraps.
clearRoute()
corridorMap = true
passageWall = true
playerPosition = { x = 102, y = 100, z = 7 }
widget('v2CavebotNodeButton').onClick()
playerPosition = { x = 100, y = 100, z = 7 }
widget('v2CavebotNodeButton').onClick()
widget('v2CavebotWaypointList').children[1].onClick()
widget('v2CavebotAutoExploringButton').onClick()
advance(50)
advance(2200)
assert(isAutoExplorerActive() and
    settings.explorer_test_auto_explorer_v2.waypointIndex == 2,
    'an unreachable Node must be skipped in favor of the following waypoint')
advance(450)
assert(isAutoExplorerActive() and
    settings.explorer_test_auto_explorer_v2.waypointIndex == 1,
    'the final Node must wrap to the first waypoint without stopping')
widget('v2CavebotAutoExploringButton').onClick()
corridorMap = false
passageWall = false

-- Recording inserts below the selected row and keeps the new row selected.
clearRoute()
playerPosition = { x = 100, y = 100, z = 7 }
widget('v2CavebotNodeButton').onClick()
playerPosition = { x = 101, y = 100, z = 7 }
widget('v2CavebotNodeButton').onClick()
playerPosition = { x = 102, y = 100, z = 7 }
widget('v2CavebotStandButton').onClick()
widget('v2CavebotWaypointList').children[1].onClick()
playerPosition = { x = 103, y = 100, z = 7 }
widget('v2CavebotUseButton').onClick()
local inserted = settings.explorer_test_auto_explorer_v2
assert(#inserted.waypoints == 4 and inserted.waypoints[2].kind == 'use' and
    inserted.waypoints[2].x == 103 and inserted.waypoints[3].x == 101 and
    inserted.waypointIndex == 2 and
    widget('v2CavebotWaypointList').children[2].on,
    'new waypoints must appear directly below the clicked row and become selected')
playerPosition = { x = 104, y = 100, z = 7 }
widget('v2CavebotStandButton').onClick()
inserted = settings.explorer_test_auto_explorer_v2
assert(inserted.waypoints[3].x == 104 and inserted.waypoints[4].x == 101,
    'subsequent recording must continue below the newly selected waypoint')
widget('v2CavebotWaypointList').children[5].onClick()
playerPosition = { x = 105, y = 100, z = 7 }
widget('v2CavebotNodeButton').onClick()
inserted = settings.explorer_test_auto_explorer_v2
assert(#inserted.waypoints == 6 and inserted.waypoints[6].x == 105,
    'clicking the final row must resume appending at the end')
nextSavePath = 'C:\\Routes\\Inserted Waypoints.json'
widget('v2CavebotSaveRouteButton').onClick()
assert(json.decode(files['C:\\Routes\\Inserted Waypoints.json']).waypoints[2].x == 103,
    'saving must keep the insertion order of waypoints')

BaiakHelperExplorerV2.terminate()
print('Auto Explorer V2 regression passed')
