--!strict
--[[
    BiomeService.lua
    Manages biome selection, rotation, and application
    Controls lighting, scenery colors, and ambient sounds per biome
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BiomeConfig = require(Shared:WaitForChild("BiomeConfig"))

local BiomeService = Knit.CreateService({
    Name = "BiomeService",

    Client = {
        BiomeChanged = Knit.CreateSignal(),
    },

    _currentBiome = "Forest",
    _roundCount = 0,
    _biomeChangedSignal = nil :: any,
    _atmosphere = nil :: Atmosphere?,
})

function BiomeService:KnitInit()
    self._biomeChangedSignal = Signal.new()

    -- Create or find atmosphere instance
    self._atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not self._atmosphere then
        self._atmosphere = Instance.new("Atmosphere")
        self._atmosphere.Parent = Lighting
    end

    print("[BiomeService] Initialized")
end

function BiomeService:KnitStart()
    -- Apply initial biome
    self:ApplyBiome(self._currentBiome, false)

    -- Listen for round starts to rotate biomes
    local GameStateService = Knit.GetService("GameStateService")
    GameStateService:OnStateChanged(function(newState, _oldState)
        local Enums = require(Shared:WaitForChild("Enums"))
        if newState == Enums.GameState.GAMEPLAY then
            -- Rotate biome each round
            self._roundCount += 1
            if self._roundCount > 1 then -- Don't rotate on first round
                self:RotateBiome()
            end
        end
    end)

    print("[BiomeService] Started")
end

--[[
    Get the current biome
    @return Current biome name
]]
function BiomeService:GetCurrentBiome(): string
    return self._currentBiome
end

--[[
    Set and apply a specific biome
    @param biome - The biome name to set
    @param animate - Whether to animate the transition (default true)
]]
function BiomeService:SetBiome(biome: string, animate: boolean?)
    if self._currentBiome == biome then
        return
    end

    local shouldAnimate = if animate == nil then true else animate
    self:ApplyBiome(biome, shouldAnimate)
end

--[[
    Rotate to the next biome in sequence
]]
function BiomeService:RotateBiome()
    local nextBiome = BiomeConfig.getNextBiome(self._currentBiome)
    self:ApplyBiome(nextBiome, true)
end

--[[
    Apply a biome's settings (lighting, scenery, audio)
    @param biome - The biome name
    @param animate - Whether to animate the transition
]]
function BiomeService:ApplyBiome(biome: string, animate: boolean)
    local config = BiomeConfig.getConfig(biome)
    local oldBiome = self._currentBiome
    self._currentBiome = biome

    print(string.format("[BiomeService] Applying biome: %s (animate: %s)", biome, tostring(animate)))

    -- Apply lighting
    self:_applyLighting(config.lighting, animate)

    -- Apply atmosphere
    self:_applyAtmosphere(config.atmosphereConfig, config.fogEnabled, animate)

    -- Apply ground color
    self:_applyGroundColor(config.colors, animate)

    -- Regenerate scenery with new biome colors
    local SceneryService = Knit.GetService("SceneryService")
    SceneryService:RegenerateWithBiome(biome)

    -- Switch ambient audio
    local AudioService = Knit.GetService("AudioService")
    AudioService:SetBiome(biome)

    -- Fire signals
    self._biomeChangedSignal:Fire(biome, oldBiome)
    self.Client.BiomeChanged:FireAll(biome, oldBiome)
end

--[[
    Apply lighting settings
]]
function BiomeService:_applyLighting(lighting: BiomeConfig.BiomeLighting, animate: boolean)
    local tweenInfo = TweenInfo.new(if animate then 2 else 0, Enum.EasingStyle.Sine)

    local properties = {
        ClockTime = lighting.ClockTime,
        Brightness = lighting.Brightness,
        Ambient = lighting.Ambient,
        OutdoorAmbient = lighting.OutdoorAmbient,
        FogColor = lighting.FogColor,
        FogStart = lighting.FogStart,
        FogEnd = lighting.FogEnd,
    }

    if animate then
        TweenService:Create(Lighting, tweenInfo, properties):Play()
    else
        for prop, value in properties do
            Lighting[prop] = value
        end
    end
end

--[[
    Apply atmosphere settings
]]
function BiomeService:_applyAtmosphere(config: { Density: number, Color: Color3, Haze: number }?, enabled: boolean, animate: boolean)
    if not self._atmosphere then
        return
    end

    if not config then
        self._atmosphere.Density = 0
        return
    end

    local tweenInfo = TweenInfo.new(if animate then 2 else 0, Enum.EasingStyle.Sine)

    local properties = {
        Density = if enabled then config.Density else 0,
        Color = config.Color,
        Haze = config.Haze,
    }

    if animate then
        TweenService:Create(self._atmosphere, tweenInfo, properties):Play()
    else
        self._atmosphere.Density = properties.Density
        self._atmosphere.Color = properties.Color
        self._atmosphere.Haze = properties.Haze
    end
end

--[[
    Apply ground color to baseplate
]]
function BiomeService:_applyGroundColor(colors: BiomeConfig.BiomeColors, animate: boolean)
    local baseplate = Workspace:FindFirstChild("Baseplate")
    if not baseplate or not baseplate:IsA("BasePart") then
        return
    end

    local part = baseplate :: BasePart

    if animate then
        local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Sine)
        TweenService:Create(part, tweenInfo, {
            Color = colors.ground,
        }):Play()

        -- Material change happens instantly
        task.delay(1, function()
            part.Material = colors.groundMaterial
        end)
    else
        part.Color = colors.ground
        part.Material = colors.groundMaterial
    end
end

--[[
    Subscribe to biome changed event
]]
function BiomeService:OnBiomeChanged(callback: (newBiome: string, oldBiome: string) -> ())
    return self._biomeChangedSignal:Connect(callback)
end

-- Client methods
function BiomeService.Client:GetCurrentBiome(): string
    return self.Server:GetCurrentBiome()
end

return BiomeService
