--!strict
--[[
    ProgressionConfig.lua
    XP values, level thresholds, and titles configuration
]]

local ProgressionConfig = {
    -- XP Rewards for various actions
    XP_REWARDS = {
        freeze = 50,          -- Freeze a runner (seeker)
        rescue = 30,          -- Rescue a frozen teammate (runner)
        survive = 10,         -- Survive for 30 seconds (runner)
        win_seeker = 100,     -- Win as seeker
        win_runner = 75,      -- Win as runner
        participate = 25,     -- Complete a round (any role)
    },

    -- Level thresholds (cumulative XP required to reach each level)
    -- Level 1 = 0 XP (starting)
    LEVEL_THRESHOLDS = {
        [1] = 0,
        [2] = 100,
        [3] = 250,
        [4] = 500,
        [5] = 1000,      -- Hunter
        [6] = 1600,
        [7] = 2400,
        [8] = 3400,
        [9] = 4600,
        [10] = 5500,     -- Stalker
        [11] = 6600,
        [12] = 7900,
        [13] = 9400,
        [14] = 11100,
        [15] = 12000,    -- Shadow
        [16] = 14200,
        [17] = 16600,
        [18] = 19200,
        [19] = 22000,
        [20] = 22000,    -- Predator
        [21] = 25200,
        [22] = 28600,
        [23] = 32200,
        [24] = 36000,
        [25] = 35000,    -- Apex
        [26] = 40000,
        [27] = 45200,
        [28] = 50600,
        [29] = 56200,
        [30] = 52000,    -- Legend
        [31] = 58500,
        [32] = 65200,
        [33] = 72100,
        [34] = 79200,
        [35] = 86500,
        [36] = 94000,
        [37] = 101700,
        [38] = 109600,
        [39] = 117700,
        [40] = 95000,    -- Mythic
        [41] = 105000,
        [42] = 115200,
        [43] = 125600,
        [44] = 136200,
        [45] = 147000,
        [46] = 158000,
        [47] = 169200,
        [48] = 180600,
        [49] = 192200,
        [50] = 150000,   -- Scorch Master
    },

    -- Titles unlocked at specific levels
    TITLES = {
        [1] = "Rookie",
        [5] = "Hunter",
        [10] = "Stalker",
        [15] = "Shadow",
        [20] = "Predator",
        [25] = "Apex",
        [30] = "Legend",
        [40] = "Mythic",
        [50] = "Scorch Master",
    },

    -- Title colors for display
    TITLE_COLORS = {
        ["Rookie"] = Color3.fromRGB(180, 180, 180),      -- Gray
        ["Hunter"] = Color3.fromRGB(100, 200, 100),      -- Green
        ["Stalker"] = Color3.fromRGB(100, 150, 255),     -- Blue
        ["Shadow"] = Color3.fromRGB(150, 100, 200),      -- Purple
        ["Predator"] = Color3.fromRGB(255, 150, 50),     -- Orange
        ["Apex"] = Color3.fromRGB(255, 215, 0),          -- Gold
        ["Legend"] = Color3.fromRGB(255, 100, 100),      -- Red
        ["Mythic"] = Color3.fromRGB(255, 50, 200),       -- Magenta
        ["Scorch Master"] = Color3.fromRGB(255, 255, 100), -- Bright Yellow
    },

    -- Maximum level
    MAX_LEVEL = 50,
}

--[[
    Get the XP reward for an action
    @param action - The action type
    @return XP amount
]]
function ProgressionConfig.getXPReward(action: string): number
    return ProgressionConfig.XP_REWARDS[action] or 0
end

--[[
    Calculate level from total XP
    @param xp - Total XP
    @return Current level
]]
function ProgressionConfig.calculateLevel(xp: number): number
    local level = 1
    for lvl = 1, ProgressionConfig.MAX_LEVEL do
        local threshold = ProgressionConfig.LEVEL_THRESHOLDS[lvl]
        if threshold and xp >= threshold then
            level = lvl
        else
            break
        end
    end
    return level
end

--[[
    Get XP required to reach a specific level
    @param level - Target level
    @return XP threshold
]]
function ProgressionConfig.getXPForLevel(level: number): number
    return ProgressionConfig.LEVEL_THRESHOLDS[level] or 0
end

--[[
    Get XP required for the next level
    @param currentLevel - Current level
    @return XP threshold for next level, or -1 if max level
]]
function ProgressionConfig.getXPForNextLevel(currentLevel: number): number
    if currentLevel >= ProgressionConfig.MAX_LEVEL then
        return -1
    end
    return ProgressionConfig.LEVEL_THRESHOLDS[currentLevel + 1] or -1
end

--[[
    Calculate progress to next level (0.0 to 1.0)
    @param xp - Total XP
    @param level - Current level
    @return Progress fraction
]]
function ProgressionConfig.calculateProgress(xp: number, level: number): number
    if level >= ProgressionConfig.MAX_LEVEL then
        return 1.0
    end

    local currentThreshold = ProgressionConfig.LEVEL_THRESHOLDS[level] or 0
    local nextThreshold = ProgressionConfig.LEVEL_THRESHOLDS[level + 1] or currentThreshold

    local xpIntoLevel = xp - currentThreshold
    local xpForLevel = nextThreshold - currentThreshold

    if xpForLevel <= 0 then
        return 1.0
    end

    return math.clamp(xpIntoLevel / xpForLevel, 0, 1)
end

--[[
    Get the title unlocked at a specific level (if any)
    @param level - The level to check
    @return Title string or nil
]]
function ProgressionConfig.getTitleAtLevel(level: number): string?
    return ProgressionConfig.TITLES[level]
end

--[[
    Get all unlocked titles for a player based on their level
    @param level - Current level
    @return Array of unlocked title strings
]]
function ProgressionConfig.getUnlockedTitles(level: number): { string }
    local titles = {}
    for lvl, title in ProgressionConfig.TITLES do
        if lvl <= level then
            table.insert(titles, title)
        end
    end

    -- Sort by level (lowest first)
    table.sort(titles, function(a, b)
        local lvlA, lvlB = 0, 0
        for lvl, title in ProgressionConfig.TITLES do
            if title == a then lvlA = lvl end
            if title == b then lvlB = lvl end
        end
        return lvlA < lvlB
    end)

    return titles
end

--[[
    Get the color for a title
    @param title - The title
    @return Color3
]]
function ProgressionConfig.getTitleColor(title: string): Color3
    return ProgressionConfig.TITLE_COLORS[title] or Color3.fromRGB(255, 255, 255)
end

--[[
    Get the level required for a title
    @param title - The title to look up
    @return Level number or nil
]]
function ProgressionConfig.getLevelForTitle(title: string): number?
    for level, t in ProgressionConfig.TITLES do
        if t == title then
            return level
        end
    end
    return nil
end

return ProgressionConfig
