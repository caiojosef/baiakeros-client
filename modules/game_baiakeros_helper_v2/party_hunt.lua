PartyHuntV2 = {}
local Hunt = PartyHuntV2
local OPCODE = 93
local panel, floating, tickEvent
local running, pendingStart, ready = false, false, false
local snapshot, lastStatusAt, lastRequestAt, pendingStartAt = {}, 0, 0, 0
local stateText = 'Aguardando dados da party do servidor...'
local previousCombat, lastTransition = nil, nil
local leaderCombat, applyingCombat = nil, false
local lastProtectionZone
local lastTargetId,lastTargetPacketAt,leaderTargetDirty=nil,0,false
local lastLeaderWalk
local updatingOptions = false
local minimized = true
local HOTKEY_CATEGORY, HOTKEY_ACTION = 'Baiakeros Party Hunt', 'Boss lever formation'
local function restoreCombat()
    if not previousCombat then return end
    local combat=modules.game_baiakeros_helper
    applyingCombat=true
    if combat.restorePartyCombatState then combat.restorePartyCombatState(previousCombat)
    else
        combat.setAutoAttackEnabled(previousCombat.auto)
        combat.setAttackRotationEnabled(previousCombat.shooter)
    end
    applyingCombat=false
    if not previousCombat.auto and g_game.isOnline() and g_game.cancelAttack then g_game.cancelAttack() end
    previousCombat,leaderCombat=nil,nil
end
local function get(id) return panel:recursiveGetChildById('party' .. id) end
local function send(action, options)
    if not g_game.isOnline() then return end
    local protocol = g_game.getProtocolGame()
    local data={action=action}
    local player=g_game.getLocalPlayer()
    if (action=='start' or action=='heartbeat') and player and snapshot.leader and snapshot.leader.id==player:getId() then
        local combat=modules.game_baiakeros_helper
        local choices=leaderCombat or {auto=combat.autoAttackEnabled==true,shooter=combat.attackRotationEnabled==true}
        data.autoAttack,data.shooter=choices.auto,choices.shooter
    end
    if action=='boss_lever' then data.enabled=options.enabled end
    if action=='options' then
        data.runThreshold,data.alwaysRun=options.runThreshold,options.alwaysRun
        data.paladinMode=options.paladinMode
        data.monkMode=options.monkMode
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
local function localProtectionZone()
    local player=g_game.getLocalPlayer()
    if player and player.hasState and PlayerStates then return player:hasState(PlayerStates.Pz) end
    return snapshot.protectionZone==true
end
local function combatAllowed()
    return not localProtectionZone() and (isLeader() or not snapshot.leader or snapshot.leader.protectionZone~=true)
end
local function syncCombat()
    if not running or snapshot.paused then return end
    local combat=modules.game_baiakeros_helper
    if not previousCombat then
        previousCombat={auto=combat.autoAttackEnabled==true,shooter=combat.attackRotationEnabled==true}
        if isLeader() then leaderCombat={auto=previousCombat.auto,shooter=previousCombat.shooter} end
    end
    local choices=isLeader() and leaderCombat or snapshot.leader and snapshot.leader.combat or {}
    local allowed=combatAllowed()
    local auto,shooter=allowed and choices.auto==true,allowed and choices.shooter==true
    applyingCombat=true
    if combat.autoAttackEnabled~=auto then combat.setAutoAttackEnabled(auto) end
    if combat.attackRotationEnabled~=shooter then combat.setAttackRotationEnabled(shooter) end
    applyingCombat=false
    -- Disabling Auto Attack must not cancel the leader's manual attack or the
    -- independent shared target of a follower. PZ still cancels all attacks.
    if not allowed and g_game.getAttackingCreature and g_game.getAttackingCreature() and g_game.cancelAttack then g_game.cancelAttack() end
end
function Hunt.onCombatOptionChange(option, enabled)
    if applyingCombat or not running then return end
    if isLeader() then
        leaderCombat=leaderCombat or {auto=false,shooter=false}
        leaderCombat[option]=enabled==true
        previousCombat={auto=leaderCombat.auto,shooter=leaderCombat.shooter}
        syncCombat()
        send('heartbeat')
    elseif not snapshot.paused then syncCombat() end
end
function Hunt.onProtectionZoneChange()
    local protected=localProtectionZone()
    local changed=lastProtectionZone~=protected
    lastProtectionZone=protected
    syncCombat()
    if running and isLeader() and changed then send('heartbeat') end
