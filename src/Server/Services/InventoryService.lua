--!strict
--[[
    InventoryService.lua
    Server-side inventory management for flashlights and skins

    Features:
    - Unlock flashlights and skins
    - Equip items
    - Check ownership and affordability
    - Handle purchases
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemConfig = require(Shared:WaitForChild("ItemConfig"))
local InventoryTypes = require(Shared:WaitForChild("InventoryTypes"))
local StatsTypes = require(Shared:WaitForChild("StatsTypes"))

local InventoryService = Knit.CreateService({
    Name = "InventoryService",

    Client = {
        InventoryUpdated = Knit.CreateSignal(),     -- (player, inventory)
        ItemUnlocked = Knit.CreateSignal(),         -- (player, itemType, itemId)
        ItemEquipped = Knit.CreateSignal(),         -- (player, itemType, itemId)
        PurchaseFailed = Knit.CreateSignal(),       -- (player, reason)
    },

    _inventoryChangedSignal = nil :: any,
})

function InventoryService:KnitInit()
    self._inventoryChangedSignal = Signal.new()
    print("[InventoryService] Initialized")
end

function InventoryService:KnitStart()
    print("[InventoryService] Started")
end

--[[
    Get a player's inventory
    @param player - The player
    @return PlayerInventory - The player's inventory (creates default if needed)
]]
function InventoryService:GetInventory(player: Player): StatsTypes.PlayerInventory
    local DataService = Knit.GetService("DataService")
    local inventory = DataService:GetInventory(player)

    if not inventory then
        -- Create default inventory
        inventory = InventoryTypes.createDefaultInventory()
        DataService:SetInventory(player, inventory)
    end

    return inventory
end

--[[
    Check if a player owns a flashlight
    @param player - The player
    @param flashlightId - The flashlight to check
    @return boolean - Whether the player owns it
]]
function InventoryService:OwnsFlashlight(player: Player, flashlightId: string): boolean
    local inventory = self:GetInventory(player)
    return table.find(inventory.unlockedFlashlights, flashlightId) ~= nil
end

--[[
    Check if a player owns a skin
    @param player - The player
    @param skinId - The skin to check
    @return boolean - Whether the player owns it
]]
function InventoryService:OwnsSkin(player: Player, skinId: string): boolean
    local inventory = self:GetInventory(player)
    return table.find(inventory.unlockedSkins, skinId) ~= nil
end

--[[
    Check if a player can afford a battery price
    @param player - The player
    @param price - The battery cost
    @return boolean - Whether they can afford it
]]
function InventoryService:CanAfford(player: Player, price: number): boolean
    local DataService = Knit.GetService("DataService")
    return DataService:GetBatteries(player) >= price
end

--[[
    Check if a player has VIP
    @param player - The player
    @return boolean - Whether they have VIP
]]
function InventoryService:HasVIP(player: Player): boolean
    local MonetizationService = Knit.GetService("MonetizationService")
    return MonetizationService:HasVIP(player)
end

--[[
    Get a player's level
    @param player - The player
    @return number - Player's level
]]
function InventoryService:GetPlayerLevel(player: Player): number
    local DataService = Knit.GetService("DataService")
    local data = DataService:GetPlayerData(player)
    if data and data.progression then
        return data.progression.level
    end
    return 1
end

--[[
    Unlock a flashlight for a player
    @param player - The player
    @param flashlightId - The flashlight to unlock
    @return boolean - Whether unlock was successful
]]
function InventoryService:UnlockFlashlight(player: Player, flashlightId: string): boolean
    -- Check if already owned
    if self:OwnsFlashlight(player, flashlightId) then
        return true  -- Already own it
    end

    local config = ItemConfig.getFlashlight(flashlightId)
    if not config then
        self.Client.PurchaseFailed:Fire(player, "Invalid flashlight")
        return false
    end

    -- Check VIP requirement
    if config.requiresVIP and not self:HasVIP(player) then
        self.Client.PurchaseFailed:Fire(player, "Requires VIP")
        return false
    end

    -- Check level requirement
    local playerLevel = self:GetPlayerLevel(player)
    if config.unlockLevel and playerLevel < config.unlockLevel then
        self.Client.PurchaseFailed:Fire(player, "Level too low")
        return false
    end

    -- Check price and deduct batteries
    if config.price and config.price > 0 then
        local DataService = Knit.GetService("DataService")
        if not DataService:SpendBatteries(player, config.price) then
            self.Client.PurchaseFailed:Fire(player, "Not enough batteries")
            return false
        end
    end

    -- Add to inventory
    local inventory = self:GetInventory(player)
    table.insert(inventory.unlockedFlashlights, flashlightId)

    local DataService = Knit.GetService("DataService")
    DataService:SetInventory(player, inventory)

    -- Notify
    self.Client.ItemUnlocked:Fire(player, "flashlight", flashlightId)
    self.Client.InventoryUpdated:Fire(player, inventory)
    self._inventoryChangedSignal:Fire(player, inventory)

    print(string.format("[InventoryService] %s unlocked flashlight: %s", player.Name, flashlightId))
    return true
end

--[[
    Unlock a skin for a player
    @param player - The player
    @param skinId - The skin to unlock
    @return boolean - Whether unlock was successful
]]
function InventoryService:UnlockSkin(player: Player, skinId: string): boolean
    -- Check if already owned
    if self:OwnsSkin(player, skinId) then
        return true  -- Already own it
    end

    local config = ItemConfig.getSkin(skinId)
    if not config then
        self.Client.PurchaseFailed:Fire(player, "Invalid skin")
        return false
    end

    -- Check VIP requirement
    if config.requiresVIP and not self:HasVIP(player) then
        self.Client.PurchaseFailed:Fire(player, "Requires VIP")
        return false
    end

    -- Check level requirement
    local playerLevel = self:GetPlayerLevel(player)
    if config.unlockLevel and playerLevel < config.unlockLevel then
        self.Client.PurchaseFailed:Fire(player, "Level too low")
        return false
    end

    -- Check price and deduct batteries
    if config.price and config.price > 0 then
        local DataService = Knit.GetService("DataService")
        if not DataService:SpendBatteries(player, config.price) then
            self.Client.PurchaseFailed:Fire(player, "Not enough batteries")
            return false
        end
    end

    -- Add to inventory
    local inventory = self:GetInventory(player)
    table.insert(inventory.unlockedSkins, skinId)

    local DataService = Knit.GetService("DataService")
    DataService:SetInventory(player, inventory)

    -- Notify
    self.Client.ItemUnlocked:Fire(player, "skin", skinId)
    self.Client.InventoryUpdated:Fire(player, inventory)
    self._inventoryChangedSignal:Fire(player, inventory)

    print(string.format("[InventoryService] %s unlocked skin: %s", player.Name, skinId))
    return true
end

--[[
    Equip a flashlight
    @param player - The player
    @param flashlightId - The flashlight to equip
    @return boolean - Whether equip was successful
]]
function InventoryService:EquipFlashlight(player: Player, flashlightId: string): boolean
    -- Check ownership
    if not self:OwnsFlashlight(player, flashlightId) then
        return false
    end

    local inventory = self:GetInventory(player)
    inventory.equippedFlashlight = flashlightId

    local DataService = Knit.GetService("DataService")
    DataService:SetInventory(player, inventory)

    -- Notify
    self.Client.ItemEquipped:Fire(player, "flashlight", flashlightId)
    self.Client.InventoryUpdated:Fire(player, inventory)
    self._inventoryChangedSignal:Fire(player, inventory)

    print(string.format("[InventoryService] %s equipped flashlight: %s", player.Name, flashlightId))
    return true
end

--[[
    Equip a skin
    @param player - The player
    @param skinId - The skin to equip (nil to unequip)
    @return boolean - Whether equip was successful
]]
function InventoryService:EquipSkin(player: Player, skinId: string?): boolean
    -- Check ownership (if not nil)
    if skinId and not self:OwnsSkin(player, skinId) then
        return false
    end

    local inventory = self:GetInventory(player)
    inventory.equippedSkin = skinId

    local DataService = Knit.GetService("DataService")
    DataService:SetInventory(player, inventory)

    -- Notify
    self.Client.ItemEquipped:Fire(player, "skin", skinId or "none")
    self.Client.InventoryUpdated:Fire(player, inventory)
    self._inventoryChangedSignal:Fire(player, inventory)

    print(string.format("[InventoryService] %s equipped skin: %s", player.Name, skinId or "none"))
    return true
end

--[[
    Get the equipped flashlight config for a player
    @param player - The player
    @return FlashlightConfig? - The equipped flashlight config
]]
function InventoryService:GetEquippedFlashlightConfig(player: Player): ItemConfig.FlashlightConfig?
    local inventory = self:GetInventory(player)
    return ItemConfig.getFlashlight(inventory.equippedFlashlight)
end

--[[
    Get the equipped skin config for a player
    @param player - The player
    @return SkinConfig? - The equipped skin config
]]
function InventoryService:GetEquippedSkinConfig(player: Player): ItemConfig.SkinConfig?
    local inventory = self:GetInventory(player)
    if inventory.equippedSkin then
        return ItemConfig.getSkin(inventory.equippedSkin)
    end
    return nil
end

--[[
    Subscribe to inventory changes
]]
function InventoryService:OnInventoryChanged(callback: (player: Player, inventory: StatsTypes.PlayerInventory) -> ())
    return self._inventoryChangedSignal:Connect(callback)
end

-- Client methods
function InventoryService.Client:GetInventory(player: Player): StatsTypes.PlayerInventory
    return self.Server:GetInventory(player)
end

function InventoryService.Client:UnlockFlashlight(player: Player, flashlightId: string): boolean
    return self.Server:UnlockFlashlight(player, flashlightId)
end

function InventoryService.Client:UnlockSkin(player: Player, skinId: string): boolean
    return self.Server:UnlockSkin(player, skinId)
end

function InventoryService.Client:EquipFlashlight(player: Player, flashlightId: string): boolean
    return self.Server:EquipFlashlight(player, flashlightId)
end

function InventoryService.Client:EquipSkin(player: Player, skinId: string?): boolean
    return self.Server:EquipSkin(player, skinId)
end

function InventoryService.Client:OwnsFlashlight(player: Player, flashlightId: string): boolean
    return self.Server:OwnsFlashlight(player, flashlightId)
end

function InventoryService.Client:OwnsSkin(player: Player, skinId: string): boolean
    return self.Server:OwnsSkin(player, skinId)
end

function InventoryService.Client:CanAfford(player: Player, price: number): boolean
    return self.Server:CanAfford(player, price)
end

return InventoryService
