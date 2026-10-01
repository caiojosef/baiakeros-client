PartyHuntV2 = {}
local Hunt = PartyHuntV2
local OPCODE, TICK = 93, 100
local panel, floating, tickEvent, dialogEvent, clearDialog
local route, selected, direction = {}, nil, 'center'
local directionOrigin, key, dialogBusy, syncing
local running, pendingStart, ready = false, false, false
local pendingStartAt = 0
local snapshot, lastStatusAt, lastHeartbeatAt = {}, 0, 0
local followDistance, avoidDistance = 2, 2
local pendingStep, pendingOrigin, pendingSince, nextMoveAt = nil, nil, 0, 0
local placement, spellPlan, previousChase, compact = nil, nil, nil, false
local lastHealthPercent, escapeDamageUntil = nil, 0
local stateText = 'Join a party and choose the knight path guide'
local directions = {
    { 'Center', 'center', 0, 0 }, { 'North', 'north', 0, -1, North },
    { 'North East', 'north-east', 1, -1, NorthEast }, { 'East', 'east', 1, 0, East },
    { 'South East', 'south-east', 1, 1, SouthEast }, { 'South', 'south', 0, 1, South },
    { 'South West', 'south-west', -1, 1, SouthWest }, { 'West', 'west', -1, 0, West },
    { 'North West', 'north-west', -1, -1, NorthWest }
}
local kindNames = { node = 'Node', stand = 'Stand', stair = 'Stair', use = 'Use', hur_up = 'Hur Up', hur_down = 'Hur Down' }
local function get(id) return panel:recursiveGetChildById('party' .. id) end
local function send(action, extra)
    if not g_game.isOnline() then return end
    local protocol = g_game.getProtocolGame()
    if protocol then
        local request = extra or {}
        request.action = action
        protocol:sendExtendedOpcode(OPCODE, json.encode(request))
    end
end
local function remainingMs()
    return math.max(0, (tonumber(snapshot.remaining) or 0) * 1000 -
        (running and math.max(0, g_clock.millis() - lastStatusAt) or 0))
end
local function isGuide()
    local player = g_game.getLocalPlayer()
    return player and snapshot.guide and snapshot.guide.id == player:getId()
end
local function localRole()
    local player = g_game.getLocalPlayer()
    for _, member in ipairs(snapshot.members or {}) do
        if player and member.id == player:getId() then return member.role end
    end
end
local function save()
    if key then
        g_settings.setNode(key, { waypoints = route, followDistance = followDistance, avoidDistance = avoidDistance })
        g_settings.save()
    end
