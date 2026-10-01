-- Pure geometry and reachability regression; no live character is moved.
North, East, South, West = 0, 1, 2, 3
NorthEast, SouthEast, SouthWest, NorthWest = 4, 5, 6, 7
dofile('modules/game_baiakeros_helper_v2/party_hunt_movement.lua')
local M = PartyHuntMovement
local box = { x = 100, y = 100, z = 7 }
local monsters = {}
for x = -1, 1 do
    for y = -1, 1 do
        if x ~= 0 or y ~= 0 then monsters[#monsters + 1] = { x = 100 + x, y = 100 + y, z = 7 } end
    end
end
local holes = {}
local function safe(p)
    if p.x < 93 or p.x > 107 or p.y < 93 or p.y > 107 or p.z ~= 7 then return false end
    if p.x == 100 and p.y == 100 then return false end -- Knight occupies the box.
    return not holes[p.x .. ':' .. p.y]
end
local earth = { words = 'exevo tera hur', profile = { shape = 'directional' }, offsets = {
    {0,-1}, {0,-2}, {-1,-3}, {0,-3}, {1,-3}, {-1,-4}, {0,-4}, {1,-4}, {-1,-5}, {0,-5}, {1,-5}
} }
local ice = { words = 'exevo gran frigo hur', profile = { shape = 'directional' }, offsets = {
    {0,-1}, {-1,-2}, {0,-2}, {1,-2}, {-1,-3}, {0,-3}, {1,-3}, {-1,-4}, {0,-4}, {1,-4}
} }
local ue = { words = 'exevo gran mas frigo', profile = { shape = 'circle', radius = 5, manhattan = 5 } }
local p = { x = 100, y = 102, z = 7 }
for _ = 1, 6 do
    local choice = assert(M.combat(p, box, monsters, earth, 2, safe))
    if choice.step then p = choice.step end
end
assert(p.y == 104 and p.x == 100, 'the ED must put the complete box in the widest part of Earth Wave')
assert(M.coverage(earth, p, box, monsters).boxCount == 8)
local iceChoice = assert(M.combat(p, box, monsters, ice, 2, safe))
assert(iceChoice.step and iceChoice.step.y == 103 and iceChoice.facing == North,
    'the next Strong Ice Wave must move the ED one SQM toward the box')
p = iceChoice.step
assert(M.coverage(ice, p, box, monsters).boxCount == 8)
local rangedEscape = assert(M.combat(p, box, monsters, ice, 2, safe, true))
assert(rangedEscape.step and rangedEscape.threatened,
    'damage from a distant attacker must trigger a safe sidestep even when the range threshold is met')
local ueChoice = assert(M.combat(p, box, monsters, ue, 2, safe))
assert(not ueChoice.step and ueChoice.boxCount == 8,
    'the ED must keep a safe position when its ultimate spell already hits the whole box')

-- An attacker near the ED forces an escape, while reachable positions still
-- favour box coverage over a loose monster outside the knight's pack.
monsters[#monsters + 1] = { x = 101, y = 103, z = 7 }
local escape = assert(M.combat(p, box, monsters, earth, 2, safe))
assert(escape.threatened and escape.step and safe(escape.step))
assert(M.distance(escape.position, monsters[9]) >= 2 and escape.boxCount == 8,
    'escape planning must preserve range from the attacker and full box coverage')
holes[escape.step.x .. ':' .. escape.step.y] = true
local alternative = assert(M.combat(p, box, monsters, earth, 2, safe))
assert(not alternative.step or safe(alternative.step), 'holes must never be chosen as escape steps')

local follow = assert(M.follow({ x = 100, y = 106, z = 7 }, box, 2, {}, safe))
assert(follow.step and follow.step.y < 106, 'the ED must follow a walking knight')
local near = M.follow({ x = 100, y = 102, z = 7 }, box, 2, {}, safe)
assert(not near.step, 'follow must stop at the selected formation distance')
local blocked = M.combat(p, box, monsters, earth, 2, function() return false end)
assert(not blocked or not blocked.step, 'a fully blocked ED must not walk into an occupied tile')
assert(M.distance(p, { x = p.x, y = p.y, z = 6 }) == math.huge)
print('Party Hunt movement passed: full box waves, spell repositioning, UE, escape, holes, follow distance')
