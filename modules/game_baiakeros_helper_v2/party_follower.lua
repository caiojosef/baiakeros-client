-- Movement only. The Shooter remains the sole owner of spell selection/casting.
PartyFollower = {}
local Follower = PartyFollower
local M = PartyHuntMovement
local pending, rejected, nextMoveAt, holdUntil, nextCastWindowAt = nil, {}, 0, 0, 0
local previousChase, state = nil, nil
local recovery, learnedHoles, lastBox, lastBoxMovedAt = nil, {}, nil, 0
local passage, nextPassageAt = nil, 0
local formation
local nextFacingAt = 0
local castWindow
local catchingUp=false
local lastPosition,previousPosition
local orbitClockwise,reverseUntil=true,0
local DRUID_FORMATION = {
    ['exevo tera hur']=4, ['exevo gran frigo hur']=3,
    ['exevo gran mas frigo']=2, ['exevo gran mas tera']=2,
    ['exevo ulus frigo']=3, ['exevo ulus tera']=3
}
local SORCERER_FORMATION = {
    ['exevo vis hur']=DRUID_FORMATION['exevo tera hur'], ['exevo gran flam hur']=DRUID_FORMATION['exevo tera hur'],
    ['exevo flam hur']=2, ['exevo infir flam hur']=2,
    ['exevo vis lux']=3, ['exevo gran vis lux']=DRUID_FORMATION['exevo tera hur'], ['exevo max mort']=3,
    ['exevo gran mas flam']=2, ['exevo gran mas vis']=2
}
local function spellRadius(druid, sorcerer, plan)
    local positions=druid and DRUID_FORMATION or sorcerer and SORCERER_FORMATION
    return positions and plan and positions[plan.words] or 3
end
local function key(p) return p.x..':'..p.y..':'..p.z end
local function now() return g_clock.millis() end
local function explorer() return BaiakHelperExplorerV2 end
local function walkable(p, allowTransition, ignoreCreatures)
    if (rejected[key(p)] or 0) > now() or not allowTransition and learnedHoles[key(p)] then return false end
    local tile = g_map.getTile(p)
    if not tile or not tile:getGround() or not tile:isWalkable(ignoreCreatures==true) then return false end
    if not allowTransition and not explorer().isSafeMovementTile(p) then return false end
    return true
