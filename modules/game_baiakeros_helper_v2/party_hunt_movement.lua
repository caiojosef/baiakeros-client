PartyHuntMovement = {}
local Movement = PartyHuntMovement
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
    elseif profile.shape == 'circle' then
        return math.abs(dx) <= profile.radius and math.abs(dy) <= profile.radius and
            math.abs(dx) + math.abs(dy) <= (profile.manhattan or profile.radius * 2)
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

local function search(start, canEnter, evaluate, maxDepth)
    local queue = { { p = start, depth = 0 } }
    local seen, head, best = { [key(start)] = true }, 1, nil
    while head <= #queue and head <= 600 do
        local node = queue[head]
        head = head + 1
        local value = evaluate(node.p, node.depth)
        if value and (not best or value.score > best.score) then
            value.position, value.step, value.direction = node.p, node.step, node.direction
            best = value
        end
        if node.depth < (maxDepth or 12) then
            for _, direction in ipairs(directions) do
                local p = { x = node.p.x + direction[1], y = node.p.y + direction[2], z = start.z }
                if not seen[key(p)] and canEnter(p) then
                    seen[key(p)] = true
                    queue[#queue + 1] = { p = p, depth = node.depth + 1,
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
            return Movement.distance(p, box) <= 7 and
                nearest(p, monsters) >= math.max(1, math.min(required, currentDistance)) and walkable(p)
        end, function(p, depth)
            if threatened and Movement.same(p, position) then return nil end
            if Movement.distance(p, box) > 7 or nearest(p, monsters) < required then return nil end
            local coverage = Movement.coverage(plan, p, box, monsters)
            -- Do not move for a tiny coverage gain when already safe; do move
            -- for a wider wave, a different spell, or an approaching attacker.
            coverage.score = coverage.score - depth * 8 -
                math.abs(Movement.distance(p, box) - 3) * 2
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

function Movement.follow(position, leader, followDistance, monsters, walkable)
    if Movement.distance(position, leader) <= followDistance then return { position = position } end
    return search(position, function(p)
        return nearest(p, monsters) >= 1 and walkable(p)
    end, function(p, depth)
        local distance = Movement.distance(p, leader)
        if distance < 1 then return nil end
        return { score = -math.max(0, distance - followDistance) * 100 - depth * 8 }
    end)
end

function Movement.toTile(position, destination, monsters, walkable)
    return search(position, function(p)
        return nearest(p, monsters) >= 1 and walkable(p)
    end, function(p, depth)
        return { score = -Movement.distance(p, destination) * 100 - depth * 8 }
    end)
end
