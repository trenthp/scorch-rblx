# Monetization Scripts

## GamePass System

```lua
-- ServerScriptService/Services/GamePassService.lua
--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePassService = {}

-- Define your GamePasses
export type GamePassId = number

local GAME_PASSES = {
    VIP = 111111111,
    DoubleCoins = 222222222,
    DoubleGems = 333333333,
    AutoCollect = 444444444,
    ExtraStorage = 555555555,
    SpeedBoost = 666666666,
}

-- Cache ownership to reduce API calls
local ownershipCache: {[number]: {[GamePassId]: boolean}} = {}

local function clearCache(player: Player)
    ownershipCache[player.UserId] = nil
end

Players.PlayerRemoving:Connect(clearCache)

-- Check if player owns a GamePass
function GamePassService.Owns(player: Player, passName: string): boolean
    local passId = GAME_PASSES[passName]
    if not passId then return false end
    
    local userId = player.UserId
    
    -- Check cache first
    if ownershipCache[userId] and ownershipCache[userId][passId] ~= nil then
        return ownershipCache[userId][passId]
    end
    
    -- Query MarketplaceService
    local success, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(userId, passId)
    end)
    
    local result = success and owns or false
    
    -- Cache result
    if not ownershipCache[userId] then
        ownershipCache[userId] = {}
    end
    ownershipCache[userId][passId] = result
    
    return result
end

-- Prompt purchase
function GamePassService.Prompt(player: Player, passName: string)
    local passId = GAME_PASSES[passName]
    if not passId then return end
    
    MarketplaceService:PromptGamePassPurchase(player, passId)
end

-- Handle purchase completion
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
    if wasPurchased then
        -- Clear cache so new ownership is detected
        if ownershipCache[player.UserId] then
            ownershipCache[player.UserId][passId] = true
        end
        
        -- Fire event for other systems to react
        local PurchaseComplete = ReplicatedStorage.Remotes.Events.GamePassPurchased :: RemoteEvent
        PurchaseComplete:FireClient(player, passId)
        
        -- Grant immediate benefits
        applyGamePassBenefits(player, passId)
    end
end)

local function applyGamePassBenefits(player: Player, passId: number)
    -- Handle immediate effects
    if passId == GAME_PASSES.SpeedBoost then
        local character = player.Character
        local humanoid = character and character:FindFirstChild("Humanoid") :: Humanoid?
        if humanoid then
            humanoid.WalkSpeed = 24  -- Default is 16
        end
    end
    
    -- Other passes might affect multipliers, which are checked dynamically
end

-- Get all passes and their ownership status
function GamePassService.GetAllPasses(player: Player): {[string]: {id: number, owned: boolean}}
    local result = {}
    for name, id in GAME_PASSES do
        result[name] = {
            id = id,
            owned = GamePassService.Owns(player, name),
        }
    end
    return result
end

-- Expose pass IDs for client use
function GamePassService.GetPassId(passName: string): number?
    return GAME_PASSES[passName]
end

return GamePassService
```

## Developer Products System

