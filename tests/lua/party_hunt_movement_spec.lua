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
-- Direction uses screen coordinates, with safety and the six-SQM bound.
holes={}
local orbitStart={x=100,y=104,z=7}
local cw=assert(M.orbit(orbitStart,box,{},2,safe,true))
local ccw=assert(M.orbit(orbitStart,box,{},2,safe,false))
assert(cw.step.x<orbitStart.x and cw.clockwise==true, 'clockwise moves left from below the box')
assert(ccw.step.x>orbitStart.x and ccw.clockwise==false, 'heavy pressure reverses the orbit')
assert(M.distance(cw.position,box)==3 and M.distance(ccw.position,box)==3,'unobstructed orbit returns to three SQMs')
local reverse=assert(M.orbit(orbitStart,box,{},2,function(q)return q.x>=100 and safe(q)end,true))
assert(reverse.clockwise==false and reverse.step.x>100,'blocked clockwise side must use the free reverse side')
local trapped=M.orbit(orbitStart,box,{},2,function()return false end,true)
assert(not trapped or not trapped.step,'an enclosed follower must not issue an impossible step')
-- Explicit cardinal slots use distance and reachability rather than maximizing wave coverage.
for _,case in ipairs({{100,97,South},{103,100,West},{100,103,North},{97,100,East}})do
 local origin={x=case[1],y=case[2],z=7}
 local choice=assert(M.cardinal(origin,box,{},3,safe))
 assert(M.same(choice.position,origin) and not choice.step and choice.facing==case[3],
  'keep the closest north/east/south/west slot and face the box')
end
local diagonal=assert(M.cardinal({x=103,y=103,z=7},box,{},3,safe))
assert((diagonal.position.x==box.x or diagonal.position.y==box.y) and M.distance(diagonal.position,box)==3)
-- A wall's shadow must not be mistaken for a valid formation at the right radius.
local function visible(q)return not (q.x>102 and q.y>100)end
local hidden={x=104,y=104,z=7}
local recovery=assert(M.follow(hidden,box,3,{},safe,visible))
assert(recovery.step and visible(recovery.position) and M.distance(recovery.position,box)<=5,
 'recover sight even if already standing at the desired distance behind a wall')
local slot=assert(M.cardinal(hidden,box,{},4,safe,visible))
assert(visible(slot.position) and M.distance(slot.position,box)==4,
 'spell formation must face a visible box from a reachable cardinal slot')
local sightOrbit=assert(M.orbit(orbitStart,box,{},2,safe,false,visible))
assert(visible(sightOrbit.position) and visible(sightOrbit.step),'orbit never enters the wall shadow')
local normal=assert(M.orbit(orbitStart,box,{},2,safe,true))
local pressured=assert(M.orbit(orbitStart,box,{},3,safe,true))
local heavy=assert(M.orbit(orbitStart,box,{},4,safe,true))
assert(M.distance(normal.position,box)==3 and M.distance(pressured.position,box)==4 and M.distance(heavy.position,box)==5,
 'higher pressure widens the orbit from three to four to five SQMs')
local orbitPoint={x=100,y=103,z=7}
local quadrants={}
for i=1,48 do
 local choice=assert(M.orbit(orbitPoint,box,{},2,safe,true))
 assert(choice.step and choice.clockwise,'open orbit must keep moving clockwise')
 local dx,dy=orbitPoint.x-box.x,orbitPoint.y-box.y
 local cross=dx*(choice.step.y-box.y)-dy*(choice.step.x-box.x)
 assert(cross>=0 and M.distance(choice.step,box)>=3 and M.distance(choice.step,box)<=5,
  'the next step itself must rotate instead of cutting inward or reversing')
 orbitPoint=choice.step
 quadrants[(orbitPoint.x>=box.x and 'E' or 'W')..(orbitPoint.y>=box.y and 'S' or 'N')]=true
end
assert(quadrants.ES and quadrants.EN and quadrants.WS and quadrants.WN,'a continuous orbit must pass all four sides of the box')
print('Party Hunt movement passed: full box waves, spell repositioning, UE, escape, holes, visible formations, wall recovery, pressure radius 3/4/5 and clockwise/reverse orbit')