end
local function remaining()
    return math.max(0, (tonumber(snapshot.remaining) or 0) -
        (running and math.floor((g_clock.millis() - lastStatusAt) / 1000) or 0))
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
    get('PaladinMode'):setCurrentOptionByData(options.paladinMode or 'distance', true)
    get('MonkMode'):setCurrentOptionByData(options.monkMode or 'hold', true)
    updatingOptions=false
    local movementAllowed=ready and snapshot.canConfigureMovement==true and snapshot.vocation~=4
    local vocationNames={[1]='Sorcerer / Master Sorcerer',[2]='Druid / Elder Druid',
        [3]='Paladin / Royal Paladin',[4]='Knight / Elite Knight',[9]='Monk / Exalted Monk'}
    get('DruidOptionsTitle'):setText('Configurações - '..(vocationNames[snapshot.vocation] or 'sua vocação'))
    get('VocationSection'):setHeight(movementAllowed and 205 or 82)
    get('RunThreshold'):setEnabled(fresh and movementAllowed and g_game.isOnline())
    get('AlwaysRun'):setEnabled(fresh and movementAllowed and g_game.isOnline())
    for _,id in ipairs({'ToleranceLabel','RunThreshold','AlwaysRun','OptionsSeparator','MovementHelp'})do
        if movementAllowed then get(id):show()else get(id):hide()end
    end
    local paladin=movementAllowed and snapshot.vocation==3
    local monk=movementAllowed and snapshot.vocation==9
    get('MonkMode'):setEnabled(fresh and monk and g_game.isOnline())
    for _,id in ipairs({'MonkModeLabel','MonkMode'})do
        if monk then get(id):show()else get(id):hide()end
    end
    get('PaladinMode'):setEnabled(fresh and paladin and g_game.isOnline())
    for _,id in ipairs({'PaladinModeLabel','PaladinMode'})do
        if paladin then get(id):show()else get(id):hide()end
    end
    if paladin then
        get('AlwaysRun'):hide();get('AlwaysRun'):setEnabled(false)
        get('MovementHelp'):setText('Fique a 2 SQMs do líder ou circule e ataque. Ao atingir o limite de atacantes, começa a circular também nos modos parados.\n\nexevo mas san pronta: para a 2 SQMs, no norte, sul, leste ou oeste da box; depois retoma o modo escolhido. As outras magias mantêm seu alvo e alcance.')
    elseif monk then
        get('AlwaysRun'):hide();get('AlwaysRun'):setEnabled(false)
        get('MovementHelp'):setText('Monk / Exalted Monk: fique a 2 SQMs virado para a box, preferindo o lado do alvo do líder. Se estiver bloqueado, procura outro lado livre.\n\nCircular e atacar: anda ao redor da box, para a 2 SQMs para cada magia pronta do Shooter e volta a circular. O limite de atacantes também ativa a corrida no modo parado.')
    else
        get('MovementHelp'):setText(get('MovementHelp').defaultMovementText)
    end
    if ready and snapshot.vocation==4 then get('KnightNotice'):show()else get('KnightNotice'):hide()end
    local attacking=#(snapshot.attackers or {})
    get('Warning'):setText(snapshot.tooMany and 'Funciona somente com ate 4 pessoas, incluindo o leader.' or
        (running and snapshot.vocation~=4 and attacking>=(options.runThreshold or 2) and 'Pressao alta: '..attacking..' monstros atacando voce.' or
        (ready and snapshot.leader and not isLeader() and 'Use Stop Party Hunt na janela flutuante para pausar apenas voce.' or ''))
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
        f('Stop'):setEnabled(fresh and running and not snapshot.tooMany)
        updatingOptions=true
        f('BossLever'):setChecked(snapshot.bossLever==true)
        updatingOptions=false
        f('BossLever'):setEnabled(control and running)
        f('LeverHotkey'):setEnabled(control and running)
        f('LeverControls'):setHeight(isLeader() and 44 or 0)
        if isLeader() then f('LeverControls'):show() else f('LeverControls'):hide() end
        floating:setHeight(minimized and (isLeader() and 318 or 270) or (isLeader() and 398 or 350))
        f('Guide'):setText(snapshot.leader and snapshot.leader.name .. ' [Leader]' or 'No leader')
        local roster={}
        for index=1,4 do
            local member=(snapshot.members or {})[index]
            roster[#roster+1]=member and (index..'. '..member.name..(member.leader and ' [Leader]' or '')) or index..'. ---'
        end
        f('Roster'):setText(table.concat(roster,'\n'))
        f('Stop'):setText(not isLeader() and snapshot.paused and 'Resume Party Hunt' or 'Stop Party Hunt')
    end
end
function Hunt.isActive() return running end
function Hunt.hasBeamMastery()
    return ready and g_clock.millis()-lastStatusAt<=8000 and snapshot.vocation==1 and
        snapshot.spellUpgrades and snapshot.spellUpgrades.beamMastery==true or false
end
function Hunt.isFollowing() return running and not snapshot.paused and snapshot.following==true and not isLeader() end
function Hunt.isRunesOnly()
    return Hunt.isFollowing() and snapshot.vocation~=3 and snapshot.vocation~=9 and snapshot.settings and snapshot.settings.alwaysRun==true or false
end
function Hunt.isChangingFloor()
    local player=g_game.getLocalPlayer()
    return Hunt.isFollowing() and player and snapshot.leader.position and
        player:getPosition().z~=snapshot.leader.position.z or false
end
function Hunt.getLeaderTarget()
    if not Hunt.isFollowing() or not combatAllowed() or snapshot.bossLever or not snapshot.leader.targetId then return nil end
    local target=g_map.getCreatureById(snapshot.leader.targetId)
    if not target or not target:isMonster() or target:isDead() then return nil end
    local player=g_game.getLocalPlayer()
    if player and player.getPosition and target.getPosition then
        local p,t=player:getPosition(),target:getPosition()
        if not p or not t or p.z~=t.z then return nil end
    end
    return target
end
-- Own the party target even with Auto Attack disabled. Return true while
-- following so the legacy target selector cannot pick a different monster.
function Hunt.syncLeaderTarget()
    if not Hunt.isFollowing() then return false end
    if not g_game.isOnline() then return true end
    local player=g_game.getLocalPlayer()
    local target=player and (not player.isDead or not player:isDead()) and Hunt.getLeaderTarget() or nil
    local current=g_game.getAttackingCreature()
    if not target then
        lastTargetId,lastTargetPacketAt=nil,0
        if current then g_game.cancelAttack() end
        return true
    end
    local id=target:getId()
    if current and current:getId()==id then return true end
    local now=g_clock.millis()
    if now-lastTargetPacketAt<(lastTargetId==id and 500 or 100) then return true end
    lastTargetId,lastTargetPacketAt=id,now
    g_game.attack(target)
    return true
end
function Hunt.onAttackingCreatureChange()
    -- Game emits this before sending the attack packet. Publish on the next
    -- tick, after the server has received the real manual/automatic selection.
    if running and isLeader() then leaderTargetDirty=true end
end
-- Attack, spells and healing remain entirely under Helper control.
function Hunt.prepareSpell(spell)
    if running and not snapshot.paused and not combatAllowed() then return false end
    if running and snapshot.bossLever then return false end
    if Hunt.isFollowing() and PartyFollower then return PartyFollower.prepareSpell(spell,snapshot.vocation==9) end
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
    send('options',{runThreshold=selected.data,alwaysRun=snapshot.vocation~=3 and snapshot.vocation~=9 and get('AlwaysRun'):isChecked() or false,
        paladinMode=snapshot.vocation==3 and get('PaladinMode'):getCurrentOption().data or nil,
        monkMode=snapshot.vocation==9 and get('MonkMode'):getCurrentOption().data or nil})
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
    minimized=true
    floating:setHeight(isLeader() and 318 or 270)
    floating:recursiveGetChildById('partyFloatDetails'):hide()
    floating:recursiveGetChildById('partyFloatMinimize'):hide()
    floating:recursiveGetChildById('partyFloatExpand'):show()
end
function Hunt.expand()
    minimized=false
    floating:setHeight(isLeader() and 398 or 350)
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
function Hunt.setFollowingPaused(paused)
    if not running or isLeader() then return end
    snapshot.paused, snapshot.following = paused, not paused
    lastTargetId,lastTargetPacketAt=nil,0
    if PartyFollower then PartyFollower.reset() end
    if g_game.stop then g_game.stop() end
    if paused then
        restoreCombat()
        if g_game.cancelFollow then g_game.cancelFollow() end
        if g_game.setChaseMode then g_game.setChaseMode(DontChase) end
    end
    stateText=paused and 'Acompanhamento pausado. Movimento manual; sem teleporte.' or 'Retomando acompanhamento...'
    send(paused and 'stop' or 'resume')
    render()
end
function Hunt.setBossLever(enabled)
    if not running or not isLeader() or not snapshot.canControl or g_clock.millis()-lastStatusAt>8000 then return end
    send('boss_lever',{enabled=enabled})
end
function Hunt.toggleBossLever()
    Hunt.setBossLever(snapshot.bossLever~=true)
end
function Hunt.setLeverHotkey()
    if not isLeader() or not modules.client_options then return end
    modules.client_options.editKeybindActionPrimary(HOTKEY_CATEGORY,HOTKEY_ACTION,Keybind.chatMode)
end
function Hunt.stop(reason, fromServer)
    if not fromServer and running and not isLeader() then Hunt.setFollowingPaused(true);return end
    local wasActive = running or pendingStart
    running, pendingStart = false, false
    lastTargetId,lastTargetPacketAt,leaderTargetDirty=nil,0,false
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
    running = response.active == true and (isLeader() or response.following==true or response.paused==true) and not response.tooMany
    if wasFollowing~=Hunt.isFollowing() then
        lastTargetId,lastTargetPacketAt=nil,0
        if wasFollowing and PartyFollower then PartyFollower.reset() end
    end
    if Hunt.isFollowing() and PartyFollower and (response.rescueSerial or 0)>0 and response.rescueSerial~=oldRescue then
        PartyFollower.reset()
    end
    if response.paused then restoreCombat() end
    if wasRunning and not running then
        restoreCombat()
        if floating then floating:hide() end
    end
    if running and (not wasRunning or oldRun~=response.run) then
        if wasRunning then restoreCombat() end
        lastTransition,lastLeaderWalk=nil,nil
        lastTargetId,lastTargetPacketAt,leaderTargetDirty=nil,0,false
        Hunt.minimize()
        Hunt.showFloating(true)
    end
    syncCombat()
    Hunt.syncLeaderTarget()
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
        if now - lastRequestAt >= (running and 500 or 3000) or
            running and leaderTargetDirty and now-lastRequestAt>=150 then
            if running then send('heartbeat') else send('status') end
            lastRequestAt = now
            leaderTargetDirty=false
        end
        syncCombat()
        Hunt.syncLeaderTarget()
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
    lastProtectionZone=nil
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
    for value=1,6 do get('RunThreshold'):addOption(tostring(value),value) end
    get('MovementHelp').defaultMovementText=get('MovementHelp'):getText()
    get('PaladinMode'):addOption('Perto da box (2 SQMs)','close')
    get('PaladinMode'):addOption('2 SQMs do líder','distance')
    get('PaladinMode'):addOption('Circular e atacar','orbit')
    get('PaladinMode').onOptionChange=changeOptions
    get('MonkMode'):addOption('Parado a 2 SQMs','hold')
    get('MonkMode'):addOption('Circular e atacar','orbit')
    get('MonkMode').onOptionChange=changeOptions
    get('RunThreshold').onOptionChange=changeOptions
    get('AlwaysRun').onCheckChange=changeOptions
    get('Refresh').onClick = Hunt.refresh
    get('Float').onClick = Hunt.showFloating
    floating:recursiveGetChildById('partyFloatStop').onClick = function()
        if isLeader() then Hunt.stop() else Hunt.setFollowingPaused(not snapshot.paused) end
    end
    floating:recursiveGetChildById('partyFloatBossLever').onCheckChange=function(_,checked)
        if not updatingOptions then Hunt.setBossLever(checked) end
    end
    floating:recursiveGetChildById('partyFloatLeverHotkey').onClick=Hunt.setLeverHotkey
    Keybind.new(HOTKEY_CATEGORY,HOTKEY_ACTION,'','')
    Keybind.bind(HOTKEY_CATEGORY,HOTKEY_ACTION,{{type=KEY_DOWN,callback=Hunt.toggleBossLever}})
    floating:recursiveGetChildById('partyFloatBack').onClick = Hunt.openHelper
    floating:recursiveGetChildById('partyFloatMinimize').onClick = Hunt.minimize
    floating:recursiveGetChildById('partyFloatExpand').onClick = Hunt.expand
    if LocalPlayer then connect(LocalPlayer,{onPositionChange=Hunt.onPositionChange,onCancelWalk=Hunt.onCancelWalk}) end
    connect(g_game,{onWalk=Hunt.onWalk,onAttackingCreatureChange=Hunt.onAttackingCreatureChange})
    tickEvent = scheduleEvent(tick, 50)
    render()
end
function Hunt.terminate()
    Keybind.delete(HOTKEY_CATEGORY,HOTKEY_ACTION)
    Hunt.onGameEnd()
    ProtocolGame.unregisterExtendedOpcode(OPCODE)
    if LocalPlayer then disconnect(LocalPlayer,{onPositionChange=Hunt.onPositionChange,onCancelWalk=Hunt.onCancelWalk}) end
    disconnect(g_game,{onWalk=Hunt.onWalk,onAttackingCreatureChange=Hunt.onAttackingCreatureChange})
    if tickEvent then removeEvent(tickEvent); tickEvent = nil end
    if floating then modules.game_walk.unbindMovementKeysFromWidget(floating); floating:destroy(); floating = nil end
    if panel then panel:destroy(); panel = nil end
end
