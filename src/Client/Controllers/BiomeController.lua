--!strict
--[[
    BiomeController.lua
    Handles client-side biome effects, including role-based lighting adjustments
    Runners get a slight brightness boost since they don't have flashlights
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BiomeConfig = require(Shared:WaitForChild("BiomeConfig"))
local Enums = require(Shared:WaitForChild("Enums"))

local BiomeController = Knit.CreateController({
    Name = "BiomeController",

    _currentBiome = "Forest",
    _isRunner = false,
    _isInGameplay = false,
    _baseLighting = nil :: BiomeConfig.BiomeLighting?,
})

function BiomeController:KnitInit()
    print("[BiomeController] Initialized")
end

function BiomeController:KnitStart()
    print("[BiomeController] KnitStart called")

    local BiomeService = Knit.GetService("BiomeService")
    local GameStateController = Knit.GetController("GameStateController")

    -- Listen for biome changes from server
    BiomeService.BiomeChanged:Connect(function(newBiome, _oldBiome)
        print("[BiomeController] Biome changed to:", newBiome)
        self._currentBiome = newBiome
        -- If already in gameplay as runner, reapply boost after server lighting settles
        if self._isInGameplay and self._isRunner then
            task.delay(2.5, function() -- Wait for server's 2s tween to complete
                self:_applyRoleLighting()
            end)
        end
    end)

    -- Listen for game state changes
    GameStateController:OnStateChanged(function(newState, _oldState)
        print("[BiomeController] Game state changed:", _oldState, "->", newState)
        local wasInGameplay = self._isInGameplay
        self._isInGameplay = (newState == Enums.GameState.GAMEPLAY)

        if self._isInGameplay and not wasInGameplay then
            -- Entering gameplay, wait a moment for role to be assigned then apply boost
            print("[BiomeController] Entering gameplay, waiting for role...")
            task.delay(0.5, function()
                local role = GameStateController:GetMyRole()
                self._isRunner = (role == Enums.PlayerRole.Runner)
                print("[BiomeController] Role check - Role:", role, "IsRunner:", self._isRunner)
                self:_applyRoleLighting()
            end)
        elseif not self._isInGameplay and wasInGameplay then
            -- Leaving gameplay, reset (server will handle base lighting)
            self._isRunner = false
            print("[BiomeController] Leaving gameplay")
        end
    end)

    -- Get initial biome
    task.spawn(function()
        local success, biome = pcall(function()
            return BiomeService:GetCurrentBiome():expect()
        end)
        if success then
            self._currentBiome = biome
            print("[BiomeController] Initial biome:", biome)
        else
            warn("[BiomeController] Failed to get initial biome:", biome)
        end
    end)

    print("[BiomeController] Started")
end

--[[
    Apply role-based lighting adjustments (runner brightness boost)
    Only called during gameplay for runners
]]
function BiomeController:_applyRoleLighting()
    print("[BiomeController] _applyRoleLighting called - isInGameplay:", self._isInGameplay, "isRunner:", self._isRunner)

    if not self._isInGameplay then
        print("[BiomeController] Not in gameplay, skipping boost")
        return
    end

    if not self._isRunner then
        print("[BiomeController] Not a runner, skipping boost (seekers get dark view)")
        return
    end

    local config = BiomeConfig.getConfig(self._currentBiome)
    local boost = config.runnerLightingBoost

    if not boost then
        warn("[BiomeController] No runner boost configured for biome:", self._currentBiome)
        return
    end

    -- Get current lighting values and add boost
    local currentBrightness = Lighting.Brightness
    local currentAmbient = Lighting.Ambient
    local currentOutdoorAmbient = Lighting.OutdoorAmbient

    local targetBrightness = currentBrightness + boost.Brightness
    local ambientBoost = boost.AmbientBoost

    local targetAmbient = Color3.fromRGB(
        math.min(255, currentAmbient.R * 255 + ambientBoost),
        math.min(255, currentAmbient.G * 255 + ambientBoost),
        math.min(255, currentAmbient.B * 255 + ambientBoost)
    )
    local targetOutdoorAmbient = Color3.fromRGB(
        math.min(255, currentOutdoorAmbient.R * 255 + ambientBoost),
        math.min(255, currentOutdoorAmbient.G * 255 + ambientBoost),
        math.min(255, currentOutdoorAmbient.B * 255 + ambientBoost)
    )

    print("[BiomeController] APPLYING RUNNER BOOST!")
    print("[BiomeController]   Biome:", self._currentBiome)
    print("[BiomeController]   Brightness:", currentBrightness, "->", targetBrightness)
    print("[BiomeController]   Ambient R:", math.floor(currentAmbient.R * 255), "->", math.floor(targetAmbient.R * 255))

    -- Apply boost with quick tween
    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    TweenService:Create(Lighting, tweenInfo, {
        Brightness = targetBrightness,
        Ambient = targetAmbient,
        OutdoorAmbient = targetOutdoorAmbient,
    }):Play()

    print("[BiomeController] Runner boost tween started")
end

--[[
    Get current biome name
]]
function BiomeController:GetCurrentBiome(): string
    return self._currentBiome
end

return BiomeController
