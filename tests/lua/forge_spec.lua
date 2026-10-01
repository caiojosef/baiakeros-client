-- Run from the client root with LuaJIT/Lua 5.1.
Controller = { new = function() return {} end }
function comma_value(value) return tostring(value) end
Item = { create = function(id)
    return { getClassification = function() return id == 99 and 2 or 4 end }
end }
ItemsDatabase = {
    getTierClip = function() return {} end,
    getClipAndImagePath = function() return nil end
}
local requests = {}
g_game = { forgeRequest = function(...) requests[#requests + 1] = {...} end }
function scheduleEvent() return 1 end
function removeEvent() end
dofile('modules/game_forge/game_forge_helpers.lua')
dofile('modules/game_forge/game_forge.lua')

local controller = ForgeController
local prices = {[4] = {[1] = 200, [2] = 320, [3] = 640}}
controller:getPrice(prices, 1, 1, false, false)
assert(controller.rawPrice == 320, 'fusion must price the next tier')
controller:getPrice(prices, 1, 2, false, true)
assert(controller.rawPrice == 200, 'transfer must price the resulting tier')
controller:getPrice({[2] = 140, [3] = 280}, 1, 2, true, true)
assert(controller.rawPrice == 280, 'convergence transfer uses donor tier prices')

local fusion = controller.fusion
fusion.selected = {id = 1, tier = 0}
fusion.selectedTarget = {id = 1, tier = 0}
fusion.canFusion = true
fusion.chanceImprovedChecked = true
fusion.reduceTierLossChecked = true
fusion.isConvergence = false
controller.rawPrice = 200
controller.rawCurrentGold = 1000
controller.currentDust = 1000
controller.currentExaltedCores = 1
controller:forgeAction(false)
assert(#requests == 0, 'selected improvements must require two cores')
controller.currentExaltedCores = 2
controller:forgeAction(false)
assert(#requests == 1 and requests[1][6] == true and requests[1][7] == true)

fusion.isConvergence = true
controller.currentDust = fusion.dust
controller:forgeAction(false)
assert(#requests == 1, 'convergence must require convergence dust')
controller.currentDust = fusion.convergenceDust
controller:forgeAction(false)
assert(#requests == 2 and not requests[2][6] and not requests[2][7], 'convergence sends no optional cores')

controller.currentDust = 1000
fusion.selected = {id = 1, tier = 0}
controller:handleSelectTarget({id = 2, tier = 0, count = 1}, false)
assert(fusion.canFusion, 'convergence accepts two different compatible items')
controller:handleSelectTarget({id = 1, tier = 0, count = 1}, false)
assert(not fusion.canFusion, 'same-item convergence requires two copies')
controller:handleSelectTarget({id = 1, tier = 0, count = 2}, false)
assert(fusion.canFusion)

controller.transfer.canTransfer = false
controller.transfer.selected = {id = 1, tier = 2}
controller.transfer.selectedTarget = {id = 2, tier = 0}
controller:forgeAction(true)
assert(#requests == 2, 'fusion eligibility must not enable transfer')

controller.transfer.items.receivers = {{id = 2}, {id = 99}}
controller.transfer.grades = {{tier = 1, exaltedCores = 1}}
controller.transfer.prices = prices
controller:handleSelect(controller.transfer, {id = 1, tier = 2}, true)
assert(#controller.transfer.currentList.receivers == 1, 'transfer receiver classifications must match')
fusion.chanceImprovedChecked = false
fusion.reduceTierLossChecked = false
controller.currentExaltedCores = 1
fusion.exaltedCoreImprovements('improve-chance')
assert(fusion.chanceImprovedChecked)
fusion.exaltedCoreImprovements('reduce-loss')
assert(not fusion.reduceTierLossChecked, 'one core cannot enable both improvements')
controller.currentExaltedCores = 0
fusion.exaltedCoreImprovements('improve-chance')
assert(not fusion.chanceImprovedChecked, 'selected improvements can be unchecked after cores run out')
controller.waitingForResult = false
controller.ui = {isDestroyed = function() return false end, isVisible = function() return true end}
fusion.chanceImprovedLabel = '65%'
onOpenForge({fusionItems = {}, transfers = {}, convergenceFusion = {}, convergenceTransfers = {}})
assert(fusion.chanceImprovedLabel == tostring(fusion.chanceBase) .. '%', 'opening forge resets the displayed chance with the core switches')
print('Forge client regression: price tiers, selected cores, dust, convergence and transfer eligibility passed')
