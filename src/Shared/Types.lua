--!strict
--[[
    Types.lua
    Shared type definitions for Scorch
]]

export type GameState = "LOBBY" | "TEAM_SELECTION" | "GAMEPLAY" | "RESULTS"

export type GameplayPhase = "COUNTDOWN" | "HIDING" | "ACTIVE"

export type PlayerRole = "Seeker" | "Runner" | "Spectator"

export type FreezeState = "Active" | "Frozen"

export type PlayerData = {
    userId: number,
    role: PlayerRole,
    freezeState: FreezeState,
    frozenBy: Player?,
    frozenAt: number?,
}

export type RoundData = {
    startTime: number,
    endTime: number,
    duration: number,
    seekers: { Player },
    runners: { Player },
    frozenCount: number,
    winner: "Seekers" | "Runners" | nil,
}

export type FlashlightData = {
    owner: Player,
    enabled: boolean,
    direction: Vector3,
}

export type TeamData = {
    seekers: { Player },
    runners: { Player },
}

export type MapData = {
    name: string,
    seekerSpawns: { BasePart },
    runnerSpawns: { BasePart },
}

-- Stats and progression types (detailed versions in StatsTypes.lua)
export type PlayerStats = {
    freezesMade: number,
    rescues: number,
    timesFrozen: number,
    gamesPlayed: number,
    wins: number,
    seekerWins: number,
    runnerWins: number,
    timeSurvived: number,
}

export type ProgressionData = {
    xp: number,
    level: number,
    selectedTitle: string,
    unlockedTitles: { string },
}

-- Biome type for map variety
export type BiomeType = "Forest" | "Snow" | "Spooky"

return nil
