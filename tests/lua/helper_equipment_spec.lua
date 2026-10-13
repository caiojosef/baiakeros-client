-- Exercise the real equipment controller and the existing Helper cooldown APIs.
PlayerStates={Pz=1,PzBlock=8192,ManaShield=16,NewManaShield=67108864}
InventorySlotNeck,InventorySlotFinger=2,9
local now,hp,voc,pz,shield,name=1000,20,14,false,false,'Equipment Test'
local skull,pzLock=0,false
local worn,counts,equips,casts,potions,saved={},{},{},{},{},{}
local p={getName=function()return name end,getVocation=function()return voc end,
    getLevel=function()return 500 end,getHealth=function()return hp*10 end,getMaxHealth=function()return 1000 end,
    getHealthPercent=function()return hp end,getMana=function()return 500 end,getMaxMana=function()return 1000 end,
    getInventoryCount=function(_,id)return counts[id] or 0 end,getInventoryItem=function(_,slot)return worn[slot] end,
    getSkull=function()return skull end,
    hasState=function(_,state)
        if state==PlayerStates.Pz then return pz end
        if state==PlayerStates.PzBlock then return pzLock end
        return shield
    end}
g_clock={millis=function()return now end}
g_game={isOnline=function()return true end,getLocalPlayer=function()return p end,
    equipItemId=function(id,tier)assert(tier==0);equips[#equips+1]=id end,
    talk=function(words)casts[#casts+1]=words end,
    useInventoryItemWith=function(id,target)assert(target==p);potions[#potions+1]=id end}
g_settings={save=function()end,getNode=function(key)return saved[key] end,setNode=function(key,value)
    local copy={};for k,v in pairs(value)do copy[k]={enabled=v.enabled,itemId=v.itemId,percent=v.percent,mode=v.mode}end;saved[key]=copy end}
SpellInfo={Default={
    ['Magic Shield']={id=44,words='utamo vita',level=14,mana=50,exhaustion=14000,group={[3]=2000}},
    ['Cancel Magic Shield']={id=245,words='exana vita',level=14,mana=50,exhaustion=2000,group={[3]=2000}}}}
modules={}
dofile('modules/game_baiakeros_helper/helper.lua')
local legacy={playerConfigPrefix=playerConfigPrefix,isManualActionPending=isManualActionPending,
    tryCastEquipmentShield=tryCastEquipmentShield,tryUseEquipmentShieldPotion=tryUseEquipmentShieldPotion}
modules.game_baiakeros_helper=legacy
dofile('modules/game_baiakeros_helper_v2/equipment_catalog.lua')
dofile('modules/game_baiakeros_helper_v2/equipment.lua')
local e=BaiakHelperEquipmentV2
modules.game_baiakeros_helper_v2={BaiakHelperEquipmentV2=e}
local items={};for _,item in ipairs(BaiakHelperEquipmentCatalog)do items[item.id]=item end
assert(e.canEquip(items[3081],p) and e.canEquip(items[3048],p),'universal equipment')
assert(e.canEquip(items[23531],p) and not e.canEquip(items[23529],p),'ED filters plasma vocation')
voc=12;assert(e.canEquip(items[23529],p) and not e.canEquip(items[23531],p),'RP filters plasma vocation')
voc=15;assert(e.canEquip(items[50150],p) and not e.canEquip(items[23529],p),'Monk filters orange plasma')
voc=14;e.onGameStart()
local function selected(id)return {getId=function()return id end}end
assert(not e.selectItem('lowRing',selected(3081)),'ring rejects amulet')
assert(not e.selectItem('lowAmulet',selected(3048)),'amulet rejects ring')
assert(not e.selectItem('lowRing',selected(266)),'equipment rejects potions')
assert(not e.selectItem('lowRing',selected(23529)),'picker rejects wrong vocation')
assert(e.selectItem('lowRing',selected(3048)),'picker accepts compatible ring')
assert(e.selectItem('lowAmulet',selected(3081)),'picker accepts compatible amulet')

e.setRule('lowAmulet',{itemId=3081,enabled=true,percent=30})
e.setRule('highAmulet',{itemId=3057,enabled=true,percent=70})
counts[3081]=2;counts[3057]=1
e.checkEquipment();assert(#equips==1 and equips[1]==3081)
e.checkEquipment();assert(#equips==1,'no duplicate equip before inventory confirmation')
now=2000;worn[2]={getId=function()return 3081 end};e.checkEquipment();assert(#equips==1,'worn SSA remains equipped')
worn[2]=nil;e.checkEquipment();assert(#equips==2,'consumed SSA is replenished')
counts[3081]=0;now=3000;e.checkEquipment();assert(#equips==2,'empty backpack emits no equip')
hp=50;e.checkEquipment();assert(#equips==2,'gap holds current equipment')
hp=80;e.checkEquipment();assert(equips[3]==3057,'high HP restores regular gear')
now=4000;e.setRule('highRing',{itemId=23531,enabled=true});counts[23531]=1
worn[9]={getId=function()return 23532 end};e.checkEquipment();assert(#equips==4 and equips[4]==3057,'active plasma must never be toggled')
now=5000;notifyManualAction('item');worn[9]=nil;e.checkEquipment();assert(#equips==4,'manual hotkey priority')
now=6000;hp=20;e.setRule('highAmulet',{percent=10});counts[3081]=1;e.checkEquipment();assert(equips[5]==3081,'overlapping ranges prefer emergency')
e.onGameEnd();name='Another Character';e.onGameStart();now=7000;e.checkEquipment();assert(#equips==5,'character settings are isolated')
name='Equipment Test';e.onGameStart();now=8000;e.checkEquipment();assert(#equips==6,'relogin restores equipment rules')
-- Use the actual server packet handlers to drive the shield fallback.
local function callback(key)
    for i=1,100 do local n,v=debug.getupvalue(init,i);if n==key then return v end end
    error('missing '..key)
end
local cooldown=callback('onSpellCooldown')
local group=callback('onSpellGroupCooldown')
e.setRule('shield',{enabled=true});e.setRule('cancel',{enabled=true});e.setRule('potion',{enabled=true})
counts[35563]=5;e.checkShield();assert(casts[1]=='utamo vita' and #potions==0,'spell before shield potion')
e.checkShield();assert(#casts==1 and #potions==0,'wait for shield state packet')
now=9000;shield=true;e.checkShield();assert(#casts==1 and #potions==0,'active shield is not renewed every tick')
shield=false;nextPotionAt=now+1000;e.checkShield();assert(#potions==0,'shared life/mana potion cooldown respected')
now=10000;e.checkShield();assert(potions[1]==35563,'broken shield falls back while utamo is cooling down')
now=11000;cooldown(44,0);group(3,2000);e.checkShield();assert(#potions==1,'support group alone is not a reason to waste potion')
now=14000;group(3,0);e.checkShield();assert(casts[2]=='utamo vita','authoritative cooldown reset allows cast')
now=15000;shield=true;hp=95;group(3,0);e.checkShield();assert(casts[3]=='exana vita','cancel above chosen HP')
now=17000;pz=true;shield=false;hp=20;e.checkShield();assert(#casts==3 and #potions==1,'PZ blocks spells and shield potion')
pz=false;notifyManualAction('spell');e.checkShield();assert(#casts==3 and #potions==1,'manual cast priority applies to shield fallback')
now=18000;voc=11;e.checkShield();assert(#casts==3,'nonmages never cast shield')
-- Actual healing scheduler: life potion wins, shield fallback precedes mana,
-- and disabling healing does not disable separately enabled shield rules.
voc=14;now=30000;hp=20;p.isPartyMember=function()return false end
modules.game_interface={getMapPanel=function()return {getSpectators=function()return {}end}end}
local rows={potionSlot1={assignedPotion={id=266,name='Health potion'},threshold=30,resource='health'},
    potionSlot2={assignedPotion={id=268,name='Mana potion'},threshold=80,resource='mana'}}
helperWindow={recursiveGetChildById=function(_,id)return rows[id] end}
e.setRule('shield',{enabled=false});cooldown(44,14000);nextPotionAt=0
local healing=callback('checkHealing')
healing();assert(potions[#potions]==266,'life potion precedes shield and mana')
rows.potionSlot1=nil;now=31000;healing();assert(potions[#potions]==35563,'shield fallback precedes mana potion')
healingEnabled=false;now=32000;healing();assert(potions[#potions]==35563,'shield independent of healing enable')
local beforeEquip,beforeCast,beforePotion=#equips,#casts,#potions
-- PZ lock disables all seven saved rules, including shield, even while a
-- manual hotkey guard is active. It must not re-enable after relogging.
e.setRule('shield',{enabled=true});e.setRule('cancel',{enabled=true})
pzLock=true;notifyManualAction('item');e.checkEquipment();e.checkShield()
local key=playerConfigPrefix()..'_equipment_v1'
for _,rule in pairs(saved[key])do assert(not rule.enabled,'PZ lock disables every saved rule')end
assert(#equips==beforeEquip and #casts==beforeCast and #potions==beforePotion,'no actions under PZ lock')
e.setRule('lowRing',{itemId=3048,enabled=true});e.setRule('shield',{enabled=true})
assert(not saved[key].lowRing.enabled and not saved[key].shield.enabled,'API cannot bypass locked checkboxes')
e.onGameEnd();e.onGameStart();assert(not saved[key].lowAmulet.enabled,'lock persists over relog')
pzLock=false;now=34000;e.checkEquipment();e.checkShield()
assert(#equips==beforeEquip and #casts==beforeCast and #potions==beforePotion,'unlock never automatically resumes')
e.setRule('lowAmulet',{enabled=true});e.setRule('shield',{enabled=true})
assert(saved[key].lowAmulet.enabled and saved[key].shield.enabled,'unlock permits explicit reactivation')
skull=2;e.updateCombatLock()
e.setRule('shield',{enabled=true});assert(saved[key].shield.enabled,'party green skull permits utamo activation')
pzLock=true;e.updateCombatLock();assert(not saved[key].shield.enabled,'party still respects real PvP lock')
pzLock=false;skull=3;e.updateCombatLock()
for _,rule in pairs(saved[key])do assert(not rule.enabled,'skull disables every rule')end
e.setRule('highAmulet',{enabled=true});assert(not saved[key].highAmulet.enabled,'skull prevents enable')
skull=0;e.updateCombatLock();e.setRule('highAmulet',{enabled=true})
assert(saved[key].highAmulet.enabled,'cleared skull permits enable')
pz=true;e.updateCombatLock();assert(saved[key].highAmulet.enabled,'safe-zone icon is distinct from combat PZ lock')
pz=false;now=60000;hp=100;shield=false;voc=14
cooldown(44,0);group(3,0)
e.setRule('shield',{enabled=true,mode='always'});e.setRule('cancel',{enabled=true})
local initial=#casts;e.checkShield();assert(casts[#casts]=='utamo vita' and #casts==initial+1,'always mode casts at full HP')
shield=true;now=62000;group(3,0);e.checkShield();assert(#casts==initial+1,'always mode suppresses exana')
shield=false;now=80000;cooldown(44,0);e.checkShield();assert(#casts==initial+2,'always mode renews expired shield')
hp=0;pzLock=true;e.updateCombatLock();e.onGameEnd();e.onGameStart()
assert(saved[key].shield.enabled and saved[key].shield.mode=='always','death preserves shield preference and mode')
pzLock=false;hp=100;e.updateCombatLock();now=100000;cooldown(44,0);group(3,0);e.checkShield()
assert(#casts==initial+3,'restored always mode casts after revival')
print('helper_equipment_spec: PASS - vocation filters, transformed rings, replacements, persistence and shared cooldowns')
