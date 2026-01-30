--!strict
--[[
    BoundaryService.lua
    Handles the freeze zone around the play area perimeter
    - Players who wander outside the play area slowly freeze
    - Encourages players to stay in the play zone
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

local BoundaryService = Knit.CreateService({
    Name = "BoundaryService",

    Client = {
        ColdUpdated = Knit.CreateSignal(), -- Notify client of cold level changes
    },

    _playerCold = {} :: { [Player]: number }, -- 0-100 cold percentage
    _checkLoop = nil :: thread?,
    _isActive = false,
})

function BoundaryService:KnitInit()
    self._playerCold = {}
    print("[BoundaryService] Initialized")
end

function BoundaryService:KnitStart()
    -- Clean up on player leave
    Players.PlayerRemoving:Connect(function(player)
        self._playerCold[player] = nil
    end)

    -- Subscribe to game state changes
    local GameStateService = Knit.GetService("GameStateService")
    GameStateService:OnStateChanged(function(newState)
        if newState == Enums.GameState.GAMEPLAY then
            self:_startBoundaryCheck()
        else
            self:_stopBoundaryCheck()
        end
    end)

    print("[BoundaryService] Started")
end

--[[
    Start checking player positions
]]
function BoundaryService:_startBoundaryCheck()
    if self._checkLoop then
        return
    end

    self._isActive = true
    -- Reset all cold levels
    for player, _ in self._playerCold do
        self._playerCold[player] = 0
        self.Client.ColdUpdated:Fire(player, 0)
    end

    print("[BoundaryService] Starting boundary check")

    self._checkLoop = task.spawn(function()
        while self._isActive do
            self:_updateAllPlayers()
            task.wait(Constants.BOUNDARY.CHECK_RATE)
        end
    end)
end

--[[
    Stop checking player positions
]]
function BoundaryService:_stopBoundaryCheck()
    self._isActive = false

    if self._checkLoop then
        task.cancel(self._checkLoop)
        self._checkLoop = nil
    end

    -- Reset all cold levels
    for player, _ in self._playerCold do
        self._playerCold[player] = 0
        self.Client.ColdUpdated:Fire(player, 0)
    end

    print("[BoundaryService] Stopped boundary check")
end

--[[
    Update cold levels for all players
]]
function BoundaryService:_updateAllPlayers()
    local TeamService = Knit.GetService("TeamService")
    local PlayerStateService = Knit.GetService("PlayerStateService")

    for _, player in Players:GetPlayers() do
        -- Only check players in the game (seekers and runners)
        local role = TeamService:GetPlayerRole(player)
        if role ~= Enums.PlayerRole.Seeker and role ~= Enums.PlayerRole.Runner then
            continue
        end

        -- Skip already frozen players
        if PlayerStateService:IsFrozen(player) then
            continue
        end

        local character = player.Character
        if not character then
            continue
        end

        local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not rootPart then
            continue
        end

        local position = rootPart.Position
        local zone = self:_getPlayerZone(position)

        self:_updatePlayerCold(player, zone)
    end
end

--[[
    Determine which zone the player is in based on position
    Returns: "play", "freeze", or "wall"
]]
function BoundaryService:_getPlayerZone(position: Vector3): string
    -- Use max of X and Z distance from center (square boundary)
    local distanceFromCenter = math.max(math.abs(position.X), math.abs(position.Z))

    if distanceFromCenter <= Constants.BOUNDARY.PLAY_AREA_RADIUS then
        return "play"
    elseif distanceFromCenter <= Constants.BOUNDARY.FREEZE_ZONE_RADIUS then
        return "freeze"
    else
        return "wall"
    end
end

--[[
    Update a player's cold level based on their zone
]]
function BoundaryService:_updatePlayerCold(player: Player, zone: string)
    local currentCold = self._playerCold[player] or 0
    local deltaTime = Constants.BOUNDARY.CHECK_RATE
    local newCold = currentCold

    if zone == "freeze" or zone == "wall" then
        -- Increase cold
        newCold = currentCold + (Constants.BOUNDARY.FREEZE_RATE * deltaTime)
    elseif zone == "play" then
        -- Decrease cold (thaw)
        newCold = currentCold - (Constants.BOUNDARY.THAW_RATE * deltaTime)
    end

    -- Clamp between 0 and 100
    newCold = math.clamp(newCold, 0, 100)

    -- Only update if changed significantly
    if math.abs(newCold - currentCold) > 0.1 then
        self._playerCold[player] = newCold
        self.Client.ColdUpdated:Fire(player, newCold)

        -- Check if fully frozen
        if newCold >= 100 then
            self:_freezePlayer(player)
        end
    end
end

--[[
    Freeze a player who has reached 100% cold
]]
function BoundaryService:_freezePlayer(player: Player)
    local PlayerStateService = Knit.GetService("PlayerStateService")

    -- Use existing freeze system
    PlayerStateService:FreezePlayer(player, nil) -- nil = frozen by boundary, not a seeker

    -- Reset cold after freezing
    self._playerCold[player] = 0
    self.Client.ColdUpdated:Fire(player, 0)

    print(string.format("[BoundaryService] %s frozen by boundary zone", player.Name))
end

--[[
    Get a player's current cold level
]]
function BoundaryService:GetPlayerCold(player: Player): number
    return self._playerCold[player] or 0
end

-- ============================================
-- CLIENT METHODS
-- ============================================

function BoundaryService.Client:GetCold(player: Player): number
    return self.Server:GetPlayerCold(player)
end

return BoundaryService
