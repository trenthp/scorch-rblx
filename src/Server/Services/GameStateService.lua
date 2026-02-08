--!strict
--[[
    GameStateService.lua
    Manages the core game state machine
    States: LOBBY → TEAM_SELECTION → GAMEPLAY → RESULTS → (loop back to TEAM_SELECTION)

    GAMEPLAY has internal phases managed by RoundService:
    - COUNTDOWN: All players frozen, 5 second countdown
    - HIDING: Runners can move, seekers frozen, 15 seconds
    - ACTIVE: Everyone can move, 3 minute timer
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

local GameStateService = Knit.CreateService({
    Name = "GameStateService",

    -- Client-exposed methods and events
    Client = {
        GameStateChanged = Knit.CreateSignal(),
        NextRoundCountdown = Knit.CreateSignal(),
    },

    -- Internal state
    _currentState = Enums.GameState.LOBBY :: string,
    _stateChangedSignal = nil :: any,
})

function GameStateService:KnitInit()
    self._stateChangedSignal = Signal.new()
    print("[GameStateService] Initialized")
end

function GameStateService:KnitStart()
    -- Start checking for enough players to begin
    self:_startLobbyCheck()
    print("[GameStateService] Started")
end

--[[
    Get the current game state
]]
function GameStateService:GetState(): string
    return self._currentState
end

--[[
    Transition to a new state
    @param newState - The state to transition to
]]
function GameStateService:SetState(newState: string)
    local oldState = self._currentState
    if oldState == newState then
        return
    end

    print(string.format("[GameStateService] State transition: %s → %s", oldState, newState))
    self._currentState = newState

    -- Fire internal signal
    self._stateChangedSignal:Fire(newState, oldState)

    -- Fire client signal
    self.Client.GameStateChanged:FireAll(newState, oldState)

    -- Handle state entry
    self:_onStateEnter(newState)
end

--[[
    Subscribe to state changes
    @param callback - Function to call when state changes
    @return Connection
]]
function GameStateService:OnStateChanged(callback: (newState: string, oldState: string) -> ())
    return self._stateChangedSignal:Connect(callback)
end

--[[
    Handle state entry logic
]]
function GameStateService:_onStateEnter(state: string)
    if state == Enums.GameState.LOBBY then
        self:_startLobbyCheck()
    elseif state == Enums.GameState.TEAM_SELECTION then
        self:_startTeamSelection()
    elseif state == Enums.GameState.GAMEPLAY then
        self:_startGameplay()
    elseif state == Enums.GameState.RESULTS then
        self:_startResults()
    end
end

--[[
    Check if there are enough queued players to start
]]
function GameStateService:_startLobbyCheck()
    task.spawn(function()
        -- Wait a moment for all services to be fully started
        task.wait(0.5)

        print("[GameStateService] Starting lobby check loop")

        while self._currentState == Enums.GameState.LOBBY do
            local success, result = pcall(function()
                local QueueService = Knit.GetService("QueueService")
                return QueueService:GetQueuedCount()
            end)

            if success then
                local queuedCount = result
                print(string.format("[GameStateService] Lobby check: %d queued players (need %d)", queuedCount, Constants.MIN_PLAYERS))

                if queuedCount >= Constants.MIN_PLAYERS then
                    local QueueService = Knit.GetService("QueueService")
                    -- Mark queued players as in game before transitioning
                    QueueService:MarkQueuedAsInGame()
                    self:SetState(Enums.GameState.TEAM_SELECTION)
                    return
                end
            else
                warn("[GameStateService] Failed to get queue count:", result)
            end

            task.wait(1)
        end

        print("[GameStateService] Lobby check loop ended (state changed)")
    end)
end

--[[
    Handle team selection phase
]]
function GameStateService:_startTeamSelection()
    task.spawn(function()
        -- Let TeamService handle assignments
        local TeamService = Knit.GetService("TeamService")
        TeamService:StartTeamSelection()

        -- Countdown during team selection
        for i = Constants.TEAM_SELECTION_DURATION, 1, -1 do
            if self._currentState ~= Enums.GameState.TEAM_SELECTION then
                return
            end
            self.Client.NextRoundCountdown:FireAll(i)
            task.wait(1)
        end

        -- Only proceed if still in team selection
        if self._currentState == Enums.GameState.TEAM_SELECTION then
            TeamService:FinalizeTeams()
            self:SetState(Enums.GameState.GAMEPLAY)
        end
    end)
end

--[[
    Handle gameplay start
]]
function GameStateService:_startGameplay()
    local RoundService = Knit.GetService("RoundService")
    RoundService:StartRound()
end

--[[
    Handle results display
    Shows results while counting down, then transitions to team selection
    The countdown shows TOTAL time (results + team selection)
]]
function GameStateService:_startResults()
    task.spawn(function()
        local totalTime = Constants.RESULTS_DURATION + Constants.TEAM_SELECTION_DURATION

        -- Countdown during results phase (starts at total time)
        for i = totalTime, Constants.TEAM_SELECTION_DURATION + 1, -1 do
            if self._currentState ~= Enums.GameState.RESULTS then
                return
            end
            self.Client.NextRoundCountdown:FireAll(i)
            task.wait(1)
        end

        -- Transition to team selection (countdown continues there)
        if self._currentState == Enums.GameState.RESULTS then
            self:_exitResults()
        end
    end)
end

--[[
    Exit results and go to next state
]]
function GameStateService:_exitResults()
    if self._currentState ~= Enums.GameState.RESULTS then
        return
    end

    -- Reset for next round
    local TeamService = Knit.GetService("TeamService")
    TeamService:ResetTeams()

    -- Mark InGame players as Queued (they stay in queue for next round)
    local QueueService = Knit.GetService("QueueService")
    QueueService:MarkInGameAsQueued()

    -- Check queued player count before returning to appropriate state
    local queuedCount = QueueService:GetQueuedCount()
    if queuedCount >= Constants.MIN_PLAYERS then
        -- Mark queued players as in game before transitioning
        QueueService:MarkQueuedAsInGame()
        self:SetState(Enums.GameState.TEAM_SELECTION)
    else
        self:SetState(Enums.GameState.LOBBY)
    end
end

-- Client methods
function GameStateService.Client:GetState(): string
    return self.Server:GetState()
end

return GameStateService
