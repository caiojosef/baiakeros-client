WheelPointTooltip = "From level 51 onwards, you receive one promotion point with each level, of which you currently have %s.\n\nFor each fully enhanced mod, you will receive another promotion point. This currently gives you %s out of a maximum of 69 points.\n\nCertain rare items and special game accomplishments can earn you bonus promotion points, of wich you currently have %s:"

ConvictionTooltip = "The Conviction Perk is unlocked when the maximum number of\npromotion points for this slice has been assigned.\n\nMost Conviction Perks can be found more than once within the\nWheel of Destiny. When they are unlocked, thier effect adds up."

-- Keep the Wheel text builder local. gamelib/util.lua also declares a global
-- setStringColor(str, color) helper and overwrites corelib's three-argument
-- version during startup. The Wheel needs the three-argument form below to
-- build its alternating { text, color, ... } arrays.
local function setStringColor(parts, text, color)
	table.insert(parts, text)
	table.insert(parts, color)
end

WheelDedicationHeight = {
	-- [VocationId][index]
	[1] = {[1] = 45, [2] = 60, [3] = 60, [4] = 74},
	[2] = {[1] = 45, [2] = 45, [3] = 60, [4] = 74},
	[3] = {[1] = 45, [2] = 60, [3] = 60, [4] = 74},
	[4] = {[1] = 45, [2] = 60, [3] = 74, [4] = 74},
	[5] = {[1] = 45, [2] = 60, [3] = 60, [4] = 74}
}

WheelConsts = {
	["lifemana"] = {
		["life"] = {
			[1] = 3, -- Knight
			[2] = 2, -- Paladin
			[3] = 1, -- Sorcerer
			[4] = 1, -- Druid
			[5] = 2, -- Monk
		},
		["mana"] = {
			[1] = 1, -- Knight
			[2] = 3, -- Paladin
			[3] = 6, -- Sorcerer
			[4] = 6, -- Druid
			[5] = 2, -- Monk
		},
	},
	["special_1"] = {
		[1] = {"Battle Instinct", "Gain +6 shielding and +1 sword/axe/club fighting when 5\ncreatures are on adjacent squares.\nFor each additional creature, up to a maximum of 8, you get +6\nshielding and +1 sword/axe/club fighting more."},
		[2] = {"Positional Tactics", "Gain +3 distance fighting while no monster is within 1 squares.\nOtherwise gain +3 holy magic level and +3 healing magic level."},
		[3] = {"Runic Mastery", "If you use a rune, you have a 25% chance of increasing your magic\nlevel by 10%, or by 20% if you use a rune that can be created by\nyour vocation."},
		[4] = {"Healing Link", "If you heal someone with Nature's Embrace or Heal Friend, you\nalso heal yourself for 25% of the applied healing."},
		[5] = {"Guiding Presence", "Gain an aura that shares 100% of your mantra with nearby party members while in combat. Enhances passive vocation bonuses by 33%."},
	},
	["special_2"] = {
		[1] = {"Battle Healing", "Increases all Knight healing spells by 10%. This bonus is doubled\nwhile wielding a shield, for a total healing increase of 20%."},
		[2] = {"Ballistic Mastery", "The critical extra damage for attacks with a crossbow is increased\nby 10%. While wielding a bow your attacks and spells treat the\ntargets physical and holy sensitivity as being 2% higher."},
		[3] = {"Focus Mastery", "After casting a focus spell, the next damage spell within 12 seconds deals +35% damage. Focus spells also have -2s primary cooldown."},
		[4] = {"Runic Mastery", "If you use a rune, you have a 25% chance of increasing your magic\nlevel by 10%, or by 20% if you use a rune that can be created by\nyour vocation."},
		[5] = {"Sanctuary", "Consuming Harmony creates a field lasting 5 seconds, increasing your damage and healing done by 2% for each Harmony consumed. Also grants +10% damage/healing to adjacent targets."},
	},
	["mitigation"] = 0.075,
	["manaleech"] = 0.25,
	["lifeleech"] = 0.75,
	["health"] = {
		[1] = 3, -- Knight
		[2] = 2, -- Paladin
		[3] = 1, -- Sorcerer
		[4] = 1, -- Druid
		[5] = 2, -- Monk
	},
	["mana"] = {
		[1] = 1, -- Knight
		[2] = 3, -- Paladin
		[3] = 6, -- Sorcerer
		[4] = 6, -- Druid
		[5] = 2, -- Monk
	},
	["skill"] = 1,
	["spell_1"] = {6, 21},
	["spell_2"] = {8, 24},
	["capacity"] = {
		[1] = 5, -- Knight
		[2] = 4, -- Paladin
		[3] = 2, -- Sorcerer
		[4] = 2, -- Druid
		[5] = 5, -- Monk
	},
	["spell_3"] = {11, 26},
	["spell_4"] = {13, 29},
	["spell_5"] = {16, 31},
}

WheelBonus = {
	[0] = {maxPoints = 200, domain = 1, dedication = "lifemana", conviction = "special_1"},
	[1] = {maxPoints = 150, domain = 1, dedication = "mitigation", conviction = "manaleech"},
	[2] = {maxPoints = 100, domain = 1, dedication = "health", conviction = "vessel", modType = 1},
	[3] = {maxPoints = 100, domain = 2, dedication = "mana", conviction = "skill"},
	[4] = {maxPoints = 150, domain = 2, dedication = "health", conviction = "vessel", modType = 2},
	[5] = {maxPoints = 200, domain = 2, dedication = "lifemana", conviction = "spell_1"},
	[6] = {maxPoints = 150, domain = 1, dedication = "mitigation", conviction = "vessel", modType = 2},
	[7] = {maxPoints = 100, domain = 1, dedication = "health", conviction = "spell_2"},
	[8] = {maxPoints = 75, domain = 1, dedication = "mana", conviction = "lifeleech"},
	[9] = {maxPoints = 75, domain = 2, dedication = "capacity", conviction = "vessel", modType = 0},
	[10] = {maxPoints = 100, domain = 2, dedication = "mana", conviction = "spell_3"},
	[11] = {maxPoints = 150, domain = 2, dedication = "health", conviction = "manaleech"},
	[12] = {maxPoints = 100, domain = 1, dedication = "health", conviction = "spell_4"},
	[13] = {maxPoints = 75, domain = 1, dedication = "mana", conviction = "skill"},
	[14] = {maxPoints = 50, domain = 1, dedication = "capacity", conviction = "vessel", modType = 0},
	[15] = {maxPoints = 50, domain = 2, dedication = "mitigation", conviction = "spell_5"},
	[16] = {maxPoints = 75, domain = 2, dedication = "capacity", conviction = "lifeleech"},
	[17] = {maxPoints = 100, domain = 2, dedication = "mana", conviction = "vessel", modType = 1},
	[18] = {maxPoints = 100, domain = 3, dedication = "mitigation", conviction = "vessel", modType = 1},
	[19] = {maxPoints = 75, domain = 3, dedication = "health", conviction = "manaleech"},
	[20] = {maxPoints = 50, domain = 3, dedication = "mana", conviction = "spell_1"},
	[21] = {maxPoints = 50, domain = 4, dedication = "health", conviction = "vessel", modType = 0},
	[22] = {maxPoints = 75, domain = 4, dedication = "mitigation", conviction = "skill"},
	[23] = {maxPoints = 100, domain = 4, dedication = "capacity", conviction = "spell_2"},
	[24] = {maxPoints = 150, domain = 3, dedication = "capacity", conviction = "lifeleech"},
	[25] = {maxPoints = 100, domain = 3, dedication = "mitigation", conviction = "spell_3"},
	[26] = {maxPoints = 75, domain = 3, dedication = "health", conviction = "vessel", modType = 0},
	[27] = {maxPoints = 75, domain = 4, dedication = "mitigation", conviction = "manaleech"},
	[28] = {maxPoints = 100, domain = 4, dedication = "capacity", conviction = "spell_4"},
	[29] = {maxPoints = 150, domain = 4, dedication = "mana", conviction = "vessel", modType = 2},
	[30] = {maxPoints = 200, domain = 3, dedication = "lifemana", conviction = "spell_5"},
	[31] = {maxPoints = 150, domain = 3, dedication = "capacity", conviction = "vessel", modType = 2},
	[32] = {maxPoints = 100, domain = 3, dedication = "mitigation", conviction = "skill"},
	[33] = {maxPoints = 100, domain = 4, dedication = "capacity", conviction = "vessel", modType = 1},
	[34] = {maxPoints = 150, domain = 4, dedication = "mana", conviction = "lifeleech"},
	[35] = {maxPoints = 200, domain = 4, dedication = "lifemana", conviction = "special_2"},
}

WheelDomainOrder = {
	[0] = {15, 14, 9, 13, 8 , 3, 7, 2, 1},
	[1] = {16, 10, 17, 4 ,11, 18 , 5, 12, 6},
	[2] = {21, 20, 27 , 19, 26, 33, 25, 32 , 31},
	[3] = {22, 23, 28, 24, 29, 34, 30, 35, 36}
}

