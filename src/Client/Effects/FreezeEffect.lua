--!strict
--[[
    FreezeEffect.lua
    Creates and manages the visual freeze effect on players
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

export type FreezeEffectObject = {
    highlight: Highlight,
    particles: ParticleEmitter?,
    iceBlock: Part?,
    destroy: (self: FreezeEffectObject) -> (),
    pulse: (self: FreezeEffectObject) -> (),
}

local FreezeEffect = {}
FreezeEffect.__index = FreezeEffect

--[[
    Create a new freeze effect on a character
    @param character - The character to apply the effect to
    @return FreezeEffectObject
]]
function FreezeEffect.new(character: Model): FreezeEffectObject?
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not humanoidRootPart then
        return nil
    end

    local self = setmetatable({}, FreezeEffect)

    -- Create highlight
    self.highlight = Instance.new("Highlight")
    self.highlight.Name = "FreezeHighlight"
    self.highlight.Adornee = character
    self.highlight.FillColor = Constants.FREEZE_COLOR
    self.highlight.FillTransparency = Constants.FREEZE_TRANSPARENCY
    self.highlight.OutlineColor = Color3.fromRGB(200, 230, 255)
    self.highlight.OutlineTransparency = 0.2
    self.highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    self.highlight.Parent = character

    -- Create ice particles
    self.particles = Instance.new("ParticleEmitter")
    self.particles.Name = "FreezeParticles"

    -- Particle colors (ice blue to white)
    self.particles.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 220, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 240, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    })

    -- Size over lifetime
    self.particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.05),
        NumberSequenceKeypoint.new(0.3, 0.2),
        NumberSequenceKeypoint.new(1, 0),
    })

    -- Transparency
    self.particles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.7, 0.6),
        NumberSequenceKeypoint.new(1, 1),
    })

    self.particles.Lifetime = NumberRange.new(1.5, 3)
    self.particles.Rate = 30
    self.particles.Speed = NumberRange.new(0.5, 2)
    self.particles.SpreadAngle = Vector2.new(180, 180)
    self.particles.RotSpeed = NumberRange.new(-90, 90)
    self.particles.Rotation = NumberRange.new(0, 360)
    self.particles.LightEmission = 0.4
    self.particles.LightInfluence = 0.3
    self.particles.Drag = 1
    self.particles.Acceleration = Vector3.new(0, -0.5, 0)

    -- Texture (snowflake/sparkle)
    self.particles.Texture = "rbxassetid://6490035152" -- Sparkle texture

    self.particles.Parent = humanoidRootPart

    -- Create semi-transparent ice block around character (optional enhancement)
    self.iceBlock = Instance.new("Part")
    self.iceBlock.Name = "IceBlock"
    self.iceBlock.Size = Vector3.new(4, 6, 4)
    self.iceBlock.CFrame = humanoidRootPart.CFrame
    self.iceBlock.Anchored = true
    self.iceBlock.CanCollide = false
    self.iceBlock.CanQuery = false
    self.iceBlock.CanTouch = false
    self.iceBlock.Transparency = 0.85
    self.iceBlock.Color = Constants.FREEZE_COLOR
    self.iceBlock.Material = Enum.Material.Ice
    self.iceBlock.CastShadow = false
    self.iceBlock.Parent = character

    -- Weld ice block to character
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = humanoidRootPart
    weld.Part1 = self.iceBlock
    weld.Parent = self.iceBlock

    -- Initial appear animation
    self:_animateAppear()

    return self :: FreezeEffectObject
end

--[[
    Animate the freeze effect appearing
]]
function FreezeEffect:_animateAppear()
    -- Flash the highlight
    if self.highlight then
        self.highlight.FillTransparency = 0
        TweenService:Create(self.highlight, TweenInfo.new(0.5), {
            FillTransparency = Constants.FREEZE_TRANSPARENCY,
        }):Play()
    end

    -- Scale up ice block
    if self.iceBlock then
        local targetSize = self.iceBlock.Size
        self.iceBlock.Size = Vector3.new(0.5, 0.5, 0.5)
        TweenService:Create(self.iceBlock, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
            Size = targetSize,
        }):Play()
    end
end

--[[
    Create a pulsing effect (for visual feedback)
]]
function FreezeEffect:pulse()
    if self.highlight then
        local originalTransparency = self.highlight.FillTransparency
        self.highlight.FillTransparency = 0.1

        TweenService:Create(self.highlight, TweenInfo.new(0.3), {
            FillTransparency = originalTransparency,
        }):Play()
    end
end

--[[
    Clean up and destroy the effect
]]
function FreezeEffect:destroy()
    -- Animate out
    if self.highlight then
        TweenService:Create(self.highlight, TweenInfo.new(0.3), {
            FillTransparency = 1,
            OutlineTransparency = 1,
        }):Play()
    end

    if self.iceBlock then
        TweenService:Create(self.iceBlock, TweenInfo.new(0.3), {
            Size = Vector3.new(0.5, 0.5, 0.5),
            Transparency = 1,
        }):Play()
    end

    -- Destroy after animation
    task.delay(0.35, function()
        if self.highlight then
            self.highlight:Destroy()
        end
        if self.particles then
            self.particles:Destroy()
        end
        if self.iceBlock then
            self.iceBlock:Destroy()
        end
    end)
end

return FreezeEffect
