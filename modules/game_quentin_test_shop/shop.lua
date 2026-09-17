local OPCODE = 219
local window
local function send(buffer)
 local protocol = g_game.getProtocolGame()
 if protocol then protocol:sendExtendedOpcode(OPCODE, buffer) end
end
function closeQuentinShop()
 if window then window:hide() end
 send('close')
end
function performQuentinSearch()
 if not window then return end
 window.results:destroyChildren()
 window.status:setText('Searching...')
 send('search|' .. window.query:getText())
end
local function receive(protocol, opcode, buffer)
 local ok, data = pcall(json.decode, buffer)
 if not ok or type(data) ~= 'table' then return end
 if data.action == 'open' then
  if not window then window = g_ui.displayUI('shop') end
  window.results:destroyChildren()
  window.query:setText('')
  window.status:setText('Enter at least 2 letters and press Search. Every item costs 1 gold.')
  window:show(); window:raise(); window:focus(); window.query:focus()
 elseif data.action == 'close' then
  if window then window:hide() end
 elseif window and data.action == 'results' then
  window.results:destroyChildren()
  for _, entry in ipairs(data.items or {}) do
   local row = g_ui.createWidget('QuentinOffer', window.results)
   row.description:setText(entry.name .. '  |  Tier ' .. entry.tier .. '  |  1 gold')
   row.buy.onClick = function() send(string.format('buy|%d|%d', entry.id, entry.tier)) end
  end
  window.status:setText(data.truncated and 'First 20 matching items. Refine your search for more.' or (#(data.items or {}) == 0 and 'No equipment found. Enter at least 2 letters.' or 'Choose a tier below. Each purchase gives one item.'))
 elseif window and data.action == 'message' then
  window.status:setText(data.text)
 end
end
local function endGame()
 if window then window:destroy(); window = nil end
end
function init()
 ProtocolGame.registerExtendedOpcode(OPCODE, receive)
 connect(g_game, {onGameEnd = endGame})
end
function terminate()
 ProtocolGame.unregisterExtendedOpcode(OPCODE)
 disconnect(g_game, {onGameEnd = endGame})
 endGame()
end