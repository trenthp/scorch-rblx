--!strict
--[[
    FlashlightBeam.lua
    Creates and manages the visual flashlight beam effect
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

export type FlashlightBeamObject = {
    spotlight: SpotLight,
    beam: Beam?,
    startAttachment: Attachment,
    endAttachment: Attachment?,
    destroy: (self: FlashlightBeamObject) -> (),
    updateDirection: (self: FlashlightBeamObject, direction: Vector3) -> (),
    setEnabled: (self: FlashlightBeamObject, enabled: boolean) -> (),
}

local FlashlightBeam = {}
FlashlightBeam.__index = FlashlightBeam

--[[
    Create a new flashlight beam attached to a character
    @param character - The character to attach the beam to
    @return FlashlightBeamObject
]]
function FlashlightBeam.new(character: Model): FlashlightBeamObject?
    local head = character:FindFirstChild("Head") :: BasePart?
    if not head then
        return nil
    end

    local self = setmetatable({}, FlashlightBeam)

    -- Create start attachment on head
    self.startAttachment = Instance.new("Attachment")
    self.startAttachment.Name = "FlashlightStart"
    self.startAttachment.Position = Vector3.new(0, 0, -0.5)
    self.startAttachment.Parent = head

    -- Create spotlight
    self.spotlight = Instance.new("SpotLight")
    self.spotlight.Name = "FlashlightSpot"
    self.spotlight.Brightness = Constants.FLASHLIGHT_BRIGHTNESS
    self.spotlight.Color = Constants.FLASHLIGHT_COLOR
    self.spotlight.Range = Constants.FLASHLIGHT_RANGE
    self.spotlight.Angle = Constants.FLASHLIGHT_ANGLE
    self.spotlight.Face = Enum.NormalId.Front
    self.spotlight.Shadows = true
    self.spotlight.Parent = head

    -- Create end attachment for beam (in terrain so it can move freely)
    self.endAttachment = Instance.new("Attachment")
    self.endAttachment.Name = "FlashlightEnd"
    self.endAttachment.WorldPosition = head.Position + Vector3.new(0, 0, -Constants.FLASHLIGHT_RANGE)
    self.endAttachment.Parent = workspace.Terrain

    -- Create volumetric beam
    self.beam = Instance.new("Beam")
    self.beam.Name = "FlashlightBeam"
    self.beam.Attachment0 = self.startAttachment
    self.beam.Attachment1 = self.endAttachment

    -- Beam appearance
    self.beam.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Constants.FLASHLIGHT_COLOR),
        ColorSequenceKeypoint.new(1, Constants.FLASHLIGHT_COLOR),
    })

    self.beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.7),
        NumberSequenceKeypoint.new(0.5, 0.85),
        NumberSequenceKeypoint.new(1, 1),
    })

    -- Calculate end width based on cone angle
    local endRadius = Constants.FLASHLIGHT_RANGE * math.tan(math.rad(Constants.FLASHLIGHT_ANGLE / 2))
    self.beam.Width0 = 0.3
    self.beam.Width1 = endRadius * 2

    self.beam.FaceCamera = true
    self.beam.LightEmission = 0.3
    self.beam.LightInfluence = 0.2
    self.beam.Segments = 10

    self.beam.Parent = head

    return self :: FlashlightBeamObject
end

--[[
    Update the beam direction
    @param direction - The direction the beam should point (unit vector)
]]
function FlashlightBeam:updateDirection(direction: Vector3)
    if not self.endAttachment then
        return
    end

    local character = self.startAttachment.Parent and self.startAttachment.Parent.Parent
    if not character then
        return
    end

    local head = character:FindFirstChild("Head") :: BasePart?
    if not head then
        return
    end

    -- Update end attachment position
    self.endAttachment.WorldPosition = head.Position + (direction.Unit * Constants.FLASHLIGHT_RANGE)
end

--[[
    Enable or disable the beam
    @param enabled - Whether the beam should be visible
]]
function FlashlightBeam:setEnabled(enabled: boolean)
    self.spotlight.Enabled = enabled
    if self.beam then
        self.beam.Enabled = enabled
    end
end

--[[
    Clean up and destroy the beam
]]
function FlashlightBeam:destroy()
    if self.spotlight then
        self.spotlight:Destroy()
    end
    if self.beam then
        self.beam:Destroy()
    end
    if self.startAttachment then
        self.startAttachment:Destroy()
    end
    if self.endAttachment then
        self.endAttachment:Destroy()
    end
end

return FlashlightBeam
