-- Run with LuaJIT from the repository root; no UI or login is needed.
local function read(path)
 local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s
end
local source=read('modules/gamelib/spells.lua')
local start=assert(source:find('local function getSpellIconOverride(',1,true))
Spells={}
SpelllistSettings={Default={iconFile='atlas32',iconsForGameCooldown='atlas20',iconSize={width=32,height=32},iconSizeCooldown={width=20,height=22}}}
assert(loadstring(source:sub(start)))()
for i=0,200 do
 local image=Spells.getIconFileByProfile('Default',i)
 local small=Spells.getCooldownIconFileByProfile('Default',i)
 local clip=Spells.getImageClip(i,'Default')
 local smallClip=Spells.getImageClipCooldown(i,'Default')
 if i==186 then
  assert(image:find('thousand-fist-blows-official',1,true) and small==image)
  assert(clip=='3 3 32 32' and smallClip==clip)
 else
  assert(image=='atlas32' and small=='atlas20')
  assert(clip==(i*32)..' 0 32 32' and smallClip==(i*20)..' 0 20 22')
 end
end
local png=read('data/images/game/spells/thousand-fist-blows-official.png')
assert(png:sub(1,8)=='\137PNG\13\10\26\10')
local assignment=read('modules/game_actionbar/logics/ActionAssignmentWindows.lua')
local a=assert(assignment:find('local function canEquipItem(item)',1,true))
local b=assert(assignment:find('function assignItem(',a,true))
InventorySlotRight=5;GameEnterGameShowAppearance=1
local modern=true;g_game={getFeature=function()return modern end}
local canEquip=assert(loadstring(assignment:sub(a,b-1)..'\nreturn canEquipItem'))()
local function item(container,slot,classification,ammo,wearout)
 return {isContainer=function()return container end,getClothSlot=function()return slot end,
 getClassification=function()return classification or 0 end,isAmmo=function()return ammo end,hasWearout=function()return wearout end}
end
for _, value in ipairs({true,false}) do
 modern=value
 assert(canEquip(item(true,5))) -- Quiver.
 assert(not canEquip(item(true,0))) -- Backpack.
 assert(not canEquip(item(true,3))) -- Other container.
 assert(canEquip(item(false,9))) -- Ring.
end
modern=true
assert(canEquip(item(false,0,1)))
assert(canEquip(item(false,0,0,true)))
assert(canEquip(item(false,0,0,false,true)))
assert(not canEquip(item(false,0)))
print('PASS: 201 icon mappings; official PNG; 12 action-bar equipment cases')
