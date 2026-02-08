--!strict
--[[
    ItemConfig.lua
    Configuration for flashlight types, skins, and shop items

    Flashlight Types:
    - Standard: Default flashlight
    - Wide: Wider beam, shorter range
    - Focused: Narrow beam, longer range
    - Strobe: Flashing effect
    - UV: Purple light, special visibility
    - Spotlight: VIP exclusive, premium beam
]]

export type FlashlightConfig = {
    id: string,
    name: string,
    description: string,
    range: number,           -- Detection range in studs
    angle: number,           -- Beam angle in degrees
    brightness: number,      -- Light brightness
    unlockLevel: number?,    -- Level required (nil = free/default)
    price: number?,          -- Battery price (nil = not purchasable with currency)
    requiresVIP: boolean,    -- Requires VIP gamepass
    lightColor: Color3?,     -- Custom light color (nil = default white)
}

export type SkinConfig = {
    id: string,
    name: string,
    description: string,
    bodyColor: Color3,
    headColor: Color3?,      -- Optional, uses bodyColor if nil
    lensColor: Color3?,      -- Optional glow color
    unlockLevel: number?,    -- Level required (nil = purchasable anytime)
    price: number?,          -- Battery price (nil = free/level reward)
    requiresVIP: boolean,
}

export type ShopItem = {
    id: string,
    itemType: string,        -- "flashlight", "skin", "battery_pack"
    name: string,
    description: string,
    price: number?,          -- Battery price
    robuxPrice: number?,     -- Robux price (nil = not purchasable with Robux)
    devProductId: number?,   -- Roblox DevProduct ID for Robux purchase
}

local ItemConfig = {}

-- Flashlight types with different properties
ItemConfig.FLASHLIGHT_TYPES = {
    Standard = {
        id = "Standard",
        name = "Standard Flashlight",
        description = "The default flashlight. Balanced range and angle.",
        range = 50,
        angle = 45,
        brightness = 2,
        unlockLevel = nil,  -- Default, always available
        price = nil,
        requiresVIP = false,
    },
    Wide = {
        id = "Wide",
        name = "Wide Beam",
        description = "A wider beam for covering more area. Shorter range.",
        range = 35,
        angle = 70,
        brightness = 1.8,
        unlockLevel = 10,
        price = 500,
        requiresVIP = false,
    },
    Focused = {
        id = "Focused",
        name = "Focused Beam",
        description = "A narrow, concentrated beam. Longer range.",
        range = 70,
        angle = 25,
        brightness = 2.5,
        unlockLevel = 15,
        price = 750,
        requiresVIP = false,
    },
    Strobe = {
        id = "Strobe",
        name = "Strobe Light",
        description = "A flashing beam. Disorienting for runners.",
        range = 45,
        angle = 45,
        brightness = 3,
        unlockLevel = 20,
        price = 1000,
        requiresVIP = false,
    },
    UV = {
        id = "UV",
        name = "UV Light",
        description = "A purple ultraviolet beam. Reveals hidden trails.",
        range = 40,
        angle = 50,
        brightness = 2,
        unlockLevel = 25,
        price = 1500,
        requiresVIP = false,
        lightColor = Color3.fromRGB(170, 85, 200),  -- Purple
    },
    Spotlight = {
        id = "Spotlight",
        name = "Spotlight",
        description = "A powerful premium beam. VIP exclusive.",
        range = 60,
        angle = 55,
        brightness = 3,
        unlockLevel = nil,
        price = nil,  -- VIP only
        requiresVIP = true,
    },
}

-- Flashlight skins (cosmetic)
ItemConfig.SKINS = {
    Default = {
        id = "Default",
        name = "Default",
        description = "Standard black flashlight.",
        bodyColor = Color3.fromRGB(40, 40, 40),
        headColor = Color3.fromRGB(60, 60, 60),
        unlockLevel = nil,
        price = nil,  -- Free default
        requiresVIP = false,
    },
    Chrome = {
        id = "Chrome",
        name = "Chrome",
        description = "Sleek silver finish.",
        bodyColor = Color3.fromRGB(180, 180, 190),
        headColor = Color3.fromRGB(200, 200, 210),
        unlockLevel = nil,
        price = 50,
        requiresVIP = false,
    },
    Gold = {
        id = "Gold",
        name = "Gold",
        description = "Prestigious golden flashlight.",
        bodyColor = Color3.fromRGB(255, 200, 50),
        headColor = Color3.fromRGB(255, 220, 80),
        unlockLevel = nil,
        price = 200,
        requiresVIP = false,
    },
    Ruby = {
        id = "Ruby",
        name = "Ruby",
        description = "Deep red gemstone finish.",
        bodyColor = Color3.fromRGB(200, 40, 60),
        headColor = Color3.fromRGB(220, 60, 80),
        lensColor = Color3.fromRGB(255, 100, 100),
        unlockLevel = nil,
        price = 300,
        requiresVIP = false,
    },
    Emerald = {
        id = "Emerald",
        name = "Emerald",
        description = "Rich green gemstone finish.",
        bodyColor = Color3.fromRGB(40, 180, 80),
        headColor = Color3.fromRGB(60, 200, 100),
        lensColor = Color3.fromRGB(100, 255, 150),
        unlockLevel = nil,
        price = 300,
        requiresVIP = false,
    },
    Sapphire = {
        id = "Sapphire",
        name = "Sapphire",
        description = "Brilliant blue gemstone finish.",
        bodyColor = Color3.fromRGB(40, 80, 200),
        headColor = Color3.fromRGB(60, 100, 220),
        lensColor = Color3.fromRGB(100, 150, 255),
        unlockLevel = nil,
        price = 300,
        requiresVIP = false,
    },
    Neon = {
        id = "Neon",
        name = "Neon",
        description = "Glowing cyberpunk aesthetic.",
        bodyColor = Color3.fromRGB(20, 20, 30),
        headColor = Color3.fromRGB(30, 30, 40),
        lensColor = Color3.fromRGB(0, 255, 200),
        unlockLevel = 15,
        price = 400,
        requiresVIP = false,
    },
    Obsidian = {
        id = "Obsidian",
        name = "Obsidian",
        description = "Dark volcanic glass finish.",
        bodyColor = Color3.fromRGB(15, 15, 20),
        headColor = Color3.fromRGB(25, 25, 30),
        lensColor = Color3.fromRGB(80, 50, 120),
        unlockLevel = 20,
        price = 500,
        requiresVIP = false,
    },
    Rainbow = {
        id = "Rainbow",
        name = "Rainbow",
        description = "Color-shifting prismatic finish.",
        bodyColor = Color3.fromRGB(255, 100, 100),  -- Animated in client
        headColor = Color3.fromRGB(255, 150, 100),
        lensColor = Color3.fromRGB(255, 255, 255),
        unlockLevel = 30,
        price = 1000,
        requiresVIP = false,
    },
    VIPExclusive = {
        id = "VIPExclusive",
        name = "VIP Exclusive",
        description = "Exclusive golden trim design.",
        bodyColor = Color3.fromRGB(30, 30, 40),
        headColor = Color3.fromRGB(255, 200, 50),
        lensColor = Color3.fromRGB(255, 255, 200),
        unlockLevel = nil,
        price = nil,
        requiresVIP = true,
    },
}

