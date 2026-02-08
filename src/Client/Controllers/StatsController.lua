--!strict
--[[
    StatsController.lua
    Client-side stats tracking and display
    Receives stats updates from server and provides data for UI
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatsTypes = require(Shared:WaitForChild("StatsTypes"))

local LocalPlayer = Players.LocalPlayer

local StatsController = Knit.CreateController({
    Name = "StatsController",

    _stats = nil :: StatsTypes.PlayerStats?,
    _sessionStats = nil :: StatsTypes.SessionStats?,
    _progression = nil :: StatsTypes.ProgressionData?,
    _leaderboard = nil :: any,
    _statsUpdatedSignal = nil :: any,
    _sessionStatsUpdatedSignal = nil :: any,
    _leaderboardUpdatedSignal = nil :: any,
    _dataLoadedSignal = nil :: any,
})

function StatsController:KnitInit()
    self._statsUpdatedSignal = Signal.new()
    self._sessionStatsUpdatedSignal = Signal.new()
    self._leaderboardUpdatedSignal = Signal.new()
    self._dataLoadedSignal = Signal.new()
    print("[StatsController] Initialized")
end

function StatsController:KnitStart()
    local StatsService = Knit.GetService("StatsService")
    local DataService = Knit.GetService("DataService")

    -- Listen for stats updates
    StatsService.StatsUpdated:Connect(function(player, stats)
        if player == LocalPlayer then
            self._stats = stats
            self._statsUpdatedSignal:Fire(stats)
        end
    end)

    -- Listen for session stats updates
    StatsService.SessionStatsUpdated:Connect(function(player, sessionStats)
        if player == LocalPlayer then
            self._sessionStats = sessionStats
            self._sessionStatsUpdatedSignal:Fire(sessionStats)
        end
    end)

    -- Listen for leaderboard updates
    StatsService.LeaderboardUpdated:Connect(function(leaderboard)
        self._leaderboard = leaderboard
        self._leaderboardUpdatedSignal:Fire(leaderboard)
    end)

    -- Listen for initial data load
    DataService.DataLoaded:Connect(function(player, data)
        if player == LocalPlayer then
            self._stats = data.stats
            self._progression = data.progression
            self._dataLoadedSignal:Fire(data)
            self._statsUpdatedSignal:Fire(data.stats)
        end
    end)

    -- Fetch initial data
    task.spawn(function()
        local data = DataService:GetMyData()
        if data then
            self._stats = data.stats
            self._progression = data.progression
            self._dataLoadedSignal:Fire(data)
            self._statsUpdatedSignal:Fire(data.stats)
        end

        local sessionStats = StatsService:GetMySessionStats()
        if sessionStats then
            self._sessionStats = sessionStats
            self._sessionStatsUpdatedSignal:Fire(sessionStats)
        end

        local leaderboard = StatsService:GetLeaderboard()
        if leaderboard then
            self._leaderboard = leaderboard
            self._leaderboardUpdatedSignal:Fire(leaderboard)
        end
    end)

    print("[StatsController] Started")
end

--[[
    Get the player's persistent stats
]]
function StatsController:GetStats(): StatsTypes.PlayerStats?
    return self._stats
end

--[[
    Get the player's session stats
]]
function StatsController:GetSessionStats(): StatsTypes.SessionStats?
    return self._sessionStats
end

--[[
    Get the player's progression data
]]
function StatsController:GetProgression(): StatsTypes.ProgressionData?
    return self._progression
end

--[[
    Get the current leaderboard
]]
function StatsController:GetLeaderboard(): any
    return self._leaderboard
end

--[[
    Subscribe to stats updates
]]
function StatsController:OnStatsUpdated(callback: (stats: StatsTypes.PlayerStats) -> ())
    return self._statsUpdatedSignal:Connect(callback)
end

--[[
    Subscribe to session stats updates
]]
function StatsController:OnSessionStatsUpdated(callback: (sessionStats: StatsTypes.SessionStats) -> ())
    return self._sessionStatsUpdatedSignal:Connect(callback)
end

--[[
    Subscribe to leaderboard updates
]]
function StatsController:OnLeaderboardUpdated(callback: (leaderboard: any) -> ())
    return self._leaderboardUpdatedSignal:Connect(callback)
end

--[[
    Subscribe to data loaded event
]]
function StatsController:OnDataLoaded(callback: (data: { stats: StatsTypes.PlayerStats, progression: StatsTypes.ProgressionData }) -> ())
    return self._dataLoadedSignal:Connect(callback)
end

--[[
    Format a stat value for display
]]
function StatsController:FormatStat(value: number, statType: string?): string
    if statType == "time" then
        -- Format as time (mm:ss or hh:mm:ss)
        local hours = math.floor(value / 3600)
        local minutes = math.floor((value % 3600) / 60)
        local seconds = math.floor(value % 60)

        if hours > 0 then
            return string.format("%d:%02d:%02d", hours, minutes, seconds)
        else
            return string.format("%d:%02d", minutes, seconds)
        end
    else
        -- Format as number with commas
        local formatted = tostring(math.floor(value))
        local k
        while true do
            formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
            if k == 0 then break end
        end
        return formatted
    end
end

return StatsController
