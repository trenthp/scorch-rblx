--!strict
--[[
    NameTagController.lua
    Hides enemy team player names during gameplay rounds
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))

local LocalPlayer = Players.LocalPlayer

local NameTagController = Knit.CreateController({
    Name = "NameTagController",

    _connections = {} :: { [Player]: RBXScriptConnection },
    _isGameplay = false,
})

function NameTagController:KnitInit()
    print("[NameTagController] Initialized")
end

function NameTagController:KnitStart()
    local GameStateController = Knit.GetController("GameStateController")

    -- Listen for state changes
    GameStateController:OnStateChanged(function(newState, oldState)
        self:_onGameStateChanged(newState, oldState)
    end)

    -- Handle existing players
    for _, player in Players:GetPlayers() do
        self:_setupPlayer(player)
    end

    -- Handle new players joining
    Players.PlayerAdded:Connect(function(player)
        self:_setupPlayer(player)
    end)

    -- Handle players leaving
    Players.PlayerRemoving:Connect(function(player)
        self:_cleanupPlayer(player)
    end)

    -- Check initial state
    local currentState = GameStateController:GetState()
    if currentState == Enums.GameState.GAMEPLAY then
        self._isGameplay = true
        self:_updateAllNameTags()
    end

    print("[NameTagController] Started")
end

--[[
    Handle game state changes
]]
function NameTagController:_onGameStateChanged(newState: string, _oldState: string)
    local wasGameplay = self._isGameplay
    self._isGameplay = (newState == Enums.GameState.GAMEPLAY)

    -- Update name tags when entering or leaving gameplay
    if self._isGameplay ~= wasGameplay then
        self:_updateAllNameTags()
    end
end

--[[
    Setup a player for name tag tracking
]]
function NameTagController:_setupPlayer(player: Player)
    if player == LocalPlayer then
        return -- Don't need to track local player
    end

    -- Handle current character
    if player.Character then
        self:_updatePlayerNameTag(player)
    end

    -- Handle character respawns
    local connection = player.CharacterAdded:Connect(function(_character)
        task.defer(function()
            self:_updatePlayerNameTag(player)
        end)
    end)

    self._connections[player] = connection
end

--[[
    Cleanup player connections
]]
function NameTagController:_cleanupPlayer(player: Player)
    local connection = self._connections[player]
    if connection then
        connection:Disconnect()
        self._connections[player] = nil
    end
end

--[[
    Update all player name tags
]]
function NameTagController:_updateAllNameTags()
    for _, player in Players:GetPlayers() do
        if player ~= LocalPlayer then
            self:_updatePlayerNameTag(player)
        end
    end
end

--[[
    Update a single player's name tag visibility
]]
function NameTagController:_updatePlayerNameTag(player: Player)
    local character = player.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    if self._isGameplay then
        -- During gameplay, check if enemy team
        local isEnemy = self:_isEnemyTeam(player)
        if isEnemy then
            -- Hide name for enemies
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        else
            -- Show name for teammates
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
            humanoid.NameDisplayDistance = 100
            humanoid.HealthDisplayDistance = 0 -- Hide health bar
        end
    else
        -- Outside gameplay, show all names
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
        humanoid.NameDisplayDistance = 100
        humanoid.HealthDisplayDistance = 0
    end
end

--[[
    Check if a player is on the enemy team relative to local player
]]
function NameTagController:_isEnemyTeam(otherPlayer: Player): boolean
    local GameStateController = Knit.GetController("GameStateController")
    local myRole = GameStateController:GetMyRole()

    -- Get other player's team
    local myTeam = LocalPlayer.Team
    local otherTeam = otherPlayer.Team

    -- If either has no team, consider them not enemy (spectator scenario)
    if not myTeam or not otherTeam then
        return false
    end

    -- Different teams = enemy
    return myTeam ~= otherTeam
end

return NameTagController
