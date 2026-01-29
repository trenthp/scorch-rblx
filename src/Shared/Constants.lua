--!strict
--[[
    Constants.lua
    Game configuration constants for Scorch
]]

local Constants = {
    -- Flashlight settings
    FLASHLIGHT_RANGE = 50,           -- studs
    FLASHLIGHT_ANGLE = 45,           -- degrees (full cone angle)
    FLASHLIGHT_CHECK_RATE = 0.1,     -- seconds between detection checks

    -- Round settings
    ROUND_DURATION = 180,            -- seconds (3 minutes) for active gameplay
    GET_READY_DURATION = 5,          -- seconds for initial "get ready" countdown
    HIDING_DURATION = 15,            -- seconds for runners to hide (seeker frozen)
    RESULTS_DURATION = 30,           -- seconds to show results
    TEAM_SELECTION_DURATION = 15,    -- seconds for team selection

    -- Player settings
    MIN_PLAYERS = 2,
    SEEKER_COUNT = 1,                -- number of seekers per round

    -- Freeze settings
    UNFREEZE_TOUCH_DISTANCE = 5,     -- studs for touch unfreeze

    -- Visual settings
    FLASHLIGHT_BRIGHTNESS = 2,
    FLASHLIGHT_COLOR = Color3.fromRGB(255, 247, 230),
    FREEZE_COLOR = Color3.fromRGB(150, 200, 255),
    FREEZE_TRANSPARENCY = 0.3,

    -- Fallback flashlight model settings
    FLASHLIGHT_BODY_COLOR = Color3.fromRGB(40, 40, 40),
    FLASHLIGHT_HEAD_COLOR = Color3.fromRGB(60, 60, 60),
    FLASHLIGHT_LENS_COLOR = Color3.fromRGB(255, 255, 200),

    -- Team colors
    SEEKER_COLOR = BrickColor.new("Bright red"),
    RUNNER_COLOR = BrickColor.new("Bright blue"),
    LOBBY_COLOR = BrickColor.new("Medium stone grey"),

    -- Spawn settings
    SEEKER_SPAWN_TAG = "SeekerSpawn",
    RUNNER_SPAWN_TAG = "RunnerSpawn",
    LOBBY_SPAWN_TAG = "LobbySpawn",

    -- Network events
    EVENTS = {
        GAME_STATE_CHANGED = "GameStateChanged",
        PLAYER_FROZEN = "PlayerFrozen",
        PLAYER_UNFROZEN = "PlayerUnfrozen",
        ROUND_TIMER_UPDATE = "RoundTimerUpdate",
        FLASHLIGHT_TOGGLE = "FlashlightToggle",
        FLASHLIGHT_UPDATE = "FlashlightUpdate",
        TEAM_ASSIGNED = "TeamAssigned",
        ROUND_RESULTS = "RoundResults",
    },
}

return Constants
