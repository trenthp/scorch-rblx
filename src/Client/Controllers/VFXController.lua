--!strict
--[[
    VFXController.lua
    Manages visual effects like particles, lighting, and camera effects
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))

local LocalPlayer = Players.LocalPlayer

local VFXController = Knit.CreateController({
    Name = "VFXController",

    _trove = nil :: any,
    _colorCorrection = nil :: ColorCorrectionEffect?,
    _bloom = nil :: BloomEffect?,
})

function VFXController:KnitInit()
    self._trove = Trove.new()
    print("[VFXController] Initialized")
end

function VFXController:KnitStart()
    local GameStateService = Knit.GetService("GameStateService")
    local PlayerStateService = Knit.GetService("PlayerStateService")

    -- Create post-processing effects
    self:_createPostProcessing()

    -- Listen for state changes
    GameStateService.GameStateChanged:Connect(function(newState)
        self:_onStateChanged(newState)
    end)

    -- Listen for freeze state
    PlayerStateService.PlayerFrozen:Connect(function(player)
        if player == LocalPlayer then
            self:_onLocalPlayerFrozen()
        end
    end)

    PlayerStateService.PlayerUnfrozen:Connect(function(player)
        if player == LocalPlayer then
            self:_onLocalPlayerUnfrozen()
        end
    end)

    print("[VFXController] Started")
end

--[[
    Create post-processing effects
]]
function VFXController:_createPostProcessing()
    -- Color correction for atmosphere
    local colorCorrection = Instance.new("ColorCorrectionEffect")
    colorCorrection.Name = "ScorchColorCorrection"
    colorCorrection.Brightness = 0
    colorCorrection.Contrast = 0.1
    colorCorrection.Saturation = -0.1
    colorCorrection.TintColor = Color3.fromRGB(220, 230, 255)
    colorCorrection.Parent = Lighting

    self._colorCorrection = colorCorrection
    self._trove:Add(colorCorrection)

    -- Bloom for flashlight glow
    local bloom = Instance.new("BloomEffect")
    bloom.Name = "ScorchBloom"
    bloom.Intensity = 0.5
    bloom.Size = 24
    bloom.Threshold = 1.5
    bloom.Parent = Lighting

    self._bloom = bloom
    self._trove:Add(bloom)

    -- Depth of field for atmosphere (subtle)
    local dof = Instance.new("DepthOfFieldEffect")
    dof.Name = "ScorchDOF"
    dof.FarIntensity = 0.1
    dof.FocusDistance = 50
    dof.InFocusRadius = 30
    dof.NearIntensity = 0
    dof.Parent = Lighting

    self._trove:Add(dof)
end

--[[
    Handle game state changes
]]
function VFXController:_onStateChanged(newState: string)
    if newState == Enums.GameState.GAMEPLAY then
        self:_setGameplayAtmosphere()
    elseif newState == Enums.GameState.LOBBY then
        self:_setLobbyAtmosphere()
    elseif newState == Enums.GameState.RESULTS then
        self:_setResultsAtmosphere()
    end
end

--[[
    Set dark, tense atmosphere for gameplay
]]
function VFXController:_setGameplayAtmosphere()
    if self._colorCorrection then
        TweenService:Create(self._colorCorrection, TweenInfo.new(2), {
            Brightness = -0.05,
            Contrast = 0.15,
            Saturation = -0.2,
        }):Play()
    end

    -- Darken ambient
    TweenService:Create(Lighting, TweenInfo.new(2), {
        Ambient = Color3.fromRGB(20, 20, 30),
        OutdoorAmbient = Color3.fromRGB(20, 20, 30),
    }):Play()
end

--[[
    Set brighter atmosphere for lobby
]]
function VFXController:_setLobbyAtmosphere()
    if self._colorCorrection then
        TweenService:Create(self._colorCorrection, TweenInfo.new(2), {
            Brightness = 0,
            Contrast = 0.1,
            Saturation = 0,
        }):Play()
    end

    TweenService:Create(Lighting, TweenInfo.new(2), {
        Ambient = Color3.fromRGB(50, 50, 60),
        OutdoorAmbient = Color3.fromRGB(50, 50, 60),
    }):Play()
end

--[[
    Atmosphere for results screen
]]
function VFXController:_setResultsAtmosphere()
    if self._colorCorrection then
        TweenService:Create(self._colorCorrection, TweenInfo.new(1), {
            Brightness = 0.05,
            Contrast = 0.05,
            Saturation = 0.1,
        }):Play()
    end
end

--[[
    Effects when local player is frozen
]]
function VFXController:_onLocalPlayerFrozen()
    if self._colorCorrection then
        TweenService:Create(self._colorCorrection, TweenInfo.new(0.3), {
            Saturation = -0.5,
            TintColor = Color3.fromRGB(180, 200, 255),
        }):Play()
    end
end

--[[
    Effects when local player is unfrozen
]]
function VFXController:_onLocalPlayerUnfrozen()
    if self._colorCorrection then
        TweenService:Create(self._colorCorrection, TweenInfo.new(0.5), {
            Saturation = -0.2,
            TintColor = Color3.fromRGB(220, 230, 255),
        }):Play()
    end
end

--[[
    Flash effect (for dramatic moments)
]]
function VFXController:FlashScreen(color: Color3?, duration: number?)
    local flashColor = color or Color3.fromRGB(255, 255, 255)
    local flashDuration = duration or 0.3

    local playerGui = LocalPlayer:WaitForChild("PlayerGui")

    local flash = Instance.new("ScreenGui")
    flash.Name = "FlashEffect"
    flash.IgnoreGuiInset = true
    flash.DisplayOrder = 999

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = flashColor
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    frame.Parent = flash

    flash.Parent = playerGui

    TweenService:Create(frame, TweenInfo.new(flashDuration), {
        BackgroundTransparency = 1,
    }):Play()

    task.delay(flashDuration, function()
        flash:Destroy()
    end)
end

return VFXController
