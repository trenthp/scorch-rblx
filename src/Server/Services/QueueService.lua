--!strict
--[[
    QueueService.lua
    Manages player queue state for opt-in round participation

    Queue States:
    - NotQueued: Player is in lobby, browsing (not participating in rounds)
    - Queued: Player has pressed Play, waiting for enough players
    - InGame: Player is in an active round

    Flow:
    Player Joins → NotQueued
    Press Play → Queued
    2+ Queued → TEAM_SELECTION → InGame
    Round Ends → Queued (auto-continue)
    Leave Game/Queue → NotQueued
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))

local QueueService = Knit.CreateService({
    Name = "QueueService",

    Client = {
        QueueStateChanged = Knit.CreateSignal(),
        QueueCountChanged = Knit.CreateSignal(),
    },

    _playerQueueStates = {} :: { [Player]: string },
    _queueStateChangedSignal = nil :: any,
})

function QueueService:KnitInit()
    self._queueStateChangedSignal = Signal.new()
    self._playerQueueStates = {}
    print("[QueueService] Initialized")
end

function QueueService:KnitStart()
    -- Initialize existing players
    for _, player in Players:GetPlayers() do
        self:_initializePlayer(player)
    end

    -- Handle player joining
    Players.PlayerAdded:Connect(function(player)
        self:_initializePlayer(player)
    end)

    -- Handle player leaving
    Players.PlayerRemoving:Connect(function(player)
        self:_handlePlayerLeave(player)
    end)

    print("[QueueService] Started")
end

--[[
    Initialize a player's queue state
]]
function QueueService:_initializePlayer(player: Player)
    self._playerQueueStates[player] = Enums.QueueState.NotQueued
    print(string.format("[QueueService] Player %s initialized as NotQueued", player.Name))
end

--[[
    Handle player leaving the game
]]
function QueueService:_handlePlayerLeave(player: Player)
    local wasQueued = self:IsQueued(player) or self:IsInGame(player)
    self._playerQueueStates[player] = nil

    -- Broadcast count change if they were in queue/game
    if wasQueued then
        self:_broadcastQueueCount()
    end
end

--[[
    Add player to queue
    @param player - The player to add
    @return boolean - Whether the operation succeeded
]]
function QueueService:JoinQueue(player: Player): boolean
    local currentState = self._playerQueueStates[player]

    if currentState == Enums.QueueState.Queued or currentState == Enums.QueueState.InGame then
        return false -- Already queued or in game
    end

    self._playerQueueStates[player] = Enums.QueueState.Queued

    -- Fire signals
    self._queueStateChangedSignal:Fire(player, Enums.QueueState.Queued)
    self.Client.QueueStateChanged:Fire(player, Enums.QueueState.Queued)
    self:_broadcastQueueCount()

    local currentCount = self:GetQueuedCount()
    print(string.format("[QueueService] %s joined queue (total queued: %d)", player.Name, currentCount))
    return true
end

--[[
    Remove player from queue (before round starts)
    @param player - The player to remove
    @return boolean - Whether the operation succeeded
]]
function QueueService:LeaveQueue(player: Player): boolean
    local currentState = self._playerQueueStates[player]

    if currentState ~= Enums.QueueState.Queued then
        return false -- Not in queue
    end

    self._playerQueueStates[player] = Enums.QueueState.NotQueued

    -- Fire signals
    self._queueStateChangedSignal:Fire(player, Enums.QueueState.NotQueued)
    self.Client.QueueStateChanged:Fire(player, Enums.QueueState.NotQueued)
    self:_broadcastQueueCount()

    print(string.format("[QueueService] %s left queue", player.Name))
    return true
end

--[[
    Remove player from active game (mid-round leave)
    @param player - The player to remove
    @return boolean - Whether the operation succeeded
]]
function QueueService:LeaveGame(player: Player): boolean
    local currentState = self._playerQueueStates[player]

    if currentState ~= Enums.QueueState.InGame then
        return false -- Not in game
    end

    self._playerQueueStates[player] = Enums.QueueState.NotQueued

    -- Handle player state cleanup (unfreeze, remove from teams, check win conditions)
    local PlayerStateService = Knit.GetService("PlayerStateService")
    PlayerStateService:HandlePlayerLeaveGame(player)

    -- Fire signals
    self._queueStateChangedSignal:Fire(player, Enums.QueueState.NotQueued)
    self.Client.QueueStateChanged:Fire(player, Enums.QueueState.NotQueued)
    self:_broadcastQueueCount()

    print(string.format("[QueueService] %s left game mid-round", player.Name))
    return true
