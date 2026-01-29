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

    -- Fair seeker selection tracking
    -- Tracks how many rounds since each player was last a seeker
    -- Higher number = longer wait = higher priority to be seeker
    _roundsSinceSeeker = {} :: { [number]: number }, -- UserId -> rounds since seeker
    _currentRoundNumber = 0,
})

function TeamService:KnitInit()
    self._teamAssignedSignal = Signal.new()
    self._seekers = {}
    self._runners = {}
    print("[TeamService] Initialized")
end

function TeamService:KnitStart()
    -- Handle player joining - initialize their seeker tracking
    Players.PlayerAdded:Connect(function(player)
        self:_initializePlayerSeekerTracking(player)
    end)

    -- Initialize existing players
    for _, player in Players:GetPlayers() do
        self:_initializePlayerSeekerTracking(player)
    end

    -- Handle player leaving mid-game
    Players.PlayerRemoving:Connect(function(player)
        self:_handlePlayerLeave(player)
        -- Clean up seeker tracking
        self._roundsSinceSeeker[player.UserId] = nil
    end)

    print("[TeamService] Started")
end

--[[
    Initialize seeker tracking for a new player
    New players get the average wait time of existing players so they're treated fairly
]]
function TeamService:_initializePlayerSeekerTracking(player: Player)
    -- Calculate average rounds-since-seeker for existing players
    local total = 0
    local count = 0
    for _, rounds in self._roundsSinceSeeker do
        total += rounds
        count += 1
    end

    -- New players start with the average (or 0 if no data yet)
    local averageWait = count > 0 and math.floor(total / count) or 0
    self._roundsSinceSeeker[player.UserId] = averageWait

    print(string.format("[TeamService] Initialized seeker tracking for %s with wait: %d",
        player.Name, averageWait))
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
    Uses fair selection to ensure all players get turns as seeker
]]
function TeamService:FinalizeTeams()
    local allPlayers = Players:GetPlayers()

    if #allPlayers < Constants.MIN_PLAYERS then
        print("[TeamService] Not enough players to finalize teams")
        return
    end

    -- Increment round counter
    self._currentRoundNumber += 1

    -- Select seekers fairly based on who has waited longest
    local selectedSeekers = self:_selectSeekersFairly(allPlayers, Constants.SEEKER_COUNT)

    -- Assign teams
    self._seekers = {}
    self._runners = {}

    local seekerTeam = Teams:FindFirstChild("Seekers") :: Team?
    local runnerTeam = Teams:FindFirstChild("Runners") :: Team?

    for _, player in allPlayers do
        if table.find(selectedSeekers, player) then
            table.insert(self._seekers, player)
            if seekerTeam then
                player.Team = seekerTeam
            end
            -- Reset their wait counter since they're seeker now
            self._roundsSinceSeeker[player.UserId] = 0
            self.Client.TeamAssigned:Fire(player, Enums.PlayerRole.Seeker)
            self._teamAssignedSignal:Fire(player, Enums.PlayerRole.Seeker)
        else
            table.insert(self._runners, player)
            if runnerTeam then
                player.Team = runnerTeam
            end
            -- Increment their wait counter
            local currentWait = self._roundsSinceSeeker[player.UserId] or 0
            self._roundsSinceSeeker[player.UserId] = currentWait + 1
            self.Client.TeamAssigned:Fire(player, Enums.PlayerRole.Runner)
            self._teamAssignedSignal:Fire(player, Enums.PlayerRole.Runner)
        end
    end

    -- Notify all clients of final teams
    self.Client.TeamsUpdated:FireAll(self:_serializeTeams())

    print(string.format("[TeamService] Teams finalized: %d seekers, %d runners (Round %d)",
        #self._seekers, #self._runners, self._currentRoundNumber))
end

--[[
    Select seekers fairly using weighted random selection
    Players who have waited longer have higher chance to be selected
]]
function TeamService:_selectSeekersFairly(players: { Player }, count: number): { Player }
    local selected = {}
    local candidates = table.clone(players)

    for _ = 1, math.min(count, #candidates) do
        if #candidates == 0 then
            break
        end

        -- Build weighted selection pool
        -- Weight = roundsSinceSeeker + 1 (so everyone has at least weight 1)
        local totalWeight = 0
        local weights = {}

        for i, player in candidates do
            local wait = self._roundsSinceSeeker[player.UserId] or 0
            local weight = wait + 1
            weights[i] = weight
            totalWeight += weight
        end

        -- Random weighted selection
        local roll = math.random() * totalWeight
        local cumulative = 0
        local selectedIndex = 1

        for i, weight in weights do
            cumulative += weight
            if roll <= cumulative then
                selectedIndex = i
                break
            end
        end

        -- Add to selected and remove from candidates
        local chosenPlayer = candidates[selectedIndex]
        table.insert(selected, chosenPlayer)
        table.remove(candidates, selectedIndex)

        print(string.format("[TeamService] Selected %s as seeker (waited %d rounds)",
            chosenPlayer.Name, self._roundsSinceSeeker[chosenPlayer.UserId] or 0))
    end

    return selected
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

--[[
    Subscribe to player team assignment changes (server-side)
    Callback receives (player: Player, role: string)
]]
function TeamService:OnPlayerTeamChanged(callback: (Player, string) -> ())
    return self._teamAssignedSignal:Connect(callback)
end

-- Client methods
function TeamService.Client:GetMyRole(player: Player): string
    return self.Server:GetPlayerRole(player)
end

function TeamService.Client:GetTeams(): { seekers: { number }, runners: { number } }
    return self.Server:_serializeTeams()
end

return TeamService
