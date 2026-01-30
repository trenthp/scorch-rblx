--!strict
--[[
    HidingService.lua
    Server-side hiding mechanics
    - Plays 3D bush rustling sounds that all players can hear
    - Tracks bush occupancy and applies glow effects for anti-camping
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

-- Type for bush state tracking
type BushState = {
    occupants: {[Player]: boolean},   -- Players currently in this bush
    heat: number,                      -- Current heat level (0-1)
    glowLight: PointLight?,            -- Reference to the glow light
    occupiedSince: number?,            -- When the bush became occupied (nil if empty)
}

local HidingService = Knit.CreateService({
    Name = "HidingService",
    Client = {},

    _bushStates = {} :: {[Model]: BushState},  -- Track state for each bush
    _playerBushes = {} :: {[Player]: Model?},  -- Which bush each player is in
    _updateLoop = nil :: thread?,
})

-- Sound configuration
local BUSH_ENTER_SOUND = "rbxassetid://395340995"
local BUSH_EXIT_SOUND = "rbxassetid://124554515259136"
local SOUND_RANGE = 50

-- Glow configuration from constants
local GLOW_START_TIME = Constants.HIDING.GLOW_START_TIME
local GLOW_MAX_TIME = Constants.HIDING.GLOW_MAX_TIME
local GLOW_COOLDOWN = Constants.HIDING.GLOW_COOLDOWN
local GLOW_COLOR = Constants.HIDING.GLOW_COLOR
local GLOW_MAX_BRIGHTNESS = Constants.HIDING.GLOW_MAX_BRIGHTNESS
local GLOW_MAX_EMISSION = Constants.HIDING.GLOW_MAX_EMISSION

function HidingService:KnitInit()
    print("[HidingService] Initialized")
end

function HidingService:KnitStart()
    local GameStateService = Knit.GetService("GameStateService")

    -- Start/stop glow updates based on game state
    GameStateService:OnStateChanged(function(newState, _oldState)
        if newState == Enums.GameState.GAMEPLAY then
            self:_startGlowUpdates()
        else
            self:_stopGlowUpdates()
            self:_resetAllBushes()
        end
    end)

    -- Clean up when players leave
    Players.PlayerRemoving:Connect(function(player)
        self:_handlePlayerLeave(player)
    end)

    print("[HidingService] Started")
end

--[[
    Start the glow update loop
]]
function HidingService:_startGlowUpdates()
    if self._updateLoop then
        return
    end

    self._updateLoop = task.spawn(function()
        while true do
            self:_updateAllBushGlows()
            task.wait(0.1)
        end
    end)
end

--[[
    Stop the glow update loop
]]
function HidingService:_stopGlowUpdates()
    if self._updateLoop then
        task.cancel(self._updateLoop)
        self._updateLoop = nil
    end
end

--[[
    Update glow for all tracked bushes
]]
function HidingService:_updateAllBushGlows()
    local now = tick()

    for bush, state in pairs(self._bushStates) do
        if not bush or not bush.Parent then
            -- Bush was destroyed, clean up
            self._bushStates[bush] = nil
            continue
        end

        local occupantCount = 0
        for _ in pairs(state.occupants) do
            occupantCount += 1
        end

        if occupantCount > 0 then
            -- Bush is occupied - increase heat
            if state.occupiedSince then
                local occupiedTime = now - state.occupiedSince

                if occupiedTime >= GLOW_START_TIME then
                    -- Start glowing
                    local glowProgress = (occupiedTime - GLOW_START_TIME) / (GLOW_MAX_TIME - GLOW_START_TIME)
                    state.heat = math.clamp(glowProgress, 0, 1)
                end
            end
        else
            -- Bush is empty - decay heat (cooldown)
            if state.heat > 0 then
                local decayRate = 1 / GLOW_COOLDOWN * 0.1  -- Per update tick
                state.heat = math.max(0, state.heat - decayRate)
            end

            -- Clear occupied timestamp when empty
            state.occupiedSince = nil
        end

        -- Apply visual glow based on heat
        self:_applyBushGlow(bush, state)
    end
end

--[[
    Apply visual glow effect to a bush based on its heat level
]]
function HidingService:_applyBushGlow(bush: Model, state: BushState)
    local heat = state.heat

    -- Create or update the glow light
    if heat > 0 then
        if not state.glowLight then
            -- Create a new point light
            local light = Instance.new("PointLight")
            light.Name = "BushGlow"
            light.Color = GLOW_COLOR
            light.Brightness = 0
            light.Range = 12
            light.Shadows = false

            if bush.PrimaryPart then
                light.Parent = bush.PrimaryPart
            else
                -- Find a suitable part
                for _, part in bush:GetDescendants() do
                    if part:IsA("BasePart") then
                        light.Parent = part
                        break
                    end
                end
            end

            state.glowLight = light
        end

        -- Update light brightness
        if state.glowLight then
            state.glowLight.Brightness = heat * GLOW_MAX_BRIGHTNESS
        end

        -- Update part emission for all bush parts
        for _, part in bush:GetDescendants() do
            if part:IsA("BasePart") and part.Name ~= "Berry" then
                -- Store original color if not already stored
                if not part:GetAttribute("OriginalColor") then
                    local color = part.Color
                    part:SetAttribute("OriginalColor", string.format("%d,%d,%d",
                        math.floor(color.R * 255),
                        math.floor(color.G * 255),
                        math.floor(color.B * 255)
                    ))
                end

                -- Lerp color toward glow color based on heat
                local originalColorStr = part:GetAttribute("OriginalColor")
                if originalColorStr then
                    local r, g, b = string.match(originalColorStr, "(%d+),(%d+),(%d+)")
                    if r and g and b then
                        local originalColor = Color3.fromRGB(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0)
                        local glowAmount = heat * 0.4  -- Max 40% blend toward glow color
                        part.Color = originalColor:Lerp(GLOW_COLOR, glowAmount)
                    end
                end
            end
        end
    else
        -- No heat - remove glow and restore colors
        if state.glowLight then
            state.glowLight:Destroy()
            state.glowLight = nil
        end

        -- Restore original colors
        for _, part in bush:GetDescendants() do
            if part:IsA("BasePart") then
                local originalColorStr = part:GetAttribute("OriginalColor")
                if originalColorStr then
                    local r, g, b = string.match(originalColorStr, "(%d+),(%d+),(%d+)")
                    if r and g and b then
                        part.Color = Color3.fromRGB(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0)
                    end
                    part:SetAttribute("OriginalColor", nil)
                end
            end
        end
    end
end

--[[
    Get or create bush state
]]
function HidingService:_getBushState(bush: Model): BushState
    if not self._bushStates[bush] then
        self._bushStates[bush] = {
            occupants = {},
            heat = 0,
            glowLight = nil,
            occupiedSince = nil,
        }
    end
    return self._bushStates[bush]
end

--[[
    Handle player entering a bush
]]
function HidingService:_handlePlayerEnterBush(player: Player, bush: Model)
    -- Remove from previous bush if any
    local previousBush = self._playerBushes[player]
    if previousBush and previousBush ~= bush then
        self:_handlePlayerExitBush(player, previousBush)
    end

    -- Add to new bush
    self._playerBushes[player] = bush
    local state = self:_getBushState(bush)
    state.occupants[player] = true

    -- If this is the first occupant, or re-entering during cooldown
    local occupantCount = 0
    for _ in pairs(state.occupants) do
        occupantCount += 1
    end

    if occupantCount == 1 then
        -- First occupant
        if state.heat > 0 then
            -- Re-entering during cooldown - resume from current heat level
            -- Adjust occupiedSince to account for existing heat
            local existingProgress = state.heat * (GLOW_MAX_TIME - GLOW_START_TIME)
            state.occupiedSince = tick() - GLOW_START_TIME - existingProgress
        else
            -- Fresh entry
            state.occupiedSince = tick()
        end
    end
end

--[[
    Handle player exiting a bush
]]
function HidingService:_handlePlayerExitBush(player: Player, bush: Model?)
    if not bush then
        bush = self._playerBushes[player]
    end

    if bush then
        local state = self._bushStates[bush]
        if state then
            state.occupants[player] = nil
        end
    end

    self._playerBushes[player] = nil
end

--[[
    Handle player leaving the game
]]
function HidingService:_handlePlayerLeave(player: Player)
    self:_handlePlayerExitBush(player, nil)
end

--[[
    Reset all bush states (called when gameplay ends)
]]
function HidingService:_resetAllBushes()
    for bush, state in pairs(self._bushStates) do
        -- Remove glow effects
        if state.glowLight then
            state.glowLight:Destroy()
        end

        -- Restore original colors
        if bush and bush.Parent then
            for _, part in bush:GetDescendants() do
                if part:IsA("BasePart") then
                    local originalColorStr = part:GetAttribute("OriginalColor")
                    if originalColorStr then
                        local r, g, b = string.match(originalColorStr, "(%d+),(%d+),(%d+)")
                        if r and g and b then
                            part.Color = Color3.fromRGB(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0)
                        end
                        part:SetAttribute("OriginalColor", nil)
                    end
                end
            end
        end
    end

    self._bushStates = {}
    self._playerBushes = {}
end

--[[
    Play a 3D sound at a player's position that all nearby players can hear
]]
function HidingService:_playBushSound(player: Player, soundId: string, volume: number, playbackSpeed: number)
    local character = player.Character
    if not character then
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not rootPart then
        return
    end

    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = volume
    sound.PlaybackSpeed = playbackSpeed
    sound.RollOffMode = Enum.RollOffMode.Linear
    sound.RollOffMinDistance = 10
    sound.RollOffMaxDistance = SOUND_RANGE
    sound.Parent = rootPart

    sound:Play()
    sound.Ended:Connect(function()
        sound:Destroy()
    end)

    task.delay(3, function()
        if sound and sound.Parent then
            sound:Destroy()
        end
    end)
end

-- ============================================
-- CLIENT METHODS
-- ============================================

--[[
    Called by client when entering a bush
]]
function HidingService.Client:OnBushEnter(player: Player, bush: Model?)
    self.Server:_playBushSound(player, BUSH_ENTER_SOUND, 0.8, 1.2)

    if bush and bush:IsA("Model") then
        self.Server:_handlePlayerEnterBush(player, bush)
    end
end

--[[
    Called by client when exiting a bush
]]
function HidingService.Client:OnBushExit(player: Player, bush: Model?)
    self.Server:_playBushSound(player, BUSH_EXIT_SOUND, 0.6, 0.9)

    if bush and bush:IsA("Model") then
        self.Server:_handlePlayerExitBush(player, bush)
    else
        self.Server:_handlePlayerExitBush(player, nil)
    end
end

return HidingService