end

--[[
    Mark queued players as InGame (called when round starts)
]]
function QueueService:MarkQueuedAsInGame()
    for player, state in self._playerQueueStates do
        if state == Enums.QueueState.Queued then
            self._playerQueueStates[player] = Enums.QueueState.InGame
            self._queueStateChangedSignal:Fire(player, Enums.QueueState.InGame)
            self.Client.QueueStateChanged:Fire(player, Enums.QueueState.InGame)
        end
    end
    print("[QueueService] Marked all queued players as InGame")
end

--[[
    Mark InGame players as Queued (called when round ends, they stay in queue)
]]
function QueueService:MarkInGameAsQueued()
    for player, state in self._playerQueueStates do
        if state == Enums.QueueState.InGame then
            self._playerQueueStates[player] = Enums.QueueState.Queued
            self._queueStateChangedSignal:Fire(player, Enums.QueueState.Queued)
            self.Client.QueueStateChanged:Fire(player, Enums.QueueState.Queued)
        end
    end
    self:_broadcastQueueCount()
    print("[QueueService] Marked all InGame players as Queued (round ended)")
end

--[[
    Get list of queued players
]]
function QueueService:GetQueuedPlayers(): { Player }
    local queued = {}
    for player, state in self._playerQueueStates do
        if state == Enums.QueueState.Queued then
            table.insert(queued, player)
        end
    end
    return queued
end

--[[
    Get list of players who are queued OR in game (for round counting)
]]
function QueueService:GetQueuedOrInGamePlayers(): { Player }
    local players = {}
    for player, state in self._playerQueueStates do
        if state == Enums.QueueState.Queued or state == Enums.QueueState.InGame then
            table.insert(players, player)
        end
    end
    return players
end

--[[
    Get count of queued players
]]
function QueueService:GetQueuedCount(): number
    local count = 0
    for player, state in self._playerQueueStates do
        if state == Enums.QueueState.Queued then
            count += 1
        end
    end
    return count
end

--[[
    Debug: Print all player queue states
]]
function QueueService:DebugPrintStates()
    print("[QueueService] Current player states:")
    for player, state in self._playerQueueStates do
        print(string.format("  - %s: %s", player.Name, state))
    end
end

--[[
    Check if player is queued
]]
function QueueService:IsQueued(player: Player): boolean
    return self._playerQueueStates[player] == Enums.QueueState.Queued
end

--[[
    Check if player is in game
]]
function QueueService:IsInGame(player: Player): boolean
    return self._playerQueueStates[player] == Enums.QueueState.InGame
end

--[[
    Get player's queue state
]]
function QueueService:GetQueueState(player: Player): string
    return self._playerQueueStates[player] or Enums.QueueState.NotQueued
end

--[[
    Subscribe to queue state changes (server-side)
]]
function QueueService:OnQueueStateChanged(callback: (player: Player, newState: string) -> ())
    return self._queueStateChangedSignal:Connect(callback)
end

--[[
    Broadcast queue count to all clients
]]
function QueueService:_broadcastQueueCount()
    local count = self:GetQueuedCount()
    print(string.format("[QueueService] Broadcasting queue count: %d", count))
    self.Client.QueueCountChanged:FireAll(count)
end

-- Client methods
function QueueService.Client:JoinQueue(player: Player): boolean
    return self.Server:JoinQueue(player)
end

function QueueService.Client:LeaveQueue(player: Player): boolean
    return self.Server:LeaveQueue(player)
end

function QueueService.Client:LeaveGame(player: Player): boolean
    return self.Server:LeaveGame(player)
end

function QueueService.Client:GetMyQueueState(player: Player): string
    return self.Server:GetQueueState(player)
end

function QueueService.Client:GetQueuedCount(): number
    return self.Server:GetQueuedCount()
end

return QueueService
