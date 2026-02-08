# Core Systems Implementation

## Data Service (ProfileService)

ProfileService is recommended for production. Install via Rojo or copy into ServerStorage.

### Setup
```lua
-- ServerScriptService/Services/DataService.lua
--!strict
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileService = require(ServerStorage.Libs.ProfileService)

local DataService = {}

-- Define your data template
local PROFILE_TEMPLATE = {
    -- Currencies
    Coins = 0,
    Gems = 0,
    
    -- Progression
    Level = 1,
    Experience = 0,
    Rebirths = 0,
    
    -- Collections
    Inventory = {},
    Pets = {},
    Achievements = {},
    
    -- Settings
    Settings = {
        MusicVolume = 0.5,
        SFXVolume = 0.5,
        ShowDamageNumbers = true,
    },
    
    -- Metadata
    JoinDate = 0,
    LastLogin = 0,
    PlayTime = 0,
    Version = 1,
}

local ProfileStore = ProfileService.GetProfileStore("PlayerData_v1", PROFILE_TEMPLATE)
local Profiles: {[Player]: typeof(ProfileService.Profile)} = {}

-- Events
local DataLoaded = Instance.new("BindableEvent")
DataService.DataLoaded = DataLoaded.Event

local function onPlayerAdded(player: Player)
    local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)
    
    if profile then
        profile:AddUserId(player.UserId)
        profile:Reconcile() -- Fill missing values from template
        
        profile:ListenToRelease(function()
            Profiles[player] = nil
            player:Kick("Data session released. Please rejoin.")
        end)
        
        if player:IsDescendantOf(Players) then
            Profiles[player] = profile
            
            -- Update metadata
            profile.Data.LastLogin = os.time()
            if profile.Data.JoinDate == 0 then
                profile.Data.JoinDate = os.time()
            end
            
            DataLoaded:Fire(player, profile.Data)
        else
            profile:Release()
        end
    else
        player:Kick("Failed to load data. Please rejoin.")
    end
end

local function onPlayerRemoving(player: Player)
    local profile = Profiles[player]
    if profile then
        profile:Release()
    end
end

function DataService.GetData(player: Player)
    local profile = Profiles[player]
    return profile and profile.Data
end

function DataService.GetProfile(player: Player)
    return Profiles[player]
end

-- Utility functions
function DataService.AddCoins(player: Player, amount: number): boolean
    local data = DataService.GetData(player)
    if not data then return false end
    data.Coins = math.max(0, data.Coins + amount)
    return true
end

function DataService.AddGems(player: Player, amount: number): boolean
    local data = DataService.GetData(player)
    if not data then return false end
    data.Gems = math.max(0, data.Gems + amount)
    return true
end

function DataService.HasEnough(player: Player, currency: string, amount: number): boolean
    local data = DataService.GetData(player)
    if not data then return false end
    return (data[currency] or 0) >= amount
end

-- Initialize
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end

return DataService
```

## Currency System

```lua
-- ServerScriptService/Services/CurrencyService.lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)

local CurrencyService = {}

local UpdateCurrency = ReplicatedStorage.Remotes.Events.UpdateCurrency :: RemoteEvent

export type CurrencyType = "Coins" | "Gems"

local MULTIPLIER_PASSES = {
    Coins = {
        [123456] = 2,  -- 2x Coins GamePass ID
    },
    Gems = {
        [123457] = 2,  -- 2x Gems GamePass ID
    },
}

local function getMultiplier(player: Player, currency: CurrencyType): number
    local MarketplaceService = game:GetService("MarketplaceService")
    local multiplier = 1
    
    local passes = MULTIPLIER_PASSES[currency]
    if passes then
        for passId, mult in passes do
            local success, owns = pcall(function()
                return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
            end)
            if success and owns then
                multiplier *= mult
            end
        end
    end
    
    -- Rebirth multiplier
    local data = DataService.GetData(player)
    if data then
        multiplier *= (1 + data.Rebirths * 0.1) -- 10% per rebirth
    end
    
    return multiplier
end

function CurrencyService.Add(player: Player, currency: CurrencyType, amount: number, applyMultiplier: boolean?): number
    local data = DataService.GetData(player)
    if not data then return 0 end
    
    local finalAmount = amount
    if applyMultiplier ~= false then
        finalAmount = math.floor(amount * getMultiplier(player, currency))
    end
    
    data[currency] = (data[currency] or 0) + finalAmount
    UpdateCurrency:FireClient(player, currency, data[currency])
    
    return finalAmount
end

function CurrencyService.Remove(player: Player, currency: CurrencyType, amount: number): boolean
    local data = DataService.GetData(player)
    if not data then return false end
    
    if (data[currency] or 0) < amount then return false end
    
    data[currency] -= amount
    UpdateCurrency:FireClient(player, currency, data[currency])
    return true
end

function CurrencyService.Get(player: Player, currency: CurrencyType): number
    local data = DataService.GetData(player)
    return data and data[currency] or 0
end

function CurrencyService.GetMultiplier(player: Player, currency: CurrencyType): number
    return getMultiplier(player, currency)
end

return CurrencyService
```