local function firstSpellIsUnlocked(attribute)
  return WheelOfDestiny.isLitFull(attribute[1]) or WheelOfDestiny.isLitFull(attribute[2])
end
local function secondSpellIsUnlocked(attribute)
  return WheelOfDestiny.isLitFull(attribute[1]) and WheelOfDestiny.isLitFull(attribute[2])
end

function getDedicationBonus(index)
	local bonus = WheelBonus[index - 1]
	local vocation = WheelOfDestiny.vocationId
	local points = WheelOfDestiny.pointInvested[index]
	if not vocation or vocation == 0 then
		return
	end

	local attribute = WheelConsts[bonus.dedication]
	local vocationAttribute = 0
	if type(attribute) == "table" then
		vocationAttribute = attribute[vocation] or 0
	end

	if bonus.dedication ==  "capacity" then
		return string.format("+%d Capacity", points * vocationAttribute)
	elseif bonus.dedication ==  "mana" then
		return string.format("+%d Mana", points * vocationAttribute)
	elseif bonus.dedication ==  "health" then
		return string.format("+%d Hit Points", points * vocationAttribute)
	elseif bonus.dedication ==  "mitigation" then
		return string.format("%.2f%% Mitigation Multiplier", points * attribute)
	elseif bonus.dedication ==  "lifemana" then
		return string.format("+%d Hit Points\n+%d Mana", points * attribute["life"][vocation], points * attribute["mana"][vocation])
	end

	return ""
end

function getDedicationTooltip(index)
	local bonus = WheelBonus[index - 1]
	local vocation = WheelOfDestiny.vocationId
	local points = WheelOfDestiny.pointInvested[index]
	if not vocation or vocation == 0 then
		return ""
	end

	local attribute = WheelConsts[bonus.dedication]
	local vocationAttribute = 0
	if type(attribute) == "table" then
		vocationAttribute = attribute[vocation] or 0
	end

	if bonus.dedication == "capacity" then
		return string.format("Per promotion point:\n+%d Capacity", vocationAttribute)
	elseif bonus.dedication == "mana" then
		return string.format("Per promotion point:\n+%d Mana", vocationAttribute)
	elseif bonus.dedication == "health" then
		return string.format("Per promotion point:\n+%d Hit Points", vocationAttribute)
	elseif bonus.dedication == "mitigation" then
		return string.format("Increases your mitigation multiplicatively.\n\n%.2f%% Mitigation Multiplier", attribute)
	elseif bonus.dedication == "lifemana" then
		return string.format("Per promotion point:\n+%d Hit Points\n+%d Mana", attribute["life"][vocation], attribute["mana"][vocation])
	end
	return ""
end

function getConvictionBonusTooltip(index)
	local bonus = WheelBonus[index - 1]
	local vocation = WheelOfDestiny.vocationId
	local points = WheelOfDestiny.pointInvested[index]

	local attribute = WheelConsts[bonus.conviction]

	if bonus.conviction == "vessel" then
		local domain = bonus.domain
		if domain == 1 then
			return "Each level of Vessel Resonance unlocks equivalent Gem Mods in its\ndomain. If the Vessel Resonance matches the gem quality, a\ndamage and healing bonus is granted."
		elseif domain == 2 then
			return "Each level of Vessel Resonance unlocks equivalent Gem Mods in its\ndomain. If the Vessel Resonance matches the gem quality, a\ndamage and healing bonus is granted."
		elseif domain == 3 then
			return "Each level of Vessel Resonance unlocks equivalent Gem Mods in its\ndomain. If the Vessel Resonance matches the gem quality, a\ndamage and healing bonus is granted."
		elseif domain == 4 then
			return "Each level of Vessel Resonance unlocks equivalent Gem Mods in its\ndomain. If the Vessel Resonance matches the gem quality, a\ndamage and healing bonus is granted."
		end
	elseif bonus.conviction == "special_1" then
		if vocation == KNIGHT then
			return "Gain +6 shielding and +1 sword/axe/club fighting when 5\ncreatures are on adjacent squares.\nFor each additional creature, up to a maximum of 8, you get +6\nshielding and +1 sword/axe/club fighting more."
		elseif vocation == PALADIN then
			return "Gain +3 distance fighting while no monster is within 1 squares.\nOtherwise gain +3 holy magic level and +3 healing magic level."
		elseif vocation == SORCERER then
			return "If you use a rune, you have a 25% chance of increasing your magic\nlevel by 10%, or by 20% if you use a rune that can be created by\nyour vocation."
		elseif vocation == DRUID then
			return "If you heal someone with Nature's Embrace or Heal Friend, you\nalso heal yourself for 25% of the applied healing."
		elseif vocation == MONK then
			return "Gain an aura that shares 100% of your\nmantra with members of your group."
		end
	elseif bonus.conviction == "special_2" then
		if vocation == KNIGHT then
			return "Increases all Knight healing spells by 10%. This bonus is doubled\nwhile wielding a shield, for a total healing increase of 20%."
		elseif vocation == PALADIN then
			return "The critical extra damage for attacks with a crossbow is increased\nby 10%. While wielding a bow your attacks and spells treat the\ntargets physical and holy sensitivity as being 2% higher."
		elseif vocation == SORCERER then
			return "Increases the damage of your next damage spell by 35% within 12\nseconds after casting a focus spell."
		elseif vocation == DRUID then
			return "If you use a rune, you have a 25% chance of increasing your magic\nlevel by 10%, or by 20% if you use a rune that can be created by\nyour vocation."
		elseif vocation == MONK then
			return "Consuming Harmony creates a field lasting 5 seconds, increasing\nyour damage and healing done by 2% for each Harmony\nconsumed."
		end
	elseif bonus.conviction == "spell_1" then
		if vocation == KNIGHT then
			return "I: +40% Base Damage.\nII: Enlarges the affected area to 5 SQMs."
		elseif vocation == PALADIN then
			local t = {}
			  if not firstSpellIsUnlocked(attribute) then
				  setStringColor(t, "I", "white")
			  else
				  setStringColor(t, "I", "white")
			  end
			  setStringColor(t, " Enables the casting of support spells while active and Focus secondary group cooldown -8s\n", "#707070")
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, " +10% Critical Hit Chance", "#707070")
			return t
		end
	elseif bonus.conviction == "spell_2" and vocation == KNIGHT then
		return "I: Adds 15% life leech to this spell.\nII: Increases the next hostile autoattack damage reduction to 75%."
	elseif bonus.conviction == "spell_3" and vocation == KNIGHT then
		return "I: Reduces cooldown by 2 seconds.\nII: Increases base damage by 12.5%."
	elseif bonus.conviction == "spell_4" and vocation == KNIGHT then
		return "I: Increases base healing by 125%.\nII: Reduces cooldown by 300 seconds (subject to the 50% cooldown limit)."
	elseif bonus.conviction == "spell_5" and vocation == KNIGHT then
		return "I: Reduces mana cost by 30.\nII: Increases base damage by 10%."
	end
	return ""
end

