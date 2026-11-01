helperWindow = nil
helperButton = nil
selectedSlot = nil
currentVocation = nil
healingEvent = nil
healingEnabled = true
autoAttackEvent = nil
autoAttackWakeEvent = nil
attackRotationEvent = nil
autoAttackEnabled = false
attackRotationEnabled = false
autoAttackMode = 'A'
attackPreset = 'default'
helperPreset = 'default'
helperPresetNames = { 'Default' }
attackPresetNames = { 'Default' }
selectedAttackPostures = { stance = nil, passive = nil }
attackPostureCastEvent = nil
attackPostureCooldownEvent = nil
updatingHelperPreset = false
currentHelperTab = 'healing'
updatingAutoAttackControls = false
updatingAttackPreset = false
updatingAttackPriority = false
updatingAttackMultiple = false
restoringAttackSlots = false
lastAutoAttackTargetId = nil
lastAutoAttackPacketAt = 0
pendingAttackTurnDirection = nil
lastAttackTurnAt = 0
local manualSpellPriorityUntil, manualItemPriorityUntil = 0, 0
local MANUAL_ACTION_PRIORITY_MS = 750

function notifyManualAction(kind)
    if not g_game.isOnline() then return end
    local deadline=g_clock.millis()+MANUAL_ACTION_PRIORITY_MS
    manualSpellPriorityUntil=deadline
    if kind=='item' then manualItemPriorityUntil=deadline end
    pendingAttackTurnDirection=nil
end

function isManualActionPending()
    return g_clock.millis()<manualSpellPriorityUntil
end

local function isManualItemPending()
    return g_clock.millis()<manualItemPriorityUntil
end
updatingEnabledCheckBox = false
nextPotionAt = 0
assignmentGrabber = nil
local assigningHelperItem
assigningPotionSlot = nil
assigningExerciseWeapon = false
assignmentCursorEvent = nil
cancelItemAssignment = nil
exerciseHelperRestoreEvent = nil
spellSelectorOpen = false
restoreHelperAfterAssignment = false
selectedPartyMember = nil
partyMemberRows = {}
selectedMassPartyMember = nil
massPartyMemberRows = {}
partySessionActive = false
lastPartyRefreshAt = 0
nextFriendHealingAt = 0
spellCooldownsById = {}
spellGroupCooldownsById = {}
autoEatEvent = nil
helperNotification = nil
helperNotificationEvent = nil
presetNameWindow = nil
presetNameKind = nil
presetDeleteWindow = nil
updatingExtrasControls = false
updateExtrasControls = nil
extrasToggleResetEvent = nil
extrasToggleResetPlayerKey = nil
nextAutoEatAt = 0
local AUTO_HASTE = {
    event = nil,
    nextAt = 0,
    selectedSpell = nil,
    checkInterval = 250,
    retryInterval = 1000,
    spellNames = { 'Haste', 'Strong Haste', 'Charge', 'Swift Foot' }
}
local CLEARED_HASTE_SPELL = '__none__'
local MANA_TRAINING = {
    event = nil,
    nextAt = 0,
    selectedSpell = nil,
    enabled = false,
    threshold = 90,
    checkInterval = 250,
    retryInterval = 1000
}
EXERCISE_TRAINING = {
    event = nil,
    nextAt = 0,
    selectedWeaponId = nil,
    enabled = false,
    dispatched = false,
    walking = false,
    destination = nil,
    targetPosition = nil,
    checkInterval = 500,
    verificationInterval = 120000,
    searchRetryInterval = 2000,
    noticeInterval = 5000,
    lastNoticeAt = 0,
    walkTimeout = 15000,
    walkStartedAt = 0
}
ATTACK_AFK = {
    timeout = 120000,
    trackingSince = 0
}
exerciseTrainingSessions = {}
activeExerciseCharacterKey = nil

local HEALING_CHECK_INTERVAL = 100
local AUTO_ATTACK_CHECK_INTERVAL = 50
local AUTO_ATTACK_NEW_TARGET_INTERVAL = 0
local AUTO_ATTACK_RETRY_INTERVAL = 500
local POTION_COOLDOWN = 1000
local FRIEND_HEALING_COOLDOWN = 1000
local PARTY_REFRESH_INTERVAL = 500
local ATTACK_ROTATION_INTERVAL = 100
local ATTACK_TURN_RETRY_INTERVAL = 300
local SPELL_COMMAND_GUARD = 350
local AUTO_EAT_CHECK_INTERVAL = 1500
local AUTO_EAT_RETRY_INTERVAL = 1100
local AUTO_EAT_BELOW_SECONDS = 300
local DEFAULT_THRESHOLDS = { 90, 60, 40 }
local HELPER_WINDOW_WIDTH = 430
local HELPER_ATTACK_WIDTH = 550
-- OTUI stretches horizontally through anchors. Vertically, use the content
-- visible on each page so the window does not retain a large empty footer.
local HELPER_HEALING_HEIGHT = 394
local HELPER_SINGLE_FRIEND_HEIGHT = 504
local HELPER_FRIEND_HEIGHT = 524
local HELPER_DRUID_HEIGHT = 679
local HELPER_ATTACK_HEIGHT = 554
local HELPER_EXTRAS_HEIGHT = 502
EXTRAS_TOGGLE_RESET_VERSION = 1
EXTRAS_TOGGLE_RESET_COMMAND_DELAY = 600

-- These IDs mirror data/scripts/actions/items/exercise_training_weapons.lua.
-- `farUse` is intentionally absent for melee, fist and shield weapons.
EXERCISE_WEAPONS = {
    [50292] = {}, [50293] = {}, [50294] = {}, [50295] = {},
    [28540] = {}, [28552] = {}, [35279] = {}, [35285] = {},
    [28541] = {}, [28553] = {}, [35280] = {}, [35286] = {},
    [28542] = {}, [28554] = {}, [35281] = {}, [35287] = {},
    [44064] = {}, [44065] = {}, [44066] = {}, [44067] = {},
    [28543] = { farUse = true }, [28555] = { farUse = true },
    [35282] = { farUse = true }, [35288] = { farUse = true },
    [28544] = { farUse = true }, [28556] = { farUse = true },
    [35283] = { farUse = true }, [35289] = { farUse = true },
    [28545] = { farUse = true }, [28557] = { farUse = true },
    [35284] = { farUse = true }, [35290] = { farUse = true }
}

EXERCISE_DUMMY_IDS = {
    [28558] = true, [28559] = true, [28560] = true, [28561] = true,
    [28562] = true, [28563] = true, [28564] = true, [28565] = true
}

local VOCATION_PROFILES = {
    [1] = { key = 'knight', friendHealing = false, massFriendHealing = false },
    [2] = { key = 'paladin', friendHealing = false, massFriendHealing = false },
    [3] = { key = 'sorcerer', friendHealing = true, friendLabel = 'Enable UH', friendKind = 'uh', friendSlotCount = 1, massFriendHealing = false },
    [4] = { key = 'druid', friendHealing = true, friendLabel = 'Enable Sio', friendKind = 'sio', massFriendHealing = true },
    [5] = { key = 'monk', friendHealing = true, friendLabel = 'Enable Sio', friendKind = 'monkSio', massFriendHealing = false },
    [6] = { key = 'druid', friendHealing = true, friendLabel = 'Enable Sio', friendKind = 'sio', massFriendHealing = true },
    [7] = { key = 'paladin', friendHealing = false, massFriendHealing = false },
    [8] = { key = 'knight', friendHealing = false, massFriendHealing = false },
    [9] = { key = 'monk', friendHealing = true, friendLabel = 'Enable Sio', friendKind = 'monkSio', massFriendHealing = false },
    [10] = { key = 'monk', friendHealing = true, friendLabel = 'Enable Sio', friendKind = 'monkSio', massFriendHealing = false },
    [11] = { key = 'knight', friendHealing = false, massFriendHealing = false },
    [12] = { key = 'paladin', friendHealing = false, massFriendHealing = false },
    [13] = { key = 'sorcerer', friendHealing = true, friendLabel = 'Enable UH', friendKind = 'uh', friendSlotCount = 1, massFriendHealing = false },
    [14] = { key = 'druid', friendHealing = true, friendLabel = 'Enable Sio', friendKind = 'sio', massFriendHealing = true },
    [15] = { key = 'monk', friendHealing = true, friendLabel = 'Enable Sio', friendKind = 'monkSio', massFriendHealing = false }
}

local ATTACK_SPELL_SLOT_COUNTS = {
    knight = 5,
    paladin = 5,
    sorcerer = 5,
    druid = 5,
    monk = 5
}

local ATTACK_RUNE_SLOT_COUNTS = {
    knight = 0,
    paladin = 2,
    sorcerer = 2,
    druid = 2,
    monk = 2
}

local LURE_SPELL_NAMES = {
    knight = { 'Chivalrous Challenge', 'Challenge' },
    paladin = { 'Divine Dazzle' },
    monk = { 'Balanced Brawl' }
}

local ATTACK_RUNE_WIDGET_COUNT = 2

local ATTACK_POSTURE_OPTIONS = {
    paladin = {
        stance = {
            { id = 'sharpshooter', spellId = 313, name = 'Sharpshooter', words = 'utori con', clientId = 197 },
            { id = 'divine_defiance', spellId = 314, name = 'Divine Defiance', words = 'utori hur', clientId = 198 }
        }
    },
    knight = {
        stance = {
            { id = 'blood_rage', spellId = 133, name = 'Blood Rage', words = 'utito tempo', clientId = 95 },
            { id = 'protector', spellId = 132, name = 'Protector', words = 'utamo tempo', clientId = 121 }
        }
    },
    druid = {
        stance = {
            { id = 'shared_conservation', spellId = 309, name = 'Shared Conservation', words = 'utura sio', clientId = 191 },
            { id = 'elemental_synthesis', spellId = 319, name = 'Elemental Synthesis', words = 'utito dru', clientId = 192 }
        }
    },
    sorcerer = {
        stance = {
            { id = 'master_of_flames', spellId = 304, name = 'Master of Flames', words = 'uteta flam', clientId = 193 },
            { id = 'master_of_thunder', spellId = 305, name = 'Master of Thunder', words = 'uteta vis', clientId = 194 },
            { id = 'master_of_decay', spellId = 306, name = 'Master of Decay', words = 'uteta mort', clientId = 195 }
        },
        passive = {
            { id = 'sapped_strength', spellId = 244, name = 'Aura of Sapped Strength', words = 'exori kor tempo', clientId = 110 },
            { id = 'exposed_weakness', spellId = 243, name = 'Aura of Exposed Weakness', words = 'exori moe tempo', clientId = 109 }
        }
    }
}

local ATTACK_POSTURE_BUTTON_IDS = {
    stance = { 'attackStanceButton1', 'attackStanceButton2', 'attackStanceButton3' },
    passive = { 'attackPassiveButton1', 'attackPassiveButton2' }
}

local ATTACK_MAX_CREATURES = 10
local ATTACK_MAX_PRIORITY = 5
local MONK_FULL_HARMONY = 5

local MONK_FULL_HARMONY_SPELLS = {
    ['exori mas nia'] = true,
    ['exori gran mas nia'] = true
}

local ATTACK_RUNES = {
    [3155] = { id = 3155, name = 'Sudden Death Rune', area = false },
    [3161] = { id = 3161, name = 'Avalanche Rune', area = true },
    [3175] = { id = 3175, name = 'Stone Shower Rune', area = true },
    [3191] = { id = 3191, name = 'Great Fireball Rune', area = true },
    [3202] = { id = 3202, name = 'Thunderstorm Rune', area = true }
}

