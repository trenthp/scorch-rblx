--!strict
--[[
    InventoryTypes.lua
    Type definitions for inventory system (future-proofing)
]]

-- Flashlight customization
export type FlashlightType = {
    id: string,
    name: string,
    description: string,
    range: number,             -- Detection range in studs
    angle: number,             -- Beam angle in degrees
    brightness: number,        -- Light brightness
    unlockLevel: number?,      -- Level required to unlock (nil = default/free)
    price: number?,            -- Battery price (nil = not purchasable)
    requiresVIP: boolean,      -- Requires VIP gamepass
    lightColor: Color3?,       -- Custom light color
}

-- Cosmetic skin for flashlight
export type FlashlightSkin = {
    id: string,
    name: string,
    description: string,
    bodyColor: Color3,
    headColor: Color3?,        -- Optional, uses bodyColor if nil
    lensColor: Color3?,        -- Optional glow color
    unlockLevel: number?,      -- Level required (nil = purchasable anytime)
    price: number?,            -- Battery price (nil = free/level reward)
    requiresVIP: boolean,
}

-- Player inventory data
export type PlayerInventory = {
    equippedFlashlight: string,            -- Flashlight type ID
    equippedSkin: string?,                 -- Optional skin ID
    unlockedFlashlights: { string },       -- List of unlocked flashlight IDs
    unlockedSkins: { string },             -- List of unlocked skin IDs
}

-- Default values
local InventoryTypes = {
    -- Default flashlight
    DEFAULT_FLASHLIGHT = "standard",

    -- Default inventory for new players
    DEFAULT_INVENTORY = {
        equippedFlashlight = "standard",
        equippedSkin = nil,
        unlockedFlashlights = { "standard" },
        unlockedSkins = {},
    } :: PlayerInventory,

    -- Available flashlight types
    FLASHLIGHT_TYPES = {
        Standard = {
            id = "Standard",
            name = "Standard",
            description = "The default flashlight. Balanced range and angle.",
            range = 50,
            angle = 45,
            brightness = 2,
            unlockLevel = nil,
            price = nil,
            requiresVIP = false,
        } :: FlashlightType,
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
        } :: FlashlightType,
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
        } :: FlashlightType,
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
        } :: FlashlightType,
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
            lightColor = Color3.fromRGB(170, 85, 200),
        } :: FlashlightType,
        Spotlight = {
            id = "Spotlight",
            name = "Spotlight",
            description = "A powerful premium beam. VIP exclusive.",
            range = 60,
            angle = 55,
            brightness = 3,
            unlockLevel = nil,
            price = nil,
            requiresVIP = true,
        } :: FlashlightType,
    },

    -- Available skins
    SKINS = {
        Default = {
            id = "Default",
            name = "Default",
            description = "Standard black flashlight.",
            bodyColor = Color3.fromRGB(40, 40, 40),
            headColor = Color3.fromRGB(60, 60, 60),
            unlockLevel = nil,
            price = nil,
            requiresVIP = false,
        } :: FlashlightSkin,
        Chrome = {
            id = "Chrome",
            name = "Chrome",
            description = "Sleek silver finish.",
            bodyColor = Color3.fromRGB(180, 180, 190),
            headColor = Color3.fromRGB(200, 200, 210),
            unlockLevel = nil,
            price = 50,
            requiresVIP = false,
        } :: FlashlightSkin,
        Gold = {
            id = "Gold",
            name = "Gold",
            description = "Prestigious golden flashlight.",
            bodyColor = Color3.fromRGB(255, 200, 50),
            headColor = Color3.fromRGB(255, 220, 80),
            unlockLevel = nil,
            price = 200,
            requiresVIP = false,
        } :: FlashlightSkin,
    },
}

--[[
    Create a new default inventory
]]
function InventoryTypes.createDefaultInventory(): PlayerInventory
    return {
        equippedFlashlight = InventoryTypes.DEFAULT_FLASHLIGHT,
        equippedSkin = nil,
        unlockedFlashlights = { InventoryTypes.DEFAULT_FLASHLIGHT },
        unlockedSkins = {},
    }
end

--[[
    Get flashlight type data by ID
]]
function InventoryTypes.getFlashlightType(id: string): FlashlightType?
    return InventoryTypes.FLASHLIGHT_TYPES[id]
end

--[[
    Get skin data by ID
]]
function InventoryTypes.getSkin(id: string): FlashlightSkin?
    return InventoryTypes.SKINS[id]
end

--[[
    Check if a player can use a flashlight
]]
function InventoryTypes.canUseFlashlight(inventory: PlayerInventory, flashlightId: string): boolean
    return table.find(inventory.unlockedFlashlights, flashlightId) ~= nil
end

--[[
    Check if a player can use a skin
]]
function InventoryTypes.canUseSkin(inventory: PlayerInventory, skinId: string): boolean
    return table.find(inventory.unlockedSkins, skinId) ~= nil
end

--[[
    Get flashlight range/angle for a given type
]]
function InventoryTypes.getFlashlightProperties(flashlightId: string): (number, number, number)
    local config = InventoryTypes.FLASHLIGHT_TYPES[flashlightId]
    if config then
        return config.range, config.angle, config.brightness
    end
    -- Default values
    return 50, 45, 2
end

return InventoryTypes
