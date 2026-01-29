--!strict
--[[
    FlashlightService.lua
    Server-authoritative flashlight detection
    Checks if runners are in seeker flashlight cones and freezes them
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))
local ConeDetection = require(Shared:WaitForChild("Utils"):WaitForChild("ConeDetection"))

type FlashlightData = {
    enabled: boolean,
    direction: Vector3,
    lastUpdate: number,
}

local FlashlightService = Knit.CreateService({
    Name = "FlashlightService",

    Client = {
        FlashlightToggled = Knit.CreateSignal(),
        FlashlightUpdated = Knit.CreateSignal(),
    },

    _flashlights = {} :: { [Player]: FlashlightData },
    _detectionLoop = nil :: thread?,
})

function FlashlightService:KnitInit()
    self._flashlights = {}
    print("[FlashlightService] Initialized")
end

function FlashlightService:KnitStart()
    -- Clean up on player leave
    Players.PlayerRemoving:Connect(function(player)
        self._flashlights[player] = nil
    end)

    -- Subscribe to game state changes
    local GameStateService = Knit.GetService("GameStateService")
    GameStateService:OnStateChanged(function(newState)
        if newState == Enums.GameState.GAMEPLAY then
            self:_startDetectionLoop()
        else
            self:_stopDetectionLoop()
        end
    end)

    print("[FlashlightService] Started")
end

--[[
    Toggle a player's flashlight
    Called by client when they press the flashlight button
]]
function FlashlightService:ToggleFlashlight(player: Player)
    local TeamService = Knit.GetService("TeamService")

    -- Only seekers can use flashlights
    if not TeamService:IsSeeker(player) then
        return
    end

    local data = self._flashlights[player]
    if not data then
        self._flashlights[player] = {
            enabled = true,
            direction = Vector3.new(0, 0, -1),
            lastUpdate = tick(),
        }
        data = self._flashlights[player]
    else
        data.enabled = not data.enabled
    end

    -- Notify all clients of flashlight state
    self.Client.FlashlightToggled:FireAll(player, data.enabled)

    print(string.format("[FlashlightService] %s flashlight: %s",
        player.Name, data.enabled and "ON" or "OFF"))
end

--[[
    Update a player's flashlight direction
    Called by client to sync look direction
]]
function FlashlightService:UpdateFlashlightDirection(player: Player, direction: Vector3)
    local data = self._flashlights[player]
    if not data then
        return
    end

    -- Validate and normalize direction
    if direction.Magnitude > 0.01 then
        data.direction = direction.Unit
        data.lastUpdate = tick()
    end
end

--[[
    Check if a player's flashlight is enabled
]]
function FlashlightService:IsFlashlightEnabled(player: Player): boolean
    local data = self._flashlights[player]
    return data ~= nil and data.enabled
end

--[[
    Start the detection loop during gameplay
]]
function FlashlightService:_startDetectionLoop()
    if self._detectionLoop then
        return
    end

    print("[FlashlightService] Starting detection loop")

    self._detectionLoop = task.spawn(function()
        while true do
            self:_processFlashlightDetection()
            task.wait(Constants.FLASHLIGHT_CHECK_RATE)
        end
    end)
end

--[[
    Stop the detection loop
]]
function FlashlightService:_stopDetectionLoop()
    if self._detectionLoop then
        task.cancel(self._detectionLoop)
        self._detectionLoop = nil
        print("[FlashlightService] Detection loop stopped")
    end

    -- Turn off all flashlights
    for player, data in self._flashlights do
        if data.enabled then
            data.enabled = false
            self.Client.FlashlightToggled:FireAll(player, false)
        end
    end
end

--[[
    Process flashlight cone detection for all active flashlights
]]
function FlashlightService:_processFlashlightDetection()
    local RoundService = Knit.GetService("RoundService")
    if not RoundService:IsRoundActive() then
        return
    end

    local TeamService = Knit.GetService("TeamService")
    local PlayerStateService = Knit.GetService("PlayerStateService")

    local seekers = TeamService:GetSeekers()
    local runners = TeamService:GetRunners()

    -- Check each seeker's flashlight
    for _, seeker in seekers do
        local flashlightData = self._flashlights[seeker]
        if not flashlightData or not flashlightData.enabled then
            continue
        end

        local seekerCharacter = seeker.Character
        if not seekerCharacter then
            continue
        end

        -- Get flashlight origin (head or HumanoidRootPart)
        local origin = self:_getFlashlightOrigin(seekerCharacter)
        if not origin then
            continue
        end

        -- Build ignore list for raycasts
        local ignoreList = { seekerCharacter }

        -- Check each runner
        for _, runner in runners do
            -- Skip already frozen runners
            if PlayerStateService:IsFrozen(runner) then
                continue
            end

            local runnerCharacter = runner.Character
            if not runnerCharacter then
                continue
            end

            -- Get target position
            local targetPos = ConeDetection.GetCharacterTargetPosition(runnerCharacter)
            if not targetPos then
                continue
            end

            -- Add runner to ignore list for LOS check
            local fullIgnoreList = table.clone(ignoreList)
            table.insert(fullIgnoreList, runnerCharacter)

            -- Check if runner is in flashlight cone with line of sight
            local inCone = ConeDetection.IsTargetInConeWithLOS(
                origin,
                flashlightData.direction,
                targetPos,
                Constants.FLASHLIGHT_RANGE,
                Constants.FLASHLIGHT_ANGLE,
                fullIgnoreList
            )

            if inCone then
                -- Freeze the runner!
                PlayerStateService:FreezePlayer(runner, seeker)
            end
        end
    end
end

--[[
    Get the flashlight origin point from a character
]]
function FlashlightService:_getFlashlightOrigin(character: Model): Vector3?
    -- Prefer head for more accurate aiming
    local head = character:FindFirstChild("Head") :: BasePart?
    if head then
        return head.Position
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if rootPart then
        return rootPart.Position
    end

    return nil
end

-- Client methods
function FlashlightService.Client:ToggleFlashlight(player: Player)
    self.Server:ToggleFlashlight(player)
end

function FlashlightService.Client:UpdateDirection(player: Player, direction: Vector3)
    self.Server:UpdateFlashlightDirection(player, direction)
end

function FlashlightService.Client:IsFlashlightEnabled(player: Player): boolean
    return self.Server:IsFlashlightEnabled(player)
end

return FlashlightService