-- Battery pack shop items (for purchasing currency with Robux)
ItemConfig.BATTERY_PACKS = {
    StarterPack = {
        id = "StarterPack",
        itemType = "battery_pack",
        name = "Starter Pack",
        description = "100 Batteries",
        price = nil,
        robuxPrice = 49,
        devProductId = nil,  -- Set this to your actual DevProduct ID
    },
    ValuePack = {
        id = "ValuePack",
        itemType = "battery_pack",
        name = "Value Pack",
        description = "500 Batteries (+50 bonus)",
        price = nil,
        robuxPrice = 199,
        devProductId = nil,
    },
    MegaPack = {
        id = "MegaPack",
        itemType = "battery_pack",
        name = "Mega Pack",
        description = "1200 Batteries (+200 bonus)",
        price = nil,
        robuxPrice = 399,
        devProductId = nil,
    },
    UltraPack = {
        id = "UltraPack",
        itemType = "battery_pack",
        name = "Ultra Pack",
        description = "3000 Batteries (+750 bonus)",
        price = nil,
        robuxPrice = 799,
        devProductId = nil,
    },
}

-- GamePass IDs (set these to your actual GamePass IDs)
ItemConfig.GAMEPASS_IDS = {
    VIP = 0,  -- Replace with actual VIP GamePass ID
}

--[[
    Get flashlight config by ID
]]
function ItemConfig.getFlashlight(flashlightId: string): FlashlightConfig?
    return ItemConfig.FLASHLIGHT_TYPES[flashlightId]
end

--[[
    Get skin config by ID
]]
function ItemConfig.getSkin(skinId: string): SkinConfig?
    return ItemConfig.SKINS[skinId]
end

--[[
    Get default flashlight ID
]]
function ItemConfig.getDefaultFlashlightId(): string
    return "Standard"
end

--[[
    Get default skin ID
]]
function ItemConfig.getDefaultSkinId(): string
    return "Default"
end

--[[
    Check if a player meets the level requirement for a flashlight
]]
function ItemConfig.canUnlockFlashlight(flashlightId: string, playerLevel: number, hasVIP: boolean): boolean
    local config = ItemConfig.FLASHLIGHT_TYPES[flashlightId]
    if not config then
        return false
    end

    if config.requiresVIP and not hasVIP then
        return false
    end

    if config.unlockLevel and playerLevel < config.unlockLevel then
        return false
    end

    return true
end

--[[
    Check if a player meets the requirements for a skin
]]
function ItemConfig.canUnlockSkin(skinId: string, playerLevel: number, hasVIP: boolean): boolean
    local config = ItemConfig.SKINS[skinId]
    if not config then
        return false
    end

    if config.requiresVIP and not hasVIP then
        return false
    end

    if config.unlockLevel and playerLevel < config.unlockLevel then
        return false
    end

    return true
end

--[[
    Get all flashlights a player can unlock at their level
]]
function ItemConfig.getAvailableFlashlights(playerLevel: number, hasVIP: boolean): { FlashlightConfig }
    local available = {}
    for _, config in ItemConfig.FLASHLIGHT_TYPES do
        if ItemConfig.canUnlockFlashlight(config.id, playerLevel, hasVIP) then
            table.insert(available, config)
        end
    end
    return available
end

--[[
    Get all skins a player can unlock at their level
]]
function ItemConfig.getAvailableSkins(playerLevel: number, hasVIP: boolean): { SkinConfig }
    local available = {}
    for _, config in ItemConfig.SKINS do
        if ItemConfig.canUnlockSkin(config.id, playerLevel, hasVIP) then
            table.insert(available, config)
        end
    end
    return available
end

--[[
    Get battery amount for a pack
]]
function ItemConfig.getBatteryPackAmount(packId: string): number
    local amounts = {
        StarterPack = 100,
        ValuePack = 550,    -- 500 + 50 bonus
        MegaPack = 1400,    -- 1200 + 200 bonus
        UltraPack = 3750,   -- 3000 + 750 bonus
    }
    return amounts[packId] or 0
end

return ItemConfig
