local OPCODE = 222

local function applyTitle(creatureId, title, attempts)
    local creature = g_map.getCreatureById(creatureId)
    if creature then
        creature:setStaffTitle(title)
        return
    end

    if attempts > 0 then
        scheduleEvent(function()
            applyTitle(creatureId, title, attempts - 1)
        end, 50)
    end
end

local function onStaffTitle(_protocol, _opcode, buffer)
    local creatureId, title = buffer:match('^(%d+)|([A-Z]+)$')
    creatureId = tonumber(creatureId)
    if not creatureId or (title ~= 'GM' and title ~= 'CM' and title ~= 'GOD') then
        return
    end

    applyTitle(creatureId, title, 4)
end

function init()
    ProtocolGame.registerExtendedOpcode(OPCODE, onStaffTitle)
end

function terminate()
    ProtocolGame.unregisterExtendedOpcode(OPCODE)
end
