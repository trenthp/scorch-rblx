--!strict
--[[
    GameStateController.lua
    Client-side game state management and UI coordination
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))

local LocalPlayer = Players.LocalPlayer

local GameStateController = Knit.CreateController({
    Name = "GameStateController",

    _currentState = Enums.GameState.LOBBY :: string,
    _stateChangedSignal = nil :: any,
    _myRole = Enums.PlayerRole.Spectator :: string,
})

function GameStateController:KnitInit()
    self._stateChangedSignal = Signal.new()
    print("[GameStateController] Initialized")
end

function GameStateController:KnitStart()
    -- Get services
    local GameStateService = Knit.GetService("GameStateService")
    local TeamService = Knit.GetService("TeamService")

    -- Listen for state changes from server
    GameStateService.GameStateChanged:Connect(function(newState, oldState)
        self:_onStateChanged(newState, oldState)
    end)

    -- Listen for team assignment
    TeamService.TeamAssigned:Connect(function(player, role)
        if player == LocalPlayer then
            self._myRole = role
            print(string.format("[GameStateController] My role: %s", role))
        end
    end)

    -- Get initial state
    self._currentState = GameStateService:GetState()
    self._myRole = TeamService:GetMyRole()

    print(string.format("[GameStateController] Started - State: %s, Role: %s",
        self._currentState, self._myRole))
end

--[[
    Handle state change from server
]]
function GameStateController:_onStateChanged(newState: string, oldState: string)
    print(string.format("[GameStateController] State: %s → %s", oldState, newState))

    self._currentState = newState
    self._stateChangedSignal:Fire(newState, oldState)

    -- Notify UI controller
    local UIController = Knit.GetController("UIController")
    if UIController then
        UIController:OnGameStateChanged(newState, oldState)
    end
end

--[[
    Get current game state
]]
function GameStateController:GetState(): string
    return self._currentState
end

--[[
    Get the local player's role
]]
function GameStateController:GetMyRole(): string
    return self._myRole
end

--[[
    Check if local player is a seeker
]]
function GameStateController:AmISeeker(): boolean
    return self._myRole == Enums.PlayerRole.Seeker
end

--[[
    Check if local player is a runner
]]
function GameStateController:AmIRunner(): boolean
    return self._myRole == Enums.PlayerRole.Runner
end

--[[
    Subscribe to state changes
]]
function GameStateController:OnStateChanged(callback: (newState: string, oldState: string) -> ())
    return self._stateChangedSignal:Connect(callback)
end

return GameStateController
