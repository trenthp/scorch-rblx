--!strict
--[[
    TeamService.lua
    Manages team assignments (Seekers, Runners, Spectators)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

local TeamService = Knit.CreateService({
    Name = "TeamService",

    Client = {
        TeamAssigned = Knit.CreateSignal(),
        TeamsUpdated = Knit.CreateSignal(),
    },

    _seekers = {} :: { Player },
    _runners = {} :: { Player },
    _teamAssignedSignal = nil :: any,
})

function TeamService:KnitInit()
    self._teamAssignedSignal = Signal.new()
    self._seekers = {}
    self._runners = {}
    print("[TeamService] Initialized")
end

function TeamService:KnitStart()
    -- Handle player leaving mid-game
    Players.PlayerRemoving:Connect(function(player)
        self:_handlePlayerLeave(player)
    end)
    print("[TeamService] Started")
end

--[[
    Start team selection phase
    Assigns players randomly for now
]]
function TeamService:StartTeamSelection()
    print("[TeamService] Starting team selection")
    -- Reset teams
    self._seekers = {}
    self._runners = {}

    -- Put all players back to lobby team initially
    local lobbyTeam = Teams:FindFirstChild("Lobby") :: Team?
    if lobbyTeam then
        for _, player in Players:GetPlayers() do
            player.Team = lobbyTeam
        end
    end
end

--[[
    Finalize team assignments
    Called when team selection timer ends
]]
function TeamService:FinalizeTeams()
    local allPlayers = Players:GetPlayers()

    -- Shuffle players for random assignment
    local shuffled = table.clone(allPlayers)
    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    -- Assign seekers
    self._seekers = {}
    self._runners = {}

    local seekerTeam = Teams:FindFirstChild("Seekers") :: Team?
    local runnerTeam = Teams:FindFirstChild("Runners") :: Team?

    for i, player in shuffled do
        if i <= Constants.SEEKER_COUNT then
            table.insert(self._seekers, player)
            if seekerTeam then
                player.Team = seekerTeam
            end
            self.Client.TeamAssigned:Fire(player, Enums.PlayerRole.Seeker)
            self._teamAssignedSignal:Fire(player, Enums.PlayerRole.Seeker)
        else
            table.insert(self._runners, player)
            if runnerTeam then
                player.Team = runnerTeam
            end
            self.Client.TeamAssigned:Fire(player, Enums.PlayerRole.Runner)
            self._teamAssignedSignal:Fire(player, Enums.PlayerRole.Runner)
        end
    end

    -- Notify all clients of final teams
    self.Client.TeamsUpdated:FireAll(self:_serializeTeams())

    print(string.format("[TeamService] Teams finalized: %d seekers, %d runners",
        #self._seekers, #self._runners))
end

--[[
    Get a player's current role
]]
function TeamService:GetPlayerRole(player: Player): string
    if table.find(self._seekers, player) then
        return Enums.PlayerRole.Seeker
    elseif table.find(self._runners, player) then
        return Enums.PlayerRole.Runner
    end
    return Enums.PlayerRole.Spectator
end

--[[
    Check if a player is a seeker
]]
function TeamService:IsSeeker(player: Player): boolean
    return table.find(self._seekers, player) ~= nil
end

--[[
    Check if a player is a runner
]]
function TeamService:IsRunner(player: Player): boolean
    return table.find(self._runners, player) ~= nil
end

--[[
    Get all seekers
]]
function TeamService:GetSeekers(): { Player }
    return table.clone(self._seekers)
end

--[[
    Get all runners
]]
function TeamService:GetRunners(): { Player }
    return table.clone(self._runners)
end

--[[
    Reset teams (return everyone to lobby)
]]
function TeamService:ResetTeams()
    self._seekers = {}
    self._runners = {}

    local lobbyTeam = Teams:FindFirstChild("Lobby") :: Team?
    if lobbyTeam then
        for _, player in Players:GetPlayers() do
            player.Team = lobbyTeam
        end
    end

    self.Client.TeamsUpdated:FireAll(self:_serializeTeams())
    print("[TeamService] Teams reset")
end

--[[
    Handle player leaving the game
]]
function TeamService:_handlePlayerLeave(player: Player)
    local seekerIndex = table.find(self._seekers, player)
    if seekerIndex then
        table.remove(self._seekers, seekerIndex)
    end

    local runnerIndex = table.find(self._runners, player)
    if runnerIndex then
        table.remove(self._runners, runnerIndex)
    end

    -- Check if game should end due to no seekers or runners
    local GameStateService = Knit.GetService("GameStateService")
    local currentState = GameStateService:GetState()

    if currentState == Enums.GameState.GAMEPLAY then
        if #self._seekers == 0 then
            local RoundService = Knit.GetService("RoundService")
            RoundService:EndRound(Enums.WinnerTeam.Runners, Enums.RoundEndReason.SeekersDisconnected)
        elseif #self._runners == 0 then
            local RoundService = Knit.GetService("RoundService")
            RoundService:EndRound(Enums.WinnerTeam.Seekers, Enums.RoundEndReason.RunnersDisconnected)
        end
    end
end

--[[
    Serialize teams for network transmission
]]
function TeamService:_serializeTeams(): { seekers: { number }, runners: { number } }
    local seekerIds = {}
    local runnerIds = {}

    for _, player in self._seekers do
        table.insert(seekerIds, player.UserId)
    end

    for _, player in self._runners do
        table.insert(runnerIds, player.UserId)
    end

    return {
        seekers = seekerIds,
        runners = runnerIds,
    }
end

-- Client methods
function TeamService.Client:GetMyRole(player: Player): string
    return self.Server:GetPlayerRole(player)
end

function TeamService.Client:GetTeams(): { seekers: { number }, runners: { number } }
    return self.Server:_serializeTeams()
end

return TeamService
