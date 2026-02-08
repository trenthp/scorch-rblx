--!strict
--[[
    BatteryConfig.lua
    Configuration for battery sizes, power-up effects, and drop rates

    Battery Mechanics:
    - Drop triggers: Freeze a runner, rescue a frozen player
    - Sizes: AAA/AA (instant use), C/D/9V/Lantern (stored, activated with keybind)
    - End of round: Unused stored batteries convert to currency
]]

export type BatterySize = {
    id: string,
    name: string,
    isInstant: boolean,      -- If true, effect applies immediately on pickup
    currencyValue: number,   -- Currency value when converted at end of round
    duration: number,        -- Effect duration in seconds
    dropWeight: number,      -- Relative drop chance (higher = more common)
}

export type PowerUpEffect = {
    id: string,
    name: string,
    description: string,
    color: Color3,
    runnerModifier: number,   -- Modifier for runners (varies by effect)
    seekerModifier: number,   -- Modifier for seekers (varies by effect)
    isRare: boolean,          -- Rare effects drop less frequently
    dropWeight: number,       -- Relative drop chance
}

export type StoredBattery = {
    effectId: string,
    sizeId: string,
}

local BatteryConfig = {}

-- Battery sizes with properties
BatteryConfig.BATTERY_SIZES = {
    AAA = {
        id = "AAA",
        name = "AAA Battery",
        isInstant = false,
        currencyValue = 5,
        duration = 5,
        dropWeight = 30,
    },
    AA = {
        id = "AA",
        name = "AA Battery",
        isInstant = false,
        currencyValue = 10,
        duration = 10,
        dropWeight = 25,
    },
    C = {
        id = "C",
        name = "C Battery",
        isInstant = false,
        currencyValue = 25,
        duration = 15,
        dropWeight = 20,
    },
    D = {
        id = "D",
        name = "D Battery",
        isInstant = false,
        currencyValue = 50,
        duration = 20,
        dropWeight = 15,
    },
    ["9V"] = {
        id = "9V",
        name = "9V Battery",
        isInstant = false,
        currencyValue = 75,
        duration = 30,
        dropWeight = 7,
    },
    Lantern = {
        id = "Lantern",
        name = "Lantern Battery",
        isInstant = false,
        currencyValue = 150,
        duration = 45,
        dropWeight = 3,
    },
}

-- Power-up effects with role-specific modifiers
BatteryConfig.EFFECTS = {
    Speed = {
        id = "Speed",
        name = "Speed Boost",
        description = "Increases movement speed",
        color = Color3.fromRGB(255, 220, 50),  -- Yellow
        runnerModifier = 1.20,   -- +20% movement speed
        seekerModifier = 1.15,   -- +15% movement speed
        isRare = false,
        dropWeight = 25,
    },
    Stealth = {
        id = "Stealth",
        name = "Stealth Mode",
        description = "Quieter footsteps, hidden nametag",
        color = Color3.fromRGB(170, 85, 200),  -- Purple
        runnerModifier = 0.3,    -- 30% footstep volume
        seekerModifier = 0.3,    -- 30% footstep volume (silent approach)
        isRare = false,
        dropWeight = 20,
    },
    Vision = {
        id = "Vision",
        name = "Enhanced Vision",
        description = "See enemy outlines through walls",
        color = Color3.fromRGB(85, 220, 255),  -- Cyan
        runnerModifier = 1.0,    -- See seeker outlines
        seekerModifier = 1.0,    -- See runner outlines
        isRare = false,
        dropWeight = 20,
    },
    Rescue = {
        id = "Rescue",
        name = "Rescue Boost",
        description = "Faster rescue or longer freeze",
        color = Color3.fromRGB(85, 220, 120),  -- Green
        runnerModifier = 2.0,    -- 2x rescue speed
        seekerModifier = 1.5,    -- +50% freeze duration
        isRare = false,
        dropWeight = 25,
    },
    Shield = {
        id = "Shield",
        name = "Shield",
        description = "Block one freeze (Runner) or instant freeze (Seeker)",
        color = Color3.fromRGB(255, 255, 255),  -- White
        runnerModifier = 1.0,    -- Blocks one freeze attempt
        seekerModifier = 1.0,    -- Instant freeze on next hit
        isRare = true,
        dropWeight = 10,
    },
}

