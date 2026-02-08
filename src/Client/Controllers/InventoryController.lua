--!strict
--[[
    InventoryController.lua
    Client-side inventory and shop management

    Features:
    - Manage ShopPanel visibility
    - Handle purchase requests
    - Sync inventory state with server
    - Track equipped items locally
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemConfig = require(Shared:WaitForChild("ItemConfig"))
local StatsTypes = require(Shared:WaitForChild("StatsTypes"))

local LocalPlayer = Players.LocalPlayer

local InventoryController = Knit.CreateController({
    Name = "InventoryController",

    _inventory = nil :: StatsTypes.PlayerInventory?,
    _hasVIP = false,
    _shopPanel = nil :: any,

    -- Signals for UI
    _inventoryChangedSignal = nil :: any,
    _itemUnlockedSignal = nil :: any,
    _purchaseFailedSignal = nil :: any,
})

function InventoryController:KnitInit()
    self._inventoryChangedSignal = Signal.new()
    self._itemUnlockedSignal = Signal.new()
    self._purchaseFailedSignal = Signal.new()

    print("[InventoryController] Initialized")
end

function InventoryController:KnitStart()
    local InventoryService = Knit.GetService("InventoryService")
    local MonetizationService = Knit.GetService("MonetizationService")

    -- Listen for inventory updates
    InventoryService.InventoryUpdated:Connect(function(player, inventory)
        if player == LocalPlayer then
            self._inventory = inventory
            self._inventoryChangedSignal:Fire(inventory)
        end
    end)

    -- Listen for item unlocks
    InventoryService.ItemUnlocked:Connect(function(player, itemType, itemId)
        if player == LocalPlayer then
            self._itemUnlockedSignal:Fire(itemType, itemId)
        end
    end)

    -- Listen for purchase failures
    InventoryService.PurchaseFailed:Connect(function(player, reason)
        if player == LocalPlayer then
            self._purchaseFailedSignal:Fire(reason)
            warn("[InventoryController] Purchase failed:", reason)
        end
    end)

    -- Listen for VIP status changes
    MonetizationService.VIPStatusChanged:Connect(function(player, hasVIP)
        if player == LocalPlayer then
            self._hasVIP = hasVIP
        end
    end)

    -- Load initial inventory
    task.spawn(function()
        self._inventory = InventoryService:GetInventory()
        self._hasVIP = MonetizationService:HasVIP()

        if self._inventory then
            self._inventoryChangedSignal:Fire(self._inventory)
        end
    end)

    print("[InventoryController] Started")
end

--[[
    Get current inventory
]]
function InventoryController:GetInventory(): StatsTypes.PlayerInventory?
    return self._inventory
end

--[[
    Get equipped flashlight ID
]]
function InventoryController:GetEquippedFlashlight(): string
    if self._inventory then
        return self._inventory.equippedFlashlight
    end
    return "Standard"
end

--[[
    Get equipped skin ID
]]
function InventoryController:GetEquippedSkin(): string?
    if self._inventory then
        return self._inventory.equippedSkin
    end
    return nil
end

--[[
    Check if player owns a flashlight
]]
function InventoryController:OwnsFlashlight(flashlightId: string): boolean
    if not self._inventory then
        return false
    end
    return table.find(self._inventory.unlockedFlashlights, flashlightId) ~= nil
end

--[[
    Check if player owns a skin
]]
function InventoryController:OwnsSkin(skinId: string): boolean
    if not self._inventory then
        return false
    end
    return table.find(self._inventory.unlockedSkins, skinId) ~= nil
end

--[[
    Check if player has VIP
]]
function InventoryController:HasVIP(): boolean
    return self._hasVIP
end

--[[
    Request to unlock a flashlight
]]
function InventoryController:UnlockFlashlight(flashlightId: string)
    local InventoryService = Knit.GetService("InventoryService")
    return InventoryService:UnlockFlashlight(flashlightId)
end

--[[
    Request to unlock a skin
]]
function InventoryController:UnlockSkin(skinId: string)
    local InventoryService = Knit.GetService("InventoryService")
    return InventoryService:UnlockSkin(skinId)
end

--[[
    Request to equip a flashlight
]]
function InventoryController:EquipFlashlight(flashlightId: string)
    local InventoryService = Knit.GetService("InventoryService")
    return InventoryService:EquipFlashlight(flashlightId)
end

--[[
    Request to equip a skin
]]
function InventoryController:EquipSkin(skinId: string?)
    local InventoryService = Knit.GetService("InventoryService")
    return InventoryService:EquipSkin(skinId)
end

--[[
    Request to purchase a battery pack
]]
function InventoryController:PurchaseBatteryPack(packId: string)
    local MonetizationService = Knit.GetService("MonetizationService")
    MonetizationService:PromptBatteryPack(packId)
end

--[[
    Request to purchase VIP
]]
function InventoryController:PurchaseVIP()
    local MonetizationService = Knit.GetService("MonetizationService")
    MonetizationService:PromptVIP()
end

--[[
    Get all flashlight configs with ownership status
]]
function InventoryController:GetFlashlightList(): { { config: ItemConfig.FlashlightConfig, owned: boolean, equipped: boolean } }
    local list = {}
    local equippedId = self:GetEquippedFlashlight()

    for id, config in ItemConfig.FLASHLIGHT_TYPES do
        table.insert(list, {
            config = config,
            owned = self:OwnsFlashlight(id),
            equipped = id == equippedId,
        })
    end

    -- Sort by unlock level
    table.sort(list, function(a, b)
        local aLevel = a.config.unlockLevel or 0
        local bLevel = b.config.unlockLevel or 0
        return aLevel < bLevel
    end)

    return list
end

--[[
    Get all skin configs with ownership status
]]
function InventoryController:GetSkinList(): { { config: ItemConfig.SkinConfig, owned: boolean, equipped: boolean } }
    local list = {}
    local equippedId = self:GetEquippedSkin()

    for id, config in ItemConfig.SKINS do
        table.insert(list, {
            config = config,
            owned = self:OwnsSkin(id),
            equipped = id == equippedId,
        })
    end

    -- Sort by price
    table.sort(list, function(a, b)
        local aPrice = a.config.price or 0
        local bPrice = b.config.price or 0
        return aPrice < bPrice
    end)

    return list
end

--[[
    Get battery pack list
]]
function InventoryController:GetBatteryPackList(): { ItemConfig.ShopItem }
    local list = {}
    for _, pack in ItemConfig.BATTERY_PACKS do
        table.insert(list, pack)
    end

    -- Sort by Robux price
    table.sort(list, function(a, b)
        local aPrice = a.robuxPrice or 0
        local bPrice = b.robuxPrice or 0
        return aPrice < bPrice
    end)

    return list
end

--[[
    Set the ShopPanel UI component reference
]]
function InventoryController:SetShopPanel(shopPanel: any)
    self._shopPanel = shopPanel
end

--[[
    Show the shop panel
]]
function InventoryController:ShowShop()
    if self._shopPanel then
        self._shopPanel:show()
    end
end

--[[
    Hide the shop panel
]]
function InventoryController:HideShop()
    if self._shopPanel then
        self._shopPanel:hide()
    end
end

--[[
    Subscribe to inventory changed events
]]
function InventoryController:OnInventoryChanged(callback: (inventory: StatsTypes.PlayerInventory) -> ())
    return self._inventoryChangedSignal:Connect(callback)
end

--[[
    Subscribe to item unlocked events
]]
function InventoryController:OnItemUnlocked(callback: (itemType: string, itemId: string) -> ())
    return self._itemUnlockedSignal:Connect(callback)
end

--[[
    Subscribe to purchase failed events
]]
function InventoryController:OnPurchaseFailed(callback: (reason: string) -> ())
    return self._purchaseFailedSignal:Connect(callback)
end

return InventoryController
