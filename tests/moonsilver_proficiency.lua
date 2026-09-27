-- Run from the client root with LuaJIT, or after the proficiency module loads.
if not ProficiencyData then
    dofile('modules/game_proficiency/const.lua')
    dofile('modules/game_proficiency/proficiency_data.lua')
end

assert(PERK_DAMAGE_VS_FULL_HP == 28 and PERK_DAMAGE_VS_LOW_HP == 29)
assert(PERK_ARMOR_PENETRATION == 30 and PERK_PIERCE == 31)

local cases = {
    {Type = 32, ElementId = 256, Probability = 0.01, Multiplier = 2.0},
    {Type = 32, ElementId = 64, Probability = 0.015, Multiplier = 3.0},
    {Type = 31, ElementId = 8, Value = 0.04},
    {Type = 29, Value = 0.06},
    {Type = 28, Value = 0.03},
    {Type = 30, Value = 0.05},
    {Type = 5, SpellId = 310, AugmentType = 17, Value = 0.025},
    {Type = 5, SpellId = 301, AugmentType = 2, Value = 0.05},
    {Type = 5, SpellId = 21, AugmentType = 17, Value = 0.025},
}
local expected = {'Death', 'Ice', 'Fire pierce', 'below 30%', 'above 95%',
    'armor penetration', 'Death Echo', 'Thousand Fist Blows', 'Sudden Death Rune'}
for i, perk in ipairs(cases) do
    local name, tooltip = ProficiencyData:getBonusNameAndTooltip(perk)
    assert(name ~= 'Empty' and tooltip:find(expected[i], 1, true), tooltip)
    local path, clip = ProficiencyData:getImageSourceAndClip(perk)
    assert(path and clip)
end
local _, tooltip = ProficiencyData:getBonusNameAndTooltip(cases[1])
assert(tooltip:find('1% chance', 1, true) and tooltip:find('200% of your level', 1, true))
print('Moonsilver proficiency: homing missiles, elemental pierce, alpha/omega and spell tooltips passed')