## Inventory System

```lua
-- ServerScriptService/Services/InventoryService.lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)

local InventoryService = {}

local UpdateInventory = ReplicatedStorage.Remotes.Events.UpdateInventory :: RemoteEvent

export type ItemData = {
    id: string,
    quantity: number,
    metadata: {[string]: any}?,
}

local MAX_STACK = 99
local DEFAULT_SLOTS = 20
local EXTRA_SLOTS_PASS = 123458  -- GamePass for extra slots

local function getMaxSlots(player: Player): number
    local MarketplaceService = game:GetService("MarketplaceService")
    local slots = DEFAULT_SLOTS
    
    local success, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, EXTRA_SLOTS_PASS)
    end)
    
    if success and owns then
        slots += 20  -- +20 extra slots
    end
    
    return slots
end

function InventoryService.AddItem(player: Player, itemId: string, quantity: number?, metadata: {[string]: any}?): boolean
    local data = DataService.GetData(player)
    if not data then return false end
    
    local qty = quantity or 1
    local inventory = data.Inventory
    
    -- Try to stack with existing
    for _, item in inventory do
        if item.id == itemId and item.quantity < MAX_STACK then
            local canAdd = math.min(qty, MAX_STACK - item.quantity)
            item.quantity += canAdd
            qty -= canAdd
            if qty <= 0 then
                UpdateInventory:FireClient(player, inventory)
                return true
            end
        end
    end
    
    -- Add new stacks
    while qty > 0 do
        if #inventory >= getMaxSlots(player) then
            UpdateInventory:FireClient(player, inventory)
            return false -- Inventory full
        end
        
        local stackSize = math.min(qty, MAX_STACK)
        table.insert(inventory, {
            id = itemId,
            quantity = stackSize,
            metadata = metadata,
        })
        qty -= stackSize
    end
    
    UpdateInventory:FireClient(player, inventory)
    return true
end

function InventoryService.RemoveItem(player: Player, itemId: string, quantity: number?): boolean
    local data = DataService.GetData(player)
    if not data then return false end
    
    local qty = quantity or 1
    local inventory = data.Inventory
    
    -- Check if player has enough
    local total = 0
    for _, item in inventory do
        if item.id == itemId then
            total += item.quantity
        end
    end
    if total < qty then return false end
    
    -- Remove items
    for i = #inventory, 1, -1 do
        local item = inventory[i]
        if item.id == itemId then
            if item.quantity <= qty then
                qty -= item.quantity
                table.remove(inventory, i)
            else
                item.quantity -= qty
                qty = 0
            end
            if qty <= 0 then break end
        end
    end
    
    UpdateInventory:FireClient(player, inventory)
    return true
end

function InventoryService.HasItem(player: Player, itemId: string, quantity: number?): boolean
    local data = DataService.GetData(player)
    if not data then return false end
    
    local needed = quantity or 1
    local total = 0
    
    for _, item in data.Inventory do
        if item.id == itemId then
            total += item.quantity
            if total >= needed then return true end
        end
    end
    
    return false
end

function InventoryService.GetItemCount(player: Player, itemId: string): number
    local data = DataService.GetData(player)
    if not data then return 0 end
    
    local total = 0
    for _, item in data.Inventory do
        if item.id == itemId then
            total += item.quantity
        end
    end
    return total
end

return InventoryService
```

## Rebirth System

