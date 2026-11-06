BaiakHelperExplorerV2 = {}

local DAILY_LIMIT_MS = 3 * 60 * 60 * 1000
local CAVEBOT_OPCODE = 92
local HEARTBEAT_MS = 3000
local serverStatusReady = false
local lastHeartbeatAt = 0
local lastRankingRequestAt = 0
local ECHO_ITEM_ID = 54133
local ECHO_SPAWN_WINDOW_MS = 12000
local ECHO_COMBAT_RADIUS = 5
local TICK_MS = 50
local BLOCKED_RETRY_MS = 4000
local MAX_SEARCH_DEPTH = 12
local MAX_SEARCH_NODES = 400
local HUNT_STYLES = {
    { name = 'Chase', value = 'chase' },
    { name = 'Distance', value = 'lure' },
    { name = 'Lure and Stop', value = 'lure_stop' },
    { name = 'Stop', value = 'stop' }
}
local DIRECTIONS = {
    { 0, -1, North }, { 1, 0, East },
    { 0, 1, South }, { -1, 0, West },
    { 1, -1, NorthEast }, { 1, 1, SouthEast },
    { -1, 1, SouthWest }, { -1, -1, NorthWest }
}
local WAYPOINT_DIRECTIONS = {
    { name = 'Center', short = 'C', value = 'center', x = 0, y = 0 },
    { name = 'North', short = 'N', value = 'north', x = 0, y = -1, walk = North },
    { name = 'North East', short = 'NE', value = 'north-east', x = 1, y = -1, walk = NorthEast },
    { name = 'East', short = 'E', value = 'east', x = 1, y = 0, walk = East },
    { name = 'South East', short = 'SE', value = 'south-east', x = 1, y = 1, walk = SouthEast },
    { name = 'South', short = 'S', value = 'south', x = 0, y = 1, walk = South },
    { name = 'South West', short = 'SW', value = 'south-west', x = -1, y = 1, walk = SouthWest },
    { name = 'West', short = 'W', value = 'west', x = -1, y = 0, walk = West },
    { name = 'North West', short = 'NW', value = 'north-west', x = -1, y = -1, walk = NorthWest }
}

local window
local tickEvent
local dialogPollEvent
local dialogBusy = false
local clearRouteWindow
local characterKey
local usedMs = 0
local options = { floors = false, maxFloors = 1, mode = 'off', waitCount = 3, movingCount = 4,
    echoRaids = false, hugWall = false, huntStyle = 'lure_stop', lureDistance = 2 }
local running = false
local phase = 'gather'
local originFloor
local lastPosition
local pendingStep
local pendingSince = 0
local pendingKite = false
local kiteRejected = {}
local nextMoveAt = 0
local lastChargeAt = 0
local lastSaveAt = 0
local lastManualWalk = 0
local fightEmptySince
local lostGroupSince
local approachProgressAt = 0
local approachCloseCount = 0
local nextGroupCheckAt = 0
local visited = {}
local blocked = {}
local trail = {}
local stairVisits = {}
local returnStairs = {}
local learnedFloorChanges = {}
local exploreGoal
local statusText = 'Ready to explore'
local syncing = false
local waypoints = {}
local legacySavedRoutes = {}
local waypointIndex = 1
local selectedWaypoint
local selectedDirection = 'center'
local directionSelectionPosition
local waypointRows = {}
local routeAction
local routeStuckSince
local routeAttempts = 0
local blockedCombat = false
local wallAnchor
local lureCombatMembers = {}
local lureRouteHistory = {}
local lureCorridor
local lurePatrolBack = true
local lastKiteDirection
local echoTarget
local echoActivatedAt
local echoActivationPosition
local echoSpawned = false
local visitedEchoesForStand = {}
local previousChaseMode
local controlledChaseMode
local routeController
local normalRouteBackup
local lastFloorTransition
local render

local function waypointDirection(value)
    for _, direction in ipairs(WAYPOINT_DIRECTIONS) do
        if direction.value == value then return direction end
    end
    return WAYPOINT_DIRECTIONS[1]
end

local function cardinalDirection(direction)
    return direction.walk == North or direction.walk == East or
        direction.walk == South or direction.walk == West
end

local function hasRoute()
    return #waypoints > 0
end

local function validHuntStyle(value)
    for _, style in ipairs(HUNT_STYLES) do
        if style.value == value then return value end
    end
    return 'lure_stop'
end

local function validLureDistance(value)
    return math.max(1, math.min(4, math.floor(tonumber(value) or 2)))
end

local function key(position)
    return position.x .. ':' .. position.y .. ':' .. position.z
end

local function samePosition(a, b)
    return a and b and a.x == b.x and a.y == b.y and a.z == b.z
end

local function resetWaypointDirection()
    selectedDirection = 'center'
    directionSelectionPosition = nil
    if window then
        window:recursiveGetChildById('v2CavebotDirectionBox'):
            setCurrentOptionByData('center', true)
    end
end

local function updateRecordingDirection(position)
    if directionSelectionPosition and not samePosition(position, directionSelectionPosition) then
        resetWaypointDirection()
    end
end

local function isFloorTransition(position, tile)
    return learnedFloorChanges[key(position)] or
        (tile and (tile:hasFloorChange() or tile:hasElevation(3)))
end

local function distance(a, b)
    if not a or not b or a.z ~= b.z then return math.huge end
    return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

local function configKey()
    local helper = modules.game_baiakeros_helper
    return helper.playerConfigPrefix() .. '_auto_explorer_v2'
end

local function save()
    if routeController then return end
    if not characterKey then return end
    g_settings.setNode(characterKey, {
        floors = options.floors,
        maxFloors = options.maxFloors,
        mode = options.mode,
        waitCount = options.waitCount,
        movingCount = options.movingCount,
        echoRaids = options.echoRaids,
        hugWall = options.hugWall,
        huntStyle = options.huntStyle,
        lureDistance = options.lureDistance,
        waypointIndex = waypointIndex,
        selectedWaypoint = selectedWaypoint,
        waypoints = waypoints,
        savedRoutes = legacySavedRoutes
    })
    g_settings.save()
    lastSaveAt = g_clock.millis()
end

local function normalizedWaypoints(source)
    local result = {}
    if type(source) ~= 'table' then return result end
    for _, waypoint in ipairs(source) do
        if #result >= 200 then break end
        if type(waypoint) == 'table' and
            (waypoint.kind == 'node' or waypoint.kind == 'stand' or
                waypoint.kind == 'use' or waypoint.kind == 'hur_up' or
                waypoint.kind == 'hur_down' or waypoint.kind == 'stair' or
                waypoint.kind == 'rope' or waypoint.kind == 'exani_tera') then
            local x, y, z = tonumber(waypoint.x), tonumber(waypoint.y), tonumber(waypoint.z)
            if x and y and z and x >= 0 and y >= 0 and z >= 0 and z <= 15 then
                local direction = waypointDirection(waypoint.direction)
                if waypoint.kind == 'exani_tera' then direction = WAYPOINT_DIRECTIONS[1] end
                x, y, z = math.floor(x), math.floor(y), math.floor(z)
                if waypoint.kind ~= 'hur_up' and waypoint.kind ~= 'hur_down' or
                    cardinalDirection(direction) then
                    result[#result + 1] = {
                        kind = waypoint.kind, x = x, y = y, z = z,
                        direction = direction.value,
                        targetX = x + direction.x,
                        targetY = y + direction.y,
                        targetZ = z
                    }
                end
            end
        end
    end
    return result
end

local function remainingMs()
    if routeController then return routeController.remainingMs() end
    return math.max(0, DAILY_LIMIT_MS - usedMs)
end

local function sendCavebotRequest(action, extra)
    if routeController then return end
    local protocol = g_game.getProtocolGame()
    if not protocol then return end
    local request = extra or {}
    request.action = action
    protocol:sendExtendedOpcode(CAVEBOT_OPCODE, json.encode(request))
end

local function setStatus(text)
    statusText = text
    if routeController then return end
    if window then window:recursiveGetChildById('v2CavebotStatus'):setText(text) end
end

