--!strict
--[[
    StatsTypes.lua
    Type definitions for stats and progression system
]]

-- Player statistics tracked across sessions
export type PlayerStats = {
    freezesMade: number,      -- Times this player froze runners (as seeker)
    rescues: number,          -- Times this player rescued frozen teammates (as runner)
    timesFrozen: number,      -- Times this player was frozen (as runner)
    gamesPlayed: number,      -- Total rounds played
    wins: number,             -- Total rounds won (either team)
    seekerWins: number,       -- Wins as seeker
    runnerWins: number,       -- Wins as runner
    timeSurvived: number,     -- Total seconds survived as runner
}

-- Progression data
export type ProgressionData = {
    xp: number,               -- Current total XP
    level: number,            -- Current level
    selectedTitle: string,    -- Currently equipped title
    unlockedTitles: { string }, -- All unlocked titles
}

-- Inventory data (imported from InventoryTypes for future use)
export type PlayerInventory = {
    equippedFlashlight: string,
    equippedSkin: string?,
    unlockedFlashlights: { string },
    unlockedSkins: { string },
}

-- Stored battery data (for activatable power-ups)
export type StoredBattery = {
    effectId: string,  -- "Speed", "Stealth", etc.
    sizeId: string,    -- "C", "D", "9V", "Lantern"
}

-- Combined player data stored in DataStore
export type PlayerData = {
    version: number,          -- Schema version for migrations
    stats: PlayerStats,
    progression: ProgressionData,
    inventory: PlayerInventory?,    -- Optional for migration (added in v1)
    achievements: { string }?,      -- Unlocked achievement IDs (added in v1)
    batteries: number,              -- Currency batteries (added in v2)
    storedBatteries: { StoredBattery }?,  -- Max 4 stored power-up batteries (added in v2)
}

-- Session stats (not persisted, reset each server)
export type SessionStats = {
    freezesMade: number,
    rescues: number,
    timesFrozen: number,
    roundsPlayed: number,
    wins: number,
}

-- XP award event data
export type XPAward = {
    amount: number,
    reason: string,
}

-- Level up event data
export type LevelUpData = {
    newLevel: number,
    unlockedTitle: string?,
}

-- Default values
local StatsTypes = {
    -- Default stats for new players
    DEFAULT_STATS = {
        freezesMade = 0,
        rescues = 0,
        timesFrozen = 0,
        gamesPlayed = 0,
        wins = 0,
        seekerWins = 0,
        runnerWins = 0,
        timeSurvived = 0,
    } :: PlayerStats,

    -- Default progression for new players
    DEFAULT_PROGRESSION = {
        xp = 0,
        level = 1,
        selectedTitle = "Rookie",
        unlockedTitles = { "Rookie" },
    } :: ProgressionData,

    -- Current data schema version
    DATA_VERSION = 2,

    -- Default inventory
    DEFAULT_INVENTORY = {
        equippedFlashlight = "Standard",
        equippedSkin = nil,
        unlockedFlashlights = { "Standard" },
        unlockedSkins = { "Default" },
    } :: PlayerInventory,

    -- Default session stats
    DEFAULT_SESSION_STATS = {
        freezesMade = 0,
        rescues = 0,
        timesFrozen = 0,
        roundsPlayed = 0,
        wins = 0,
    } :: SessionStats,
}

--[[
    Create a new default player data object
]]
function StatsTypes.createDefaultPlayerData(): PlayerData
    return {
        version = StatsTypes.DATA_VERSION,
        stats = table.clone(StatsTypes.DEFAULT_STATS),
        progression = {
            xp = 0,
            level = 1,
            selectedTitle = "Rookie",
            unlockedTitles = { "Rookie" },
        },
        inventory = {
            equippedFlashlight = "Standard",
            equippedSkin = nil,
            unlockedFlashlights = { "Standard" },
            unlockedSkins = { "Default" },
        },
        achievements = {},
        batteries = 0,
        storedBatteries = {},
    }
end

--[[
    Create a new default session stats object
]]
function StatsTypes.createDefaultSessionStats(): SessionStats
    return table.clone(StatsTypes.DEFAULT_SESSION_STATS)
end

return StatsTypes
