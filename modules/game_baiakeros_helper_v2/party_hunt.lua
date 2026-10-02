PartyHuntV2 = {}
local Hunt = PartyHuntV2
local OPCODE = 93
local panel, floating, tickEvent
local running, pendingStart, ready = false, false, false
local snapshot, lastStatusAt, lastRequestAt, pendingStartAt = {}, 0, 0, 0
local stateText = 'Aguardando dados da party do servidor...'
local previousCombat, lastTransition = nil, nil
local lastLeaderWalk
local updatingOptions = false
local function restoreCombat()
    if not previousCombat then return end
    local combat=modules.game_baiakeros_helper
    if combat.restorePartyCombatState then combat.restorePartyCombatState(previousCombat)
    else
        combat.setAutoAttackEnabled(previousCombat.auto)
        combat.setAttackRotationEnabled(previousCombat.shooter)
    end
    if not previousCombat.auto and g_game.isOnline() and g_game.cancelAttack then g_game.cancelAttack() end
    previousCombat=nil
end
local function get(id) return panel:recursiveGetChildById('party' .. id) end
local function send(action, options)
    if not g_game.isOnline() then return end
    local protocol = g_game.getProtocolGame()
    local data={action=action}
    if action=='options' then
        data.runThreshold,data.alwaysRun=options.runThreshold,options.alwaysRun
    end
    if action=='heartbeat' then
        local t=lastTransition
        if t and t.entry and t.exit and t.direction~=nil then
            data.transitionKind,data.transitionDirection=t.kind,t.direction
            data.entryX,data.entryY,data.entryZ=t.entry.x,t.entry.y,t.entry.z
            data.exitX,data.exitY,data.exitZ=t.exit.x,t.exit.y,t.exit.z
        end
    end
    if protocol then protocol:sendExtendedOpcode(OPCODE, json.encode(data)) end
end
local function isLeader()
    local player = g_game.getLocalPlayer()
    return player and snapshot.leader and snapshot.leader.id == player:getId()
end
local function remaining()
    return math.max(0, (tonumber(snapshot.remaining) or 0) -
        (running and math.floor((g_clock.millis() - lastStatusAt) / 1000) or 0))
end
local function cooldown()
    return math.max(0, (tonumber(snapshot.teleportRemaining) or 0) - math.floor((g_clock.millis() - lastStatusAt) / 1000))
