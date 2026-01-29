--!strict
--[[
    FreezeService.lua
    Handles unfreezing mechanics - runners can touch frozen teammates to rescue them
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

local FreezeService = Knit.CreateService({
    Name = "FreezeService",

    Client = {},

    _touchConnections = {} :: { [Player]: RBXScriptConnection },
    _unfreezeDebounce = {} :: { [Player]: boolean },
})

function FreezeService:KnitInit()
    self._touchConnections = {}
    self._unfreezeDebounce = {}
    print("[FreezeService] Initialized")
end

function FreezeService:KnitStart()
    -- Subscribe to game state changes
    local GameStateService = Knit.GetService("GameStateService")
    GameStateService:OnStateChanged(function(newState)
        if newState == Enums.GameState.GAMEPLAY then
            self:_setupTouchDetection()
        else
            self:_cleanupTouchDetection()
        end
    end)

    -- Handle character spawns during gameplay
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
            local GameStateService = Knit.GetService("GameStateService")
            if GameStateService:GetState() == Enums.GameState.GAMEPLAY then
                self:_setupPlayerTouchDetection(player)
            end
        end)
    end)

    -- Handle existing players
    for _, player in Players:GetPlayers() do
        player.CharacterAdded:Connect(function()
            local GameStateService = Knit.GetService("GameStateService")
            if GameStateService:GetState() == Enums.GameState.GAMEPLAY then
                self:_setupPlayerTouchDetection(player)
            end
        end)
    end

    print("[FreezeService] Started")
end

--[[
    Set up touch detection for all players
]]
function FreezeService:_setupTouchDetection()
    print("[FreezeService] Setting up touch detection")

    for _, player in Players:GetPlayers() do
        self:_setupPlayerTouchDetection(player)
    end
end

--[[
    Set up touch detection for a single player
]]
function FreezeService:_setupPlayerTouchDetection(player: Player)
    -- Clean up existing connection
    if self._touchConnections[player] then
        self._touchConnections[player]:Disconnect()
    end

    local character = player.Character
    if not character then
        return
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not humanoidRootPart then
        return
    end

    -- Listen for touches on the player
    self._touchConnections[player] = humanoidRootPart.Touched:Connect(function(hit)
        self:_onPlayerTouched(player, hit)
    end)
end

--[[
    Handle when a player's root part is touched
]]
function FreezeService:_onPlayerTouched(touchedPlayer: Player, hitPart: BasePart)
    -- Get the player who touched
    local touchingCharacter = hitPart.Parent
    if not touchingCharacter then
        return
    end

    local touchingPlayer = Players:GetPlayerFromCharacter(touchingCharacter)
    if not touchingPlayer then
        return
    end

    -- Can't unfreeze yourself
    if touchingPlayer == touchedPlayer then
        return
    end

    -- Debounce check
    if self._unfreezeDebounce[touchedPlayer] then
        return
    end

    local TeamService = Knit.GetService("TeamService")
    local PlayerStateService = Knit.GetService("PlayerStateService")

    -- Check if touched player is frozen
    if not PlayerStateService:IsFrozen(touchedPlayer) then
        return
    end

    -- Check if touching player is a runner (only runners can rescue)
    if not TeamService:IsRunner(touchingPlayer) then
        return
    end

    -- Check if touching player is active (not frozen themselves)
    if PlayerStateService:IsFrozen(touchingPlayer) then
        return
    end

    -- Apply debounce
    self._unfreezeDebounce[touchedPlayer] = true
    task.delay(0.5, function()
        self._unfreezeDebounce[touchedPlayer] = nil
    end)

    -- Unfreeze the player!
    PlayerStateService:UnfreezePlayer(touchedPlayer, touchingPlayer)
end

--[[
    Clean up all touch connections
]]
function FreezeService:_cleanupTouchDetection()
    print("[FreezeService] Cleaning up touch detection")

    for player, connection in self._touchConnections do
        connection:Disconnect()
    end

    self._touchConnections = {}
    self._unfreezeDebounce = {}
end

--[[
    Manual unfreeze request from client (not used in current design)
    Could be used for alternative unfreeze mechanics
]]
function FreezeService:RequestUnfreeze(player: Player, targetPlayer: Player)
    local TeamService = Knit.GetService("TeamService")
    local PlayerStateService = Knit.GetService("PlayerStateService")

    -- Validate request
    if not TeamService:IsRunner(player) then
        return false
    end

    if PlayerStateService:IsFrozen(player) then
        return false
    end

    if not PlayerStateService:IsFrozen(targetPlayer) then
        return false
    end

    -- Check distance
    local playerCharacter = player.Character
    local targetCharacter = targetPlayer.Character

    if not playerCharacter or not targetCharacter then
        return false
    end

    local playerRoot = playerCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
    local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?

    if not playerRoot or not targetRoot then
        return false
    end

    local distance = (playerRoot.Position - targetRoot.Position).Magnitude
    if distance > Constants.UNFREEZE_TOUCH_DISTANCE then
        return false
    end

    -- Unfreeze
    PlayerStateService:UnfreezePlayer(targetPlayer, player)
    return true
end

return FreezeService
