-- Run from the client root with Lua/LuaJIT. Exercise the real drag handlers and rarity styling.
TextColors = {}
UIItem = {}
UIWidget = {onHoverChange = function() end}
UIDragIcon = {display = function() end, hide = function() end}
g_mouse = {pushCursor = function() end, popCursor = function() end}
modules = {client_options = {getOption = function() return false end}}
g_game = {getFeature = function() return false end}
GameColorizedLootValue, GameItemTooltipV8 = 1, 2
local dragging
g_ui = {getDraggingWidget = function() return dragging end}
dofile('modules/gamelib/items.lua')
dofile('modules/game_interface/widgets/uiitem.lua')

local function widget(rank)
    local value = setmetatable({width = 0, color = 'white', background = 'default', source = '/images/ui/item'}, {__index = UIItem})
    value.item = rank and {getRarity = function() return rank end} or nil
    function value:getItem() return self.item end
    function value:isVirtual() return false end
    function value:isDraggable() return true end
    function value:getClassName() return 'UIItem' end
    function value:getBackgroundColor() return self.background end
    function value:setBackgroundColor(c) self.background = c end
    function value:getBorderTopColor() return self.color end
    function value:setBorderColor(c) self.color = c end
    function value:getBorderTopWidth() return self.width end
    function value:setBorderWidth(w) self.width = w end
    function value:getImageSource() return self.source end
    function value:setImageSource(s) self.source = s end
    function value:setImageClip() end
    ItemsDatabase.setRarityItem(value, value.item)
    return value
end

for rank, info in ipairs(ItemsDatabase.equipmentRarities) do
    local value = widget(rank)
    local function colored()
        assert(value.width == 1 and value.color == info.color and value.background == info.background)
    end
    colored()
    assert(value:onDragEnter({}))
    value:onDragLeave(nil, {})
    colored()
    assert(not value:onDrop({}, {}), 'rejected drop remains rejected')
    colored()
    dragging = widget(0)
    value:onHoverChange(true)
    assert(dragging.hoveredWho == value)
    value:onHoverChange(false)
    assert(not dragging.hoveredWho)
    colored()
    dragging.hoveredWho = value
    dragging:onDestroy()
    colored()
    dragging = nil
    value.item = nil
    value:onDragLeave(nil, {})
    assert(value.width == 0 and value.color == 'white' and value.background == 'default')
end
for _, value in ipairs({widget(0), widget(nil)}) do
    value:setBorderWidth(1)
    value:onDragLeave(nil, {})
    assert(value.width == 0, 'ordinary/empty slots keep the old drag cleanup')
end
print('PASS: all rarity borders survive drag, rejected drops, hover and destroyed drag sources; ordinary/empty slots reset')
