--!strict
--[[
    ProgressionController.lua
    Client-side progression tracking and UI coordination
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))
local StatsTypes = require(Shared:WaitForChild("StatsTypes"))

local LocalPlayer = Players.LocalPlayer

local ProgressionController = Knit.CreateController({
    Name = "ProgressionController",

    _level = 1,
    _xp = 0,
    _selectedTitle = "Rookie",
    _unlockedTitles = { "Rookie" } :: { string },

    _xpAwardedSignal = nil :: any,
    _levelUpSignal = nil :: any,
    _titleUnlockedSignal = nil :: any,
    _progressionUpdatedSignal = nil :: any,
})

function ProgressionController:KnitInit()
    self._xpAwardedSignal = Signal.new()
    self._levelUpSignal = Signal.new()
    self._titleUnlockedSignal = Signal.new()
    self._progressionUpdatedSignal = Signal.new()
    print("[ProgressionController] Initialized")
end

function ProgressionController:KnitStart()
    local ProgressionService = Knit.GetService("ProgressionService")

    -- Listen for XP awards
    ProgressionService.XPAwarded:Connect(function(xpAmount, reason, newTotal)
        self._xp = newTotal
        self._xpAwardedSignal:Fire(xpAmount, reason, newTotal)
    end)

    -- Listen for level ups
    ProgressionService.LevelUp:Connect(function(newLevel, unlockedTitle)
        self._level = newLevel
        self._levelUpSignal:Fire(newLevel, unlockedTitle)
    end)

    -- Listen for title unlocks
    ProgressionService.TitleUnlocked:Connect(function(title)
        if not table.find(self._unlockedTitles, title) then
            table.insert(self._unlockedTitles, title)
        end
        self._titleUnlockedSignal:Fire(title)
    end)

    -- Listen for full progression updates
    ProgressionService.ProgressionUpdated:Connect(function(progression)
        self._level = progression.level
        self._xp = progression.xp
        self._selectedTitle = progression.selectedTitle
        self._unlockedTitles = progression.unlockedTitles
        self._progressionUpdatedSignal:Fire(progression)
    end)

    -- Fetch initial data
    task.spawn(function()
        local levelSuccess, level = ProgressionService:GetMyLevel():await()
        local xpSuccess, xp = ProgressionService:GetMyXP():await()
        local titleSuccess, title = ProgressionService:GetMyTitle():await()
        local titlesSuccess, titles = ProgressionService:GetMyUnlockedTitles():await()

        if levelSuccess then self._level = level end
        if xpSuccess then self._xp = xp end
        if titleSuccess then self._selectedTitle = title end
        if titlesSuccess then self._unlockedTitles = titles end

        self._progressionUpdatedSignal:Fire({
            level = self._level,
            xp = self._xp,
            selectedTitle = self._selectedTitle,
            unlockedTitles = self._unlockedTitles,
        })
    end)

    print("[ProgressionController] Started")
end

--[[
    Get current level
]]
function ProgressionController:GetLevel(): number
    return self._level
end

--[[
    Get current XP
]]
function ProgressionController:GetXP(): number
    return self._xp
end

--[[
    Get selected title
]]
function ProgressionController:GetTitle(): string
    return self._selectedTitle
end

--[[
    Get unlocked titles
]]
function ProgressionController:GetUnlockedTitles(): { string }
    return self._unlockedTitles
end

--[[
    Get progress to next level (0.0 to 1.0)
]]
function ProgressionController:GetProgress(): number
    return ProgressionConfig.calculateProgress(self._xp, self._level)
end

--[[
    Get XP needed for next level
]]
function ProgressionController:GetXPForNextLevel(): number
    return ProgressionConfig.getXPForNextLevel(self._level)
end

--[[
    Get XP threshold for current level
]]
function ProgressionController:GetXPForCurrentLevel(): number
    return ProgressionConfig.getXPForLevel(self._level)
end

--[[
    Get title color
]]
function ProgressionController:GetTitleColor(title: string?): Color3
    return ProgressionConfig.getTitleColor(title or self._selectedTitle)
end

--[[
    Check if at max level
]]
function ProgressionController:IsMaxLevel(): boolean
    return self._level >= ProgressionConfig.MAX_LEVEL
end

--[[
    Select a title
]]
function ProgressionController:SelectTitle(title: string)
    if table.find(self._unlockedTitles, title) then
        local ProgressionService = Knit.GetService("ProgressionService")
        local success = ProgressionService:SelectTitle(title)
        if success then
            self._selectedTitle = title
        end
        return success
    end
    return false
end

--[[
    Get another player's title
]]
function ProgressionController:GetPlayerTitle(player: Player): string
    if player == LocalPlayer then
        return self._selectedTitle
    end

    local ProgressionService = Knit.GetService("ProgressionService")
    local success, result = ProgressionService:GetPlayerTitle(player):await()
    if success then
        return result
    end
    return "Rookie"
end

--[[
    Get another player's level
]]
function ProgressionController:GetPlayerLevel(player: Player): number
    if player == LocalPlayer then
        return self._level
    end

    local ProgressionService = Knit.GetService("ProgressionService")
    local success, result = ProgressionService:GetPlayerLevel(player):await()
    if success then
        return result
    end
    return 1
end

--[[
    Subscribe to XP awarded events
]]
function ProgressionController:OnXPAwarded(callback: (amount: number, reason: string, newTotal: number) -> ())
    return self._xpAwardedSignal:Connect(callback)
end

--[[
    Subscribe to level up events
]]
function ProgressionController:OnLevelUp(callback: (newLevel: number, unlockedTitle: string?) -> ())
    return self._levelUpSignal:Connect(callback)
end

--[[
    Subscribe to title unlock events
]]
function ProgressionController:OnTitleUnlocked(callback: (title: string) -> ())
    return self._titleUnlockedSignal:Connect(callback)
end

--[[
    Subscribe to progression update events
]]
function ProgressionController:OnProgressionUpdated(callback: (progression: StatsTypes.ProgressionData) -> ())
    return self._progressionUpdatedSignal:Connect(callback)
end

--[[
    Format XP for display
]]
function ProgressionController:FormatXP(xp: number): string
    if xp >= 1000000 then
        return string.format("%.1fM", xp / 1000000)
    elseif xp >= 1000 then
        return string.format("%.1fK", xp / 1000)
    else
        return tostring(xp)
    end
end

return ProgressionController
