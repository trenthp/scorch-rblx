--!strict
--[[
    QueueController.lua
    Client-side queue state management and UI coordination

    Mirrors queue state locally, provides UI-friendly methods,
    and fires local signals for UI updates.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Constants = require(Shared:WaitForChild("Constants"))

local LocalPlayer = Players.LocalPlayer

local QueueController = Knit.CreateController({
    Name = "QueueController",

    _queueState = Enums.QueueState.NotQueued :: string,
    _queuedCount = 0,

    _queueStateChangedSignal = nil :: any,
    _queueCountChangedSignal = nil :: any,
})

function QueueController:KnitInit()
    self._queueStateChangedSignal = Signal.new()
    self._queueCountChangedSignal = Signal.new()
    print("[QueueController] Initialized")
end

function QueueController:KnitStart()
    local QueueService = Knit.GetService("QueueService")

    -- Listen for queue state changes
    QueueService.QueueStateChanged:Connect(function(newState)
        print("[QueueController] QueueStateChanged signal received:", newState)
        self._queueState = newState
        self._queueStateChangedSignal:Fire(newState)
    end)

    -- Listen for queue count changes
    QueueService.QueueCountChanged:Connect(function(count)
        print("[QueueController] QueueCountChanged signal received:", count)
        self._queuedCount = count
        self._queueCountChangedSignal:Fire(count)
    end)

    -- Fetch initial state (Knit returns Promises for client-to-server calls)
    task.spawn(function()
        local stateSuccess, state = pcall(function()
            return QueueService:GetMyQueueState():expect()
        end)
        if stateSuccess then
            print("[QueueController] Initial queue state:", state)
            self._queueState = state
            self._queueStateChangedSignal:Fire(self._queueState)
        else
            warn("[QueueController] Failed to get initial queue state:", state)
        end

        local countSuccess, count = pcall(function()
            return QueueService:GetQueuedCount():expect()
        end)
        if countSuccess then
            print("[QueueController] Initial queue count:", count)
            self._queuedCount = count
            self._queueCountChangedSignal:Fire(self._queuedCount)
        else
            warn("[QueueController] Failed to get initial queue count:", count)
        end
    end)

    print("[QueueController] Started")
end

--[[
    Join the queue
    @return boolean - Whether the operation succeeded
]]
function QueueController:JoinQueue(): boolean
    print("[QueueController] JoinQueue called!")
    local QueueService = Knit.GetService("QueueService")
    print("[QueueController] Got QueueService, calling server JoinQueue...")
    local success, result = pcall(function()
        return QueueService:JoinQueue():expect()
    end)
    if success then
        print("[QueueController] Server JoinQueue returned:", result)
        return result
    else
        warn("[QueueController] Server JoinQueue failed:", result)
        return false
    end
end

--[[
    Leave the queue (before round starts)
    @return boolean - Whether the operation succeeded
]]
function QueueController:LeaveQueue(): boolean
    print("[QueueController] LeaveQueue called!")
    local QueueService = Knit.GetService("QueueService")
    local success, result = pcall(function()
        return QueueService:LeaveQueue():expect()
    end)
    if success then
        print("[QueueController] Server LeaveQueue returned:", result)
        return result
    else
        warn("[QueueController] Server LeaveQueue failed:", result)
        return false
    end
end

--[[
    Leave the active game (mid-round)
    @return boolean - Whether the operation succeeded
]]
function QueueController:LeaveGame(): boolean
    print("[QueueController] LeaveGame called!")
    local QueueService = Knit.GetService("QueueService")
    local success, result = pcall(function()
        return QueueService:LeaveGame():expect()
    end)
    if success then
        print("[QueueController] Server LeaveGame returned:", result)
        return result
    else
        warn("[QueueController] Server LeaveGame failed:", result)
        return false
    end
end

--[[
    Get current queue state
]]
function QueueController:GetQueueState(): string
    return self._queueState
end

--[[
    Get current queued player count
]]
function QueueController:GetQueuedCount(): number
    return self._queuedCount
end

--[[
    Check if player is not queued
]]
function QueueController:IsNotQueued(): boolean
    return self._queueState == Enums.QueueState.NotQueued
end

--[[
    Check if player is queued (waiting for round)
]]
function QueueController:IsQueued(): boolean
    return self._queueState == Enums.QueueState.Queued
end

--[[
    Check if player is in active game
]]
function QueueController:IsInGame(): boolean
    return self._queueState == Enums.QueueState.InGame
end

--[[
    Get the minimum players needed
]]
function QueueController:GetMinPlayers(): number
    return Constants.MIN_PLAYERS
end

--[[
    Check if there are enough players to start
]]
function QueueController:HasEnoughPlayers(): boolean
    return self._queuedCount >= Constants.MIN_PLAYERS
end

--[[
    Get formatted queue status text for UI
]]
function QueueController:GetQueueStatusText(): string
    if self._queueState == Enums.QueueState.NotQueued then
        return "Not in queue"
    elseif self._queueState == Enums.QueueState.Queued then
        if self._queuedCount >= Constants.MIN_PLAYERS then
            return "Starting soon..."
        else
            return string.format("Waiting... %d/%d players", self._queuedCount, Constants.MIN_PLAYERS)
        end
    elseif self._queueState == Enums.QueueState.InGame then
        return "In game"
    end
    return ""
end

--[[
    Subscribe to queue state changes
]]
function QueueController:OnQueueStateChanged(callback: (newState: string) -> ())
    return self._queueStateChangedSignal:Connect(callback)
end

--[[
    Subscribe to queue count changes
]]
function QueueController:OnQueueCountChanged(callback: (count: number) -> ())
    return self._queueCountChangedSignal:Connect(callback)
end

return QueueController
