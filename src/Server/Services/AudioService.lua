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
-- Find sounds at: https://create.roblox.com/store/audio
local SOUND_IDS = {
    -- UI/Feedback sounds
    Countdown = "rbxassetid://9125402735",      -- Countdown beep/tick

    -- Round transition sounds
    TeamSelection = "rbxassetid://79221349951511",  -- Team selection music/jingle
    RoundStart = "rbxassetid://9125402735",     -- Round start horn/signal
    RoundEnd = "rbxassetid://9125402735",       -- Round end sound
    SeekerWin = "rbxassetid://101228531956240",      -- Seekers victory
    RunnerWin = "rbxassetid://79221349951511",      -- Runners victory

    -- Gameplay sounds
    Freeze = "rbxassetid://128004921736980",         -- Player frozen
    Unfreeze = "rbxassetid://9114869369",       -- Player unfrozen/rescued
    FlashlightOn = "rbxassetid://91780959457306",   -- Flashlight toggle on
    FlashlightOff = "rbxassetid://242135745",  -- Flashlight toggle off

    -- Ambient/Music
    Ambient = "rbxassetid://102839112392293",        -- Gameplay ambient/music
}

local AudioService = Knit.CreateService({
    Name = "AudioService",

    Client = {
        PlaySound = Knit.CreateSignal(),
        PlaySoundAtPosition = Knit.CreateSignal(),
    },

    _sounds = {} :: { [string]: Sound },
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
        sound.Volume = 0.5
        sound.Parent = soundsFolder

        self._sounds[name] = sound
    end

    -- Set up ambient sound for looping
    if self._sounds.Ambient then
        self._sounds.Ambient.Looped = true
        self._sounds.Ambient.Volume = 0.3
    end

    -- Team selection can also loop
    if self._sounds.TeamSelection then
        self._sounds.TeamSelection.Looped = true
        self._sounds.TeamSelection.Volume = 0.4
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
    Start ambient/gameplay music
]]
function AudioService:_startAmbient()
    if self._sounds.Ambient and not self._sounds.Ambient.Playing then
        self._sounds.Ambient:Play()
    end
end

--[[
    Stop ambient/gameplay music
]]
function AudioService:_stopAmbient()
    if self._sounds.Ambient and self._sounds.Ambient.Playing then
        self._sounds.Ambient:Stop()
    end
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

-- Client methods (for UI sounds, etc.)
function AudioService.Client:RequestSound(player: Player, soundName: string)
    -- Client can request certain sounds (with validation)
    local allowedSounds = { "FlashlightOn", "FlashlightOff" }
    if table.find(allowedSounds, soundName) then
        self.Server.Client.PlaySound:Fire(player, soundName)
    end
end

return AudioService
