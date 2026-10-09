PartyHuntMovement = {}
local Movement = PartyHuntMovement
Movement.boxRadius, Movement.orbitRadius = 5, 3
local directions = {
    { 0, -1, North }, { 1, 0, East }, { 0, 1, South }, { -1, 0, West },
    { 1, -1, NorthEast }, { 1, 1, SouthEast }, { -1, 1, SouthWest }, { -1, -1, NorthWest }
}
local function key(p) return p.x .. ':' .. p.y .. ':' .. p.z end
function Movement.distance(a, b)
    if not a or not b or a.z ~= b.z then return math.huge end
    return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end
function Movement.same(a, b) return Movement.distance(a, b) == 0 end
local function rotate(x, y, facing)
    if facing == East then return -y, x end
    if facing == South then return -x, -y end
    if facing == West then return y, -x end
    return x, y
end
local function hits(plan, p, monster, facing)
    if not plan or not plan.profile then return false end
    local profile = plan.profile
    local dx, dy = monster.x - p.x, monster.y - p.y
    if profile.shape == 'directional' then
        for _, offset in ipairs(plan.offsets or {}) do
            local x, y = rotate(offset[1], offset[2], facing)
            if dx == x and dy == y then return true end
        end
    elseif profile.shape == 'circle' or profile.shape == 'ring' then
        return math.abs(dx) <= profile.radius and math.abs(dy) <= profile.radius and
            math.abs(dx) + math.abs(dy) <= (profile.manhattan or profile.radius * 2) and
            (profile.shape~='ring' or math.max(math.abs(dx),math.abs(dy))>(profile.innerRadius or 0))
    end
    return false
end

function Movement.coverage(plan, position, box, monsters)
    local best = { score = 0, count = 0, boxCount = 0 }
    for _, facing in ipairs({ North, East, South, West }) do
        local count, boxCount = 0, 0
        for _, monster in ipairs(monsters) do
            if hits(plan, position, monster, facing) then
                count = count + 1
                if Movement.distance(monster, box) <= 2 then boxCount = boxCount + 1 end
            end
        end
        local score = boxCount * 120 + (count - boxCount) * 15
        if score > best.score then
            best = { score = score, count = count, boxCount = boxCount,
                facing = plan and plan.profile and plan.profile.shape == 'directional' and facing or nil }
        end
    end
    return best
end

local function nearest(position, monsters)
    local closest = math.huge
    for _, monster in ipairs(monsters) do closest = math.min(closest, Movement.distance(position, monster)) end
    return closest
end
local function inSight(position,box,visible)
    return not visible or visible(position,box)
end
local function visibleRoute(position,box,visible)
    local keepSight=inSight(position,box,visible)
    return function(p) return not keepSight or inSight(p,box,visible) end
end

local function search(start, canEnter, evaluate, maxDepth, cornerWalkable)
    local queue = { { p = start, depth = 0 } }
    local seen, head, best = { [key(start)] = true }, 1, nil
    while head <= #queue and head <= 600 do
        local node = queue[head]
        head = head + 1
        local value = evaluate(node.p, node.depth, node.step)
        if value and (not best or value.score > best.score) then
            value.position, value.step, value.direction = node.p, node.step, node.direction
            best = value
        end
        if node.depth < (maxDepth or 12) then
            for _, direction in ipairs(directions) do
                local p = { x = node.p.x + direction[1], y = node.p.y + direction[2], z = start.z }
                local flank = cornerWalkable or canEnter
                local cornerClear = direction[1] == 0 or direction[2] == 0 or
                    (flank({x=node.p.x+direction[1],y=node.p.y,z=start.z}) and
                     flank({x=node.p.x,y=node.p.y+direction[2],z=start.z}))
                if not seen[key(p)] and cornerClear and canEnter(p) then
                    seen[key(p)] = true
                    queue[#queue + 1] = { p = p, depth = node.depth + (direction[1] ~= 0 and direction[2] ~= 0 and 1.5 or 1),
                        step = node.step or p, direction = node.direction or direction[3] }
                end
            end
        end
    end
    return best
