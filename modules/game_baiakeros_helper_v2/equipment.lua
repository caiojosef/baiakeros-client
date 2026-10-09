BaiakHelperEquipmentV2 = {}
local Equipment = BaiakHelperEquipmentV2
local panel, selector, event, characterKey
local blocked = false
local settings, updating = {}, false
local nextEquip = {necklace=0, ring=0}
local definitions = {
    {key='lowAmulet', slot='necklace', below=true, percent=30},
    {key='lowRing', slot='ring', below=true, percent=30},
    {key='highAmulet', slot='necklace', percent=70},
    {key='highRing', slot='ring', percent=70},
    {key='shield', percent=30}, {key='cancel', percent=90}, {key='potion', percent=30}
}
local byId = {}
for _, item in ipairs(BaiakHelperEquipmentCatalog) do byId[item.id] = item end
local function legacy() return modules.game_baiakeros_helper end
local function player() return g_game.getLocalPlayer() end
local function vocation(p)
    local value = tonumber(p and p:getVocation()) or 0
    local compatibility={[6]=14,[7]=12,[8]=11,[9]=5,[10]=15}
    if compatibility[value] then return compatibility[value] end
    return value
end
local function mage(p)
    local value = vocation(p)
    return value==3 or value==13 or value==4 or value==14
end
function Equipment.canEquip(item, p)
    if not item or not p or p:getLevel() < item.level then return false end
    if #item.vocations==0 then return true end
    for _, allowed in ipairs(item.vocations) do if allowed==vocation(p) then return true end end
    return false
end
local function save()
    if characterKey then
        g_settings.setNode(characterKey, settings)
        g_settings.save()
    end
end
local function closeSelector()
    if selector then selector:destroy(); selector=nil end
end
function Equipment.isCombatBlocked()
    local p=player()
    return p~=nil and ((PlayerStates.PzBlock and p:hasState(PlayerStates.PzBlock)) or
        (tonumber(p:getSkull()) or 0)~=(SkullNone or 0)) or false
end
-- Disable the saved rules, rather than silently resuming automation when the
-- skull/PZ lock disappears. Check before every action as well as state events.
function Equipment.updateCombatLock()
    local previous=blocked
    blocked=Equipment.isCombatBlocked()
    local changed=false
    if blocked then
        for _, rule in pairs(settings) do
            if rule.enabled then rule.enabled=false;changed=true end
        end
    end
    if changed then save() end
    if changed or previous~=blocked then Equipment.render() end
    return blocked
end
function Equipment.render()
    if not panel then return end
    updating=true
    local p=player()
    panel:recursiveGetChildById('shieldSection'):setVisible(mage(p))
    panel:recursiveGetChildById('nonMageNote'):setVisible(not mage(p))
    local status=panel:recursiveGetChildById('equipmentCombatStatus')
    status:setText(blocked and 'PK / PZ lock: all rules disabled. Wait for the lock to end.' or
        'PK / PZ lock disables all rules. Enable them again after it ends.')
    status:setColor(blocked and '#ed7777' or '#bbbbbb')
    for _, definition in ipairs(definitions) do
        local row=panel:recursiveGetChildById(definition.key)
        local rule=settings[definition.key]
        row:recursiveGetChildById('enabled'):setChecked(rule.enabled)
        row:recursiveGetChildById('percent'):setText(rule.percent..'%')
        row:recursiveGetChildById('enabled'):setEnabled(not blocked and mage(p))
        row:recursiveGetChildById('enabled'):setTooltip(blocked and
            'Cannot enable while you have a skull or PZ lock.' or 'Enable this rule')
        if definition.slot then
            local item=byId[rule.itemId]
            row:recursiveGetChildById('item'):setItemId(item and item.id or 0)
            row:recursiveGetChildById('name'):setText(item and item.name or 'Choose '..(definition.slot=='ring' and 'ring' or 'amulet'))
            row:recursiveGetChildById('assign'):setTooltip(item and (item.name..'\nClick to change. Right-click to clear.') or 'Click, then select an item from your backpack or equipment.')
            row:recursiveGetChildById('enabled'):setEnabled(not blocked and item~=nil and Equipment.canEquip(item,p))
        end
    end
    updating=false