```lua
-- ServerScriptService/Services/ProductService.lua
--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local ProductService = {}

-- Define products
local PRODUCTS = {
    -- Currency packs
    [1111111] = { type = "currency", currency = "Coins", amount = 1000 },
    [1111112] = { type = "currency", currency = "Coins", amount = 5000 },
    [1111113] = { type = "currency", currency = "Coins", amount = 10000 },
    [1111114] = { type = "currency", currency = "Gems", amount = 100 },
    [1111115] = { type = "currency", currency = "Gems", amount = 500 },
    
    -- Boosts
    [2222221] = { type = "boost", boostType = "2xCoins", duration = 1800 }, -- 30 min
    [2222222] = { type = "boost", boostType = "2xCoins", duration = 3600 }, -- 60 min
    [2222223] = { type = "boost", boostType = "2xXP", duration = 1800 },
    
    -- Crates
    [3333331] = { type = "crate", crateType = "Common" },
    [3333332] = { type = "crate", crateType = "Rare" },
    [3333333] = { type = "crate", crateType = "Legendary" },
    
    -- Misc
    [4444441] = { type = "revive" },
    [4444442] = { type = "skipStage" },
}

-- Purchase tracking for idempotency
local PurchaseHistory = DataStoreService:GetDataStore("PurchaseHistory")

local function recordPurchase(receiptInfo): boolean
    local key = receiptInfo.PlayerId .. "_" .. receiptInfo.PurchaseId
    
    local success = pcall(function()
        PurchaseHistory:UpdateAsync(key, function(oldData)
            if oldData then
                return oldData -- Already processed
            end
            return { processed = true, time = os.time() }
        end)
    end)
    
    return success
end

local function isPurchaseProcessed(receiptInfo): boolean
    local key = receiptInfo.PlayerId .. "_" .. receiptInfo.PurchaseId
    
    local success, data = pcall(function()
        return PurchaseHistory:GetAsync(key)
    end)
    
    return success and data ~= nil
end

-- Process receipt
local function processReceipt(receiptInfo): Enum.ProductPurchaseDecision
    -- Check if already processed
    if isPurchaseProcessed(receiptInfo) then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    local product = PRODUCTS[receiptInfo.ProductId]
    if not product then
        warn("Unknown product:", receiptInfo.ProductId)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    local success = false
    
    if product.type == "currency" then
        success = grantCurrency(player, product)
    elseif product.type == "boost" then
        success = grantBoost(player, product)
    elseif product.type == "crate" then
        success = grantCrate(player, product)
    elseif product.type == "revive" then
        success = grantRevive(player)
    elseif product.type == "skipStage" then
        success = grantSkipStage(player)
    end
    
    if success then
        recordPurchase(receiptInfo)
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Grant functions
local function grantCurrency(player: Player, product): boolean
    return CurrencyService.Add(player, product.currency, product.amount, false) > 0
end

local function grantBoost(player: Player, product): boolean
    local data = DataService.GetData(player)
    if not data then return false end
    
    -- Store active boosts
    if not data.ActiveBoosts then
        data.ActiveBoosts = {}
    end
    
    local expiry = os.time() + product.duration
    local existing = data.ActiveBoosts[product.boostType]
    
    if existing and existing > os.time() then
        -- Extend existing boost
        data.ActiveBoosts[product.boostType] = existing + product.duration
    else
        data.ActiveBoosts[product.boostType] = expiry
    end
    
    return true
end

local function grantCrate(player: Player, product): boolean
    -- Implement your crate/loot box logic
    local CrateService = require(script.Parent.CrateService)
    return CrateService.OpenCrate(player, product.crateType)
end

local function grantRevive(player: Player): boolean
    -- Implement revive logic
    local character = player.Character
    local humanoid = character and character:FindFirstChild("Humanoid") :: Humanoid?
    if humanoid and humanoid.Health <= 0 then
        player:LoadCharacter()
        return true
    end
    return false
end

local function grantSkipStage(player: Player): boolean
    -- Implement skip logic for obby/level games
    local ProgressService = require(script.Parent.ProgressService)
    return ProgressService.SkipStage(player)
end

-- Prompt purchase
function ProductService.Prompt(player: Player, productId: number)
    MarketplaceService:PromptProductPurchase(player, productId)
end

-- Check if boost is active
function ProductService.IsBoostActive(player: Player, boostType: string): boolean
    local data = DataService.GetData(player)
    if not data or not data.ActiveBoosts then return false end
    
    local expiry = data.ActiveBoosts[boostType]
    return expiry and expiry > os.time()
end

function ProductService.GetBoostTimeRemaining(player: Player, boostType: string): number
    local data = DataService.GetData(player)
    if not data or not data.ActiveBoosts then return 0 end
    
    local expiry = data.ActiveBoosts[boostType]
    if expiry and expiry > os.time() then
        return expiry - os.time()
    end
    return 0
end

-- Set receipt processor
MarketplaceService.ProcessReceipt = processReceipt

return ProductService
```

## Premium Payouts

Premium Payouts are automatic based on Premium subscriber engagement time. To maximize:

```lua
-- Tips for Premium Payout optimization:

-- 1. Track premium status
local function isPremium(player: Player): boolean
    return player.MembershipType == Enum.MembershipType.Premium
end

-- 2. Offer premium-exclusive benefits (non-pay-to-win)
local function getPremiumMultiplier(player: Player): number
    if isPremium(player) then
        return 1.1  -- 10% bonus for Premium members
    end
    return 1
end

-- 3. Show premium badge/indicator
local function setupPremiumBadge(player: Player)
    if isPremium(player) then
        -- Add visual indicator above character
        -- Show in leaderboard
        -- Premium-only chat tag
    end
end

-- 4. Premium-exclusive cosmetics
local PREMIUM_ITEMS = {
    "PremiumSkin_Gold",
    "PremiumPet_Diamond",
    "PremiumTrail_Sparkle",
}
```

## Purchase Prompts (Client-Side UI)

```lua
-- StarterGui/ShopUI/ShopController.client.lua
--!strict
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = script.Parent

-- Product data for display
local PRODUCT_DISPLAY = {
    Coins = {
        { id = 1111111, amount = 1000, price = 50 },
        { id = 1111112, amount = 5000, price = 200 },
        { id = 1111113, amount = 10000, price = 350, badge = "BEST VALUE" },
    },
    Gems = {
        { id = 1111114, amount = 100, price = 75 },
        { id = 1111115, amount = 500, price = 300, badge = "POPULAR" },
    },
}

local function createProductButton(product, parent)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 150, 0, 80)
    button.Text = string.format("%d\n%d R$", product.amount, product.price)
    
    if product.badge then
        -- Add badge label
        local badge = Instance.new("TextLabel")
        badge.Text = product.badge
        badge.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
        badge.Parent = button
    end
    
    button.MouseButton1Click:Connect(function()
        MarketplaceService:PromptProductPurchase(player, product.id)
    end)
    
    button.Parent = parent
end

-- GamePass button
local function promptGamePass(passId: number)
    -- Check if already owned
    local success, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
    end)
    
    if success and owns then
        -- Already owned, show message
        print("You already own this GamePass!")
        return
    end
    
    MarketplaceService:PromptGamePassPurchase(player, passId)
end

-- Update UI when purchase completes
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
    if wasPurchased and userId == player.UserId then
        -- Play purchase animation/sound
        -- Update displayed currency
    end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, wasPurchased)
    if wasPurchased and plr == player then
        -- Update UI to show "OWNED"
        -- Play celebration effect
    end
end)
```

## Purchase Analytics (Track what sells)

```lua
-- ServerScriptService/Services/AnalyticsService.lua
--!strict
local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

function Analytics.TrackPurchase(player: Player, productType: string, productId: number, robuxAmount: number)
    -- Use Roblox Analytics
    pcall(function()
        AnalyticsService:LogEconomyEvent(
            player,
            Enum.AnalyticsEconomyFlowType.Source,
            "Robux",
            robuxAmount,
            robuxAmount, -- Balance after (approximate)
            Enum.AnalyticsEconomyTransactionType.IAP.Name,
            productType .. "_" .. productId
        )
    end)
end

function Analytics.TrackCurrencySpend(player: Player, currency: string, amount: number, itemName: string)
    pcall(function()
        AnalyticsService:LogEconomyEvent(
            player,
            Enum.AnalyticsEconomyFlowType.Sink,
            currency,
            amount,
            0, -- Calculate actual balance
            Enum.AnalyticsEconomyTransactionType.Shop.Name,
            itemName
        )
    end)
end

function Analytics.TrackFunnel(player: Player, funnelName: string, step: number, stepName: string)
    pcall(function()
        AnalyticsService:LogFunnelStepEvent(
            player,
            funnelName,
            step,
            stepName
        )
    end)
end

return Analytics
```

## Pricing Strategy Reference

| Price (R$) | Target | Conversion Rate | Use For |
|------------|--------|-----------------|---------|
| 25-50 | Impulse | High | Small boosts, cosmetics |
| 75-150 | Casual | Medium | Starter packs, 2x passes |
| 200-400 | Committed | Medium-Low | VIP, major perks |
| 500-1000 | Whale | Low | Premium bundles |
| 1500+ | Super Whale | Very Low | Ultimate editions |

**Tiering Example (Currency Pack):**
- 1,000 Coins = 50 R$ (20 coins/R$)
- 5,000 Coins = 200 R$ (25 coins/R$) - "20% MORE VALUE"
- 12,000 Coins = 400 R$ (30 coins/R$) - "50% MORE VALUE - BEST DEAL"

Always make the middle or larger pack the best value to encourage larger purchases.