local function renderWaypoints()
    if routeController then return end
    if not window then return end
    local list = window:recursiveGetChildById('v2CavebotWaypointList')
    list:destroyChildren()
    waypointRows = {}
    for index, waypoint in ipairs(waypoints) do
        local direction = waypointDirection(waypoint.direction)
        local kindLabel = waypoint.kind == 'use' and 'Use' or
            waypoint.kind == 'node' and 'Node' or
            waypoint.kind == 'hur_up' and 'Hur Up' or
            waypoint.kind == 'hur_down' and 'Hur Down' or
            waypoint.kind == 'rope' and 'Rope' or
            waypoint.kind == 'exani_tera' and 'Exani Tera' or
            waypoint.kind == 'stair' and 'Stair' or 'Stand'
        local row = g_ui.createWidget('HelperV2WaypointRow', list)
        local prefix = running and index == waypointIndex and '> ' or '  '
        row:setText(string.format('%s%02d %s %d,%d,%d %s', prefix, index,
            kindLabel,
            waypoint.x, waypoint.y, waypoint.z, direction.short))
        row:setTooltip(waypoint.kind == 'node' and
            string.format('Node at %d, %d, %d: continue to the next waypoint',
                waypoint.x, waypoint.y, waypoint.z) or
            string.format('%s at %d, %d, %d; %s targets %d, %d, %d',
                kindLabel, waypoint.x, waypoint.y, waypoint.z, direction.name,
                waypoint.targetX, waypoint.targetY, waypoint.targetZ))
        row:setOn(index == selectedWaypoint)
        local removeButton = row:recursiveGetChildById('removeWaypoint')
        removeButton.onClick = function()
            table.remove(waypoints, index)
            if #waypoints == 0 then
                waypointIndex, selectedWaypoint = 1, nil
            else
                if waypointIndex > index then waypointIndex = waypointIndex - 1 end
                waypointIndex = math.min(waypointIndex, #waypoints)
                if selectedWaypoint == index then
                    selectedWaypoint = waypointIndex
                elseif selectedWaypoint and selectedWaypoint > index then
                    selectedWaypoint = selectedWaypoint - 1
                end
            end
            routeAction, echoTarget, echoActivatedAt = nil, nil, nil
            blockedCombat = false
            wallAnchor = nil
            lureCombatMembers, lureCorridor = {}, nil
            echoActivationPosition, echoSpawned = nil, false
            visitedEchoesForStand = {}
            if running and #waypoints == 0 then
                window:recursiveGetChildById('v2CavebotAutoExploringButton').onClick()
            end
            save()
            renderWaypoints()
            render()
            return true
        end
        row.onClick = function()
            selectedWaypoint = index
            waypointIndex = index
            if running then phase = 'gather' end
            routeAction, routeStuckSince = nil, nil
            blockedCombat = false
            wallAnchor = nil
            lureCombatMembers, lureCorridor = {}, nil
            echoTarget, echoActivatedAt = nil, nil
            echoActivationPosition, echoSpawned = nil, false
            visitedEchoesForStand = {}
            for rowIndex, item in ipairs(waypointRows) do
                item:setOn(rowIndex == selectedWaypoint)
            end
            save()
            renderWaypoints()
            render()
        end
        waypointRows[#waypointRows + 1] = row
    end
    window:recursiveGetChildById('v2CavebotEmptyWaypoints'):setVisible(#waypoints == 0)
    window:recursiveGetChildById('v2CavebotWaypointScroll'):setVisible(
        #waypoints * 22 > list:getHeight())
    if selectedWaypoint and waypointRows[selectedWaypoint] and
        list.ensureChildVisible then
        list:ensureChildVisible(waypointRows[selectedWaypoint])
    end
end

local function formatTime(milliseconds)
    local seconds = math.ceil(milliseconds / 1000)
    return string.format('%02d:%02d:%02d', math.floor(seconds / 3600),
        math.floor(seconds / 60) % 60, seconds % 60)
end

render = function()
    if routeController then return end
    if not window then return end
    local time = formatTime(remainingMs())
    window:recursiveGetChildById('v2CavebotTimerLabel'):setText(time)
    local percent = math.floor(remainingMs() * 100 / DAILY_LIMIT_MS)
    local bar = window:recursiveGetChildById('v2CavebotProgress')
    bar:setPercent(percent)
    local progressColor = percent > 50 and '#63d897' or
        percent > 20 and '#efbe61' or '#e76b69'
    bar:setBackgroundColor(progressColor)
    local percentLabel = window:recursiveGetChildById('v2CavebotPercentLabel')
    percentLabel:setText(percent .. '%')
    percentLabel:setColor(progressColor)
    local helperV2 = modules.game_baiakeros_helper_v2
    if helperV2 and helperV2.updateCavebotCompact then
        helperV2.updateCavebotCompact(time, percent, progressColor, running)
    end
    local button = window:recursiveGetChildById('v2CavebotAutoExploringButton')
    button:setText(running and 'Stop' or 'Start')
    button:setEnabled(g_game.isOnline() and serverStatusReady and not dialogBusy and
        (running or (remainingMs() > 0 and #waypoints>=2)))
    window:recursiveGetChildById('v2CavebotStatus'):setText(statusText)
    window:recursiveGetChildById('v2CavebotNodeButton'):setEnabled(not running and not dialogBusy and g_game.isOnline())
    window:recursiveGetChildById('v2CavebotStandButton'):setEnabled(not running and not dialogBusy and g_game.isOnline())
    window:recursiveGetChildById('v2CavebotUseButton'):setEnabled(not running and not dialogBusy and g_game.isOnline())
    window:recursiveGetChildById('v2CavebotHurUpButton'):setEnabled(not running and not dialogBusy and g_game.isOnline())
    window:recursiveGetChildById('v2CavebotHurDownButton'):setEnabled(not running and not dialogBusy and g_game.isOnline())
    window:recursiveGetChildById('v2CavebotStairButton'):setEnabled(not running and not dialogBusy and g_game.isOnline())
    window:recursiveGetChildById('v2CavebotRopeButton'):setEnabled(not running and not dialogBusy and g_game.isOnline())
    window:recursiveGetChildById('v2CavebotExaniTeraButton'):setEnabled(not running and not dialogBusy and g_game.isOnline())
    window:recursiveGetChildById('v2CavebotSaveRouteButton'):setEnabled(
        not running and not dialogBusy and characterKey ~= nil and #waypoints > 0)
    window:recursiveGetChildById('v2CavebotLoadRouteButton'):setEnabled(
        not running and not dialogBusy and characterKey ~= nil)
    window:recursiveGetChildById('v2CavebotClearRouteButton'):setEnabled(
        not running and not dialogBusy and characterKey ~= nil and #waypoints > 0)
    window:recursiveGetChildById('v2CavebotHuntStyleBox'):setEnabled(not running)
    local showDistance = options.huntStyle == 'lure'
    window:recursiveGetChildById('v2CavebotLureDistanceLabel'):setVisible(showDistance)
    window:recursiveGetChildById('v2CavebotLureDistanceIcon'):setVisible(showDistance)
    local distanceBox = window:recursiveGetChildById('v2CavebotLureDistanceBox')
    distanceBox:setVisible(showDistance)
    distanceBox:setEnabled(showDistance and g_game.isOnline())
end

local function validMonster(creature, playerPosition)
    if not creature or not creature:isMonster() or creature:isDead() then return false end
    local masterId = creature:getMasterId()
    if masterId and masterId > 0 then return false end
    local position = creature:getPosition()
    return position and position.z == playerPosition.z and creature:getHealthPercent() > 0
end

local function visibleMonsters(playerPosition)
    local mapPanel = modules.game_interface and modules.game_interface.getMapPanel()
    local spectators = mapPanel and mapPanel:getSpectators() or {}
    local monsters = {}
    for _, creature in ipairs(spectators) do
        if validMonster(creature, playerPosition) then
            monsters[#monsters + 1] = creature
        end
    end
    return monsters
end

local function nearbyCount(monsters, position, radius)
    local count = 0
    for _, monster in ipairs(monsters) do
        if distance(position, monster:getPosition()) <= radius then count = count + 1 end
    end
    return count
end

local function selectedLureSpell()
    local helper = modules.game_baiakeros_helper
    local state = helper and helper.getAttackState and helper.getAttackState()
    return state and state.shooter and helper.getSelectedExplorerLureSpell and
        helper.getSelectedExplorerLureSpell() or nil
end

local function freeAdjacentSqm(position, monsters)
    for _, direction in ipairs(DIRECTIONS) do
        local neighbor = {
            x = position.x + direction[1],
            y = position.y + direction[2],
            z = position.z
        }
        local tile = g_map.getTile(neighbor)
        if tile and tile:getGround() and tile:isWalkable() then
            local occupied = false
            for _, monster in ipairs(monsters) do
                if samePosition(neighbor, monster:getPosition()) then
                    occupied = true
                    break
                end
            end
            if not occupied then return true end
        end
    end
    return false
end

local function pullsDistantMonsters(spell, position, monsters)
    if not spell or spell.name == 'Challenge' then return false end
    if spell.name == 'Chivalrous Challenge' then
        return freeAdjacentSqm(position, monsters)
    end
    return true
end

local function routeCombatCount(monsters, position)
    if echoActivatedAt then
        return nearbyCount(monsters, echoActivationPosition or position,
            ECHO_COMBAT_RADIUS)
    end
    -- Stand clearance is independent of the selected lure spell. Chebyshev
    -- distance includes every diagonal in the 11 by 11 SQM combat area.
    return nearbyCount(monsters, position, 5)
end

local function lureCombatMonsters(monsters, position)
    -- Any nearby monster starts Distance combat, including along Nodes.
    if not next(lureCombatMembers) and nearbyCount(monsters, position, 5) == 0 then
        lureCorridor = nil
        return {}
    end
    if not lureCorridor then
        lureCorridor = BaiakLureMovement.corridor(lureRouteHistory, position)
        lurePatrolBack = true
    end
    local pack, current = {}, {}
    for _, monster in ipairs(monsters) do
        local id = monster.getId and monster:getId() or monster
        if distance(position, monster:getPosition()) <= 5 or lureCombatMembers[id] then
            pack[#pack + 1], current[id] = monster, true
        end
    end
    -- An engaged, still-visible monster stays in the pack if an escape step
    -- briefly puts it beyond five SQM. New distant monsters do not block routing.
    lureCombatMembers = current
    if #pack == 0 then lureCorridor = nil end
    return pack
end

local function rangedVocation(player)
    local vocation = tonumber(player:getVocation()) or 0
    return vocation == 2 or vocation == 3 or vocation == 4 or
        vocation == 12 or vocation == 13 or vocation == 14 or
        vocation == 6 or vocation == 7
end

local function tileIsSafe(position, allowStair, monsters, minimumDistance, explicitStair)
    local positionKey = key(position)
    if blocked[positionKey] then
        if blocked[positionKey] > g_clock.millis() then return false end
        blocked[positionKey] = nil
    end
    local tile = g_map.getTile(position)
    -- Closed doors and unknown ground are never opened or crossed automatically.
    if not tile or not tile:getGround() or not tile:isWalkable() then return false end
    local isStair = isFloorTransition(position, tile)
    if isStair and not allowStair and not explicitStair then return false end
    if isStair and not options.floors and not explicitStair then return false end
    if isStair and math.abs(position.z - originFloor) >= options.maxFloors and
        not returnStairs[positionKey] and not explicitStair then return false end
    for _, monster in ipairs(monsters or {}) do
        if distance(position, monster:getPosition()) < (minimumDistance or 1) then
            return false
        end
    end
    return true, isStair
end

local function openNeighbors(position, monsters, minimumDistance)
    local count = 0
    for _, direction in ipairs(DIRECTIONS) do
        local neighbor = {
            x = position.x + direction[1],
            y = position.y + direction[2],
            z = position.z
        }
        if tileIsSafe(neighbor, false, monsters, minimumDistance) then
            count = count + 1
        end
    end
    return count
end

local function searchStep(startPosition, goal, monsters, minimumDistance, allowStairs,
        allowGoalStair, routeAnchors)
    local queue = { { position = startPosition, depth = 0 } }
    local seen = { [key(startPosition)] = true }
    local best, bestScore
    local roam, roamScore
    local stair, stairScore
    local detour, detourScore
    local head = 1
    while head <= #queue and head <= MAX_SEARCH_NODES do
        local node = queue[head]
        head = head + 1
        if node.depth < MAX_SEARCH_DEPTH then
            for _, direction in ipairs(DIRECTIONS) do
                local nextPosition = {
                    x = node.position.x + direction[1],
                    y = node.position.y + direction[2],
                    z = node.position.z
                }
                local nextKey = key(nextPosition)
                if not seen[nextKey] then
                    seen[nextKey] = true
                    local safe, isStair = tileIsSafe(nextPosition,
                        allowStairs ~= false, monsters, minimumDistance,
                        allowGoalStair and goal and samePosition(nextPosition, goal))
                    if safe then
                        local first = node.first or direction[3]
                        local firstPosition = node.firstPosition or nextPosition
                        local depth = node.depth + 1
                        if goal and samePosition(nextPosition, goal) then
                            return first, firstPosition
                        end
                        -- A distant waypoint may be outside this visible search.
                        -- Rejoin a reachable point ahead on the recorded route
                        -- instead of waiting behind a player that can be bypassed.
                        if routeAnchors and routeAnchors[nextKey] and not isStair then
                            local score = routeAnchors[nextKey] * 1000 - depth * 10
                            if not detour or score > detourScore then
                                detour, detourScore = { first, firstPosition }, score
                            end
                        end
                        if not goal and not isStair then
                            local visits = visited[nextKey] or 0
                            local score = openNeighbors(nextPosition, monsters, minimumDistance) * 10 + depth * 2
                            if visits == 0 then
                                if not best or score > bestScore then
                                    best, bestScore = { first, firstPosition, nextPosition }, score
                                end
                            else
                                score = score - visits * 25
                                if not roam or score > roamScore then
                                    roam, roamScore = { first, firstPosition, nextPosition }, score
                                end
                            end
                        elseif not goal and isStair and options.floors then
                            local uses = stairVisits[nextKey] or 0
                            local score = 100 - uses * 100 - depth
                            if uses == 0 and (not stair or score > stairScore) then
                                stair, stairScore = { first, firstPosition, nextPosition }, score
                            end
                        end
                        if not isStair then
                            queue[#queue + 1] = {
                                position = nextPosition, depth = depth,
                                first = first, firstPosition = firstPosition
                            }
                        end
                    end
                end
            end
        end
    end
    if not goal then
        local selected = best or stair or roam
        if selected then return selected[1], selected[2], selected[3] end
    end
    if detour then return detour[1], detour[2] end
    return nil
end

local function beginFight(text)
    phase = 'fight'
    exploreGoal = nil
    fightEmptySince = nil
    lostGroupSince = nil
    nextGroupCheckAt = 0
    setStatus(text or 'Fighting gathered monsters')
end

local function setChaseEngaged(engaged)
    if engaged then
        if options.huntStyle ~= 'chase' and options.huntStyle ~= 'lure' then return end
        if previousChaseMode == nil then
            previousChaseMode = g_game.getChaseMode()
        end
        -- Native chase walks into the target and competes with Lure's escape
        -- steps. Keep the attack, but let Cavebot own movement in this style.
        controlledChaseMode = options.huntStyle == 'lure' and DontChase or ChaseOpponent
        if g_game.getChaseMode() ~= controlledChaseMode then
            g_game.setChaseMode(controlledChaseMode)
        end
    elseif previousChaseMode ~= nil then
        if g_game.isOnline() and g_game.getChaseMode() == controlledChaseMode then
            g_game.setChaseMode(previousChaseMode)
        end
        previousChaseMode, controlledChaseMode = nil, nil
    end
end

local function stop(reason)
    setChaseEngaged(false)
    if not running then
        if reason then setStatus(reason) end
        render()
        return
    end
    running = false
    if g_game.isOnline() then sendCavebotRequest('stop') end
    pendingStep = nil
    blockedCombat = false
    wallAnchor = nil
    lureCombatMembers, lureCorridor = {}, nil
    lastKiteDirection = nil
    exploreGoal = nil
    local controller = routeController
    if controller then
        options, waypoints = normalRouteBackup.options, normalRouteBackup.waypoints
        waypointIndex, selectedWaypoint = normalRouteBackup.index, normalRouteBackup.selected
        routeController, normalRouteBackup = nil, nil
    end
    save()
    setStatus(reason or 'Exploration stopped')
    renderWaypoints()
    render()
    if controller then controller.onStop(reason or 'Party route stopped') end
end

local function onCavebotOpcode(protocol, opcode, buffer)
    local ok, response = pcall(json.decode, buffer)
    if not ok or type(response) ~= 'table' then return end
    if response.action == 'ranking' then
        local helper = modules.game_baiakeros_helper_v2
        if helper and helper.updateCavebotRanking then
            helper.updateCavebotRanking(response.daily or {}, response.monthly or {})
        end
    elseif response.action == 'status' then
        serverStatusReady = true
        DAILY_LIMIT_MS=math.max(1,tonumber(response.limitSeconds) or 10800)*1000
        local remaining = math.max(0, math.min(DAILY_LIMIT_MS/1000, tonumber(response.remaining) or 0))
        usedMs = DAILY_LIMIT_MS - remaining * 1000
        lastChargeAt = g_clock.millis()
        if running and not routeController and response.active ~= true then
            stop(remaining > 0 and 'Cavebot session stopped by server' or 'Daily time exhausted')
        elseif not running then
            setStatus(remaining > 0 and 'Ready to explore' or 'Daily time exhausted')
        end
        render()
    end
end

function BaiakHelperExplorerV2.requestRanking()
    lastRankingRequestAt = g_clock.millis()
    sendCavebotRequest('ranking')
end

local function isOccupiedWalkableTile(tile)
    return tile and tile.hasCreatures and tile:hasCreatures() and
        tile:isWalkable(true)
end

local function walkOneStep(player, direction, destination, delay, explicitStair, kiteStep)
    if not player:canWalk() then return false end
    local tile = g_map.getTile(destination)
    local source = explicitStair and g_map.getTile(player:getPosition())
    local elevatedExit = explicitStair and source and source:hasElevation(3) and
        (not tile or not tile:getGround())
    if not elevatedExit and (not tile or (not explicitStair and not tile:getGround()) or not tile:isWalkable()) then
        if isOccupiedWalkableTile(tile) then
            setStatus('Passage occupied: waiting for it to clear')
        else
            blocked[key(destination)] = g_clock.millis() + BLOCKED_RETRY_MS
        end
        return false
    end
    if tile and isFloorTransition(destination, tile) then
        -- Normal route and combat movement must never enter a floor transition.
        -- Only the recorded stair action may authorize this particular step.
        if hasRoute() and not explicitStair then return false end
        stairVisits[key(destination)] = (stairVisits[key(destination)] or 0) + 1
    end
    pendingStep = destination
    pendingSince = g_clock.millis()
    pendingKite = kiteStep == true
    nextMoveAt = pendingSince + (delay or TICK_MS)
    if g_game.walk(direction) == false then
        pendingStep = nil
        return false
    end
    -- Use the client's normal prediction when supported, so running does not
    -- add a network round trip to every step. Never predict floor transitions.
    if pendingKite and GameAllowPreWalk and g_game.getFeature and
        g_game.getFeature(GameAllowPreWalk) and player.preWalk then
        player:preWalk(direction)
    end
    return true
end

local function rejectKiteStep(player)
    if not pendingStep or not pendingKite then return end
    -- A creature, a walk lock or a rejected packet is NOT a four-second wall.
    -- Exclude this step briefly, then let fresh map data decide again.
    local duration = player.getStepDuration and player:getStepDuration() or TICK_MS
    kiteRejected[key(pendingStep)] = g_clock.millis() + math.max(250, duration)
    pendingStep, pendingKite = nil, false
    nextMoveAt = g_clock.millis()
    setStatus('Distance: step cancelled; choosing another exit')
end

local function onExplorerCancelWalk(player)
    if running and player == g_game.getLocalPlayer() then rejectKiteStep(player) end
end

local function recordPosition(position)
    if samePosition(position, lastPosition) then return end
    local oldPosition = lastPosition
    lastPosition = position
    local positionKey = key(position)
    visited[positionKey] = (visited[positionKey] or 0) + 1
    if oldPosition and oldPosition.z ~= position.z then
        lureRouteHistory, lureCombatMembers, lureCorridor = { position }, {}, nil
    elseif hasRoute() and not next(lureCombatMembers) then
        -- Only route travel grows the history. Never record kiting as new route.
        lureRouteHistory[#lureRouteHistory + 1] = { x = position.x, y = position.y, z = position.z }
        if #lureRouteHistory > 60 then table.remove(lureRouteHistory, 1) end
    end
    if oldPosition and oldPosition.z ~= position.z then
        local waypoint = waypoints[waypointIndex]
        lastFloorTransition = {
            entry = pendingStep or oldPosition, exit = position, at = g_clock.millis(),
            kind = waypoint and (waypoint.kind == 'rope' or waypoint.kind == 'exani_tera') and 'rope' or
                waypoint and (waypoint.kind == 'hur_up' or waypoint.kind == 'hur_down') and waypoint.kind or 'stair',
            direction = waypoint and waypointDirection(waypoint.direction).walk or nil
        }
        if pendingStep then
            -- Remember the tile that actually changed floors even when the
            -- client's item data does not flag it as a stair or hole.
            learnedFloorChanges[key(pendingStep)] = true
            if pendingStep.x ~= position.x or pendingStep.y ~= position.y then
                learnedFloorChanges[key({ x = pendingStep.x, y = pendingStep.y,
                    z = position.z })] = true
            end
        end
        local departureTile = g_map.getTile(oldPosition)
        if position.z == oldPosition.z - 1 and departureTile and
            departureTile:hasElevation(3) then
            -- Walking off an elevated stair leaves its return hole directly
            -- above the departure SQM. Route around it on the new floor.
            learnedFloorChanges[key({ x = oldPosition.x, y = oldPosition.y,
                z = position.z })] = true
        end
        exploreGoal = nil
        if hasRoute() and not routeAction then
            -- A hole or a manual floor change may bypass a scripted stair.
            -- Keep the route active and look for its next waypoint on this floor.
            routeStuckSince = nil
            pendingStep = nil
            setStatus('Floor changed: finding a waypoint on floor ' .. position.z)
        end
        if not hasRoute() and math.abs(position.z - originFloor) > options.maxFloors then
            stop('Floor limit reached; exploration stopped')
            return
        end
        -- A newly reached stair is the only return route allowed at the floor limit.
        local arrivalTile = g_map.getTile(position)
        if arrivalTile and (arrivalTile:hasFloorChange() or arrivalTile:hasElevation(3)) then
            returnStairs[positionKey] = true
        end
        for _, direction in ipairs(DIRECTIONS) do
            local neighbor = { x = position.x + direction[1], y = position.y + direction[2], z = position.z }
            local tile = g_map.getTile(neighbor)
            if tile and (tile:hasFloorChange() or tile:hasElevation(3)) then
                returnStairs[key(neighbor)] = true
            end
        end
        trail = { position }
        if phase == 'return' then beginFight('Floor changed; fighting here') end
    elseif options.mode == 'moving' and phase == 'gather' then
        if #trail == 0 or not samePosition(trail[#trail], position) then
            trail[#trail + 1] = position
            if #trail > 80 then table.remove(trail, 1) end
        end
    elseif options.mode == 'moving' and phase == 'return' and
        #trail > 1 and samePosition(position, trail[#trail - 1]) then
        table.remove(trail)
    end
    pendingStep = nil
end

local function advanceWaypoint()
    if options.huntStyle ~= 'lure' then setChaseEngaged(false) end
    waypointIndex = waypointIndex % #waypoints + 1
    selectedWaypoint = waypointIndex
    phase = 'gather'
    fightEmptySince = nil
    routeAction = nil
    routeStuckSince = nil
    routeAttempts = 0
    blockedCombat = false
    wallAnchor = nil
    lureCombatMembers, lureCorridor = {}, nil
    lastKiteDirection = nil
    exploreGoal = nil
    echoTarget, echoActivatedAt = nil, nil
    echoActivationPosition, echoSpawned = nil, false
    visitedEchoesForStand = {}
    save()
    renderWaypoints()
end

local function skipWaypoint(reason, now)
    local skipped = waypointIndex
    advanceWaypoint()
    nextMoveAt = now + 400
    setStatus('Skipped waypoint ' .. skipped .. ': ' .. reason ..
        '; next ' .. waypointIndex .. '/' .. #waypoints)
end

local function closeClearRouteWindow()
    if clearRouteWindow then
        clearRouteWindow:destroy()
        clearRouteWindow = nil
    end
end

local function clearWaypoints()
    if running or dialogBusy or not characterKey then return end
    waypoints = {}
    waypointIndex, selectedWaypoint = 1, nil
    phase = 'gather'
    pendingStep, routeAction, routeStuckSince = nil, nil, nil
    routeAttempts = 0
    fightEmptySince = nil
    blockedCombat = false
    wallAnchor, lastKiteDirection = nil, nil
    lureCombatMembers, lureCorridor = {}, nil
    echoTarget, echoActivatedAt, echoActivationPosition = nil, nil, nil
    echoSpawned = false
    visitedEchoesForStand = {}
    resetWaypointDirection()
    save()
    renderWaypoints()
    setStatus('Waypoints cleared: record or load a new route')
    render()
end

local function resumeWaypointOnFloor(floor, now)
    for offset = 0, #waypoints - 1 do
        local index = (waypointIndex + offset - 1) % #waypoints + 1
        if waypoints[index].z == floor then
            if index ~= waypointIndex then
                waypointIndex = index - 1
                advanceWaypoint()
            end
            setStatus('Resuming waypoint ' .. waypointIndex .. '/' .. #waypoints ..
                ' on floor ' .. floor)
            return
        end
    end
    nextMoveAt = now + 600
    setStatus('Waiting for a route waypoint on floor ' .. floor)
end

local function findVisibleEcho(position)
    local nearest, nearestDistance
    for dx = -8, 8 do
        for dy = -6, 6 do
            local candidate = { x = position.x + dx, y = position.y + dy, z = position.z }
            local tile = g_map.getTile(candidate)
            if tile and tile.getItems then
                for _, item in ipairs(tile:getItems()) do
                    if item.getId and item:getId() == ECHO_ITEM_ID and
                        not visitedEchoesForStand[key(candidate)] then
                        local range = distance(position, candidate)
                        if not nearest or range < nearestDistance then
                            nearest, nearestDistance = candidate, range
                        end
                    end
                end
            end
        end
    end
    return nearest
end

local function routePathStep(position, goal, monsters, allowGoalStair)
    local routeAnchors
    if g_map.findPath then
        -- Allow decorative, non-pathable floor items; never allow solid blockers.
        local path = g_map.findPath(position, goal, 4000, 4)
        local direction = path and path[1]
        if direction then
            for _, option in ipairs(WAYPOINT_DIRECTIONS) do
                if option.walk == direction then
                    local nextPosition = {
                        x = position.x + option.x, y = position.y + option.y, z = position.z
                    }
                    if tileIsSafe(nextPosition, false, monsters, 1,
                            allowGoalStair and samePosition(nextPosition, goal)) then
                        return direction, nextPosition
                    end
                    break
                end
            end
        end
        -- Ignoring creatures supplies only route hints, never permission to
        -- walk through them. The visible search still checks each destination.
        local guide = g_map.findPath(position, goal, 4000, 4 + 16)
        if guide then
            routeAnchors = {}
            local p = { x = position.x, y = position.y, z = position.z }
            for index = 1, math.min(#guide, MAX_SEARCH_DEPTH) do
                for _, option in ipairs(WAYPOINT_DIRECTIONS) do
                    if option.walk == guide[index] then
                        p = { x = p.x + option.x, y = p.y + option.y, z = p.z }
                        routeAnchors[key(p)] = index
                        break
                    end
                end
            end
        end
    end
    return searchStep(position, goal, monsters, 1, false, allowGoalStair, routeAnchors)
end

local function routeBlockedByCreature(position, goal)
    if isOccupiedWalkableTile(g_map.getTile(goal)) then return true end
    if not g_map.findPath then return false end
    -- The normal route excludes creatures. A route that exists only when
    -- creatures are ignored means the same passage can open again.
    local path = g_map.findPath(position, goal, 4000, 4 + 16)
    if not path or #path == 0 then return false end
    local stepPosition = { x = position.x, y = position.y, z = position.z }
    for _, stepDirection in ipairs(path) do
        for _, direction in ipairs(WAYPOINT_DIRECTIONS) do
            if direction.walk == stepDirection then
                stepPosition = {
                    x = stepPosition.x + direction.x,
                    y = stepPosition.y + direction.y,
                    z = stepPosition.z
                }
                if isOccupiedWalkableTile(g_map.getTile(stepPosition)) then
                    return true
                end
                break
            end
        end
    end
    return false
end

local function useWaypointThing(position)
    local tile = g_map.getTile(position)
    if not tile then return false end
    local thing = tile:getTopUseThing()
    if tile.getItems then
        for _, item in ipairs(tile:getItems()) do
            if item:isForceUse() or (item.isDoor and item:isDoor()) then
                thing = item
                break
            end
        end
    end
    if not thing or not thing:isItem() then return false end
    local wasWalkable = tile:isWalkable()
    g_game.use(thing)
    return true, wasWalkable
end

local function findStandWallAnchor(base)
    local candidates = { base }
    for index = 1, 4 do
        local direction = DIRECTIONS[index]
        candidates[#candidates + 1] = {
            x = base.x + direction[1], y = base.y + direction[2], z = base.z
        }
    end
    for index, candidate in ipairs(candidates) do
        local tile = g_map.getTile(candidate)
        if tile and tile:getGround() and tile:isWalkable(index == 1) and
            not tile:hasFloorChange() and not tile:hasElevation(3) then
            for wallIndex = 1, 4 do
                local direction = DIRECTIONS[wallIndex]
                local wall = g_map.getTile({
                    x = candidate.x + direction[1],
                    y = candidate.y + direction[2], z = candidate.z
                })
                if wall and wall:getGround() and not wall:isWalkable(true) then
                    return {
                        position = candidate,
                        facing = DIRECTIONS[(wallIndex + 1) % 4 + 1][3]
                    }
                end
            end
        end
    end
end

local function kiteAroundTarget(player, position, monsters, obstacles)
    if #monsters == 0 then return end
    local attacking = g_game.getAttackingCreature()
    local target
    for _, monster in ipairs(monsters) do
        if monster == attacking or
            (attacking and monster.getId and attacking.getId and
                monster:getId() == attacking:getId()) then
            target = monster
            break
        end
    end
    if not target then
        for _, monster in ipairs(monsters) do
            if not target or distance(position, monster:getPosition()) <
                distance(position, target:getPosition()) then
                target = monster
            end
        end
    end
    local targetPosition = target:getPosition()
    local desiredDistance = options.lureDistance
    local patrolGoal = lureCorridor and (lurePatrolBack and lureCorridor.first or lureCorridor.last)
    if patrolGoal and distance(position, patrolGoal) <= 1 then
        lurePatrolBack = not lurePatrolBack
        patrolGoal = lurePatrolBack and lureCorridor.first or lureCorridor.last
    end
    if not player:canWalk() then
        setStatus('Distance: waiting for next step, attacking target')
        return
    end
    local obstaclePositions, occupied = {}, {}
    for _, monster in ipairs(obstacles or monsters) do
        local p = monster:getPosition()
        obstaclePositions[#obstaclePositions + 1], occupied[key(p)] = p, true
    end
    local now = g_clock.millis()
    local movementConfig = {
        walkable = function(p)
            return not occupied[key(p)] and tileIsSafe(p, false, nil, 1)
        end,
        rejected = function(p) return (kiteRejected[key(p)] or 0) > now end,
        wall = function(p)
            local tile = g_map.getTile(p)
            return not tile or not tile:getGround() or not tile:isWalkable(true) or isFloorTransition(p, tile)
        end,
        visits = function(p) return visited[key(p)] or 0 end,
        routeDistance = lureCorridor and lureCorridor.distance,
        patrolGoal = patrolGoal,
        lastDirection = lastKiteDirection
    }
    local choice = BaiakLureMovement.choose(position, targetPosition, obstaclePositions,
        desiredDistance, movementConfig)
    if choice and walkOneStep(player, choice.direction, choice.position, TICK_MS, false, true) then
        lastKiteDirection = choice.direction
        setStatus('Distance: kiting target at ' .. distance(choice.position, targetPosition) ..
            ' SQM; fighting along the recorded route')
    else
        setStatus(choice and 'Distance: waiting for movement; attacking target' or
            'Distance: all safe exits blocked; attacking target')
    end
end
local function followWaypoint(player, position, monsters, visibleCount, now)
    blockedCombat = false
    local waypoint = waypoints[waypointIndex]
    if not waypoint then return false end
    local direction = waypointDirection(waypoint.direction)
    local target = {
        x = waypoint.targetX,
        y = waypoint.targetY,
        z = waypoint.targetZ
    }
    local combatCount = routeCombatCount(monsters, position)
    local stair = waypoint.kind == 'stair'
    local rope = waypoint.kind == 'rope' or waypoint.kind == 'exani_tera'
    local transition = stair or rope or waypoint.kind == 'hur_up' or waypoint.kind == 'hur_down'
    local expectedFloor = (rope or waypoint.kind == 'hur_up') and waypoint.z - 1 or
        waypoint.kind == 'hur_down' and waypoint.z + 1 or nil
    if stair or rope then
        if options.huntStyle ~= 'lure' then
            phase = 'gather'
            setChaseEngaged(false)
        end
    end
    if routeAction then
        if (position.z ~= waypoint.z and (not expectedFloor or position.z == expectedFloor)) or
            (routeAction.kind == 'stand' and not routeAction.expectFloor and
                samePosition(position, target)) then
            advanceWaypoint()
            return true
        end
        if position.z ~= waypoint.z then
            setStatus('Unexpected floor: waiting for floor ' .. expectedFloor)
            return true
        end
        local elapsed = now - routeAction.issuedAt
        if routeAction.kind == 'stair_reset' then
            local base = { x = waypoint.x, y = waypoint.y, z = waypoint.z }
            if not samePosition(position, base) then
                routeAction = nil
            elseif elapsed >= 2600 then
                -- A centered stair that failed needs a fresh entry, not another
                -- walk into the tile the player is already standing on.
                for _, exit in ipairs(DIRECTIONS) do
                    local candidate = { x = base.x + exit[1], y = base.y + exit[2], z = base.z }
                    local tile = g_map.getTile(candidate)
                    if tile and not isFloorTransition(candidate, tile) and
                        walkOneStep(player, exit[3], candidate, 300) then
                        routeAction.issuedAt = now
                        break
                    end
                end
                setStatus('Stair: stepping back to retry waypoint ' .. waypointIndex)
            end
        elseif routeAction.kind == 'use' and elapsed >= 600 then
            local tile = g_map.getTile(target)
            if routeAction.wasWalkable or (tile and tile:isWalkable()) then
                advanceWaypoint()
            elseif routeAction.attempts >= 3 then
                skipWaypoint('Use did not open the tile', now)
            else
                routeAction = nil
                pendingStep = nil
            end
        elseif (routeAction.kind == 'stair_approach' or routeAction.kind == 'stand' or
            routeAction.kind == 'hur' or routeAction.kind == 'rope') and
            elapsed >= 2600 then
            if not transition and routeAction.kind == 'stand' and not routeAction.expectFloor and routeAttempts >= 3 then
                skipWaypoint('stair did not complete the floor change', now)
            else
                routeAction = routeAction.kind == 'stair_approach' and
                    { kind = 'stair_reset', issuedAt = now - 2600 } or nil
                pendingStep = nil
                nextMoveAt = now + 200
                setStatus('Retrying stair waypoint ' .. waypointIndex)
            end
        end
        return true
    end
    if position.z ~= waypoint.z then
        resumeWaypointOnFloor(position.z, now)
        return true
    end
    if options.huntStyle == 'lure' then
        local pack = lureCombatMonsters(monsters, position)
        if #pack > 0 then
            routeStuckSince = nil
            if phase ~= 'fight' then beginFight('Distance: clearing monsters before the waypoint') end
            kiteAroundTarget(player, position, pack, monsters)
            return true
        end
    end
    local base = { x = waypoint.x, y = waypoint.y, z = waypoint.z }
    if waypoint.kind == 'stand' and echoTarget then
        if samePosition(position, echoTarget) then
            visitedEchoesForStand[key(echoTarget)] = true
            echoActivationPosition = echoTarget
            echoTarget = nil
            echoActivatedAt = now
            echoSpawned = false
            setStatus('Echo Raid activated: waiting for monsters')
        else
            local walkDirection, nextPosition = routePathStep(position, echoTarget, monsters)
            if walkDirection then
                walkOneStep(player, walkDirection, nextPosition)
                setStatus('Moving to Echo Raid')
            elseif routeBlockedByCreature(position, echoTarget) then
                blockedCombat = visibleCount > 0
                setStatus('Echo Raid passage occupied: clearing monsters')
            else
                visitedEchoesForStand[key(echoTarget)] = true
                echoTarget = nil
                setStatus('Echo Raid unreachable: checking another')
            end
        end
        return true
    end
    if waypoint.kind == 'stand' and echoActivatedAt then
        local activeMonsters = nearbyCount(monsters,
            echoActivationPosition or position, ECHO_COMBAT_RADIUS)
        if activeMonsters > 0 or
            (not echoSpawned and now < echoActivatedAt + ECHO_SPAWN_WINDOW_MS) then
            setStatus('Echo Raid: clearing spawned monsters')
            return true
        end
        echoActivatedAt = nil
        echoActivationPosition, echoSpawned = nil, false
        echoTarget = findVisibleEcho(position) or findVisibleEcho(base)
        if echoTarget then
            setStatus('Another Echo Raid found')
            return true
        end
        if direction.value == 'center' and options.huntStyle ~= 'lure' then
            advanceWaypoint()
            return true
        end
    end
    if waypoint.kind == 'stand' and direction.value == 'center' and
        options.hugWall and options.huntStyle ~= 'lure' and
        not wallAnchor and samePosition(position, base) then
        wallAnchor = findStandWallAnchor(base)
    end
    local standPosition = wallAnchor and wallAnchor.position or base
    if not samePosition(position, standPosition) then
        local walkDirection, nextPosition = routePathStep(position, standPosition, monsters, stair)
        if walkDirection then
            routeStuckSince = nil
            setStatus(wallAnchor and 'Stand: moving against the wall' or string.format('%s %d/%d - %s',
                waypoint.kind == 'node' and 'Node' or 'Waypoint',
                waypointIndex, #waypoints,
                pullsDistantMonsters(selectedLureSpell(), position, monsters) and
                    ('pulling ' .. visibleCount .. ' monsters') or
                    'moving to waypoint'))
            local moveDelay = options.huntStyle == 'lure_stop' and
                combatCount > 0 and 200 or TICK_MS
            if waypoint.kind == 'node' and visibleCount > 0 and
                (options.huntStyle == 'lure_stop' or options.huntStyle == 'lure') then
                moveDelay = 250
            end
            if walkOneStep(player, walkDirection, nextPosition, moveDelay,
                    stair and samePosition(nextPosition, standPosition)) then
                local nextTile = g_map.getTile(nextPosition)
                if samePosition(nextPosition, standPosition) and nextTile and
                    isFloorTransition(nextPosition, nextTile) and not
                    (stair and direction.value ~= 'center' and nextTile:hasElevation(3) and
                        not nextTile:hasFloorChange()) then
                    -- Elevated stairs change floor on the directional exit,
                    -- rather than when reaching their top tile.
                    routeAction = { kind = 'stair_approach', issuedAt = now,
                        expectFloor = true }
                end
            end
        else
            if routeBlockedByCreature(position, standPosition) then
                routeStuckSince = nil
                -- Keep movement paused, but let the shooter clear monsters
                -- around the player while the occupied passage is blocked.
                blockedCombat = visibleCount > 0
                setStatus('Passage occupied: waiting for waypoint ' .. waypointIndex)
            else
                routeStuckSince = routeStuckSince or now
                if now - routeStuckSince > 2000 and not transition then
                    skipWaypoint('no accessible path', now)
                else
                    setStatus('Finding route to waypoint ' .. waypointIndex)
                end
            end
        end
        return true
    end
    routeStuckSince = nil
    if wallAnchor and not wallAnchor.turned then
        if player.getDirection and player:getDirection() ~= wallAnchor.facing then
            g_game.turn(wallAnchor.facing)
        end
        wallAnchor.turned = true
    end
    if waypoint.kind == 'node' then
        advanceWaypoint()
        return true
    end
    if rope then
        local helper = modules.game_baiakeros_helper
        local executed = helper and (waypoint.kind == 'rope' and
            helper.tryUseExplorerRope and helper.tryUseExplorerRope(target) or
            waypoint.kind == 'exani_tera' and helper.tryCastExplorerMagicRope and
                helper.tryCastExplorerMagicRope())
        if executed then
            routeAttempts = routeAttempts + 1
            routeAction = { kind = 'rope', issuedAt = now, expectFloor = true }
            setStatus('Waiting for confirmed ascent: ' .. (waypoint.kind == 'rope' and 'Rope' or 'Exani Tera'))
        else
            nextMoveAt = now + 300
            setStatus(waypoint.kind == 'rope' and 'Rope: waiting for rope and a usable rope spot' or
                'Exani Tera: waiting for mana, cooldown or spell availability')
        end
        return true
    end
    if waypoint.kind == 'stand' or stair or waypoint.kind == 'hur_up' or
        waypoint.kind == 'hur_down' then
        if waypoint.kind == 'stand' then
            if options.huntStyle ~= 'lure' then
                setChaseEngaged(options.huntStyle == 'chase' and combatCount > 0)
            end
        end
        if not stair and combatCount > 0 then
            if phase ~= 'fight' then
                beginFight(combatCount > nearbyCount(monsters, position, 2) and
                    'Stand: pulling distant monsters' or 'Stand: clearing nearby monsters')
            end
            return true
        end
        if waypoint.kind == 'stand' and options.echoRaids then
            -- Only an Echo that is visible now is actionable; do not wait
            -- for one to appear after the box has been cleared.
            echoTarget = findVisibleEcho(position)
            if echoTarget then
                setStatus('Echo Raid found')
                return true
            end
        end
        if waypoint.kind == 'hur_up' or waypoint.kind == 'hur_down' then
            local helper = modules.game_baiakeros_helper
            if not helper or not helper.tryCastExplorerLevitate then
                nextMoveAt = now + 300
                setStatus('Waiting for Levitate support')
            elseif helper.tryCastExplorerLevitate(
                    waypoint.kind == 'hur_up' and 'up' or 'down', direction.walk) then
                routeAttempts = routeAttempts + 1
                routeAction = { kind = 'hur', issuedAt = now, expectFloor = true }
                routeStuckSince = nil
                setStatus('Hur ' .. (waypoint.kind == 'hur_up' and 'Up' or 'Down') ..
                    ': ' .. direction.name)
            else
                routeStuckSince = routeStuckSince or now
                nextMoveAt = now + 300
                setStatus('Waiting to cast Hur ' ..
                    (waypoint.kind == 'hur_up' and 'Up' or 'Down'))
            end
            return true
        end
        if direction.value == 'center' then
            local tile = g_map.getTile(base)
            if stair and isFloorTransition(base, tile) then
                routeAction = { kind = 'stair_reset', issuedAt = now - 2600 }
                return true
            end
            advanceWaypoint()
            return true
        end
        local tile = g_map.getTile(target)
        if not stair and isFloorTransition(target, tile) then
            skipWaypoint('floor transition requires Stair', now)
            return true
        end
        if cardinalDirection(direction) and player:getDirection() ~= direction.walk then
            g_game.turn(direction.walk)
            nextMoveAt = now + 150
            setStatus((stair and 'Stair' or 'Stand') .. ': facing ' .. direction.name)
            return true
        end
        local baseTile = stair and g_map.getTile(base)
        local elevatedExit = stair and baseTile and baseTile:hasElevation(3) and
            (not tile or not tile:getGround())
        if not elevatedExit and (not tile or not tile:isWalkable()) then
            if isOccupiedWalkableTile(tile) then
                setStatus('Stand passage occupied: waiting for it to clear')
            else
                if stair then
                    nextMoveAt = now + 500
                    setStatus('Stair passage blocked: waiting to retry')
                else
                    skipWaypoint('Stand direction is blocked', now)
                end
            end
            return true
        end
        if walkOneStep(player, direction.walk, target, nil, stair) then
            routeAttempts = routeAttempts + 1
            routeAction = { kind = 'stand', issuedAt = now,
                expectFloor = stair or isFloorTransition(target, tile) }
            setStatus((stair and 'Stair' or 'Stand') .. ': stepping ' .. direction.name)
        end
        return true
    end
    local used, wasWalkable = useWaypointThing(target)
    if not used then
        skipWaypoint('Use has no usable map item', now)
        return true
    end
    routeAttempts = routeAttempts + 1
    routeAction = { kind = 'use', issuedAt = now,
        wasWalkable = wasWalkable, attempts = routeAttempts }
    setStatus('Use: ' .. direction.name .. ' from waypoint ' .. waypointIndex)
    return true
end

local function tick()
    tickEvent = nil
    local recordingPlayer = g_game.isOnline() and g_game.getLocalPlayer()
    if recordingPlayer then updateRecordingDirection(recordingPlayer:getPosition()) end
    if g_game.isOnline() and window and serverStatusReady then
        local highScorePage = window:recursiveGetChildById('v2CavebotHighScorePage')
        if highScorePage and highScorePage:isVisible() and
            g_clock.millis() - lastRankingRequestAt >= 10000 then
            BaiakHelperExplorerV2.requestRanking()
        end
    end
    if running then
        local now = g_clock.millis()
        if not routeController then
            usedMs = math.min(DAILY_LIMIT_MS, usedMs + math.max(0, now - lastChargeAt))
        end
        lastChargeAt = now
        if now - lastHeartbeatAt >= HEARTBEAT_MS then
            sendCavebotRequest('heartbeat')
            lastHeartbeatAt = now
        end
        if now - lastSaveAt >= 5000 then save() end
        if remainingMs() <= 0 then
            stop('Daily time exhausted')
        else
            local player = g_game.getLocalPlayer()
            if not g_game.isOnline() or not player or player:isDead() then
                stop('Exploration stopped on disconnect')
            elseif options.huntStyle ~= 'lure' and player:getHealthPercent() < 35 then
                stop('Low health: exploration stopped')
            elseif player:hasState(PlayerStates.Pz) then
                stop('Protection zone: exploration stopped')
            elseif (PlayerStates.PzBlock and player:hasState(PlayerStates.PzBlock)) or (player.getSkull and player:getSkull()~=(SkullNone or 0)) then
                stop('Combate PvP: Cavebot parado')
            elseif g_game.isFollowing() then
                stop('Following another character: exploration stopped')
            elseif player:isAutoWalking() then
                local combat=modules.game_baiakeros_helper
                if not combat.autoAttackEnabled then combat.setAutoAttackEnabled(true) end
                if not combat.attackRotationEnabled then combat.setAttackRotationEnabled(true) end
                -- A user click-to-walk may temporarily own movement. Keep the
                -- waypoint and resume routing once that walk finishes.
                pendingStep = nil
                routeAction = nil
                blockedCombat = false
                setStatus('Manual walk: resuming waypoint ' .. waypointIndex)
            else
                local combat=modules.game_baiakeros_helper
                if not combat.autoAttackEnabled then combat.setAutoAttackEnabled(true) end
                if not combat.attackRotationEnabled then combat.setAttackRotationEnabled(true) end
                local manualWalkAt = modules.game_interface.lastManualWalk or 0
                if manualWalkAt > lastManualWalk then
                    lastManualWalk = manualWalkAt
                    pendingStep = nil
                    nextMoveAt = now + 200
                    routeAction = nil
                    blockedCombat = false
                end
                local position = player:getPosition()
                -- Predicted positions are not server acknowledgement. Keep the
                -- pending step until confirmation or onCancelWalk; otherwise a
                -- rejected prediction looks like progress and stalls recovery.
                if not (pendingStep and pendingKite and player.isPreWalking and player:isPreWalking()) then
                    recordPosition(position)
                end
                if running then
                    if options.huntStyle == 'lure' then setChaseEngaged(true) end
                    local monsters = visibleMonsters(position)
                    local visibleCount = #monsters
                    if echoActivatedAt and nearbyCount(monsters,
                        echoActivationPosition or position, ECHO_COMBAT_RADIUS) > 0 then
                        echoSpawned = true
                        if phase ~= 'fight' then
                            beginFight('Echo Raid: clearing spawned monsters')
                        end
                    end
                    local closeCount = nearbyCount(monsters, position, 2)
                    local count = options.mode == 'wait' and visibleCount or
                        nearbyCount(monsters, position, 7)
                    if not hasRoute() and options.huntStyle ~= 'lure' and
                        options.mode ~= 'off' and
                        phase ~= 'fight' and player:getHealthPercent() < 60 and
                        #monsters > 0 then
                        beginFight('Health low: fighting early')
                    elseif not hasRoute() and options.mode == 'wait' and phase == 'gather' and
                        closeCount >= options.waitCount then
                        beginFight('Lure ready: fighting ' .. closeCount .. ' monsters')
                    elseif not hasRoute() and options.mode == 'wait' and phase == 'gather' and
                        count >= options.waitCount and now >= nextGroupCheckAt then
                        phase = 'approach'
                        exploreGoal = nil
                        lostGroupSince = nil
                        approachProgressAt = now
                        approachCloseCount = closeCount
                        setStatus('Group found: waiting for monsters to approach')
                    elseif not hasRoute() and options.mode == 'wait' and
                        phase == 'approach' then
                        if closeCount > approachCloseCount then
                            approachCloseCount = closeCount
                            approachProgressAt = now
                        end
                        if closeCount >= options.waitCount then
                            beginFight('Lure ready: fighting ' .. closeCount .. ' monsters')
                        elseif visibleCount < options.waitCount then
                            lostGroupSince = lostGroupSince or now
                            if now - lostGroupSince >= 750 then
                                phase = 'gather'
                                lostGroupSince = nil
                                setStatus('Group lost: exploring for more monsters')
                            end
                        elseif now - approachProgressAt >= 2500 then
                            phase = 'gather'
                            nextGroupCheckAt = now + 900
                            exploreGoal = nil
                            setStatus('Group cannot approach: repositioning')
                        else
                            lostGroupSince = nil
                        end
                    elseif not hasRoute() and options.mode == 'moving' and
                        phase == 'gather' and count >= options.movingCount then
                        phase = #trail > 1 and 'return' or 'fight'
                        exploreGoal = nil
                        setStatus(phase == 'return' and 'Lure ready: returning' or 'Lure ready: fighting')
                    end

                    if phase == 'fight' then
                        if (hasRoute() and routeCombatCount(monsters, position) or #monsters) == 0 then
                            fightEmptySince = fightEmptySince or now
                            if now - fightEmptySince >= 350 then
                                phase = hasRoute() and options.huntStyle == 'stop' and
                                    visibleCount > 0 and 'approach' or 'gather'
                                trail = { position }
                                fightEmptySince = nil
                            end
                        else
                            fightEmptySince = nil
                        end
                    end

                    local stepDuration = player.getStepDuration and player:getStepDuration() or TICK_MS
                    local ping = g_game.getPing and math.max(0, g_game.getPing()) or 0
                    local confirmationTimeout = pendingKite and math.max(250, stepDuration + ping * 2 + 100) or
                        math.max(900, stepDuration + 500)
                    -- A slow server/animation must finish before we declare a
                    -- rejection. Native canWalk includes walk locks and sync.
                    if pendingStep and now - pendingSince >= confirmationTimeout and
                        (not pendingKite or player:canWalk()) then
                        if pendingKite then
                            rejectKiteStep(player)
                        else
                            local pendingTile = g_map.getTile(pendingStep)
                            if not pendingTile or not pendingTile:isWalkable(true) then
                                blocked[key(pendingStep)] = now + BLOCKED_RETRY_MS
                            end
                            pendingStep = nil
                        end
                    end
                    if now >= nextMoveAt and not pendingStep then
                        local mobileFight = not hasRoute() and options.mode == 'wait' and phase == 'fight' and
                            visibleCount < options.waitCount
                        if hasRoute() and followWaypoint(player, position, monsters,
                            visibleCount, now) then
                            -- Nodes keep the recorded route moving; Stand owns
                            -- the planned combat stop and resumes after it clears.
                        elseif options.mode == 'wait' and phase == 'approach' then
                            setStatus('Waiting for ' .. closeCount .. '/' .. options.waitCount .. ' to approach')
                        elseif (phase == 'fight' and not mobileFight) or
                            (not hasRoute() and options.mode == 'off' and #monsters > 0) then
                            setStatus(echoActivatedAt and 'Echo Raid: fighting spawned monsters' or
                                options.huntStyle == 'chase' and 'Chase: pursuing one monster' or
                                'Fighting visible monsters')
                        elseif phase == 'return' then
                            if #trail <= 1 then
                                beginFight('Lure ready: fighting')
                            else
                                local previous = trail[#trail - 1]
                                local direction, nextPosition = searchStep(position, previous, monsters,
                                    rangedVocation(player) and 3 or 1)
                                if direction then
                                    walkOneStep(player, direction, nextPosition)
                                else
                                    beginFight('Return blocked: fighting here')
                                end
                            end
                        else
                            local minimumDistance = options.mode == 'moving' and
                                (rangedVocation(player) and 3 or 2) or 1
                            if samePosition(position, exploreGoal) then exploreGoal = nil end
                            local direction, nextPosition
                            if exploreGoal then
                                direction, nextPosition = searchStep(
                                    position, exploreGoal, monsters, minimumDistance)
                                if not direction then exploreGoal = nil end
                            end
                            if not exploreGoal then
                                direction, nextPosition, exploreGoal = searchStep(
                                    position, nil, monsters, minimumDistance)
                            end
                            if direction then
                                setStatus(mobileFight and
                                    ('Moving and fighting ' .. visibleCount .. '/' .. options.waitCount) or
                                    options.mode == 'moving' and
                                    ('Luring ' .. count .. '/' .. options.movingCount) or
                                    options.mode == 'wait' and
                                    ('Searching ' .. visibleCount .. '/' .. options.waitCount .. ' on screen') or
                                    'Exploring known tiles')
                                walkOneStep(player, direction, nextPosition)
                            elseif options.mode == 'moving' and #monsters > 0 then
                                beginFight('No safe route: fighting here')
                            elseif options.mode == 'wait' and #monsters > 0 then
                                if phase ~= 'fight' then
                                    beginFight('Path blocked: clearing visible monsters')
                                else
                                    setStatus('Clearing monsters blocking the route')
                                end
                            else
                                stop('No accessible unexplored tiles or stairs')
                            end
                        end
                    end
                end
            end
        end
    end
    render()
    tickEvent = scheduleEvent(tick, TICK_MS)
end

local function start()
    if running then stop() return end
    if not routeController and PartyHuntV2 and PartyHuntV2.isFollowing() then
        setStatus('Stop Party Hunt before starting Cavebot')
        return
    end
    if dialogBusy then return end
    if not g_game.isOnline() then return end
    if #waypoints<2 then
        setStatus('Adicione pelo menos 2 waypoints para iniciar')
        render()
        return
    end
    if not routeController and not serverStatusReady then setStatus('Waiting for server time') render() return end
    if remainingMs() <= 0 then setStatus('Daily time exhausted') render() return end
    local player = g_game.getLocalPlayer()
    if not player or player:isDead() or player:hasState(PlayerStates.Pz) then
        setStatus('Leave the protection zone to explore')
        return
    end
    local position = player:getPosition()
    if not position then return end
    local combat = modules.game_baiakeros_helper
    combat.setAutoAttackEnabled(true)
    combat.setAttackRotationEnabled(true)
    running = true
    sendCavebotRequest('start', { waypoints = #waypoints })
    previousChaseMode, controlledChaseMode = nil, nil
    if options.huntStyle == 'lure' then setChaseEngaged(true) end
    phase = 'gather'
    originFloor = position.z
    lastFloorTransition = nil
    lastPosition = position
    pendingStep = nil
    pendingKite, kiteRejected = false, {}
    nextMoveAt = 0
    lastChargeAt = g_clock.millis()
    lastHeartbeatAt = lastChargeAt
    lastManualWalk = modules.game_interface.lastManualWalk or 0
    fightEmptySince = nil
    lostGroupSince = nil
    waypointIndex = math.max(1, math.min(waypointIndex, #waypoints))
    if hasRoute() then selectedWaypoint = waypointIndex end
    routeAction = nil
    routeStuckSince = nil
    routeAttempts = 0
    blockedCombat = false
    wallAnchor = nil
    lureCombatMembers, lastKiteDirection, lureCorridor = {}, nil, nil
    lureRouteHistory, lureCorridor = { { x = position.x, y = position.y, z = position.z } }, nil
    echoTarget, echoActivatedAt = nil, nil
    echoActivationPosition, echoSpawned = nil, false
    visitedEchoesForStand = {}
    approachProgressAt = 0
    approachCloseCount = 0
    nextGroupCheckAt = 0
    visited = { [key(position)] = 1 }
    blocked = {}
    trail = { position }
    stairVisits = {}
    returnStairs = {}
    exploreGoal = nil
    renderWaypoints()
    setStatus('Following waypoint ' .. waypointIndex)
    render()
    local helperV2 = modules.game_baiakeros_helper_v2
    if not routeController and helperV2 and helperV2.detachCavebot then helperV2.detachCavebot() end
end

function BaiakHelperExplorerV2.copyRoute()
    local source = normalRouteBackup and normalRouteBackup.waypoints or waypoints
    return { version = 1, waypoints = normalizedWaypoints(source) }
end

function BaiakHelperExplorerV2.replaceRoute(route)
    if running or type(route) ~= 'table' then return false end
    waypoints = normalizedWaypoints(route.waypoints)
    waypointIndex, selectedWaypoint = 1, #waypoints > 0 and 1 or nil
    save()
    renderWaypoints()
    render()
    return true
end

function BaiakHelperExplorerV2.startPartyRoute(route, controller)
    if running or type(route) ~= 'table' or type(controller) ~= 'table' then return false end
    local partyWaypoints = normalizedWaypoints(route.waypoints)
    if #partyWaypoints == 0 then return false end
    normalRouteBackup = { options = options, waypoints = waypoints,
        index = waypointIndex, selected = selectedWaypoint }
    routeController = controller
    options = { floors = false, maxFloors = 1, mode = 'off', waitCount = 3,
        movingCount = 4, echoRaids = false, hugWall = false,
        huntStyle = 'lure_stop', lureDistance = 2 }
    waypoints, waypointIndex, selectedWaypoint = partyWaypoints, 1, 1
    start()
    if not running then
        options, waypoints = normalRouteBackup.options, normalRouteBackup.waypoints
        waypointIndex, selectedWaypoint = normalRouteBackup.index, normalRouteBackup.selected
        routeController, normalRouteBackup = nil, nil
    end
    return running
end

function BaiakHelperExplorerV2.stopPartyRoute(reason)
    if routeController then stop(reason) end
end

function BaiakHelperExplorerV2.getRouteState()
    return { active = running, owner = routeController and 'party' or 'cavebot',
        phase = (phase == 'fight' or blockedCombat) and 'fight' or 'travel',
        waypoint = waypointIndex, status = statusText,
        transition = lastFloorTransition and g_clock.millis() - lastFloorTransition.at < 15000 and lastFloorTransition or nil }
end

function BaiakHelperExplorerV2.isSafeMovementTile(position)
    return not isFloorTransition(position, g_map.getTile(position))
end

function isAutoExplorerActive()
    return running and not routeController
end

BaiakHelperExplorerV2.isAutoExplorerActive = isAutoExplorerActive

-- Keep combat owned by the running session, rather than by recent user input
-- or movement. Expired quota and Party Hunt routes do not grant this lease.
function BaiakHelperExplorerV2.isCombatAutomationActive()
    return g_game.isOnline() and running and not routeController and remainingMs() > 0
end

function shouldHoldExplorerAttack()
    if routeController then return false end
    if options.huntStyle == 'chase' or options.huntStyle == 'lure' then return false end
    return running and (hasRoute() or options.mode ~= 'off') and
        phase ~= 'fight' and not blockedCombat
end

function preferAreaExplorerAttack()
    if options.huntStyle == 'chase' then return false end
    if options.huntStyle == 'lure' then return running and hasRoute() end
    return running and (hasRoute() or options.mode ~= 'off') and
        (phase == 'fight' or blockedCombat)
end

function isSingleTargetExplorerHunt()
    return running and hasRoute() and options.huntStyle == 'chase' and
        waypoints[waypointIndex].kind ~= 'stair'
end

function BaiakHelperExplorerV2.onGameStart()
    if not g_game.isOnline() then return end
    learnedFloorChanges = {}
    resetWaypointDirection()
    characterKey = configKey()
    local saved = g_settings.getNode(characterKey) or {}
    usedMs = 0
    serverStatusReady = false
    options.floors = false
    options.maxFloors = math.max(1, math.min(5, tonumber(saved.maxFloors) or 1))
    options.mode = 'off'
    options.waitCount = math.max(2, math.min(8, tonumber(saved.waitCount) or 3))
    options.movingCount = math.max(2, math.min(8, tonumber(saved.movingCount) or 4))
    options.echoRaids = saved.echoRaids == true
    options.hugWall = saved.hugWall == true
    options.huntStyle = validHuntStyle(saved.huntStyle)
    options.lureDistance = validLureDistance(saved.lureDistance)
    waypoints = normalizedWaypoints(saved.waypoints)
    legacySavedRoutes = type(saved.savedRoutes) == 'table' and saved.savedRoutes or {}
    waypointIndex = math.max(1, math.min(#waypoints, tonumber(saved.waypointIndex) or 1))
    selectedWaypoint = #waypoints > 0 and waypointIndex or nil
    routeAction = nil
    blockedCombat = false
    wallAnchor = nil
    lureCombatMembers, lastKiteDirection, lureCorridor = {}, nil, nil
    echoTarget, echoActivatedAt = nil, nil
    echoActivationPosition, echoSpawned = nil, false
    visitedEchoesForStand = {}
    syncing = true
    window:recursiveGetChildById('v2CavebotEchoRaidsBox'):setChecked(options.echoRaids)
    window:recursiveGetChildById('v2CavebotHugWallBox'):setChecked(options.hugWall)
    window:recursiveGetChildById('v2CavebotHuntStyleBox'):
        setCurrentOptionByData(options.huntStyle, true)
    window:recursiveGetChildById('v2CavebotLureDistanceBox'):
        setCurrentOptionByData(options.lureDistance, true)
    window:recursiveGetChildById('v2CavebotDirectionBox'):setCurrentOptionByData(selectedDirection, true)
    syncing = false
    renderWaypoints()
    setStatus('Waiting for server time')
    render()
    sendCavebotRequest('status')
    BaiakHelperExplorerV2.requestRanking()
end

function BaiakHelperExplorerV2.onGameEnd()
    closeClearRouteWindow()
    stop('Exploration stopped on disconnect')
    characterKey = nil
    serverStatusReady = false
    render()
end

function BaiakHelperExplorerV2.init(helperWindow)
    -- Keep widget lookups anchored to the panel while it changes parents.
    window = helperWindow:recursiveGetChildById('cavebotPanel')
    ProtocolGame.registerExtendedOpcode(CAVEBOT_OPCODE, onCavebotOpcode)
    if LocalPlayer then connect(LocalPlayer, { onCancelWalk = onExplorerCancelWalk }) end
    local directionBox = window:recursiveGetChildById('v2CavebotDirectionBox')
    for _, direction in ipairs(WAYPOINT_DIRECTIONS) do
        directionBox:addOption(direction.name, direction.value)
    end
    directionBox:setCurrentOptionByData(selectedDirection, true)
    directionBox.onOptionChange = function(_, _, value)
        if value then
            selectedDirection = waypointDirection(value).value
            local player = g_game.getLocalPlayer()
            local position = player and player:getPosition()
            directionSelectionPosition = selectedDirection ~= 'center' and position and
                { x = position.x, y = position.y, z = position.z } or nil
        end
    end
    local huntStyleBox = window:recursiveGetChildById('v2CavebotHuntStyleBox')
    for _, style in ipairs(HUNT_STYLES) do
        huntStyleBox:addOption(style.name, style.value)
    end
    huntStyleBox:setCurrentOptionByData(options.huntStyle, true)
    huntStyleBox.onOptionChange = function(_, _, value)
        if syncing or running then return end
        options.huntStyle = validHuntStyle(value)
        save()
        render()
    end
    local lureDistanceBox = window:recursiveGetChildById('v2CavebotLureDistanceBox')
    for sqm = 1, 4 do lureDistanceBox:addOption(tostring(sqm), sqm) end
    lureDistanceBox:setCurrentOptionByData(options.lureDistance, true)
    lureDistanceBox.onOptionChange = function(_, _, value)
        if syncing then return end
        options.lureDistance = validLureDistance(value)
        save()
    end
    local function addWaypoint(kind)
        if running or not g_game.isOnline() then return end
        local player = g_game.getLocalPlayer()
        local position = player and player:getPosition()
        if not position then return end
        if #waypoints >= 200 then
            setStatus('Route limit: 200 waypoints')
            return
        end
        local direction = (kind == 'node' or kind == 'exani_tera') and WAYPOINT_DIRECTIONS[1] or
            waypointDirection(selectedDirection)
        if (kind == 'hur_up' or kind == 'hur_down') and
            not cardinalDirection(direction) then
            setStatus('Hur Up/Down requires North, East, South or West')
            render()
            return
        end
        local insertAt = selectedWaypoint and
            math.min(selectedWaypoint + 1, #waypoints + 1) or #waypoints + 1
        table.insert(waypoints, insertAt, {
            kind = kind, x = position.x, y = position.y, z = position.z,
            direction = direction.value,
            targetX = position.x + direction.x,
            targetY = position.y + direction.y,
            targetZ = position.z
        })
        selectedWaypoint = insertAt
        waypointIndex = insertAt
        resetWaypointDirection()
        save()
        renderWaypoints()
        render()
    end
    window:recursiveGetChildById('v2CavebotNodeButton').onClick = function()
        addWaypoint('node')
    end
    window:recursiveGetChildById('v2CavebotStandButton').onClick = function()
        addWaypoint('stand')
    end
    window:recursiveGetChildById('v2CavebotUseButton').onClick = function()
        addWaypoint('use')
    end
    window:recursiveGetChildById('v2CavebotHurUpButton').onClick = function()
        addWaypoint('hur_up')
    end
    window:recursiveGetChildById('v2CavebotHurDownButton').onClick = function()
        addWaypoint('hur_down')
    end
    window:recursiveGetChildById('v2CavebotStairButton').onClick = function()
        addWaypoint('stair')
    end
    window:recursiveGetChildById('v2CavebotRopeButton').onClick = function()
        addWaypoint('rope')
    end
    window:recursiveGetChildById('v2CavebotExaniTeraButton').onClick = function()
        addWaypoint('exani_tera')
    end
    local function chooseRouteFile(saveDialog, onChosen)
        if not g_platform.startJsonFileDialog or not g_platform.isJsonFileDialogPending or
            not g_platform.takeJsonFileDialogResult then
            setStatus('Update and restart the client to Save/Load routes')
            return
        end
        if dialogBusy or not g_platform.startJsonFileDialog(saveDialog) then
            setStatus('File dialog unavailable')
            return
        end
        dialogBusy = true
        local openedFor = characterKey
        setStatus(saveDialog and 'Choose a filename; game remains active' or
            'Choose a route; game remains active')
        render()
        local function checkDialog()
            dialogPollEvent = nil
            if g_platform.isJsonFileDialogPending() then
                dialogPollEvent = scheduleEvent(checkDialog, 100)
                return
            end
            local path = g_platform.takeJsonFileDialogResult()
            dialogBusy = false
            if characterKey ~= openedFor or not window then return end
            if path and path ~= '' then
                onChosen(path)
            else
                setStatus('Route selection canceled')
            end
            render()
        end
        dialogPollEvent = scheduleEvent(checkDialog, 100)
    end
    window:recursiveGetChildById('v2CavebotSaveRouteButton').onClick = function()
        if running or not characterKey or #waypoints == 0 then return end
        chooseRouteFile(true, function(path)
            local encoded, contents = pcall(json.encode,
                { version = 1, waypoints = normalizedWaypoints(waypoints),
                    huntStyle = options.huntStyle,
                    lureDistance = options.lureDistance })
            if not encoded or not g_platform.writeUserFile(path, contents) then
                setStatus('Could not save route')
                return
            end
            setStatus('Saved: ' .. (path:match('[^/\\]+$') or path))
        end)
    end
    window:recursiveGetChildById('v2CavebotLoadRouteButton').onClick = function()
        if running or not characterKey then return end
        chooseRouteFile(false, function(path)
            local contents = g_platform.readUserFile(path)
            local decoded, route = pcall(json.decode, contents)
            if not decoded or type(route) ~= 'table' or route.version ~= 1 or
                type(route.waypoints) ~= 'table' then
                setStatus('Invalid Cavebot route file')
                return
            end
            waypoints = normalizedWaypoints(route.waypoints)
            if route.huntStyle then
                options.huntStyle = validHuntStyle(route.huntStyle)
                huntStyleBox:setCurrentOptionByData(options.huntStyle, true)
            end
            if route.lureDistance then
                options.lureDistance = validLureDistance(route.lureDistance)
                lureDistanceBox:setCurrentOptionByData(options.lureDistance, true)
            end
            selectedWaypoint = #waypoints > 0 and 1 or nil
            waypointIndex = 1
            routeAction = nil
            blockedCombat = false
            wallAnchor = nil
            lureCombatMembers, lastKiteDirection, lureCorridor = {}, nil, nil
            echoTarget, echoActivatedAt = nil, nil
            echoActivationPosition, echoSpawned = nil, false
            visitedEchoesForStand = {}
            save()
            renderWaypoints()
            setStatus('Loaded: ' .. (path:match('[^/\\]+$') or path))
        end)
    end
    window:recursiveGetChildById('v2CavebotClearRouteButton').onClick = function()
        if running or dialogBusy or not characterKey or #waypoints == 0 then return end
        closeClearRouteWindow()
        local openedFor = characterKey
        local confirm = function()
            closeClearRouteWindow()
            if characterKey == openedFor then clearWaypoints() end
        end
        clearRouteWindow = displayGeneralBox('Clear Waypoints',
            'Clear all waypoints from this list? Saved JSON files will be kept.', {
                { text = 'Clear', callback = confirm },
                { text = 'Cancel', callback = closeClearRouteWindow },
                anchor = AnchorHorizontalCenter
            }, confirm, closeClearRouteWindow)
    end
    window:recursiveGetChildById('v2CavebotAutoExploringButton').onClick = start
    window:recursiveGetChildById('v2CavebotEchoRaidsBox').onCheckChange = function(_, checked)
        if syncing then return end
        options.echoRaids = checked == true
        save()
    end
    window:recursiveGetChildById('v2CavebotHugWallBox').onCheckChange = function(_, checked)
        if syncing then return end
        options.hugWall = checked == true
        wallAnchor = nil
        save()
    end
    tickEvent = scheduleEvent(tick, TICK_MS)
end

function BaiakHelperExplorerV2.terminate()
    closeClearRouteWindow()
    if dialogPollEvent then removeEvent(dialogPollEvent) dialogPollEvent = nil end
    ProtocolGame.unregisterExtendedOpcode(CAVEBOT_OPCODE)
    if LocalPlayer then disconnect(LocalPlayer, { onCancelWalk = onExplorerCancelWalk }) end
    if tickEvent then removeEvent(tickEvent) tickEvent = nil end
    stop()
    window = nil
end
