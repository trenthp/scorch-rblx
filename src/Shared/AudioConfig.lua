--!strict
--[[
    AudioConfig.lua
    All sound IDs and audio settings for Scorch
    Find sounds at: https://create.roblox.com/store/audio
]]

local AudioConfig = {
    -- ===========================================
    -- SOUND IDS
    -- Replace these with actual Roblox sound IDs
    -- ===========================================

    SOUNDS = {
        -- Phase Transitions
        Countdown = "rbxassetid://9125402735",           -- Countdown tick
        HidingStart = "rbxassetid://9125402735",         -- Runners can start hiding
        ActiveStart = "rbxassetid://9125402735",         -- Hunt begins

        -- Victory/Defeat
        SeekerWin = "rbxassetid://101228531956240",      -- Seekers victory fanfare
        RunnerWin = "rbxassetid://79221349951511",       -- Runners victory fanfare
        RoundEnd = "rbxassetid://9125402735",            -- Generic round end

        -- Gameplay Events
        Freeze = "rbxassetid://128004921736980",         -- Player frozen
        Unfreeze = "rbxassetid://9114869369",            -- Player rescued/unfrozen
        FlashlightOn = "rbxassetid://91780959457306",    -- Flashlight toggle on
        FlashlightOff = "rbxassetid://242135745",        -- Flashlight toggle off

        -- Footsteps (per material/biome)
        FootstepGrass = "rbxassetid://9114869369",       -- Grass footstep
        FootstepSnow = "rbxassetid://9114869369",        -- Snow footstep (crunchy)
        FootstepStone = "rbxassetid://9114869369",       -- Stone/slate footstep

        -- Progression
        XPGain = "rbxassetid://9114869369",              -- Small XP gain sound
        LevelUp = "rbxassetid://9114869369",             -- Level up celebration

        -- Ambient (per biome)
        AmbientForest = "rbxassetid://102839112392293",  -- Forest: Birds, gentle wind
        AmbientSnow = "rbxassetid://102839112392293",    -- Snow: Cold wind, silence
        AmbientSpooky = "rbxassetid://102839112392293",  -- Spooky: Crickets, owls, howls

        -- UI/Feedback
        UIClick = "rbxassetid://9114869369",             -- Button click
        UIHover = "rbxassetid://9114869369",             -- Button hover

        -- Team Selection
        TeamSelection = "rbxassetid://79221349951511",   -- Team selection music
    },

    -- ===========================================
    -- VOLUME SETTINGS
    -- ===========================================

    VOLUME = {
        -- Categories
        Master = 1.0,
        Music = 0.4,
        SFX = 0.6,
        Ambient = 0.3,
        Footsteps = 0.4,
        UI = 0.5,

        -- Per-sound overrides
        Countdown = 0.6,
        Freeze = 0.7,
        Unfreeze = 0.6,
        LevelUp = 0.8,
        SeekerWin = 0.7,
        RunnerWin = 0.7,
    },

    -- ===========================================
    -- FOOTSTEP SETTINGS
    -- ===========================================

    FOOTSTEPS = {
        -- Base rate (steps per second at walk speed)
        BASE_RATE = 2.0,

        -- Speed thresholds
        MIN_SPEED = 2,               -- Don't play footsteps below this speed

        -- Crouch modifier
        CROUCH_VOLUME_MULT = 0.5,    -- Quieter when crouching
        CROUCH_RATE_MULT = 0.6,      -- Slower when crouching

        -- Sprint modifier (if implemented)
        SPRINT_RATE_MULT = 1.4,

        -- Pitch variation
        PITCH_MIN = 0.9,
        PITCH_MAX = 1.1,

        -- Material to sound mapping
        MATERIAL_SOUNDS = {
            [Enum.Material.Grass] = "FootstepGrass",
            [Enum.Material.LeafyGrass] = "FootstepGrass",
            [Enum.Material.Snow] = "FootstepSnow",
            [Enum.Material.Ice] = "FootstepSnow",
            [Enum.Material.Glacier] = "FootstepSnow",
            [Enum.Material.Slate] = "FootstepStone",
            [Enum.Material.Basalt] = "FootstepStone",
            [Enum.Material.Rock] = "FootstepStone",
            [Enum.Material.Concrete] = "FootstepStone",
            [Enum.Material.Pavement] = "FootstepStone",
            [Enum.Material.Brick] = "FootstepStone",
            [Enum.Material.Cobblestone] = "FootstepStone",
        },

        -- Default sound if material not mapped
        DEFAULT_SOUND = "FootstepGrass",
    },

    -- ===========================================
    -- AMBIENT SETTINGS
    -- ===========================================

    AMBIENT = {
        -- Fade duration when switching biomes
        FADE_TIME = 2.0,

        -- Per-biome ambient settings
        Forest = {
            sound = "AmbientForest",
            volume = 0.3,
            looped = true,
        },
        Snow = {
            sound = "AmbientSnow",
            volume = 0.25,
            looped = true,
        },
        Spooky = {
            sound = "AmbientSpooky",
            volume = 0.35,
            looped = true,
        },
    },

    -- ===========================================
    -- 3D SOUND SETTINGS
    -- ===========================================

    SPATIAL = {
        -- Default 3D sound settings
        RollOffMinDistance = 10,
        RollOffMaxDistance = 100,
        RollOffMode = Enum.RollOffMode.InverseTapered,

        -- Footsteps (closer range)
        FootstepMinDistance = 5,
        FootstepMaxDistance = 50,

        -- Freeze/Unfreeze (medium range)
        FreezeMinDistance = 10,
        FreezeMaxDistance = 80,
    },
}

--[[
    Get the sound ID for a sound name
    @param soundName - Name from SOUNDS table
    @return Sound ID string
]]
function AudioConfig.getSoundId(soundName: string): string
    return AudioConfig.SOUNDS[soundName] or ""
end

--[[
    Get the volume for a sound
    @param soundName - Name of the sound
    @param category - Category for base volume (optional)
    @return Volume multiplier
]]
function AudioConfig.getVolume(soundName: string, category: string?): number
    local baseVolume = AudioConfig.VOLUME.Master

    -- Apply category volume
    if category and AudioConfig.VOLUME[category] then
        baseVolume = baseVolume * AudioConfig.VOLUME[category]
    end

    -- Apply per-sound override if exists
    if AudioConfig.VOLUME[soundName] then
        baseVolume = baseVolume * AudioConfig.VOLUME[soundName]
    end

    return baseVolume
end

--[[
    Get the footstep sound for a material
    @param material - Roblox Material enum
    @return Sound name from SOUNDS table
]]
function AudioConfig.getFootstepSound(material: Enum.Material): string
    return AudioConfig.FOOTSTEPS.MATERIAL_SOUNDS[material] or AudioConfig.FOOTSTEPS.DEFAULT_SOUND
end

--[[
    Get ambient config for a biome
    @param biome - Biome name
    @return Ambient config table
]]
function AudioConfig.getAmbientConfig(biome: string): { sound: string, volume: number, looped: boolean }
    return AudioConfig.AMBIENT[biome] or AudioConfig.AMBIENT.Forest
end

return AudioConfig
