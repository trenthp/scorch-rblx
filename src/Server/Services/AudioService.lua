--!strict
--[[
    AudioService.lua
    Manages game audio and sound effects
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))

-- Sound IDs (placeholder - replace with actual Roblox sound IDs)
local SOUND_IDS = {
    Freeze = "rbxassetid://9125402735", -- Ice/freeze sound
    Unfreeze = "rbxassetid://9125402735", -- Unfreeze sound
    Countdown = "rbxassetid://9125402735", -- Countdown beep
    RoundStart = "rbxassetid://9125402735", -- Round start horn
    RoundEnd = "rbxassetid://9125402735", -- Round end sound
    SeekerWin = "rbxassetid://9125402735", -- Seekers win
    RunnerWin = "rbxassetid://9125402735", -- Runners win
    FlashlightOn = "rbxassetid://9125402735", -- Flashlight toggle
    FlashlightOff = "rbxassetid://9125402735", -- Flashlight off
    Ambient = "rbxassetid://9125402735", -- Ambient forest sounds
}

local AudioService = Knit.CreateService({
    Name = "AudioService",

    Client = {
        PlaySound = Knit.CreateSignal(),
        PlaySoundAtPosition = Knit.CreateSignal(),
    },

    _sounds = {} :: { [string]: Sound },
    _ambientSound = nil :: Sound?,
})

function AudioService:KnitInit()
    self:_createSounds()
    print("[AudioService] Initialized")
end

function AudioService:KnitStart()
    -- Subscribe to game events for automatic sound playing
    local GameStateService = Knit.GetService("GameStateService")
    GameStateService:OnStateChanged(function(newState)
        self:_onStateChanged(newState)
    end)

    local PlayerStateService = Knit.GetService("PlayerStateService")
    PlayerStateService:OnPlayerFrozen(function(player)
        self:PlaySoundForAll("Freeze")
        self:PlaySoundAtPlayer(player, "Freeze")
    end)

    PlayerStateService:OnPlayerUnfrozen(function(player)
        self:PlaySoundForAll("Unfreeze")
        self:PlaySoundAtPlayer(player, "Unfreeze")
    end)

    print("[AudioService] Started")
end

--[[
    Create sound instances
]]
function AudioService:_createSounds()
    local soundsFolder = SoundService:FindFirstChild("Sounds")
    if not soundsFolder then
        soundsFolder = Instance.new("Folder")
        soundsFolder.Name = "Sounds"
        soundsFolder.Parent = SoundService
    end

    for name, soundId in SOUND_IDS do
        local sound = Instance.new("Sound")
        sound.Name = name
        sound.SoundId = soundId
        sound.Volume = 0.5
        sound.Parent = soundsFolder

        self._sounds[name] = sound
    end

    -- Set up ambient sound for looping
    if self._sounds.Ambient then
        self._sounds.Ambient.Looped = true
        self._sounds.Ambient.Volume = 0.3
    end
end

--[[
    Handle state changes for automatic sounds
]]
function AudioService:_onStateChanged(newState: string)
    if newState == Enums.GameState.COUNTDOWN then
        self:PlaySoundForAll("Countdown")
    elseif newState == Enums.GameState.GAMEPLAY then
        self:PlaySoundForAll("RoundStart")
        self:_startAmbient()
    elseif newState == Enums.GameState.RESULTS then
        self:_stopAmbient()
    elseif newState == Enums.GameState.LOBBY then
        self:_stopAmbient()
    end
end

--[[
    Play a sound for all clients
]]
function AudioService:PlaySoundForAll(soundName: string)
    self.Client.PlaySound:FireAll(soundName)
end

--[[
    Play a sound at a specific player's position
]]
function AudioService:PlaySoundAtPlayer(player: Player, soundName: string)
    local character = player.Character
    if not character then
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not rootPart then
        return
    end

    self.Client.PlaySoundAtPosition:FireAll(soundName, rootPart.Position)
end

--[[
    Start ambient sounds
]]
function AudioService:_startAmbient()
    if self._sounds.Ambient and not self._sounds.Ambient.Playing then
        self._sounds.Ambient:Play()
    end
end

--[[
    Stop ambient sounds
]]
function AudioService:_stopAmbient()
    if self._sounds.Ambient and self._sounds.Ambient.Playing then
        self._sounds.Ambient:Stop()
    end
end

--[[
    Play round end sound based on winner
]]
function AudioService:PlayRoundEndSound(winner: string)
    if winner == Enums.WinnerTeam.Seekers then
        self:PlaySoundForAll("SeekerWin")
    else
        self:PlaySoundForAll("RunnerWin")
    end
    self:PlaySoundForAll("RoundEnd")
end

-- Client methods (for UI sounds, etc.)
function AudioService.Client:RequestSound(player: Player, soundName: string)
    -- Client can request certain sounds (with validation)
    local allowedSounds = { "FlashlightOn", "FlashlightOff" }
    if table.find(allowedSounds, soundName) then
        self.Server.Client.PlaySound:Fire(player, soundName)
    end
end

return AudioService
