--!strict
--[[
    StatsService.lua
    Tracks freezes, rescues, wins and other gameplay statistics
    Handles both session stats (leaderboards) and persistent stats
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatsTypes = require(Shared:WaitForChild("StatsTypes"))
local Enums = require(Shared:WaitForChild("Enums"))

local StatsService = Knit.CreateService({
    Name = "StatsService",

    Client = {
        StatsUpdated = Knit.CreateSignal(),           -- (player, stats)
        SessionStatsUpdated = Knit.CreateSignal(),    -- (player, sessionStats)
        LeaderboardUpdated = Knit.CreateSignal(),     -- (leaderboardData)
    },

    _sessionStats = {} :: { [Player]: StatsTypes.SessionStats },
    _survivalTimers = {} :: { [Player]: number }, -- Track when runner started surviving
    _statsChangedSignal = nil :: any,
})

function StatsService:KnitInit()
    self._statsChangedSignal = Signal.new()
    print("[StatsService] Initialized")
end

function StatsService:KnitStart()
    -- Initialize session stats for existing players
    for _, player in Players:GetPlayers() do
        self:_initSessionStats(player)
    end

    -- Handle new players
    Players.PlayerAdded:Connect(function(player)
        self:_initSessionStats(player)
    end)

    -- Handle players leaving
    Players.PlayerRemoving:Connect(function(player)
        self._sessionStats[player] = nil
        self._survivalTimers[player] = nil
    end)

    -- Subscribe to freeze/unfreeze events
    local PlayerStateService = Knit.GetService("PlayerStateService")
    PlayerStateService:OnPlayerFrozen(function(player, frozenBy)
        self:RecordFreeze(player, frozenBy)
    end)

    PlayerStateService:OnPlayerUnfrozen(function(player, unfrozenBy)
        self:RecordRescue(player, unfrozenBy)
    end)

    -- Subscribe to round events
    local RoundService = Knit.GetService("RoundService")
    RoundService:OnRoundEnded(function(results)
        self:RecordRoundResults(results)
    end)

    RoundService:OnPhaseChanged(function(phase)
        if phase == Enums.GameplayPhase.ACTIVE then
            self:_startSurvivalTracking()
        end
    end)

    print("[StatsService] Started")
end

--[[
    Initialize session stats for a player
]]
function StatsService:_initSessionStats(player: Player)
    self._sessionStats[player] = StatsTypes.createDefaultSessionStats()
end

--[[
    Record a freeze event (seeker froze a runner)
    @param frozenPlayer - The runner who was frozen
    @param frozenBy - The seeker who did the freezing
]]
function StatsService:RecordFreeze(frozenPlayer: Player, frozenBy: Player)
    -- Update seeker's stats (freezesMade)
    self:_updateSessionStat(frozenBy, "freezesMade", 1)
    self:_updatePersistentStat(frozenBy, "freezesMade", 1)

    -- Update runner's stats (timesFrozen)
    self:_updateSessionStat(frozenPlayer, "timesFrozen", 1)
    self:_updatePersistentStat(frozenPlayer, "timesFrozen", 1)

    -- Stop survival timer for frozen player
    self:_stopSurvivalTimer(frozenPlayer)

    -- Fire XP event for the seeker
    local ProgressionService = Knit.GetService("ProgressionService")
    ProgressionService:AwardXP(frozenBy, "freeze")

    -- Update leaderboard
    self:_broadcastLeaderboard()

    print(string.format("[StatsService] %s froze %s", frozenBy.Name, frozenPlayer.Name))
end

--[[
    Record a rescue event (runner unfroze a teammate)
    @param rescuedPlayer - The player who was unfrozen
    @param rescuedBy - The player who did the rescuing
]]
function StatsService:RecordRescue(rescuedPlayer: Player, rescuedBy: Player)
    -- Don't count if player unfroze themselves (shouldn't happen but safety check)
    if rescuedPlayer == rescuedBy then
        return
    end

    -- Update rescuer's stats
    self:_updateSessionStat(rescuedBy, "rescues", 1)
    self:_updatePersistentStat(rescuedBy, "rescues", 1)

    -- Restart survival timer for rescued player
    self._survivalTimers[rescuedPlayer] = tick()

    -- Fire XP event for the rescuer
    local ProgressionService = Knit.GetService("ProgressionService")
    ProgressionService:AwardXP(rescuedBy, "rescue")

    -- Update leaderboard
    self:_broadcastLeaderboard()

    print(string.format("[StatsService] %s rescued %s", rescuedBy.Name, rescuedPlayer.Name))
end

--[[
    Record round results for all participants
    @param results - Round results from RoundService
]]
function StatsService:RecordRoundResults(results: any)
    local TeamService = Knit.GetService("TeamService")
    local ProgressionService = Knit.GetService("ProgressionService")

    local seekers = TeamService:GetSeekers()
    local runners = TeamService:GetRunners()

    -- Stop all survival timers and record survival time
    self:_finalizeSurvivalTimers()

    -- Record games played for all participants
    for _, seeker in seekers do
        self:_updateSessionStat(seeker, "roundsPlayed", 1)
        self:_updatePersistentStat(seeker, "gamesPlayed", 1)

        -- Award participation XP
        ProgressionService:AwardXP(seeker, "participate")
    end

    for _, runner in runners do
        self:_updateSessionStat(runner, "roundsPlayed", 1)
        self:_updatePersistentStat(runner, "gamesPlayed", 1)

        -- Award participation XP
        ProgressionService:AwardXP(runner, "participate")
    end

    -- Record wins
    if results.winner == Enums.WinnerTeam.Seekers then
        for _, seeker in seekers do
            self:_updateSessionStat(seeker, "wins", 1)
            self:_updatePersistentStat(seeker, "wins", 1)
            self:_updatePersistentStat(seeker, "seekerWins", 1)
            ProgressionService:AwardXP(seeker, "win_seeker")
        end
    else
        for _, runner in runners do
            self:_updateSessionStat(runner, "wins", 1)
            self:_updatePersistentStat(runner, "wins", 1)
            self:_updatePersistentStat(runner, "runnerWins", 1)
            ProgressionService:AwardXP(runner, "win_runner")
        end
    end

    -- Update leaderboard
    self:_broadcastLeaderboard()

    print(string.format("[StatsService] Round results recorded. Winner: %s", results.winner))
end

--[[
    Start survival tracking for all runners when ACTIVE phase begins
]]
function StatsService:_startSurvivalTracking()
    local TeamService = Knit.GetService("TeamService")
    local runners = TeamService:GetRunners()
    local now = tick()

    for _, runner in runners do
        self._survivalTimers[runner] = now
    end

    -- Award survival XP periodically
    task.spawn(function()
        local RoundService = Knit.GetService("RoundService")
        local ProgressionService = Knit.GetService("ProgressionService")
        local PlayerStateService = Knit.GetService("PlayerStateService")

        while RoundService:IsRoundActive() and RoundService:GetCurrentPhase() == Enums.GameplayPhase.ACTIVE do
            task.wait(30) -- Award XP every 30 seconds

            if not RoundService:IsRoundActive() then break end

            -- Award survival XP to unfrozen runners
            for _, runner in TeamService:GetRunners() do
                if not PlayerStateService:IsFrozen(runner) then
                    ProgressionService:AwardXP(runner, "survive")
                end
            end
        end
    end)
end

--[[
    Stop a player's survival timer
]]
function StatsService:_stopSurvivalTimer(player: Player)
    local startTime = self._survivalTimers[player]
    if startTime then
        local survived = tick() - startTime
        self:_updatePersistentStat(player, "timeSurvived", survived)
        self._survivalTimers[player] = nil
    end
end

--[[
    Finalize all survival timers at round end
]]
function StatsService:_finalizeSurvivalTimers()
    local now = tick()
    for player, startTime in self._survivalTimers do
        local survived = now - startTime
        self:_updatePersistentStat(player, "timeSurvived", survived)
    end
    self._survivalTimers = {}
end

--[[
    Update a session stat for a player
]]
function StatsService:_updateSessionStat(player: Player, stat: string, delta: number)
    local stats = self._sessionStats[player]
    if stats and stats[stat] ~= nil then
        stats[stat] += delta
        self.Client.SessionStatsUpdated:Fire(player, stats)
    end
end

--[[
    Update a persistent stat for a player
]]
function StatsService:_updatePersistentStat(player: Player, stat: string, delta: number)
    local DataService = Knit.GetService("DataService")
    DataService:UpdateStats(player, { [stat] = delta })

    local data = DataService:GetPlayerData(player)
    if data then
        self.Client.StatsUpdated:Fire(player, data.stats)
        self._statsChangedSignal:Fire(player, data.stats)
    end
end

--[[
    Get session stats for a player
]]
function StatsService:GetSessionStats(player: Player): StatsTypes.SessionStats?
    return self._sessionStats[player]
end

--[[
    Get leaderboard data (top players by freezes and rescues)
]]
function StatsService:GetLeaderboard(): { topSeekers: { { player: Player, freezes: number } }, topRescuers: { { player: Player, rescues: number } } }
    local seekerList = {}
    local rescuerList = {}

    for player, stats in self._sessionStats do
        table.insert(seekerList, { player = player, freezes = stats.freezesMade })
        table.insert(rescuerList, { player = player, rescues = stats.rescues })
    end

    -- Sort by count descending
    table.sort(seekerList, function(a, b)
        return a.freezes > b.freezes
    end)

    table.sort(rescuerList, function(a, b)
        return a.rescues > b.rescues
    end)

    -- Take top 5
    local topSeekers = {}
    local topRescuers = {}

    for i = 1, math.min(5, #seekerList) do
        table.insert(topSeekers, seekerList[i])
    end

    for i = 1, math.min(5, #rescuerList) do
        table.insert(topRescuers, rescuerList[i])
    end

    return {
        topSeekers = topSeekers,
        topRescuers = topRescuers,
    }
end

--[[
    Broadcast leaderboard update to all clients
]]
function StatsService:_broadcastLeaderboard()
    local leaderboard = self:GetLeaderboard()

    -- Convert Player objects to names/userIds for network transmission
    local networkLeaderboard = {
        topSeekers = {},
        topRescuers = {},
    }

    for _, entry in leaderboard.topSeekers do
        table.insert(networkLeaderboard.topSeekers, {
            name = entry.player.Name,
            displayName = entry.player.DisplayName,
            userId = entry.player.UserId,
            freezes = entry.freezes,
        })
    end

    for _, entry in leaderboard.topRescuers do
        table.insert(networkLeaderboard.topRescuers, {
            name = entry.player.Name,
            displayName = entry.player.DisplayName,
            userId = entry.player.UserId,
            rescues = entry.rescues,
        })
    end

    self.Client.LeaderboardUpdated:FireAll(networkLeaderboard)
end

--[[
    Subscribe to stats changed event
]]
function StatsService:OnStatsChanged(callback: (player: Player, stats: StatsTypes.PlayerStats) -> ())
    return self._statsChangedSignal:Connect(callback)
end

-- Client methods
function StatsService.Client:GetMySessionStats(player: Player): StatsTypes.SessionStats?
    return self.Server:GetSessionStats(player)
end

function StatsService.Client:GetLeaderboard(): any
    local leaderboard = self.Server:GetLeaderboard()

    -- Convert for network
    local networkLeaderboard = {
        topSeekers = {},
        topRescuers = {},
    }

    for _, entry in leaderboard.topSeekers do
        table.insert(networkLeaderboard.topSeekers, {
            name = entry.player.Name,
            displayName = entry.player.DisplayName,
            userId = entry.player.UserId,
            freezes = entry.freezes,
        })
    end

    for _, entry in leaderboard.topRescuers do
        table.insert(networkLeaderboard.topRescuers, {
            name = entry.player.Name,
            displayName = entry.player.DisplayName,
            userId = entry.player.UserId,
            rescues = entry.rescues,
        })
    end

    return networkLeaderboard
end

return StatsService
