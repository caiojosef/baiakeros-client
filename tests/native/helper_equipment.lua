scheduleEvent(function()
    local module=modules.game_baiakeros_helper_v2
    local original=g_game.getLocalPlayer
    local voc,skull,pzLock=14,0,false
    local fake={getId=function()return 2 end,getName=function()return 'Equipment QA' end,
        getVocation=function()return voc end,getLevel=function()return 500 end,isPremium=function()return true end,
        getMana=function()return 5000 end,getMaxMana=function()return 5000 end,
        getHealth=function()return 1000 end,getMaxHealth=function()return 1000 end,getHealthPercent=function()return 100 end,
        getSkull=function()return skull end,
        hasState=function(_,state)return state==PlayerStates.PzBlock and pzLock end,getInventoryItem=function()return nil end,isMonk=function()return false end,
        isPartyMember=function()return false end}
    g_game.getLocalPlayer=function()return fake end
    local ok,err=pcall(function()
        module.BaiakHelperEquipmentV2.onGameStart()
        module.showHelperV2Tab('equipment')
        module.helperV2Window:show();module.helperV2Window:raise()
        modules.client_entergame.EnterGame.hide()
        module.BaiakHelperEquipmentV2.setRule('lowAmulet',{itemId=3081,enabled=true})
        module.BaiakHelperEquipmentV2.setRule('highRing',{itemId=23531,enabled=true})
        scheduleEvent(function()
            local good,message=pcall(function()
                local w=module.helperV2Window
                local page=w:recursiveGetChildById('equipmentPage')
                assert(page:isVisible())
                local a,b,c=w:recursiveGetChildById('attackTab'),w:recursiveGetChildById('equipmentTab'),w:recursiveGetChildById('cavebotTab')
                assert(a:getPosition().x<b:getPosition().x and b:getPosition().x<c:getPosition().x,'tab order')
                assert(page:recursiveGetChildById('shieldSection'):isVisible(),'mage controls')
                local shieldSection,footer=page:recursiveGetChildById('shieldSection'),page:recursiveGetChildById('equipmentFooter')
                assert(footer:getPosition().y>shieldSection:getPosition().y+shieldSection:getHeight(),'footer does not cross the shield border')
                assert(footer:getPosition().y+footer:getHeight()<=page:getPosition().y+page:getHeight(),'footer fits the equipment page')
                module.showHelperV2Tab('cavebot')
                local status=w:recursiveGetChildById('v2CavebotStatus')
                local script=w:recursiveGetChildById('v2CavebotScriptHomeSlot')
                local runtime=w:recursiveGetChildById('v2CavebotRuntimeColumn')
                assert(not status:isVisible(),'Cavebot has no status footer')
                assert(script:getPosition().y+script:getHeight()==runtime:getPosition().y+runtime:getHeight()-6,'waypoints use the former status area')
                module.showHelperV2Tab('equipment')
                for _,key in ipairs({'lowAmulet','lowRing','highAmulet','highRing','shield','cancel','potion'}) do
                    local row=page:recursiveGetChildById(key)
                    assert(row:getHeight()==64)
                    local name,check=row:recursiveGetChildById('name'),row:recursiveGetChildById('enabled')
                    assert(name:getPosition().y+name:getHeight()<=check:getPosition().y,'name above compact controls '..key)
                    assert(check:getPosition().x+check:getWidth()<row:getPosition().x+row:getWidth(),'checkbox fits compact column '..key)
                    local slot,value=row:recursiveGetChildById('assign'),row:recursiveGetChildById('value')
                    assert(value:getPosition().y+value:getHeight()==slot:getPosition().y+slot:getHeight(),'percentage aligns with icon bottom '..key)
                    assert(row:recursiveGetChildById('increase'):getPosition().x+16<row:getPosition().x+row:getWidth(),'percentage fits')
                end
                local equipment=module.BaiakHelperEquipmentV2
                local originalCreate=g_ui.createWidget
                local menuOptions={}
                g_ui.createWidget=function(style,...)
                    if style~='PopupMenu' then return originalCreate(style,...) end
                    return {setGameMenu=function()end,display=function()end,
                        addOption=function(_,label,action)menuOptions[label]=action end}
                end
                local icon=page:recursiveGetChildById('lowAmulet'):recursiveGetChildById('assign')
                icon.onMouseRelease(icon,{x=100,y=100},MouseRightButton)
                g_ui.createWidget=originalCreate
                assert(menuOptions['Assign Amulet'] and menuOptions['Remove Item'],'assigned gear context menu')
                menuOptions['Remove Item']()
                assert(page:recursiveGetChildById('lowAmulet'):recursiveGetChildById('item'):getItemId()==0,'remove clears the square')
                equipment.setRule('lowAmulet',{itemId=3081,enabled=true})
                equipment.setRule('shield',{enabled=true,mode='always'})
                assert(not page:recursiveGetChildById('cancel'):recursiveGetChildById('enabled'):isEnabled(),'always shield disables exana')
                equipment.setRule('shield',{mode='percent'})
                local divider=page:recursiveGetChildById('equipmentDivider')
                local low,high=page:recursiveGetChildById('lowAmulet'),page:recursiveGetChildById('highAmulet')
                assert(low:getPosition().x+low:getWidth()<=divider:getPosition().x+1 and high:getPosition().x>=divider:getPosition().x,'divider separates both gear columns')
                pzLock=true;module.BaiakHelperEquipmentV2.updateCombatLock()
                for _,key in ipairs({'lowAmulet','lowRing','highAmulet','highRing','shield','cancel','potion'}) do
                    local check=page:recursiveGetChildById(key):recursiveGetChildById('enabled')
                    assert(not check:isChecked() and not check:isEnabled(),'PZ lock unchecks and disables '..key)
                end
                pzLock=false;module.BaiakHelperEquipmentV2.updateCombatLock()
                assert(page:recursiveGetChildById('lowAmulet'):recursiveGetChildById('enabled'):isEnabled(),'unlock frees checkbox')
                assert(not page:recursiveGetChildById('lowAmulet'):recursiveGetChildById('enabled'):isChecked(),'unlock leaves checkbox off')
                module.BaiakHelperEquipmentV2.setRule('lowAmulet',{enabled=true})
                modules.client_entergame.EnterGame.hide();module.helperV2Window:raise()
                scheduleEvent(function()g_app.doScreenshot('/equipment-mage.png')end,100)
                voc=11;module.BaiakHelperEquipmentV2.render()
                assert(not page:recursiveGetChildById('shieldSection'):isVisible(),'Knight hides shield')
                voc=14;module.BaiakHelperEquipmentV2.render()
                scheduleEvent(function()module.BaiakHelperEquipmentV2.openSelector('highRing')end,200)
                scheduleEvent(function()
                    assert(g_ui.isMouseGrabbed(),'equipment uses the potion assignment cursor')
                    modules.game_baiakeros_helper.cancelItemAssignment()
                    assert(not g_ui.isMouseGrabbed(),'Escape cancellation releases the item picker')
                    g_app.doScreenshot('/equipment-picker.png')
                    g_game.getLocalPlayer=original
                    g_logger.info('[EquipmentQA] PASS: compact rules, divider, combat lock controls, shield visibility and selector')
                    scheduleEvent(function()g_app.exit()end,200)
                end,500)
            end)
            if not good then g_game.getLocalPlayer=original;g_logger.error('[EquipmentQA] FAIL: '..tostring(message));g_app.exit()end
        end,400)
    end)
    if not ok then g_game.getLocalPlayer=original;g_logger.error('[EquipmentQA] FAIL: '..tostring(err));g_app.exit()end
end,2500)
