--!strict
--[[
    GameStateService.lua
    Manages the core game state machine
    States: LOBBY → TEAM_SELECTION → COUNTDOWN → GAMEPLAY → RESULTS → (loop)
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
    elseif state == Enums.GameState.COUNTDOWN then
        self:_startCountdown()
    elseif state == Enums.GameState.GAMEPLAY then
        self:_startGameplay()
    elseif state == Enums.GameState.RESULTS then
        self:_startResults()
    end
end

--[[
    Check if there are enough players to start
]]
function GameStateService:_startLobbyCheck()
    task.spawn(function()
        while self._currentState == Enums.GameState.LOBBY do
            local playerCount = #Players:GetPlayers()
            if playerCount >= Constants.MIN_PLAYERS then
                self:SetState(Enums.GameState.TEAM_SELECTION)
                return
            end
            task.wait(1)
        end
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

        -- Wait for team selection duration
        task.wait(Constants.TEAM_SELECTION_DURATION)

        -- Only proceed if still in team selection
        if self._currentState == Enums.GameState.TEAM_SELECTION then
            TeamService:FinalizeTeams()
            self:SetState(Enums.GameState.COUNTDOWN)
        end
    end)
end

--[[
    Handle countdown before gameplay
]]
function GameStateService:_startCountdown()
    task.spawn(function()
        local RoundService = Knit.GetService("RoundService")
        RoundService:StartCountdown()

        task.wait(Constants.COUNTDOWN_DURATION)

        if self._currentState == Enums.GameState.COUNTDOWN then
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
]]
function GameStateService:_startResults()
    task.spawn(function()
        task.wait(Constants.RESULTS_DURATION)

        if self._currentState == Enums.GameState.RESULTS then
            -- Reset for next round
            local TeamService = Knit.GetService("TeamService")
            TeamService:ResetTeams()

            -- Check player count before returning to appropriate state
            local playerCount = #Players:GetPlayers()
            if playerCount >= Constants.MIN_PLAYERS then
                self:SetState(Enums.GameState.TEAM_SELECTION)
            else
                self:SetState(Enums.GameState.LOBBY)
            end
        end
    end)
end

-- Client methods
function GameStateService.Client:GetState(): string
    return self.Server:GetState()
end

return GameStateService
