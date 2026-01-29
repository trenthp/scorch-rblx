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
}

return Enums
