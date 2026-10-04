-- Druid-specific spell formation delegates navigation and pressure to shared code.
PartyDruid = {}
function PartyDruid.update(snapshot) return PartyFollower.update(snapshot, true) end
function PartyDruid.reset() PartyFollower.reset() end
function PartyDruid.prepareSpell(spell) return PartyFollower.prepareSpell(spell) end
function PartyDruid.onSpellCast(spell) PartyFollower.onSpellCast(spell) end
