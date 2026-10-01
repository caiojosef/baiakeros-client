-- Bounded look-ahead for target-based kiting inside the travelled route.
BaiakLureMovement = {}
local Movement = BaiakLureMovement
local directions = {
    { 0, -1, North }, { 1, 0, East }, { 0, 1, South }, { -1, 0, West },
    { 1, -1, NorthEast }, { 1, 1, SouthEast }, { -1, 1, SouthWest }, { -1, -1, NorthWest }
}
local opposite = {
    [North] = South, [South] = North, [East] = West, [West] = East,
    [NorthEast] = SouthWest, [SouthWest] = NorthEast,
    [NorthWest] = SouthEast, [SouthEast] = NorthWest
}
local function key(p) return p.x .. ':' .. p.y .. ':' .. p.z end
local function distance(a, b) return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) end

-- Freeze the actually travelled path when combat starts. Escape steps must
-- never extend this corridor, otherwise following a target expands it forever.
function Movement.corridor(history, position)
    local path, distances = {}, {}
    for _, p in ipairs(history) do
        if p.z == position.z then path[#path + 1] = { x = p.x, y = p.y, z = p.z } end
    end
    path[#path + 1] = { x = position.x, y = position.y, z = position.z }
    for _, p in ipairs(path) do
        for x = -4, 4 do for y = -4, 4 do
            local k = key({ x = p.x + x, y = p.y + y, z = p.z })
            distances[k] = math.min(distances[k] or math.huge, math.max(math.abs(x), math.abs(y)))
        end end
    end
    return {
        first = path[1], last = path[#path],
        distance = function(p)
            if p.z ~= position.z then return math.huge end
            if distances[key(p)] then return distances[key(p)] end
            local nearest = math.huge
            for _, q in ipairs(path) do nearest = math.min(nearest, distance(p, q)) end
            distances[key(p)] = nearest
            return nearest
        end
    }
end

function Movement.choose(position, target, monsters, desired, config)
    local safe, walls, statistics = {}, {}, {}
    local routeDistance = config.routeDistance or function() return 0 end
    local routeLimit = config.emergencyDetour and 6 or math.max(4, routeDistance(position))
    local function enterable(p)
        local k = key(p)
        if safe[k] == nil then
            safe[k] = routeDistance(p) <= routeLimit and config.walkable(p) == true
        end
        return safe[k]
    end
    local function wall(p)
        local k = key(p)
        if walls[k] == nil then walls[k] = config.wall(p) == true end
        return walls[k]
    end
    local function geometry(p)
        local k = key(p)
        if statistics[k] then return statistics[k] end
        local exits, cardinalWalls, diagonalWalls, outerWalls = 0, 0, 0, 0
        for index, d in ipairs(directions) do
            local neighbor = { x = p.x + d[1], y = p.y + d[2], z = p.z }
            if enterable(neighbor) then exits = exits + 1 end
            if wall(neighbor) then
                if index <= 4 then cardinalWalls = cardinalWalls + 1
                else diagonalWalls = diagonalWalls + 1 end
            end
        end
        for x = -2, 2 do for y = -2, 2 do
            if math.max(math.abs(x), math.abs(y)) == 2 and
                wall({ x = p.x + x, y = p.y + y, z = p.z }) then outerWalls = outerWalls + 1 end
        end end
        local value = { score = exits * 4 - cardinalWalls * 14 - diagonalWalls * 6 - outerWalls,
            risk = cardinalWalls * 2 }
        if exits < 3 then value.score = value.score - (3 - exits) * 55 end
        statistics[k] = value
        return value
    end
    local function nearestMonster(p)
        local nearest = math.huge
        for _, monster in ipairs(monsters) do
            nearest = math.min(nearest, distance(p, monster))
        end
        return nearest
    end

    local queue = { { position = position, depth = 0, risk = 0 } }
    local seen, head, best = { [key(position)] = true }, 1, nil
    local dangerRange = math.min(2, desired)
    local maximumRange = math.max(desired + 3, distance(position, target) + 1)
    local availableClearance = 0
    for index, d in ipairs(directions) do
        local p = { x = position.x + d[1], y = position.y + d[2], z = position.z }
        local corner = index > 4 and
            wall({ x = p.x, y = position.y, z = p.z }) and
            wall({ x = position.x, y = p.y, z = p.z })
        if not corner and enterable(p) and distance(p, target) <= maximumRange and
            (config.emergencyDetour or routeDistance(position) <= 4 or routeDistance(p) <= routeDistance(position)) and
            (not config.rejected or not config.rejected(p)) then
            availableClearance = math.max(availableClearance, nearestMonster(p))
        end
    end
    -- Safety outranks exact target range: if any exit avoids melee with the
    -- pack, do not step adjacent to another monster for a prettier endpoint.
    -- In a genuine trap/narrow passage, use the best clearance still possible.
    local firstClearance = math.min(dangerRange, availableClearance)
    while head <= #queue and head <= 400 do
        local node = queue[head]
        head = head + 1
        if node.depth > 0 then
            local range, room = distance(node.position, target), geometry(node.position)
            local nearest = nearestMonster(node.position)
            local firstRange, firstRoom = distance(node.step, target), geometry(node.step)
            local firstNearest = nearestMonster(node.step)
            local score = -math.abs(range - desired) * 90 - math.max(0, desired - range) * 30 +
                room.score - node.depth * 10 - node.risk -
                math.max(0, dangerRange - nearest) * 90 -
                math.min((config.visits and config.visits(node.position)) or 0, 8) * 7
            -- We execute only the FIRST step of a plan. A good endpoint cannot
            -- justify stepping closer to an attacker on the way there. Score
            -- immediate range, all attackers and escape room separately.
            score = score - math.abs(firstRange - desired) * 100 -
                math.max(0, desired - firstRange) * 60 -
                math.max(0, dangerRange - firstNearest) * 220 + firstRoom.score * 0.6 -
                math.min((config.visits and config.visits(node.step)) or 0, 12) * 10
            if config.routeDistance then
                score = score - routeDistance(node.position) * 12
                if routeLimit > 4 then score = score - routeDistance(node.position) * 150 end
            end
            if config.patrolGoal then score = score - distance(node.position, config.patrolGoal) * 4 end
            -- A diagonal must improve safety/range substantially to outweigh a
            -- straight step. Charge later diagonals too: short diagonal paths
            -- must not win just because BFS reaches the same range sooner.
            if node.diagonal then score = score - 50 end
            score = score - (node.diagonalSteps or 0) * 10
            if node.direction == config.lastDirection then score = score + 20 end
            if config.lastDirection and node.direction == opposite[config.lastDirection] then score = score - 65 end
            if not best or score > best.score then
                best = { direction = node.direction, position = node.step,
                    destination = node.position, score = score }
            end
        end
        if node.depth < 8 then
            for index, d in ipairs(directions) do
                local p = { x = node.position.x + d[1], y = node.position.y + d[2], z = position.z }
                local k = key(p)
                local returning = routeDistance(node.position) > 4
                local rejected = node.depth == 0 and config.rejected and config.rejected(p)
                if not rejected and (node.depth > 0 or nearestMonster(p) >= firstClearance) and
                    not seen[k] and distance(p, target) <= maximumRange and enterable(p) and
                    (config.emergencyDetour or not returning or routeDistance(p) <= routeDistance(node.position)) then
                    -- Do not cut diagonally through two solid corner tiles.
                    local corner = index > 4 and
                        wall({ x = node.position.x + d[1], y = node.position.y, z = p.z }) and
                        wall({ x = node.position.x, y = node.position.y + d[2], z = p.z })
                    if not corner then
                        seen[k] = true
                        local room = geometry(p)
                        queue[#queue + 1] = { position = p, depth = node.depth + 1,
                            risk = node.risk + room.risk + math.max(0, desired - distance(p, target)) * 4 +
                                math.max(0, dangerRange - nearestMonster(p)) * 35,
                            direction = node.direction or d[3], step = node.step or p,
                            diagonalSteps = (node.diagonalSteps or 0) + (index > 4 and 1 or 0),
                            diagonal = node.depth == 0 and index > 4 or node.diagonal }
                    end
                end
            end
        end
    end
    -- Rejections expire quickly, and may all describe transient creature/walk
    -- locks. If no alternative exists, revalidate the map and retry a real
    -- walkable exit rather than waiting for every exclusion to expire.
    if not best and config.rejected then
        local retryConfig = {}
        for k, v in pairs(config) do if k ~= 'rejected' then retryConfig[k] = v end end
        return Movement.choose(position, target, monsters, desired, retryConfig)
    end
    -- The route boundary is virtual terrain, not a physical wall. If all
    -- normal exits are occupied, permit a bounded two-SQM sidestep around the
    -- blockage. Never grow the frozen path, cross a hole or drift indefinitely.
    -- On the next tick the normal recovery preference leads back to the route.
    if not best and config.routeDistance and not config.emergencyDetour and
        routeDistance(position) <= 6 then
        local detourConfig = {}
        for k, v in pairs(config) do detourConfig[k] = v end
        detourConfig.emergencyDetour = true
        return Movement.choose(position, target, monsters, desired, detourConfig)
    end
    return best
end
