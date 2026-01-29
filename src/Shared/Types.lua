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

return nil
