--!strict
--[[
    AudioService.lua
    Manages game audio and sound effects
    Supports biome-specific ambient sounds
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local AudioConfig = require(Shared:WaitForChild("AudioConfig"))

-- Sound IDs now loaded from AudioConfig
local SOUND_IDS = AudioConfig.SOUNDS

local AudioService = Knit.CreateService({
    Name = "AudioService",

    Client = {
        PlaySound = Knit.CreateSignal(),
        PlaySoundAtPosition = Knit.CreateSignal(),
        SetAmbientBiome = Knit.CreateSignal(),
    },

    _sounds = {} :: { [string]: Sound },
    _ambientSounds = {} :: { [string]: Sound },
    _currentBiome = "Forest",
})

function AudioService:KnitInit()
    self:_createSounds()
    print("[AudioService] Initialized")
end

function AudioService:KnitStart()
    -- Subscribe to game state changes
    local GameStateService = Knit.GetService("GameStateService")
    GameStateService:OnStateChanged(function(newState)
        self:_onStateChanged(newState)
    end)

    -- Subscribe to gameplay phase changes
    local RoundService = Knit.GetService("RoundService")
    RoundService:OnPhaseChanged(function(phase)
        self:_onPhaseChanged(phase)
    end)

    -- Subscribe to countdown ticks for countdown audio
    RoundService:OnCountdownTick(function(seconds, phase)
        self:_onCountdownTick(seconds, phase)
    end)

    -- Subscribe to round end for victory sounds
    RoundService:OnRoundEnded(function(results)
        self:_onRoundEnded(results)
    end)

    -- Subscribe to player freeze/unfreeze
    local PlayerStateService = Knit.GetService("PlayerStateService")
    PlayerStateService:OnPlayerFrozen(function(player)
        self:PlaySoundAtPlayer(player, "Freeze")
    end)

    PlayerStateService:OnPlayerUnfrozen(function(player)
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
        sound.Volume = AudioConfig.getVolume(name, "SFX")
        sound.Parent = soundsFolder

        self._sounds[name] = sound
    end

    -- Set up ambient sounds for each biome
    local ambientFolder = soundsFolder:FindFirstChild("Ambient")
    if not ambientFolder then
        ambientFolder = Instance.new("Folder")
        ambientFolder.Name = "Ambient"
        ambientFolder.Parent = soundsFolder
    end

    for biome, config in AudioConfig.AMBIENT do
        -- Skip non-table entries (like FADE_TIME)
        if type(config) == "table" and config.sound then
            local soundId = AudioConfig.getSoundId(config.sound)
            if soundId and soundId ~= "" then
                local sound = Instance.new("Sound")
                sound.Name = "Ambient_" .. biome
                sound.SoundId = soundId
                sound.Volume = 0 -- Start at 0, fade in when needed
                sound.Looped = config.looped
                sound.Parent = ambientFolder
                self._ambientSounds[biome] = sound
            end
        end
    end

    -- Team selection can also loop
    if self._sounds.TeamSelection then
        self._sounds.TeamSelection.Looped = true
        self._sounds.TeamSelection.Volume = AudioConfig.getVolume("TeamSelection", "Music")
    end

    -- Setup progression sounds
    if self._sounds.LevelUp then
        self._sounds.LevelUp.Volume = AudioConfig.getVolume("LevelUp", "SFX")
    end
    if self._sounds.XPGain then
        self._sounds.XPGain.Volume = AudioConfig.getVolume("XPGain", "SFX")
    end
end

--[[
    Handle game state changes
]]
function AudioService:_onStateChanged(newState: string)
    if newState == Enums.GameState.TEAM_SELECTION then
        -- Play team selection music (continues from RESULTS if already playing)
        self:_stopAmbient()
        self:_startTeamSelectionMusic()
    elseif newState == Enums.GameState.GAMEPLAY then
        -- Stop team selection music (ambient starts when ACTIVE phase begins)
        self:_stopTeamSelectionMusic()
    elseif newState == Enums.GameState.RESULTS then
        -- Stop ambient, start team selection music for results/transition
        self:_stopAmbient()
        self:_startTeamSelectionMusic()
    elseif newState == Enums.GameState.LOBBY then
        self:_stopAmbient()
        self:_stopTeamSelectionMusic()
    end
end

--[[
    Handle gameplay phase changes
]]
function AudioService:_onPhaseChanged(phase: string)
    if phase == Enums.GameplayPhase.ACTIVE then
        -- Start ambient music and play round start sound when seeker is released
        self:PlaySoundForAll("RoundStart")
        self:_startAmbient()
    end
end

--[[
    Handle countdown ticks for audio
    Plays during COUNTDOWN, HIDING, and last 15 seconds of ACTIVE phase
]]
function AudioService:_onCountdownTick(_seconds: number, _phase: string)
    self:PlaySoundForAll("Countdown")
end

--[[
    Handle round end for victory sounds
]]
function AudioService:_onRoundEnded(results: any)
    -- Play round end sound
    self:PlaySoundForAll("RoundEnd")

    -- Play winner-specific sound
    if results.winner == Enums.WinnerTeam.Seekers then
        self:PlaySoundForAll("SeekerWin")
    else
        self:PlaySoundForAll("RunnerWin")
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
    Start ambient/gameplay music for current biome
]]
function AudioService:_startAmbient()
    local biomeSound = self._ambientSounds[self._currentBiome]
    if biomeSound then
        local config = AudioConfig.getAmbientConfig(self._currentBiome)
        biomeSound.Volume = config.volume
        if not biomeSound.Playing then
            biomeSound:Play()
        end
    end
end

--[[
    Stop ambient/gameplay music
]]
function AudioService:_stopAmbient()
    for _, sound in self._ambientSounds do
        if sound.Playing then
            sound:Stop()
        end
        sound.Volume = 0
    end
end

--[[
    Set the current biome for ambient sounds
    @param biome - The biome name ("Forest", "Snow", "Spooky")
]]
function AudioService:SetBiome(biome: string)
    if self._currentBiome == biome then
        return
    end

    local oldBiome = self._currentBiome
    self._currentBiome = biome

    -- Crossfade ambient sounds
    local oldSound = self._ambientSounds[oldBiome]
    local newSound = self._ambientSounds[biome]
    local fadeTime = AudioConfig.AMBIENT.FADE_TIME

    -- Fade out old
    if oldSound and oldSound.Playing then
        task.spawn(function()
            local startVol = oldSound.Volume
            local steps = 20
            for i = 1, steps do
                oldSound.Volume = startVol * (1 - i / steps)
                task.wait(fadeTime / steps)
            end
            oldSound:Stop()
            oldSound.Volume = 0
        end)
    end

    -- Fade in new
    if newSound then
        local config = AudioConfig.getAmbientConfig(biome)
        local targetVol = config.volume

        if not newSound.Playing then
            newSound.Volume = 0
            newSound:Play()
        end

        task.spawn(function()
            local steps = 20
            for i = 1, steps do
                newSound.Volume = targetVol * (i / steps)
                task.wait(fadeTime / steps)
            end
            newSound.Volume = targetVol
        end)
    end

    -- Notify clients
    self.Client.SetAmbientBiome:FireAll(biome)

    print(string.format("[AudioService] Biome changed: %s -> %s", oldBiome, biome))
end

--[[
    Get the current biome
]]
function AudioService:GetBiome(): string
    return self._currentBiome
end

--[[
    Start team selection music
]]
function AudioService:_startTeamSelectionMusic()
    if self._sounds.TeamSelection and not self._sounds.TeamSelection.Playing then
        self._sounds.TeamSelection:Play()
    end
end

--[[
    Stop team selection music
]]
function AudioService:_stopTeamSelectionMusic()
    if self._sounds.TeamSelection and self._sounds.TeamSelection.Playing then
        self._sounds.TeamSelection:Stop()
    end
end

--[[
    Play a sound for level up
    @param player - The player who leveled up
]]
function AudioService:PlayLevelUp(player: Player)
    self.Client.PlaySound:Fire(player, "LevelUp")
end

--[[
    Play XP gain sound
    @param player - The player who gained XP
]]
function AudioService:PlayXPGain(player: Player)
    self.Client.PlaySound:Fire(player, "XPGain")
end

-- Client methods (for UI sounds, etc.)
function AudioService.Client:RequestSound(player: Player, soundName: string)
    -- Client can request certain sounds (with validation)
    local allowedSounds = { "FlashlightOn", "FlashlightOff", "UIClick", "UIHover" }
    if table.find(allowedSounds, soundName) then
        self.Server.Client.PlaySound:Fire(player, soundName)
    end
end

function AudioService.Client:GetCurrentBiome(): string
    return self.Server:GetBiome()
end

return AudioService