end
local function render()
    if not panel then return end
    local seconds = remaining()
    local dailyLimit=math.max(1,tonumber(snapshot.limitSeconds) or 10800)
    local text = ready and string.format('%02d:%02d:%02d', math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60) or '--:--:--'
    local fresh = ready and g_clock.millis() - lastStatusAt <= 8000
    local control = fresh and snapshot.canControl == true and isLeader() and not snapshot.tooMany
    get('Time'):setText(text)
    get('Progress'):setPercent(math.min(100,math.floor(seconds * 100 / dailyLimit)))
    get('Start'):setText(running and isLeader() and 'Stop Party Hunt' or running and 'Following leader' or pendingStart and 'Starting...' or 'Start')
    get('Start'):setEnabled(control and not pendingStart and (running or seconds > 0))
    get('Float'):setEnabled(control)
    local options=snapshot.settings or {runThreshold=2,alwaysRun=false}
    updatingOptions=true
    get('RunThreshold'):setCurrentOptionByData(options.runThreshold, true)
    get('AlwaysRun'):setChecked(options.alwaysRun==true)
    updatingOptions=false
    local movementAllowed=ready and snapshot.canConfigureMovement==true and snapshot.vocation~=4
    get('RunThreshold'):setEnabled(fresh and movementAllowed and g_game.isOnline())
    get('AlwaysRun'):setEnabled(fresh and movementAllowed and g_game.isOnline())
    for _,id in ipairs({'ToleranceLabel','RunThreshold','AlwaysRun','OptionsSeparator','MovementHelp'})do
        if movementAllowed then get(id):show()else get(id):hide()end
    end
    if ready and snapshot.vocation==4 then get('KnightNotice'):show()else get('KnightNotice'):hide()end
    local wait = cooldown()
    get('Teleport'):setText(wait > 0 and string.format('Teleport to leader (%d:%02d)', math.floor(wait / 60), wait % 60) or 'Teleport to leader')
    get('Teleport'):setEnabled(control and snapshot.canTeleport == true and wait == 0)
    local attacking=#(snapshot.attackers or {})
    get('Warning'):setText(snapshot.tooMany and 'Funciona somente com ate 4 pessoas, incluindo o leader.' or
        (running and snapshot.vocation~=4 and attacking>=(options.runThreshold or 2) and 'Pressao alta: '..attacking..' monstros atacando voce.' or
        (ready and snapshot.leader and not isLeader() and 'Somente o leader pode iniciar e parar.' or ''))
        )
    local statusText = not ready and 'Aguardando dados da party do servidor...' or
        (not fresh and 'Sem resposta do servidor. Atualizando a party...' or stateText)
    get('Status'):setText(statusText)
    for index = 1, 4 do
        local member = (snapshot.members or {})[index]
        get('Member' .. index):setText(member and (index .. '. ' .. member.name .. (member.leader and ' [Leader]' or '')) or index .. '. ---')
    end
    if floating then
        local function f(id) return floating:recursiveGetChildById('partyFloat' .. id) end
        f('Time'):setText(text)
        f('Progress'):setPercent(math.min(100,math.floor(seconds * 100 / dailyLimit)))
        f('Status'):setText(statusText)
        f('Stop'):setEnabled(control and running)
        f('Guide'):setText(snapshot.leader and snapshot.leader.name .. ' [Leader]' or 'No leader')
        local roster={}
        for index=1,4 do
            local member=(snapshot.members or {})[index]
            roster[#roster+1]=member and (index..'. '..member.name..(member.leader and ' [Leader]' or '')) or index..'. ---'
        end
        f('Roster'):setText(table.concat(roster,'\n'))
        f('Stop'):setText(isLeader() and 'Stop Party Hunt' or 'Following leader')
    end
end
function Hunt.isActive() return running end
function Hunt.isFollowing() return running and snapshot.following==true and not isLeader() end
function Hunt.isChangingFloor()
    local player=g_game.getLocalPlayer()
    return Hunt.isFollowing() and player and snapshot.leader.position and
        player:getPosition().z~=snapshot.leader.position.z or false
end
function Hunt.getLeaderTarget()
    if not Hunt.isFollowing() or not snapshot.leader.targetId then return nil end
    return g_map.getCreatureById(snapshot.leader.targetId)
end
-- Attack, spells and healing remain entirely under Helper control.
function Hunt.prepareSpell(spell)
    if Hunt.isFollowing() and PartyFollower then return PartyFollower.prepareSpell(spell) end
    return true
end
function Hunt.onSpellCast(spell)
    if Hunt.isFollowing() and PartyFollower then PartyFollower.onSpellCast(spell) end
end
function Hunt.refresh() send('status') end
local function changeOptions()
    if updatingOptions or not ready or snapshot.canConfigureMovement~=true or snapshot.vocation==4 or
        g_clock.millis()-lastStatusAt>8000 then return end
    local selected=get('RunThreshold'):getCurrentOption()
    if not selected then return end
    send('options',{runThreshold=selected.data,alwaysRun=get('AlwaysRun'):isChecked()})
end
function Hunt.showFloating(automatic)
    if not floating or not running and not isLeader() then return end
    floating:show(); floating:raise()
    if helperV2Window then helperV2Window:hide() end
    local legacy = modules.game_baiakeros_helper
    if legacy.setHelperButtonOn then legacy.setHelperButtonOn(false) end
    modules.game_walk.bindMovementKeysToWidget(floating)
    if not automatic then floating:focus() end
end
function Hunt.minimize()
    floating:setHeight(270)
    floating:recursiveGetChildById('partyFloatDetails'):hide()
    floating:recursiveGetChildById('partyFloatMinimize'):hide()
    floating:recursiveGetChildById('partyFloatExpand'):show()
end
function Hunt.expand()
    floating:setHeight(350)
    floating:recursiveGetChildById('partyFloatDetails'):show()
    floating:recursiveGetChildById('partyFloatMinimize'):show()
    floating:recursiveGetChildById('partyFloatExpand'):hide()
end
function Hunt.openHelper()
    if floating then floating:hide() end
    modules.game_baiakeros_helper_v2.showHelperV2Tab('party')
    modules.game_baiakeros_helper_v2.show()
end
function Hunt.closeFloating()
    if running then Hunt.minimize() else floating:hide() end
end
function Hunt.stop(reason, fromServer)
    local wasActive = running or pendingStart
    running, pendingStart = false, false
    if PartyFollower then PartyFollower.reset() end
    restoreCombat()
    if floating then floating:hide() end
    if wasActive and not fromServer and isLeader() then send('stop') end
    stateText = reason or 'Party Hunt stopped'
    render()
end
local function onOpcode(_, _, buffer)
    local ok, response = pcall(json.decode, buffer)
    if not ok or type(response) ~= 'table' or response.action ~= 'status' then return end
    local wasFollowing,wasRunning,oldRun,oldRescue=Hunt.isFollowing(),running,snapshot.run,snapshot.rescueSerial
    snapshot, lastStatusAt, ready = response, g_clock.millis(), true
    if pendingStart then pendingStart = false end
    running = response.active == true and (isLeader() or response.following==true) and not response.tooMany
    if wasFollowing and not Hunt.isFollowing() and PartyFollower then PartyFollower.reset() end
    if Hunt.isFollowing() and PartyFollower and (response.rescueSerial or 0)>0 and response.rescueSerial~=oldRescue then
        PartyFollower.reset()
    end
    if wasRunning and not running then
        restoreCombat()
        if floating then floating:hide() end
    end
    if running and (not wasRunning or oldRun~=response.run) then
        if wasRunning then restoreCombat() end
        local combat=modules.game_baiakeros_helper
        previousCombat={auto=combat.autoAttackEnabled==true,shooter=combat.attackRotationEnabled==true}
        combat.setAutoAttackEnabled(true)
        combat.setAttackRotationEnabled(true)
        lastTransition,lastLeaderWalk=nil,nil
        Hunt.minimize()
        Hunt.showFloating(true)
    end
    stateText = type(response.reason) == 'string' and response.reason ~= '' and response.reason or
        (running and (isLeader() and 'Leader ativo: party acompanhando.' or 'Acompanhando o leader') or
            (response.leader and 'Party pronta' or 'Entre em uma party para comecar'))
    render()
end
local function tick()
    tickEvent = nil
    if g_game.isOnline() then
        local now = g_clock.millis()
        if pendingStart and now - pendingStartAt >= 8000 then Hunt.stop('Start confirmation timed out') end
        if running and now - lastStatusAt > 8000 then Hunt.stop('Party Hunt connection expired', true) end
        if now - lastRequestAt >= (running and 500 or 3000) then
            if running then send('heartbeat') else send('status') end
            lastRequestAt = now
        end
        if Hunt.isFollowing() and PartyFollower then
            stateText=PartyFollower.update(snapshot,snapshot.vocation==2)
        end
    end
    render()
    tickEvent = scheduleEvent(tick, 50)
end
function Hunt.onGameStart()
    if PartyFollower then PartyFollower.reset() end
    lastTransition,lastLeaderWalk=nil,nil
    snapshot, ready, running, pendingStart = {}, false, false, false
    lastRequestAt = 0
    Hunt.refresh()
end
function Hunt.onGameEnd()
    Hunt.stop('Party Hunt stopped on disconnect', true)
    snapshot, ready = {}, false
    if floating then floating:hide() end
    render()
end
function Hunt.onPositionChange(player, position, oldPosition)
    if not running or player~=g_game.getLocalPlayer() then return end
    if Hunt.isFollowing() and PartyFollower then
        PartyFollower.onPositionChange(position,oldPosition)
    elseif isLeader() and position and oldPosition and math.abs(position.z-oldPosition.z)==1 then
        local route=BaiakHelperExplorerV2 and BaiakHelperExplorerV2.getRouteState()
        local t=route and route.transition
        if not t or not t.exit or not PartyHuntMovement.same(t.exit,position) then
            local walk=lastLeaderWalk
            local recent=walk and g_clock.millis()-walk.at<1500 and PartyHuntMovement.same(walk.from,oldPosition)
            t={entry=oldPosition,exit=position,kind='stair',direction=recent and walk.direction or player:getDirection()}
        end
        lastTransition=t
        send('heartbeat')
    end
end
function Hunt.onWalk(direction)
    if not running or not isLeader() then return end
    local p=g_game.getLocalPlayer():getPosition()
    lastLeaderWalk={from={x=p.x,y=p.y,z=p.z},direction=direction,at=g_clock.millis()}
end
function Hunt.onCancelWalk(player)
    if Hunt.isFollowing() and player==g_game.getLocalPlayer() and PartyFollower then PartyFollower.onCancelWalk() end
end
function Hunt.init(helperWindow)
    g_ui.importStyle('party_hunt')
    panel = g_ui.createWidget('BaiakerosPartyHuntPanel', helperWindow:recursiveGetChildById('partyHuntPage'))
    floating = g_ui.createWidget('BaiakerosPartyHuntFloat', rootWidget)
    ProtocolGame.registerExtendedOpcode(OPCODE, onOpcode)
    get('Start').onClick = function()
        if not ready or not isLeader() or not snapshot.canControl or snapshot.tooMany or pendingStart then return end
        if running then Hunt.stop() return end
        if remaining() <= 0 then return end
        pendingStart, pendingStartAt = true, g_clock.millis()
        send('start'); render()
    end
    get('Teleport').onClick = function()
        if ready and isLeader() and snapshot.canTeleport and not snapshot.tooMany and cooldown() == 0 then send('teleport') end
    end
    for value=1,6 do get('RunThreshold'):addOption(tostring(value),value) end
    get('RunThreshold').onOptionChange=changeOptions
    get('AlwaysRun').onCheckChange=changeOptions
    get('Refresh').onClick = Hunt.refresh
    get('Float').onClick = Hunt.showFloating
    floating:recursiveGetChildById('partyFloatStop').onClick = function() if isLeader() then Hunt.stop() end end
    floating:recursiveGetChildById('partyFloatBack').onClick = Hunt.openHelper
    floating:recursiveGetChildById('partyFloatMinimize').onClick = Hunt.minimize
    floating:recursiveGetChildById('partyFloatExpand').onClick = Hunt.expand
    if LocalPlayer then connect(LocalPlayer,{onPositionChange=Hunt.onPositionChange,onCancelWalk=Hunt.onCancelWalk}) end
    connect(g_game,{onWalk=Hunt.onWalk})
    tickEvent = scheduleEvent(tick, 50)
    render()
end
function Hunt.terminate()
    Hunt.onGameEnd()
    ProtocolGame.unregisterExtendedOpcode(OPCODE)
    if LocalPlayer then disconnect(LocalPlayer,{onPositionChange=Hunt.onPositionChange,onCancelWalk=Hunt.onCancelWalk}) end
    disconnect(g_game,{onWalk=Hunt.onWalk})
    if tickEvent then removeEvent(tickEvent); tickEvent = nil end
    if floating then modules.game_walk.unbindMovementKeysFromWidget(floating); floating:destroy(); floating = nil end
    if panel then panel:destroy(); panel = nil end
end
