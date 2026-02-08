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

    -- Scenery settings
    SCENERY = {
        AUTO_GENERATE = true,            -- Generate scenery on game start
        SEED = nil,                       -- nil = random seed each time, or set number for consistent generation
        DENSITY = 0.8,                    -- Objects per 100 square studs (higher = more dense)
        MIN_SPACING = 4,                  -- Minimum studs between scenery objects
        BOUNDS = {                        -- Play area boundaries for scenery generation
            min = Vector3.new(-150, 0, -150),
            max = Vector3.new(150, 0, 150),
        },
        SPAWN_EXCLUSION_RADIUS = 15,     -- Keep scenery away from spawn points
        HIDING_BUSH_COUNT = 20,          -- Number of hiding bushes to place
        HIDING_BUSH_MIN_SPACING = 25,    -- Minimum distance between hiding bushes
    },

    -- Hiding mechanics
    HIDING = {
        DETECTION_RADIUS = 8,            -- How close to bush center to count as hiding (doubled for larger bushes)
        MAX_HIDE_TIME = 15,              -- Seconds before forced out of bush
        WARNING_TIME = 5,                -- Seconds before max time to show warning
        CHECK_RATE = 0.1,                -- How often to check hiding state

        -- Bush glow mechanics (anti-camping)
        GLOW_START_TIME = 12,            -- Seconds before bush starts glowing (after warning at 10s)
        GLOW_MAX_TIME = 15,              -- Seconds to reach full glow (matches MAX_HIDE_TIME)
        GLOW_COOLDOWN = 10,              -- Seconds for bush heat to fully decay when empty
        GLOW_COLOR = Color3.fromRGB(255, 180, 80),  -- Warm amber glow
        GLOW_MAX_BRIGHTNESS = 1.5,       -- Maximum PointLight brightness
        GLOW_MAX_EMISSION = 0.6,         -- Maximum part surface emission
    },

    -- Crouch mechanics (runners only)
    CROUCH = {
        HIP_HEIGHT_MULTIPLIER = 0.4,     -- How much to lower stance (40% of normal)
        SPEED_MULTIPLIER = 0.5,          -- Movement speed while crouching (50%)
        DETECTION_HEIGHT_OFFSET = -1.5,  -- Lower flashlight detection point when crouching
        TWEEN_TIME = 0.2,                -- Transition time in seconds
    },

    -- Lobby settings
    LOBBY = {
        HEIGHT = 120,                    -- Studs above ground
        PLATFORM_SIZE = 80,              -- Platform width/length in studs
        WALL_HEIGHT = 15,                -- Railing/wall height
        FADE_TIME = 0.5,                 -- Transition fade duration in seconds
    },

    -- Boundary zone settings
    BOUNDARY = {
        PLAY_AREA_RADIUS = 150,          -- Safe play area (-150 to 150)
        FREEZE_ZONE_RADIUS = 200,        -- Freeze zone (150 to 200)
        WALL_RADIUS = 205,               -- Invisible wall position
        FREEZE_RATE = 20,                -- Cold % gained per second in zone
        THAW_RATE = 10,                  -- Cold % lost per second when back in play area
        CHECK_RATE = 0.1,                -- How often to check player position
    },

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