end
local function monstersAt(player, position)
    local monsters={}
    local map=modules.game_interface.getMapPanel()
    for _,creature in ipairs(map and map:getSpectators() or {}) do
        local p=creature:getPosition()
        if creature:isMonster() and not creature:isDead() and
            (not creature.getMasterId or creature:getMasterId()==0) and M.distance(p,position)<=6 then
            monsters[#monsters+1]=p
        end
    end
    return monsters
end
local function pressure(player, position, box, monsters, attackers, settings)
    local attacking=#(attackers or {})
    local threshold=math.max(1,math.min(6,tonumber(settings.runThreshold) or 2))
    local running=settings.alwaysRun==true or attacking>=threshold
    -- Below the configured limit, nearby monsters and lost health must not
    -- silently override the leader's explicit choice to hold the formation.
    if not running then return false,1,false end
    local health=player:getHealthPercent()
    local mana=player:getMaxMana()>0 and player:getMana()*100/player:getMaxMana() or 0
    local heavy=attacking>=threshold+2 or health<35
    local avoid=heavy and 4 or (attacking>=threshold+1 or health<60 or mana<25) and 3 or 2
    return true,avoid,heavy
end
local function heldFormation(position,box,monsters,plan,radius,safe,visible)
    local words=plan and plan.words or "default"
    local lateral=words=='exevo gran vis lux' and not plan.beamMastery
    local selector=lateral and function(p,b,m,r,s,v) return M.beamFormation(p,b,m,plan,r,s,v) end or M.cardinal
    if not formation or formation.words~=words or formation.radius~=radius or formation.lateral~=lateral or not M.same(formation.box,box) or
        M.distance(formation.position,box)~=radius or not visible(formation.position,box) or
        not M.same(formation.position,position) and not safe(formation.position) then
        local selected=selector(position,box,monsters,radius,safe,visible)
        formation=selected and {words=words,radius=radius,lateral=lateral,box={x=box.x,y=box.y,z=box.z},position=selected.position} or nil
    end
    if not formation then return nil end
    if lateral then
        -- Re-evaluate both sides when the box pack changes, keeping the current
        -- side on a tie instead of oscillating between two equal beam lanes.
        local selected=M.beamFormation(position,box,monsters,plan,radius,safe,visible,formation.position)
        if selected then formation.position=selected.position end
    end
    local route=not M.same(position,formation.position) and M.toTile(position,formation.position,monsters,function(p)
        return M.distance(p,box)<=M.boxRadius and safe(p) and
            (not visible(position,box) or visible(p,box))
    end) or nil
    if not M.same(position,formation.position) and (not route or not M.same(route.position,formation.position)) then
        local selected=selector(position,box,monsters,radius,safe,visible)
        if not selected then formation=nil;return nil end
        formation.position=selected.position;route=selected
    end
    local coverage=M.coverageFacing(plan,formation.position,box,monsters,M.faceBox(formation.position,box))
    return {position=formation.position,step=route and route.step,direction=route and route.direction,
        boxCount=coverage.boxCount,count=coverage.count,facing=coverage.facing}
end
local function settlePending(player, position)
    if not pending then return end
    if M.same(position,pending.to) then pending=nil
    elseif not M.same(position,pending.from) then pending=nil
    elseif now()-pending.at>math.max(800,(player:getStepDuration() or 200)*3) then
        rejected[key(pending.to)]=now()+1500
        pending=nil
    end
end
local function move(player, position, choice)
    if not choice or not choice.step or pending or now()<nextMoveAt or now()<holdUntil or
        player:isWalking() or player:isAutoWalking() then return end
    pending={from=position,to=choice.step,at=now()}
    nextMoveAt=now()+math.max(35,(player:getStepDuration() or 100)-35)
    if g_game.walk(choice.direction)==false then pending=nil;nextMoveAt=now()+200 end
end
function Follower.reset()
    if previousChase~=nil and g_game.isOnline() and g_game.getChaseMode()==DontChase then
        g_game.setChaseMode(previousChase)
    end
    pending,rejected,nextMoveAt,holdUntil,nextCastWindowAt=nil,{},0,0,0
    previousChase,state=nil,nil
    recovery,learnedHoles,lastBox,lastBoxMovedAt=nil,{},nil,0
    passage,nextPassageAt=nil,0
    formation=nil
    nextFacingAt=0
    castWindow=nil
    catchingUp=false
    lastPosition,previousPosition=nil,nil
    orbitClockwise,reverseUntil=true,0
end
function Follower.onCancelWalk()
    if pending then rejected[key(pending.to)]=now()+1000 end
    pending=nil;nextMoveAt=now()+50
end
function Follower.onPositionChange(position, oldPosition)
    if not position or not oldPosition then return end
    if position.z~=oldPosition.z then
        local entered=pending and pending.to or oldPosition
        recovery={origin=oldPosition,landing=position,entered=entered,expires=now()+60000}
        learnedHoles[key(entered)]=true
        learnedHoles[key({x=entered.x,y=entered.y,z=position.z})]=true
        holdUntil=0
        passage,nextPassageAt=nil,0
    end
    if pending and not M.same(position,pending.from) then pending=nil end
end
local function floorRoute(snapshot,position,box)
    local function eligible(t)
        return t and t.entry and t.entry.z==position.z and t.exit and
            math.abs(t.exit.z-box.z)<math.abs(position.z-box.z)
    end
    local returning=snapshot.returnPassage
    if eligible(returning) then passage=returning;return passage end
    local transitions=snapshot.leader.transitions
    if not transitions or #transitions==0 then transitions={snapshot.leader.transition} end
    for index=#transitions,1,-1 do
        local t=transitions[index]
        if eligible(t) then
            -- Keep the passage until the floor change is confirmed. A precise
            -- server action can replace an approximate walking observation.
            if not eligible(passage) or t.authoritative and not passage.authoritative then passage=t end
            return passage
        end
    end
    if eligible(passage) then return passage end
    -- Immediate local recovery while waiting for the next server snapshot.
    -- Only a staircase next to the observed accidental transition is eligible.
    if recovery and recovery.expires>now() and recovery.origin.z==box.z then
        local best,bestDistance
        for x=-2,2 do for y=-2,2 do
            local p={x=recovery.entered.x+x,y=recovery.entered.y+y,z=position.z}
            local tile=g_map.getTile(p)
            if tile and tile:getGround() and tile:hasElevation(3) and box.z<position.z then
                local d=M.distance(position,p)
                if not bestDistance or d<bestDistance then best,bestDistance=p,d end
            end
        end end
        if best then passage={entry=best,exit=recovery.origin,kind='stair',tile=true};return passage end
    end
end
local function usePassage(transition)
    local tile=g_map.getTile(transition.entry)
    if not tile then return false end
    local thing=tile.getTopUseThing and tile:getTopUseThing()
    if transition.itemId and tile.getItems then
        for _,item in ipairs(tile:getItems()) do
            if item:getId()==transition.itemId then thing=item;break end
        end
    end
    if thing and thing:isItem() then g_game.use(thing);return true end
    return false
end
function Follower.update(snapshot, druid)
    local player=g_game.getLocalPlayer()
    if snapshot.paused then Follower.reset();return 'Acompanhamento pausado' end
    if not player or player:isDead() or not snapshot.leader then Follower.reset();return 'Aguardando leader' end
    if previousChase==nil then previousChase=g_game.getChaseMode() end
    if g_game.getChaseMode()~=DontChase then g_game.setChaseMode(DontChase) end
    local visibleLeader=g_map.getCreatureById(snapshot.leader.id)
    local position,box=player:getPosition(),visibleLeader and visibleLeader:getPosition() or snapshot.leader.position
    if not position or not box then return 'Aguardando posicao do leader' end
    if lastPosition and not M.same(position,lastPosition) then previousPosition=lastPosition end
    lastPosition={x=position.x,y=position.y,z=position.z}
    settlePending(player,position)
    local leaderPz=snapshot.leader.protectionZone==true
    local function protected(p)
        if not leaderPz then return true end
        local area=snapshot.protectionArea
        if not area or p.z~=area.z then return false end
        local row=area.rows[p.y-area.y+1]
        local column=p.x-area.x+1
        return row and column>=1 and row:sub(column,column)=='1' or false
    end
    local monsters=monstersAt(player,position)
    local settings=snapshot.settings or {}
    local paladin=snapshot.vocation==3
    local paladinMode=settings.paladinMode
    if paladinMode~='close' and paladinMode~='orbit' then paladinMode='distance' end
    local danger,avoid,heavy=false,1,false
    if snapshot.vocation~=4 then danger,avoid,heavy=pressure(player,position,box,monsters,snapshot.attackers,settings) end
    if paladin then
        -- Paladin orbit permits spells. The legacy runes-only switch is not
        -- its movement mode and must not suppress its configured Shooter.
        local movementSettings={runThreshold=settings.runThreshold,alwaysRun=paladinMode=='orbit'}
        danger,avoid,heavy=pressure(player,position,box,monsters,snapshot.attackers,movementSettings)
    end
    local safeCache={}
    local sightCache={}
    local function visible(p,leader)
        local sightKey=key(p)..'>'..key(leader)
        if sightCache[sightKey]==nil then
            sightCache[sightKey]=p.z==leader.z and
                (not g_map.isSightClear or g_map.isSightClear(p,leader) and g_map.isSightClear(leader,p))
        end
        return sightCache[sightKey]
    end
    local function safe(p)
        if safeCache[key(p)]==nil then safeCache[key(p)]=protected(p) and walkable(p) end
        return safeCache[key(p)]
    end
    local function cornerSafe(p)
        -- A creature beside a diagonal step does not occupy its destination.
        -- Check the flanking terrain, while the destination still checks creatures.
        return protected(p) and walkable(p,false,true)
    end
    if leaderPz then
        state={protection=true,at=now()}
        formation,castWindow=nil,nil
        holdUntil=0
        if pending and not protected(pending.to) then
            if g_game.stop then g_game.stop() end
            pending=nil
        end
        if position.z~=box.z or not protected(position) then
            return 'Leader em PZ: aguardando retorno para uma posicao protegida'
        end
        if not snapshot.bossLever then
            -- Stay near the leader without attack formation, orbit or floor changes.
            local choice=M.follow(position,box,2,{},safe,visible)
            move(player,position,choice)
            return 'Aguardando o leader sair do PZ'
        end
    end
    if snapshot.bossLever and snapshot.formationTarget then
        state={lineup=true,protection=leaderPz,at=now()}
        formation,castWindow=nil,nil
        holdUntil=0
        local destination=snapshot.formationTarget
        if position.z~=destination.z then return 'Fila da alavanca em outro andar: aguardando' end
        if not M.same(position,destination) then
            local choice=M.toTile(position,destination,{},safe)
            move(player,position,choice)
            return 'Enfileirando na posicao da party'
        end
        return 'Pronto na fila da alavanca'
    end
    if position.z~=box.z then
        state,formation=nil,nil
        holdUntil=0
        local transition=floorRoute(snapshot,position,box)
        if not transition then
            return 'Leader em outro andar: aguardando passagem conhecida'
        end
        -- Only the confirmed route transition may cross floors. Never choose a random hole.
        if transition.kind=='use' and M.distance(position,transition.entry)<=1 then
            if now()>=nextPassageAt and not pending and not player:isWalking() then
                usePassage(transition);nextPassageAt=now()+700
            end
        elseif M.same(position,transition.entry) then
            if transition.kind=='stair' and transition.direction~=nil and now()>=nextPassageAt and not pending then
                local d=({[North]={0,-1},[East]={1,0},[South]={0,1},[West]={-1,0},
                    [NorthEast]={1,-1},[SouthEast]={1,1},[SouthWest]={-1,1},[NorthWest]={-1,-1}})[transition.direction]
                if d then
                    local step={x=position.x+d[1],y=position.y+d[2],z=position.z}
                    -- An elevated stair often has no ground on this floor in
                    -- the walking direction. Only this recorded passage may
                    -- send that step; ordinary routing still rejects holes.
                    move(player,position,{step=step,direction=transition.direction})
                    nextPassageAt=now()+500
                end
            elseif transition.tile and now()>=nextMoveAt and not pending then
                -- Elevated stairs go up when walking off their top tile.
                local directions={{0,-1,North},{1,0,East},{0,1,South},{-1,0,West}}
                for _,d in ipairs(directions) do
                    local step={x=position.x+d[1],y=position.y+d[2],z=position.z}
                    if walkable(step) then move(player,position,{step=step,direction=d[3]});break end
                end
            elseif (transition.kind=='hur_up' or transition.kind=='hur_down' or transition.kind=='rope') and now()>=nextPassageAt and
                not pending and not player:isWalking() and not player:isAutoWalking() then
                local helper=modules.game_baiakeros_helper
                if helper.isManualActionPending and helper.isManualActionPending() then return 'Aguardando hotkey manual' end
                if transition.kind=='rope' then
                    g_game.talk('exani tera');nextPassageAt=now()+2200
                elseif player:getDirection()~=transition.direction then
                    g_game.turn(transition.direction);nextPassageAt=now()+200
                else
                    g_game.talk(transition.kind=='hur_up' and 'exani hur "up' or 'exani hur "down')
                    nextPassageAt=now()+2200
                end
            end
        else
            local choice=M.toTile(position,transition.entry,monsters,function(p)
                return walkable(p,M.same(p,transition.entry))
            end)
            move(player,position,choice)
        end
        return 'Seguindo a passagem de andar do leader'
    end
    local combat=modules.game_baiakeros_helper
    local sorcerer=snapshot.vocation==1
    local ranged=druid or sorcerer or paladin
    local plan=ranged and combat.getPartyHuntSpellPlan and combat.getPartyHuntSpellPlan()
    if plan and not plan.ready then plan=nil end
    if not lastBox then lastBoxMovedAt=now()-500
    elseif not M.same(box,lastBox) then lastBoxMovedAt=now() end
    lastBox={x=box.x,y=box.y,z=box.z}
    local leaderMoving=now()-lastBoxMovedAt<500
    if leaderMoving or M.distance(position,box)>M.boxRadius then catchingUp=true
    elseif M.distance(position,box)<=M.orbitRadius then catchingUp=false end
    local fighting=not leaderMoving and #monsters>0 and M.distance(position,box)<=M.boxRadius and not player:hasState(PlayerStates.Pz)
    local choice
    local masSan=paladin and plan and plan.words=='exevo mas san'
    if fighting and masSan then
        choice=heldFormation(position,box,monsters,plan,2,safe,visible)
        if danger and (not choice or M.distance(choice.position,box)~=2) then choice=nil end
    end
    if choice then
        -- A ready Divine Caldera takes its two-SQM cardinal slot even in orbit.
    elseif fighting and danger then
        formation=nil
        local castRadius=plan and spellRadius(druid,sorcerer,plan)
        if now()>=reverseUntil then orbitClockwise=true end
        choice=M.orbit(position,box,monsters,avoid,safe,orbitClockwise,visible,castRadius,previousPosition,cornerSafe,sorcerer and plan or nil)
        if choice and choice.clockwise~=nil and choice.clockwise~=orbitClockwise then
            orbitClockwise=choice.clockwise
            reverseUntil=orbitClockwise and 0 or now()+2000
        end
        if choice then local coverage=M.coverage(plan,choice.position,box,monsters)
            choice.boxCount,choice.count=coverage.boxCount,coverage.count end
    elseif paladin then
        formation=nil
        choice=M.paladin(position,box,monsters,2,
            plan,safe,visible,cornerSafe)
    elseif not leaderMoving and ranged and M.distance(position,box)<=M.boxRadius then
        if not plan and not catchingUp and M.distance(position,box)>=2 and visible(position,box) then
            -- No offensive spell is ready. Stay here instead of approaching
            -- the box for a cooled-down ultimate or oscillating between slots.
            formation=nil
            choice={position=position,facing=M.faceBox(position,box)}
        else
            local radius=spellRadius(druid,sorcerer,plan)
            choice=heldFormation(position,box,monsters,plan,radius,safe,visible)
        end
    else
        formation=nil
        choice=M.follow(position,box,M.orbitRadius,monsters,safe,visible)
    end
    state={druid=druid,sorcerer=sorcerer,paladin=paladin,ranged=ranged,snapshot=snapshot,position=position,box=box,monsters=monsters,plan=plan,
        choice=choice,danger=danger,alwaysRun=not paladin and snapshot.vocation~=4 and settings.alwaysRun==true,fighting=fighting,at=now()}
    if castWindow and (now()>=castWindow.expires or not plan or plan.words~=castWindow.words) then castWindow=nil end
    if fighting and danger and (paladin or settings.alwaysRun~=true) and plan and plan.ready and not pending and
        not player:isWalking() and not player:isAutoWalking() and now()>=nextCastWindowAt and visible(position,box) then
        local coverage=M.coverage(plan,position,box,monsters)
        if coverage.boxCount>0 and coverage.count>=(plan.minEnemies or 1) or
            ranged and plan.needTarget and plan.canCastHere then
            -- Reserve a confirmed step boundary before walking again. Adjacent
            -- attackers do not suppress the Shooter; healing remains independent.
            castWindow={words=plan.words,expires=now()+450}
            holdUntil,nextCastWindowAt=castWindow.expires,now()+700
        end
    end
    -- Ready spells face the box; while cooling down, keep the current slot.
    if not leaderMoving and ranged and not danger and choice and M.same(position,choice.position) and
        not pending and not player:isWalking() and not player:isAutoWalking() and
        choice.facing~=nil and player:getDirection()~=choice.facing and now()>=nextFacingAt then
        -- Direction is server-confirmed. Avoid sending a turn on every 50 ms
        -- tick while that confirmation is delayed or the turn is rejected.
        nextFacingAt=now()+250
        g_game.turn(choice.facing)
    end
    if choice then move(player,position,choice) end
    return fighting and (danger and (choice and choice.clockwise==false and 'Contornando obstaculo no sentido anti-horario' or 'Contornando no sentido horario') or
        plan and (paladin and 'Paladin: posicionando para ' or druid and 'Druid: posicionando para ' or 'Sorcerer: posicionando para ')..plan.words or 'Mantendo a formacao da box') or 'Seguindo o leader'
end
function Follower.prepareSpell(spell)
    if state and (state.lineup or state.protection) then return false end
    if not state or now()-state.at>500 then
        return spell.words and spell.words:match('^exori ') ~= nil
    end
    if state.alwaysRun then return false end
    if state.paladin and spell.words=='exevo mas san' then
        -- This exception is exact: never launch from the EK's adjacent tile,
        -- a diagonal slot or a distant fallback when all four slots are occupied.
        local player=g_game.getLocalPlayer()
        local p=player and player:getPosition()
        if not state.fighting or not p or M.distance(p,state.box)~=2 or
            p.x~=state.box.x and p.y~=state.box.y then return false end
    end
    if not state.fighting or not state.ranged then return true end
    local player=g_game.getLocalPlayer()
    if not player then return false end
    local position=player:getPosition()
    if state.sorcerer and spell.words=='exevo gran vis lux' then
        local dx,dy=math.abs(position.x-state.box.x),math.abs(position.y-state.box.y)
        local radius=SORCERER_FORMATION[spell.words]
        local width=state.plan and state.plan.beamMastery and 0 or 1
        if not (dx==radius and dy==width or dy==radius and dx==width) then return false end
    end
    -- Single-target spells do not require the wave formation, but retain safety.
    local profile=state.plan and state.plan.profile
    local formationSpell=state.druid and DRUID_FORMATION[spell.words]~=nil or
        state.sorcerer and SORCERER_FORMATION[spell.words]~=nil or state.paladin and spell.words=='exevo mas san'
    if formationSpell and (not state.plan or state.plan.words~=spell.words) then return false end
    if not profile or profile.shape~='directional' and profile.shape~='circle' and profile.shape~='ring' then
        return not pending and not player:isWalking()
    end
    if not state.plan or not state.plan.ready or state.plan.words~=spell.words then return false end
    local choice=state.choice
    settlePending(player,position)
    if pending or player:isWalking() or player:isAutoWalking() then return false end
    local coverage=not state.danger and M.coverageFacing(state.plan,position,state.box,state.monsters,M.faceBox(position,state.box)) or
        M.coverage(state.plan,position,state.box,state.monsters)
    if g_map.isSightClear and not g_map.isSightClear(position,state.box) then return false end
    if not choice then
        -- When completely trapped, keep the Helper attacking from here.
        return coverage.boxCount>0 and coverage.count>=(state.plan.minEnemies or 1),
            profile.shape=='directional' and coverage.facing or nil
    end
    if not M.same(choice.position,position) then
        -- A threatened ED may briefly cast from a safe tile on its escape path,
        -- instead of eternally postponing spells while searching the next tile.
        if not state.danger or not castWindow or castWindow.words~=spell.words or now()>=castWindow.expires then return false end
    end
    if coverage.boxCount<1 or coverage.count<(state.plan.minEnemies or 1) then return false end
    holdUntil=now()+350
    return true,profile.shape=='directional' and coverage.facing or nil
end
function Follower.onSpellCast() castWindow=nil;holdUntil=now()+180 end