end

-- Score the real combat tiles of the chosen spell, with the EK's box weighted
-- more heavily than loose attackers. Reachability is part of the search.
function Movement.combat(position, box, monsters, plan, avoidDistance, walkable, escapingDamage)
    local currentDistance = nearest(position, monsters)
    local threatened = currentDistance < avoidDistance or escapingDamage == true
    local current = Movement.coverage(plan, position, box, monsters)
    local best
    for required = avoidDistance, 1, -1 do
        best = search(position, function(p)
            return Movement.distance(p, box) <= Movement.boxRadius and
                nearest(p, monsters) >= math.max(1, math.min(required, currentDistance)) and walkable(p)
        end, function(p, depth)
            if threatened and Movement.same(p, position) then return nil end
            local boxDistance = Movement.distance(p, box)
            if boxDistance > Movement.boxRadius or boxDistance < 1 or nearest(p, monsters) < required then return nil end
            local coverage = Movement.coverage(plan, p, box, monsters)
            -- Do not move for a tiny coverage gain when already safe; do move
            -- for a wider wave, a different spell, or an approaching attacker.
            local preferred = plan and ({['exevo tera hur']=4,['exevo gran frigo hur']=3,
                ['exevo gran mas frigo']=2})[plan.words] or 3
            local exits = 0
            for index=1,4 do
                local d=directions[index]
                if walkable({x=p.x+d[1],y=p.y+d[2],z=p.z}) then exits=exits+1 end
            end
            coverage.score = coverage.score - depth * 8 - math.abs(boxDistance - preferred) * 40 + exits * 5
            if threatened then coverage.score=coverage.score + math.min(nearest(p,monsters),4)*30 end
            if Movement.same(p, position) and not threatened then coverage.score = coverage.score + 12 end
            return coverage
        end)
        if best then break end
    end
    if best then
        best.threatened = threatened
        best.currentCoverage = current
    end
    return best
end

function Movement.follow(position, leader, followDistance, monsters, walkable,visible)
    if Movement.distance(position, leader) == followDistance and inSight(position,leader,visible) then return { position = position } end
    local route=visibleRoute(position,leader,visible)
    return search(position, function(p)
        return Movement.distance(p,leader)<=math.max(Movement.boxRadius,Movement.distance(position,leader)) and
            nearest(p, monsters) >= 1 and walkable(p) and route(p)
    end, function(p, depth)
        local distance = Movement.distance(p, leader)
        if distance<1 or distance>Movement.boxRadius or not inSight(p,leader,visible) then return nil end
        return { score = -math.abs(distance - followDistance) * 100 - depth * 8 }
    end)
end

function Movement.faceBox(position,box)
    local dx,dy=box.x-position.x,box.y-position.y
    if math.abs(dx)>math.abs(dy) then return dx>0 and East or West end
    return dy>0 and South or North
end
-- Paladin targeted attacks keep the selected formation, but must still reach
-- and see the actual Shooter target. A blocked close slot falls back to free space.
function Movement.paladin(position,box,monsters,radius,plan,walkable,visible,cornerWalkable)
    local route=visibleRoute(position,box,visible)
    local target=plan and plan.needTarget and plan.targetPosition
    return search(position,function(p)
        return Movement.distance(p,box)<=math.max(Movement.boxRadius,Movement.distance(position,box)) and
            nearest(p,monsters)>=1 and walkable(p) and route(p)
    end,function(p,depth)
        local distance=Movement.distance(p,box)
        if distance<1 or distance>Movement.boxRadius or not inSight(p,box,visible) or
            target and (Movement.distance(p,target)>(plan.castRange or 7) or not inSight(p,target,visible)) then return nil end
        return {score=-math.abs(distance-radius)*1000-depth*10,facing=Movement.faceBox(p,box)}
    end,nil,cornerWalkable)
