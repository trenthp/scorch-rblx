--!strict
--[[
    ProgressionService.lua
    Manages XP awards, level calculations, and title unlocks
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))
local StatsTypes = require(Shared:WaitForChild("StatsTypes"))

local ProgressionService = Knit.CreateService({
    Name = "ProgressionService",

    Client = {
        XPAwarded = Knit.CreateSignal(),      -- (xpAmount, reason, newTotal)
        LevelUp = Knit.CreateSignal(),         -- (newLevel, unlockedTitle)
        TitleUnlocked = Knit.CreateSignal(),   -- (title)
        ProgressionUpdated = Knit.CreateSignal(), -- (progressionData)
    },

    _xpAwardedSignal = nil :: any,
    _levelUpSignal = nil :: any,
})

function ProgressionService:KnitInit()
    self._xpAwardedSignal = Signal.new()
    self._levelUpSignal = Signal.new()
    print("[ProgressionService] Initialized")
end

function ProgressionService:KnitStart()
    -- When player data loads, ensure their level matches their XP
    local DataService = Knit.GetService("DataService")
    DataService:OnDataLoaded(function(player, data)
        self:_validateProgression(player, data)
    end)

    print("[ProgressionService] Started")
end

--[[
    Validate and fix progression data (ensure level matches XP)
    @param player - The player to validate
    @param data - Their loaded data
]]
function ProgressionService:_validateProgression(player: Player, data: StatsTypes.PlayerData)
    local correctLevel = ProgressionConfig.calculateLevel(data.progression.xp)
    local correctTitles = ProgressionConfig.getUnlockedTitles(correctLevel)

    local needsUpdate = false

    -- Fix level if incorrect
    if data.progression.level ~= correctLevel then
        data.progression.level = correctLevel
        needsUpdate = true
    end

    -- Ensure all earned titles are unlocked
    for _, title in correctTitles do
        if not table.find(data.progression.unlockedTitles, title) then
            table.insert(data.progression.unlockedTitles, title)
            needsUpdate = true
        end
    end

    -- Ensure selected title is valid
    if not table.find(data.progression.unlockedTitles, data.progression.selectedTitle) then
        data.progression.selectedTitle = "Rookie"
        needsUpdate = true
    end

    if needsUpdate then
        local DataService = Knit.GetService("DataService")
        DataService:UpdateProgression(player, {
            level = data.progression.level,
            unlockedTitles = data.progression.unlockedTitles,
            selectedTitle = data.progression.selectedTitle,
        })
        print(string.format("[ProgressionService] Fixed progression for %s (Level %d)",
            player.Name, correctLevel))
    end
end

--[[
    Award XP to a player for an action
    @param player - The player to award XP to
    @param action - The action type (from ProgressionConfig.XP_REWARDS)
]]
function ProgressionService:AwardXP(player: Player, action: string)
    local xpAmount = ProgressionConfig.getXPReward(action)
    if xpAmount <= 0 then
        return
    end

    local DataService = Knit.GetService("DataService")
    local data = DataService:GetPlayerData(player)
    if not data then
        return
    end

    local oldLevel = data.progression.level
    local oldXP = data.progression.xp

    -- Add XP
    DataService:AddXP(player, xpAmount)
    local newXP = oldXP + xpAmount

    -- Calculate new level
    local newLevel = ProgressionConfig.calculateLevel(newXP)

    -- Check for level up
    if newLevel > oldLevel then
        DataService:SetLevel(player, newLevel)

        -- Check for title unlocks
        for level = oldLevel + 1, newLevel do
            local unlockedTitle = ProgressionConfig.getTitleAtLevel(level)
            if unlockedTitle then
                DataService:UnlockTitle(player, unlockedTitle)
                self.Client.TitleUnlocked:Fire(player, unlockedTitle)
                print(string.format("[ProgressionService] %s unlocked title: %s", player.Name, unlockedTitle))
            end
        end

        -- Fire level up event
        local titleAtLevel = ProgressionConfig.getTitleAtLevel(newLevel)
        self.Client.LevelUp:Fire(player, newLevel, titleAtLevel)
        self._levelUpSignal:Fire(player, newLevel, titleAtLevel)

        print(string.format("[ProgressionService] %s leveled up! %d -> %d",
            player.Name, oldLevel, newLevel))
    end

    -- Fire XP awarded event
    self.Client.XPAwarded:Fire(player, xpAmount, action, newXP)
    self._xpAwardedSignal:Fire(player, xpAmount, action, newXP)

    -- Send full progression update
    local updatedData = DataService:GetPlayerData(player)
    if updatedData then
        self.Client.ProgressionUpdated:Fire(player, updatedData.progression)
    end
