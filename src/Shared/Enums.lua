--!strict
--[[
    Enums.lua
    Enumeration values for Scorch
]]

local Enums = {
    GameState = {
        LOBBY = "LOBBY",
        TEAM_SELECTION = "TEAM_SELECTION",
        GAMEPLAY = "GAMEPLAY",
        RESULTS = "RESULTS",
    },

    -- Internal phases within GAMEPLAY state
    GameplayPhase = {
        COUNTDOWN = "COUNTDOWN",       -- Initial countdown (5 seconds)
        HIDING = "HIDING",             -- Runners hide (15 seconds), seekers still frozen
        ACTIVE = "ACTIVE",             -- Main gameplay (3 minutes)
    },

    PlayerRole = {
        Seeker = "Seeker",
        Runner = "Runner",
        Spectator = "Spectator",
    },

    FreezeState = {
        Active = "Active",
        Frozen = "Frozen",
    },

    RoundEndReason = {
        AllFrozen = "AllFrozen",
        TimeUp = "TimeUp",
        SeekersDisconnected = "SeekersDisconnected",
        RunnersDisconnected = "RunnersDisconnected",
    },

    WinnerTeam = {
        Seekers = "Seekers",
        Runners = "Runners",
    },

    Biome = {
        Forest = "Forest",
        Snow = "Snow",
        Warehouse = "Warehouse",
    },

    QueueState = {
        NotQueued = "NotQueued",
        Queued = "Queued",
        InGame = "InGame",
    },

    -- Power-up effect types
    PowerUpEffect = {
        Speed = "Speed",
        Stealth = "Stealth",
        Vision = "Vision",
        Rescue = "Rescue",
        Shield = "Shield",
    },

    -- Battery sizes
    BatterySize = {
        AAA = "AAA",
        AA = "AA",
        C = "C",
        D = "D",
        ["9V"] = "9V",
        Lantern = "Lantern",
    },

    -- Flashlight types
    FlashlightType = {
        Standard = "Standard",
        Wide = "Wide",
        Focused = "Focused",
        Strobe = "Strobe",
        UV = "UV",
        Spotlight = "Spotlight",
    },
}

return Enums
