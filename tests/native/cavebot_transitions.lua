-- Validate the real Cavebot widgets without connecting a character.
scheduleEvent(function()
    local helper = modules.game_baiakeros_helper_v2
    local window = helper.helperV2Window
    local function checkLayout()
        local rope = window:recursiveGetChildById('v2CavebotRopeButton')
        -- The script panel is reparented to the float, so locate it at the root.
        if not rope then rope = rootWidget:recursiveGetChildById('v2CavebotRopeButton') end
        local magic = rootWidget:recursiveGetChildById('v2CavebotExaniTeraButton')
        local panel = rootWidget:recursiveGetChildById('v2CavebotWaypointPanel')
        local stair = rootWidget:recursiveGetChildById('v2CavebotStairButton')
        assert(rope and magic and panel and stair, 'all waypoint controls exist')
        assert(rope:getText() == 'Rope' and magic:getText() == 'Exani Tera')
        assert(rope:getPosition().y >= stair:getPosition().y + stair:getHeight(), 'new row is below stairs')
        assert(rope:getPosition().x + rope:getWidth() <= magic:getPosition().x, 'new buttons do not overlap')
        assert(panel:getPosition().y >= rope:getPosition().y + rope:getHeight(), 'list is below new row')
        assert(panel:getHeight() > 100, 'waypoint list remains usable')
        local parent = rope:getParent()
        assert(magic:getPosition().x + magic:getWidth() <= parent:getPosition().x + parent:getWidth(), 'buttons fit column')
    end
    local function fail(err)
        g_logger.error('[CavebotTransitionsQA] FAIL: ' .. tostring(err))
        g_app.exit()
    end
    local ok, err = pcall(function()
        helper.showHelperV2Tab('cavebot')
        window:show(); window:raise()
        modules.client_entergame.EnterGame.hide()
        scheduleEvent(function()
            local valid, message = pcall(function()
                checkLayout()
                g_app.doScreenshot('/cavebot-transitions-helper.png')
                local online = g_game.isOnline
                g_game.isOnline = function() return true end
                helper.detachCavebot()
                g_game.isOnline = online
                scheduleEvent(function()
                    local fitted, reason = pcall(checkLayout)
                    if not fitted then fail(reason); return end
                    g_app.doScreenshot('/cavebot-transitions-float.png')
                    g_logger.info('[CavebotTransitionsQA] PASS: Rope and Exani Tera fit the normal and floating panels; waypoint list remains usable')
                    scheduleEvent(function() g_app.exit() end, 500)
                end, 300)
            end)
            if not valid then fail(message) end
        end, 300)
    end)
    if not ok then fail(err) end
end, 1300)