end

--[[
    Get a player's current level
    @param player - The player
    @return Level number
]]
function ProgressionService:GetLevel(player: Player): number
    local DataService = Knit.GetService("DataService")
    local data = DataService:GetPlayerData(player)
    if data then
        return data.progression.level
    end
    return 1
end

--[[
    Get a player's total XP
    @param player - The player
    @return Total XP
]]
function ProgressionService:GetXP(player: Player): number
    local DataService = Knit.GetService("DataService")
    local data = DataService:GetPlayerData(player)
    if data then
        return data.progression.xp
    end
    return 0
end

--[[
    Get a player's currently selected title
    @param player - The player
    @return Title string
]]
function ProgressionService:GetTitle(player: Player): string
    local DataService = Knit.GetService("DataService")
    local data = DataService:GetPlayerData(player)
    if data then
        return data.progression.selectedTitle
    end
    return "Rookie"
end

--[[
    Get a player's unlocked titles
    @param player - The player
    @return Array of title strings
]]
function ProgressionService:GetUnlockedTitles(player: Player): { string }
    local DataService = Knit.GetService("DataService")
    local data = DataService:GetPlayerData(player)
    if data then
        return data.progression.unlockedTitles
    end
    return { "Rookie" }
end

--[[
    Set a player's selected title
    @param player - The player
    @param title - The title to select
    @return True if successful
]]
function ProgressionService:SelectTitle(player: Player, title: string): boolean
    local unlockedTitles = self:GetUnlockedTitles(player)
    if not table.find(unlockedTitles, title) then
        return false
    end

    local DataService = Knit.GetService("DataService")
    DataService:SetSelectedTitle(player, title)

    -- Notify client
    local data = DataService:GetPlayerData(player)
    if data then
        self.Client.ProgressionUpdated:Fire(player, data.progression)
    end

    return true
end

--[[
    Get progress to next level (0.0 to 1.0)
    @param player - The player
    @return Progress fraction
]]
function ProgressionService:GetProgress(player: Player): number
    local DataService = Knit.GetService("DataService")
    local data = DataService:GetPlayerData(player)
    if data then
        return ProgressionConfig.calculateProgress(data.progression.xp, data.progression.level)
    end
    return 0
end

--[[
    Subscribe to XP awarded event
]]
function ProgressionService:OnXPAwarded(callback: (player: Player, amount: number, action: string, newTotal: number) -> ())
    return self._xpAwardedSignal:Connect(callback)
end

--[[
    Subscribe to level up event
]]
function ProgressionService:OnLevelUp(callback: (player: Player, newLevel: number, unlockedTitle: string?) -> ())
    return self._levelUpSignal:Connect(callback)
end

-- Client methods
function ProgressionService.Client:GetMyLevel(player: Player): number
    return self.Server:GetLevel(player)
end

function ProgressionService.Client:GetMyXP(player: Player): number
    return self.Server:GetXP(player)
end

function ProgressionService.Client:GetMyTitle(player: Player): string
    return self.Server:GetTitle(player)
end

function ProgressionService.Client:GetMyUnlockedTitles(player: Player): { string }
    return self.Server:GetUnlockedTitles(player)
end

function ProgressionService.Client:SelectTitle(player: Player, title: string): boolean
    return self.Server:SelectTitle(player, title)
end

function ProgressionService.Client:GetMyProgress(player: Player): number
    return self.Server:GetProgress(player)
end

function ProgressionService.Client:GetPlayerTitle(player: Player, targetPlayer: Player): string
    return self.Server:GetTitle(targetPlayer)
end

function ProgressionService.Client:GetPlayerLevel(player: Player, targetPlayer: Player): number
    return self.Server:GetLevel(targetPlayer)
end

return ProgressionService