end
function Movement.coverageFacing(plan,position,box,monsters,facing)
    local count,boxCount=0,0
    for _,monster in ipairs(monsters)do
        if hits(plan,position,monster,facing) then
            count=count+1
            if Movement.distance(monster,box)<=2 then boxCount=boxCount+1 end
        end
    end
    return {count=count,boxCount=boxCount,facing=facing}
end
-- The closest reachable cardinal slot wins. Spell coverage cannot pull the
-- caster away from the explicit formation chosen for this hunt strategy.
function Movement.cardinal(position,box,monsters,radius,walkable,visible,plan,exact,preferredTarget)
    local route=visibleRoute(position,box,visible)
    return search(position,function(p)
        return Movement.distance(p,box)<=Movement.boxRadius and nearest(p,monsters)>=1 and walkable(p) and route(p)
    end,function(p,depth)
        local d=Movement.distance(p,box)
        if d<1 or d>Movement.boxRadius or nearest(p,monsters)<1 or
            (p.x~=box.x and p.y~=box.y) or not inSight(p,box,visible) then return nil end
        if exact and (d~=radius or not Movement.canUseFormation(plan,p,box,monsters,visible)) then return nil end
        local targetBias=0
        if exact and preferredTarget and preferredTarget.z==box.z then
            local dx,dy=preferredTarget.x-box.x,preferredTarget.y-box.y
            local span=math.max(math.abs(dx),math.abs(dy))
            if span>0 then
                -- Prefer the target's side before path length. A diagonal
                -- target gives equal priority to its two cardinal sides.
                targetBias=((p.x-box.x)*dx+(p.y-box.y)*dy)/(d*span)*10000
            end
        end
        return {score=targetBias-math.abs(d-radius)*1000-depth*10,facing=Movement.faceBox(p,box)}
    end)
end

-- The Monk's slot is exact, including single-target spell range. This filters
-- destinations only: the route may pass through other safe, visible tiles.
function Movement.canUseFormation(plan,p,box,monsters,visible)
    if not plan then return true end
    if plan.needTarget and (not plan.targetPosition or Movement.distance(p,plan.targetPosition)>(plan.castRange or 1) or
        not inSight(p,plan.targetPosition,visible)) then return false end
    local shape=plan.profile and plan.profile.shape
    if shape=='directional' or shape=='circle' or shape=='ring' then
        local coverage=Movement.coverageFacing(plan,p,box,monsters,Movement.faceBox(p,box))
        return coverage.boxCount>0 and coverage.count>=(plan.minEnemies or 1)
    end
    return true
end

function Movement.toTile(position, destination, monsters, walkable)
    return search(position, function(p)
        return nearest(p, monsters) >= 1 and walkable(p)
    end, function(p, depth)
        return { score = -Movement.distance(p, destination) * 100 - depth * 8 }
    end)
end

-- Normal Great Energy Beam is one tile wide. From the nearest cardinal axis,
-- move one tile sideways and fire parallel to that axis through the fuller
-- side of the EK's box. Beam Mastery uses the ordinary cardinal formation.
function Movement.beamFormation(position,box,monsters,plan,radius,walkable,visible,previousSlot)
    local route=visibleRoute(position,box,visible)
    return search(position,function(p)
        return Movement.distance(p,box)<=Movement.boxRadius and nearest(p,monsters)>=1 and walkable(p) and route(p)
    end,function(p,depth)
        local dx,dy=p.x-box.x,p.y-box.y
        if not (math.abs(dx)==radius and math.abs(dy)==1 or math.abs(dy)==radius and math.abs(dx)==1) or
            not inSight(p,box,visible) then return nil end
        local axis={x=math.abs(dx)==radius and p.x or box.x,y=math.abs(dy)==radius and p.y or box.y,z=box.z}
        local coverage=Movement.coverageFacing(plan,p,box,monsters,Movement.faceBox(p,box))
        -- Prefer the nearest reachable axis, then the fuller of its two lanes.
        -- The cardinal base itself may be occupied: only the lateral destination
        -- and its route must be free, so a blocked base cannot stall the beam.
        coverage.score=-Movement.distance(position,axis)*1000000+coverage.boxCount*10000-depth*8+
            (previousSlot and Movement.same(p,previousSlot) and 1000 or 0)
        return coverage
    end)