end
function Equipment.setRule(key, values)
    Equipment.updateCombatLock()
    local rule=settings[key]
    if not rule then return end
    if values.itemId~=nil then
        local item=byId[tonumber(values.itemId)]
        local slot=key:find('Ring') and 'ring' or 'necklace'
        if values.itemId~=0 and (not item or item.slot~=slot or not Equipment.canEquip(item,player())) then return end
        rule.itemId=tonumber(values.itemId) or 0
        if rule.itemId==0 then rule.enabled=false end
    end
    if values.enabled~=nil then rule.enabled=values.enabled==true and not blocked end
    if values.percent then rule.percent=math.max(1,math.min(100,math.floor(tonumber(values.percent) or rule.percent))) end
    save(); Equipment.render()
end
function Equipment.selectItem(key, selected)
    local slot=key:find('Ring') and 'ring' or 'necklace'
    local item=selected and byId[selected:getId()]
    if selected and not item then
        for _, candidate in ipairs(BaiakHelperEquipmentCatalog) do
            for _, id in ipairs(candidate.variants) do
                if id==selected:getId() then item=candidate;break end
            end
            if item then break end
        end
    end
    if not item or item.slot~=slot then
        return false,slot=='ring' and 'Selecione um anel para este espaço.' or 'Selecione um amuleto para este espaço.'
    end
    if not Equipment.canEquip(item,player()) then
        return false,'Este item não é compatível com sua vocação ou nível.'
    end
    Equipment.setRule(key,{itemId=item.id})
    return true
end
function Equipment.openSelector(key)
    closeSelector()
    local slot=key:find('Ring') and 'ring' or 'necklace'
    legacy().beginHelperItemAssignment(function(item) return Equipment.selectItem(key,item) end,
        slot=='ring' and 'Clique no anel que deseja usar. Escape ou botão direito cancela.' or
        'Clique no amuleto que deseja usar. Escape ou botão direito cancela.')
end
function Equipment.onGameStart()
    closeSelector()
    characterKey=legacy().playerConfigPrefix()..'_equipment_v1'
    local saved=g_settings.getNode(characterKey) or {}
    settings={}
    for _, definition in ipairs(definitions) do
        local rule=saved[definition.key] or {}
        settings[definition.key]={enabled=rule.enabled==true or rule.enabled=='true',
            itemId=tonumber(rule.itemId) or 0,
            percent=math.max(1,math.min(100,tonumber(rule.percent) or definition.percent))}
    end
    nextEquip={necklace=0,ring=0};Equipment.updateCombatLock();Equipment.render()
end
function Equipment.onGameEnd()
    save();closeSelector();characterKey=nil
end
local function onEquipmentEligibilityChange()
    closeSelector()
    Equipment.render()
end
local function onEquipmentCombatStateChange(creature)
    if creature==player() then Equipment.updateCombatLock() end
end
function Equipment.checkEquipment()
    if not g_game.isOnline() or not characterKey then return end
    if Equipment.updateCombatLock() or legacy().isManualActionPending() then return end
    local p=player()
    if not p or p:getHealth()<=0 then return end
    local hp=p:getHealthPercent()
    local now=g_clock.millis()
    for _, slot in ipairs({'necklace','ring'}) do
        local chosen
        -- Emergency equipment wins when the user overlaps the two HP ranges.
        for _, definition in ipairs(definitions) do
            local rule=settings[definition.key]
            if definition.slot==slot and rule.enabled and
                (definition.below and hp<rule.percent or not definition.below and hp>rule.percent) and
                Equipment.canEquip(byId[rule.itemId],p) then chosen=byId[rule.itemId];break end
        end
        if chosen and now>=nextEquip[slot] then
            local worn=p:getInventoryItem(slot=='ring' and InventorySlotFinger or InventorySlotNeck)
            local matches=false
            for _, id in ipairs(chosen.variants) do if worn and worn:getId()==id then matches=true;break end end
            if not matches and p:getInventoryCount(chosen.id,0)>0 then
                g_game.equipItemId(chosen.id,0)
                nextEquip[slot]=now+750 -- Wait for the authoritative inventory update; never toggle a worn ring.
            end
        end
    end