-- Maximum stored batteries a player can hold
BatteryConfig.MAX_STORED_BATTERIES = 4

-- Spawn settings
BatteryConfig.SPAWN_HEIGHT_OFFSET = 3  -- Height above ground to spawn battery
BatteryConfig.BATTERY_LIFETIME = 30     -- Seconds before uncollected battery despawns
BatteryConfig.PICKUP_RANGE = 5          -- Distance to auto-collect instant batteries

-- Random drop settings (periodic spawns during active gameplay)
BatteryConfig.RANDOM_DROP_INTERVAL = 12    -- Seconds between random drops
BatteryConfig.RANDOM_DROP_COUNT = {1, 2}   -- Min/max batteries per drop
BatteryConfig.RANDOM_DROP_BOUNDS = {        -- Area where random batteries can spawn
    min = Vector3.new(-140, 0, -140),
    max = Vector3.new(140, 0, 140),
}
BatteryConfig.MAX_WORLD_BATTERIES = 15     -- Cap on total batteries in the world at once

-- Visual settings
BatteryConfig.BATTERY_SIZE = Vector3.new(0.5, 0.8, 0.5)
BatteryConfig.BATTERY_GLOW_INTENSITY = 0.5
BatteryConfig.BATTERY_ROTATION_SPEED = 1.5  -- Rotations per second
BatteryConfig.BATTERY_BOB_AMPLITUDE = 0.3   -- Units up/down
BatteryConfig.BATTERY_BOB_SPEED = 2         -- Cycles per second

--[[
    Get a battery size configuration by ID
]]
function BatteryConfig.getBatterySize(sizeId: string): BatterySize?
    return BatteryConfig.BATTERY_SIZES[sizeId]
end

--[[
    Get an effect configuration by ID
]]
function BatteryConfig.getEffect(effectId: string): PowerUpEffect?
    return BatteryConfig.EFFECTS[effectId]
end

--[[
    Roll a random battery size based on weights
]]
function BatteryConfig.rollBatterySize(): string
    local totalWeight = 0
    for _, size in BatteryConfig.BATTERY_SIZES do
        totalWeight += size.dropWeight
    end

    local roll = math.random() * totalWeight
    local cumulative = 0

    for id, size in BatteryConfig.BATTERY_SIZES do
        cumulative += size.dropWeight
        if roll <= cumulative then
            return id
        end
    end

    return "AA"  -- Fallback
end

--[[
    Roll a random effect based on weights
]]
function BatteryConfig.rollEffect(): string
    local totalWeight = 0
    for _, effect in BatteryConfig.EFFECTS do
        totalWeight += effect.dropWeight
    end

    local roll = math.random() * totalWeight
    local cumulative = 0

    for id, effect in BatteryConfig.EFFECTS do
        cumulative += effect.dropWeight
        if roll <= cumulative then
            return id
        end
    end

    return "Speed"  -- Fallback
end

--[[
    Calculate effect duration based on battery size
]]
function BatteryConfig.getEffectDuration(sizeId: string): number
    local size = BatteryConfig.BATTERY_SIZES[sizeId]
    if size then
        return size.duration
    end
    return 10  -- Default fallback
end

--[[
    Calculate currency value of stored batteries for end-of-round conversion
]]
function BatteryConfig.calculateConversionValue(storedBatteries: { StoredBattery }): number
    local total = 0
    for _, battery in storedBatteries do
        local size = BatteryConfig.BATTERY_SIZES[battery.sizeId]
        if size then
            total += size.currencyValue
        end
    end
    return total
end

--[[
    Check if an effect is a "one-time" effect (consumed on use rather than timed)
]]
function BatteryConfig.isOneTimeEffect(effectId: string): boolean
    return effectId == "Shield"
end

--[[
    Get all instant (AAA/AA) battery size IDs
]]
function BatteryConfig.getInstantBatterySizes(): { string }
    local instant = {}
    for id, size in BatteryConfig.BATTERY_SIZES do
        if size.isInstant then
            table.insert(instant, id)
        end
    end
    return instant
end

--[[
    Get all storable (C/D/9V/Lantern) battery size IDs
]]
function BatteryConfig.getStorableBatterySizes(): { string }
    local storable = {}
    for id, size in BatteryConfig.BATTERY_SIZES do
        if not size.isInstant then
            table.insert(storable, id)
        end
    end
    return storable
end

return BatteryConfig