end

-- Screen coordinates grow downwards, so a positive cross product is clockwise.
-- Prefer the requested direction; reverse only if its reachable exits are blocked.
function Movement.orbit(position, box, monsters, avoidDistance, walkable, clockwise,visible,castRadius,previousPosition,cornerWalkable,plan)
    local radius=Movement.distance(position,box)
    if radius>Movement.boxRadius or not inSight(position,box,visible) then
        return Movement.follow(position,box,Movement.orbitRadius,monsters,walkable,visible)
    end
    local preferred=math.max(Movement.orbitRadius,math.min(Movement.boxRadius,castRadius or avoidDistance+1))
    -- Box monsters occupy the leader's adjacent tiles. Requiring three free
    -- SQMs from them would exclude every casting slot on the three-SQM orbit.
    -- A ready spell may approach its orbit slot; occupied tiles stay forbidden.
    local requiredDistance=castRadius and math.min(avoidDistance,preferred-1) or avoidDistance
    local minimumRadius=math.min(radius,Movement.orbitRadius)
    local dx,dy=position.x-box.x,position.y-box.y
    local current=nearest(position,monsters)
    local function choose(clockwiseDirection,required)
        return search(position,function(p)
            local d=Movement.distance(p,box)
            return d>=minimumRadius and d<=Movement.boxRadius and inSight(p,box,visible) and
                nearest(p,monsters)>=math.max(1,math.min(current,required)) and walkable(p)
        end,function(p,depth,firstStep)
            local cross=dx*(p.y-box.y)-dy*(p.x-box.x)
            local stepCross=firstStep and (dx*(firstStep.y-box.y)-dy*(firstStep.x-box.x)) or 0
            if depth==0 or Movement.distance(p,box)<Movement.orbitRadius or
                previousPosition and Movement.same(firstStep,previousPosition) or
                (clockwiseDirection and (cross<=0 or stepCross<0) or not clockwiseDirection and (cross>=0 or stepCross>0)) or
                nearest(p,monsters)<required then return nil end
            local exits=0
            for index=1,4 do local d=directions[index]
                local exit={x=p.x+d[1],y=p.y+d[2],z=p.z}
                if Movement.distance(exit,box)<=Movement.boxRadius and walkable(exit) and inSight(exit,box,visible) then exits=exits+1 end
            end
            local coverage=plan and Movement.coverage(plan,p,box,monsters)
            local castScore=coverage and (coverage.boxCount*120+
                (coverage.boxCount>0 and coverage.count>=(plan.minEnemies or 1) and 2000 or 0)) or 0
            return {score=math.min(nearest(p,monsters),5)*80+exits*12+
                castScore+
                math.abs(cross)*5+(stepCross~=0 and 35 or 0)-depth*25-
                math.abs(Movement.distance(p,box)-preferred)*(castRadius and 300 or 120)-
                (castRadius and firstStep and math.abs(Movement.distance(firstStep,box)-preferred)*300 or 0),
                clockwise=clockwiseDirection}
        end,3,cornerWalkable)
    end
    for _,orientation in ipairs({clockwise,not clockwise}) do
        for required=requiredDistance,1,-1 do
            local choice=choose(orientation,required)
            if choice then return choice end
        end
    end
    return Movement.combat(position,box,monsters,nil,1,function(p)
        return Movement.distance(p,box)>=minimumRadius and walkable(p) and inSight(p,box,visible)
    end,true)
end
