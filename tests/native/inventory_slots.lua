local result={checks={},errors={},result='RUNNING'}
local function save()g_resources.writeFileContents('/result.json',json.encode(result))end
local function check(value,label)assert(value,label);result.checks[#result.checks+1]=label end
InventorySlotQaLogger=function(level,message)
    if level>=LogError then result.errors[#result.errors+1]=tostring(message);save()end
end
g_logger.setOnLog(InventorySlotQaLogger)
scheduleEvent(function()
 local ok,err=pcall(function()
    local inventory=assert(modules.game_inventory)
    local controller=assert(inventory.inventoryController)
    local layout={'MainWindow','  id: inventorySlotPreview','  text: Equipment slot silhouettes','  size: 550 260'}
    local slotNames={'helmet','amulet','backpack','armor','shield','sword','legs','boots','ring','tools'}
    local labels={'Head','Neck','Backpack','Armor','Right hand / quiver','Left hand / weapon','Legs','Feet','Ring','Ammo / tools'}
    for i,name in ipairs(slotNames)do
        local x=10+((i-1)%5)*100
        local y=math.floor((i-1)/5)*85
        layout[#layout+1]=string.format('  MainInventoryItem\n    id: %s\n    anchors.left: parent.left\n    anchors.top: parent.top\n    margin-left: %d\n    margin-top: %d',name,x+22,y)
        layout[#layout+1]=string.format('  Label\n    text: %s\n    anchors.left: parent.left\n    anchors.top: parent.top\n    margin-left: %d\n    margin-top: %d\n    width: 100\n    text-align: center',labels[i],x-10,y+40)
    end
    local preview=g_ui.loadUIFromString(table.concat(layout,'\n'),g_ui.getRootWidget())
    assert(preview,'Preview UI did not load')
    controller.ui.onPanel=preview
    local update
    for i=1,30 do local name,value=debug.getupvalue(inventory.reloadInventory,i);if name=='inventoryEvent'then update=value end end
    assert(update,'Inventory callback not found')
    local ui=controller.ui.onPanel
    local names={'helmet','amulet','backpack','armor','shield','sword','legs','boots','ring','tools'}
    local item=assert(Item.create(34088))
    local fake={isMonk=function()return false end,getInventoryItem=function()return nil end}
    local original=g_game.getLocalPlayer
    g_game.getLocalPlayer=function()return fake end
    for slot,name in ipairs(names)do
        local panel=assert(ui[name]);local hint=assert(panel[name])
        panel.item:setImageSource('/images/ui/rarity_frames')
        panel.item:setImageClip('0 0 32 32')
        update(fake,slot,nil)
        check(panel.item:getImageSource()==''and hint:isEnabled(),name..' empty after market-price frame')
        check(g_resources.fileExists(hint:getImageSource()..'.png'),name..' silhouette asset exists')
        for rank=1,4 do
            item:setRarity(rank);update(fake,slot,item)
            check(not hint:isEnabled()and panel.item:getBorderTopWidth()==1,name..' equipped rarity '..rank)
            update(fake,slot,nil)
            check(hint:isEnabled()and panel.item:getImageSource()==''and panel.item:getBorderTopWidth()==0,name..' empty after rarity '..rank)
        end
    end
    fake.isMonk=function()return true end
    g_game.enableFeature(GameVocationMonk)
    item:setRarity(4)
    update(fake,InventorySlotLeft,item)
    check(not ui.shield.shield:isEnabled()and ui.shield.item:getOpacity()==0.5,'Monk mirrored weapon remains visible')
    check(ui.shield.item:getBorderTopWidth()==1,'Monk mirror inherits item rarity')
    update(fake,InventorySlotLeft,nil)
    check(ui.shield.shield:isEnabled()and ui.shield.item:getImageSource()==''and ui.shield.item:getBorderTopWidth()==0,'Monk right-hand silhouette returns after unequipping')
    g_game.getLocalPlayer=original
    preview:show()
    preview:raise()
    if modules.client_entergame.EnterGame then modules.client_entergame.EnterGame.hide()end
    result.result='PASS'
 end)
 if not ok then result.errors[#result.errors+1]=tostring(err);result.result='FAIL'end
 save()
 scheduleEvent(function()g_app.doScreenshot('/empty-slots.png')end,700)
 scheduleEvent(function()g_logger.setOnLog(nil);g_app.exit()end,1600)
end,5000)
