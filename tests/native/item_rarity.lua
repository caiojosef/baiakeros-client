scheduleEvent(function()
    local window
    local ok, err = pcall(function()
        window = g_ui.createWidget('MainWindow', rootWidget)
        window:setSize({width=480,height=200})
        window:setText('Baiakeros - Raridades de equipamento')
        window:show()
        local names={'Common','Rare','Epic','Ultra'}
        local colors={'#4299ffff','#ac66ffff','#ffd447ff','#ff4545ff'}
        local function hex(c) return string.format('#%02x%02x%02x%02x',c.r,c.g,c.b,c.a) end
        for rarity=1,4 do
            local widget=g_ui.createWidget('UIItem',window)
            widget:setSize({width=60,height=60})
            widget:addAnchor(AnchorLeft,'parent',AnchorLeft)
            widget:addAnchor(AnchorTop,'parent',AnchorTop)
            widget:setMarginLeft(25+(rarity-1)*100)
            widget:setMarginTop(55)
            local item=Item.create(3552)
            assert(item:getRarity()==0)
            item:setRarity(rarity)
            assert(item:clone():getRarity()==rarity)
            local before=widget:getBackgroundColor()
            widget:setItem(item)
            ItemsDatabase.setRarityItem(widget,item)
            assert(widget.baiakerosRarityState)
            assert(hex(widget:getBorderTopColor())==colors[rarity], hex(widget:getBorderTopColor()))
            local caption=g_ui.createWidget('Label',window)
            caption:setText(names[rarity]);caption:setColor(colors[rarity]);caption:addAnchor(AnchorLeft, 'parent', AnchorLeft);caption:addAnchor(AnchorTop, 'parent', AnchorTop);caption:setMarginLeft(25+(rarity-1)*100);caption:setMarginTop(125)
            ItemsDatabase.setRarityItem(widget,nil)
            assert(not widget.baiakerosRarityState)
            assert(hex(widget:getBackgroundColor())==hex(before))
            ItemsDatabase.setRarityItem(widget,item)
        end
        g_logger.info('[RarityQA] PASS: four exact colors, instance clone, empty-slot reset')
    end)
    if not ok then g_logger.error('[RarityQA] FAIL: '..tostring(err)) end
    scheduleEvent(function()
        if ok then g_app.doScreenshot('/rarity-colors.png') end
        scheduleEvent(function() if window then window:destroy() end; g_app.exit() end,800)
    end,800)
end,3000)
