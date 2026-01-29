--!strict
--[[
    FreezeController.lua
    Client-side freeze visual effects on characters (not screen overlay - UIController handles that)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local LocalPlayer = Players.LocalPlayer

type FreezeVisual = {
    highlight: Highlight?,
    particles: ParticleEmitter?,
}

local FreezeController = Knit.CreateController({
    Name = "FreezeController",

    _trove = nil :: any,
    _freezeVisuals = {} :: { [Player]: FreezeVisual },
})

function FreezeController:KnitInit()
    self._trove = Trove.new()
    self._freezeVisuals = {}
    print("[FreezeController] Initialized")
end

function FreezeController:KnitStart()
    local PlayerStateService = Knit.GetService("PlayerStateService")

    -- Listen for freeze/unfreeze events
    PlayerStateService.PlayerFrozen:Connect(function(player, frozenBy)
        self:_onPlayerFrozen(player, frozenBy)
    end)

    PlayerStateService.PlayerUnfrozen:Connect(function(player, unfrozenBy)
        self:_onPlayerUnfrozen(player, unfrozenBy)
    end)

    print("[FreezeController] Started")
end

--[[
    Handle player frozen event - create visual effect on character
]]
function FreezeController:_onPlayerFrozen(player: Player, frozenBy: Player)
    print(string.format("[FreezeController] %s frozen by %s", player.Name, frozenBy.Name))
    self:_createFreezeVisual(player)
end

--[[
    Handle player unfrozen event - remove visual effect
]]
function FreezeController:_onPlayerUnfrozen(player: Player, unfrozenBy: Player)
    print(string.format("[FreezeController] %s unfrozen by %s", player.Name, unfrozenBy.Name))
    self:_removeFreezeVisual(player)
end

--[[
    Create freeze visual effect on a character
]]
function FreezeController:_createFreezeVisual(player: Player)
    -- Remove existing first
    self:_removeFreezeVisual(player)

    local character = player.Character
    if not character then
        return
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not humanoidRootPart then
        return
    end

    -- Create highlight effect
    local highlight = Instance.new("Highlight")
    highlight.Name = "FreezeHighlight"
    highlight.Adornee = character
    highlight.FillColor = Constants.FREEZE_COLOR
    highlight.FillTransparency = 0.4
    highlight.OutlineColor = Color3.fromRGB(200, 230, 255)
    highlight.OutlineTransparency = 0.2
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Parent = character

    -- Create ice particles
    local particles = Instance.new("ParticleEmitter")
    particles.Name = "FreezeParticles"
    particles.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 220, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    })
    particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.5, 0.25),
        NumberSequenceKeypoint.new(1, 0),
    })
    particles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    particles.Lifetime = NumberRange.new(1, 2)
    particles.Rate = 15
    particles.Speed = NumberRange.new(0.5, 1.5)
    particles.SpreadAngle = Vector2.new(180, 180)
    particles.RotSpeed = NumberRange.new(-60, 60)
    particles.LightEmission = 0.3
    particles.Parent = humanoidRootPart

    self._freezeVisuals[player] = {
        highlight = highlight,
        particles = particles,
    }
end

--[[
    Remove freeze visual for a player
]]
function FreezeController:_removeFreezeVisual(player: Player)
    local visual = self._freezeVisuals[player]
    if not visual then
        return
    end

    if visual.highlight then
        visual.highlight:Destroy()
    end
    if visual.particles then
        visual.particles:Destroy()
    end

    self._freezeVisuals[player] = nil
end

return FreezeController
