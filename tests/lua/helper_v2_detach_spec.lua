-- Run with: luajit tests/lua/helper_v2_detach_spec.lua
local widgets = {}
local gameEvents
local movementBindings = { binds = 0, unbinds = 0 }
local explorerActive = false

local function widget(id, parent)
    local value = { id = id, parent = parent, visible = false }
    widgets[id] = value
    function value:recursiveGetChildById(childId) return widgets[childId] or widget(childId) end
    function value:getParent() return self.parent end
    function value:setParent(newParent) self.parent = newParent end
    function value:breakAnchors() self.anchors = {} end
    function value:addAnchor(edge, target, targetEdge)
        self.anchors[#self.anchors + 1] = { edge, target, targetEdge }
    end
    function value:fill(target) self.fillTarget = target end
    function value:show() self.visible = true end
    function value:hide() self.visible = false end
    function value:isVisible() return self.visible end
    function value:setVisible(visible) self.visible = visible end
    function value:setText(text) self.text = text end
    function value:setWidth(width) self.width = width end
    function value:setHeight(height) self.height = height end
    function value:setPercent(percent) self.percent = percent end
    function value:setBackgroundColor(color) self.backgroundColor = color end
    function value:setColor(color) self.color = color end
    function value:setOn(on) self.on = on end
    function value:setEnabled(enabled) self.enabled = enabled end
    function value:raise() end
    function value:focus() self.focused = true end
    function value:destroy() self.destroyed = true end
    return value
end

rootWidget = widget('root')
tr = function(text) return text end
AnchorLeft, AnchorRight, AnchorTop, AnchorBottom = 1, 2, 3, 4
local helper = widget('helper', rootWidget)
local floating = widget('floating', rootWidget)
local attackPage = widget('attackPage', helper)
local cavebotPage = widget('cavebotPage', helper)
widget('healingToolsPage', helper)
widget('healingToolsTab', helper)
widget('attackTab', helper)
widget('cavebotTab', helper)
local panel = widget('cavebotPanel', cavebotPage)
local detachButton = widget('v2CavebotDetachButton', panel)
local floatSlot = widget('v2CavebotFloatSlot', floating)
local gamePanel = widget('gamePanel', rootWidget)

g_game = { isOnline = function() return true end }
g_ui = {
    importStyle = function() end,
    createWidget = function(style)
        return style == 'BaiakerosHelperV2Window' and helper or floating
    end
}
connect = function(_, events) gameEvents = events end
disconnect = function() end
modules = {
    game_baiakeros_helper = {
        setHelperButtonOn = function(on) widget('helperButton'):setOn(on) end
    },
    game_mainpanel = {
        addToggleButton = function() error('Helper V2 must use the existing button') end
    },
    game_interface = {
        getRootPanel = function() return gamePanel end
    },
    game_walk = {
        bindMovementKeysToWidget = function(target)
            assert(target == floating)
            movementBindings.binds = movementBindings.binds + 1
        end,
        unbindMovementKeysFromWidget = function(target)
            assert(target == floating)
            movementBindings.unbinds = movementBindings.unbinds + 1
        end
    }
}

local function submodule()
    return { init = function() end, terminate = function() end,
        onGameStart = function() end, onGameEnd = function() end }
end
BaiakHelperHealingV2 = submodule()
BaiakHelperTrainingV2 = submodule()
BaiakHelperToolsV2 = submodule()
BaiakHelperAttackV2 = submodule()
BaiakHelperExplorerV2 = submodule()
BaiakHelperExplorerV2.isAutoExplorerActive = function() return explorerActive end

dofile('modules/game_baiakeros_helper_v2/helper_v2.lua')
init()
show()
assert(helper.visible and widgets.helperButton.on)
assert(widgets.healingToolsPage.visible and not attackPage.visible and
    not cavebotPage.visible)
showHelperV2Tab('attack')
assert(attackPage.visible and not cavebotPage.visible and
    widgets.attackTab.width == 116)
showHelperV2Tab('cavebot')
assert(cavebotPage.visible and not attackPage.visible and
    widgets.cavebotTab.width == 116 and widgets.cavebotTab.text == 'Cavebot',
    'the Cavebot tab must own its full-size page and match Attack tab sizing')

detachButton.onClick()
assert(panel.parent == floatSlot and floating.visible and not helper.visible,
    'Detach must move Cavebot into its own window and hide Helper')
assert(panel.fillTarget == 'parent', 'the detached panel must fill its floating slot')
assert(not detachButton.visible and not widgets.helperButton.on)
assert(movementBindings.binds == 1 and movementBindings.unbinds == 0,
    'Detach must enable movement keys in the focused floating window')

closeDetachedCavebot()
assert(panel.parent == cavebotPage and not floating.visible and not helper.visible,
    'X must close the floating window and restore Cavebot without opening Helper')
assert(panel.width == 260 and #panel.anchors == 3,
    'reattaching must restore the panel width and anchors')
assert(panel.anchors[1][1] == AnchorLeft,
    'reattaching must return Cavebot to the left edge of its own page')
assert(detachButton.visible)
assert(movementBindings.unbinds == 1 and gamePanel.focused,
    'closing the floating window must restore normal movement focus')

show()
detachButton.onClick()
returnCavebotToHelper()
assert(panel.parent == cavebotPage and helper.visible and not floating.visible,
    'Back must return Cavebot to its own tab')
assert(cavebotPage.visible and widgets.helperButton.on)
assert(movementBindings.binds == 2 and movementBindings.unbinds == 2)

detachButton.onClick()
toggle()
assert(panel.parent == cavebotPage and helper.visible and not floating.visible,
    'opening Helper while detached must reattach Cavebot')

detachButton.onClick()
explorerActive = true
show()
assert(panel.parent == floatSlot and floating.visible,
    'an active Cavebot must stay floating when Helper opens')
hide()
assert(panel.parent == floatSlot and floating.visible and not helper.visible,
    'closing Helper must preserve the active floating Cavebot')
closeDetachedCavebot()
assert(floating.visible and floating.height == 154 and
    widgets.v2CavebotCompactPanel.visible and not floatSlot.visible,
    string.format('X must compact an active Cavebot: visible=%s height=%s panel=%s slot=%s',
        tostring(floating.visible), tostring(floating.height),
        tostring(widgets.v2CavebotCompactPanel.visible), tostring(floatSlot.visible)))
expandCavebot()
assert(floating.height == 570 and floatSlot.visible and
    not widgets.v2CavebotCompactPanel.visible,
    'Expand must restore the full floating Cavebot')
updateCavebotCompact('00:30:00', 50, '#efbe61', true)
assert(widgets.v2CavebotCompactTime.text == '00:30:00' and
    widgets.v2CavebotCompactProgress.percent == 50 and
    widgets.v2CavebotCompactStopButton.visible,
    'the compact display must reflect the live explorer timer')
widget('v2CavebotAutoExploringButton').onClick = function() explorerActive = false end
stopFromCompactCavebot()
assert(not explorerActive, 'compact Stop must stop the explorer')
gameEvents.onGameEnd()
assert(panel.parent == cavebotPage and not floating.visible and not helper.visible,
    'disconnect must close the floating window safely')

show()
detachButton.onClick()
terminate()
assert(panel.parent == cavebotPage and floating.destroyed and helper.destroyed,
    'unload must restore Cavebot before destroying the floating window')
assert(movementBindings.binds == movementBindings.unbinds,
    'unload must remove every detached movement binding')

print('Helper V2 detachable Cavebot regression passed')