end
local function status(text) stateText = text end
local function normalize(source)
    if type(source) ~= 'table' or type(source.waypoints) ~= 'table' or #source.waypoints > 200 then return nil end
    local normalized = {}
    for _, waypoint in ipairs(source.waypoints) do
        if type(waypoint) ~= 'table' or not kindNames[waypoint.kind] then return nil end
        local x, y, z = tonumber(waypoint.x), tonumber(waypoint.y), tonumber(waypoint.z)
        if not x or not y or not z or x ~= math.floor(x) or y ~= math.floor(y) or
            z ~= math.floor(z) or x < 0 or y < 0 or x > 65535 or y > 65535 or z < 0 or z > 15 then return nil end
        local found
        for _, d in ipairs(directions) do if d[2] == (waypoint.direction or 'center') then found = d break end end
        if not found or ((waypoint.kind == 'hur_up' or waypoint.kind == 'hur_down') and
            (not found[5] or found[5] > West)) then return nil end
        normalized[#normalized + 1] = { kind = waypoint.kind, x = x, y = y, z = z, direction = found[2] }
    end
    return normalized
end
local function script() return { version = 1, waypoints = route } end
local function renderRoute()
    if not panel then return end
    local list = get('WaypointList')
    list:destroyChildren()
    for index, waypoint in ipairs(route) do
        local row = g_ui.createWidget('PartyHuntWaypointRow', list)
        row:setText(string.format('%02d %s %d,%d,%d %s', index, kindNames[waypoint.kind],
            waypoint.x, waypoint.y, waypoint.z, waypoint.direction))
        row:setOn(selected == index)
        row:setTooltip('Select this row to insert new waypoints immediately below it')
        row.onClick = function()
            if running then return end
            selected = index
            renderRoute()
        end
        local remove = row:recursiveGetChildById('removeWaypoint')
        remove:setEnabled(not running)
        remove.onClick = function()
            if running then return end
            table.remove(route, index)
            selected = #route > 0 and math.min(index, #route) or nil
            save()
            renderRoute()
        end
    end
    get('EmptyRoute'):setVisible(#route == 0)
    get('JsonEditor'):setText(json.encode(script()))
end
local function render()
    if not panel then return end
    local seconds = math.ceil(remainingMs() / 1000)
    local time = string.format('%02d:%02d:%02d', math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
    get('Time'):setText(ready and time or '--:--:--')
    get('Progress'):setPercent(math.floor(seconds * 100 / 3600))
    get('Start'):setText(running and 'Stop' or pendingStart and 'Starting...' or 'Start')
    local supported = localRole() == 'druid' or isGuide()
    get('Start'):setEnabled(running or (ready and not pendingStart and not dialogBusy and
        supported and not snapshot.tooMany and snapshot.guide and seconds > 0 and (not isGuide() or #route > 0)))
    get('Status'):setText(stateText)
    for _, id in ipairs({ 'Node', 'Stand', 'Use', 'Stair', 'HurUp', 'HurDown', 'Save', 'Load', 'Clear',
        'FromCavebot', 'ToCavebot', 'ApplyJson', 'Direction', 'JsonEditor' }) do
        get(id):setEnabled(not running and not pendingStart and not dialogBusy)
    end
    get('Save'):setEnabled(not running and not dialogBusy and #route > 0)
    get('Guide'):setEnabled(not running and not pendingStart and snapshot.canChooseGuide == true)
    if floating then
        local function f(id) return floating:recursiveGetChildById('partyFloat' .. id) end
        f('Time'):setText(ready and time or '--:--:--')
        f('Progress'):setPercent(math.floor(seconds * 100 / 3600))
        f('Status'):setText(stateText)
        f('Stop'):setEnabled(running)
        f('Guide'):setText(snapshot.guide and snapshot.guide.name or 'No guide')
    end
end
local function renderMembers()
    syncing = true
    local box = get('Guide')
    box:clearOptions()
    for index = 1, 4 do
        local member = (snapshot.members or {})[index]
        get('Member' .. index):setText(member and (index .. '. ' .. member.name ..
            (member.role == 'knight' and '  [EK]' or member.role == 'druid' and '  [ED]' or '  [Soon]')) or index .. '. ---')
        if member and member.role == 'knight' then box:addOption(member.name, member.guid) end
    end
    if snapshot.guide then box:setCurrentOptionByData(snapshot.guide.guid, true) end
    syncing = false
end
function Hunt.isActive() return running end
function Hunt.showFloating()
    if not floating then return end
    floating:show()
    floating:raise()
    if helperV2Window then helperV2Window:hide() end
    local legacy = modules.game_baiakeros_helper
    if legacy.setHelperButtonOn then legacy.setHelperButtonOn(false) end
    modules.game_walk.bindMovementKeysToWidget(floating)
    floating:focus()
end
function Hunt.minimize()
    compact = true
    floating:setHeight(168)
    floating:recursiveGetChildById('partyFloatDetails'):hide()
    floating:recursiveGetChildById('partyFloatMinimize'):hide()
    floating:recursiveGetChildById('partyFloatExpand'):show()
end
function Hunt.expand()
    compact = false
    floating:setHeight(242)
    floating:recursiveGetChildById('partyFloatDetails'):show()
    floating:recursiveGetChildById('partyFloatMinimize'):show()
    floating:recursiveGetChildById('partyFloatExpand'):hide()
end
function Hunt.openHelper()
    if not running then floating:hide() end
    modules.game_baiakeros_helper_v2.showHelperV2Tab('party')
    modules.game_baiakeros_helper_v2.show()
end
function Hunt.closeFloating()
    if running then Hunt.minimize() else floating:hide() end
end
function Hunt.refresh() send('status') end

function Hunt.stop(reason, fromServer)
    local wasRunning = running or pendingStart
    running, pendingStart = false, false
    BaiakHelperExplorerV2.stopPartyRoute(reason)
    if previousChase ~= nil then
        if g_game.isOnline() and g_game.getChaseMode() == DontChase then g_game.setChaseMode(previousChase) end
        previousChase = nil
    end
    pendingStep, pendingOrigin, placement, spellPlan = nil, nil, nil, nil
    lastHealthPercent, escapeDamageUntil = nil, 0
    if wasRunning and not fromServer then send('stop') end
    status(reason or 'Party Hunt stopped')
    render()
end
local function acceptedStart()
    running, pendingStart = true, false
    lastHeartbeatAt, nextMoveAt = 0, 0
    if isGuide() then
        if not BaiakHelperExplorerV2.startPartyRoute(script(), {
            remainingMs = remainingMs,
            onStop = function(reason) if running then Hunt.stop(reason) end end
        }) then
            Hunt.stop('Could not start the knight route; stop Cavebot first')
            return
        end
    else
        lastHealthPercent = g_game.getLocalPlayer():getHealthPercent()
        previousChase = g_game.getChaseMode()
        g_game.setChaseMode(DontChase)
        modules.game_baiakeros_helper.setAutoAttackEnabled(true)
        modules.game_baiakeros_helper.setAttackRotationEnabled(true)
    end
    Hunt.showFloating()
end
local function onOpcode(_, _, buffer)
    local ok, response = pcall(json.decode, buffer)
    if not ok or type(response) ~= 'table' or response.action ~= 'status' then return end
    snapshot, lastStatusAt, ready = response, g_clock.millis(), true
    if response.active == true and pendingStart then acceptedStart() end
    if running and response.active ~= true then Hunt.stop(response.reason ~= '' and response.reason or 'Party Hunt stopped by server', true) end
    if pendingStart and response.active ~= true then
        pendingStart = false
        status(response.reason ~= '' and response.reason or 'Party Hunt request rejected')
    elseif not running then status(response.reason ~= '' and response.reason or 'Ready: start the knight route, then the druid') end
    renderMembers()
    render()
end
local function visibleMonsters(position)
    local result, positions = {}, {}
    for _, creature in ipairs(modules.game_interface.getMapPanel():getSpectators() or {}) do
        local p = creature:getPosition()
        if creature:isMonster() and not creature:isDead() and creature:getHealthPercent() > 0 and
            (not creature.getMasterId or creature:getMasterId() <= 0) and p and p.z == position.z then
            result[#result + 1], positions[#positions + 1] = creature, p
        end
    end
    return result, positions
end
local function safeTile(p, monsters, explicitStair)
    local tile = g_map.getTile(p)
    if not tile or not tile:getGround() or not tile:isWalkable() then return false end
    if not explicitStair and not BaiakHelperExplorerV2.isSafeMovementTile(p) then return false end
    for _, monster in ipairs(monsters) do if PartyHuntMovement.same(p, monster) then return false end end
    return true
end
local function step(player, choice, monsters, explicitStair)
    if not choice or not choice.step or not player:canWalk() or g_clock.millis() < nextMoveAt then return end
    if not safeTile(choice.step, monsters, explicitStair) then return end
    local origin = player:getPosition()
    if g_game.walk(choice.direction) == false then return end
    pendingOrigin = origin and { x = origin.x, y = origin.y, z = origin.z }
    pendingStep, pendingSince = choice.step, g_clock.millis()
    nextMoveAt = pendingSince + 100
end
local function druidTick(player, position)
    if not snapshot.guide or not snapshot.guide.active then status('Waiting for the knight route') return end
    local leader = snapshot.guide.position
    local creature = g_map.getCreatureById and g_map.getCreatureById(snapshot.guide.id)
    if creature then leader = creature:getPosition() end
    if not leader or leader.z ~= position.z then
        placement, spellPlan = nil, nil
        local transition = snapshot.guide.transition
        if transition and transition.entry and transition.exit and transition.entry.z == position.z and
            leader and transition.exit.z == leader.z then
            local _, monsters = visibleMonsters(position)
            local entry = transition.entry
            if transition.kind ~= 'stair' and PartyHuntMovement.same(position, entry) then
                local helper = modules.game_baiakeros_helper
                helper.tryCastExplorerLevitate(transition.kind == 'hur_up' and 'up' or 'down', transition.direction)
                status('ED: following the guide with ' .. transition.kind)
            else
                local choice = PartyHuntMovement.toTile(position, entry, monsters, function(p)
                    return safeTile(p, monsters, transition.kind == 'stair' and PartyHuntMovement.same(p, entry))
                end)
                step(player, choice, monsters, choice and PartyHuntMovement.same(choice.step, entry))
                status('ED: following the guide through the staircase')
            end
        else status('Guide on another floor: waiting for a confirmed stair') end
        return
    end
    g_game.setChaseMode(DontChase)
    local _, monsters = visibleMonsters(position)
    local walkable = function(p) return safeTile(p, monsters) end
    if snapshot.guide.phase == 'fight' and #monsters > 0 and PartyHuntMovement.distance(position, leader) <= 7 then
        spellPlan = modules.game_baiakeros_helper.getPartyHuntSpellPlan()
        placement = PartyHuntMovement.combat(position, leader, monsters, spellPlan, avoidDistance, walkable,
            g_clock.millis() < escapeDamageUntil)
        if not placement then
            placement = { currentCoverage = PartyHuntMovement.coverage(spellPlan, position, leader, monsters), threatened = true }
            status('No free SQM: healing and attacking here')
            return
        end
        if placement.step then
            status(placement.threatened and 'ED: escaping attackers and facing the box' or
                'ED: positioning for ' .. (spellPlan and spellPlan.words or 'the box'))
            step(player, placement, monsters)
        else
            status('ED: facing the box - ' .. (spellPlan and spellPlan.words or 'configure Shooter in Attack'))
        end
    else
        placement, spellPlan = nil, nil
        local choice = PartyHuntMovement.follow(position, leader, followDistance, monsters, walkable)
        status('ED: following ' .. snapshot.guide.name .. ' at ' .. followDistance .. ' SQM')
        step(player, choice, monsters)
    end
end
function Hunt.prepareSpell(spell)
    if not running or isGuide() or localRole() ~= 'druid' then return true end
    if g_clock.millis() - lastStatusAt > 4000 then return false end
    if not spellPlan or not spellPlan.profile then return true end
    if not placement or spell.words ~= spellPlan.words then return false end
    local current = placement.currentCoverage
    if not current or current.boxCount < (spellPlan.minEnemies or 1) then return false end
    -- A usable wave may be fired during an escape. If a better footprint is
    -- reachable, reposition first while the independent healing loop continues.
    if placement.step and not placement.threatened and current.boxCount < placement.boxCount then return false end
    return true, current.facing
end
function Hunt.onSpellCast(spell)
    if running and not isGuide() then nextMoveAt = g_clock.millis() + 120 end
end
local function tick()
    tickEvent = nil
    if g_game.isOnline() then
        local player, now = g_game.getLocalPlayer(), g_clock.millis()
        local position = player and player:getPosition()
        if position and directionOrigin and not PartyHuntMovement.same(position, directionOrigin) then
            direction, directionOrigin = 'center', nil
            get('Direction'):setCurrentOptionByData('center', true)
        end
        if pendingStart and now - pendingStartAt >= 8000 then
            Hunt.stop('Start confirmation timed out; try again')
        end
        if running then
            if not player or player:isDead() then Hunt.stop('Party Hunt stopped on death')
            elseif remainingMs() <= 0 then Hunt.stop('Daily Party Hunt hour exhausted')
            elseif now - lastStatusAt > 8000 then Hunt.stop('Party Hunt server connection expired')
            else
                if now - lastHeartbeatAt >= 1000 then
                    local routeState = BaiakHelperExplorerV2.getRouteState()
                    local message = { phase = isGuide() and routeState.phase or 'travel' }
                    local transition = isGuide() and routeState.transition
                    if transition then
                        for _, coordinate in ipairs({ 'x', 'y', 'z' }) do
                            message['entry' .. coordinate:upper()] = transition.entry[coordinate]
                            message['exit' .. coordinate:upper()] = transition.exit[coordinate]
                        end
                        message.transitionKind, message.transitionDirection = transition.kind, transition.direction
                    end
                    send('heartbeat', message)
                    lastHeartbeatAt = now
                end
                if now - lastStatusAt <= 4000 then
                    if isGuide() then
                        status('EK: ' .. BaiakHelperExplorerV2.getRouteState().status)
                    elseif position then
                        local healthPercent = player:getHealthPercent()
                        if lastHealthPercent and healthPercent < lastHealthPercent then escapeDamageUntil = now + 600 end
                        lastHealthPercent = healthPercent
                        if pendingStep and (PartyHuntMovement.same(position, pendingStep) or
                            (pendingOrigin and not PartyHuntMovement.same(position, pendingOrigin)) or
                            now - pendingSince >= 1200) then pendingStep, pendingOrigin = nil, nil end
                        if not pendingStep then druidTick(player, position) end
                    end
                else status('Waiting for Party Hunt server status') end
            end
        elseif panel and panel:isVisible() and now - lastHeartbeatAt >= 3000 then
            send('status')
            lastHeartbeatAt = now
        end
    end
    render()
    tickEvent = scheduleEvent(tick, TICK)
end
local function loadScript(value)
    local normalized = normalize(value)
    if not normalized then status('Invalid JSON route: use Node, Stand, Stair, Use or Hur waypoints') return false end
    route, selected = normalized, #normalized > 0 and #normalized or nil
    save()
    renderRoute()
    render()
    return true
end
local function fileDialog(saving)
    if running or pendingStart or dialogBusy then return end
    if not g_platform.startJsonFileDialog or not g_platform.isJsonFileDialogPending or not g_platform.takeJsonFileDialogResult then status('Update and restart the client to Save/Load routes') return end
    if not g_platform.startJsonFileDialog(saving) then status('File dialog unavailable') return end
    dialogBusy = true
    local openedFor = key
    local function poll()
        dialogEvent = nil
        if g_platform.isJsonFileDialogPending() then dialogEvent = scheduleEvent(poll, 100) return end
        local path = g_platform.takeJsonFileDialogResult()
        dialogBusy = false
        if openedFor ~= key then return end
        if path and path ~= '' then
            if saving then
                status(g_platform.writeUserFile(path, json.encode(script())) and 'Party Hunt route saved' or 'Could not save route')
            else
                local contents = g_platform.readUserFile(path)
                local ok, value = pcall(json.decode, contents)
                if ok and loadScript(value) then status('Party Hunt route loaded') else status('Invalid route file') end
            end
        else status('File selection canceled') end
        render()
    end
    status('Choose a JSON file; the game and healing remain active')
    dialogEvent = scheduleEvent(poll, 100)
    render()
end
function Hunt.onGameStart()
    key = modules.game_baiakeros_helper.playerConfigPrefix() .. '_party_hunt_v1'
    local saved = g_settings.getNode(key) or {}
    route = normalize({ waypoints = saved.waypoints or {} }) or {}
    followDistance = math.max(1, math.min(4, tonumber(saved.followDistance) or 2))
    avoidDistance = math.max(1, math.min(4, tonumber(saved.avoidDistance) or 2))
    selected, ready = #route > 0 and #route or nil, false
    get('FollowDistance'):setCurrentOptionByData(followDistance, true)
    get('AvoidDistance'):setCurrentOptionByData(avoidDistance, true)
    renderRoute()
    Hunt.refresh()
end
function Hunt.onGameEnd()
    Hunt.stop('Party Hunt stopped on disconnect', true)
    key, ready, snapshot = nil, false, {}
    if floating then floating:hide() end
end
function Hunt.init(helperWindow)
    g_ui.importStyle('party_hunt')
    panel = g_ui.createWidget('BaiakerosPartyHuntPanel', helperWindow:recursiveGetChildById('partyHuntPage'))
    floating = g_ui.createWidget('BaiakerosPartyHuntFloat', rootWidget)
    ProtocolGame.registerExtendedOpcode(OPCODE, onOpcode)
    for _, d in ipairs(directions) do get('Direction'):addOption(d[1], d[2]) end
    get('Direction'):setCurrentOptionByData('center', true)
    get('Direction').onOptionChange = function(_, _, value)
        direction = value
        local player = g_game.getLocalPlayer()
        directionOrigin = player and player:getPosition()
    end
    for _, entry in ipairs({ { 'Node', 'node' }, { 'Stand', 'stand' }, { 'Use', 'use' },
        { 'Stair', 'stair' }, { 'HurUp', 'hur_up' }, { 'HurDown', 'hur_down' } }) do
        get(entry[1]).onClick = function()
            if running or pendingStart or #route >= 200 or not g_game.isOnline() then return end
            local player = g_game.getLocalPlayer()
            if not player then return end
            local p = player:getPosition()
            local chosen = entry[2] == 'node' and 'center' or direction
            local candidate = { kind = entry[2], x = p.x, y = p.y, z = p.z, direction = chosen }
            if not normalize({ waypoints = { candidate } }) then status('Hur requires a cardinal direction') return end
            local index = selected and math.min(selected + 1, #route + 1) or #route + 1
            table.insert(route, index, candidate)
            selected, direction, directionOrigin = index, 'center', nil
            get('Direction'):setCurrentOptionByData('center', true)
            save()
            renderRoute()
            render()
        end
    end
    get('Start').onClick = function()
        if running then Hunt.stop() return end
        if not ready or pendingStart or dialogBusy or remainingMs() <= 0 then return end
        if BaiakHelperExplorerV2.getRouteState().active then status('Stop Cavebot before starting Party Hunt') return end
        pendingStart = true
        pendingStartAt = g_clock.millis()
        send('start', { waypoints = #route })
        render()
    end
    get('Refresh').onClick = Hunt.refresh
    get('Guide').onOptionChange = function(_, _, value) if not syncing and value then send('guide', { guide = value }) end end
    for _, setting in ipairs({ { 'FollowDistance', 'follow' }, { 'AvoidDistance', 'avoid' } }) do
        local box = get(setting[1])
        for value = 1, 4 do box:addOption(value .. ' SQM', value) end
        box.onOptionChange = function(_, _, value)
            if setting[2] == 'follow' then followDistance = tonumber(value) or 2 else avoidDistance = tonumber(value) or 2 end
            save()
        end
    end
    get('FromCavebot').onClick = function() if not running then loadScript(BaiakHelperExplorerV2.copyRoute()) end end
    get('ToCavebot').onClick = function()
        status(BaiakHelperExplorerV2.replaceRoute(script()) and 'Route copied to Cavebot' or 'Stop Cavebot before copying')
        render()
    end
    get('ApplyJson').onClick = function()
        local text = get('JsonEditor'):getText()
        if running or #text > 100000 then return end
        local ok, value = pcall(json.decode, text)
        if ok and loadScript(value) then status('JSON waypoints applied') else status('Invalid JSON route') end
        render()
    end
    get('Save').onClick = function() fileDialog(true) end
    get('Load').onClick = function() fileDialog(false) end
    get('Clear').onClick = function()
        if running or pendingStart then return end
        clearDialog = displayGeneralBox('Clear Party Waypoints', 'Clear every waypoint in this Party Hunt route?', {
            { text = 'Clear', callback = function()
                if not running then loadScript({ waypoints = {} }) end
                if clearDialog then clearDialog:destroy() clearDialog = nil end
            end },
            { text = 'Cancel', callback = function() if clearDialog then clearDialog:destroy() clearDialog = nil end end },
            anchor = AnchorHorizontalCenter
        })
    end
    get('Float').onClick = Hunt.showFloating
    floating:recursiveGetChildById('partyFloatStop').onClick = function() Hunt.stop() end
    floating:recursiveGetChildById('partyFloatBack').onClick = Hunt.openHelper
    floating:recursiveGetChildById('partyFloatMinimize').onClick = Hunt.minimize
    floating:recursiveGetChildById('partyFloatExpand').onClick = Hunt.expand
    tickEvent = scheduleEvent(tick, TICK)
    renderRoute()
    render()
end
function Hunt.terminate()
    Hunt.onGameEnd()
    ProtocolGame.unregisterExtendedOpcode(OPCODE)
    if tickEvent then removeEvent(tickEvent) tickEvent = nil end
    if dialogEvent then removeEvent(dialogEvent) dialogEvent = nil end
    if clearDialog then clearDialog:destroy() clearDialog = nil end
    if floating then
        modules.game_walk.unbindMovementKeysFromWidget(floating)
        floating:destroy()
        floating = nil
    end
    if panel then panel:destroy() panel = nil end
end