```lua
-- ServerScriptService/Services/RebirthService.lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local RebirthService = {}

local RebirthRemote = ReplicatedStorage.Remotes.Functions.Rebirth :: RemoteFunction

-- Rebirth costs scale exponentially
local function getRebirthCost(currentRebirths: number): number
    local baseCost = 1000000
    return math.floor(baseCost * (1.5 ^ currentRebirths))
end

function RebirthService.GetCost(player: Player): number
    local data = DataService.GetData(player)
    if not data then return math.huge end
    return getRebirthCost(data.Rebirths)
end

function RebirthService.CanRebirth(player: Player): boolean
    local data = DataService.GetData(player)
    if not data then return false end
    return data.Coins >= getRebirthCost(data.Rebirths)
end

function RebirthService.DoRebirth(player: Player): (boolean, string)
    local data = DataService.GetData(player)
    if not data then return false, "No data" end
    
    local cost = getRebirthCost(data.Rebirths)
    if data.Coins < cost then
        return false, "Not enough coins"
    end
    
    -- Reset progress
    data.Coins = 0
    data.Level = 1
    data.Experience = 0
    -- Keep: Gems, Rebirths, Achievements, Settings
    
    -- Increment rebirth count
    data.Rebirths += 1
    
    -- Could reset inventory too, depending on game design
    -- data.Inventory = {}
    
    return true, "Rebirth successful! New multiplier: " .. (1 + data.Rebirths * 0.1) .. "x"
end

-- Remote handler
RebirthRemote.OnServerInvoke = function(player: Player)
    return RebirthService.DoRebirth(player)
end

return RebirthService
```

## Daily Rewards

```lua
-- ServerScriptService/Services/DailyRewardService.lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local DailyRewardService = {}

local ClaimDaily = ReplicatedStorage.Remotes.Functions.ClaimDaily :: RemoteFunction

local REWARDS = {
    { Coins = 100 },
    { Coins = 200 },
    { Coins = 300 },
    { Coins = 400 },
    { Coins = 500 },
    { Coins = 750, Gems = 5 },
    { Coins = 1000, Gems = 10 }, -- Day 7 bonus
}

local DAY_SECONDS = 86400

function DailyRewardService.GetStatus(player: Player): (number, boolean, number)
    local data = DataService.GetData(player)
    if not data then return 1, false, 0 end
    
    local lastClaim = data.LastDailyClaim or 0
    local streak = data.DailyStreak or 0
    local now = os.time()
    
    local daysSinceClaim = math.floor((now - lastClaim) / DAY_SECONDS)
    
    if daysSinceClaim >= 2 then
        -- Streak broken
        streak = 0
    end
    
    local canClaim = daysSinceClaim >= 1
    local currentDay = (streak % #REWARDS) + 1
    
    return currentDay, canClaim, streak
end

function DailyRewardService.Claim(player: Player): (boolean, string, {[string]: number}?)
    local data = DataService.GetData(player)
    if not data then return false, "No data", nil end
    
    local currentDay, canClaim, streak = DailyRewardService.GetStatus(player)
    
    if not canClaim then
        return false, "Already claimed today", nil
    end
    
    local reward = REWARDS[currentDay]
    
    -- Grant rewards
    for currency, amount in reward do
        CurrencyService.Add(player, currency :: any, amount, false)
    end
    
    -- Update tracking
    data.LastDailyClaim = os.time()
    data.DailyStreak = streak + 1
    
    return true, "Day " .. currentDay .. " claimed!", reward
end

ClaimDaily.OnServerInvoke = function(player: Player)
    return DailyRewardService.Claim(player)
end

return DailyRewardService
```

## Leaderboard Service

```lua
-- ServerScriptService/Services/LeaderboardService.lua
--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local LeaderboardService = {}

local leaderboards: {[string]: OrderedDataStore} = {}

local function getStore(name: string): OrderedDataStore
    if not leaderboards[name] then
        leaderboards[name] = DataStoreService:GetOrderedDataStore("Leaderboard_" .. name)
    end
    return leaderboards[name]
end

function LeaderboardService.SetScore(leaderboardName: string, player: Player, score: number)
    local store = getStore(leaderboardName)
    
    task.spawn(function()
        local success, err = pcall(function()
            store:SetAsync(tostring(player.UserId), score)
        end)
        if not success then
            warn("Failed to set leaderboard score:", err)
        end
    end)
end

function LeaderboardService.GetTopScores(leaderboardName: string, count: number?): {{userId: number, score: number, rank: number}}
    local store = getStore(leaderboardName)
    local results = {}
    
    local success, pages = pcall(function()
        return store:GetSortedAsync(false, count or 100)
    end)
    
    if success then
        local data = pages:GetCurrentPage()
        for rank, entry in data do
            table.insert(results, {
                userId = tonumber(entry.key) or 0,
                score = entry.value,
                rank = rank,
            })
        end
    end
    
    return results
end

function LeaderboardService.GetPlayerRank(leaderboardName: string, player: Player): number?
    local store = getStore(leaderboardName)
    
    local success, rank = pcall(function()
        return store:GetRankAsync(tostring(player.UserId))
    end)
    
    return success and rank or nil
end

return LeaderboardService
```
