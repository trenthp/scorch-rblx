--!strict
--[[
    Enums.lua
    Enumeration values for Scorch
]]

local Enums = {
    GameState = {
        LOBBY = "LOBBY",
        TEAM_SELECTION = "TEAM_SELECTION",
        COUNTDOWN = "COUNTDOWN",
        GAMEPLAY = "GAMEPLAY",
        RESULTS = "RESULTS",
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
