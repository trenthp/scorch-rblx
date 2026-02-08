--!strict
--[[
    MonetizationService.lua
    Handles Robux purchases for battery packs and GamePass checks

    Features:
    - Process DevProduct purchases for battery packs
    - Check VIP GamePass ownership
    - Grant purchases to players
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemConfig = require(Shared:WaitForChild("ItemConfig"))

local MonetizationService = Knit.CreateService({
    Name = "MonetizationService",

    Client = {
        PurchaseCompleted = Knit.CreateSignal(),  -- (player, productId, success)
        VIPStatusChanged = Knit.CreateSignal(),   -- (player, hasVIP)
    },

    _vipCache = {} :: { [number]: boolean },  -- userId -> hasVIP
    _purchaseCompletedSignal = nil :: any,
})

function MonetizationService:KnitInit()
    self._vipCache = {}
    self._purchaseCompletedSignal = Signal.new()
    print("[MonetizationService] Initialized")
end

function MonetizationService:KnitStart()
    -- Set up DevProduct purchase handler
    MarketplaceService.ProcessReceipt = function(receiptInfo)
        return self:_processReceipt(receiptInfo)
    end

    -- Check VIP status for existing players
    for _, player in Players:GetPlayers() do
        task.spawn(function()
            self:_checkVIPStatus(player)
        end)
    end

    -- Check VIP for new players
    Players.PlayerAdded:Connect(function(player)
        self:_checkVIPStatus(player)
    end)

    -- Clean up on player leave
    Players.PlayerRemoving:Connect(function(player)
        self._vipCache[player.UserId] = nil
    end)

    print("[MonetizationService] Started")
end

--[[
    Process a DevProduct purchase receipt
    @param receiptInfo - The receipt information from Roblox
    @return Enum.ProductPurchaseDecision
]]
function MonetizationService:_processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        -- Player left, can't process - Roblox will retry
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local productId = receiptInfo.ProductId
    local purchaseId = receiptInfo.PurchaseId

    print(string.format("[MonetizationService] Processing purchase %s for %s (product %d)",
        purchaseId, player.Name, productId))

    -- Find which battery pack was purchased
    local packId = nil
    local batteryAmount = 0

    for id, pack in ItemConfig.BATTERY_PACKS do
        if pack.devProductId == productId then
            packId = id
            batteryAmount = ItemConfig.getBatteryPackAmount(id)
            break
        end
    end

    if packId and batteryAmount > 0 then
        -- Grant batteries
        local DataService = Knit.GetService("DataService")
        DataService:AddBatteries(player, batteryAmount)

        -- Notify client
        local BatteryService = Knit.GetService("BatteryService")
        local newTotal = DataService:GetBatteries(player)
        BatteryService.Client.CurrencyUpdated:Fire(player, newTotal)

        self.Client.PurchaseCompleted:Fire(player, productId, true)
        self._purchaseCompletedSignal:Fire(player, packId, batteryAmount)

        print(string.format("[MonetizationService] Granted %d batteries to %s",
            batteryAmount, player.Name))

        return Enum.ProductPurchaseDecision.PurchaseGranted
    else
        -- Unknown product
        warn(string.format("[MonetizationService] Unknown product ID: %d", productId))
        self.Client.PurchaseCompleted:Fire(player, productId, false)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
end

--[[
    Check and cache VIP status for a player
    @param player - The player to check
]]
function MonetizationService:_checkVIPStatus(player: Player)
    local vipGamePassId = ItemConfig.GAMEPASS_IDS.VIP

    if vipGamePassId == 0 then
        -- No VIP GamePass configured
        self._vipCache[player.UserId] = false
        return
    end

    local success, hasVIP = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, vipGamePassId)
    end)

    if success then
        self._vipCache[player.UserId] = hasVIP
        self.Client.VIPStatusChanged:Fire(player, hasVIP)

        if hasVIP then
            print(string.format("[MonetizationService] %s has VIP", player.Name))

            -- Grant VIP-exclusive items
            self:_grantVIPItems(player)
        end
    else
        -- Error checking, assume no VIP
        self._vipCache[player.UserId] = false
        warn(string.format("[MonetizationService] Failed to check VIP status for %s", player.Name))
    end
end

--[[
    Grant VIP-exclusive items to a player
    @param player - The VIP player
]]
function MonetizationService:_grantVIPItems(player: Player)
    local InventoryService = Knit.GetService("InventoryService")

    -- Unlock VIP flashlight (Spotlight)
    local inventory = InventoryService:GetInventory(player)
    if not table.find(inventory.unlockedFlashlights, "Spotlight") then
        table.insert(inventory.unlockedFlashlights, "Spotlight")
    end

    -- Unlock VIP skin
    if not table.find(inventory.unlockedSkins, "VIPExclusive") then
        table.insert(inventory.unlockedSkins, "VIPExclusive")
    end

    local DataService = Knit.GetService("DataService")
    DataService:SetInventory(player, inventory)

    InventoryService.Client.InventoryUpdated:Fire(player, inventory)

    print(string.format("[MonetizationService] Granted VIP items to %s", player.Name))
end

--[[
    Check if a player has VIP
    @param player - The player to check
    @return boolean - Whether they have VIP
]]
function MonetizationService:HasVIP(player: Player): boolean
    return self._vipCache[player.UserId] == true
end

--[[
    Prompt a player to purchase a battery pack
    @param player - The player
    @param packId - The pack to purchase
]]
function MonetizationService:PromptBatteryPack(player: Player, packId: string)
    local pack = ItemConfig.BATTERY_PACKS[packId]
    if not pack or not pack.devProductId then
        warn(string.format("[MonetizationService] Invalid pack or no devProductId: %s", packId))
        return
    end

    MarketplaceService:PromptProductPurchase(player, pack.devProductId)
end

--[[
    Prompt a player to purchase the VIP GamePass
    @param player - The player
]]
function MonetizationService:PromptVIP(player: Player)
    local vipGamePassId = ItemConfig.GAMEPASS_IDS.VIP
    if vipGamePassId == 0 then
        warn("[MonetizationService] VIP GamePass not configured")
        return
    end

    MarketplaceService:PromptGamePassPurchase(player, vipGamePassId)
end

--[[
    Subscribe to purchase completed events (server-side)
]]
function MonetizationService:OnPurchaseCompleted(callback: (player: Player, packId: string, amount: number) -> ())
    return self._purchaseCompletedSignal:Connect(callback)
end

-- Client methods
function MonetizationService.Client:HasVIP(player: Player): boolean
    return self.Server:HasVIP(player)
end

function MonetizationService.Client:PromptBatteryPack(player: Player, packId: string)
    self.Server:PromptBatteryPack(player, packId)
end

function MonetizationService.Client:PromptVIP(player: Player)
    self.Server:PromptVIP(player)
end

return MonetizationService