function getConvictionBonus(index, fullMessage)
	local bonus = WheelBonus[index - 1]
	local vocation = WheelOfDestiny.vocationId
	local points = WheelOfDestiny.pointInvested[index]

	local attribute = WheelConsts[bonus.conviction]

	if bonus.conviction == "vessel" then
		local domain = bonus.domain
		if domain == 1 then
			if not fullMessage then
				return "Vessel Resonance Top Left\nEach level of Vessel\nResonance unlocks equivalent\nGem Mods in its domain. If the\nVessel Resonance matches t..."
			else
				return "Vessel Resonance Top Left\nEach level of Vessel\nResonance unlocks equivalent\nGem Mods in its domain. If the\nVessel Resonance matches\nthe gem quality, a damage\nand healing bonus is granted."
			end
		elseif domain == 2 then
			if not fullMessage then
				return "Vessel Resonance Top Right\nEach level of Vessel\nResonance unlocks equivalent\nGem Mods in its domain. If the\nVessel Resonance matches t..."
			else
				return "Vessel Resonance Top Right\nEach level of Vessel\nResonance unlocks equivalent\nGem Mods in its domain. If the\nVessel Resonance matches\nthe gem quality, a damage\nand healing bonus is granted."
			end
		elseif domain == 3 then
			if not fullMessage then
				return "Vessel Resonance Bottom Left\nEach level of Vessel\nResonance unlocks equivalent\nGem Mods in its domain. If the\nVessel Resonance matches t..."
			else
				return "Vessel Resonance Bottom Left\nEach level of Vessel\nResonance unlocks equivalent\nGem Mods in its domain. If the\nVessel Resonance matches\nthe gem quality, a damage\nand healing bonus is granted."
			end
		elseif domain == 4 then
			if not fullMessage then
				return "VR Bottom Right\nEach level of Vessel\nResonance unlocks equivalent\nGem Mods in its domain. If the\nVessel Resonance matches t..."
			else
				return "VR Bottom Right\nEach level of Vessel\nResonance unlocks equivalent\nGem Mods in its domain. If the\nVessel Resonance matches\nthe gem quality, a damage\nand healing bonus is granted."
			end
		end
	elseif bonus.conviction == "skill" then
		if vocation == KNIGHT then
			return string.format("+%d Weapon Skill Boost\nApplies to sword, axe and club\nfighting", attribute)
		elseif vocation == PALADIN then
			return string.format("+%d Distance Skill Boost", attribute)
		elseif vocation == SORCERER or vocation == DRUID then
			return string.format("+%d Magic Skill Boost", attribute)
		elseif vocation == MONK then
			return string.format("+%d Fist Fighting Skill Boost", attribute)
		end
	elseif bonus.conviction == "lifeleech" then
		return string.format("+%.2f%% Life Leech", attribute)
	elseif bonus.conviction == "manaleech" then
		return string.format("+%.2f%% Mana Leech", attribute)
	elseif bonus.conviction == "spell_1" then
		if vocation == KNIGHT then
			return "Aug. Front Sweep\nI: +40% Base Damage\nII: Enlarges the area to 5 SQMs"
		elseif vocation == PALADIN then
			local t = {}
			setStringColor(t, "Augmented Ethereal Barrage\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": +10% Life Leech\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": +10% Critical Hit Chance", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		elseif vocation == SORCERER then
			local t = {}
			setStringColor(t, "Augmented Focus Spells\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": +5% Base Damage for Hell's\nCore and Rage of the Skies\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": -4s Cooldown; Focus\nsecondary group cooldow...", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		elseif vocation == DRUID then
		        local t = {}
		        setStringColor(t, "Augmented Forked Spells\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
		        setStringColor(t, "I", "white")
		        setStringColor(t, ": -2s Cooldown\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
		        setStringColor(t, "II", "white")
		        setStringColor(t, ": +1 Chain Target", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
		        return t
		elseif vocation == MONK then
			local t = {}
			setStringColor(t, "Aug. Chained Penance\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": Jumps to +1 additional\ntarget\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": +18% Base Damage", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		end
	elseif bonus.conviction == "spell_2" then
		if vocation == KNIGHT then
			return "Aug. Shield Slam\nI: +15% Life Leech\nII: Next hostile autoattack damage reduction increased to 75%"
		elseif vocation == PALADIN then
			local t = {}
			setStringColor(t, "Aug. Strong Ethereal Spear\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": -2s Cooldown\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": +380% Base Damage", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		elseif vocation == SORCERER then
			local t = {}
			setStringColor(t, "Augmented Special Spells\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": -4s Cooldown for Lightning,\nStrong Energy Strike and\nStrong Flame Strike\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": +50% Base Damage", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		elseif vocation == DRUID then
			local t = {}
			setStringColor(t, "Augmented Mass Healing\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": +4% Base Healing\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": Affected area enlarged", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		elseif vocation == MONK then
			local t = {}
			setStringColor(t, "Augmented Mass Spirit Mend\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": +8% Base Healing\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": -4s Cooldown", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		end
	elseif bonus.conviction == "spell_3" then
		if vocation == KNIGHT then
			return "Aug. Groundshaker\nI: -2s Cooldown\nII: +12.5% Base Damage"
		elseif vocation == PALADIN then
			local t = {}
			setStringColor(t, "Augmented Divine Dazzle\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": Jumps to +2 additional\ntargets\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": -8s Cooldown", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		elseif vocation == SORCERER then
			local t = {}
			setStringColor(t, "Augmented Death Echo\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": -2s Cooldown\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": +12% Base Damage", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		elseif vocation == DRUID then
		        local t = {}
		        setStringColor(t, "Augmented Heal Friend\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
		        setStringColor(t, "I", "white")
		        setStringColor(t, ": +4% Base Healing\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
		        setStringColor(t, "II", "white")
		        setStringColor(t, ": +6% Base Healing", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
		        return t
		elseif vocation == MONK then
			local t = {}
			setStringColor(t, "Augmented Mystic Repulse\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": -4s Cooldown\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": +40% Base Damage", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		end
	elseif bonus.conviction == "spell_4" then
		if vocation == KNIGHT then
			return "Aug. Intense Wound Cleansing\nI: +125% Base Healing\nII: -300s Cooldown"
		elseif vocation == PALADIN then
			local t = {}
			setStringColor(t, "Augmented Divine Barrage\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": +8% Base Damage\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": +12% Base Damage", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		elseif vocation == SORCERER then
			local t = {}
			setStringColor(t, "Augmented Energy Wave\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": Affected area enlarged\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": +10% Base Damage", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		elseif vocation == DRUID then
			local t = {}
			setStringColor(t, "Augmented Terra Wave\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": +6.5% Base Damage\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": Adds 10% life leech to this\nspell", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		elseif vocation == MONK then
			local t = {}
			setStringColor(t, "Augmented Flurry of Blows\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": Affected area enlarged\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": +12% Base Damage", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		end
	elseif bonus.conviction == "spell_5" then
		if vocation == KNIGHT then
			return "Aug. Fierce Berserk\nI: -30 Mana Cost\nII: +10% Base Damage"
		elseif vocation == PALADIN then
			local t = {}
			setStringColor(t, "Augmented Divine Caldera\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": -20 Mana Cost\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": +10% Base Damage", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		elseif vocation == SORCERER then
			local t = {}
			setStringColor(t, "Augmented Great Fire Wave\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": +15% Critical Extra Damage\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": +5% Base Damage", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		elseif vocation == DRUID then
		        local t = {}
		        setStringColor(t, "Augmented Strong Ice Wave\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
		        setStringColor(t, "I", "white")
		        setStringColor(t, ": +6% Base Damage\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
		        setStringColor(t, "II", "white")
		        setStringColor(t, ": Affected area enlarged", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
		        return t
		elseif vocation == MONK then
			local t = {}
			setStringColor(t, "Aug. Thousand Fist Blows\n", (points >= bonus.maxPoints and "#C0C0C0" or "#707070"))
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(t, "I", "white")
			else
				setStringColor(t, "I", "white")
			end
			setStringColor(t, ": +40% Critical Extra Damage\n", (firstSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(t, "II", "white")
			else
				setStringColor(t, "II", "white")
			end
			setStringColor(t, ": -4s Cooldown", (secondSpellIsUnlocked(attribute) and "#C0C0C0" or "#707070"))
			return t
		end
	elseif bonus.conviction == "special_1" then
		if vocation == KNIGHT then
			if not fullMessage then
				return "Battle Instinct\nGain +6 shielding and +1\nsword/axe/club fighting when\n5 creatures are on adjacent\nsquares..."
			else
				return "Battle Instinct\nGain +6 shielding and +1\nsword/axe/club fighting when\n5 creatures are on adjacent\nsquares.\nFor each additional creature,\nup to a maximum of 8, you get\n+6 shielding and +1 sword/\naxe/club fighting more."
			end
		elseif vocation == PALADIN then
			if not fullMessage then
				return "Positional Tactics\nGain +3 distance fighting\nwhile no monster is within 1\nsquares. Otherwise gain +3\nholy magic level and +3 hea..."
			else
				return "Positional Tactics\nGain +3 distance fighting\nwhile no monster is within 1\nsquares. Otherwise gain +3\nholy magic level and +3\nhealing magic level."
			end
		elseif vocation == SORCERER then
			if not fullMessage then
				return "Runic Mastery\nIf you use a rune, you have a\n25% chance of increasing\nyour magic level by 10%, or\nby 20% if you use a rune th..."
			else
				return "Runic Mastery\nIf you use a rune, you have a\n25% chance of increasing\nyour magic level by 10%, or\nby 20% if you use a rune that\ncan be created by your\nvocation."
			end
		elseif vocation == DRUID then
			if not fullMessage then
				return "Healing Link\nIf you heal someone with\nNature's Embrace or Heal\nFriend, you also heal yourself\nfor 25% of the applied heali..."
			else
				return "Healing Link\nIf you heal someone with\nNature's Embrace or Heal\nFriend, you also heal yourself\nfor 25% of the applied\nhealing."
			end
		elseif vocation == MONK then
			if not fullMessage then
				return "Guiding Presence\nShare 100% mantra with nearby\nparty members while in combat.\nPassive vocation bonuses +33%."
			else
				return "Guiding Presence\nShare 100% mantra with nearby\nparty members while in combat.\nPassive vocation bonuses +33%."
			end
		end
	elseif bonus.conviction == "special_2" then
		if vocation == KNIGHT then
			if not fullMessage then
				return "Battle Healing\nIncreases Knight healing spells\nby 10%, or 20% while wielding\na shield."
			else
				return "Battle Healing\nIncreases all Knight healing\nspells by 10%. This bonus is\ndoubled while wielding a shield,\nfor a total increase of 20%."
			end
		elseif vocation == PALADIN then
			if not fullMessage then
				return "Ballistic Mastery\nThe critical extra damage for\nattacks with a crossbow is\nincreased by 10%.\nWhile wielding a bow your a..."
			else
				return "Ballistic Mastery\nThe critical extra damage for\nattacks with a crossbow is\nincreased by 10%.\nWhile wielding a bow your\nattacks and spells treat the\ntargets physical and holy\nsensitivity as being 2%\nhigher."
			end
		elseif vocation == SORCERER then
			return "Focus Mastery\nAfter casting a focus spell,\nthe next damage spell within\n12 seconds deals +35% damage.\nFocus spells: -2s primary\ncooldown."
		elseif vocation == DRUID then
			if not fullMessage then
				return "Runic Mastery\nIf you use a rune, you have a\n25% chance of increasing\nyour magic level by 10%, or\nby 20% if you use a rune th..."
			else
				return "Runic Mastery\nIf you use a rune, you have a\n25% chance of increasing\nyour magic level by 10%, or\nby 20% if you use a rune that\ncan be created by your\nvocation."
			end
		elseif vocation == MONK then
			if not fullMessage then
				return "Sanctuary\nConsuming Harmony creates\na field lasting 5 seconds,\nincreasing damage and..."
			else
				return "Sanctuary\nConsuming Harmony grants +2%\ndamage/healing per stack for 5s.\nAlso +10% damage/healing to\nadjacent targets."
			end
		end
	end
	return ""
end

function getConvictionPerks()
	local convictions = {}
  
	local vocation = WheelOfDestiny.vocationId
	local order = {
	  ["special_1"] = 1,
	  ["special_2"] = 2,
	  ["special_3"] = 3,
	  ["special_4"] = 4,
	  ["skill"] = 5,
	  ["lifeleech"] = 6,
	  ["manaleech"] = 7,
	  ["spell_1"] = 8,
	  ["spell_2"] = 9,
	  ["spell_3"] = 10,
	  ["spell_4"] = 11,
	  ["spell_5"] = 12,
	  ["vessel.1"] = 13,
	  ["vessel.2"] = 14,
	  ["vessel.3"] = 15,
	  ["vessel.4"] = 16,
	}
  
	for id, bonus in pairs(WheelBonus) do
	  repeat
	  local index = id + 1
	  if not WheelOfDestiny.isLit(index) then
		break
	  end
  
	  local t = order[bonus.conviction] or table.size(order) + 1
	  local attribute = WheelConsts[bonus.conviction]
	  local pointsInvested = WheelOfDestiny.pointInvested[index] or 0	
  
	  if pointsInvested ~= bonus.maxPoints then
		  break
	  end
  
	  if bonus.conviction ==  "special_1" then
		  convictions[t] = {perk = attribute[vocation][1], tooltip = attribute[vocation][2]}
	  elseif bonus.conviction ==  "special_2" then
		  convictions[t] = {perk = attribute[vocation][1], tooltip = attribute[vocation][2]}
	  elseif bonus.conviction ==  "special_3" then
		  if vocation == MONK then
			  convictions[t] = {perk = attribute[vocation][1], tooltip = attribute[vocation][2]}
		  end
	  elseif bonus.conviction ==  "special_4" then
		  if vocation == MONK then
			  convictions[t] = {perk = attribute[vocation][1], tooltip = attribute[vocation][2]}
		  end
	  elseif bonus.conviction ==  "manaleech" then
		if not convictions[t] then
		  convictions[t] = {perk = "Mana Leech", points = 0, stringPoint = ""}
		end
		convictions[t].points = convictions[t].points + attribute
		convictions[t].stringPoint = string.format("+%.2f%%", convictions[t].points)
	  elseif bonus.conviction ==  "lifeleech" then
		if not convictions[t] then
		  convictions[t] = {perk = "Life Leech", points = 0, stringPoint = ""}
		end
		convictions[t].points = convictions[t].points + attribute
		convictions[t].stringPoint = string.format("+%.2f%%", convictions[t].points)
	  elseif bonus.conviction ==  "vessel" then
		  t = "vessel."..bonus.domain
		  t = order[t]
			if bonus.domain == 1 then
				if not convictions[t] then
				  convictions[t] = {perk = "VR Top Left", points = 0, stringPoint = "I"}
				end
			  convictions[t].points = convictions[t].points + 1
			  if convictions[t].points == 1 then
				  convictions[t].stringPoint = "I"
			  elseif convictions[t].points == 2 then
				  convictions[t].stringPoint = "II"
			  else
				  convictions[t].stringPoint = "III"
			  end
			elseif bonus.domain == 2 then
				if not convictions[t] then
				  convictions[t] = {perk = "VR Top Right", points = 0, stringPoint = "I"}
				end
			  convictions[t].points = convictions[t].points + 1
			  if convictions[t].points == 1 then
				  convictions[t].stringPoint = "I"
			  elseif convictions[t].points == 2 then
				  convictions[t].stringPoint = "II"
			  else
				  convictions[t].stringPoint = "III"
			  end
			elseif bonus.domain == 3 then
				if not convictions[t] then
				  convictions[t] = {perk = "VR Bottom Left", points = 0, stringPoint = "I"}
				end
			  convictions[t].points = convictions[t].points + 1
			  if convictions[t].points == 1 then
				  convictions[t].stringPoint = "I"
			  elseif convictions[t].points == 2 then
				  convictions[t].stringPoint = "II"
			  else
				  convictions[t].stringPoint = "III"
			  end
		  else
				if not convictions[t] then
				  convictions[t] = {perk = "VR Bottom Right", points = 0, stringPoint = "I"}
				end
			  convictions[t].points = convictions[t].points + 1
			  if convictions[t].points == 1 then
				  convictions[t].stringPoint = "I"
			  elseif convictions[t].points == 2 then
				  convictions[t].stringPoint = "II"
			  else
				  convictions[t].stringPoint = "III"
			  end
			end
			convictions[t].tooltip = "Each level of Vessel Resonance unlocks equivalent Gem Mods in its\ndomain. If the Vessel Resonance matches the gem quality, a\ndamage and healing bonus is granted."
	  elseif bonus.conviction ==  "skill" then
		if not convictions[t] then
		  convictions[t] = {perk = "", points = 0, stringPoint = ""}
		end
		if vocation == KNIGHT then
		  convictions[t].perk = "Weapon Skill Boost"
		  convictions[t].points = convictions[t].points + attribute
		  convictions[t].stringPoint = string.format("+%d", convictions[t].points)
		  convictions[t].tooltip = "Applies to sword, axe and club fighting"
		elseif vocation == PALADIN then
		  convictions[t].perk = "Distance Skill Boost"
		  convictions[t].points = convictions[t].points + attribute
		  convictions[t].stringPoint = string.format("+%d", convictions[t].points)
		elseif vocation == SORCERER or vocation == DRUID then
		  convictions[t].perk = "Magic Skill Boost"
		  convictions[t].points = convictions[t].points + attribute
		  convictions[t].stringPoint = string.format("+%.2f%%", convictions[t].points)
		elseif vocation == MONK then
		  convictions[t].perk = "Fist Fighting Skill Boost"
		  convictions[t].points = convictions[t].points + attribute
		  convictions[t].stringPoint = string.format("+%d", convictions[t].points)
		 end
	  elseif bonus.conviction ==  "spell_1" then
		  if vocation == KNIGHT then
			  if not convictions[t] then
				  convictions[t] = {perk = "Aug. Front Sweep", points = 0, stringPoint = ""}
			  end
			  convictions[t].points = convictions[t].points + 1
			  if convictions[t].points == 1 then
				  convictions[t].stringPoint = "I"
			  else
				  convictions[t].stringPoint = "II"
			  end
			  local message = {}
			  if not firstSpellIsUnlocked(attribute) then
				  setStringColor(message, "I: ", "white")
			  else
				  setStringColor(message, "I: ", "white")
			  end
			  setStringColor(message, "+40% Base Damage\n", "#3F3F3F")
			  if not secondSpellIsUnlocked(attribute) then
				  setStringColor(message, "II: ", "white")
			  else
				  setStringColor(message, "II: ", "white")
			  end
			  setStringColor(message, "Affected area enlarged to 5 SQMs", "#3f3f3f")
			  convictions[t].tooltip = message
		  elseif vocation == PALADIN then
			  if not convictions[t] then
				  convictions[t] = {perk = "Aug. Ethereal Barrage", points = 0, stringPoint = ""}
			  end
			  convictions[t].points = convictions[t].points + 1
			  if convictions[t].points == 1 then
				  convictions[t].stringPoint = "I"
			  else
				  convictions[t].stringPoint = "II"
			  end
			  local message = {}
			  if not firstSpellIsUnlocked(attribute) then
				  setStringColor(message, "I", "white")
			  else
				  setStringColor(message, "I", "white")
			  end
			  setStringColor(message, "+10% Life Leech\n", "#3F3F3F")
			  if not secondSpellIsUnlocked(attribute) then
				  setStringColor(message, "II", "white")
			  else
				  setStringColor(message, "II", "white")
			  end
			  setStringColor(message, "+10% Critical Hit Chance", "#3F3F3F")
			  convictions[t].tooltip = message
		  elseif vocation == SORCERER then
			  if not convictions[t] then
				  convictions[t] = {perk = "Aug. Focus Spells", points = 0, stringPoint = ""}
			  end
			  convictions[t].points = convictions[t].points + 1
			  if convictions[t].points == 1 then
				  convictions[t].stringPoint = "I"
			  else
				  convictions[t].stringPoint = "II"
			  end
			  local message = {}
			  if not firstSpellIsUnlocked(attribute) then
				  setStringColor(message, "I", "white")
			  else
				  setStringColor(message, "I", "white")
			  end
			  setStringColor(message, "+5% Base Damage for Hell's Core and Rage of the Skies\n", "#3F3F3F")
			  if not secondSpellIsUnlocked(attribute) then
				  setStringColor(message, "II", "white")
			  else
				  setStringColor(message, "II", "white")
			  end
			  setStringColor(message, "-4s Cooldown; Focus secondary group cooldown -4s for Hell's\nCore and Rage of the Skies", "#3F3F3F")
			  convictions[t].tooltip = message
		  elseif vocation == DRUID then
		          if not convictions[t] then
		                  convictions[t] = {perk = "Aug. Forked Spells", points = 0, stringPoint = ""}
		          end
		          convictions[t].points = convictions[t].points + 1
		          if convictions[t].points == 1 then
		                  convictions[t].stringPoint = "I"
		          else
		                  convictions[t].stringPoint = "II"
		          end
		          local message = {}
		          setStringColor(message, "I: ", "white")
		          setStringColor(message, "-2s Cooldown\n", "#3F3F3F")
		          setStringColor(message, "II: ", "white")
		          setStringColor(message, "+1 Chain Target", "#3F3F3F")
		          convictions[t].tooltip = message
		  elseif vocation == MONK then
			  if not convictions[t] then
				  convictions[t] = {perk = "Aug. Chained Penance", points = 0, stringPoint = ""}
			  end
			  convictions[t].points = convictions[t].points + 1
			  if convictions[t].points == 1 then
				  convictions[t].stringPoint = "I"
			  else
				  convictions[t].stringPoint = "II"
			  end
			  local message = {}
			  if not firstSpellIsUnlocked(attribute) then
				  setStringColor(message, "I", "white")
			  else
				  setStringColor(message, "I", "white")
			  end
			  setStringColor(message, "Adds 3% mana leech to this spell\n", "#3F3F3F")
			  if not secondSpellIsUnlocked(attribute) then
				  setStringColor(message, "II", "white")
			  else
				  setStringColor(message, "II", "white")
			  end
			  setStringColor(message, "Adds 25% critical extra damage", "#3F3F3F")
			  convictions[t].tooltip = message
		  end
	  elseif bonus.conviction ==  "spell_2" then
		  if vocation == KNIGHT then
			  if not convictions[t] then
				  convictions[t] = {perk = "Aug. Shield Slam", points = 0, stringPoint = ""}
			  end
			  convictions[t].points = convictions[t].points + 1
			  if convictions[t].points == 1 then
				  convictions[t].stringPoint = "I"
			  else
				  convictions[t].stringPoint = "II"
			  end
			  local message = {}
			  if not firstSpellIsUnlocked(attribute) then
				  setStringColor(message, "I: ", "white")
			  else
				  setStringColor(message, "I: ", "white")
			  end
			  setStringColor(message, "+15% Life Leech\n", "#3F3F3F")
			  if not secondSpellIsUnlocked(attribute) then
				  setStringColor(message, "II: ", "white")
			  else
				  setStringColor(message, "II: ", "white")
			  end
			  setStringColor(message, "Next autoattack damage reduction increased to 75%", "#3F3F3F")
			  convictions[t].tooltip = message
		  elseif vocation == PALADIN then
			  if not convictions[t] then
				  convictions[t] = {perk = "Aug. Strong Ethereal Spear", points = 0, stringPoint = ""}
			  end
			  convictions[t].points = convictions[t].points + 1
			  if convictions[t].points == 1 then
				  convictions[t].stringPoint = "I"
			  else
				  convictions[t].stringPoint = "II"
			  end
			  local message = {}
			  if not firstSpellIsUnlocked(attribute) then
				  setStringColor(message, "I", "white")
			  else
				  setStringColor(message, "I", "white")
			  end
			  setStringColor(message, "-2s Cooldown\n", "#3F3F3F")
			  if not secondSpellIsUnlocked(attribute) then
				  setStringColor(message, "II", "white")
			  else
				  setStringColor(message, "II", "white")
			  end
			  setStringColor(message, "+380% Base Damage", "#3F3F3F")
			  convictions[t].tooltip = message
		  elseif vocation == SORCERER then
			  if not convictions[t] then
				  convictions[t] = {perk = "Aug. Special Spells", points = 0, stringPoint = ""}
			  end
			  convictions[t].points = convictions[t].points + 1
			  if convictions[t].points == 1 then
				  convictions[t].stringPoint = "I"
			  else
				  convictions[t].stringPoint = "II"
			  end
			  local message = {}
			  if not firstSpellIsUnlocked(attribute) then
				  setStringColor(message, "I", "white")
			  else
				  setStringColor(message, "I", "white")
			  end
			  setStringColor(message, "-4s Cooldown for Lightning, Strong Energy Strike and Strong Flame Strike\n", "#3F3F3F")
			  if not secondSpellIsUnlocked(attribute) then
				  setStringColor(message, "II", "white")
			  else
				  setStringColor(message, "II", "white")
			  end
			  setStringColor(message, "+50% Base Damage", "#3F3F3F")
			  convictions[t].tooltip = message
		  elseif vocation == DRUID then
			  if not convictions[t] then
				  convictions[t] = {perk = "Aug. Mass Healing", points = 0, stringPoint = ""}
			  end
			  convictions[t].points = convictions[t].points + 1
			  if convictions[t].points == 1 then
				  convictions[t].stringPoint = "I"
			  else
				  convictions[t].stringPoint = "II"
			  end
			  local message = {}
			  if not firstSpellIsUnlocked(attribute) then
				  setStringColor(message, "I", "white")
			  else
				  setStringColor(message, "I", "white")
			  end
			  setStringColor(message, "+4% Base Healing\n", "#3F3F3F")
			  if not secondSpellIsUnlocked(attribute) then
				  setStringColor(message, "II", "white")
			  else
				  setStringColor(message, "II", "white")
			  end
			  setStringColor(message, "Affected area enlarged", "#3F3F3F")
			  convictions[t].tooltip = message
		  elseif vocation == MONK then
			  if not convictions[t] then
				  convictions[t] = {perk = "Aug. Mass Spirit Mend", points = 0, stringPoint = ""}
			  end
			  convictions[t].points = convictions[t].points + 1
			  if convictions[t].points == 1 then
				  convictions[t].stringPoint = "I"
			  else
				  convictions[t].stringPoint = "II"
			  end
			  local message = {}
			  if not firstSpellIsUnlocked(attribute) then
				  setStringColor(message, "I", "white")
			  else
				  setStringColor(message, "I", "white")
			  end
			  setStringColor(message, "+8% Base Healing\n", "#3F3F3F")
			  if not secondSpellIsUnlocked(attribute) then
				  setStringColor(message, "II", "white")
			  else
				  setStringColor(message, "II", "white")
			  end
			  setStringColor(message, "Affected area enlarged", "#3F3F3F")
			  convictions[t].tooltip = message
		  end
	  elseif bonus.conviction == "spell_3" then
		  if vocation == KNIGHT then
			  if not convictions[t] then
				  convictions[t] = {perk = "Aug. Groundshaker", points = 0, stringPoint = ""}
			  end
			  convictions[t].points = convictions[t].points + 1
			  if convictions[t].points == 1 then
				  convictions[t].stringPoint = "I"
			  else
				  convictions[t].stringPoint = "II"
			  end
			  local message = {}
			  if not firstSpellIsUnlocked(attribute) then
				  setStringColor(message, "I: ", "white")
			  else
				  setStringColor(message, "I: ", "white")
			  end
			  setStringColor(message, "-2s Cooldown\n", "#3F3F3F")
			  if not secondSpellIsUnlocked(attribute) then
				  setStringColor(message, "II: ", "white")
			  else
				  setStringColor(message, "II: ", "white")
			  end
			  setStringColor(message, "+12.5% Base Damage", "#3F3F3F")
			  convictions[t].tooltip = message
		  elseif vocation == PALADIN then
			  if not convictions[t] then
				  convictions[t] = {perk = "Aug. Divine Dazzle", points = 0, stringPoint = ""}
			  end
			  convictions[t].points = convictions[t].points + 1
			  if convictions[t].points == 1 then
				  convictions[t].stringPoint = "I"
			  else
				  convictions[t].stringPoint = "II"
			  end
			  local message = {}
			  if not firstSpellIsUnlocked(attribute) then
				  setStringColor(message, "I", "white")
			  else
				  setStringColor(message, "I", "white")
			  end
			  setStringColor(message, "Jumps to +2 additional targets\n", "#3F3F3F")
			  if not secondSpellIsUnlocked(attribute) then
				  setStringColor(message, "II", "white")
			  else
				  setStringColor(message, "II", "white")
			  end
			  setStringColor(message, "-8s Cooldown", "#3F3F3F")
			  convictions[t].tooltip = message
		  elseif vocation == SORCERER then
			  if not convictions[t] then
				  convictions[t] = {perk = "Aug. Death Echo", points = 0, stringPoint = ""}
			  end
			  convictions[t].points = convictions[t].points + 1
			  if convictions[t].points == 1 then
				  convictions[t].stringPoint = "I"
			  else
				  convictions[t].stringPoint = "II"
			  end
			  local message = {}
			  if not firstSpellIsUnlocked(attribute) then
				  setStringColor(message, "I", "white")
			  else
				  setStringColor(message, "I", "white")
			  end
			  setStringColor(message, "-2s Cooldown\n", "#3F3F3F")
			  if not secondSpellIsUnlocked(attribute) then
				  setStringColor(message, "II", "white")
			  else
				  setStringColor(message, "II", "white")
			  end
			  setStringColor(message, "+12% Base Damage", "#3F3F3F")
			  convictions[t].tooltip = message
		  elseif vocation == DRUID then
		          if not convictions[t] then
		                  convictions[t] = {perk = "Aug. Heal Friend", points = 0, stringPoint = ""}
		          end
		          convictions[t].points = convictions[t].points + 1
		          if convictions[t].points == 1 then
		                  convictions[t].stringPoint = "I"
		          else
		                  convictions[t].stringPoint = "II"
		          end
		          local message = {}
		          setStringColor(message, "I: ", "white")
		          setStringColor(message, "+4% Base Healing\n", "#3F3F3F")
		          setStringColor(message, "II: ", "white")
		          setStringColor(message, "+6% Base Healing", "#3F3F3F")
		          convictions[t].tooltip = message
		elseif vocation == MONK then
			if not convictions[t] then
				convictions[t] = {perk = "Aug. Mystic Repulse", points = 0, stringPoint = ""}
			end
			convictions[t].points = convictions[t].points + 1
			if convictions[t].points == 1 then
				convictions[t].stringPoint = "I"
			else
				convictions[t].stringPoint = "II"
			end
			local message = {}
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(message, "I", "white")
			else
				setStringColor(message, "I", "white")
			end
			setStringColor(message, "-4s Cooldown\n", "#3F3F3F")
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(message, "II", "white")
			else
				setStringColor(message, "II", "white")
			end
			setStringColor(message, "+40% Base Damage", "#3F3F3F")
			convictions[t].tooltip = message
		end
	elseif bonus.conviction == "spell_4" then
		if vocation == KNIGHT then
			if not convictions[t] then
				convictions[t] = {perk = "Aug. Intense Wound C...", points = 0, stringPoint = ""}
			end
			convictions[t].points = convictions[t].points + 1
			if convictions[t].points == 1 then
				convictions[t].stringPoint = "I"
			else
				convictions[t].stringPoint = "II"
			end
			local message = {}
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(message, "I: ", "white")
			else
				setStringColor(message, "I: ", "white")
			end
			setStringColor(message, "+125% Base Healing\n", "#3F3F3F")
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(message, "II: ", "white")
			else
				setStringColor(message, "II: ", "white")
			end
			setStringColor(message, "-300s Cooldown", "#3F3F3F")
			convictions[t].tooltip = message
		elseif vocation == PALADIN then
			if not convictions[t] then
				convictions[t] = {perk = "Aug. Divine Barrage", points = 0, stringPoint = ""}
			end
			convictions[t].points = convictions[t].points + 1
			if convictions[t].points == 1 then
				convictions[t].stringPoint = "I"
			else
				convictions[t].stringPoint = "II"
			end
			local message = {}
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(message, "I", "white")
			else
				setStringColor(message, "I", "white")
			end
			setStringColor(message, "+8% Base Damage\n", "#3F3F3F")
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(message, "II", "white")
			else
				setStringColor(message, "II", "white")
			end
			setStringColor(message, "+12% Base Damage", "#3F3F3F")
			convictions[t].tooltip = message
		elseif vocation == SORCERER then
			if not convictions[t] then
				convictions[t] = {perk = "Aug. Energy Wave", points = 0, stringPoint = ""}
			end
			convictions[t].points = convictions[t].points + 1
			if convictions[t].points == 1 then
				convictions[t].stringPoint = "I"
			else
				convictions[t].stringPoint = "II"
			end
			local message = {}
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(message, "I", "white")
			else
				setStringColor(message, "I", "white")
			end
			setStringColor(message, "Affected area enlarged\n", "#3F3F3F")
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(message, "II", "white")
			else
				setStringColor(message, "II", "white")
			end
			setStringColor(message, "+10% Base Damage", "#3F3F3F")
			convictions[t].tooltip = message
		elseif vocation == DRUID then
			if not convictions[t] then
				convictions[t] = {perk = "Aug. Terra Wave", points = 0, stringPoint = ""}
			end
			convictions[t].points = convictions[t].points + 1
			if convictions[t].points == 1 then
				convictions[t].stringPoint = "I"
			else
				convictions[t].stringPoint = "II"
			end
			local message = {}
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(message, "I", "white")
			else
				setStringColor(message, "I", "white")
			end
			setStringColor(message, "+6.5% Base Damage\n", "#3F3F3F")
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(message, "II", "white")
			else
				setStringColor(message, "II", "white")
			end
			setStringColor(message, "Adds 10% life leech to this spell", "#3F3F3F")
			convictions[t].tooltip = message
		elseif vocation == MONK then
			if not convictions[t] then
				convictions[t] = {perk = "Aug. Flurry of Blows", points = 0, stringPoint = ""}
			end
			convictions[t].points = convictions[t].points + 1
			if convictions[t].points == 1 then
				convictions[t].stringPoint = "I"
			else
				convictions[t].stringPoint = "II"
			end
			local message = {}
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(message, "I", "white")
			else
				setStringColor(message, "I", "white")
			end
			setStringColor(message, "Adds 5% life leech to this spell", "#3F3F3F")
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(message, "II", "white")
			else
				setStringColor(message, "II", "white")
			end
			setStringColor(message, "+15% Base Damage", "#3F3F3F")
			convictions[t].tooltip = message
		end
	elseif bonus.conviction == "spell_5" then
		if vocation == KNIGHT then
			if not convictions[t] then
				convictions[t] = {perk = "Aug. Fierce Berserk", points = 0, stringPoint = ""}
			end
			convictions[t].points = convictions[t].points + 1
			if convictions[t].points == 1 then
				convictions[t].stringPoint = "I"
			else
				convictions[t].stringPoint = "II"
			end
			local message = {}
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(message, "I", "white")
			else
				setStringColor(message, "I", "white")
			end
			setStringColor(message, "-30 Mana Cost\n", "#3F3F3F")
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(message, "II", "white")
			else
				setStringColor(message, "II", "white")
			end
			setStringColor(message, "+10% Base Damage", "#3F3F3F")
			convictions[t].tooltip = message
		elseif vocation == PALADIN then
			if not convictions[t] then
				convictions[t] = {perk = "Aug. Divine Caldera", points = 0, stringPoint = ""}
			end
			convictions[t].points = convictions[t].points + 1
			if convictions[t].points == 1 then
				convictions[t].stringPoint = "I"
			else
				convictions[t].stringPoint = "II"
			end
			local message = {}
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(message, "I", "white")
			else
				setStringColor(message, "I", "white")
			end
			setStringColor(message, "-20 Mana Cost\n", "#3F3F3F")
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(message, "II", "white")
			else
				setStringColor(message, "II", "white")
			end
			setStringColor(message, "+10% Base Damage", "#3F3F3F")
			convictions[t].tooltip = message
		elseif vocation == SORCERER then
			if not convictions[t] then
				convictions[t] = {perk = "Aug. Great Fire Wave", points = 0, stringPoint = ""}
			end
			convictions[t].points = convictions[t].points + 1
			if convictions[t].points == 1 then
				convictions[t].stringPoint = "I"
			else
				convictions[t].stringPoint = "II"
			end
			local message = {}
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(message, "I", "white")
			else
				setStringColor(message, "I", "white")
			end
			setStringColor(message, "+15% Critical Extra Damage\n", "#3F3F3F")
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(message, "II", "white")
			else
				setStringColor(message, "II", "white")
			end
			setStringColor(message, "+5% Base Damage", "#3F3F3F")
			convictions[t].tooltip = message
		elseif vocation == DRUID then
		        if not convictions[t] then
		                convictions[t] = {perk = "Aug. Strong Ice Wave", points = 0, stringPoint = ""}
		        end
		        convictions[t].points = convictions[t].points + 1
		        if convictions[t].points == 1 then
		                convictions[t].stringPoint = "I"
		        else
		                convictions[t].stringPoint = "II"
		        end
		        local message = {}
		        setStringColor(message, "I: ", "white")
		        setStringColor(message, "+6% Base Damage\n", "#3F3F3F")
		        setStringColor(message, "II: ", "white")
		        setStringColor(message, "Affected area enlarged", "#3F3F3F")
		        convictions[t].tooltip = message
		elseif vocation == MONK then
			if not convictions[t] then
				convictions[t] = {perk = "Aug. Thousand Fist Blows", points = 0, stringPoint = ""}
			end
			convictions[t].points = convictions[t].points + 1
			if convictions[t].points == 1 then
				convictions[t].stringPoint = "I"
			else
				convictions[t].stringPoint = "II"
			end
			local message = {}
			if not firstSpellIsUnlocked(attribute) then
				setStringColor(message, "I", "white")
			else
				setStringColor(message, "I", "white")
			end
			setStringColor(message, "Adds 3% mana leech to this spell\n", "#3F3F3F")
			if not secondSpellIsUnlocked(attribute) then
				setStringColor(message, "II", "white")
			else
				setStringColor(message, "II", "white")
			end
			setStringColor(message, "Adds 25% critical extra damage for this spell and grants a 10% chance (non-cumulative) for a critical hit.", "#3F3F3F")
			convictions[t].tooltip = message
		end
    end

	  until true
  end

  return convictions
end

function getPassiveInfo(domain)
	local extraPoints = WheelOfDestiny.extraPassivePoints[domain] or 0
	local passive = WheelOfDestiny.passivePoints[domain] + extraPoints
	local message = {}

	local function currentUnlocked(i)
		if passive >= 1000 and i == 3 then
			return true
		elseif passive >= 500 and passive < 1000 and i == 2 then
			return true
		elseif passive >= 250 and passive < 500 and i == 1 then
			return true
		else
			return false
		end
	end

	local m1 = ""
	local m2 = ""
	local vocation = WheelOfDestiny.vocationId
	if domain == 1 then
		setStringColor(message, "If an attack (except with agony damage) were to kill you but the\noverkill damage amounts to less than ", "#3F3F3F")
		setStringColor(message, "20%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
		setStringColor(message, "/", "#3F3F3F")
		setStringColor(message, "25%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
		setStringColor(message, "/", "#3F3F3F")
		setStringColor(message, "30% ", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
		setStringColor(message, "of your\nmaximum hit points, you will heal yourself for ", "#3F3F3F")
		setStringColor(message, "20%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
		setStringColor(message, "/", "#3F3F3F")
		setStringColor(message, "25%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
		setStringColor(message, "/", "#3F3F3F")
		setStringColor(message, "30% ", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
		setStringColor(message, " of\nyour maximum hit points. Only after that is the damage applied.\nIn addition, all your spell cooldowns are reduced by 60 seconds.\n\nCooldown: ", "#3F3F3F")
		setStringColor(message, "30h", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
		setStringColor(message, "/", "#3F3F3F")
		setStringColor(message, "20h", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
		setStringColor(message, "/", "#3F3F3F")
		setStringColor(message, "10h ", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
		m1 = "Gift of Life\nAllows you to survive an\notherwise fatal blow."
		m2 = message
	elseif domain == 2 then
		if vocation == KNIGHT then
			m1 = "Executioner's Throw\nThrowing attack that deals\nmassive damage to enemies\nwith low hit points."
			setStringColor(message, "This spell throws your weapon on your target and jumps on ", "#3F3F3F")
			setStringColor(message, "2", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "3", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "4\n ", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "nearby enemies. Deals ", "#3F3F3F")
			setStringColor(message, "100%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "125%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "150%  ", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "additional damage to\ntargets with less than 30% of their hit points.\nCooldown: ", "#3F3F3F")
			setStringColor(message, "18", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "14", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "10", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, " seconds", "#3F3F3F")
			m2 = message
		elseif vocation == PALADIN then
			setStringColor(message, "This spell plants a marker at the feet of your target that explodes\nafter 3 seconds, dealing holy damage. +16% Base Damage with\nhigher spell stages.\n\nCooldown: ", "#3F3F3F")
			setStringColor(message, "26", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "20", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "14", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, " seconds", "#3F3F3F")
			m1 = "Divine Grenade\nDeploy a powerful delayed\neffect that deals holy damage."
			m2 = message
		elseif vocation == SORCERER then
			setStringColor(message, "Beam spells also hit adjacent fields for ", "#3F3F3F")
			setStringColor(message, "25%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "40%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "70%", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, " damage.\n\nFor each target hit by the central beam, all other spell cooldowns\nare reduced by 1 second, up to 3 seconds, and central beam damage\nincreases by ", "#3F3F3F")
			setStringColor(message, "10%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "12%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "14%", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, " per target, up to ", "#3F3F3F")
			setStringColor(message, "30%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "36%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "42%", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, ".", "#3F3F3F")
			m1 = "Beam Mastery\nExpands beam spells and improves\ntheir central line when targets\nare hit."
			m2 = message
		elseif vocation == DRUID then
			setStringColor(message, "Healing spells can critically heal using your critical chance and extra damage.\nYour healing is increased by\n", "#3F3F3F")
			setStringColor(message, "5%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "7.5%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "10%", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "if the target has less\nthan 60% but more than 30% of\ntheir hit points.\n", "#3F3F3F")
			setStringColor(message, "Your healing is increased by\n", "#3F3F3F")
			setStringColor(message, "10%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "15%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "20%", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "if the target has less\nthan 30% of their hit points.", "#3F3F3F")
			m1 = "Blessing of the Grove\nHealing spells can critically heal. Healing also increases when the target is below 60% or 30% HP."
			m2 = message
		elseif vocation == MONK then
			setStringColor(message, "This spell consumes your Harmony. Releases a massive attack\nchaining to ", "#3F3F3F")
			setStringColor(message, "7", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, " additional enemies. When used with full Harmony,\n", "#3F3F3F")
			setStringColor(message, "repeats after 1 second for ", "#3F3F3F")
			setStringColor(message, "37.5%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "50%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "62.5%", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, " of its original\ndamage. Cooldown: ", "#3F3F3F")
			setStringColor(message, "24", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "20", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "16", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, " seconds.", "#3F3F3F")
			m1 = "Spiritual Outburst\nA powerful spell that consumes\nHarmony to release a massive\nchain attack."
			m2 = message
		end
	elseif domain == 3 then
		if vocation == KNIGHT then
			setStringColor(message, "Reduces damage taken by 1% for each ", "#3F3F3F")
			setStringColor(message, "14", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "12", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "10% missing HP; doubled with a shield.\n", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "Increases damage dealt by 1% for each ", "#3F3F3F")
			setStringColor(message, "14", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "12", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "10% target missing HP; doubled with a two-handed weapon.", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			m1 = "Combat Mastery\nScale offense and defense\nwith missing hit points."
			m2 = message
		elseif vocation == PALADIN then
			setStringColor(message, "This support spell creates a field of holy energy around your feet\nfor 5 seconds. As long as you stand in this field, your dealt damage\nincreases by ", "#3F3F3F")
			setStringColor(message, "8%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "10%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "12%.\n\n", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "Cooldown: ", "#3F3F3F")
			setStringColor(message, "32", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "28", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "24", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "seconds", "#3F3F3F")
			m1 = "Divine Empowerment\nThis support spell creates a\nfield that increases your dealt\ndamage."
			m2 = message
		elseif vocation == SORCERER then
			setStringColor(message, "Increases the bonus granted by your active elemental stance.\n\nMaster of Flames: +", "#3F3F3F")
			setStringColor(message, "2%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "3%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "4%", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, " Base Power for fire spells.\nMaster of Thunder: +", "#3F3F3F")
			setStringColor(message, "2%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "3%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "4%", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, " critical hit chance for energy spells.\nMaster of Decay: +", "#3F3F3F")
			setStringColor(message, "15%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "22.5%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "30%", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, " critical extra damage for death spells.", "#3F3F3F")
			m1 = "Lord of Destruction\nIncreases the bonus effects of\nyour active elemental stance."
			m2 = message
		elseif vocation == DRUID then
			setStringColor(message, "Decide wisely whether you want to cast ice or earth damage in a\nsmall area around you, as these two ring spells share the same\ncooldown. Both spells deal ", "#3F3F3F")
			setStringColor(message, "20%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "40%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "60%", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, " additional damage to\ntargets with more than 60% of their hit points.\nCooldown: ", "#3F3F3F")
			setStringColor(message, "22", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "18", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "14", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, " seconds", "#3F3F3F")
			m1 = "Twin Bursts\nPowerful ring spell that deals\nice or earth damage that is\nenhanced against targets with\nhigh hit points."
			m2 = message
		elseif vocation == MONK then
			setStringColor(message, "Increases the Harmony base bonus by ", "#3F3F3F")
			setStringColor(message, "1%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "2%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "3%", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, " and your\nautoattacks deal additional damage equal to ", "#3F3F3F")
			setStringColor(message, "100%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "200%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
			setStringColor(message, "/", "#3F3F3F")
			setStringColor(message, "300%", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
			setStringColor(message, " of\nyour mantra.", "#3F3F3F")
			m1 = "Ascetic\nImprove all spenders and allows\nmantra to improve the damage\nof your attacks."
			m2 = message
		end
	elseif domain == 4 then
		setStringColor(message, "This spell transforms yourself into a powerful avatar for 15 \nseconds.\nWhile in this form, you benefit from ", "#3F3F3F")
		setStringColor(message, "5%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
		setStringColor(message, "/", "#3F3F3F")
		setStringColor(message, "10%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
		setStringColor(message, "/", "#3F3F3F")
		setStringColor(message, "15%", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
		setStringColor(message, " damage \nreduction and all your attacks are critical hits with ", "#3F3F3F")
		setStringColor(message, "5%", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
		setStringColor(message, "/", "#3F3F3F")
		setStringColor(message, "10%", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
		setStringColor(message, "/", "#3F3F3F")
		setStringColor(message, "15%\n", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
		setStringColor(message, "critical extra damage.\nCooldown: ", "#3F3F3F")
		setStringColor(message, "120", currentUnlocked(1) and "#ffffff" or "#3F3F3F")
		setStringColor(message, "/", "#3F3F3F")
		setStringColor(message, "90", currentUnlocked(2) and "#ffffff" or "#3F3F3F")
		setStringColor(message, "/", "#3F3F3F")
		setStringColor(message, "60", currentUnlocked(3) and "#ffffff" or "#3F3F3F")
		setStringColor(message, " minutes", "#3F3F3F")
		if vocation == KNIGHT then
			m1 = "Avatar of Steel\nTransforms you into a\npowerful form that reduces\ndamage taken and increases\ndamage dealt."
			m2 = message
		elseif vocation == PALADIN then
			m1 = "Avatar of Light\nTransforms you into a\npowerful form that reduces\ndamage taken and increases\ndamage dealt."
			m2 = message
		elseif vocation == SORCERER then
			m1 = "Avatar of Storm\nTransforms you into a\npowerful form that reduces\ndamage taken and increases\ndamage dealt."
			m2 = message
		elseif vocation == DRUID then
			m1 = "Avatar of Nature\nTransforms you into a\npowerful form that reduces\ndamage taken and increases\ndamage dealt."
			m2 = message
		elseif vocation == MONK then
			m1 = "Avatar of Balance\nTransforms you into a\npowerful form that reduces\ndamage taken and increases\ndamage dealt."
			m2 = message
		end
	end

	return m1, m2
end

function getBonusValueUpgrade(currentBonusID, gemID, supreme, firstBonus)
	local gem = GemAtelier.getGemDataById(gemID)
	if not gem then
		return 0
	end

	local slot = 0
	if gem.lesserBonus == currentBonusID then
		slot = 0
	elseif gem.regularBonus == currentBonusID then
		slot = 1
	elseif gem.supremeBonus == currentBonusID then
		slot = 2
	end

	local effectiveLevel = GemAtelier.getEffectiveLevel(gem, currentBonusID, supreme, slot)
	local modInfo = Workshop.getDataByBonus(currentBonusID, supreme)
	local bonus = Workshop.getBonusValue(modInfo, effectiveLevel, firstBonus)
	return bonus
end

function getValueByVocation(bonusType, steps)
	local step = bonusStep[WheelOfDestiny.vocationId]
	local bonus = 0

	if bonusType == "mana" then
		bonus = steps * step.mana
	elseif bonusType == "life" then
		bonus = steps * step.life
	elseif bonusType == "capacity" then
		bonus = steps * step.capacity
	end

	return bonus
end

function getVesselBonus()
	local bonuses = {}
	local defenses = {}

	local function findBonusByText(text)
		for i, b in ipairs(bonuses) do
			if b.text == text then
				return b, i
			end
		end
		return nil
	end

	local function findDefenseByText(text)
		for i, b in ipairs(defenses) do
			if b.text == text then
				return b, i
			end
		end
		return nil
	end

	for _, k in pairs(WheelOfDestiny.equipedGemBonuses) do
		repeat
		if k.bonusID == -1 then
			break
		end

		local bonus = k.supreme and SupremeGemDescription[k.bonusID] or RegularGemDescription[k.bonusID]
		local firstString, secondString
		local skipIndex = bonus.text:find("\n")

		if skipIndex then
			firstString = bonus.text:sub(1, skipIndex - 1)
			secondString = bonus.text:sub(skipIndex + 1)
		else
			firstString = bonus.text
		end

		if not k.supreme then
			if firstString then
				-- Solo bonus
				if firstString:find("Mitigation") then
					local number = getBonusValueUpgrade(k.bonusID, k.gemID, k.supreme, true)
					local existingBonus = findBonusByText("Mitigation Mult.")
					if existingBonus then
						existingBonus.value = existingBonus.value + tonumber(number)
					else
						bonuses[#bonuses + 1] = {bonusType = bonus.type1, text = "Mitigation Mult.", value = number, tooltip = bonus.tooltip}
					end
					break
				end

				local number = getBonusValueUpgrade(k.bonusID, k.gemID, k.supreme, true)
				local message = firstString:match("@%s*(.+)")
				if bonus.type1 == "defense" then
					number = getBonusValueUpgrade(k.bonusID, k.gemID, k.supreme, true)
					message = firstString:gsub("^%+%s*%% ", "")
				end

				local existingBonus = findBonusByText(message)
				if bonus.type1 == "defense" then
					existingBonus = findDefenseByText(message)
				end

				if existingBonus then
					existingBonus.value = existingBonus.value + tonumber(number)
				else
					if bonus.type1 == "defense" then
						defenses[#defenses + 1] = {bonusType = bonus.type1, text = message, value = number}
					else
						bonuses[#bonuses + 1] = {bonusType = bonus.type1, text = message, value = "+" .. number}
					end
				end
			end

			if secondString then
				local number = getBonusValueUpgrade(k.bonusID, k.gemID, k.supreme, false)
				local message = secondString:match("@%s*(.+)")
				if bonus.type2 == "defense" then
					if bonus.bonus2 and bonus.bonus2 == -1 then
						number, message = secondString:match("([-]?%d+%.?%d*)%% (.+)")
					else
						number = getBonusValueUpgrade(k.bonusID, k.gemID, k.supreme, false)
						message = secondString:gsub("^%+%s*%% ", "")
					end
				end

				local existingBonus = findBonusByText(message)
				if bonus.type2 == "defense" then
					existingBonus = findDefenseByText(message)
				end

				if existingBonus then
					existingBonus.value = existingBonus.value + tonumber(number)
				else
					if bonus.type2 == "defense" then
						defenses[#defenses + 1] = {bonusType = bonus.type2, text = message, value = number}
					else
						bonuses[#bonuses + 1] = {bonusType = bonus.type2, text = message, value = "+" .. number}
					end
				end
			end
		else
			if bonus.text:find("RM") then
				local number = getBonusValueUpgrade(k.bonusID, k.gemID, k.supreme, true)
				local existingBonus = findBonusByText(short_text(bonus.text, 17))
				if existingBonus then
					existingBonus.value = existingBonus.value + tonumber(number)
				else
					bonuses[#bonuses + 1] = {bonusType = "revelation", text = short_text(bonus.text, 17), value = number, tooltip = bonus.tooltip}
				end
			elseif not bonus.text:find("\n") then
				local number, message = firstString:match("([-]?%d+%.?%d*)%% (.+)")
				local existingBonus = findBonusByText(message)
				if existingBonus then
					existingBonus.value = existingBonus.value + tonumber(number)
				else
					bonuses[#bonuses + 1] = {bonusType = "special", text = message, value = number}
				end
			elseif bonus.text:find("Aug.") then
				local bonusName = firstString
				local number = getBonusValueUpgrade(k.bonusID, k.gemID, k.supreme, true)
				local tooltip = bonus.tooltip
				bonusName = bonusName:gsub("Aug. ", "")
				if vocation == 5 then -- Monk
					if bonusName == "Greater Flurry of Blows" then
						tooltip = string.format("+%d%% Base Damage", number) -- Example adjustment
					end
				end
				local existingBonus = findBonusByText(bonusName)

				if existingBonus then
					existingBonus.value = existingBonus.value + tonumber(number)
					if string.find(tooltip, "%%") then
						existingBonus.tooltip = tr(tooltip, existingBonus.value)
					end
				else
					if string.find(tooltip, "%%") then
						tooltip = tr(tooltip, number)
					end
					bonuses[#bonuses + 1] = {bonusType = "augment", text = short_text(bonusName, 15), value = number, tooltip = tooltip}
				end
			end
		end

		until true
	end

	if #defenses > 0 then
		bonuses[#bonuses + 1] = {bonusType = "defense", text = ("Resistances:"), value = -1}
	end

	for _, v in pairs(defenses) do
		repeat
		if v.value == 0 then
			break
		end

		local valueString = tonumber(v.value) > 0 and "+" .. v.value or v.value
		bonuses[#bonuses + 1] = {bonusType = v.bonusType, text = ("  " .. v.text:gsub(" Resistance", "")), value = (valueString .. "%")}
		until true
	end

	-- Damage and healing
	local DHcount = GemAtelier:getDamageAndHealing()

	if DHcount > 0 then
		table.insert(bonuses, 1, {bonusType = "damagehealing", text = "Damage and Healing", value = "+" .. DHcount, tooltip = "If the Vessel Resonance matches the gem quality in this domain, a\nbonus of +1 to all damage and healing is granted. This bonus is\nincreased by 1 for greater gems.\n\nRegardless of the match, gems will always grant mod bonuses\nbased on the Vessel Resonance.\n? Lesser gems match Dormant Vessels (VR I)\n? Regular gems match Awakened Vessels (VR II)\n? Greater gems match Radiant Vessels (VR III)"})
	end
	return bonuses
end
