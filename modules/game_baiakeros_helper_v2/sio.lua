BaiakHelperSioV2 = {}

local window
local updating = false
local selectedMemberName
local memberRows = {}
local memberNamesKey

local function legacy()
    return modules.game_baiakeros_helper
end

local function rowFor(prefix, index)
    local id = (prefix == 'friendSlot' and 'v2FriendSlot' or 'v2MassFriendSlot') .. index
    return window:recursiveGetChildById(id)
end

local function refreshMemberSelection()
    for _, row in ipairs(memberRows) do
        row:setOn(row.memberName == selectedMemberName)
    end
end

local function syncMembers(members)
    local list = window:recursiveGetChildById('v2SioMemberList')
    local namesKey = table.concat(members, '\n')
    if namesKey ~= memberNamesKey then
        memberNamesKey = namesKey
        list:destroyChildren()
        memberRows = {}
        local selectionStillVisible = false
        for _, name in ipairs(members) do
            local memberName = name
            if memberName == selectedMemberName then selectionStillVisible = true end
            local row = g_ui.createWidget('HelperV2PartyMemberRow', list)
            row.memberName = memberName
            row:recursiveGetChildById('nameLabel'):setText(memberName)
            row:setTooltip(memberName)
            row.onClick = function()
                selectedMemberName = memberName
                refreshMemberSelection()
            end
            table.insert(memberRows, row)
        end
        if not selectionStillVisible then selectedMemberName = nil end
        refreshMemberSelection()
    end
    window:recursiveGetChildById('v2SioEmptyPartyLabel'):setVisible(#members == 0)
    window:recursiveGetChildById('v2SioMemberScroll'):setVisible(
        #members * 24 > list:getHeight())
end

local function renderRow(row, slot)
    local assigned = slot ~= nil and slot.name ~= nil and slot.name ~= ''
    local name = row:recursiveGetChildById('nameLabel')
    local displayName = assigned and slot.name or ''
    if #displayName > 9 then displayName = displayName:sub(1, 7) .. '..' end
    name:setText(displayName)
    name:setTooltip(assigned and slot.name or 'Select a party member, then press +')
    local addButton = row:recursiveGetChildById('addButton')
    addButton:setText(assigned and (slot.outfit and '' or '?') or '+')
    addButton:setTooltip(assigned and (slot.name ..
        (slot.outfit and '' or '\nOutfit appears when this player is visible.')) or
        'Assign the selected party member.')
    local outfit = row:recursiveGetChildById('outfit')
    outfit:setVisible(assigned and slot.outfit ~= nil)
    if assigned and slot.outfit then outfit:setOutfit(slot.outfit) end
    row:recursiveGetChildById('clearButton'):setVisible(assigned)
    row:recursiveGetChildById('thresholdBox'):setCurrentOptionByData(
        slot and slot.threshold or 80, true)
    local enabled = row:recursiveGetChildById('enableBox')
    enabled:setEnabled(assigned)
    enabled:setChecked(assigned and slot.enabled or false)
end

function BaiakHelperSioV2.sync()
    if not window then return end
    local module = legacy()
    local state = module and module.getSioState and module.getSioState()
    if not state then return end
    local panel = window:recursiveGetChildById('v2SioPanel')
    panel:setEnabled(state.available)
    panel:setOpacity(state.available and 1 or 0.45)
    updating = true
    syncMembers(state.members or {})
    local massLabel = window:recursiveGetChildById('v2MassSioLabel')
    local showMass = state.massAvailable or not state.available
    massLabel:setVisible(showMass)
    for _, prefix in ipairs({ 'friendSlot', 'massFriendSlot' }) do
        for index = 1, 2 do
            local row = rowFor(prefix, index)
            local visible = prefix == 'friendSlot' or showMass
            row:setVisible(visible)
            if visible then
                renderRow(row, state.slots[prefix .. index])
            end
        end
    end
    updating = false
end

function BaiakHelperSioV2.init(helperWindow)
    window = helperWindow
    for _, prefix in ipairs({ 'friendSlot', 'massFriendSlot' }) do
        for index = 1, 2 do
            local slotId = prefix .. index
            local row = rowFor(prefix, index)
            local threshold = row:recursiveGetChildById('thresholdBox')
            for value = 5, 95, 5 do
                threshold:addOption(value .. '%', value)
            end
            threshold.onOptionChange = function(_, _, value)
                if not updating and value then legacy().setFriendThreshold(slotId, value) end
            end
            row:recursiveGetChildById('addButton').onClick = function()
                if selectedMemberName then
                    legacy().assignSioSlot(slotId, selectedMemberName)
                else
                    modules.game_textmessage.displayFailureMessage(
                        'Select a party member first.')
                end
                BaiakHelperSioV2.sync()
            end
            row:recursiveGetChildById('clearButton').onClick = function()
                legacy().clearFriendSlot(slotId)
                BaiakHelperSioV2.sync()
            end
            row:recursiveGetChildById('enableBox').onCheckChange = function(_, checked)
                if not updating then legacy().setFriendEnabled(slotId, checked) end
            end
        end
    end
    BaiakHelperSioV2.sync()
end

function BaiakHelperSioV2.terminate()
    window = nil
    selectedMemberName = nil
    memberRows = {}
    memberNamesKey = nil
end
