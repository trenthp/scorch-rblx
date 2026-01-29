--!strict
--[[
    FlashlightController.lua
    Client-side flashlight visuals and input handling
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

local LocalPlayer = Players.LocalPlayer

type FlashlightVisual = {
    spotlight: SpotLight,
    beam: Beam?,
    attachment0: Attachment,
    attachment1: Attachment?,
}

local FlashlightController = Knit.CreateController({
    Name = "FlashlightController",

    _trove = nil :: any,
    _flashlightVisuals = {} :: { [Player]: FlashlightVisual },
    _isEnabled = false,
    _updateConnection = nil :: RBXScriptConnection?,
})

function FlashlightController:KnitInit()
    self._trove = Trove.new()
    self._flashlightVisuals = {}
    print("[FlashlightController] Initialized")
end

function FlashlightController:KnitStart()
    local FlashlightService = Knit.GetService("FlashlightService")
    local GameStateService = Knit.GetService("GameStateService")

    -- Listen for flashlight toggle events
    FlashlightService.FlashlightToggled:Connect(function(player, enabled)
        self:_onFlashlightToggled(player, enabled)
    end)

    -- Listen for game state changes
    GameStateService.GameStateChanged:Connect(function(newState)
        if newState ~= Enums.GameState.GAMEPLAY then
            self:_cleanupAllFlashlights()
        end
    end)

    -- Start update loop for local player flashlight direction
    self:_startDirectionUpdate()

    print("[FlashlightController] Started")
end

--[[
    Toggle the local player's flashlight
    Called by InputController
]]
function FlashlightController:ToggleFlashlight()
    local GameStateController = Knit.GetController("GameStateController")

    -- Only seekers can use flashlight
    if not GameStateController:AmISeeker() then
        return
    end

    -- Only during gameplay
    if GameStateController:GetState() ~= Enums.GameState.GAMEPLAY then
        return
    end

    local FlashlightService = Knit.GetService("FlashlightService")
    FlashlightService:ToggleFlashlight()
end

--[[
    Handle flashlight toggle event from server
]]
function FlashlightController:_onFlashlightToggled(player: Player, enabled: boolean)
    if enabled then
        self:_createFlashlightVisual(player)
    else
        self:_removeFlashlightVisual(player)
    end

    if player == LocalPlayer then
        self._isEnabled = enabled
    end
end

--[[
    Create flashlight visual for a player
]]
function FlashlightController:_createFlashlightVisual(player: Player)
    -- Remove existing first
    self:_removeFlashlightVisual(player)

    local character = player.Character
    if not character then
        return
    end

    local head = character:FindFirstChild("Head") :: BasePart?
    if not head then
        return
    end

    -- Create attachment for spotlight
    local attachment = Instance.new("Attachment")
    attachment.Name = "FlashlightAttachment"
    attachment.Position = Vector3.new(0, 0, -0.5) -- Slightly in front of face
    attachment.Parent = head

    -- Create spotlight
    local spotlight = Instance.new("SpotLight")
    spotlight.Name = "Flashlight"
    spotlight.Brightness = Constants.FLASHLIGHT_BRIGHTNESS
    spotlight.Color = Constants.FLASHLIGHT_COLOR
    spotlight.Range = Constants.FLASHLIGHT_RANGE
    spotlight.Angle = Constants.FLASHLIGHT_ANGLE
    spotlight.Face = Enum.NormalId.Front
    spotlight.Shadows = true
    spotlight.Parent = head

    -- Create beam effect for visual cone (optional visual enhancement)
    local beamAttachment = Instance.new("Attachment")
    beamAttachment.Name = "FlashlightBeamEnd"
    beamAttachment.WorldPosition = head.Position + (head.CFrame.LookVector * Constants.FLASHLIGHT_RANGE)
    beamAttachment.Parent = workspace.Terrain

    local beam = Instance.new("Beam")
    beam.Name = "FlashlightBeam"
    beam.Attachment0 = attachment
    beam.Attachment1 = beamAttachment
    beam.Color = ColorSequence.new(Constants.FLASHLIGHT_COLOR)
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, 1),
    })
    beam.Width0 = 0.5
    beam.Width1 = Constants.FLASHLIGHT_RANGE * math.tan(math.rad(Constants.FLASHLIGHT_ANGLE / 2)) * 2
    beam.FaceCamera = true
    beam.LightEmission = 0.5
    beam.LightInfluence = 0
    beam.Parent = head

    self._flashlightVisuals[player] = {
        spotlight = spotlight,
        beam = beam,
        attachment0 = attachment,
        attachment1 = beamAttachment,
    }

    print(string.format("[FlashlightController] Created flashlight visual for %s", player.Name))
end

--[[
    Remove flashlight visual for a player
]]
function FlashlightController:_removeFlashlightVisual(player: Player)
    local visual = self._flashlightVisuals[player]
    if not visual then
        return
    end

    if visual.spotlight then
        visual.spotlight:Destroy()
    end
    if visual.beam then
        visual.beam:Destroy()
    end
    if visual.attachment0 then
        visual.attachment0:Destroy()
    end
    if visual.attachment1 then
        visual.attachment1:Destroy()
    end

    self._flashlightVisuals[player] = nil
    print(string.format("[FlashlightController] Removed flashlight visual for %s", player.Name))
end

--[[
    Clean up all flashlight visuals
]]
function FlashlightController:_cleanupAllFlashlights()
    for player, _ in self._flashlightVisuals do
        self:_removeFlashlightVisual(player)
    end
    self._isEnabled = false
end

--[[
    Start the direction update loop for local player
]]
function FlashlightController:_startDirectionUpdate()
    local FlashlightService = Knit.GetService("FlashlightService")

    self._updateConnection = RunService.Heartbeat:Connect(function()
        if not self._isEnabled then
            return
        end

        local character = LocalPlayer.Character
        if not character then
            return
        end

        local head = character:FindFirstChild("Head") :: BasePart?
        if not head then
            return
        end

        -- Get look direction from camera
        local camera = workspace.CurrentCamera
        if camera then
            local direction = camera.CFrame.LookVector
            FlashlightService:UpdateDirection(direction)

            -- Update beam end position
            local visual = self._flashlightVisuals[LocalPlayer]
            if visual and visual.attachment1 then
                visual.attachment1.WorldPosition = head.Position + (direction * Constants.FLASHLIGHT_RANGE)
            end
        end
    end)

    self._trove:Add(self._updateConnection)
end

--[[
    Check if local player's flashlight is enabled
]]
function FlashlightController:IsEnabled(): boolean
    return self._isEnabled
end

return FlashlightController