end
function Equipment.checkShield()
    if not characterKey or Equipment.updateCombatLock() or not mage(player()) then return end
    local p=player()
    local hp=p:getHealthPercent()
    local active=p:hasState(PlayerStates.ManaShield) or p:hasState(PlayerStates.NewManaShield)
    local shield,cancel,potion=settings.shield,settings.cancel,settings.potion
    if active then
        -- The defensive threshold wins if shield/cancel ranges overlap.
        if cancel.enabled and hp>cancel.percent and not (shield.enabled and hp<shield.percent) and
            not (potion.enabled and hp<potion.percent) then
            legacy().tryCastEquipmentShield(true)
        end
    elseif (shield.enabled and hp<shield.percent) or (potion.enabled and hp<potion.percent) then
        if shield.enabled and hp<shield.percent and legacy().tryCastEquipmentShield(false) then return end
        if potion.enabled and hp<potion.percent then legacy().tryUseEquipmentShieldPotion() end
    end
end
local function tick()
    Equipment.checkEquipment()
    event=scheduleEvent(tick,150)
end
function Equipment.init(window)
    g_ui.importStyle('equipment')
    panel=g_ui.createWidget('HelperEquipmentPanel',window:recursiveGetChildById('equipmentPage'))
    panel:recursiveGetChildById('equipmentFooter'):setText('Click here, then click the item in your backpack. Right-click here to clear.\nItems must be in your backpack. Settings are saved per character.')
    panel:recursiveGetChildById('equipmentHelp'):setText('Life < %: equip below the selected health percentage.\nLife > %: equip above it, restoring your regular equipment.\n\nEnable each item with its checkbox. Replacements are equipped while the rule matches and the item is in your backpack.')
    panel:recursiveGetChildById('shieldHelp'):setText('The potion is used when utamo vita is on cooldown.\n\nLife potions remain the first priority.\n\nShield spells respect cooldowns and manual hotkeys.')
    for _, definition in ipairs(definitions) do
        local key=definition.key
        local row=g_ui.createWidget('HelperEquipmentCompactRule',panel:recursiveGetChildById(definition.slot and
            (definition.below and 'belowRules' or 'aboveRules') or 'shieldRules'))
        row:setId(key)
        row:recursiveGetChildById('enabled').onCheckChange=function(_,checked)
            if not updating then Equipment.setRule(key,{enabled=checked}) end
        end
        for _, change in ipairs({{'decrease',-1},{'increase',1}}) do
            local delta=change[2]
            row:recursiveGetChildById(change[1]).onClick=function() Equipment.setRule(key,{percent=settings[key].percent+delta}) end
        end
        local assign=row:recursiveGetChildById('assign')
        if definition.slot then
            assign.onClick=function() Equipment.openSelector(key) end
            assign.onMouseRelease=function(_,_,button)
                if button==MouseRightButton then Equipment.setRule(key,{itemId=0});return true end
            end
        else
            assign:setEnabled(false)
            row:recursiveGetChildById('name'):setText(key=='shield' and 'utamo vita - HP below' or
                key=='cancel' and 'exana vita - HP above' or 'Shield potion - HP below')
            if key=='potion' then row:recursiveGetChildById('item'):setItemId(35563)
            else
                local spell=SpellInfo.Default[key=='shield' and 'Magic Shield' or 'Cancel Magic Shield']
                local icon=row:recursiveGetChildById('spell')
                icon:setImageSource(Spells.getIconFileByProfile('Default'))
                icon:setImageClip(Spells.getImageClip(spell.clientId,'Default'))
                icon:show()
            end
        end
    end
    Equipment.onGameStart();if not g_game.isOnline() then characterKey=nil end
    connect(LocalPlayer,{onVocationChange=onEquipmentEligibilityChange,onLevelChange=onEquipmentEligibilityChange})
    connect(LocalPlayer,{onStatesChange=onEquipmentCombatStateChange})
    connect(Creature,{onSkullChange=onEquipmentCombatStateChange})
    tick()
end
function Equipment.terminate()
    disconnect(LocalPlayer,{onVocationChange=onEquipmentEligibilityChange,onLevelChange=onEquipmentEligibilityChange})
    disconnect(LocalPlayer,{onStatesChange=onEquipmentCombatStateChange})
    disconnect(Creature,{onSkullChange=onEquipmentCombatStateChange})
    Equipment.onGameEnd()
    if event then removeEvent(event);event=nil end
    if panel then panel:destroy();panel=nil end
end
