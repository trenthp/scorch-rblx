--!strict
--[[
    FreezeController.lua
    Client-side freeze state visuals and effects
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local LocalPlayer = Players.LocalPlayer

type FreezeVisual = {
    particles: ParticleEmitter?,
    iceOverlay: Part?,
    highlight: Highlight?,
}

local FreezeController = Knit.CreateController({
    Name = "FreezeController",

    _trove = nil :: any,
    _freezeVisuals = {} :: { [Player]: FreezeVisual },
    _localFreezeOverlay = nil :: Frame?,
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

    -- Create local freeze overlay UI
    self:_createFreezeOverlay()

    print("[FreezeController] Started")
end

--[[
    Handle player frozen event
]]
function FreezeController:_onPlayerFrozen(player: Player, frozenBy: Player)
    print(string.format("[FreezeController] %s frozen by %s", player.Name, frozenBy.Name))

    -- Create freeze visual
    self:_createFreezeVisual(player)

    -- If local player is frozen, show overlay
    if player == LocalPlayer then
        self:_showLocalFreezeOverlay(true)
    end
end

--[[
    Handle player unfrozen event
]]
function FreezeController:_onPlayerUnfrozen(player: Player, unfrozenBy: Player)
    print(string.format("[FreezeController] %s unfrozen by %s", player.Name, unfrozenBy.Name))

    -- Remove freeze visual
    self:_removeFreezeVisual(player)

    -- If local player is unfrozen, hide overlay
    if player == LocalPlayer then
        self:_showLocalFreezeOverlay(false)
    end
end

--[[
    Create freeze visual effect for a player
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
    highlight.FillTransparency = Constants.FREEZE_TRANSPARENCY
    highlight.OutlineColor = Color3.fromRGB(200, 230, 255)
    highlight.OutlineTransparency = 0.3
    highlight.Parent = character

    -- Create ice particles
    local particles = Instance.new("ParticleEmitter")
    particles.Name = "FreezeParticles"
    particles.Color = ColorSequence.new(Constants.FREEZE_COLOR)
    particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.5, 0.3),
        NumberSequenceKeypoint.new(1, 0),
    })
    particles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    particles.Lifetime = NumberRange.new(1, 2)
    particles.Rate = 20
    particles.Speed = NumberRange.new(1, 3)
    particles.SpreadAngle = Vector2.new(180, 180)
    particles.RotSpeed = NumberRange.new(-45, 45)
    particles.LightEmission = 0.3
    particles.Parent = humanoidRootPart

    self._freezeVisuals[player] = {
        particles = particles,
        highlight = highlight,
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

    if visual.particles then
        visual.particles:Destroy()
    end
    if visual.iceOverlay then
        visual.iceOverlay:Destroy()
    end
    if visual.highlight then
        visual.highlight:Destroy()
    end

    self._freezeVisuals[player] = nil
end

--[[
    Create the local freeze overlay UI
]]
function FreezeController:_createFreezeOverlay()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FreezeOverlay"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 100
    screenGui.Parent = playerGui

    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Constants.FREEZE_COLOR
    overlay.BackgroundTransparency = 1 -- Start invisible
    overlay.BorderSizePixel = 0
    overlay.Parent = screenGui

    -- Add frost pattern (gradient)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 220, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 200, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 220, 255)),
    })
    gradient.Rotation = 45
    gradient.Parent = overlay

    -- Frozen text
    local frozenText = Instance.new("TextLabel")
    frozenText.Name = "FrozenText"
    frozenText.Size = UDim2.new(1, 0, 0, 50)
    frozenText.Position = UDim2.new(0, 0, 0.4, 0)
    frozenText.BackgroundTransparency = 1
    frozenText.Text = "FROZEN"
    frozenText.TextColor3 = Color3.fromRGB(255, 255, 255)
    frozenText.TextStrokeColor3 = Color3.fromRGB(100, 150, 200)
    frozenText.TextStrokeTransparency = 0.5
    frozenText.TextSize = 48
    frozenText.Font = Enum.Font.GothamBold
    frozenText.TextTransparency = 1 -- Start invisible
    frozenText.Parent = overlay

    local helpText = Instance.new("TextLabel")
    helpText.Name = "HelpText"
    helpText.Size = UDim2.new(1, 0, 0, 30)
    helpText.Position = UDim2.new(0, 0, 0.5, 0)
    helpText.BackgroundTransparency = 1
    helpText.Text = "Wait for a teammate to rescue you!"
    helpText.TextColor3 = Color3.fromRGB(220, 240, 255)
    helpText.TextStrokeTransparency = 0.7
    helpText.TextSize = 24
    helpText.Font = Enum.Font.Gotham
    helpText.TextTransparency = 1 -- Start invisible
    helpText.Parent = overlay

    self._localFreezeOverlay = overlay
    self._trove:Add(screenGui)
end

--[[
    Show or hide the local freeze overlay
]]
function FreezeController:_showLocalFreezeOverlay(show: boolean)
    if not self._localFreezeOverlay then
        return
    end

    local targetTransparency = if show then 0.6 else 1
    local textTransparency = if show then 0 else 1

    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    TweenService:Create(self._localFreezeOverlay, tweenInfo, {
        BackgroundTransparency = targetTransparency,
    }):Play()

    local frozenText = self._localFreezeOverlay:FindFirstChild("FrozenText") :: TextLabel?
    local helpText = self._localFreezeOverlay:FindFirstChild("HelpText") :: TextLabel?

    if frozenText then
        TweenService:Create(frozenText, tweenInfo, {
            TextTransparency = textTransparency,
        }):Play()
    end

    if helpText then
        TweenService:Create(helpText, tweenInfo, {
            TextTransparency = textTransparency,
        }):Play()
    end
end

return FreezeController
