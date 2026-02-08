--!strict
--[[
    FootstepController.lua
    Movement-based footstep sounds with material detection
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared:WaitForChild("AudioConfig"))

local LocalPlayer = Players.LocalPlayer

local FootstepController = Knit.CreateController({
    Name = "FootstepController",

    _sounds = {} :: { [string]: Sound },
    _lastStepTime = 0,
    _stepInterval = 0.5,
    _isMoving = false,
    _isCrouching = false,
    _enabled = true,
    _connection = nil :: RBXScriptConnection?,
})

function FootstepController:KnitInit()
    self:_createSounds()
    print("[FootstepController] Initialized")
end

function FootstepController:KnitStart()
    -- Listen for character added
    LocalPlayer.CharacterAdded:Connect(function(character)
        self:_setupCharacter(character)
    end)

    -- Setup current character if exists
    if LocalPlayer.Character then
        self:_setupCharacter(LocalPlayer.Character)
    end

    -- Listen for crouch state changes
    local CrouchController = Knit.GetController("CrouchController")
    if CrouchController and CrouchController.OnCrouchChanged then
        CrouchController:OnCrouchChanged(function(isCrouching)
            self._isCrouching = isCrouching
        end)
    end

    print("[FootstepController] Started")
end

--[[
    Create footstep sound instances
]]
function FootstepController:_createSounds()
    local soundsFolder = SoundService:FindFirstChild("FootstepSounds")
    if not soundsFolder then
        soundsFolder = Instance.new("Folder")
        soundsFolder.Name = "FootstepSounds"
        soundsFolder.Parent = SoundService
    end

    -- Create sounds for each footstep type
    local footstepSounds = {
        "FootstepGrass",
        "FootstepSnow",
        "FootstepStone",
    }

    for _, soundName in footstepSounds do
        local soundId = AudioConfig.getSoundId(soundName)
        if soundId and soundId ~= "" then
            local sound = Instance.new("Sound")
            sound.Name = soundName
            sound.SoundId = soundId
            sound.Volume = AudioConfig.getVolume(soundName, "Footsteps")
            sound.RollOffMinDistance = AudioConfig.SPATIAL.FootstepMinDistance
            sound.RollOffMaxDistance = AudioConfig.SPATIAL.FootstepMaxDistance
            sound.RollOffMode = Enum.RollOffMode.InverseTapered
            sound.Parent = soundsFolder

            self._sounds[soundName] = sound
        end
    end
end

--[[
    Setup character for footstep tracking
]]
function FootstepController:_setupCharacter(character: Model)
    -- Disconnect previous connection
    if self._connection then
        self._connection:Disconnect()
    end

    local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
    local rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?

    if not humanoid or not rootPart then
        return
    end

    -- Track movement with RunService
    local RunService = game:GetService("RunService")
    self._connection = RunService.Heartbeat:Connect(function()
        if not self._enabled then
            return
        end

        local velocity = rootPart.AssemblyLinearVelocity
        local horizontalSpeed = Vector2.new(velocity.X, velocity.Z).Magnitude

        -- Check if moving fast enough
        if horizontalSpeed >= AudioConfig.FOOTSTEPS.MIN_SPEED and humanoid.FloorMaterial ~= Enum.Material.Air then
            -- Calculate step interval based on speed
            local baseRate = AudioConfig.FOOTSTEPS.BASE_RATE
            local speedRatio = math.clamp(humanoid.WalkSpeed / 16, 0.5, 2.0) -- Normalized to default walk speed

            -- Apply crouch modifier
            local rateMultiplier = 1.0
            if self._isCrouching then
                rateMultiplier = AudioConfig.FOOTSTEPS.CROUCH_RATE_MULT
            end

            self._stepInterval = 1.0 / (baseRate * speedRatio * rateMultiplier)

            -- Play footstep if enough time has passed
            local now = tick()
            if now - self._lastStepTime >= self._stepInterval then
                self:_playFootstep(humanoid.FloorMaterial, rootPart)
                self._lastStepTime = now
            end
        end
    end)
end

--[[
    Play a footstep sound
]]
function FootstepController:_playFootstep(material: Enum.Material, rootPart: BasePart)
    local soundName = AudioConfig.getFootstepSound(material)
    local sound = self._sounds[soundName]

    if not sound then
        -- Fallback to grass
        sound = self._sounds.FootstepGrass
    end

    if not sound then
        return
    end

    -- Clone sound and play at position
    local footstepSound = sound:Clone()
    footstepSound.Parent = rootPart

    -- Apply volume modifiers
    local volume = AudioConfig.getVolume(soundName, "Footsteps")
    if self._isCrouching then
        volume = volume * AudioConfig.FOOTSTEPS.CROUCH_VOLUME_MULT
    end

    -- Apply stealth effect volume modifier
    local BatteryController = Knit.GetController("BatteryController")
    if BatteryController and BatteryController:HasEffect("Stealth") then
        local stealthMultiplier = BatteryController:GetEffectMultiplier("Stealth")
        volume = volume * stealthMultiplier  -- Stealth modifier is typically 0.3 for 30% volume
    end

    footstepSound.Volume = volume

    -- Apply pitch variation
    local pitch = math.random() * (AudioConfig.FOOTSTEPS.PITCH_MAX - AudioConfig.FOOTSTEPS.PITCH_MIN) + AudioConfig.FOOTSTEPS.PITCH_MIN
    footstepSound.PlaybackSpeed = pitch

    footstepSound:Play()

    -- Cleanup after playing
    footstepSound.Ended:Connect(function()
        footstepSound:Destroy()
    end)
end

--[[
    Enable or disable footsteps
]]
function FootstepController:SetEnabled(enabled: boolean)
    self._enabled = enabled
end

--[[
    Check if footsteps are enabled
]]
function FootstepController:IsEnabled(): boolean
    return self._enabled
end

return FootstepController