-- SpellInfo contains cast range, but not the actual combat-area geometry.
-- These profiles keep the monster condition tied to tiles that the spell can
-- really hit instead of counting every monster visible on the game screen.
local ATTACK_DIRECTIONAL_AREAS = {
    wave6 = { {-1, -1}, {0, -1}, {1, -1} },
    wave4 = {
        {-1, -1}, {0, -1}, {1, -1},
        {-1, -2}, {0, -2}, {1, -2},
        {-2, -3}, {-1, -3}, {0, -3}, {1, -3}, {2, -3}
    },
    wave7 = {
        {-1, -1}, {0, -1}, {1, -1},
        {-1, -2}, {0, -2}, {1, -2},
        {-2, -3}, {-1, -3}, {0, -3}, {1, -3}, {2, -3},
        {-2, -4}, {-1, -4}, {0, -4}, {1, -4}, {2, -4}
    },
    strongIceWave = {
        {0, -1},
        {-1, -2}, {0, -2}, {1, -2},
        {-1, -3}, {0, -3}, {1, -3},
        {-1, -4}, {0, -4}, {1, -4}
    },
    shortWave3 = {
        {-1, -1}, {0, -1}, {1, -1},
        {-1, -2}, {0, -2}, {1, -2}
    },
    squareWave5 = {
        {0, -1},
        {0, -2},
        {-1, -3}, {0, -3}, {1, -3},
        {-1, -4}, {0, -4}, {1, -4},
        {-1, -5}, {0, -5}, {1, -5}
    },
    beam5 = { {0, -1}, {0, -2}, {0, -3}, {0, -4} },
    beam6 = { {0, -1}, {0, -2}, {0, -3}, {0, -4}, {0, -5} },
    beam8 = {
        {0, -1}, {0, -2}, {0, -3}, {0, -4},
        {0, -5}, {0, -6}, {0, -7}
    },
    -- Exact AREA_BEAM_MASTERY10 from the server, including the caster's sides.
    beamMastery10 = (function()
        local offsets={}
        for y=0,9 do for x=-1,1 do
            if x~=0 or y~=0 then offsets[#offsets+1]={x,-y} end
        end end
        return offsets
    end)(),
    flurry = {
        {0, -2}, {-1, -1}, {0, -1}, {1, -1},
        {-1, 0}, {1, 0}, {-1, 1}, {1, 1}
    },
    greaterFlurry = {
        {0, -3}, {-1, -2}, {0, -2}, {1, -2},
        {-1, -1}, {0, -1}, {1, -1},
        {-2, 0}, {-1, 0}, {1, 0}, {2, 0}, {-1, 1}, {1, 1}
    },
    sweeping = {
        {-1, -3}, {0, -3}, {1, -3},
        {-2, -2}, {-1, -2}, {0, -2}, {1, -2}, {2, -2},
        {-2, -1}, {-1, -1}, {0, -1}, {1, -1}, {2, -1},
        {-2, 0}, {-1, 0}, {1, 0}, {2, 0},
        {-2, 1}, {-1, 1}, {1, 1}, {2, 1}
    }
}

local ATTACK_SPELL_AREAS = {
    -- Knight
    ['exori'] = { shape = 'square', radius = 1 },
    ['exori gran'] = { shape = 'square', radius = 1 },
    ['exori min'] = { shape = 'directional', area = 'wave6' },
    ['exori infir min'] = { shape = 'directional', area = 'wave6' },
    ['exori mas'] = { shape = 'circle', radius = 3, manhattan = 4 },
    ['exori amp kor'] = { shape = 'chain', range = 5, chainRange = 3, maxTargets = 3 },

    -- Sorcerer and Druid waves, beams and ultimate areas
    ['exevo flam hur'] = { shape = 'directional', area = 'wave4' },
    ['exevo infir flam hur'] = { shape = 'directional', area = 'wave4' },
    ['exevo frigo hur'] = { shape = 'directional', area = 'wave4' },
    ['exevo infir frigo hur'] = { shape = 'directional', area = 'wave4' },
    ['exevo gran flam hur'] = { shape = 'directional', area = 'wave7' },
    ['exevo gran frigo hur'] = { shape = 'directional', area = 'strongIceWave' },
    -- The server's normal Energy Wave uses the same 4-tile matrix as Strong Ice Wave.
    ['exevo vis hur'] = { shape = 'directional', area = 'strongIceWave' },
    ['exevo tera hur'] = { shape = 'directional', area = 'squareWave5' },
    ['exevo vis lux'] = { shape = 'directional', area = 'beam5' },
    ['exevo gran vis lux'] = { shape = 'directional', area = 'beam8' },
    ['exevo max mort'] = { shape = 'directional', area = 'beam8' },
    ['exevo gran mas flam'] = { shape = 'circle', radius = 5, manhattan = 5 },
    ['exevo gran mas frigo'] = { shape = 'circle', radius = 5, manhattan = 5 },
    ['exevo gran mas tera'] = { shape = 'circle', radius = 6, manhattan = 6 },
    ['exevo gran mas vis'] = { shape = 'circle', radius = 6, manhattan = 6 },
    ['exevo ulus frigo'] = { shape = 'ring', radius = 4, manhattan = 5, innerRadius = 1 },
    ['exevo ulus tera'] = { shape = 'ring', radius = 4, manhattan = 5, innerRadius = 1 },
    ['exevo mort ora'] = { shape = 'targetSquare', castRange = 7, radius = 2 },
    ['exori amp vis'] = { shape = 'chain', range = 7, chainRange = 4, maxTargets = 3 },
    ['exevo fur frigo'] = { shape = 'chain', range = 7, chainRange = 4, maxTargets = 7 },
    ['exevo fur tera'] = { shape = 'chain', range = 7, chainRange = 4, maxTargets = 6 },

    -- Paladin
    ['exevo mas san'] = { shape = 'circle', radius = 3, manhattan = 4 },
    ['exevo tempo mas san'] = {
        shape = 'targetCircle', castRange = 7, radius = 2, manhattan = 3
    },
    ['exori dir san'] = {
        shape = 'targetCircle', castRange = 7, radius = 2, manhattan = 3
    },
    ['exori dir moe'] = {
        shape = 'targetCircle', castRange = 7, radius = 2, manhattan = 3
    },

    -- Monk
    ['exori mas pug'] = { shape = 'directional', area = 'flurry' },
    ['exori gran mas pug'] = { shape = 'directional', area = 'greaterFlurry' },
    ['exori mas nia'] = { shape = 'directional', area = 'sweeping' },
    ['exori med pug'] = { shape = 'chain', chainRange = 3, maxTargets = 3 },
    ['exori gran mas nia'] = { shape = 'chain', chainRange = 2, maxTargets = 6 }
}

-- Vocation IDs received by the 15.11 client are different from the IDs used
-- by SpellInfo. Keeping both IDs here lets the helper distinguish promotion.
local SUPPORTED_VOCATIONS = {
    [1] = { name = 'Knight', baseSpellVocation = 4, promotedSpellVocation = 8, promoted = false },
    [2] = { name = 'Paladin', baseSpellVocation = 3, promotedSpellVocation = 7, promoted = false },
    [3] = { name = 'Sorcerer', baseSpellVocation = 1, promotedSpellVocation = 5, promoted = false },
    [4] = { name = 'Druid', baseSpellVocation = 2, promotedSpellVocation = 6, promoted = false },
    [5] = { name = 'Monk', baseSpellVocation = 9, promotedSpellVocation = 10, promoted = false },
    [11] = { name = 'Elite Knight', baseSpellVocation = 4, promotedSpellVocation = 8, promoted = true },
    [12] = { name = 'Royal Paladin', baseSpellVocation = 3, promotedSpellVocation = 7, promoted = true },
    [13] = { name = 'Master Sorcerer', baseSpellVocation = 1, promotedSpellVocation = 5, promoted = true },
    [14] = { name = 'Elder Druid', baseSpellVocation = 2, promotedSpellVocation = 6, promoted = true },
    [15] = { name = 'Exalted Monk', baseSpellVocation = 9, promotedSpellVocation = 10, promoted = true },

    -- Compatibility for servers that send promoted server vocation IDs
    -- instead of the client-facing 11-15 range.
    [6] = { name = 'Elder Druid', baseSpellVocation = 2, promotedSpellVocation = 6, promoted = true },
    [7] = { name = 'Royal Paladin', baseSpellVocation = 3, promotedSpellVocation = 7, promoted = true },
    [8] = { name = 'Elite Knight', baseSpellVocation = 4, promotedSpellVocation = 8, promoted = true },
    [9] = { name = 'Monk', baseSpellVocation = 9, promotedSpellVocation = 10, promoted = false },
    [10] = { name = 'Exalted Monk', baseSpellVocation = 9, promotedSpellVocation = 10, promoted = true }
}

-- Only self-healing spells belong here. This intentionally excludes cure
-- condition spells, friend healing and attack/support spells from group 2.
local HEALING_SPELL_NAMES = {
    [1] = { 'Magic Patch', 'Light Healing', 'Intense Healing', 'Ultimate Healing', 'Restoration' },
    [2] = { 'Magic Patch', 'Light Healing', 'Intense Healing', 'Ultimate Healing', 'Restoration' },
    [3] = { 'Magic Patch', 'Light Healing', 'Intense Healing', 'Divine Healing', 'Salvation' },
    [4] = { 'Bruise Bane', 'Wound Cleansing', 'Intense Wound Cleansing', 'Fair Wound Cleansing' },
    [9] = { 'Magic Patch', 'Light Healing', 'Intense Healing', 'Spirit Mend', 'Mass Spirit Mend' }
}

-- Health and spirit potions registered by the Baiakeros server. Vocation and
-- level restrictions deliberately remain server-side, just like a hotkey.
local POTIONS = {
    [7876] = { id = 7876, name = 'Small Health Potion', resources = { health = true } },
    [266] = { id = 266, name = 'Health Potion', resources = { health = true } },
    [236] = { id = 236, name = 'Strong Health Potion', resources = { health = true } },
    [239] = { id = 239, name = 'Great Health Potion', resources = { health = true } },
    [7642] = { id = 7642, name = 'Great Spirit Potion', resources = { health = true, mana = true } },
    [7643] = { id = 7643, name = 'Ultimate Health Potion', resources = { health = true } },
    [23374] = { id = 23374, name = 'Ultimate Spirit Potion', resources = { health = true, mana = true } },
    [23375] = { id = 23375, name = 'Supreme Health Potion', resources = { health = true } },
    [268] = { id = 268, name = 'Mana Potion', resources = { mana = true } },
    [237] = { id = 237, name = 'Strong Mana Potion', resources = { mana = true } },
    [238] = { id = 238, name = 'Great Mana Potion', resources = { mana = true } },
    [53162] = { id = 53162, name = 'Superior Mana Potion', resources = { mana = true } },
    [53163] = { id = 53163, name = 'Distilled Superior Mana Potion', resources = { mana = true } },
    [23373] = { id = 23373, name = 'Ultimate Mana Potion', resources = { mana = true } },
    [53164] = { id = 53164, name = 'Distilled Ultimate Mana Potion', resources = { mana = true } }
}

-- Foods registered by data/scripts/actions/items/foods.lua on the BaiakEros
-- server. Keeping the allow-list here prevents Auto Eat from using unrelated
-- usable items just because they happen to be stored beside food.
local FOOD_ITEM_IDS = {
    [169] = true, [229] = true, [836] = true, [841] = true, [901] = true,
    [904] = true, [3250] = true, [3577] = true, [3578] = true, [3579] = true,
    [3580] = true, [3581] = true, [3582] = true, [3583] = true, [3584] = true,
    [3585] = true, [3586] = true, [3587] = true, [3588] = true, [3589] = true,
    [3590] = true, [3591] = true, [3592] = true, [3593] = true, [3594] = true,
    [3595] = true, [3596] = true, [3597] = true, [3598] = true, [3599] = true,
    [3600] = true, [3601] = true, [3602] = true, [3606] = true, [3607] = true,
    [3723] = true, [3724] = true, [3725] = true, [3726] = true, [3727] = true,
    [3728] = true, [3729] = true, [3730] = true, [3731] = true, [3732] = true,
    [5096] = true, [5678] = true, [6125] = true, [6277] = true, [6278] = true,
    [6392] = true, [6393] = true, [6500] = true, [6541] = true, [6542] = true,
    [6543] = true, [6544] = true, [6545] = true, [6569] = true, [6574] = true,
    [7158] = true, [7159] = true, [7373] = true, [7374] = true, [7375] = true,
    [7376] = true, [7377] = true, [8010] = true, [8011] = true, [8012] = true,
    [8013] = true, [8014] = true, [8015] = true, [8016] = true, [8017] = true,
    [8019] = true, [8177] = true, [8197] = true, [10219] = true, [10329] = true,
    [10453] = true, [11459] = true, [11460] = true, [11461] = true,
    [11462] = true, [11681] = true, [11682] = true, [11683] = true,
    [12310] = true, [13992] = true, [14084] = true, [14085] = true,
    [14681] = true, [16103] = true, [17457] = true, [17820] = true,
    [17821] = true, [20310] = true, [21143] = true, [21144] = true,
    [21145] = true, [21146] = true, [22185] = true, [22187] = true,
    [23535] = true, [23545] = true, [24382] = true, [24383] = true,
    [24396] = true, [24948] = true, [25692] = true, [30198] = true,
    [30202] = true, [31560] = true, [32069] = true, [37530] = true,
    [37531] = true, [37532] = true, [37533] = true, [48116] = true,
    [48251] = true, [48252] = true, [48253] = true, [48254] = true,
    [48255] = true, [48256] = true, [48273] = true, [48508] = true,
    [48509] = true, [48511] = true, [48544] = true
}

local function getVocationProfile()
    local player = g_game.getLocalPlayer()
    return player and VOCATION_PROFILES[tonumber(player:getVocation())] or nil
end

local function getHelperWindowHeight(profile, tabName)
    tabName = tabName or currentHelperTab
    if tabName == 'attack' then
        local spellCount = profile and ATTACK_SPELL_SLOT_COUNTS[profile.key] or 0
        local runeCount = profile and ATTACK_RUNE_SLOT_COUNTS[profile.key] or 0
        -- The base attack window was designed for five total rows (three
        -- spells and two runes). Grow it when a vocation exposes more rows so
        -- the rune panel never overlaps the controls anchored to the bottom.
        local extraRows = math.max(0, spellCount + runeCount - 5)
        return HELPER_ATTACK_HEIGHT + extraRows * 38
    elseif tabName == 'extras' then
        return HELPER_EXTRAS_HEIGHT
    end
    if profile and profile.massFriendHealing then
        return HELPER_DRUID_HEIGHT
    end
    if profile and profile.friendHealing then
        if profile.friendSlotCount == 1 then return HELPER_SINGLE_FRIEND_HEIGHT end
        return HELPER_FRIEND_HEIGHT
    end
    return HELPER_HEALING_HEIGHT
end

local function getPlayerKey()
    local player = g_game.getLocalPlayer()
    local playerName = player and player:getName() or 'unknown'
    return playerName:lower():gsub('[^%w]', '_')
end

function presetId(name)
    return tostring(name or 'default'):lower()
end

function playerConfigPrefix()
    return 'baiakeros_helper_' .. getPlayerKey()
end

function helperConfigPrefix(selectedPreset)
    selectedPreset = selectedPreset or helperPreset
    local prefix = playerConfigPrefix()
    if selectedPreset ~= 'default' then
        prefix = prefix .. '_preset_' .. selectedPreset
    end
    return prefix
end

function helperPresetNamesConfigKey()
    return playerConfigPrefix() .. '_presets'
end

function currentHelperPresetConfigKey()
    return playerConfigPrefix() .. '_current_preset'
end

function attackPresetNamesConfigKey(selectedHelperPreset)
    return helperConfigPrefix(selectedHelperPreset) .. '_attack_presets'
end

function normalizePresetNames(savedNames)
    local names = { 'Default' }
    local seen = { default = true }
    for _, name in ipairs(savedNames or {}) do
        local text = tostring(name)
        local id = presetId(text)
        if id ~= 'default' and #text >= 1 and #text <= 10 and
            text:match('^[%w]+$') and not seen[id] then
            table.insert(names, text)
            seen[id] = true
        end
    end
    return names
end

function findPresetName(names, id)
    id = presetId(id)
    for _, name in ipairs(names or {}) do
        if presetId(name) == id then return name end
    end
    return nil
end

function nextPresetId(names, currentId)
    if #names == 0 then return 'default' end
    currentId = presetId(currentId)
    for index, name in ipairs(names) do
        if presetId(name) == currentId then
            return presetId(names[index % #names + 1])
        end
    end
    return presetId(names[1])
end

local function configKey(slotId)
    return helperConfigPrefix() .. '_' .. slotId
end

local function enabledConfigKey()
    return helperConfigPrefix() .. '_healing_enabled_v2'
end

local function autoAttackEnabledConfigKey()
    return helperConfigPrefix() .. '_auto_attack_enabled'
end

local function attackRotationEnabledConfigKey()
    return helperConfigPrefix() .. '_attack_rotation_enabled'
end

local function autoAttackModeConfigKey()
    return helperConfigPrefix() .. '_auto_attack_mode'
end

function autoHasteEnabledConfigKey()
    return helperConfigPrefix() .. '_auto_haste_enabled'
end

function autoHasteSpellConfigKey()
    return helperConfigPrefix() .. '_auto_haste_spell'
end

function autoHasteInProtectionZoneConfigKey()
    return helperConfigPrefix() .. '_auto_haste_in_protection_zone'
end

local function changeGoldEnabledConfigKey()
    -- This is a server-side player toggle, not a helper-preset option.
    return playerConfigPrefix() .. '_change_gold_enabled'
end

local function commandEnabledConfigKey(commandName)
    local player = g_game.getLocalPlayer()
    local character = player and player:getName() or 'offline'
    return string.format('baiakeros_command_%s_%s', commandName,
        character:lower():gsub('[^%w]+', '_'))
end

local function lootPouchKnownConfigKey()
    return playerConfigPrefix() .. '_loot_pouch_known'
end

function extrasToggleResetConfigKey()
    return string.format('%s_extras_toggle_reset_v%d', playerConfigPrefix(),
        EXTRAS_TOGGLE_RESET_VERSION)
end

function autoReconnectConfigKey()
    return helperConfigPrefix() .. '_auto_reconnect'
end

function autoEatConfigKey()
    return helperConfigPrefix() .. '_auto_eat_food'
end

function exerciseWeaponConfigKey()
    return helperConfigPrefix() .. '_exercise_weapon'
end

function exerciseTrainingEnabledConfigKey()
    return helperConfigPrefix() .. '_exercise_training_enabled'
end

local function friendConfigKey(slotId)
    return helperConfigPrefix() .. '_' .. slotId
end

local function normalizeFriendThreshold(value)
    value = tonumber(value) or 80
    return math.max(5, math.min(95, math.floor((value + 2) / 5) * 5))
end

local function getFriendSlotCount(prefix)
    local profile = getVocationProfile()
    if prefix == 'friendSlot' then
        return profile and profile.friendSlotCount or 2
    end
    return 2
end

local AUTO_ATTACK_MODES = {
    A = 'Nearest target',
    B = 'Farthest target',
    C = 'Lowest health target',
    D = 'Highest health target / Boss',
    E = 'Best area target',
    F = 'Nearest target with lowest health',
    G = 'Nearest target with highest health',
    H = 'Farthest target with lowest health',
    I = 'Farthest target with highest health'
}

-- Compact labels are used only by the narrow RubinOT-style selector. The
-- complete descriptions above remain available as the field tooltip.
local AUTO_ATTACK_MODE_LABELS = {
    A = 'Nearest',
    B = 'Farthest',
    C = 'Lowest HP',
    D = 'Highest HP / Boss',
    E = 'Best AoE',
    F = 'Near + lowest HP',
    G = 'Near + highest HP',
    H = 'Far + lowest HP',
    I = 'Far + highest HP'
}

local HELPER_HOTKEY_CATEGORY = 'BaiakEros Helper'
local HELPER_HOTKEY_ACTIONS = {
    healing = 'Toggle Healing',
    autoTarget = 'Toggle Auto Target',
    shooter = 'Toggle Shooter',
    both = 'Toggle Auto Target + Shooter',
    helperPreset = 'Next Helper Preset',
    attackPreset = 'Next Attack Preset'
}

local function attackConfigKey(slotId)
    return helperConfigPrefix() .. '_attack_' ..
        attackPreset .. '_' .. slotId
end

local function attackPresetConfigKey()
    return helperConfigPrefix() .. '_attack_preset'
end

local function attackPostureConfigKey(kind)
    return attackConfigKey('posture_' .. kind)
end

local function getAttackPostureOptions()
    local profile = getVocationProfile()
    if not profile or not currentVocation or not currentVocation.promoted then
        return {}
    end
    return ATTACK_POSTURE_OPTIONS[profile.key] or {}
end

local function findAttackPostureOption(kind, optionId)
    if not optionId or optionId == '' then return nil end
    for _, option in ipairs(getAttackPostureOptions()[kind] or {}) do
        if option.id == optionId then return option end
    end
    return nil
end

local function getAttackPostureCooldownExpiry(kind, option)
    local expiry = spellCooldownsById[tonumber(option and option.spellId) or 0] or 0
    local groupId = kind == 'passive' and 6 or 12
    expiry = math.max(expiry, spellGroupCooldownsById[groupId] or 0)
    expiry = math.max(expiry, spellGroupCooldownsById[3] or 0)
    return expiry
end

local function updateAttackPostureControls()
    if attackPostureCooldownEvent then
        removeEvent(attackPostureCooldownEvent)
        attackPostureCooldownEvent = nil
    end
    if not helperWindow then return end
    local options = getAttackPostureOptions()
    local editable = not attackRotationEnabled
    local now = g_clock.millis()
    local nextExpiry = nil
    for _, kind in ipairs({ 'stance', 'passive' }) do
        local title = helperWindow:recursiveGetChildById(
            kind == 'stance' and 'attackStanceTitle' or 'attackPassiveTitle')
        local kindOptions = options[kind] or {}
        if title then title:setVisible(#kindOptions > 0) end
        for index, buttonId in ipairs(ATTACK_POSTURE_BUTTON_IDS[kind]) do
            local button = helperWindow:recursiveGetChildById(buttonId)
            local option = kindOptions[index]
            if button then
                button:setVisible(option ~= nil)
                if option then
                    local cooldownExpiry = getAttackPostureCooldownExpiry(kind, option)
                    local remaining = math.max(0, cooldownExpiry - now)
                    button:setEnabled(editable and remaining <= 0)
                    local cooldown = button:recursiveGetChildById('cooldown')
                    if cooldown then
                        if remaining > 0 then
                            cooldown:showTime(true)
                            cooldown:showProgress(true)
                            cooldown:setDuration(remaining)
                            cooldown:start()
                            if not nextExpiry or cooldownExpiry < nextExpiry then
                                nextExpiry = cooldownExpiry
                            end
                        else
                            cooldown:stop()
                            cooldown:setPercent(100)
                            cooldown:setText('')
                        end
                    end
                    button.postureKind = kind
                    button.postureOption = option
                    button:setImageSource(Spells.getIconFileByProfile('Default'))
                    button:setImageClip(Spells.getImageClip(option.clientId, 'Default'))
                    button:setTooltip(string.format('%s\n%s%s', option.name,
                        option.words, editable and '' or
                        '\nDisable Shooter Helper to change this selection.'))
                    local activeSpell = button:recursiveGetChildById('activeSpell')
                    local isSelected = selectedAttackPostures[kind] == option.id
                    if activeSpell then activeSpell:setVisible(isSelected) end
                end
            end
        end
    end
    if nextExpiry then
        attackPostureCooldownEvent = scheduleEvent(function()
            attackPostureCooldownEvent = nil
            updateAttackPostureControls()
        end, math.max(1, nextExpiry - now + 25))
    end
end

local function restoreAttackPostures()
    for _, kind in ipairs({ 'stance', 'passive' }) do
        local saved = g_settings.getString(attackPostureConfigKey(kind), '')
        selectedAttackPostures[kind] = findAttackPostureOption(kind, saved) and
            saved or nil
    end
    updateAttackPostureControls()
end

function onActiveStanceSpellIdsChanged()
    local changed = false
    if modules.game_actionbar and modules.game_actionbar.isActiveStanceSpellId then
        for _, kind in ipairs({ 'stance', 'passive' }) do
            for _, option in ipairs(getAttackPostureOptions()[kind] or {}) do
                if modules.game_actionbar.isActiveStanceSpellId(option.spellId) then
                    selectedAttackPostures[kind] = option.id
                    g_settings.set(attackPostureConfigKey(kind), option.id)
                    changed = true
                    break
                end
            end
        end
    end
    if changed then g_settings.save() end
    updateAttackPostureControls()
end

function selectAttackPosture(kind, index)
    if attackRotationEnabled then
        updateAttackPostureControls()
        showHelperNotification('Disable Shooter Helper to change Stance or Passive.', false)
        return
    end
    local option = (getAttackPostureOptions()[kind] or {})[tonumber(index) or 0]
    if not option then return end
    if getAttackPostureCooldownExpiry(kind, option) > g_clock.millis() then
        showHelperNotification('Wait for the combat style cooldown to finish.', false)
        updateAttackPostureControls()
        return
    end
    selectedAttackPostures[kind] = option.id
    g_settings.set(attackPostureConfigKey(kind), option.id)
    g_settings.save()
    updateAttackPostureControls()
end

local function castSelectedAttackPostures()
    if isManualActionPending() then return end
    if attackPostureCastEvent then
        removeEvent(attackPostureCastEvent)
        attackPostureCastEvent = nil
    end
    local casts = {}
    for _, kind in ipairs({ 'stance', 'passive' }) do
        local option = findAttackPostureOption(kind, selectedAttackPostures[kind])
        local alreadyActive = option and modules.game_actionbar and
            modules.game_actionbar.isActiveStanceSpellId and
            modules.game_actionbar.isActiveStanceSpellId(option.spellId)
        if option and not alreadyActive then table.insert(casts, option) end
    end
    if #casts == 0 then return end
    g_game.talk(casts[1].words)
    if #casts > 1 then
        attackPostureCastEvent = scheduleEvent(function()
            attackPostureCastEvent = nil
            if attackRotationEnabled and g_game.isOnline() and not isManualActionPending() then
                g_game.talk(casts[2].words)
            end
        end, 2100)
    end
end

local function isCooldownReady(cooldowns, id, now)
    return (cooldowns[tonumber(id)] or 0) <= now
end

local function isSpellCooldownReady(spell, now)
    -- The server sends SpellInfo.id in opcode 0xA4. clientId only selects
    -- the icon cell in the local atlas.
    local cooldownId = spell and tonumber(spell.id)
    if not cooldownId or not isCooldownReady(spellCooldownsById, cooldownId, now) then
        return false
    end
    for groupId in pairs(spell.group or {}) do
        if not isCooldownReady(spellGroupCooldownsById, groupId, now) then
            return false
        end
    end
    return true
end

local function guardSpellCommand(spell, primaryGroupId, now)
    local expiresAt = now + SPELL_COMMAND_GUARD
    if spell then
        local cooldownId = tonumber(spell.id)
        if cooldownId then spellCooldownsById[cooldownId] = expiresAt end
    end
    if primaryGroupId then
        spellGroupCooldownsById[tonumber(primaryGroupId)] = expiresAt
    end
end

local function detectVocation()
    local player = g_game.getLocalPlayer()
    if not player then return nil end
    return SUPPORTED_VOCATIONS[tonumber(player:getVocation())]
end

-- Temporary diagnostic for server/client vocation mismatches. Keep the raw
-- value separate from the Helper profile so an unexpected packet can be
-- identified without changing any healing or attack behavior.
local function logVocationDiagnostic(context, newVocation, oldVocation)
    local player = g_game.getLocalPlayer()
    local getter = player and player:getVocation() or nil
    local message = string.format(
        '[BaiakEros Helper][Vocation Diagnostic] %s getter=%s',
        tostring(context), tostring(getter))

    if newVocation ~= nil or oldVocation ~= nil then
        message = message .. string.format(
            ' new=%s old=%s', tostring(newVocation), tostring(oldVocation))
    end

    g_logger.info(message)
end

local function spellHasVocation(spell, vocationId)
    if not spell or not spell.vocations then return false end
    return table.contains(spell.vocations, vocationId)
end

local function spellRequiresPromotion(spell, vocation)
    return spellHasVocation(spell, vocation.promotedSpellVocation) and
        not spellHasVocation(spell, vocation.baseSpellVocation)
end

local function isSpellAvailable(spell, player, vocation)
    if not spell or not player or not vocation then return false end
    if spell.type ~= 'Instant' or Spells.getPrimaryGroup(spell) ~= 2 then return false end
    if spell.needTarget or spell.parameter or not spell.words or spell.words == '' then return false end
    if (spell.level or 0) > player:getLevel() then return false end
    if spell.premium and not player:isPremium() then return false end

    if vocation.promoted then
        return spellHasVocation(spell, vocation.baseSpellVocation) or
            spellHasVocation(spell, vocation.promotedSpellVocation)
    end

    return spellHasVocation(spell, vocation.baseSpellVocation) and
        not spellRequiresPromotion(spell, vocation)
end

-- The Shooter owns support casts and shares the server-reported cooldowns
-- with healing and haste, whether or not the Cavebot is running.
local nextExplorerTurnAt = 0
function tryCastExplorerLureSpell(spellName, direction)
    if isManualActionPending() then return false end
    if not g_game.isOnline() then return false end
    local player = g_game.getLocalPlayer()
    local vocation = detectVocation()
    local spell = getSelectedExplorerLureSpell()
    if not player or not vocation or not spell or player:isDead() or
        spell.name ~= spellName or
        player:hasState(PlayerStates.Pz) or
        (spell.level or 0) > player:getLevel() or
        (spell.premium and not player:isPremium()) or
        not spellHasVocation(spell, vocation.promoted and
            vocation.promotedSpellVocation or vocation.baseSpellVocation) or
        player:getMana() < (spell.mana or 0) then
        return false
    end
    local now = g_clock.millis()
    if not isSpellCooldownReady(spell, now) then return false end
    if direction and player:getDirection() ~= direction then
        if now >= nextExplorerTurnAt then
            g_game.turn(direction)
            nextExplorerTurnAt = now + 250
        end
        return false
    end
    g_game.talk(spell.words)
    guardSpellCommand(spell, 3, now)
    -- The server's packet remains authoritative; this only prevents a cast
    -- from being repeated before that packet arrives.
    spellCooldownsById[spell.id] = now + (spell.exhaustion or 2000)
    spellGroupCooldownsById[3] = now + (spell.group[3] or 2000)
    return true
end

function tryCastExplorerLevitate(level, direction)
    if isManualActionPending() then return false end
    if level ~= 'up' and level ~= 'down' or not direction or
        not g_game.isOnline() then return false end
    local player = g_game.getLocalPlayer()
    local vocation = detectVocation()
    local spell = SpellInfo.Default and SpellInfo.Default.Levitate
    if not player or not vocation or not spell or player:isDead() or
        player:hasState(PlayerStates.Pz) or
        player:getLevel() < (spell.level or 0) or
        (spell.premium and not player:isPremium()) or
        player:getMana() < (spell.mana or 0) or
        not spellHasVocation(spell, vocation.promoted and
            vocation.promotedSpellVocation or vocation.baseSpellVocation) then
        return false
    end
    local now = g_clock.millis()
    if not isSpellCooldownReady(spell, now) then return false end
    if player:getDirection() ~= direction then
        if now >= nextExplorerTurnAt then
            g_game.turn(direction)
            nextExplorerTurnAt = now + 250
        end
        return false
    end
    g_game.talk(string.format('%s "%s"', spell.words, level))
    guardSpellCommand(spell, 3, now)
    spellCooldownsById[spell.id] = now + (spell.exhaustion or 2000)
    spellGroupCooldownsById[3] = now + (spell.group[3] or 2000)
    return true
end

function tryCastExplorerMagicRope()
    if isManualActionPending() or not g_game.isOnline() then return false end
    local player = g_game.getLocalPlayer()
    local vocation = detectVocation()
    local spell = SpellInfo.Default and SpellInfo.Default['Magic Rope']
    if not player or not vocation or not spell or player:isDead() or
        player:hasState(PlayerStates.Pz) or
        player:getLevel() < (spell.level or 0) or
        (spell.premium and not player:isPremium()) or
        player:getMana() < (spell.mana or 0) or
        not spellHasVocation(spell, vocation.promoted and
            vocation.promotedSpellVocation or vocation.baseSpellVocation) then
        return false
    end
    local now = g_clock.millis()
    if not isSpellCooldownReady(spell, now) then return false end
    g_game.talk(spell.words)
    guardSpellCommand(spell, 3, now)
    spellCooldownsById[spell.id] = now + (spell.exhaustion or 2000)
    spellGroupCooldownsById[3] = now + (spell.group[3] or 2000)
    return true
end

local nextExplorerRopeAt = 0
local explorerRopeFallbackId = 3003
function tryUseExplorerRope(position)
    if isManualActionPending() or not g_game.isOnline() then return false end
    local now = g_clock.millis()
    if now < nextExplorerRopeAt or now < nextPotionAt then return false end
    local player = g_game.getLocalPlayer()
    if not player or player:isDead() or not position then return false end
    local playerPosition = player:getPosition()
    if playerPosition.z ~= position.z or math.abs(playerPosition.x - position.x) > 1 or
        math.abs(playerPosition.y - position.y) > 1 then return false end
    local tile = g_map.getTile(position)
    local target = tile and (tile:getTopUseThing() or tile:getGround())
    local rope = g_game.findPlayerItem(3003, -1, 0) or g_game.findPlayerItem(646, -1, 0)
    if not target then return false end
    -- Closed backpacks are not exposed by findPlayerItem. Inventory hotkeys
    -- resolve the item on the server; try the two supported tools in turn.
    local ropeId = rope and rope:getId() or explorerRopeFallbackId
    if not rope then explorerRopeFallbackId = ropeId == 3003 and 646 or 3003 end
    g_game.useInventoryItemWith(ropeId, target, -1)
    nextExplorerRopeAt = now + 2200
    return true
end

local function getAvailableHealingSpells()
    local player = g_game.getLocalPlayer()
    local vocation = detectVocation()
    if not player or not vocation then return {} end

    local spells = {}
    for _, spellName in ipairs(HEALING_SPELL_NAMES[vocation.baseSpellVocation] or {}) do
        local spell = SpellInfo.Default[spellName]
        if isSpellAvailable(spell, player, vocation) then
            table.insert(spells, spell)
        end
    end

    table.sort(spells, function(a, b)
        if (a.level or 0) == (b.level or 0) then
            return (a.mana or 0) < (b.mana or 0)
        end
        return (a.level or 0) < (b.level or 0)
    end)
    return spells
end

function isHasteSpellAvailable(spell, player, vocation)
    if not spell or not player or not vocation then return false end
    if spell.type ~= 'Instant' or Spells.getPrimaryGroup(spell) ~= 3 then return false end
    if spell.needTarget or spell.parameter or not spell.words or spell.words == '' then return false end
    if (spell.level or 0) > player:getLevel() then return false end
    if spell.premium and not player:isPremium() then return false end
    if vocation.promoted then
        return spellHasVocation(spell, vocation.baseSpellVocation) or
            spellHasVocation(spell, vocation.promotedSpellVocation)
    end
    return spellHasVocation(spell, vocation.baseSpellVocation) and
        not spellRequiresPromotion(spell, vocation)
end

function getAvailableHasteSpells()
    local player = g_game.getLocalPlayer()
    local vocation = detectVocation()
    if not player or not vocation then return {} end

    local spells = {}
    for _, spellName in ipairs(AUTO_HASTE.spellNames) do
        local spell = SpellInfo.Default[spellName]
        if isHasteSpellAvailable(spell, player, vocation) then
            table.insert(spells, spell)
        end
    end
    table.sort(spells, function(first, second)
        if (first.level or 0) == (second.level or 0) then
            return first.name < second.name
        end
        return (first.level or 0) < (second.level or 0)
    end)
    return spells
end

local function getAvailableManaTrainingSpells()
    local player = g_game.getLocalPlayer()
    local vocation = detectVocation()
    if not player or not vocation then return {} end

    local spells = {}
    for _, spell in pairs(SpellInfo.Default or {}) do
        -- Mana Training accepts only instant support spells the current
        -- character can cast. Attack, healing, conjure, target and parameter
        -- spells are deliberately excluded.
        if isHasteSpellAvailable(spell, player, vocation) then
            table.insert(spells, spell)
        end
    end
    table.sort(spells, function(first, second)
        if (first.level or 0) == (second.level or 0) then
            if (first.mana or 0) == (second.mana or 0) then
                return first.name < second.name
            end
            return (first.mana or 0) < (second.mana or 0)
        end
        return (first.level or 0) < (second.level or 0)
    end)
    return spells
end

local function isAttackSpellAvailable(spell, player, vocation)
    if not spell or not player or not vocation then return false end
    if spell.type ~= 'Instant' or Spells.getPrimaryGroup(spell) ~= 1 then return false end
    if spell.parameter or not spell.words or spell.words == '' then return false end
    if (spell.level or 0) > player:getLevel() then return false end
    if spell.premium and not player:isPremium() then return false end
    if vocation.promoted then
        return spellHasVocation(spell, vocation.baseSpellVocation) or
            spellHasVocation(spell, vocation.promotedSpellVocation)
    end
    return spellHasVocation(spell, vocation.baseSpellVocation) and
        not spellRequiresPromotion(spell, vocation)
end

local function getAvailableAttackSpells()
    local player = g_game.getLocalPlayer()
    local vocation = detectVocation()
    if not player or not vocation then return {} end
    local spells = {}
    for _, spell in pairs(SpellInfo.Default) do
        if isAttackSpellAvailable(spell, player, vocation) then
            table.insert(spells, spell)
        end
    end
    table.sort(spells, function(first, second)
        if (first.level or 0) == (second.level or 0) then
            return first.name < second.name
        end
        return (first.level or 0) < (second.level or 0)
    end)
    return spells
end

function getAvailableExplorerLureSpells()
    local player = g_game.getLocalPlayer()
    local vocation = detectVocation()
    local profile = getVocationProfile()
    if not player or not vocation or not profile then return {} end
    local spells = {}
    for _, name in ipairs(LURE_SPELL_NAMES[profile.key] or {}) do
        local spell = SpellInfo.Default[name]
        if isHasteSpellAvailable(spell, player, vocation) then
            table.insert(spells, spell)
        end
    end
    return spells
end

function getSelectedExplorerLureSpell()
    local name = g_settings.getString(attackConfigKey('lureSpell'), '')
    for _, spell in ipairs(getAvailableExplorerLureSpells()) do
        if spell.name == name then return spell end
    end
    return nil
end

function setExplorerLureSpell(name)
    if name and name ~= '' then
        local available = false
        for _, spell in ipairs(getAvailableExplorerLureSpells()) do
            if spell.name == name then available = true break end
        end
        if not available then return false end
        g_settings.set(attackConfigKey('lureSpell'), name)
    else
        g_settings.remove(attackConfigKey('lureSpell'))
    end
    g_settings.save()
    return true
end

local function findSavedAttackSpell(savedId, vocation, storedName, savedWords)
    if not savedId and not storedName and not savedWords then return nil end
    local savedIdentity = savedId and tostring(savedId) or ''
    local numericId = tonumber(savedId)
    local expectedName = storedName and tostring(storedName) or nil
    local expectedWords = savedWords and tostring(savedWords):lower() or nil
    local fallback
    for _, spell in pairs(SpellInfo.Default) do
        if spell and spell.type == 'Instant' and Spells.getPrimaryGroup(spell) == 1 and
            not spell.parameter and (spell.name == savedIdentity or
            (expectedName and spell.name == expectedName) or
            (expectedWords and spell.words and spell.words:lower() == expectedWords) or
            (numericId and spell.id == numericId)) then
            fallback = fallback or spell
            if not vocation or spellHasVocation(spell, vocation.baseSpellVocation) or
                spellHasVocation(spell, vocation.promotedSpellVocation) then
                return spell
            end
        end
    end
    -- The assignment belongs to this character-specific configuration. Keep
    -- an exact spell match visible even if vocation metadata arrives late.
    return fallback
end

local function findSavedHealingSpell(savedId, vocation)
    if not savedId or not vocation then return nil end

    -- Restoring a selection must not depend on transient player data such as
    -- level or premium status. Those values may not be populated yet when the
    -- onGameStart/onVocationChange callbacks run. Casting is still protected by
    -- isSpellAvailable in checkHealing.
    local savedName = tostring(savedId)
    local numericId = tonumber(savedId)
    for _, healingName in ipairs(HEALING_SPELL_NAMES[vocation.baseSpellVocation] or {}) do
        local spell = SpellInfo.Default[healingName]
        if spell and (healingName == savedName or (numericId and spell.id == numericId)) then
            return spell
        end
    end
    return nil
end

local function setStatus(text, color)
    if not helperWindow then return end
    local statusLabel = helperWindow:recursiveGetChildById('statusLabel')
    if statusLabel then
        statusLabel:setText(text)
        statusLabel:setColor(color or '#d0d0d0')
    end
end

function showHelperNotification(text, enabled)
    if not helperNotification then return end
    if helperNotificationEvent then
        removeEvent(helperNotificationEvent)
        helperNotificationEvent = nil
    end
    helperNotification:setText(text)
    helperNotification:setColor(enabled == false and '#ff7777' or '#79ef8b')
    helperNotification:setBorderColor(enabled == false and '#9a3434' or '#3f934d')
    helperNotification:setOpacity(0)
    helperNotification:show()
    helperNotification:raise()
    g_effects.fadeIn(helperNotification, 160)
    helperNotificationEvent = scheduleEvent(function()
        helperNotificationEvent = nil
        if helperNotification then g_effects.fadeOut(helperNotification, 350) end
    end, 1200)
end

function helperPresetNotificationSuffix(includeAttackPreset)
    local suffix = 'Preset: ' ..
        (findPresetName(helperPresetNames, helperPreset) or 'Default')
    if includeAttackPreset then
        suffix = suffix .. ' / Spells: ' ..
            (findPresetName(attackPresetNames, attackPreset) or 'Default')
    end
    return suffix
end

function setHelperItemSlotEmptyVisual(assignButton, empty)
    if not assignButton then return end
    -- Keep the slot frame around an assigned item. Only the four empty-slot
    -- marks disappear, so potions, runes and exercise weapons stay framed.
    assignButton:setImageSource('/images/game/actionbar/actionbarslot')
    local decoration = assignButton:recursiveGetChildById('emptyDecoration')
    if decoration then decoration:setVisible(empty) end
end

local function clearSlot(slot)
    slot.assignedSpell = nil
    slot.assignedPotion = nil
    slot.spellIcon:hide()
    slot.itemIcon:hide()
    if slot.assignedName then slot.assignedName:setText('Empty slot') end
    slot.assignButton:setText('')
    slot.assignButton:setBorderWidth(0)
    slot.assignButton:setBorderColor('alpha')
    setHelperItemSlotEmptyVisual(slot.assignButton, true)
    slot.assignButton:setTooltip(slot:getId():sub(1, 6) == 'potion' and
        'Right-click to assign a healing potion' or 'Right-click to assign a healing spell')
    local resourceButton = slot:recursiveGetChildById('resourceButton')
    if resourceButton then resourceButton:hide() end
end

local function refreshPotionResource(slot)
    if not slot or not slot.assignedPotion then return end
    local potion = slot.assignedPotion
    local resourceButton = slot:recursiveGetChildById('resourceButton')
    if not resourceButton then return end

    if not potion.resources[slot.resource] then
        slot.resource = potion.resources.health and 'health' or 'mana'
    end
    resourceButton:setText(slot.resource == 'mana' and 'M' or 'H')
    resourceButton:setColor(slot.resource == 'mana' and '#57a8ff' or '#ed6464')
    resourceButton:setBorderColor(slot.resource == 'mana' and '#2e7fd0' or '#b83c3c')
    resourceButton:setTooltip(slot.resource == 'mana' and
        'Mana mode: trigger using mana percentage' or
        'Health mode: trigger using health percentage')
    resourceButton:setVisible(potion.resources.health and potion.resources.mana)
    slot.assignButton:setBorderWidth(1)
    slot.assignButton:setBorderColor(slot.resource == 'mana' and '#2e7fd0' or '#b83c3c')
end

local function applySpell(slot, spell)
    slot.assignedSpell = spell
    slot.itemIcon:hide()
    slot.spellIcon:setImageSource(Spells.getIconFileByProfile('Default'))
    slot.spellIcon:setImageClip(Spells.getImageClip(spell.clientId, 'Default'))
    slot.spellIcon:show()
    slot.assignedName:setText(spell.name)
    slot.assignButton:setText('')
    setHelperItemSlotEmptyVisual(slot.assignButton, true)
    slot.assignButton:setTooltip(string.format('%s\n%s\nLevel %d | Mana %d',
        spell.name, spell.words, spell.level or 0, spell.mana or 0))
end

local function applyPotion(slot, potion)
    slot.assignedSpell = nil
    slot.assignedPotion = potion
    slot.spellIcon:hide()
    slot.itemIcon:setItemId(potion.id)
    slot.itemIcon:show()
    if slot.assignedName then slot.assignedName:setText(potion.name) end
    slot.assignButton:setText('')
    setHelperItemSlotEmptyVisual(slot.assignButton, false)
    slot.assignButton:setTooltip(potion.name .. '\nRight-click to change or clear')
    refreshPotionResource(slot)
end

local function saveSelection(slot, kind, id)
    g_settings.setNode(configKey(slot:getId()), {
        kind = kind,
        id = id,
        threshold = slot.threshold,
        resource = slot.resource
    })
    g_settings.save()
end

local function setThreshold(slot, value)
    value = math.max(1, math.min(99, tonumber(value) or 50))
    slot.threshold = value
    local thresholdLabel = slot:recursiveGetChildById('thresholdLabel')
    if thresholdLabel then thresholdLabel:setText(value .. '%') end
end

function changeThreshold(slotId, delta)
    local slot = helperWindow:recursiveGetChildById(slotId)
    if not slot then return end
    setThreshold(slot, (slot.threshold or 50) + delta)
    local saved = g_settings.getNode(configKey(slotId)) or {}
    saved.threshold = slot.threshold
    g_settings.setNode(configKey(slotId), saved)
    g_settings.save()
end

function togglePotionResource(slotId)
    local slot = helperWindow and helperWindow:recursiveGetChildById(slotId)
    local potion = slot and slot.assignedPotion
    if not potion or not potion.resources.health or not potion.resources.mana then return end
    slot.resource = slot.resource == 'mana' and 'health' or 'mana'
    refreshPotionResource(slot)
    saveSelection(slot, 'potion', potion.id)
end

-- The second Helper window presents this state without reading or copying
-- widgets from the original window. Healing still runs in one place.
function getHealingState()
    local state = {
        enabled = healingEnabled,
        supported = currentVocation ~= nil,
        preset = helperPreset,
        presetNames = helperPresetNames,
        slots = {}
    }
    if not helperWindow then return state end
    for index = 1, 3 do
        for _, kind in ipairs({ 'spell', 'potion' }) do
            local slotId = kind .. 'Slot' .. index
            local slot = helperWindow:recursiveGetChildById(slotId)
            if slot then
                state.slots[slotId] = {
                    threshold = slot.threshold or DEFAULT_THRESHOLDS[index],
                    resource = slot.resource or 'health',
                    spell = slot.assignedSpell,
                    potion = slot.assignedPotion,
                    available = slot.assignButton:isEnabled()
                }
            end
        end
    end
    return state
end

local function getVisiblePartyMembers()
    local player = g_game.getLocalPlayer()
    if not player or not player:isPartyMember() then return {} end
    local mapPanel = modules.game_interface and modules.game_interface.getMapPanel()
    local spectators = mapPanel and mapPanel:getSpectators() or {}
    local members = {}
    for _, creature in ipairs(spectators) do
        if creature ~= player and creature:isPlayer() and creature:isPartyMember() then
            table.insert(members, creature)
        end
    end
    table.sort(members, function(first, second)
        return first:getName():lower() < second:getName():lower()
    end)
    return members
end

local function findVisiblePartyMember(name)
    if not name or name == '' then return nil end
    for _, creature in ipairs(getVisiblePartyMembers()) do
        if creature:getName():lower() == name:lower() then return creature end
    end
    return nil
end

local function getPartyMemberNames()
    local player = g_game.getLocalPlayer()
    if not player or not player:isPartyMember() then return {} end
    local names, seen = {}, {}
    local function addName(name)
        if type(name) ~= 'string' or name == '' or
            name:lower() == player:getName():lower() or seen[name:lower()] then
            return
        end
        seen[name:lower()] = true
        table.insert(names, name)
    end
    local analyzer = modules.game_analyser and modules.game_analyser.PartyHuntAnalyser
    if analyzer and analyzer.membersName and analyzer.membersData then
        for memberId, name in pairs(analyzer.membersName) do
            if analyzer.membersData[memberId] then addName(name) end
        end
    end
    for _, creature in ipairs(getVisiblePartyMembers()) do
        addName(creature:getName())
    end
    table.sort(names, function(first, second)
        return first:lower() < second:lower()
    end)
    return names
end

local function refreshPartySelection()
    for _, row in ipairs(partyMemberRows) do
        row:setOn(selectedPartyMember ~= nil and
            row.memberName == selectedPartyMember.name)
    end
    for _, row in ipairs(massPartyMemberRows) do
        row:setOn(selectedMassPartyMember ~= nil and
            row.memberName == selectedMassPartyMember.name)
    end
end

local function selectPartyMember(creature)
    selectedPartyMember = {
        name = creature:getName(),
        outfit = creature:getOutfit()
    }
    refreshPartySelection()
end

local function selectMassPartyMember(creature)
    selectedMassPartyMember = {
        name = creature:getName(),
        outfit = creature:getOutfit()
    }
    refreshPartySelection()
end

local function populatePartyMemberList(listId, emptyLabelId, scrollId, members, selectMember)
    local list = helperWindow:recursiveGetChildById(listId)
    if not list then return {} end
    list:destroyChildren()
    local rows = {}
    for _, creature in ipairs(members) do
        local member = creature
        local row = g_ui.createWidget('HelperPartyMemberRow', list)
        row.memberName = member:getName()
        row.nameLabel:setText(row.memberName)
        row.onClick = function() selectMember(member) end
        table.insert(rows, row)
    end
    local emptyLabel = helperWindow:recursiveGetChildById(emptyLabelId)
    if emptyLabel then emptyLabel:setVisible(#members == 0) end
    local scrollBar = helperWindow:recursiveGetChildById(scrollId)
    if scrollBar then
        local rowHeight = 24
        scrollBar:setVisible(#members * rowHeight > list:getHeight())
    end
    return rows
end

local function refreshPartyMemberList(force)
    if not helperWindow or not g_game.isOnline() then return end
    local now = g_clock.millis()
    if not force and now - lastPartyRefreshAt < PARTY_REFRESH_INTERVAL then return end
    lastPartyRefreshAt = now

    local members = getVisiblePartyMembers()
    partyMemberRows = populatePartyMemberList(
        'partyMemberList', 'emptyPartyLabel', 'partyMemberScroll', members,
        selectPartyMember)
    massPartyMemberRows = populatePartyMemberList(
        'massPartyMemberList', 'emptyMassPartyLabel', 'massPartyMemberScroll', members,
        selectMassPartyMember)
    refreshPartySelection()
end

local function refreshFriendSlot(slot)
    if not slot then return end
    local nameLabel = slot:recursiveGetChildById('nameLabel')
    local enableBox = slot:recursiveGetChildById('enableBox')
    local thresholdBox = slot:recursiveGetChildById('thresholdBox')
    local clearButton = slot:recursiveGetChildById('clearButton')
    local addButton = slot:recursiveGetChildById('addButton')
    local outfit = slot:recursiveGetChildById('outfit')
    local hasFriend = slot.friendName ~= nil and slot.friendName ~= ''
    nameLabel:setText(hasFriend and slot.friendName or 'Empty slot')
    -- The party list already identifies the character by name. Once assigned,
    -- keep this row compact: outfit, threshold, enabled checkbox and remove.
    nameLabel:setVisible(false)
    enableBox:setVisible(hasFriend)
    thresholdBox:setVisible(hasFriend)
    clearButton:setVisible(hasFriend)
    addButton:setVisible(not hasFriend)
    outfit:setVisible(hasFriend)
    if hasFriend then
        local creature = findVisiblePartyMember(slot.friendName)
        if creature then outfit:setOutfit(creature:getOutfit()) end
        enableBox:setChecked(slot.friendEnabled ~= false)
        thresholdBox:setCurrentOptionByData(
            normalizeFriendThreshold(slot.friendThreshold), true)
    end
end

local function saveFriendSlot(slot)
    g_settings.setNode(friendConfigKey(slot:getId()), {
        name = slot.friendName,
        enabled = slot.friendEnabled ~= false,
        threshold = slot.friendThreshold or 80
    })
    g_settings.save()
end

local function assignPartyMemberToSlot(slotId, selectedMember)
    local slot = helperWindow and helperWindow:recursiveGetChildById(slotId)
    if not slot or not selectedMember then
        modules.game_textmessage.displayFailureMessage('Select a visible party member first.')
        return
    end

    local prefix = slotId:match('^(massFriendSlot)') or slotId:match('^(friendSlot)')
    if prefix then
        for i = 1, getFriendSlotCount(prefix) do
            local otherSlotId = prefix .. i
            local otherSlot = helperWindow:recursiveGetChildById(otherSlotId)
            if otherSlotId ~= slotId and otherSlot and
                otherSlot.friendName == selectedMember.name then
                modules.game_textmessage.displayFailureMessage(
                    'This party member is already assigned in this section.')
                return
            end
        end
    end
    slot.friendName = selectedMember.name
    slot.friendEnabled = true
    slot.friendThreshold = normalizeFriendThreshold(slot.friendThreshold)
    if selectedMember.outfit then
        slot:recursiveGetChildById('outfit'):setOutfit(selectedMember.outfit)
    end
    saveFriendSlot(slot)
    refreshFriendSlot(slot)
end

function assignFriendSlot(slotId)
    assignPartyMemberToSlot(slotId, selectedPartyMember)
end

function assignMassFriendSlot(slotId)
    assignPartyMemberToSlot(slotId, selectedMassPartyMember)
end

-- Expose the existing party-healing state to Helper V2. V2 uses the same
-- configured slots and the same casting loop; sorcerer UH is intentionally
-- excluded from its Sio interface.
function getSioState()
    local profile = getVocationProfile()
    local available = profile and (profile.key == 'druid' or profile.key == 'monk')
    local state = { available = available == true,
        massAvailable = available and profile.massFriendHealing or false,
        members = {}, slots = {} }
    if not helperWindow then return state end
    state.members = getPartyMemberNames()
    if not available then return state end
    for _, prefix in ipairs({ 'friendSlot', 'massFriendSlot' }) do
        if prefix == 'friendSlot' or state.massAvailable then
            for index = 1, 2 do
                local slotId = prefix .. index
                local slot = helperWindow:recursiveGetChildById(slotId)
                if slot then
                    local creature = findVisiblePartyMember(slot.friendName)
                    state.slots[slotId] = {
                        name = slot.friendName,
                        enabled = slot.friendEnabled ~= false,
                        threshold = slot.friendThreshold or 80,
                        outfit = creature and creature:getOutfit() or nil
                    }
                end
            end
        end
    end
    return state
end

function assignSioSlot(slotId, memberName)
    local state = getSioState()
    if not state.available or not state.slots[slotId] then return end
    local listed = false
    for _, name in ipairs(state.members) do
        if name == memberName then listed = true break end
    end
    if not listed then
        modules.game_textmessage.displayFailureMessage('Select a party member first.')
        return
    end
    local creature = findVisiblePartyMember(memberName)
    assignPartyMemberToSlot(slotId, {
        name = memberName, outfit = creature and creature:getOutfit() or nil
    })
end

function clearFriendSlot(slotId)
    local slot = helperWindow and helperWindow:recursiveGetChildById(slotId)
    if not slot then return end
    slot.friendName = nil
    slot.friendEnabled = true
    slot.friendThreshold = 80
    g_settings.setNode(friendConfigKey(slotId), {})
    g_settings.save()
    refreshFriendSlot(slot)
end

function setFriendEnabled(slotId, enabled)
    local slot = helperWindow and helperWindow:recursiveGetChildById(slotId)
    if not slot or not slot.friendName then return end
    slot.friendEnabled = enabled == true
    saveFriendSlot(slot)
end

function setFriendThreshold(slotId, value)
    local slot = helperWindow and helperWindow:recursiveGetChildById(slotId)
    if not slot then return end
    slot.friendThreshold = normalizeFriendThreshold(value)
    slot:recursiveGetChildById('thresholdBox'):setCurrentOptionByData(
        slot.friendThreshold, true)
    saveFriendSlot(slot)
end

local function restoreFriendSlots()
    for _, prefix in ipairs({ 'friendSlot', 'massFriendSlot' }) do
        local seenNames = {}
        local slotCount = getFriendSlotCount(prefix)
        for i = 1, 2 do
            local slot = helperWindow:recursiveGetChildById(prefix .. i)
            local saved = g_settings.getNode(friendConfigKey(slot:getId())) or {}
            local savedName = i <= slotCount and saved.name or nil
            if savedName and seenNames[savedName] then savedName = nil end
            if savedName then seenNames[savedName] = true end
            slot.friendName = savedName
            slot.friendEnabled = saved.enabled ~= false
            slot.friendThreshold = normalizeFriendThreshold(saved.threshold)
            if not savedName and saved.name then
                g_settings.setNode(friendConfigKey(slot:getId()), {})
            end
            refreshFriendSlot(slot)
        end
    end
    g_settings.save()
    refreshPartyMemberList(true)
end

local function resetPartyHealingState()
    selectedPartyMember = nil
    selectedMassPartyMember = nil
    for _, prefix in ipairs({ 'friendSlot', 'massFriendSlot' }) do
        for i = 1, 2 do
            local slot = helperWindow and
                helperWindow:recursiveGetChildById(prefix .. i)
            if slot then
                slot.friendName = nil
                slot.friendEnabled = true
                slot.friendThreshold = 80
                g_settings.setNode(friendConfigKey(slot:getId()), {})
                refreshFriendSlot(slot)
            end
        end
    end
    g_settings.save()
    lastPartyRefreshAt = 0
    refreshPartyMemberList(true)
end

local function updatePartySession()
    local player = g_game.getLocalPlayer()
    local inParty = player ~= nil and player:isPartyMember()
    if partySessionActive and not inParty then
        partySessionActive = false
        resetPartyHealingState()
    elseif not partySessionActive and inParty then
        partySessionActive = true
        selectedPartyMember = nil
        selectedMassPartyMember = nil
        lastPartyRefreshAt = 0
        refreshPartyMemberList(true)
    end
    return inParty
end

local function showHelperAfterAssignment()
    restoreHelperAfterAssignment = false
    local helperV2 = modules.game_baiakeros_helper_v2
    if helperV2 and helperV2.restoreAfterHealingAssignment then
        helperV2.restoreAfterHealingAssignment()
    end
end

local function hideHelperForAssignment()
    local helperV2 = modules.game_baiakeros_helper_v2
    if helperV2 and helperV2.hideForHealingAssignment then
        helperV2.hideForHealingAssignment()
    end
    restoreHelperAfterAssignment = false
    if helperWindow then helperWindow:hide() end
end

local function startSpellAssignment(slot)
    selectedSlot = slot
    hideHelperForAssignment()
    spellSelectorOpen = true

    local function finishAssignment(spell)
        local targetSlot = selectedSlot
        spellSelectorOpen = false
        selectedSlot = nil
        if targetSlot and spell then
            applySpell(targetSlot, spell)
            saveSelection(targetSlot, 'spell', spell.name)
        end
        showHelperAfterAssignment()
    end

    local actionbar = modules.game_actionbar
    if not actionbar or not actionbar.openFilteredSpellSelector then
        spellSelectorOpen = false
        selectedSlot = nil
        showHelperAfterAssignment()
        modules.game_textmessage.displayFailureMessage('The action bar spell selector is not available.')
        return
    end

    actionbar.openFilteredSpellSelector({
        title = 'Assign Spell',
        spells = getAvailableHealingSpells(),
        preselected = slot.assignedSpell,
        onConfirm = finishAssignment,
        onCancel = function() finishAssignment(nil) end
    })
end

local function clearSpellAssignment(slot)
    clearSlot(slot)
    setThreshold(slot, slot.threshold or 50)
    g_settings.setNode(configKey(slot:getId()), { threshold = slot.threshold })
    g_settings.save()
end

function showSpellMenu(slotId, mousePosition, mouseButton)
    if mouseButton ~= MouseRightButton then return false end
    local slot = helperWindow:recursiveGetChildById(slotId)
    if not slot then return true end

    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption('Assign Spell', function() startSpellAssignment(slot) end)
    if slot.assignedSpell then
        menu:addSeparator()
        menu:addOption('Clear Assignment', function() clearSpellAssignment(slot) end)
    end
    menu:display(mousePosition)
    return true
end

local function isSingleTargetAttackSpell(spell)
    if not spell then return false end
    local words = tostring(spell.words or ''):lower()
    if ATTACK_SPELL_AREAS[words] then return false end
    return spell.needTarget == true or (tonumber(spell.range) or -1) > 0
end

local function hasRequiredAttackSpellHarmony(spell, player)
    if not spell then return false end
    local words = tostring(spell.words or ''):lower()
    if not MONK_FULL_HARMONY_SPELLS[words] then return true end
    return player and player:getHarmony() >= MONK_FULL_HARMONY
end

local function refreshAttackSlot(slot)
    if not slot then return end
    local spellIcon = slot:recursiveGetChildById('attackSpellIcon')
    local itemIcon = slot:recursiveGetChildById('attackItemIcon')
    local nameLabel = slot:recursiveGetChildById('attackNameLabel')
    local assignButton = slot:recursiveGetChildById('attackAssignButton')
    spellIcon:hide()
    itemIcon:hide()
    setHelperItemSlotEmptyVisual(assignButton, true)
    if slot.assignedAttackSpell then
        local spell = slot.assignedAttackSpell
        spellIcon:setImageSource(Spells.getIconFileByProfile('Default'))
        spellIcon:setImageClip(Spells.getImageClip(spell.clientId, 'Default'))
        spellIcon:show()
        setHelperItemSlotEmptyVisual(assignButton, true)
        nameLabel:setText(spell.name)
        assignButton:setTooltip(string.format('%s\n%s\nLevel %d | Mana %d',
            spell.name, spell.words, spell.level or 0, spell.mana or 0))
    elseif slot.assignedAttackRune then
        itemIcon:setItemId(slot.assignedAttackRune.id)
        itemIcon:show()
        setHelperItemSlotEmptyVisual(assignButton, false)
        nameLabel:setText(slot.assignedAttackRune.name)
        assignButton:setTooltip(slot.assignedAttackRune.name)
    else
        local isRuneSlot = slot.attackSlotKind == 'rune'
        nameLabel:setText(isRuneSlot and 'Empty rune slot' or 'Empty spell slot')
        assignButton:setTooltip(isRuneSlot and
            'Right-click to assign a rune' or 'Right-click to assign an attack spell')
    end
    local singleTarget = isSingleTargetAttackSpell(slot.assignedAttackSpell)
    if singleTarget then slot.attackMinEnemies = 1 end

    slot:recursiveGetChildById('attackEnabledBox'):setChecked(slot.attackEnabled ~= false)
    local enemiesLabel = slot:recursiveGetChildById('attackEnemiesLabel')
    local enemiesDecrease = slot:recursiveGetChildById('attackEnemiesDecrease')
    local enemiesIncrease = slot:recursiveGetChildById('attackEnemiesIncrease')
    local enemiesPanel = slot:recursiveGetChildById('attackEnemiesPanel')
    local creaturesTooltip = singleTarget and
        'Single-target spells always use exactly 1 creature.' or ''
    enemiesLabel:setText(tostring(slot.attackMinEnemies or 1))
    enemiesLabel:setColor(singleTarget and '#777777' or '#eeeeee')
    enemiesDecrease:setEnabled(not singleTarget)
    enemiesIncrease:setEnabled(not singleTarget)
    enemiesDecrease:setTooltip(creaturesTooltip)
    enemiesIncrease:setTooltip(creaturesTooltip)
    enemiesPanel:setTooltip(creaturesTooltip)
    slot:recursiveGetChildById('attackManaLabel'):setText(
        string.format('%d%%', slot.attackMinMana or 0))
    local multipleBox = slot:recursiveGetChildById('attackAllowMultipleBox')
    if multipleBox then
        updatingAttackMultiple = true
        multipleBox:setVisible(singleTarget)
        multipleBox:setChecked(slot.attackAllowMultiple == true)
        multipleBox:setTooltip(singleTarget and 'Cast if have +1 creatures' or '')
        updatingAttackMultiple = false
    end
    local priorityBox = slot:recursiveGetChildById('attackPriorityBox')
    if priorityBox then
        updatingAttackPriority = true
        priorityBox:setCurrentOptionByData(slot.attackPriority or 1, true)
        updatingAttackPriority = false
    end
end

local function saveAttackSlot(slot)
    local kind
    local id
    if slot.assignedAttackSpell then
        kind = 'spell'
        id = slot.assignedAttackSpell.id
    elseif slot.assignedAttackRune then
        kind = 'rune'
        id = slot.assignedAttackRune.id
    end
    local key = attackConfigKey(slot:getId())
    -- setNode updates an existing OTML node and does not delete properties
    -- omitted from the Lua table. Remove it first so clearing an assignment
    -- cannot leave stale kind/id values that return on the next login.
    g_settings.remove(key)
    g_settings.setNode(key, {
        kind = kind,
        id = id,
        spellName = slot.assignedAttackSpell and slot.assignedAttackSpell.name or nil,
        spellWords = slot.assignedAttackSpell and slot.assignedAttackSpell.words or nil,
        enabled = slot.attackEnabled ~= false,
        minEnemies = slot.attackMinEnemies or 1,
        minMana = slot.attackMinMana or 0,
        allowMultiple = slot.attackAllowMultiple == true,
        priority = slot.attackPriority or 1
    })
    -- Keep assignment identity outside the compound node too. This prevents
    -- an OTUI change event from destroying the spell while the remaining
    -- numeric conditions are being refreshed.
    if kind then
        g_settings.set(key .. '_kind', kind)
        g_settings.set(key .. '_id', id)
    else
        g_settings.remove(key .. '_kind')
        g_settings.remove(key .. '_id')
    end
    g_settings.save()
end

local function clearAttackSlot(slot)
    slot.assignedAttackSpell = nil
    slot.assignedAttackRune = nil
    slot.attackAllowMultiple = false
    refreshAttackSlot(slot)
    saveAttackSlot(slot)
end

local function startAttackSpellAssignment(slot)
    hideHelperForAssignment()
    local actionbar = modules.game_actionbar
    if not actionbar or not actionbar.openFilteredSpellSelector then
        showHelperAfterAssignment()
        modules.game_textmessage.displayFailureMessage('The spell selector is not available.')
        return
    end
    actionbar.openFilteredSpellSelector({
        title = 'Assign Attack Spell',
        spells = getAvailableAttackSpells(),
        preselected = slot.assignedAttackSpell,
        onConfirm = function(spell)
            if spell then
                slot.assignedAttackSpell = spell
                slot.assignedAttackRune = nil
                if isSingleTargetAttackSpell(spell) then slot.attackMinEnemies = 1 end
                refreshAttackSlot(slot)
                saveAttackSlot(slot)
            end
            showHelperAfterAssignment()
        end,
        onCancel = function() showHelperAfterAssignment() end
    })
end

function showAttackSpellSlotMenu(slotId, mousePosition, mouseButton)
    if mouseButton ~= MouseRightButton then return false end
    local slot = helperWindow and helperWindow:recursiveGetChildById(slotId)
    if not slot then return true end
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption('Assign Spell', function() startAttackSpellAssignment(slot) end)
    if slot.assignedAttackSpell then
        menu:addSeparator()
        menu:addOption('Remove Assignment', function() clearAttackSlot(slot) end)
    end
    menu:display(mousePosition)
    return true
end

function showAttackRuneSlotMenu(slotId, mousePosition, mouseButton)
    if mouseButton ~= MouseRightButton then return false end
    local slot = helperWindow and helperWindow:recursiveGetChildById(slotId)
    if not slot then return true end
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    if slot.assignedAttackRune then
        menu:addOption('Remove Item', function() clearAttackSlot(slot) end)
        menu:addSeparator()
    end
    local runes = {}
    for _, rune in pairs(ATTACK_RUNES) do table.insert(runes, rune) end
    table.sort(runes, function(a, b) return a.name < b.name end)
    for _, rune in ipairs(runes) do
        local selectedRune = rune
        menu:addOption('Assign ' .. selectedRune.name, function()
            slot.assignedAttackSpell = nil
            slot.assignedAttackRune = selectedRune
            refreshAttackSlot(slot)
            saveAttackSlot(slot)
        end)
    end
    menu:display(mousePosition)
    return true
end

function showExplorerLureSpellMenu(mousePosition, mouseButton)
    if mouseButton ~= MouseRightButton then return false end
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption('Assign Lure Spell', function()
        hideHelperForAssignment()
        local actionbar = modules.game_actionbar
        if not actionbar or not actionbar.openFilteredSpellSelector then
            showHelperAfterAssignment()
            modules.game_textmessage.displayFailureMessage('The spell selector is not available.')
            return
        end
        actionbar.openFilteredSpellSelector({
            title = 'Assign Lure Spell',
            spells = getAvailableExplorerLureSpells(),
            preselected = getSelectedExplorerLureSpell(),
            onConfirm = function(spell)
                if spell then setExplorerLureSpell(spell.name) end
                showHelperAfterAssignment()
            end,
            onCancel = function() showHelperAfterAssignment() end
        })
    end)
    if getSelectedExplorerLureSpell() then
        menu:addSeparator()
        menu:addOption('Clear', function() setExplorerLureSpell(nil) end)
    end
    menu:display(mousePosition)
    return true
end

function setAttackSlotEnabled(slotId, enabled)
    if restoringAttackSlots then return end
    local slot = helperWindow and helperWindow:recursiveGetChildById(slotId)
    if not slot then return end
    slot.attackEnabled = enabled == true
    saveAttackSlot(slot)
end

function changeAttackEnemies(slotId, delta)
    if restoringAttackSlots then return end
    local slot = helperWindow and helperWindow:recursiveGetChildById(slotId)
    if not slot then return end
    if isSingleTargetAttackSpell(slot.assignedAttackSpell) then
        slot.attackMinEnemies = 1
        refreshAttackSlot(slot)
        saveAttackSlot(slot)
        return
    end
    slot.attackMinEnemies = math.max(1, math.min(ATTACK_MAX_CREATURES,
        (slot.attackMinEnemies or 1) + delta))
    refreshAttackSlot(slot)
    saveAttackSlot(slot)
end

function changeAttackMana(slotId, delta)
    if restoringAttackSlots then return end
    local slot = helperWindow and helperWindow:recursiveGetChildById(slotId)
    if not slot then return end
    slot.attackMinMana = math.max(0, math.min(100,
        (slot.attackMinMana or 0) + delta))
    refreshAttackSlot(slot)
    saveAttackSlot(slot)
end

function setAttackPriority(slotId, priority)
    if updatingAttackPriority or restoringAttackSlots then return end
    local slot = helperWindow and helperWindow:recursiveGetChildById(slotId)
    priority = tonumber(priority)
    if not slot or not priority then return end
    slot.attackPriority = math.max(1, math.min(ATTACK_MAX_PRIORITY, priority))
    refreshAttackSlot(slot)
    saveAttackSlot(slot)
end

function setAttackAllowMultiple(slotId, enabled)
    if updatingAttackMultiple or restoringAttackSlots then return end
    local slot = helperWindow and helperWindow:recursiveGetChildById(slotId)
    if not slot or not isSingleTargetAttackSpell(slot.assignedAttackSpell) then return end
    slot.attackAllowMultiple = enabled == true
    saveAttackSlot(slot)
end

local function restoreAttackSlots()
    restoringAttackSlots = true
    local profile = getVocationProfile()
    local visibleCount = profile and ATTACK_SPELL_SLOT_COUNTS[profile.key] or 0
    local visibleRuneCount = profile and ATTACK_RUNE_SLOT_COUNTS[profile.key] or 0
    local legacyRunes = {}
    for i = 1, 6 do
        local legacy = g_settings.getNode(attackConfigKey('attackSlot' .. i)) or {}
        if legacy.kind == 'rune' and ATTACK_RUNES[tonumber(legacy.id)] then
            table.insert(legacyRunes, legacy)
        end
        local slot = helperWindow:recursiveGetChildById('attackSpellSlot' .. i)
        slot:setVisible(i <= visibleCount)
        slot.attackSlotKind = 'spell'
        local slotKey = attackConfigKey(slot:getId())
        local savedNode = g_settings.getNode(slotKey)
        local saved = savedNode or (legacy.kind == 'spell' and legacy or {})
        local scalarKind = g_settings.getString(slotKey .. '_kind', '')
        local scalarId = g_settings.getString(slotKey .. '_id', '')
        if scalarKind ~= '' then saved.kind = scalarKind end
        if scalarId ~= '' then saved.id = scalarId end
        slot.assignedAttackSpell = nil
        slot.assignedAttackRune = nil
        slot.attackEnabled = saved.enabled ~= false
        slot.attackMinEnemies = math.max(1, math.min(ATTACK_MAX_CREATURES,
            tonumber(saved.minEnemies) or 1))
        slot.attackMinMana = math.max(0, math.min(100,
            tonumber(saved.minMana) or 0))
        slot.attackAllowMultiple = saved.allowMultiple == true
        slot.attackPriority = math.max(1, math.min(ATTACK_MAX_PRIORITY,
            tonumber(saved.priority) or i))
        if saved.kind == 'spell' then
            slot.assignedAttackSpell = findSavedAttackSpell(
                saved.id, currentVocation, saved.spellName, saved.spellWords)
        end
        if isSingleTargetAttackSpell(slot.assignedAttackSpell) then
            slot.attackMinEnemies = 1
        end
        refreshAttackSlot(slot)
        if not savedNode and saved.kind == 'spell' then saveAttackSlot(slot) end
    end
    for i = 1, ATTACK_RUNE_WIDGET_COUNT do
        local slot = helperWindow:recursiveGetChildById('attackRuneSlot' .. i)
        slot:setVisible(i <= visibleRuneCount)
        slot.attackSlotKind = 'rune'
        local slotKey = attackConfigKey(slot:getId())
        local savedNode = g_settings.getNode(slotKey)
        local saved = savedNode or legacyRunes[i] or {}
        local scalarKind = g_settings.getString(slotKey .. '_kind', '')
        local scalarId = g_settings.getString(slotKey .. '_id', '')
        if scalarKind ~= '' then saved.kind = scalarKind end
        if scalarId ~= '' then saved.id = scalarId end
        slot.assignedAttackSpell = nil
        slot.assignedAttackRune = saved.kind == 'rune' and
            ATTACK_RUNES[tonumber(saved.id)] or nil
        slot.attackEnabled = saved.enabled ~= false
        slot.attackMinEnemies = math.max(1, math.min(ATTACK_MAX_CREATURES,
            tonumber(saved.minEnemies) or 1))
        slot.attackMinMana = math.max(0, math.min(100,
            tonumber(saved.minMana) or 0))
        slot.attackAllowMultiple = false
        slot.attackPriority = math.max(1, math.min(ATTACK_MAX_PRIORITY,
            tonumber(saved.priority) or i))
        refreshAttackSlot(slot)
        if not savedNode and saved.kind == 'rune' then saveAttackSlot(slot) end
    end
    restoringAttackSlots = false
    restoreAttackPostures()
end

local function refreshAttackPresetBox()
    local box = helperWindow and helperWindow:recursiveGetChildById('attackPresetBox')
    if not box then return end
    updatingAttackPreset = true
    box:clearOptions()
    for _, name in ipairs(attackPresetNames) do
        box:addOption(name, presetId(name))
    end
    box:setCurrentOptionByData(attackPreset, true)
    updatingAttackPreset = false
end

function loadAttackPresetState()
    attackPresetNames = normalizePresetNames(
        g_settings.getList(attackPresetNamesConfigKey()))
    attackPreset = presetId(g_settings.getString(attackPresetConfigKey(), 'default'))
    if not findPresetName(attackPresetNames, attackPreset) then
        attackPreset = 'default'
    end
    refreshAttackPresetBox()
end

function setAttackPreset(preset)
    if updatingAttackPreset or not preset or preset == attackPreset then return end
    if attackRotationEnabled then
        refreshAttackPresetBox()
        showHelperNotification('Disable Shooter Helper before changing the Attack Preset.', false)
        return
    end
    preset = presetId(preset)
    if not findPresetName(attackPresetNames, preset) then return end
    attackPreset = preset
    g_settings.set(attackPresetConfigKey(), attackPreset)
    g_settings.save()
    restoreAttackSlots()
    refreshAttackPresetBox()
    showHelperNotification('Attack Preset: ' ..
        (findPresetName(attackPresetNames, attackPreset) or 'Default'), true)
end

function getAttackState()
    local profile = getVocationProfile()
    local spellCount = profile and ATTACK_SPELL_SLOT_COUNTS[profile.key] or 0
    local runeCount = profile and ATTACK_RUNE_SLOT_COUNTS[profile.key] or 0
    local slots = {}
    if helperWindow then
        for _, entry in ipairs({
            { kind = 'spell', prefix = 'attackSpellSlot', count = 5 },
            { kind = 'rune', prefix = 'attackRuneSlot', count = ATTACK_RUNE_WIDGET_COUNT }
        }) do
            for index = 1, entry.count do
                local id = entry.prefix .. index
                local slot = helperWindow:recursiveGetChildById(id)
                if slot then
                    slots[id] = {
                        spell = slot.assignedAttackSpell,
                        rune = slot.assignedAttackRune,
                        enabled = slot.attackEnabled ~= false,
                        minMana = slot.attackMinMana or 0,
                        minEnemies = slot.attackMinEnemies or 1,
                        allowMultiple = slot.attackAllowMultiple == true,
                        singleTarget = isSingleTargetAttackSpell(slot.assignedAttackSpell),
                        priority = slot.attackPriority or index,
                        visible = index <= (entry.kind == 'spell' and spellCount or runeCount)
                    }
                end
            end
        end
    end

    local postures = {}
    local options = getAttackPostureOptions()
    for _, kind in ipairs({ 'stance', 'passive' }) do
        postures[kind] = {}
        for index, option in ipairs(options[kind] or {}) do
            postures[kind][index] = {
                name = option.name,
                words = option.words,
                clientId = option.clientId,
                selected = selectedAttackPostures[kind] == option.id,
                cooldownExpiry = getAttackPostureCooldownExpiry(kind, option)
            }
        end
    end

    return {
        preset = attackPreset,
        presetNames = attackPresetNames,
        spellCount = spellCount,
        runeCount = runeCount,
        lureSlotVisible = profile and LURE_SPELL_NAMES[profile.key] ~= nil or false,
        lureSpell = getSelectedExplorerLureSpell(),
        slots = slots,
        postures = postures,
        autoTarget = autoAttackEnabled,
        shooter = attackRotationEnabled,
        autoTargetMode = autoAttackMode
    }
end

local function restoreAssignmentCursor()
    if modules.client_options and modules.client_options.getOption('nativeCursor') then
        g_window.restoreMouseCursor()
    else
        g_mouse.popCursor('target')
    end
end

function keepAssignmentCursor()
    if not assignmentGrabber or not g_ui.isMouseGrabbed() or
        (not assigningPotionSlot and not assigningExerciseWeapon and not assigningHelperItem) then
        return
    end
    if modules.client_options and modules.client_options.getOption('nativeCursor') then
        g_window.setSystemCursor('cross')
    else
        -- Resizable UI widgets may push their own cursor. Reinsert target at
        -- the top of the custom cursor stack until an item is accepted.
        g_mouse.popCursor('target')
        g_mouse.pushCursor('target')
    end
end

function beginItemAssignmentCursor()
    assignmentGrabber:grabMouse()
    if modules.client_options and modules.client_options.getOption('nativeCursor') then
        g_window.setSystemCursor('cross')
    else
        g_mouse.pushCursor('target')
    end
    if assignmentCursorEvent then removeEvent(assignmentCursorEvent) end
    assignmentCursorEvent = cycleEvent(keepAssignmentCursor, 30)
    g_keyboard.unbindKeyPress('Escape', cancelItemAssignment)
    g_keyboard.bindKeyPress('Escape', cancelItemAssignment)
end

function endItemAssignmentCursor()
    g_keyboard.unbindKeyPress('Escape', cancelItemAssignment)
    if assignmentCursorEvent then
        removeEvent(assignmentCursorEvent)
        assignmentCursorEvent = nil
    end
    if assignmentGrabber and g_ui.isMouseGrabbed() then assignmentGrabber:ungrabMouse() end
    restoreAssignmentCursor()
end

cancelItemAssignment = function()
    if not assigningPotionSlot and not assigningExerciseWeapon and not assigningHelperItem then return false end

    assigningPotionSlot = nil
    assigningExerciseWeapon = false
    assigningHelperItem = nil
    endItemAssignmentCursor()
    showHelperAfterAssignment()
    modules.game_textmessage.displayStatusMessage('Item selection cancelled.')
    return true
end

local function getClickedItem(mousePosition)
    local root = modules.game_interface.getRootPanel()
    local clickedWidget = root and root:recursiveGetChildByPos(mousePosition, false)
    while clickedWidget do
        if clickedWidget:getClassName() == 'UIItem' then
            -- Container and Store Inbox item widgets can be marked virtual
            -- even though they hold a real item. The caller validates its ID.
            local item = clickedWidget:getItem()
            if item then return item end
        elseif clickedWidget:getClassName() == 'UIGameMap' then
            local tile = clickedWidget:getTile(mousePosition)
            local thing = tile and tile:getTopUseThing()
            if thing and thing:isItem() then return thing end
        end
        clickedWidget = clickedWidget:getParent()
    end
    return nil
end

-- Shared item picker used by equipment as well as the existing potion cursor.
function beginHelperItemAssignment(acceptItem, instruction)
    if not assignmentGrabber or g_ui.isMouseGrabbed() then return false end
    assigningHelperItem=acceptItem
    hideHelperForAssignment()
    beginItemAssignmentCursor()
    modules.game_textmessage.displayStatusMessage(instruction)
    return true
end

local function finishHelperItemAssignment(mousePosition, mouseButton)
    if mouseButton==MouseRightButton then return cancelItemAssignment() end
    if mouseButton~=MouseLeftButton then keepAssignmentCursor();return true end
    local item=getClickedItem(mousePosition)
    local accepted,reason=assigningHelperItem(item)
    if not accepted then
        modules.game_textmessage.displayFailureMessage(reason or 'Selecione um item válido.')
        keepAssignmentCursor()
        return true
    end
    assigningHelperItem=nil
    endItemAssignmentCursor()
    showHelperAfterAssignment()
    return true
end

local function finishPotionAssignment(mousePosition, mouseButton)
    local slot = assigningPotionSlot
    if mouseButton == MouseRightButton then return cancelItemAssignment() end
    if mouseButton ~= MouseLeftButton or not slot then
        keepAssignmentCursor()
        return true
    end

    local item = getClickedItem(mousePosition)
    local potion = item and POTIONS[item:getId()]
    if not potion then
        modules.game_textmessage.displayFailureMessage('Select a health or spirit potion.')
        keepAssignmentCursor()
        return true
    end

    assigningPotionSlot = nil
    endItemAssignmentCursor()
    applyPotion(slot, potion)
    slot.resource = potion.resources.health and 'health' or 'mana'
    refreshPotionResource(slot)
    saveSelection(slot, 'potion', potion.id)
    modules.game_textmessage.displayStatusMessage(potion.name .. ' assigned to BaiakEros Helper.')
    showHelperAfterAssignment()
    return true
end

local function startPotionAssignment(slot)
    if g_ui.isMouseGrabbed() then return end
    assigningPotionSlot = slot
    hideHelperForAssignment()
    beginItemAssignmentCursor()
    modules.game_textmessage.displayStatusMessage('Select a health or spirit potion.')
end

local function clearPotionAssignment(slot)
    clearSlot(slot)
    setThreshold(slot, slot.threshold or 50)
    g_settings.setNode(configKey(slot:getId()), { threshold = slot.threshold })
    g_settings.save()
end

function showPotionMenu(slotId, mousePosition, mouseButton)
    if mouseButton ~= MouseRightButton then return false end
    local slot = helperWindow:recursiveGetChildById(slotId)
    if not slot then return true end

    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption('Assign Potion', function() startPotionAssignment(slot) end)
    if slot.assignedPotion then
        menu:addSeparator()
        menu:addOption('Clear Assignment', function() clearPotionAssignment(slot) end)
    end
    menu:display(mousePosition)
    return true
end

local function isSelectedManaTrainingSpellAvailable()
    local player = g_game.getLocalPlayer()
    local vocation = detectVocation()
    return isHasteSpellAvailable(MANA_TRAINING.selectedSpell, player, vocation)
end

function updateManaTrainingControls()
    if not helperWindow then return end
    local slot = helperWindow:recursiveGetChildById('manaSpellTrainingSlot')
    local percentLabel = helperWindow:recursiveGetChildById('manaTrainingPercentLabel')
    local decreaseButton = helperWindow:recursiveGetChildById('manaTrainingDecrease')
    local increaseButton = helperWindow:recursiveGetChildById('manaTrainingIncrease')
    local enabledBox = helperWindow:recursiveGetChildById('manaTrainingEnabledBox')
    local spell = MANA_TRAINING.selectedSpell
    if spell and not isSelectedManaTrainingSpellAvailable() then
        spell = nil
        MANA_TRAINING.selectedSpell = nil
        MANA_TRAINING.enabled = false
    end

    if slot then
        local selected = spell ~= nil
        local tooltip = selected and string.format(
            '%s\n%s\nMana: %d\nClick to activate. Right-click to select or remove the spell.',
            spell.name, spell.words, spell.mana or 0) or
            'Right-click to select a spell.'
        slot.itemIcon:hide()
        slot.spellIcon:setVisible(selected)
        if selected then
            slot.spellIcon:setImageSource(Spells.getIconFileByProfile('Default'))
            slot.spellIcon:setImageClip(Spells.getImageClip(spell.clientId, 'Default'))
        end
        setHelperItemSlotEmptyVisual(slot.assignButton, not selected)
        local selectedMask = slot.assignButton:recursiveGetChildById(
            'selectedBackgroundMask')
        if selectedMask then selectedMask:setVisible(selected) end
        slot:setTooltip(tooltip)
        slot.assignButton:setTooltip(tooltip)
        slot.spellIcon:setTooltip(tooltip)
    end
    if percentLabel then
        percentLabel:setText(string.format('%d%%', MANA_TRAINING.threshold))
    end
    if decreaseButton then decreaseButton:setEnabled(spell ~= nil) end
    if increaseButton then increaseButton:setEnabled(spell ~= nil) end
    if enabledBox then
        updatingExtrasControls = true
        enabledBox:setEnabled(spell ~= nil)
        enabledBox:setChecked(spell ~= nil and MANA_TRAINING.enabled)
        updatingExtrasControls = false
    end
end

function changeManaTrainingThreshold(delta)
    local value = MANA_TRAINING.threshold or 90
    if delta > 0 then
        value = value >= 95 and 99 or math.min(95, value + 5)
    elseif delta < 0 then
        value = value == 99 and 95 or math.max(5, value - 5)
    end
    MANA_TRAINING.threshold = value
    updateManaTrainingControls()
end

function setManaTrainingEnabled(enabled)
    if updatingExtrasControls then return end
    local canEnable = enabled == true and isSelectedManaTrainingSpellAvailable()
    MANA_TRAINING.enabled = canEnable
    MANA_TRAINING.nextAt = 0
    if canEnable then
        -- The two automatic support spell systems are mutually exclusive.
        g_settings.set(autoHasteEnabledConfigKey(), false)
        g_settings.save()
        AUTO_HASTE.nextAt = 0
    end
    updateExtrasControls()
end

function getTrainingState()
    return {
        exerciseWeaponId = EXERCISE_TRAINING.selectedWeaponId,
        exerciseEnabled = EXERCISE_TRAINING.enabled == true,
        manaSpell = MANA_TRAINING.selectedSpell,
        manaEnabled = MANA_TRAINING.enabled == true,
        manaThreshold = MANA_TRAINING.threshold or 90
    }
end

function clearManaTrainingSpell()
    MANA_TRAINING.selectedSpell = nil
    MANA_TRAINING.enabled = false
    MANA_TRAINING.nextAt = 0
    updateManaTrainingControls()
end

function startManaTrainingSpellAssignment()
    hideHelperForAssignment()
    local actionbar = modules.game_actionbar
    if not actionbar or not actionbar.openFilteredSpellSelector then
        showHelperAfterAssignment()
        modules.game_textmessage.displayFailureMessage(
            'The spell selector is not available.')
        return
    end

    local function finishAssignment(spell)
        if spell then
            MANA_TRAINING.selectedSpell = spell
            MANA_TRAINING.enabled = false
            MANA_TRAINING.nextAt = 0
        end
        showHelperAfterAssignment()
        updateManaTrainingControls()
    end

    actionbar.openFilteredSpellSelector({
        title = 'Select Spell',
        spells = getAvailableManaTrainingSpells(),
        preselected = MANA_TRAINING.selectedSpell,
        emptyText = 'No support spell selected',
        onConfirm = finishAssignment,
        onCancel = function() finishAssignment(nil) end
    })
end

function showManaTrainingSpellMenu(mousePosition, mouseButton)
    if mouseButton ~= MouseRightButton then return false end
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption('Select Spell', startManaTrainingSpellAssignment)
    if MANA_TRAINING.selectedSpell then
        menu:addSeparator()
        menu:addOption('Remove Spell', clearManaTrainingSpell)
    end
    menu:display(mousePosition)
    return true
end

function handleManaTrainingSlotClick(mousePosition, mouseButton)
    if mouseButton == MouseRightButton then
        return showManaTrainingSpellMenu(mousePosition, mouseButton)
    end
    if mouseButton ~= MouseLeftButton then return false end
    if not MANA_TRAINING.selectedSpell then
        modules.game_textmessage.displayFailureMessage(
            'Right-click and select a spell first.')
        return true
    end
    setManaTrainingEnabled(not MANA_TRAINING.enabled)
    return true
end

function checkManaTraining()
    if isManualActionPending() then return end
    if not g_game.isOnline() or not MANA_TRAINING.enabled then return end
    local player = g_game.getLocalPlayer()
    local spell = MANA_TRAINING.selectedSpell
    if not player or player:isDead() or not isSelectedManaTrainingSpellAvailable() then
        return
    end

    local now = g_clock.millis()
    local maxMana = player:getMaxMana()
    local manaPercent = maxMana and maxMana > 0 and
        math.floor((player:getMana() * 100) / maxMana) or 100
    if now < MANA_TRAINING.nextAt or not isSpellCooldownReady(spell, now) or
        manaPercent < (MANA_TRAINING.threshold or 90) or
        (spell.mana or 0) > player:getMana() then
        return
    end

    g_game.talk(spell.words)
    guardSpellCommand(spell, 3, now)
    MANA_TRAINING.nextAt = now + MANA_TRAINING.retryInterval
end

function resetExerciseRuntime()
    if EXERCISE_TRAINING.walking then
        local player = g_game.getLocalPlayer()
        if player then player:stopAutoWalk() end
    end
    EXERCISE_TRAINING.nextAt = 0
    EXERCISE_TRAINING.dispatched = false
    EXERCISE_TRAINING.walking = false
    EXERCISE_TRAINING.destination = nil
    EXERCISE_TRAINING.targetPosition = nil
    EXERCISE_TRAINING.walkStartedAt = 0
end

function saveExerciseTrainingSession()
    if not activeExerciseCharacterKey then return end
    exerciseTrainingSessions[activeExerciseCharacterKey] = {
        selectedWeaponId = EXERCISE_TRAINING.selectedWeaponId,
        enabled = EXERCISE_TRAINING.enabled == true
    }
end

function restoreExerciseTrainingSession()
    activeExerciseCharacterKey = getPlayerKey()
    local session = exerciseTrainingSessions[activeExerciseCharacterKey]
    local weaponId = session and tonumber(session.selectedWeaponId) or nil
    if not EXERCISE_WEAPONS[weaponId] then weaponId = nil end
    EXERCISE_TRAINING.selectedWeaponId = weaponId
    EXERCISE_TRAINING.enabled = weaponId ~= nil and session and
        session.enabled == true or false
    resetExerciseRuntime()
end

function dispatchExerciseWeapon(weapon, target, now)
    EXERCISE_TRAINING.dispatched = true
    EXERCISE_TRAINING.nextAt = now + EXERCISE_TRAINING.verificationInterval
    g_game.useWith(weapon, target)
end

function updateExerciseTrainingControls()
    if not helperWindow then return end
    local slot = helperWindow:recursiveGetChildById('exerciseWeaponSlot')
    local modeBox = helperWindow:recursiveGetChildById('exerciseTrainingModeBox')
    local weaponId = EXERCISE_TRAINING.selectedWeaponId
    if not EXERCISE_WEAPONS[weaponId] then weaponId = nil end

    if slot then
        local tooltip = weaponId and
            'Click to activate.\nRight-click to select or remove the exercise weapon.' or
            'Right-click to select an exercise weapon.'
        slot.itemIcon:setItemId(weaponId or 0)
        slot.itemIcon:setVisible(weaponId ~= nil)
        setHelperItemSlotEmptyVisual(slot.assignButton, weaponId == nil)
        -- The action-bar slot texture contains four dots. Cover only its
        -- interior after assignment, preserving the surrounding frame.
        local selectedMask = slot.assignButton:recursiveGetChildById(
            'selectedBackgroundMask')
        if selectedMask then selectedMask:setVisible(weaponId ~= nil) end
        slot:setTooltip(tooltip)
        slot.assignButton:setTooltip(tooltip)
        slot.itemIcon:setTooltip(tooltip)
    end
    if modeBox then
        updatingExtrasControls = true
        modeBox:setEnabled(weaponId ~= nil)
        modeBox:setCurrentOptionByData(weaponId ~= nil and
            EXERCISE_TRAINING.enabled and
            'enable' or 'disable', true)
        updatingExtrasControls = false
    end
end

function clearExerciseWeapon()
    EXERCISE_TRAINING.selectedWeaponId = nil
    EXERCISE_TRAINING.enabled = false
    resetExerciseRuntime()
    saveExerciseTrainingSession()
    updateExerciseTrainingControls()
end

function finishExerciseWeaponAssignment(mousePosition, mouseButton)
    if mouseButton == MouseRightButton then return cancelItemAssignment() end
    if mouseButton ~= MouseLeftButton then
        keepAssignmentCursor()
        return true
    end

    local item = getClickedItem(mousePosition)
    local weaponId = item and item:getId() or nil
    if not EXERCISE_WEAPONS[weaponId] then
        modules.game_textmessage.displayFailureMessage('Select a valid exercise weapon.')
        keepAssignmentCursor()
        return true
    end

    assigningExerciseWeapon = false
    endItemAssignmentCursor()
    EXERCISE_TRAINING.selectedWeaponId = weaponId
    EXERCISE_TRAINING.enabled = false
    resetExerciseRuntime()
    saveExerciseTrainingSession()
    updateExerciseTrainingControls()
    -- Store Inbox may expose an item proxy without Item:getName() in this
    -- client build. The validated client ID is enough for the assignment.
    local confirmation = 'Exercise weapon assigned to Training.'

    -- Store/container widgets finish processing their click after this mouse
    -- release callback. Restore the Helper afterwards so they cannot hide or
    -- lower it again, and replace the selection prompt at the same time.
    if exerciseHelperRestoreEvent then removeEvent(exerciseHelperRestoreEvent) end
    exerciseHelperRestoreEvent = scheduleEvent(function()
        exerciseHelperRestoreEvent = nil
        if not g_game.isOnline() then return end
        showHelperAfterAssignment()
        if modules.game_textmessage.clearMessages then
            modules.game_textmessage.clearMessages()
        end
        modules.game_textmessage.displayStatusMessage(confirmation)
    end, 100)
    return true
end

function startExerciseWeaponAssignment()
    if g_ui.isMouseGrabbed() then return end
    assigningPotionSlot = nil
    assigningExerciseWeapon = true
    hideHelperForAssignment()
    beginItemAssignmentCursor()
    modules.game_textmessage.displayStatusMessage('Select an exercise weapon.')
end

function showExerciseWeaponMenu(mousePosition, mouseButton)
    if mouseButton ~= MouseRightButton then return false end
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption('Select Exercise Weapon', startExerciseWeaponAssignment)
    if EXERCISE_TRAINING.selectedWeaponId then
        menu:addSeparator()
        menu:addOption('Remove Exercise', clearExerciseWeapon)
    end
    menu:display(mousePosition)
    return true
end

function handleExerciseWeaponSlotClick(mousePosition, mouseButton)
    if mouseButton == MouseRightButton then
        return showExerciseWeaponMenu(mousePosition, mouseButton)
    end
    if mouseButton ~= MouseLeftButton then return false end
    if not EXERCISE_TRAINING.selectedWeaponId then
        modules.game_textmessage.displayFailureMessage(
            'Right-click and select an exercise weapon first.')
        return true
    end
    setExerciseTrainingEnabled(not EXERCISE_TRAINING.enabled)
    return true
end

function setExerciseTrainingEnabled(enabled)
    if updatingExtrasControls then return end
    local canEnable = enabled == true and EXERCISE_TRAINING.selectedWeaponId ~= nil
    EXERCISE_TRAINING.enabled = canEnable
    resetExerciseRuntime()
    saveExerciseTrainingSession()
    updateExerciseTrainingControls()
end

function positionDistance(a, b)
    if not a or not b or a.z ~= b.z then return math.huge end
    return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

function findVisibleExerciseDummies(playerPosition)
    local candidates = {}
    local seen = {}
    for dummyId in pairs(EXERCISE_DUMMY_IDS) do
        for position, item in pairs(g_map.findItemsById(dummyId, 32)) do
            if position.z == playerPosition.z then
                local key = string.format('%d:%d:%d', position.x, position.y, position.z)
                if not seen[key] then
                    seen[key] = true
                    table.insert(candidates, {
                        item = item,
                        position = position,
                        private = dummyId ~= 28558 and dummyId ~= 28565
                    })
                end
            end
        end
    end
    return candidates
end

function findDummyAt(position)
    local tile = position and g_map.getTile(position)
    if not tile then return nil end
    for _, item in ipairs(tile:getItems()) do
        if EXERCISE_DUMMY_IDS[item:getId()] then return item end
    end
    return nil
end

function findClosestMeleeDummy(playerPosition, candidates)
    local best
    local offsets = {
        {-1, -1}, {0, -1}, {1, -1}, {-1, 0},
        {1, 0}, {-1, 1}, {0, 1}, {1, 1}
    }
    for _, candidate in ipairs(candidates) do
        for _, offset in ipairs(offsets) do
            local destination = {
                x = candidate.position.x + offset[1],
                y = candidate.position.y + offset[2],
                z = candidate.position.z
            }
            local tile = g_map.getTile(destination)
            local samePosition = positionDistance(playerPosition, destination) == 0
            if samePosition or (tile and tile:isWalkable()) then
                local path, result = g_map.findPath(playerPosition, destination, 10000, 0)
                if result == PathFindResults.Ok or result == PathFindResults.Position then
                    local length = path and #path or 0
                    if not best or length < best.length then
                        best = {
                            item = candidate.item,
                            position = candidate.position,
                            destination = destination,
                            length = length
                        }
                    end
                end
            end
        end
    end
    return best
end

function notifyExerciseFailure(text, now)
    if now - EXERCISE_TRAINING.lastNoticeAt < EXERCISE_TRAINING.noticeInterval then return end
    EXERCISE_TRAINING.lastNoticeAt = now
    modules.game_textmessage.displayFailureMessage(text)
end

function checkExerciseTraining()
    if not g_game.isOnline() or not EXERCISE_TRAINING.enabled then
        return
    end

    local now = g_clock.millis()
    if now < EXERCISE_TRAINING.nextAt then return end
    -- There is no client-side acknowledgement that exercise training remains
    -- active. Re-dispatching useWith every two minutes safely renews it. Keep
    -- `dispatched` set while retrying so manual movement still disables it.
    local player = g_game.getLocalPlayer()
    if not player or player:isDead() then return end
    local weaponId = EXERCISE_TRAINING.selectedWeaponId
    local weaponInfo = EXERCISE_WEAPONS[weaponId]
    if not weaponInfo then return end
    local weapon = g_game.findPlayerItem(weaponId, -1, 0)
    if not weapon then
        notifyExerciseFailure('The selected exercise weapon was not found in your open backpacks.', now)
        EXERCISE_TRAINING.nextAt = now + EXERCISE_TRAINING.searchRetryInterval
        return
    end

    local playerPosition = player:getPosition()
    if EXERCISE_TRAINING.walking then
        local target = findDummyAt(EXERCISE_TRAINING.targetPosition)
        if target and positionDistance(playerPosition, EXERCISE_TRAINING.targetPosition) <= 1 then
            EXERCISE_TRAINING.walking = false
            dispatchExerciseWeapon(weapon, target, now)
            return
        end
        if not target or now - EXERCISE_TRAINING.walkStartedAt >= EXERCISE_TRAINING.walkTimeout then
            EXERCISE_TRAINING.walking = false
            EXERCISE_TRAINING.destination = nil
            EXERCISE_TRAINING.targetPosition = nil
        else
            EXERCISE_TRAINING.nextAt = now + EXERCISE_TRAINING.checkInterval
            return
        end
    end

    local candidates = findVisibleExerciseDummies(playerPosition)
    if #candidates == 0 then
        notifyExerciseFailure('No exercise dummy is visible.', now)
        EXERCISE_TRAINING.nextAt = now + EXERCISE_TRAINING.searchRetryInterval
        return
    end

    if weaponInfo.farUse then
        local publicCandidates = {}
        for _, candidate in ipairs(candidates) do
            if not candidate.private then table.insert(publicCandidates, candidate) end
        end
        table.sort(publicCandidates, function(a, b)
            return positionDistance(playerPosition, a.position) <
                positionDistance(playerPosition, b.position)
        end)
        if #publicCandidates > 0 then
            dispatchExerciseWeapon(weapon, publicCandidates[1].item, now)
            return
        end
        -- House dummies are approached even with a ranged weapon. This lets
        -- the server's authoritative same-house check decide access and
        -- prevents firing into a house from outside.
    end

    local target = findClosestMeleeDummy(playerPosition, candidates)
    if not target then
        notifyExerciseFailure('No accessible exercise dummy was found.', now)
        EXERCISE_TRAINING.nextAt = now + EXERCISE_TRAINING.searchRetryInterval
        return
    end
    if positionDistance(playerPosition, target.position) <= 1 then
        dispatchExerciseWeapon(weapon, target.item, now)
        return
    end

    -- Movement from here is the Helper's intentional approach to a melee
    -- dummy, so it must not be mistaken for the player's cancel movement.
    EXERCISE_TRAINING.dispatched = false
    EXERCISE_TRAINING.walking = true
    EXERCISE_TRAINING.destination = target.destination
    EXERCISE_TRAINING.targetPosition = target.position
    EXERCISE_TRAINING.walkStartedAt = now
    EXERCISE_TRAINING.nextAt = now + EXERCISE_TRAINING.checkInterval
    player:autoWalk(target.destination)
end

function onExerciseTrainingPlayerPositionChange(player, newPosition, oldPosition)
    if not newPosition or not oldPosition or
        (newPosition.x == oldPosition.x and newPosition.y == oldPosition.y and
            newPosition.z == oldPosition.z) then
        return
    end

    if not EXERCISE_TRAINING.enabled or not EXERCISE_TRAINING.dispatched then return end

    -- Once useWith has started the exercise, any subsequent movement stops
    -- Training immediately. The automatic approach to a melee dummy happens
    -- before `dispatched`, so it remains allowed.
    setExerciseTrainingEnabled(false)
end

function closeSelector()
    if spellSelectorOpen and modules.game_actionbar and modules.game_actionbar.closeFilteredSpellSelector then
        modules.game_actionbar.closeFilteredSpellSelector()
    end
    spellSelectorOpen = false
    selectedSlot = nil
    showHelperAfterAssignment()
end

local function restoreSlots()
    currentVocation = detectVocation()

    for i = 1, 3 do
        for _, kind in ipairs({ 'spell', 'potion' }) do
            local slot = helperWindow:recursiveGetChildById(kind .. 'Slot' .. i)
            clearSlot(slot)
            local saved = g_settings.getNode(configKey(slot:getId()))
            setThreshold(slot, saved and saved.threshold or DEFAULT_THRESHOLDS[i])
            slot.resource = saved and saved.resource or 'health'

            if saved and saved.kind == 'spell' then
                local spell = findSavedHealingSpell(saved.id, currentVocation)
                if spell then
                    applySpell(slot, spell)
                end
            elseif saved and saved.kind == 'potion' then
                local potion = POTIONS[tonumber(saved.id)]
                if potion then applyPotion(slot, potion) end
            end
        end
    end
end

local function updateEnabledCheckBox()
    local checkBox = helperWindow and helperWindow:recursiveGetChildById('healingEnabledBox')
    if not checkBox then return end
    updatingEnabledCheckBox = true
    checkBox:setChecked(healingEnabled)
    updatingEnabledCheckBox = false
end

function cancelExtrasToggleReset()
    if extrasToggleResetEvent then
        removeEvent(extrasToggleResetEvent)
        extrasToggleResetEvent = nil
    end
    extrasToggleResetPlayerKey = nil
end

function startExtrasToggleResetMigration()
    local migrationKey = extrasToggleResetConfigKey()
    if g_settings.getBoolean(migrationKey, false) then return end

    local playerKey = getPlayerKey()
    if extrasToggleResetEvent and extrasToggleResetPlayerKey == playerKey then
        return
    end
    cancelExtrasToggleReset()
    extrasToggleResetPlayerKey = playerKey

    -- Clear stale client checkmarks first. The server commands below are
    -- intentionally sent once for this migration so the persisted KV state
    -- and the UI begin from the same disabled state.
    local shouldDisableAutoloot =
        g_settings.getBoolean(commandEnabledConfigKey('autoloot'), false) or
        g_settings.getBoolean(lootPouchKnownConfigKey(), false)
    g_settings.set(changeGoldEnabledConfigKey(), false)
    g_settings.set(commandEnabledConfigKey('flask'), false)
    g_settings.set(commandEnabledConfigKey('autoloot'), false)
    g_settings.save()

    local commands = { '!changegold off', '!flask off' }
    if shouldDisableAutoloot then commands[#commands + 1] = '!autoloot off' end
    local commandIndex = 1
    local sendNextCommand
    sendNextCommand = function()
        extrasToggleResetEvent = nil
        if not g_game.isOnline() or getPlayerKey() ~= playerKey then
            extrasToggleResetPlayerKey = nil
            return
        end

        local command = commands[commandIndex]
        if command then
            g_game.talk(command)
            commandIndex = commandIndex + 1
            extrasToggleResetEvent = scheduleEvent(sendNextCommand,
                EXTRAS_TOGGLE_RESET_COMMAND_DELAY)
            return
        end

        g_settings.set(migrationKey, true)
        g_settings.save()
        extrasToggleResetPlayerKey = nil
        updateExtrasControls()
    end
    sendNextCommand()
end

updateExtrasControls = function()
    if not helperWindow then return end
    local reconnectBox = helperWindow:recursiveGetChildById('autoReconnectBox')
    local eatFoodBox = helperWindow:recursiveGetChildById('autoEatFoodBox')
    local hasteBox = helperWindow:recursiveGetChildById('autoHasteBox')
    local hasteSpellBox = helperWindow:recursiveGetChildById('autoHasteSpellBox')
    local hasteInPzBox = helperWindow:recursiveGetChildById('autoHasteInPzBox')
    local changeGoldBox = helperWindow:recursiveGetChildById('changeGoldBox')
    local flaskRemoverBox = helperWindow:recursiveGetChildById('flaskRemoverBox')
    local autolootBox = helperWindow:recursiveGetChildById('autolootBox')
    local autolootInfo = helperWindow:recursiveGetChildById('autolootInfo')
    updatingExtrasControls = true
    if reconnectBox then
        reconnectBox:setChecked(g_settings.getBoolean(autoReconnectConfigKey(), false))
    end
    if eatFoodBox then
        eatFoodBox:setChecked(g_settings.getBoolean(autoEatConfigKey(), false))
    end

    local availableHasteSpells = getAvailableHasteSpells()
    local savedHasteName = g_settings.getString(autoHasteSpellConfigKey(), '')
    local chosenHasteSpell
    if hasteSpellBox then
        hasteSpellBox:clearOptions()
        for _, spell in ipairs(availableHasteSpells) do
            hasteSpellBox:addOption(spell.words, spell.name)
            if spell.name == savedHasteName then chosenHasteSpell = spell end
        end
        if savedHasteName ~= CLEARED_HASTE_SPELL then
            chosenHasteSpell = chosenHasteSpell or availableHasteSpells[1]
        end
        if chosenHasteSpell then
            hasteSpellBox:setCurrentOptionByData(chosenHasteSpell.name, true)
        else
            hasteSpellBox:addOption(#availableHasteSpells > 0 and
                'No haste selected' or 'No haste available', '')
            hasteSpellBox:setCurrentOptionByData('', true)
        end
        hasteSpellBox:setEnabled(chosenHasteSpell ~= nil)
    end
    AUTO_HASTE.selectedSpell = chosenHasteSpell
    if hasteBox then
        hasteBox:setChecked(g_settings.getBoolean(autoHasteEnabledConfigKey(), false))
        hasteBox:setEnabled(chosenHasteSpell ~= nil)
    end
    if hasteInPzBox then
        hasteInPzBox:setChecked(g_settings.getBoolean(
            autoHasteInProtectionZoneConfigKey(), false))
        hasteInPzBox:setEnabled(chosenHasteSpell ~= nil)
    end
    if changeGoldBox then
        changeGoldBox:setChecked(g_settings.getBoolean(
            changeGoldEnabledConfigKey(), false))
    end
    if flaskRemoverBox then
        flaskRemoverBox:setChecked(g_settings.getBoolean(
            commandEnabledConfigKey('flask'), false))
    end

    local hasLootPouch = g_settings.getBoolean(lootPouchKnownConfigKey(), false)
    -- Discover the pouch once. Loot snapshots must not rescan all backpacks
    -- or synchronously rewrite the same character setting on every kill.
    if not hasLootPouch then
        for _, container in pairs(g_game.getContainers()) do
            for _, item in ipairs(container:getItems()) do
                local itemId = item.getServerId and tonumber(item:getServerId()) or 0
                if itemId == 0 then itemId = tonumber(item:getId()) or 0 end
                if itemId == 23721 then
                    hasLootPouch = true
                    g_settings.set(lootPouchKnownConfigKey(), true)
                    g_settings.save()
                    break
                end
            end
            if hasLootPouch then break end
        end
    end
    if autolootBox then
        autolootBox:setChecked(hasLootPouch and g_settings.getBoolean(
            commandEnabledConfigKey('autoloot'), false))
        autolootBox:setEnabled(hasLootPouch)
        autolootBox:setOpacity(hasLootPouch and 1 or 0.45)
    end
    if autolootInfo then
        autolootInfo:setTooltip(hasLootPouch and
            tr('Automatically enables or disables server autoloot with !autoloot on or !autoloot off.') or
            tr('Buy a Loot Pouch from the Store first to enable Autoloot.'))
    end
    updatingExtrasControls = false
    updateExerciseTrainingControls()
    updateManaTrainingControls()
end

function setChangeGoldEnabled(enabled)
    if updatingExtrasControls or not g_game.isOnline() then return end
    local value = enabled == true
    g_settings.set(changeGoldEnabledConfigKey(), value)
    g_settings.save()
    g_game.talk(value and '!changegold on' or '!changegold off')
end

function setFlaskRemoverEnabled(enabled)
    if updatingExtrasControls or not g_game.isOnline() then return end
    local value = enabled == true
    g_settings.set(commandEnabledConfigKey('flask'), value)
    g_settings.save()
    g_game.talk(value and '!flask on' or '!flask off')
end

function setAutolootEnabled(enabled)
    if updatingExtrasControls or not g_game.isOnline() then return end
    if not g_settings.getBoolean(lootPouchKnownConfigKey(), false) then
        updateExtrasControls()
        return
    end
    local value = enabled == true
    g_settings.set(commandEnabledConfigKey('autoloot'), value)
    g_settings.save()
    g_game.talk(value and '!autoloot on' or '!autoloot off')
end

function openLootPouchStore()
    if not modules.game_store then return end
    modules.game_store.show()
    scheduleEvent(function()
        local storeUI = modules.game_store.getUI()
        local listCategory = storeUI and storeUI:recursiveGetChildById('listCategory')
        local extrasWidget = listCategory and listCategory:getChildById('Extras')
        if not extrasWidget or not extrasWidget.Button then
            g_game.requestStoreOffers('Useful Things', '', 0, 1)
            return
        end
        extrasWidget.Button:onClick()
        scheduleEvent(function()
            for subId, subData in ipairs(extrasWidget.subCategories or {}) do
                if subData.name == 'Useful Things' then
                    local usefulThingsWidget = extrasWidget:getChildById(subId)
                    if usefulThingsWidget and usefulThingsWidget.Button then
                        usefulThingsWidget.Button:onClick()
                        return
                    end
                end
            end
            g_game.requestStoreOffers('Useful Things', '', 0, 1)
        end, 300)
    end, 500)
end

function getToolsState()
    local hasteSpells = {}
    for _, spell in ipairs(getAvailableHasteSpells()) do
        hasteSpells[#hasteSpells + 1] = {
            name = spell.name,
            words = spell.words,
            clientId = spell.clientId,
            level = spell.level,
            mana = spell.mana
        }
    end
    local hasLootPouch = g_settings.getBoolean(lootPouchKnownConfigKey(), false)
    return {
        autoReconnect = g_settings.getBoolean(autoReconnectConfigKey(), false),
        autoEatFood = g_settings.getBoolean(autoEatConfigKey(), false),
        autoHaste = g_settings.getBoolean(autoHasteEnabledConfigKey(), false),
        autoHasteSpell = AUTO_HASTE.selectedSpell and AUTO_HASTE.selectedSpell.name or '',
        autoHasteInPz = g_settings.getBoolean(autoHasteInProtectionZoneConfigKey(), false),
        changeGold = g_settings.getBoolean(changeGoldEnabledConfigKey(), false),
        flaskRemover = g_settings.getBoolean(commandEnabledConfigKey('flask'), false),
        autoloot = hasLootPouch and g_settings.getBoolean(
            commandEnabledConfigKey('autoloot'), false),
        hasLootPouch = hasLootPouch,
        hasteSpells = hasteSpells
    }
end

function setAutoReconnectEnabled(enabled)
    if updatingExtrasControls then return end
    g_settings.set(autoReconnectConfigKey(), enabled == true)
    g_settings.save()
    updateExtrasControls()
end

function setAutoEatFoodEnabled(enabled)
    if updatingExtrasControls then return end
    g_settings.set(autoEatConfigKey(), enabled == true)
    g_settings.save()
    nextAutoEatAt = 0
    updateExtrasControls()
end

function setAutoHasteEnabled(enabled)
    if updatingExtrasControls then return end
    local canEnable = enabled == true and AUTO_HASTE.selectedSpell ~= nil
    if canEnable then
        MANA_TRAINING.enabled = false
        MANA_TRAINING.nextAt = 0
    end
    g_settings.set(autoHasteEnabledConfigKey(), canEnable)
    g_settings.save()
    AUTO_HASTE.nextAt = 0
    updateExtrasControls()
end

function setAutoHasteSpell(spellName)
    if updatingExtrasControls or not spellName or spellName == '' then return end
    local player = g_game.getLocalPlayer()
    local vocation = detectVocation()
    local spell = SpellInfo.Default[spellName]
    if not isHasteSpellAvailable(spell, player, vocation) then
        updateExtrasControls()
        return
    end
    AUTO_HASTE.selectedSpell = spell
    g_settings.set(autoHasteSpellConfigKey(), spell.name)
    g_settings.save()
    AUTO_HASTE.nextAt = 0
end

function clearAutoHasteSpell()
    AUTO_HASTE.selectedSpell = nil
    AUTO_HASTE.nextAt = 0
    g_settings.set(autoHasteSpellConfigKey(), CLEARED_HASTE_SPELL)
    g_settings.set(autoHasteEnabledConfigKey(), false)
    g_settings.save()
    updateExtrasControls()
end

function setAutoHasteInProtectionZone(enabled)
    if updatingExtrasControls then return end
    g_settings.set(autoHasteInProtectionZoneConfigKey(), enabled == true)
    g_settings.save()
    AUTO_HASTE.nextAt = 0
end

local function findFoodInKnownContainers()
    for _, container in pairs(g_game.getContainers()) do
        for _, item in ipairs(container:getItems()) do
            if FOOD_ITEM_IDS[item:getId()] then
                return item
            end
        end
    end
    return nil
end

local function checkAutoEatFood()
    if isManualItemPending() then return end
    if not g_game.isOnline() or not g_settings.getBoolean(autoEatConfigKey(), false) then
        return
    end

    local now = g_clock.millis()
    if now < nextAutoEatAt then return end

    local player = g_game.getLocalPlayer()
    if not player then return end

    -- Protocol 15.11 sends the remaining regeneration/food time. Waiting
    -- until the last five minutes avoids wasting food while keeping the
    -- character fed. On protocols without that field Auto Eat stays idle.
    if not g_game.getFeature(GamePlayerRegenerationTime) then return end
    local regenerationTime = tonumber(player:getRegenerationTime()) or 0
    if regenerationTime > AUTO_EAT_BELOW_SECONDS then return end

    local food = findFoodInKnownContainers()
    if food then
        g_game.use(food)
        nextAutoEatAt = now + AUTO_EAT_RETRY_INTERVAL
    end
end

function checkAutoHaste()
    if isManualActionPending() then return end
    if not g_game.isOnline() or
        not g_settings.getBoolean(autoHasteEnabledConfigKey(), false) then
        return
    end

    local party=modules.game_baiakeros_helper_v2 and modules.game_baiakeros_helper_v2.PartyHuntV2
    if party and party.isChangingFloor and party.isChangingFloor() then return end

    local player = g_game.getLocalPlayer()
    if not player or player:isDead() or player:hasState(PlayerStates.Haste) then return end
    if player:hasState(PlayerStates.Pz) and not g_settings.getBoolean(
        autoHasteInProtectionZoneConfigKey(), false) then
        return
    end
    local spell = AUTO_HASTE.selectedSpell
    local vocation = detectVocation()
    if not isHasteSpellAvailable(spell, player, vocation) then return end

    local now = g_clock.millis()
    if now < AUTO_HASTE.nextAt or not isSpellCooldownReady(spell, now) or
        (spell.mana or 0) > player:getMana() then
        return
    end

    g_game.talk(spell.words)
    guardSpellCommand(spell, 3, now)
    AUTO_HASTE.nextAt = now + AUTO_HASTE.retryInterval
end

function setHealingEnabled(enabled)
    if updatingEnabledCheckBox then return end
    currentVocation = detectVocation()
    healingEnabled = enabled == true and g_game.isOnline() and currentVocation ~= nil
    g_settings.set(enabledConfigKey(), healingEnabled)
    g_settings.save()
    updateEnabledCheckBox()

    if healingEnabled then
        setStatus('Automatic healing active', '#78d878')
    elseif currentVocation then
        setStatus('Automatic healing disabled', '#d8b878')
    else
        setStatus('Unsupported vocation', '#d88878')
    end
end

local function getHealthPercent(player)
    local maxHealth = player:getMaxHealth()
    if not maxHealth or maxHealth <= 0 then return 100 end
    return math.floor((player:getHealth() * 100) / maxHealth)
end

local function getManaPercent(player)
    local maxMana = player:getMaxMana()
    if not maxMana or maxMana <= 0 then return 100 end
    return math.floor((player:getMana() * 100) / maxMana)
end

local function getHealingCandidates(player, healthPercent, now)
    local candidates = {}
    currentVocation = detectVocation()

    for i = 1, 3 do
        local slot = helperWindow:recursiveGetChildById('spellSlot' .. i)
        local spell = slot and slot.assignedSpell
        local threshold = slot and slot.threshold or 0
        if spell and healthPercent <= threshold and
            isSpellAvailable(spell, player, currentVocation) and
            (spell.mana or 0) <= player:getMana() and
            isSpellCooldownReady(spell, now) then
            table.insert(candidates, { spell = spell, threshold = threshold, slot = i })
        end
    end

    -- A lower threshold represents a more urgent spell and must win whenever
    -- more than one configured range matches the current health percentage.
    table.sort(candidates, function(a, b)
        if a.threshold == b.threshold then return a.slot < b.slot end
        return a.threshold < b.threshold
    end)
    return candidates
end

local function getPotionCandidates(healthPercent, manaPercent, resourceFilter)
    local candidates = {}
    for i = 1, 3 do
        local slot = helperWindow:recursiveGetChildById('potionSlot' .. i)
        local potion = slot and slot.assignedPotion
        local threshold = slot and slot.threshold or 0
        local resource = slot and slot.resource or 'health'
        local resourcePercent = resource == 'mana' and manaPercent or healthPercent
        if potion and resource == resourceFilter and resourcePercent <= threshold then
            table.insert(candidates, {
                potion = potion,
                threshold = threshold,
                slot = i,
                resource = resource,
                resourcePercent = resourcePercent
            })
        end
    end
    table.sort(candidates, function(a, b)
        if a.threshold == b.threshold then return a.slot < b.slot end
        return a.threshold < b.threshold
    end)
    return candidates
end

local function getPartyHealingCandidate(prefix)
    local candidates = {}
    for i = 1, getFriendSlotCount(prefix) do
        local slot = helperWindow:recursiveGetChildById(prefix .. i)
        local creature = slot and slot.friendEnabled ~= false and
            findVisiblePartyMember(slot.friendName) or nil
        local healthPercent = creature and creature:getHealthPercent() or 100
        if creature and healthPercent > 0 and
            healthPercent <= (slot.friendThreshold or 80) then
            table.insert(candidates, {
                creature = creature,
                healthPercent = healthPercent,
                threshold = slot.friendThreshold or 80,
                slot = i
            })
        end
    end
    table.sort(candidates, function(first, second)
        if first.healthPercent == second.healthPercent then
            return first.slot < second.slot
        end
        return first.healthPercent < second.healthPercent
    end)
    return candidates[1]
end

local function getFriendHealingCandidate()
    return getPartyHealingCandidate('friendSlot')
end

local function getMassFriendHealingCandidate()
    return getPartyHealingCandidate('massFriendSlot')
end

local function tryMassFriendHealing(now)
    if isManualActionPending() then return false end
    local profile = getVocationProfile()
    if not profile or not profile.massFriendHealing then return false end
    local spell = SpellInfo.Default and SpellInfo.Default["Nature's Embrace"]
    if not spell or not isSpellCooldownReady(spell, now) then return false end
    local selected = getMassFriendHealingCandidate()
    if not selected then return false end

    g_game.talk(string.format('%s "%s', spell.words,
        selected.creature:getName()))
    guardSpellCommand(spell, 2, now)
    return true
end

local function tryFriendHealing(now)
    if isManualActionPending() then return false end
    local profile = getVocationProfile()
    if not profile or not profile.friendHealing or profile.friendKind == 'uh' then
        return false
    end
    local selected = getFriendHealingCandidate()
    if not selected then return false end

    if not isCooldownReady(spellGroupCooldownsById, 2, now) then return false end
    local words = profile.friendKind == 'monkSio' and 'exura tio sio' or 'exura sio'
    g_game.talk(string.format('%s "%s', words, selected.creature:getName()))
    guardSpellCommand(nil, 2, now)
    setStatus(string.format('%d%%  healing %s', selected.healthPercent,
        selected.creature:getName()), '#78d878')
    return true
end

-- Defensive equipment uses the same authoritative cooldowns as the other
-- Helper actions, including the shared potion timer and manual hotkey guard.
local equipmentShieldPendingUntil = 0
function tryCastEquipmentShield(cancel)
    if not g_game.isOnline() or isManualActionPending() then return false end
    local player = g_game.getLocalPlayer()
    local profile = detectVocation()
    local spell = SpellInfo.Default[cancel and 'Cancel Magic Shield' or 'Magic Shield']
    if not player or not profile or (profile.baseSpellVocation ~= 1 and profile.baseSpellVocation ~= 2) or
        player:getHealth() <= 0 or player:hasState(PlayerStates.Pz) or not spell or
        player:getLevel() < spell.level or player:getMana() < spell.mana then return false end
    local now = g_clock.millis()
    if not isSpellCooldownReady(spell, now) then return false end
    g_game.talk(spell.words)
    guardSpellCommand(spell, 3, now)
    spellCooldownsById[spell.id] = now + (spell.exhaustion or 2000)
    equipmentShieldPendingUntil = now + 750
    return true
end

function tryUseEquipmentShieldPotion()
    if not g_game.isOnline() or isManualActionPending() or isManualItemPending() then return false end
    local player = g_game.getLocalPlayer()
    local profile = detectVocation()
    local spell = SpellInfo.Default['Magic Shield']
    local now = g_clock.millis()
    if not player or not profile or (profile.baseSpellVocation ~= 1 and profile.baseSpellVocation ~= 2) or
        player:getHealth() <= 0 or player:getLevel() < 14 or player:hasState(PlayerStates.Pz) or
        now < nextPotionAt or now < equipmentShieldPendingUntil or not spell or
        player:hasState(PlayerStates.ManaShield) or player:hasState(PlayerStates.NewManaShield) or
        isCooldownReady(spellCooldownsById, spell.id, now) or
        player:getInventoryCount(35563, 0) <= 0 then return false end
    g_game.useInventoryItemWith(35563, player, -1)
    nextPotionAt = now + POTION_COOLDOWN
    equipmentShieldPendingUntil = now + POTION_COOLDOWN
    return true
end

local function checkEquipmentShield()
    local v2 = modules.game_baiakeros_helper_v2
    if v2 and v2.BaiakHelperEquipmentV2 then v2.BaiakHelperEquipmentV2.checkShield() end
end

local function checkHealing()
    if not g_game.isOnline() then return end
    updatePartySession()
    refreshPartyMemberList(false)
    local player = g_game.getLocalPlayer()
    if not player or player:getHealth() <= 0 then return end
    if not healingEnabled then checkEquipmentShield(); return end

    local now = g_clock.millis()
    local healthPercent = getHealthPercent(player)
    local manaPercent = getManaPercent(player)

    local function usePotion(resource)
        if isManualItemPending() then return end
        if now < nextPotionAt then return end
        local selected = getPotionCandidates(healthPercent, manaPercent, resource)[1]
        if selected then
            -- Same path used by a "Use on yourself" item hotkey. The server
            -- remains authoritative for vocation and level restrictions.
            g_game.useInventoryItemWith(selected.potion.id, player, -1)
            nextPotionAt = now + POTION_COOLDOWN
            setStatus(string.format('%s %d%%  %s',
                selected.resource == 'mana' and 'MP' or 'HP',
                selected.resourcePercent, selected.potion.name), '#78d878')
        end
    end

    -- Life potions take priority on the shared item cooldown. Spell healing
    -- remains available on its independent cooldown while potions recover.
    usePotion('health')
    if not isManualActionPending() and isCooldownReady(spellGroupCooldownsById, 2, now) then
        local selected = getHealingCandidates(player, healthPercent, now)[1]
        if selected then
            local spell = selected.spell
            g_game.talk(spell.words)
            guardSpellCommand(spell, 2, now)
            setStatus(string.format('%d%%  %s', healthPercent, spell.words), '#78d878')
        end
    end
    checkEquipmentShield()
    usePotion('mana')
    if isCooldownReady(spellGroupCooldownsById, 2, now) and not tryMassFriendHealing(now) then
        tryFriendHealing(now)
    end
end

local function tileDistance(firstPosition, secondPosition)
    if not firstPosition or not secondPosition or firstPosition.z ~= secondPosition.z then return math.huge end
    return math.max(math.abs(firstPosition.x - secondPosition.x), math.abs(firstPosition.y - secondPosition.y))
end

local function getSingleTargetRangeMonsterCount(spell, monsters, playerPosition)
    if not isSingleTargetAttackSpell(spell) or not playerPosition then return 0 end
    local castRange = math.max(1, tonumber(spell.range) or 1)
    local count = 0
    for _, monster in ipairs(monsters) do
        local position = monster:getPosition()
        if position and tileDistance(playerPosition, position) <= castRange then
            count = count + 1
        end
    end
    return count
end

local function isPlayerSummon(creature)
    if not creature then return false end

    local creatureType = creature:getType()
    if creatureType and
        ((CreatureTypeSummonOwn and creatureType == CreatureTypeSummonOwn) or
        (CreatureTypeSummonOther and creatureType == CreatureTypeSummonOther)) then
        return true
    end

    -- The master id is kept as a fallback for servers/protocol revisions that
    -- expose the familiar as a regular monster while still sending its owner.
    local masterId = creature:getMasterId()
    return masterId and masterId > 0
end

local function isValidAutoAttackTarget(creature, playerPosition)
    if not creature or creature:isDead() or not creature:isMonster() or isPlayerSummon(creature) then
        return false
    end
    local position = creature:getPosition()
    return position and position.z == playerPosition.z and creature:getHealthPercent() > 0
end

local function getVisibleMonsters(playerPosition)
    local mapPanel = modules.game_interface and modules.game_interface.getMapPanel()
    local spectators = mapPanel and mapPanel:getSpectators() or {}
    local monsters = {}
    for _, creature in ipairs(spectators) do
        if isValidAutoAttackTarget(creature, playerPosition) then table.insert(monsters, creature) end
    end
    return monsters
end

local nextShooterLureAt = 0
local function checkShooterLureSpell(player, monsters, playerPosition)
    local party=modules.game_baiakeros_helper_v2 and modules.game_baiakeros_helper_v2.PartyHuntV2
    if party and party.isChangingFloor and party.isChangingFloor() then return false end
    local spell = getSelectedExplorerLureSpell()
    if not spell or g_clock.millis() < nextShooterLureAt then return false end

    local adjacent, distant, closestPosition, closestDistance = false, false
    for _, monster in ipairs(monsters) do
        local position = monster:getPosition()
        local range = math.max(math.abs(position.x - playerPosition.x),
            math.abs(position.y - playerPosition.y))
        if range <= 1 then adjacent = true end
        if range >= 2 and range <= 7 then distant = true end
        if not closestDistance or range < closestDistance then
            closestPosition, closestDistance = position, range
        end
    end
    if spell.name == 'Challenge' then
        if not adjacent then return false end
    elseif not distant then
        return false
    end
    if spell.name == 'Chivalrous Challenge' then
        local freeAdjacent = false
        for _, offset in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 },
                { 1, -1 }, { 1, 1 }, { -1, 1 }, { -1, -1 } }) do
            local tile = g_map.getTile({
                x = playerPosition.x + offset[1],
                y = playerPosition.y + offset[2], z = playerPosition.z
            })
            if tile and tile:getGround() and tile:isWalkable() then
                freeAdjacent = true
                break
            end
        end
        if not freeAdjacent then return false end
    end

    local direction
    if spell.name == 'Balanced Brawl' and closestPosition then
        local dx = closestPosition.x - playerPosition.x
        local dy = closestPosition.y - playerPosition.y
        direction = math.abs(dx) > math.abs(dy) and
            (dx > 0 and East or West) or (dy > 0 and South or North)
    end
    if not tryCastExplorerLureSpell(spell.name, direction) then return false end
    nextShooterLureAt = g_clock.millis() + 250
    return true
end

local function rotateNorthOffset(dx, dy, direction)
    if direction == East or direction == SouthEast or direction == NorthEast then
        return -dy, dx
    elseif direction == South then
        return -dx, -dy
    elseif direction == West or direction == SouthWest or direction == NorthWest then
        return dy, -dx
    end
    return dx, dy
end

local function isInDirectionalArea(player, playerPosition, monsterPosition, areaName, direction)
    local offsets = ATTACK_DIRECTIONAL_AREAS[areaName] or {}
    local monsterDx = monsterPosition.x - playerPosition.x
    local monsterDy = monsterPosition.y - playerPosition.y
    direction = direction or player:getDirection()
    for _, offset in ipairs(offsets) do
        local dx, dy = rotateNorthOffset(offset[1], offset[2], direction)
        if monsterDx == dx and monsterDy == dy then return true end
    end
    return false
end

local function getDirectionalAffectedMonsters(monsters, player, playerPosition, areaName, direction)
    local affected = {}
    for _, monster in ipairs(monsters) do
        local monsterPosition = monster:getPosition()
        if monsterPosition and isInDirectionalArea(
            player, playerPosition, monsterPosition, areaName, direction) then
            table.insert(affected, monster)
        end
    end
    return affected
end

local function getBestDirectionalSpellCast(monsters, player, playerPosition, areaName)
    local currentDirection = player:getDirection()
    local directions = {}
    if currentDirection == North or currentDirection == East or
        currentDirection == South or currentDirection == West then
        table.insert(directions, currentDirection)
    end
    table.insert(directions, North)
    table.insert(directions, East)
    table.insert(directions, South)
    table.insert(directions, West)
    local visited = {}
    local bestAffected = {}
    local bestDirection = directions[1]
    for _, direction in ipairs(directions) do
        if not visited[direction] then
            visited[direction] = true
            local affected = getDirectionalAffectedMonsters(
                monsters, player, playerPosition, areaName, direction)
            -- Keeping the first result makes the current facing direction win
            -- ties and avoids unnecessary turns when two waves hit equally.
            if #affected > #bestAffected then
                bestAffected = affected
                bestDirection = direction
            end
        end
    end
    return bestAffected, bestDirection
end

local function isInCircle(center, position, radius, manhattan)
    if not center or not position or center.z ~= position.z then return false end
    local dx = math.abs(position.x - center.x)
    local dy = math.abs(position.y - center.y)
    return dx <= radius and dy <= radius and dx + dy <= manhattan
end

local function getChainedMonsters(monsters, target, playerPosition, profile)
    local affected = {}
    if not target or not isValidAutoAttackTarget(target, playerPosition) then return affected end
    if profile.range and tileDistance(playerPosition, target:getPosition()) > profile.range then
        return affected
    end
    local selected = { [target:getId()] = true }
    table.insert(affected, target)
    local current = target
    while #affected < (profile.maxTargets or 1) do
        local best
        local bestDistance = math.huge
        for _, monster in ipairs(monsters) do
            if not selected[monster:getId()] then
                local distance = tileDistance(current:getPosition(), monster:getPosition())
                if distance <= (profile.chainRange or 1) and
                    (distance < bestDistance or
                    (distance == bestDistance and (not best or monster:getId() < best:getId()))) then
                    best = monster
                    bestDistance = distance
                end
            end
        end
        if not best then break end
        selected[best:getId()] = true
        table.insert(affected, best)
        current = best
    end
    return affected
end

local function getAttackSpellProfile(words)
    local explorer=modules.game_baiakeros_helper_v2
    local party=explorer and explorer.PartyHuntV2
    if words=='exevo gran vis lux' and party and party.hasBeamMastery and party.hasBeamMastery() then
        return {shape='directional',area='beamMastery10'}
    end
    return ATTACK_SPELL_AREAS[words]
end

local function getSpellAffectedMonsters(spell, monsters, player, playerPosition, target)
    local affected = {}
    if not spell or not playerPosition then return affected end
    local words = tostring(spell.words or ''):lower()
    local profile = getAttackSpellProfile(words)

    if profile and profile.shape == 'chain' then
        return getChainedMonsters(monsters, target, playerPosition, profile)
    end

    if profile and profile.shape == 'directional' then
        return getBestDirectionalSpellCast(
            monsters, player, playerPosition, profile.area)
    end

    if profile then
        local center = playerPosition
        if profile.shape == 'targetCircle' or profile.shape == 'targetSquare' then
            if not target or not isValidAutoAttackTarget(target, playerPosition) or
                tileDistance(playerPosition, target:getPosition()) > (profile.castRange or 1) then
                return affected
            end
            center = target:getPosition()
        end
        for _, monster in ipairs(monsters) do
            local monsterPosition = monster:getPosition()
            local inArea = false
            if profile.shape == 'square' or profile.shape == 'targetSquare' then
                inArea = tileDistance(center, monsterPosition) <= (profile.radius or 1)
            elseif profile.shape == 'circle' or profile.shape == 'targetCircle' then
                inArea = isInCircle(center, monsterPosition,
                    profile.radius or 1, profile.manhattan or profile.radius or 1)
            elseif profile.shape == 'ring' then
                inArea = isInCircle(center, monsterPosition,
                    profile.radius or 1, profile.manhattan or profile.radius or 1) and
                    tileDistance(center, monsterPosition) > (profile.innerRadius or 0)
            end
            if inArea then table.insert(affected, monster) end
        end
        return affected
    end

    -- Target and strike spells affect one creature. Some entries in the client
    -- spell list expose a positive range but omit needTarget, so both fields are
    -- considered here.
    local castRange = tonumber(spell.range) or -1
    if spell.needTarget or castRange > 0 then
        if target and isValidAutoAttackTarget(target, playerPosition) and
            (castRange <= 0 or tileDistance(playerPosition, target:getPosition()) <= castRange) then
            table.insert(affected, target)
        end
        return affected
    end

    -- Unknown untargeted spells use the conservative adjacent area. This is
    -- intentionally never the whole screen; a dedicated profile can expand it
    -- once its server combat area is known.
    for _, monster in ipairs(monsters) do
        if tileDistance(playerPosition, monster:getPosition()) <= 1 then
            table.insert(affected, monster)
        end
    end
    return affected
end

local function getRuneAffectedMonsters(rune, monsters, playerPosition, target)
    local affected = {}
    if not rune or not target or not isValidAutoAttackTarget(target, playerPosition) then
        return affected
    end
    if not rune.area then
        table.insert(affected, target)
        return affected
    end
    local center = target:getPosition()
    for _, monster in ipairs(monsters) do
        if isInCircle(center, monster:getPosition(), 3, 4) then
            table.insert(affected, monster)
        end
    end
    return affected
end

local function isBetterAutoAttackTarget(candidate, best, monsters, playerPosition)
    if not best then return true end
    local candidateDistance = tileDistance(playerPosition, candidate:getPosition())
    local bestDistance = tileDistance(playerPosition, best:getPosition())
    local candidateHealth = candidate:getHealthPercent()
    local bestHealth = best:getHealthPercent()

    local function areaScore(creature)
        local score = 0
        for _, monster in ipairs(monsters) do
            if tileDistance(creature:getPosition(), monster:getPosition()) <= 1 then
                score = score + 1
            end
        end
        return score
    end

    if autoAttackMode == 'C' then
        if candidateHealth ~= bestHealth then return candidateHealth < bestHealth end
        if candidateDistance ~= bestDistance then return candidateDistance < bestDistance end
    elseif autoAttackMode == 'D' then
        if candidateHealth ~= bestHealth then return candidateHealth > bestHealth end
        if candidateDistance ~= bestDistance then return candidateDistance < bestDistance end
    elseif autoAttackMode == 'E' then
        local candidateArea = areaScore(candidate)
        local bestArea = areaScore(best)
        if candidateArea ~= bestArea then return candidateArea > bestArea end
        if candidateDistance ~= bestDistance then return candidateDistance < bestDistance end
        if candidateHealth ~= bestHealth then return candidateHealth < bestHealth end
    elseif autoAttackMode == 'F' or autoAttackMode == 'H' then
        if candidateHealth ~= bestHealth then return candidateHealth < bestHealth end
    elseif autoAttackMode == 'G' or autoAttackMode == 'I' then
        if candidateHealth ~= bestHealth then return candidateHealth > bestHealth end
    end
    return candidate:getId() < best:getId()
end

local function getAdjacentMonsters(monsters, playerPosition)
    local adjacent = {}
    for _, monster in ipairs(monsters) do
        if tileDistance(playerPosition, monster:getPosition()) <= 1 then
            table.insert(adjacent, monster)
        end
    end
    return adjacent
end

local function getDistanceGroup(monsters, playerPosition, farthest)
    local selectedDistance = farthest and -1 or math.huge
    local selected = {}
    for _, monster in ipairs(monsters) do
        local distance = tileDistance(playerPosition, monster:getPosition())
        local betterDistance = farthest and distance > selectedDistance or distance < selectedDistance
        if betterDistance then
            selectedDistance = distance
            selected = { monster }
        elseif distance == selectedDistance then
            table.insert(selected, monster)
        end
    end
    return selected
end

local function containsCreature(creatures, creature)
    if not creature then return false end
    for _, candidate in ipairs(creatures) do
        if candidate:getId() == creature:getId() then return true end
    end
    return false
end

local function isInProtectionZone(player, states)
    return player and player:hasState(PlayerStates.Pz, states)
end

local function checkAutoAttack()
    local partyModule=modules.game_baiakeros_helper_v2
    local party=partyModule and partyModule.PartyHuntV2
    if party and party.syncLeaderTarget and party.syncLeaderTarget() then return end
    if checkAttackAfkTimeout() then return end
    if not autoAttackEnabled or not g_game.isOnline() then return end
    local player = g_game.getLocalPlayer()
    if not player or player:isDead() then return end
    if isInProtectionZone(player) then
        if g_game.getAttackingCreature() then g_game.cancelAttack() end
        return
    end
    local playerPosition = player:getPosition()
    if not playerPosition then return end

    local monsters = getVisibleMonsters(playerPosition)
    local currentTarget = g_game.getAttackingCreature()
    local explorer = modules.game_baiakeros_helper_v2
    if explorer and explorer.isSingleTargetExplorerHunt and
        explorer.isSingleTargetExplorerHunt() and
        containsCreature(monsters, currentTarget) then
        -- Chase keeps the current monster until it dies or leaves the screen.
        -- Re-evaluating distance priorities every tick would switch targets
        -- while the client is trying to pursue the first one.
        return
    end
    local adjacent = getAdjacentMonsters(monsters, playerPosition)
    local candidates
    local partyHunt=explorer and explorer.PartyHuntV2
    local leaderTarget=partyHunt and partyHunt.getLeaderTarget and partyHunt.getLeaderTarget()
    if containsCreature(monsters,leaderTarget) then
        candidates={leaderTarget}
    elseif autoAttackMode == 'A' or autoAttackMode == 'F' or autoAttackMode == 'G' then
        candidates = #adjacent > 0 and adjacent or
            getDistanceGroup(monsters, playerPosition, false)
    elseif autoAttackMode == 'B' or autoAttackMode == 'H' or autoAttackMode == 'I' then
        candidates = getDistanceGroup(monsters, playerPosition, true)
    else
        candidates = monsters
    end
    if #candidates == 0 then return end

    -- A and B pick any creature from the winning distance group, then remain
    -- stable while that creature still belongs to the same priority group.
    if (autoAttackMode == 'A' or autoAttackMode == 'B') and containsCreature(candidates, currentTarget) then
        return
    end

    local best
    if autoAttackMode == 'A' or autoAttackMode == 'B' then
        -- Preserve an unconfirmed random choice so a server cancellation
        -- cannot make the 50 ms loop choose different IDs and flood packets.
        for _, candidate in ipairs(candidates) do
            if candidate:getId() == lastAutoAttackTargetId then
                best = candidate
                break
            end
        end
        if not best then best = candidates[math.random(1, #candidates)] end
    else
        for _, monster in ipairs(candidates) do
            if isBetterAutoAttackTarget(monster, best, candidates, playerPosition) then best = monster end
        end
    end
    if not best then return end

    -- C-I continuously enforce their priority, including after a
    -- manual click. A and B were handled above by distance-group membership.
    if currentTarget and currentTarget:getId() == best:getId() then return end

    local now = g_clock.millis()
    -- Selection runs every 50 ms, but an identical unconfirmed request is
    -- throttled so the Helper cannot flood the server.
    local minimumDelay
    if lastAutoAttackTargetId == best:getId() then
        minimumDelay = AUTO_ATTACK_RETRY_INTERVAL
    else
        -- A genuinely different target is sent immediately.
        minimumDelay = AUTO_ATTACK_NEW_TARGET_INTERVAL
    end
    if now - lastAutoAttackPacketAt < minimumDelay then return end

    lastAutoAttackTargetId = best:getId()
    lastAutoAttackPacketAt = now
    g_game.attack(best)
end

local function getOrderedAttackSpellSlots()
    local profile = getVocationProfile()
    local count = profile and ATTACK_SPELL_SLOT_COUNTS[profile.key] or 0
    local ordered = {}
    for i = 1, count do
        local slot = helperWindow:recursiveGetChildById('attackSpellSlot' .. i)
        if slot then ordered[#ordered + 1] = { slot = slot, index = i } end
    end
    table.sort(ordered, function(a, b)
        local aPriority, bPriority = a.slot.attackPriority or a.index, b.slot.attackPriority or b.index
        if aPriority ~= bPriority then return aPriority < bPriority end
        return a.index < b.index
    end)
    return ordered
end

-- Position planning reads the Shooter's configured rotation and all server
-- cooldowns. Casting still goes through checkAttackRotation and all its gates.
function getPartyHuntSpellPlan()
    if isManualActionPending() then return nil end
    if not attackRotationEnabled or not helperWindow or not g_game.isOnline() then return nil end
    local explorer=modules.game_baiakeros_helper_v2
    local party=explorer and explorer.PartyHuntV2
    if party and party.isRunesOnly and party.isRunesOnly() then return nil end
    local player = g_game.getLocalPlayer()
    if not player then return nil end
    local ordered = getOrderedAttackSpellSlots()
    local now, manaPercent = g_clock.millis(), getManaPercent(player)
    local monsters=getVisibleMonsters(player:getPosition())
    local target=g_game.getAttackingCreature()
    for _,entry in ipairs(ordered) do
        local slot, spell = entry.slot, entry.slot.assignedAttackSpell
        if spell and slot.attackEnabled ~= false and manaPercent >= (slot.attackMinMana or 0) and
            (spell.mana or 0) <= player:getMana() and isAttackSpellAvailable(spell, player, currentVocation) and
            hasRequiredAttackSpellHarmony(spell, player) and
            #monsters >= (slot.attackMinEnemies or 1) and (not spell.needTarget or target) and
            (not isSingleTargetAttackSpell(spell) or slot.attackAllowMultiple==true or #monsters==1) then
            local profile = getAttackSpellProfile(spell.words)
            if isSpellCooldownReady(spell, now) then
                local affected=getSpellAffectedMonsters(spell,monsters,player,player:getPosition(),target)
                return { words = spell.words, id = spell.id, profile = profile,
                    beamMastery = spell.words=='exevo gran vis lux' and profile and profile.area=='beamMastery10' or false,
                    offsets = profile and ATTACK_DIRECTIONAL_AREAS[profile.area],
                    minEnemies = slot.attackMinEnemies or 1, ready = true,
                    needTarget = spell.needTarget == true, targetPosition = target and target:getPosition(),
                    castRange = profile and (profile.castRange or profile.range) or spell.range or 7,
                    canCastHere = #affected >= (slot.attackMinEnemies or 1) }
            end
        end
    end
    return nil
end

local function checkAttackRotation()
    if isManualActionPending() then return end
    if not attackRotationEnabled or not g_game.isOnline() then return end
    local player = g_game.getLocalPlayer()
    if not player or player:isDead() then return end
    if isInProtectionZone(player) then return end
    local playerPosition = player:getPosition()
    if not playerPosition then return end
    local monsters = getVisibleMonsters(playerPosition)
    if #monsters == 0 then return end
    -- Support lure spells belong to the Shooter, not to Cavebot movement.
    if checkShooterLureSpell(player, monsters, playerPosition) then return end
    local explorer = modules.game_baiakeros_helper_v2
    local singleTargetOnly = explorer and explorer.isSingleTargetExplorerHunt and
        explorer.isSingleTargetExplorerHunt()
    local now = g_clock.millis()
    if not isCooldownReady(spellGroupCooldownsById, 1, now) then return end
    local manaPercent = getManaPercent(player)
    local target = g_game.getAttackingCreature()
    local profile = getVocationProfile()
    local partyHunt = explorer and explorer.PartyHuntV2
    local runesOnly=partyHunt and partyHunt.isRunesOnly and partyHunt.isRunesOnly()
    -- The highest ready priority also owns Party Hunt movement. Do not fire a
    -- lower spell or a rune while it is waiting for its position/confirmed turn.
    local partyPlan=partyHunt and partyHunt.isFollowing and partyHunt.isFollowing() and getPartyHuntSpellPlan()
    local orderedSpellSlots = not runesOnly and getOrderedAttackSpellSlots() or {}
    for _,entry in ipairs(orderedSpellSlots) do
        local slot = entry.slot
        if slot and slot.attackEnabled ~= false and
            manaPercent >= (slot.attackMinMana or 0) then
            local spell = slot.assignedAttackSpell
            local affectedMonsters, castDirection = getSpellAffectedMonsters(
                spell, monsters, player, playerPosition, target)
            local positioned = true
            if partyHunt and spell and isSpellCooldownReady(spell,now) then
                local partyDirection
                positioned, partyDirection = partyHunt.prepareSpell(spell)
                local area = spell and getAttackSpellProfile(spell.words)
                if positioned and partyDirection and area and area.shape=='directional' then
                    castDirection = partyDirection
                    affectedMonsters = getDirectionalAffectedMonsters(monsters, player,
                        playerPosition, area and area.area, partyDirection)
                end
            end
            local singleTarget = isSingleTargetAttackSpell(spell)
            local monstersInRange = singleTarget and
                getSingleTargetRangeMonsterCount(spell, monsters, playerPosition) or 0
            local singleTargetCondition = not singleTarget or
                (singleTargetOnly and monstersInRange >= 1) or
                (slot.attackAllowMultiple == true and monstersInRange >= 1) or
                (slot.attackAllowMultiple ~= true and monstersInRange == 1)
            if positioned and spell and (not partyPlan or partyPlan.words==spell.words) and
                (not singleTargetOnly or singleTarget) and
                #affectedMonsters >= (slot.attackMinEnemies or 1) and
                singleTargetCondition and
                isAttackSpellAvailable(spell, player, currentVocation) and
                hasRequiredAttackSpellHarmony(spell, player) and
                (spell.mana or 0) <= player:getMana() and
                isSpellCooldownReady(spell, now) and
                (not spell.needTarget or target) then
                if castDirection and player:getDirection() ~= castDirection then
                    if pendingAttackTurnDirection ~= castDirection or
                        now - lastAttackTurnAt >= ATTACK_TURN_RETRY_INTERVAL then
                        pendingAttackTurnDirection = castDirection
                        lastAttackTurnAt = now
                        g_game.turn(castDirection)
                    end
                    -- Wait for the server-confirmed direction before speaking;
                    -- otherwise the wave can still be cast in the old direction.
                    return
                end
                pendingAttackTurnDirection = nil
                g_game.talk(spell.words)
                -- The server packet replaces this short duplicate guard with
                -- the exact spell, primary and secondary group cooldowns.
                guardSpellCommand(spell, 1, now)
                -- Every selection restarts at priority one. A recovered first
                -- spell preempts later entries instead of waiting for a lap.
                if partyHunt then partyHunt.onSpellCast(spell) end
                return
            end
        end
    end

    if partyPlan then return end

    local runeSlotCount = profile and ATTACK_RUNE_SLOT_COUNTS[profile.key] or 0
    local orderedRuneSlots = {}
    for i = 1, runeSlotCount do
        local slot = helperWindow:recursiveGetChildById('attackRuneSlot' .. i)
        if slot then table.insert(orderedRuneSlots, { slot = slot, index = i }) end
    end
    table.sort(orderedRuneSlots, function(a, b)
        local aPriority = a.slot.attackPriority or a.index
        local bPriority = b.slot.attackPriority or b.index
        if aPriority ~= bPriority then return aPriority < bPriority end
        return a.index < b.index
    end)
    for _,entry in ipairs(orderedRuneSlots) do
        local slot = entry.slot
        if slot and slot.attackEnabled ~= false and
            manaPercent >= (slot.attackMinMana or 0) then
            local rune = slot.assignedAttackRune
            local affectedMonsters = getRuneAffectedMonsters(
                rune, monsters, playerPosition, target)
            if rune and (not singleTargetOnly or not rune.area) and
                #affectedMonsters >= (slot.attackMinEnemies or 1) and target then
                g_game.useInventoryItemWith(rune.id, target, -1)
                guardSpellCommand(nil, 1, now)
                return
            end
        end
    end
end

local function onAttackingCreatureChange(creature, oldCreature)
    if not autoAttackEnabled or not g_game.isOnline() then return end
    -- A user click on a different creature must not inherit the retry guard
    -- from the Helper's previous choice; priority may correct it immediately.
    if creature and lastAutoAttackTargetId and creature:getId() ~= lastAutoAttackTargetId then
        lastAutoAttackTargetId = nil
        lastAutoAttackPacketAt = 0
    end
    -- Some servers answer the death of the previous target with a sequence-0
    -- attack cancel. If that arrives just after we selected the next monster,
    -- it also clears the new local target. A dead/removed old target therefore
    -- releases the retry guard immediately. A cancellation of a living target
    -- keeps the guard, preventing rejection loops and packet flooding.
    if not creature and oldCreature then
        local oldPosition = oldCreature:getPosition()
        local removedPosition = not oldPosition or
            (oldPosition.x == 0 and oldPosition.y == 0 and oldPosition.z == 0)
        if oldCreature:isDead() or oldCreature:getHealthPercent() <= 0 or removedPosition then
            lastAutoAttackTargetId = nil
            lastAutoAttackPacketAt = 0
        end
    end
    if autoAttackWakeEvent then removeEvent(autoAttackWakeEvent) end
    autoAttackWakeEvent = scheduleEvent(function()
        autoAttackWakeEvent = nil
        checkAutoAttack()
    end, 1)
end

local function wakeAutoAttack()
    if not autoAttackEnabled or not g_game.isOnline() then return end
    if autoAttackWakeEvent then removeEvent(autoAttackWakeEvent) end
    autoAttackWakeEvent = scheduleEvent(function()
        autoAttackWakeEvent = nil
        checkAutoAttack()
    end, 1)
end

local function updateAutoAttackControls()
    if not helperWindow then return end
    local checkBox = helperWindow:recursiveGetChildById('autoAttackEnabledBox')
    local rotationCheckBox = helperWindow:recursiveGetChildById('attackRotationEnabledBox')
    local modeBox = helperWindow:recursiveGetChildById('autoAttackModeBox')
    local statusLabel = helperWindow:recursiveGetChildById('attackHelperStatusLabel')
    updatingAutoAttackControls = true
    if checkBox then checkBox:setChecked(autoAttackEnabled) end
    if rotationCheckBox then rotationCheckBox:setChecked(attackRotationEnabled) end
    if modeBox then
        modeBox:setCurrentOptionByData(autoAttackMode, true)
        modeBox:setTooltip(AUTO_ATTACK_MODES[autoAttackMode] or '')
    end
    updatingAutoAttackControls = false
    updateAttackPostureControls()
    if statusLabel then
        local enabled = autoAttackEnabled or attackRotationEnabled
        statusLabel:setText(enabled and 'Helper Status: Enabled' or
            'Helper Status: Disabled')
        statusLabel:setColor(enabled and '#78d878' or '#999999')
    end
end

function resetAttackAfkTimer()
    if (autoAttackEnabled or attackRotationEnabled) and g_game.isOnline() then
        ATTACK_AFK.trackingSince = g_clock.millis()
    else
        ATTACK_AFK.trackingSince = 0
    end
end

function checkAttackAfkTimeout()
    if not g_game.isOnline() then
        ATTACK_AFK.trackingSince = 0
        return false
    end

    local explorer = modules.game_baiakeros_helper_v2
    local cavebot = explorer and explorer.BaiakHelperExplorerV2
    local cavebotActive = cavebot and
        (cavebot.isCombatAutomationActive or cavebot.isAutoExplorerActive)
    -- An active, timed Cavebot session owns both combat switches. Reconcile
    -- them before the disabled/idle gates, including while standing to fight.
    if cavebotActive and cavebotActive() then
        if not autoAttackEnabled then setAutoAttackEnabled(true) end
        if not attackRotationEnabled then setAttackRotationEnabled(true) end
        ATTACK_AFK.trackingSince = g_clock.millis()
        return false
    end

    if not autoAttackEnabled and not attackRotationEnabled then
        ATTACK_AFK.trackingSince = 0
        return false
    end
    if explorer and explorer.PartyHuntV2 and explorer.PartyHuntV2.isActive() then
        ATTACK_AFK.trackingSince = g_clock.millis()
        return false
    end

    local now = g_clock.millis()
    if ATTACK_AFK.trackingSince == 0 then
        ATTACK_AFK.trackingSince = now
        return false
    end
    -- Both conditions prevent surprising shutdowns: the helper must have
    -- been active for two minutes and the user must have sent no real key or
    -- mouse press during the same period.
    if now - ATTACK_AFK.trackingSince < ATTACK_AFK.timeout or
        g_ui.getInputIdleMillis() < ATTACK_AFK.timeout then return false end

    autoAttackEnabled = false
    attackRotationEnabled = false
    ATTACK_AFK.trackingSince = 0
    lastAutoAttackTargetId = nil
    lastAutoAttackPacketAt = 0
    pendingAttackTurnDirection = nil
    lastAttackTurnAt = 0
    if g_game.getAttackingCreature() then g_game.cancelAttack() end
    g_settings.set(autoAttackEnabledConfigKey(), false)
    g_settings.set(attackRotationEnabledConfigKey(), false)
    g_settings.save()
    updateAutoAttackControls()
    showHelperNotification('Auto Target and Shooter disabled after 2 minutes without keyboard or mouse activity.', false)
    return true
end

local function onLocalPlayerStatesChange(player, states, oldStates)
    local explorer = modules.game_baiakeros_helper_v2
    local party = explorer and explorer.PartyHuntV2
    local partyActive = party and party.isActive() and party.onProtectionZoneChange
    if partyActive then party.onProtectionZoneChange() end
    if not isInProtectionZone(player, states) then return end

    if g_game.getAttackingCreature() then g_game.cancelAttack() end
    lastAutoAttackTargetId = nil
    lastAutoAttackPacketAt = 0
    pendingAttackTurnDirection = nil
    lastAttackTurnAt = 0

    if partyActive then return end

    if not autoAttackEnabled and not attackRotationEnabled then return end

    autoAttackEnabled = false
    attackRotationEnabled = false
    ATTACK_AFK.trackingSince = 0
    g_settings.set(autoAttackEnabledConfigKey(), false)
    g_settings.set(attackRotationEnabledConfigKey(), false)
    g_settings.save()
    updateAutoAttackControls()
end

function setAttackRotationEnabled(enabled)
    if updatingAutoAttackControls then return end
    local wasEnabled = attackRotationEnabled
    attackRotationEnabled = enabled == true and g_game.isOnline()
    if attackRotationEnabled and not wasEnabled then
        castSelectedAttackPostures()
    elseif not attackRotationEnabled and attackPostureCastEvent then
        removeEvent(attackPostureCastEvent)
        attackPostureCastEvent = nil
    end
    g_settings.set(attackRotationEnabledConfigKey(), attackRotationEnabled)
    g_settings.save()
    updateAutoAttackControls()
    resetAttackAfkTimer()
    local explorer=modules.game_baiakeros_helper_v2
    if explorer and explorer.PartyHuntV2 and explorer.PartyHuntV2.onCombatOptionChange then
        explorer.PartyHuntV2.onCombatOptionChange('shooter',enabled)
    end
end

function setAutoAttackEnabled(enabled)
    if updatingAutoAttackControls then return end
    autoAttackEnabled = enabled == true and g_game.isOnline()
    lastAutoAttackTargetId = nil
    lastAutoAttackPacketAt = 0
    g_settings.set(autoAttackEnabledConfigKey(), autoAttackEnabled)
    g_settings.save()
    updateAutoAttackControls()
    resetAttackAfkTimer()
    local explorer=modules.game_baiakeros_helper_v2
    if explorer and explorer.PartyHuntV2 and explorer.PartyHuntV2.onCombatOptionChange then
        explorer.PartyHuntV2.onCombatOptionChange('auto',enabled)
    end
end

function setAutoAttackMode(mode)
    if updatingAutoAttackControls or not AUTO_ATTACK_MODES[mode] then return end
    autoAttackMode = mode
    lastAutoAttackTargetId = nil
    lastAutoAttackPacketAt = 0
    g_settings.set(autoAttackModeConfigKey(), autoAttackMode)
    g_settings.save()
    updateAutoAttackControls()
end

-- Restore the user's choices even when logout has already made setters offline.
function restorePartyCombatState(state)
    setAutoAttackEnabled(state.auto)
    setAttackRotationEnabled(state.shooter)
    if not g_game.isOnline() then
        g_settings.set(autoAttackEnabledConfigKey(),state.auto==true)
        g_settings.set(attackRotationEnabledConfigKey(),state.shooter==true)
        g_settings.save()
    end
end

function refreshHelperPresetBox()
    local box = helperWindow and helperWindow:recursiveGetChildById('helperPresetBox')
    if not box then return end
    updatingHelperPreset = true
    box:clearOptions()
    for _, name in ipairs(helperPresetNames) do
        box:addOption(name, presetId(name))
    end
    box:setCurrentOptionByData(helperPreset, true)
    updatingHelperPreset = false
end

function loadHelperPresetState()
    local migrationKey = playerConfigPrefix() .. '_preset_storage_v1'
    if not g_settings.getBoolean(migrationKey, false) then
        local defaultPrefix = helperConfigPrefix('default')
        g_settings.set(defaultPrefix .. '_auto_reconnect',
            g_settings.getBoolean('autoReconnect', false))
        g_settings.set(defaultPrefix .. '_auto_eat_food',
            g_settings.getBoolean('baiakeros_helper_auto_eat_food', false))
        g_settings.set(migrationKey, true)
        g_settings.save()
    end
    helperPresetNames = normalizePresetNames(
        g_settings.getList(helperPresetNamesConfigKey()))
    helperPreset = presetId(g_settings.getString(
        currentHelperPresetConfigKey(), 'default'))
    if not findPresetName(helperPresetNames, helperPreset) then
        helperPreset = 'default'
    end
    refreshHelperPresetBox()
    loadAttackPresetState()
end

function restoreCurrentHelperPreset()
    closeSelector()
    nextPotionAt = 0
    nextFriendHealingAt = 0
    lastAutoAttackTargetId = nil
    lastAutoAttackPacketAt = 0
    AUTO_HASTE.nextAt = 0
    resetExerciseRuntime()

    restoreSlots()
    restoreFriendSlots()
    loadAttackPresetState()
    restoreAttackSlots()

    local defaultHealing = helperPreset == 'default'
    healingEnabled = currentVocation ~= nil and
        g_settings.getBoolean(enabledConfigKey(), defaultHealing)
    autoAttackEnabled = g_settings.getBoolean(autoAttackEnabledConfigKey(), false)
    attackRotationEnabled = g_settings.getBoolean(
        attackRotationEnabledConfigKey(), autoAttackEnabled)
    autoAttackMode = g_settings.getString(autoAttackModeConfigKey(), 'A')
    if not AUTO_ATTACK_MODES[autoAttackMode] then autoAttackMode = 'A' end

    updateEnabledCheckBox()
    updateAutoAttackControls()
    updateExtrasControls()
    refreshHelperPresetBox()

    if healingEnabled then
        setStatus('Automatic healing active', '#78d878')
    elseif currentVocation then
        setStatus('Automatic healing disabled', '#d8b878')
    else
        setStatus('Unsupported vocation', '#d88878')
    end
end

function setHelperPreset(selectedPreset)
    if updatingHelperPreset or not selectedPreset then return end
    selectedPreset = presetId(selectedPreset)
    if selectedPreset == helperPreset or
        not findPresetName(helperPresetNames, selectedPreset) then return end
    helperPreset = selectedPreset
    g_settings.set(currentHelperPresetConfigKey(), helperPreset)
    g_settings.save()
    restoreCurrentHelperPreset()
    showHelperNotification('Helper Preset: ' ..
        (findPresetName(helperPresetNames, helperPreset) or 'Default'), true)
end

function removeAttackPresetData(selectedAttackPreset, selectedHelperPreset)
    local previousHelperPreset = helperPreset
    local previousAttackPreset = attackPreset
    helperPreset = selectedHelperPreset or helperPreset
    attackPreset = selectedAttackPreset
    for i = 1, 6 do
        local key = attackConfigKey('attackSpellSlot' .. i)
        g_settings.remove(key)
        g_settings.remove(key .. '_kind')
        g_settings.remove(key .. '_id')
    end
    for i = 1, ATTACK_RUNE_WIDGET_COUNT do
        local key = attackConfigKey('attackRuneSlot' .. i)
        g_settings.remove(key)
        g_settings.remove(key .. '_kind')
        g_settings.remove(key .. '_id')
    end
    g_settings.remove(attackPostureConfigKey('stance'))
    g_settings.remove(attackPostureConfigKey('passive'))
    g_settings.remove(attackConfigKey('lureSpell'))
    helperPreset = previousHelperPreset
    attackPreset = previousAttackPreset
end

function removeHelperPresetData(selectedPreset)
    local prefix = helperConfigPrefix(selectedPreset)
    for i = 1, 3 do
        g_settings.remove(prefix .. '_spellSlot' .. i)
        g_settings.remove(prefix .. '_potionSlot' .. i)
    end
    for _, slotPrefix in ipairs({ 'friendSlot', 'massFriendSlot' }) do
        for i = 1, 2 do
            g_settings.remove(prefix .. '_' .. slotPrefix .. i)
        end
    end
    for _, suffix in ipairs({
        '_healing_enabled_v2', '_auto_attack_enabled',
        '_attack_rotation_enabled', '_auto_attack_mode', '_auto_haste_enabled',
        '_auto_haste_spell', '_auto_haste_in_protection_zone',
        '_auto_reconnect', '_auto_eat_food'
    }) do
        g_settings.remove(prefix .. suffix)
    end

    local names = normalizePresetNames(
        g_settings.getList(attackPresetNamesConfigKey(selectedPreset)))
    for _, name in ipairs(names) do
        removeAttackPresetData(presetId(name), selectedPreset)
    end
    g_settings.remove(attackPresetNamesConfigKey(selectedPreset))
    g_settings.remove(prefix .. '_attack_preset')
end

function openPresetNameWindow(kind)
    if kind ~= 'helper' and kind ~= 'attack' then return end
    if presetNameWindow then presetNameWindow:destroy() end
    presetNameKind = kind
    presetNameWindow = g_ui.createWidget('HelperPresetNameWindow', rootWidget)
    presetNameWindow:setText(kind == 'helper' and
        'New Helper Preset' or 'New Attack Preset')
    presetNameWindow.infoLabel:setText(
        'Use 1-10 letters or numbers:')
    presetNameWindow.nameEdit:setText('')
    presetNameWindow.nameEdit:focus()
end

function closePresetNameWindow()
    if presetNameWindow then
        presetNameWindow:destroy()
        presetNameWindow = nil
    end
    presetNameKind = nil
end

function createPresetFromWindow()
    if not presetNameWindow or not presetNameKind then return end
    local name = presetNameWindow.nameEdit:getText():trim()
    if #name < 1 or #name > 10 or not name:match('^[%w]+$') then
        modules.game_textmessage.displayFailureMessage(
            'Preset name must contain 1-10 letters or numbers.')
        return
    end

    local names = presetNameKind == 'helper' and
        helperPresetNames or attackPresetNames
    if findPresetName(names, presetId(name)) then
        modules.game_textmessage.displayFailureMessage(
            'A preset with this name already exists.')
        return
    end

    local kind = presetNameKind
    table.insert(names, name)
    if kind == 'helper' then
        g_settings.setList(helperPresetNamesConfigKey(), helperPresetNames)
    else
        g_settings.setList(attackPresetNamesConfigKey(), attackPresetNames)
    end
    g_settings.save()
    closePresetNameWindow()

    if kind == 'helper' then
        setHelperPreset(presetId(name))
    else
        setAttackPreset(presetId(name))
        refreshAttackPresetBox()
    end
end

function deleteSelectedPreset(kind)
    if kind == 'helper' then
        local deletedPreset = helperPreset
        removeHelperPresetData(deletedPreset)
        for index, name in ipairs(helperPresetNames) do
            if presetId(name) == deletedPreset then
                table.remove(helperPresetNames, index)
                break
            end
        end
        helperPreset = 'default'
        g_settings.setList(helperPresetNamesConfigKey(), helperPresetNames)
        g_settings.set(currentHelperPresetConfigKey(), helperPreset)
        g_settings.save()
        restoreCurrentHelperPreset()
        showHelperNotification('Helper Preset: Default', true)
    else
        local deletedPreset = attackPreset
        removeAttackPresetData(deletedPreset)
        for index, name in ipairs(attackPresetNames) do
            if presetId(name) == deletedPreset then
                table.remove(attackPresetNames, index)
                break
            end
        end
        attackPreset = 'default'
        g_settings.setList(attackPresetNamesConfigKey(), attackPresetNames)
        g_settings.set(attackPresetConfigKey(), attackPreset)
        g_settings.save()
        restoreAttackSlots()
        refreshAttackPresetBox()
        showHelperNotification('Attack Preset: Default', true)
    end
end

function requestDeletePreset(kind)
    if kind ~= 'helper' and kind ~= 'attack' then return end
    local selected = kind == 'helper' and helperPreset or attackPreset
    if selected == 'default' then
        modules.game_textmessage.displayFailureMessage(
            'The Default preset cannot be deleted.')
        return
    end
    local names = kind == 'helper' and helperPresetNames or attackPresetNames
    local name = findPresetName(names, selected) or selected
    if presetDeleteWindow then presetDeleteWindow:destroy() end
    local yesCallback = function()
        if presetDeleteWindow then
            presetDeleteWindow:destroy()
            presetDeleteWindow = nil
        end
        deleteSelectedPreset(kind)
    end
    local noCallback = function()
        if presetDeleteWindow then
            presetDeleteWindow:destroy()
            presetDeleteWindow = nil
        end
    end
    presetDeleteWindow = displayGeneralBox('Delete Preset',
        string.format("Delete preset '%s'?", name), {
            { text = 'Yes', callback = yesCallback },
            { text = 'No', callback = noCallback },
            anchor = AnchorHorizontalCenter
        }, yesCallback, noCallback)
end

local function toggleHealingHotkey()
    if not g_game.isOnline() then return end
    setHealingEnabled(not healingEnabled)
    showHelperNotification((healingEnabled and
        'Enable Healing' or 'Disable Healing') .. ' - ' ..
        helperPresetNotificationSuffix(false), healingEnabled)
end

local function toggleAutoTargetHotkey()
    if not g_game.isOnline() then return end
    setAutoAttackEnabled(not autoAttackEnabled)
    showHelperNotification((autoAttackEnabled and
        'Enable Auto Target' or 'Disable Auto Target') .. ' - ' ..
        helperPresetNotificationSuffix(true), autoAttackEnabled)
end

local function toggleShooterHotkey()
    if not g_game.isOnline() then return end
    setAttackRotationEnabled(not attackRotationEnabled)
    showHelperNotification((attackRotationEnabled and
        'Enable Shooter' or 'Disable Shooter') .. ' - ' ..
        helperPresetNotificationSuffix(true), attackRotationEnabled)
end

local function toggleAttackHelpersHotkey()
    if not g_game.isOnline() then return end
    -- If both are already active the combined key disables both. In every
    -- other state it enables both, making the action deterministic.
    local enabled = not (autoAttackEnabled and attackRotationEnabled)
    setAutoAttackEnabled(enabled)
    setAttackRotationEnabled(enabled)
    showHelperNotification((enabled and
        'Enable Auto Target + Shooter' or
        'Disable Auto Target + Shooter') .. ' - ' ..
        helperPresetNotificationSuffix(true), enabled)
end

function cycleHelperPresetHotkey()
    if not g_game.isOnline() then return end
    setHelperPreset(nextPresetId(helperPresetNames, helperPreset))
end

function cycleAttackPresetHotkey()
    if not g_game.isOnline() then return end
    setAttackPreset(nextPresetId(attackPresetNames, attackPreset))
end

local function registerHelperHotkeys()
    local callbacks = {
        [HELPER_HOTKEY_ACTIONS.healing] = toggleHealingHotkey,
        [HELPER_HOTKEY_ACTIONS.autoTarget] = toggleAutoTargetHotkey,
        [HELPER_HOTKEY_ACTIONS.shooter] = toggleShooterHotkey,
        [HELPER_HOTKEY_ACTIONS.both] = toggleAttackHelpersHotkey,
        [HELPER_HOTKEY_ACTIONS.helperPreset] = cycleHelperPresetHotkey,
        [HELPER_HOTKEY_ACTIONS.attackPreset] = cycleAttackPresetHotkey
    }

    for action, callback in pairs(callbacks) do
        Keybind.new(HELPER_HOTKEY_CATEGORY, action, '', '')
        Keybind.bind(HELPER_HOTKEY_CATEGORY, action, {
            { type = KEY_DOWN, callback = callback }
        })
    end
end

local function unregisterHelperHotkeys()
    for _, action in pairs(HELPER_HOTKEY_ACTIONS) do
        Keybind.delete(HELPER_HOTKEY_CATEGORY, action)
    end
end

function setHelperHotkey(action)
    local validAction = false
    for _, registeredAction in pairs(HELPER_HOTKEY_ACTIONS) do
        if registeredAction == action then
            validAction = true
            break
        end
    end
    if not validAction then return end
    local keybind = Keybind.getAction(HELPER_HOTKEY_CATEGORY, action)
    if not keybind or not modules.client_options then return end
    modules.client_options.editKeybindActionPrimary(
        HELPER_HOTKEY_CATEGORY, action, Keybind.chatMode)
end

local function onSpellGroupCooldown(groupId, duration)
    groupId = tonumber(groupId)
    duration = math.max(0, tonumber(duration) or 0)
    if not groupId then return end
    -- This is an authoritative snapshot. Assignment is intentional: Wheel,
    -- Momentum and proficiency can send a shorter remaining cooldown.
    spellGroupCooldownsById[groupId] = duration > 0 and
        g_clock.millis() + duration or 0
    updateAttackPostureControls()
end

local function onSpellCooldown(iconId, duration)
    local spellId = tonumber(iconId)
    duration = math.max(0, tonumber(duration) or 0)
    if not spellId then return end
    spellCooldownsById[spellId] = duration > 0 and
        g_clock.millis() + duration or 0
    updateAttackPostureControls()
end

local function refreshAttackLayout()
    if not helperWindow then return end
    local profile = getVocationProfile()
    local spellCount = profile and ATTACK_SPELL_SLOT_COUNTS[profile.key] or 0
    local runeCount = profile and ATTACK_RUNE_SLOT_COUNTS[profile.key] or 0
    local spellPanel = helperWindow:recursiveGetChildById('spellShooterPanel')
    local spellSlotsPanel = helperWindow:recursiveGetChildById('attackSpellSlotsPanel')
    local runePanel = helperWindow:recursiveGetChildById('runeShooterPanel')
    local runeSlotsPanel = helperWindow:recursiveGetChildById('attackRuneSlotsPanel')
    if spellSlotsPanel then spellSlotsPanel:setHeight(spellCount * 38) end
    if spellPanel then spellPanel:setHeight(48 + spellCount * 38) end
    if runeSlotsPanel then runeSlotsPanel:setHeight(runeCount * 38) end
    if runePanel then
        runePanel:setHeight(48 + runeCount * 38)
        runePanel:setVisible(runeCount > 0)
    end
end

local function refreshCharacterState()
    currentVocation = detectVocation()
    local player = g_game.getLocalPlayer()
    local vocationLabel = helperWindow:recursiveGetChildById('vocationLabel')
    local headerVocationLabel = helperWindow:recursiveGetChildById('headerVocationLabel')
    local characterNameLabel = helperWindow:recursiveGetChildById('characterNameLabel')
    local outfitPreview = helperWindow:recursiveGetChildById('outfitPreview')
    local supported = currentVocation ~= nil
    local profile = getVocationProfile()
    refreshAttackLayout()

    if supported then
        helperWindow:setText('BaiakEros Helper - ' .. currentVocation.name)
        vocationLabel:setText(currentVocation.name)
        if headerVocationLabel then headerVocationLabel:setText(currentVocation.name) end
        characterNameLabel:setText(player:getName())
        outfitPreview:setOutfit(player:getOutfit())
    else
        helperWindow:setText('BaiakEros Helper - Unsupported vocation')
        vocationLabel:setText('Unsupported vocation')
        if headerVocationLabel then headerVocationLabel:setText('Unsupported vocation') end
        characterNameLabel:setText(player and player:getName() or 'Offline')
    end

    for i = 1, 3 do
        helperWindow:recursiveGetChildById('spellSlot' .. i).assignButton:setEnabled(supported)
        helperWindow:recursiveGetChildById('potionSlot' .. i).assignButton:setEnabled(supported)
    end

    local friendPanel = helperWindow:recursiveGetChildById('friendHealingPanel')
    local massFriendPanel = helperWindow:recursiveGetChildById('massFriendHealingPanel')
    local configurationPanel = helperWindow:recursiveGetChildById('configurationPanel')
    local friendSlot2 = helperWindow:recursiveGetChildById('friendSlot2')
    local singleFriendSlot = profile and profile.friendSlotCount == 1 or false
    if friendPanel then
        friendPanel:setVisible(profile and profile.friendHealing or false)
        friendPanel:setHeight(singleFriendSlot and 120 or 138)
    end
    if friendSlot2 then friendSlot2:setVisible(not singleFriendSlot) end
    if massFriendPanel then
        massFriendPanel:setVisible(profile and profile.massFriendHealing or false)
    end
    local friendModeLabel = helperWindow:recursiveGetChildById('friendModeLabel')
    if friendModeLabel and profile then
        friendModeLabel:setText(profile.friendLabel or 'Friend Healing')
    end
    -- The frame, logo, tabs and footer never move. Switching tabs replaces
    -- only the central page, matching the compact Rubinot-style helper.
    local helperHeight = getHelperWindowHeight(profile, currentHelperTab)
    helperWindow:setWidth(currentHelperTab == 'attack' and
        HELPER_ATTACK_WIDTH or HELPER_WINDOW_WIDTH)
    helperWindow:setHeight(helperHeight)
    if configurationPanel then
        configurationPanel:setHeight(230)
    end
end

function showHelperTab(tabName)
    if not helperWindow then return end
    local healingPage = helperWindow:recursiveGetChildById('healingPage')
    local attackPage = helperWindow:recursiveGetChildById('attackPage')
    local extrasPage = helperWindow:recursiveGetChildById('extrasPage')
    local healingTab = helperWindow:recursiveGetChildById('healingTabButton')
    local attackTab = helperWindow:recursiveGetChildById('attackTabButton')
    local extrasTab = helperWindow:recursiveGetChildById('extrasTabButton')
    local helperPresetPanel = helperWindow:recursiveGetChildById('helperPresetPanel')
    local attackPresetPanel = helperWindow:recursiveGetChildById('attackPresetPanel')
    local showAttack = tabName == 'attack'
    local showExtras = tabName == 'extras'
    local showHealing = not showAttack and not showExtras
    currentHelperTab = showAttack and 'attack' or (showExtras and 'extras' or 'healing')
    healingPage:setVisible(showHealing)
    attackPage:setVisible(showAttack)
    extrasPage:setVisible(showExtras)
    helperPresetPanel:setVisible(showHealing)
    attackPresetPanel:setVisible(showAttack)
    local function updateTab(button, selected)
        button:setOn(selected)
    end
    updateTab(healingTab, showHealing)
    updateTab(attackTab, showAttack)
    updateTab(extrasTab, showExtras)
    if showExtras then updateExtrasControls() end
    local profile = getVocationProfile()
    helperWindow:setWidth(showAttack and HELPER_ATTACK_WIDTH or HELPER_WINDOW_WIDTH)
    helperWindow:setHeight(getHelperWindowHeight(profile, currentHelperTab))
end

local function online()
    manualSpellPriorityUntil,manualItemPriorityUntil=0,0
    nextPotionAt = 0
    nextFriendHealingAt = 0
    lastPartyRefreshAt = 0
    spellCooldownsById = {}
    spellGroupCooldownsById = {}
    lastAutoAttackTargetId = nil
    lastAutoAttackPacketAt = 0
    pendingAttackTurnDirection = nil
    lastAttackTurnAt = 0
    AUTO_HASTE.nextAt = 0
    -- Mana Training remains login-only. Exercise Training is retained in
    -- memory per character until the client process closes, so reconnect can
    -- resume an enabled exercise weapon automatically.
    MANA_TRAINING.nextAt = 0
    MANA_TRAINING.selectedSpell = nil
    MANA_TRAINING.enabled = false
    MANA_TRAINING.threshold = 90
    refreshCharacterState()
    restoreExerciseTrainingSession()
    loadHelperPresetState()
    startExtrasToggleResetMigration()
    local player = g_game.getLocalPlayer()
    logVocationDiagnostic('online')
    partySessionActive = player ~= nil and player:isPartyMember()
    restoreSlots()
    restoreFriendSlots()
    if not partySessionActive then resetPartyHealingState() end
    restoreAttackSlots()
    healingEnabled = currentVocation ~= nil and
        g_settings.getBoolean(enabledConfigKey(), helperPreset == 'default')
    autoAttackEnabled = g_settings.getBoolean(autoAttackEnabledConfigKey(), false)
    -- Existing users keep the old combined behavior until they explicitly
    -- choose independent settings in the redesigned Attack page.
    attackRotationEnabled = g_settings.getBoolean(
        attackRotationEnabledConfigKey(), autoAttackEnabled)
    autoAttackMode = g_settings.getString(autoAttackModeConfigKey(), 'A')
    if not AUTO_ATTACK_MODES[autoAttackMode] then autoAttackMode = 'A' end
    updateEnabledCheckBox()
    updateAutoAttackControls()
    updateExtrasControls()
    if player then onLocalPlayerStatesChange(player, player:getStates()) end
    resetAttackAfkTimer()
    if healingEnabled then
        setStatus('Automatic healing active', '#78d878')
    elseif currentVocation then
        setStatus('Automatic healing disabled', '#d8b878')
    else
        setStatus('Unsupported vocation', '#d88878')
    end
end

local function onLocalPlayerVocationChange(player, newVocation, oldVocation)
    logVocationDiagnostic('signal', newVocation, oldVocation)
    online()
end

local function offline()
    manualSpellPriorityUntil,manualItemPriorityUntil=0,0
    cancelExtrasToggleReset()
    if attackPostureCastEvent then
        removeEvent(attackPostureCastEvent)
        attackPostureCastEvent = nil
    end
    if attackPostureCooldownEvent then
        removeEvent(attackPostureCooldownEvent)
        attackPostureCooldownEvent = nil
    end
    saveExerciseTrainingSession()
    healingEnabled = false
    autoAttackEnabled = false
    attackRotationEnabled = false
    ATTACK_AFK.trackingSince = 0
    nextPotionAt = 0
    nextFriendHealingAt = 0
    selectedPartyMember = nil
    partyMemberRows = {}
    selectedMassPartyMember = nil
    massPartyMemberRows = {}
    partySessionActive = false
    spellCooldownsById = {}
    spellGroupCooldownsById = {}
    lastAutoAttackTargetId = nil
    lastAutoAttackPacketAt = 0
    pendingAttackTurnDirection = nil
    lastAttackTurnAt = 0
    nextAutoEatAt = 0
    AUTO_HASTE.nextAt = 0
    AUTO_HASTE.selectedSpell = nil
    MANA_TRAINING.nextAt = 0
    MANA_TRAINING.selectedSpell = nil
    MANA_TRAINING.enabled = false
    MANA_TRAINING.threshold = 90
    resetExerciseRuntime()
    if autoAttackWakeEvent then
        removeEvent(autoAttackWakeEvent)
        autoAttackWakeEvent = nil
    end
    closeSelector()
    hide()
end

function show()
    local helperV2 = modules.game_baiakeros_helper_v2
    if helperV2 and helperV2.show then helperV2.show() end
end

function hide()
    closeSelector()
    helperWindow:hide()
    local helperV2 = modules.game_baiakeros_helper_v2
    if helperV2 and helperV2.hide then helperV2.hide() end
    setHelperButtonOn(false)
end

function toggle()
    local helperV2 = modules.game_baiakeros_helper_v2
    if helperV2 and helperV2.toggle then helperV2.toggle() end
end

function setHelperButtonOn(enabled)
    if helperButton then helperButton:setOn(enabled) end
end

function init()
    g_ui.importStyle('helper')
    helperWindow = g_ui.createWidget('BaiakerosHelperWindow', rootWidget)
    -- Keep the old window for comparison while V2 owns all configuration input.
    local readOnlyOverlay = helperWindow:recursiveGetChildById('legacyReadOnlyOverlay')
    readOnlyOverlay.onMousePress = function() return true end
    readOnlyOverlay.onMouseRelease = function() return true end
    readOnlyOverlay.onMouseWheel = function() return true end
    local notificationParent = modules.game_interface.getMapPanel() or rootWidget
    helperNotification = g_ui.createWidget(
        'HelperToggleNotification', notificationParent)
    helperNotification:hide()
    assignmentGrabber = g_ui.createWidget('UIWidget')
    assignmentGrabber:setVisible(false)
    assignmentGrabber:setFocusable(false)
    assignmentGrabber.onMousePress = function(self, mousePosition, mouseButton)
        -- Store Inbox items may begin their own drag handling before mouse
        -- release. Accept the assignment on press so the grabbed selection
        -- cannot be lost to the container widget.
        if assigningHelperItem then return finishHelperItemAssignment(mousePosition, mouseButton) end
        if assigningExerciseWeapon then
            return finishExerciseWeaponAssignment(mousePosition, mouseButton)
        end
        if assigningPotionSlot then
            return finishPotionAssignment(mousePosition, mouseButton)
        end
        return true
    end
    assignmentGrabber.onMouseRelease = function(self, mousePosition, mouseButton)
        if assigningHelperItem then return finishHelperItemAssignment(mousePosition, mouseButton) end
        if assigningExerciseWeapon then
            return finishExerciseWeaponAssignment(mousePosition, mouseButton)
        end
        if assigningPotionSlot then
            return finishPotionAssignment(mousePosition, mouseButton)
        end
        return true
    end
    assignmentGrabber.onMouseMove = function()
        keepAssignmentCursor()
        return true
    end

    -- Apply once on press, then keep stepping while the left mouse button is
    -- held. This is shared by every arrow-based percentage field.
    local function bindPercentAutoRepeat(button, callback)
        if not button then return end
        button.onClick = nil
        g_mouse.bindAutoPress(button, function()
            if button:isEnabled() then callback() end
        end, 350, MouseLeftButton, 80)
    end

    for i = 1, 3 do
        local spellSlot = helperWindow:recursiveGetChildById('spellSlot' .. i)
        local potionSlot = helperWindow:recursiveGetChildById('potionSlot' .. i)
        local currentSpellSlot = spellSlot
        local currentPotionSlot = potionSlot
        spellSlot.assignButton.onMouseRelease = function(_, mousePosition, mouseButton)
            return showSpellMenu(currentSpellSlot:getId(), mousePosition, mouseButton)
        end
        potionSlot.assignButton.onMouseRelease = function(_, mousePosition, mouseButton)
            return showPotionMenu(currentPotionSlot:getId(), mousePosition, mouseButton)
        end
        -- UIItem is rendered above the assignment button.  Handle the
        -- context click on it explicitly so an assigned potion can always
        -- be changed or cleared, just like an assigned spell.
        potionSlot.itemIcon:setPhantom(false)
        potionSlot.itemIcon.onMouseRelease = function(_, mousePosition, mouseButton)
            return showPotionMenu(currentPotionSlot:getId(), mousePosition, mouseButton)
        end
        bindPercentAutoRepeat(spellSlot.decreaseButton, function()
            changeThreshold(currentSpellSlot:getId(), -1)
        end)
        bindPercentAutoRepeat(spellSlot.increaseButton, function()
            changeThreshold(currentSpellSlot:getId(), 1)
        end)
        bindPercentAutoRepeat(potionSlot.decreaseButton, function()
            changeThreshold(currentPotionSlot:getId(), -1)
        end)
        bindPercentAutoRepeat(potionSlot.increaseButton, function()
            changeThreshold(currentPotionSlot:getId(), 1)
        end)
    end
    for i = 1, 2 do
        local friendSlot = helperWindow:recursiveGetChildById('friendSlot' .. i)
        local currentFriendSlot = friendSlot
        friendSlot.addButton.onClick = function()
            assignFriendSlot(currentFriendSlot:getId())
        end
        friendSlot.clearButton.onClick = function()
            clearFriendSlot(currentFriendSlot:getId())
        end
        local friendThresholdBox = friendSlot:recursiveGetChildById('thresholdBox')
        for threshold = 5, 95, 5 do
            friendThresholdBox:addOption(string.format('%d%%', threshold), threshold)
        end
        friendThresholdBox.onOptionChange = function(_, _, threshold)
            setFriendThreshold(currentFriendSlot:getId(), threshold)
        end
        friendSlot.enableBox.onCheckChange = function(_, checked)
            setFriendEnabled(currentFriendSlot:getId(), checked)
        end

        local massFriendSlot = helperWindow:recursiveGetChildById('massFriendSlot' .. i)
        local currentMassFriendSlot = massFriendSlot
        massFriendSlot.addButton.onClick = function()
            assignMassFriendSlot(currentMassFriendSlot:getId())
        end
        massFriendSlot.clearButton.onClick = function()
            clearFriendSlot(currentMassFriendSlot:getId())
        end
        local massFriendThresholdBox = massFriendSlot:recursiveGetChildById('thresholdBox')
        for threshold = 5, 95, 5 do
            massFriendThresholdBox:addOption(string.format('%d%%', threshold), threshold)
        end
        massFriendThresholdBox.onOptionChange = function(_, _, threshold)
            setFriendThreshold(currentMassFriendSlot:getId(), threshold)
        end
        massFriendSlot.enableBox.onCheckChange = function(_, checked)
            setFriendEnabled(currentMassFriendSlot:getId(), checked)
        end
    end
    for i = 1, 6 do
        local attackSlot = helperWindow:recursiveGetChildById('attackSpellSlot' .. i)
        local currentAttackSlot = attackSlot
        attackSlot.attackSlotKind = 'spell'
        attackSlot.attackPriorityLabel:setText(tostring(i))
        attackSlot.attackAssignButton.onMouseRelease = function(_, mousePosition, mouseButton)
            return showAttackSpellSlotMenu(currentAttackSlot:getId(), mousePosition, mouseButton)
        end
        attackSlot.attackEnabledBox.onCheckChange = function(_, checked)
            setAttackSlotEnabled(currentAttackSlot:getId(), checked)
        end
        attackSlot.attackEnemiesDecrease.onClick = function()
            changeAttackEnemies(currentAttackSlot:getId(), -1)
        end
        attackSlot.attackEnemiesIncrease.onClick = function()
            changeAttackEnemies(currentAttackSlot:getId(), 1)
        end
        bindPercentAutoRepeat(attackSlot.attackManaDecrease, function()
            changeAttackMana(currentAttackSlot:getId(), -5)
        end)
        bindPercentAutoRepeat(attackSlot.attackManaIncrease, function()
            changeAttackMana(currentAttackSlot:getId(), 5)
        end)
        attackSlot.attackAllowMultipleBox.onCheckChange = function(_, checked)
            setAttackAllowMultiple(currentAttackSlot:getId(), checked)
        end
        local priorityBox = attackSlot:recursiveGetChildById('attackPriorityBox')
        priorityBox:addOption('1st', 1)
        priorityBox:addOption('2nd', 2)
        priorityBox:addOption('3rd', 3)
        priorityBox:addOption('4th', 4)
        priorityBox:addOption('5th', 5)
        priorityBox.onTextChange = function(widget)
            local option = widget:getCurrentOption()
            if option then setAttackPriority(currentAttackSlot:getId(), option.data) end
        end
    end
    for i = 1, ATTACK_RUNE_WIDGET_COUNT do
        local attackSlot = helperWindow:recursiveGetChildById('attackRuneSlot' .. i)
        local currentAttackSlot = attackSlot
        attackSlot.attackSlotKind = 'rune'
        attackSlot.attackPriorityLabel:setText(tostring(i))
        attackSlot.attackAssignButton.onMouseRelease = function(_, mousePosition, mouseButton)
            return showAttackRuneSlotMenu(currentAttackSlot:getId(), mousePosition, mouseButton)
        end
        -- The rendered rune is a UIItem above the slot button. Handle its
        -- context click directly so changing or removing it is reliable.
        attackSlot.attackItemIcon:setPhantom(false)
        attackSlot.attackItemIcon.onMouseRelease = function(_, mousePosition, mouseButton)
            return showAttackRuneSlotMenu(currentAttackSlot:getId(), mousePosition, mouseButton)
        end
        attackSlot.attackEnabledBox.onCheckChange = function(_, checked)
            setAttackSlotEnabled(currentAttackSlot:getId(), checked)
        end
        attackSlot.attackEnemiesDecrease.onClick = function()
            changeAttackEnemies(currentAttackSlot:getId(), -1)
        end
        attackSlot.attackEnemiesIncrease.onClick = function()
            changeAttackEnemies(currentAttackSlot:getId(), 1)
        end
        bindPercentAutoRepeat(attackSlot.attackManaDecrease, function()
            changeAttackMana(currentAttackSlot:getId(), -5)
        end)
        bindPercentAutoRepeat(attackSlot.attackManaIncrease, function()
            changeAttackMana(currentAttackSlot:getId(), 5)
        end)
        local priorityBox = attackSlot:recursiveGetChildById('attackPriorityBox')
        priorityBox:addOption('1st', 1)
        priorityBox:addOption('2nd', 2)
        priorityBox:addOption('3rd', 3)
        priorityBox:addOption('4th', 4)
        priorityBox:addOption('5th', 5)
        priorityBox.onTextChange = function(widget)
            local option = widget:getCurrentOption()
            if option then setAttackPriority(currentAttackSlot:getId(), option.data) end
        end
    end
    local autoAttackModeBox = helperWindow:recursiveGetChildById('autoAttackModeBox')
    updatingAutoAttackControls = true
    for mode = string.byte('A'), string.byte('I') do
        local letter = string.char(mode)
        autoAttackModeBox:addOption(letter, letter)
    end
    updatingAutoAttackControls = false
    local helperPresetBox = helperWindow:recursiveGetChildById('helperPresetBox')
    if helperPresetBox then
        helperPresetBox.onOptionChange = function(_, _, selectedPreset)
            setHelperPreset(selectedPreset)
        end
    end
    local attackPresetBox = helperWindow:recursiveGetChildById('attackPresetBox')
    if attackPresetBox then
        attackPresetBox.onOptionChange = function(_, _, selectedPreset)
            setAttackPreset(selectedPreset)
        end
    end
    for kind, buttonIds in pairs(ATTACK_POSTURE_BUTTON_IDS) do
        for index, buttonId in ipairs(buttonIds) do
            local button = helperWindow:recursiveGetChildById(buttonId)
            if button then
                local selectedKind = kind
                local selectedIndex = index
                button.onClick = function()
                    selectAttackPosture(selectedKind, selectedIndex)
                end
            end
        end
    end
    local autoReconnectBox = helperWindow:recursiveGetChildById('autoReconnectBox')
    local autoEatFoodBox = helperWindow:recursiveGetChildById('autoEatFoodBox')
    local autoHasteBox = helperWindow:recursiveGetChildById('autoHasteBox')
    local autoHasteSpellBox = helperWindow:recursiveGetChildById('autoHasteSpellBox')
    local autoHasteInPzBox = helperWindow:recursiveGetChildById('autoHasteInPzBox')
    local changeGoldBox = helperWindow:recursiveGetChildById('changeGoldBox')
    local flaskRemoverBox = helperWindow:recursiveGetChildById('flaskRemoverBox')
    local autolootBox = helperWindow:recursiveGetChildById('autolootBox')
    local lootPouchStoreButton = helperWindow:recursiveGetChildById(
        'lootPouchStoreButton')
    local exerciseWeaponSlot = helperWindow:recursiveGetChildById('exerciseWeaponSlot')
    local exerciseTrainingModeBox = helperWindow:recursiveGetChildById(
        'exerciseTrainingModeBox')
    local manaTrainingSlot = helperWindow:recursiveGetChildById('manaSpellTrainingSlot')
    local manaTrainingDecrease = helperWindow:recursiveGetChildById(
        'manaTrainingDecrease')
    local manaTrainingIncrease = helperWindow:recursiveGetChildById(
        'manaTrainingIncrease')
    local manaTrainingEnabledBox = helperWindow:recursiveGetChildById(
        'manaTrainingEnabledBox')
    if autoReconnectBox then
        autoReconnectBox.onCheckChange = function(_, checked)
            setAutoReconnectEnabled(checked)
        end
    end
    if autoEatFoodBox then
        autoEatFoodBox.onCheckChange = function(_, checked)
            setAutoEatFoodEnabled(checked)
        end
    end
    if autoHasteBox then
        autoHasteBox.onCheckChange = function(_, checked)
            setAutoHasteEnabled(checked)
        end
    end
    if autoHasteSpellBox then
        autoHasteSpellBox.onOptionChange = function(_, _, spellName)
            setAutoHasteSpell(spellName)
        end
    end
    if autoHasteInPzBox then
        autoHasteInPzBox.onCheckChange = function(_, checked)
            setAutoHasteInProtectionZone(checked)
        end
    end
    if changeGoldBox then
        changeGoldBox.onCheckChange = function(_, checked)
            setChangeGoldEnabled(checked)
        end
    end
    if flaskRemoverBox then
        flaskRemoverBox.onCheckChange = function(_, checked)
            setFlaskRemoverEnabled(checked)
        end
    end
    if autolootBox then
        autolootBox.onCheckChange = function(_, checked)
            setAutolootEnabled(checked)
        end
    end
    if lootPouchStoreButton then
        lootPouchStoreButton.onClick = openLootPouchStore
    end
    if exerciseWeaponSlot then
        exerciseWeaponSlot.assignButton.onMouseRelease = function(_, mousePosition, mouseButton)
            return handleExerciseWeaponSlotClick(mousePosition, mouseButton)
        end
        exerciseWeaponSlot.itemIcon:setPhantom(false)
        exerciseWeaponSlot.itemIcon.onMouseRelease = function(_, mousePosition, mouseButton)
            return handleExerciseWeaponSlotClick(mousePosition, mouseButton)
        end
    end
    if exerciseTrainingModeBox then
        exerciseTrainingModeBox:addOption('Disable', 'disable')
        exerciseTrainingModeBox:addOption('Enable', 'enable')
        exerciseTrainingModeBox.onOptionChange = function(_, _, mode)
            setExerciseTrainingEnabled(mode == 'enable')
        end
    end
    if manaTrainingSlot then
        manaTrainingSlot.assignButton.onMouseRelease = function(_, mousePosition, mouseButton)
            return handleManaTrainingSlotClick(mousePosition, mouseButton)
        end
    end
    bindPercentAutoRepeat(manaTrainingDecrease, function()
        changeManaTrainingThreshold(-5)
    end)
    bindPercentAutoRepeat(manaTrainingIncrease, function()
        changeManaTrainingThreshold(5)
    end)
    if manaTrainingEnabledBox then
        manaTrainingEnabledBox.onCheckChange = function(_, checked)
            setManaTrainingEnabled(checked)
        end
    end
    updateExtrasControls()
    registerHelperHotkeys()
    showHelperTab('healing')

    helperButton = modules.game_mainpanel.addCompactStoreButton('baiakerosHelperButton',
        tr('Baiakeros Helper'), '/images/options/blue_large', toggle, 1,
        nil, '/images/topbuttons/bot')
    helperButton:show()
    helperButton:setOn(false)
    modules.game_mainpanel.reloadMainPanelSizes()

    connect(g_game, {
        onGameStart = online,
        onGameEnd = offline,
        onAttackingCreatureChange = onAttackingCreatureChange,
        onSpellGroupCooldown = onSpellGroupCooldown,
        onSpellCooldown = onSpellCooldown
    })
    connect(LocalPlayer, {
        onVocationChange = onLocalPlayerVocationChange,
        onLevelChange = updateExtrasControls,
        onStatesChange = onLocalPlayerStatesChange,
        onPositionChange = onExerciseTrainingPlayerPositionChange
    })
    connect(Creature, {
        onHealthPercentChange = wakeAutoAttack,
        onAppear = wakeAutoAttack,
        onDeath = wakeAutoAttack
    })
    connect(Container, {
        onOpen = updateExtrasControls,
        onUpdateItem = updateExtrasControls
    })
    healingEvent = cycleEvent(checkHealing, HEALING_CHECK_INTERVAL)
    autoAttackEvent = cycleEvent(checkAutoAttack, AUTO_ATTACK_CHECK_INTERVAL)
    attackRotationEvent = cycleEvent(checkAttackRotation, ATTACK_ROTATION_INTERVAL)
    autoEatEvent = cycleEvent(checkAutoEatFood, AUTO_EAT_CHECK_INTERVAL)
    AUTO_HASTE.event = cycleEvent(checkAutoHaste, AUTO_HASTE.checkInterval)
    MANA_TRAINING.event = cycleEvent(
        checkManaTraining, MANA_TRAINING.checkInterval)
    EXERCISE_TRAINING.event = cycleEvent(
        checkExerciseTraining, EXERCISE_TRAINING.checkInterval)

    if g_game.isOnline() then online() end
end

function terminate()
    cancelExtrasToggleReset()
    unregisterHelperHotkeys()
    disconnect(g_game, {
        onGameStart = online,
        onGameEnd = offline,
        onAttackingCreatureChange = onAttackingCreatureChange,
        onSpellGroupCooldown = onSpellGroupCooldown,
        onSpellCooldown = onSpellCooldown
    })
    disconnect(LocalPlayer, {
        onVocationChange = onLocalPlayerVocationChange,
        onLevelChange = updateExtrasControls,
        onStatesChange = onLocalPlayerStatesChange,
        onPositionChange = onExerciseTrainingPlayerPositionChange
    })
    disconnect(Creature, {
        onHealthPercentChange = wakeAutoAttack,
        onAppear = wakeAutoAttack,
        onDeath = wakeAutoAttack
    })
    disconnect(Container, {
        onOpen = updateExtrasControls,
        onUpdateItem = updateExtrasControls
    })
    if healingEvent then removeEvent(healingEvent) healingEvent = nil end
    if autoAttackEvent then removeEvent(autoAttackEvent) autoAttackEvent = nil end
    if attackRotationEvent then removeEvent(attackRotationEvent) attackRotationEvent = nil end
    if autoEatEvent then removeEvent(autoEatEvent) autoEatEvent = nil end
    if AUTO_HASTE.event then removeEvent(AUTO_HASTE.event) AUTO_HASTE.event = nil end
    if MANA_TRAINING.event then
        removeEvent(MANA_TRAINING.event)
        MANA_TRAINING.event = nil
    end
    if EXERCISE_TRAINING.event then
        removeEvent(EXERCISE_TRAINING.event)
        EXERCISE_TRAINING.event = nil
    end
    if autoAttackWakeEvent then removeEvent(autoAttackWakeEvent) autoAttackWakeEvent = nil end
    if helperNotificationEvent then
        removeEvent(helperNotificationEvent)
        helperNotificationEvent = nil
    end
    if presetNameWindow then
        presetNameWindow:destroy()
        presetNameWindow = nil
    end
    if presetDeleteWindow then
        presetDeleteWindow:destroy()
        presetDeleteWindow = nil
    end
    if assignmentGrabber then
        if assignmentCursorEvent then
            removeEvent(assignmentCursorEvent)
            assignmentCursorEvent = nil
        end
        if g_ui.isMouseGrabbed() then assignmentGrabber:ungrabMouse() end
        restoreAssignmentCursor()
        assignmentGrabber:destroy()
        assignmentGrabber = nil
    end
    if exerciseHelperRestoreEvent then
        removeEvent(exerciseHelperRestoreEvent)
        exerciseHelperRestoreEvent = nil
    end
    if helperButton then helperButton:destroy() helperButton = nil end
    if helperNotification then
        helperNotification:destroy()
        helperNotification = nil
    end
    if helperWindow then helperWindow:destroy() helperWindow = nil end
end
