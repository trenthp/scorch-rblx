--!strict
--[[
    DataService.lua
    DataStore wrapper for save/load player data
    Handles persistence of stats and progression
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatsTypes = require(Shared:WaitForChild("StatsTypes"))
local BatteryConfig = require(Shared:WaitForChild("BatteryConfig"))

-- DataStore configuration
local DATA_STORE_NAME = "ScorchPlayerData_v1"
local DATA_KEY_PREFIX = "player_"
local SAVE_DEBOUNCE = 30 -- Minimum seconds between saves per player
local RETRY_ATTEMPTS = 3
local RETRY_DELAY = 2

local DataService = Knit.CreateService({
    Name = "DataService",

    Client = {
        DataLoaded = Knit.CreateSignal(),
    },

    _dataStore = nil :: DataStore?,
    _playerData = {} :: { [Player]: StatsTypes.PlayerData },
    _lastSaveTime = {} :: { [Player]: number },
    _dataLoadedSignal = nil :: any,
    _isStudio = false,
})

function DataService:KnitInit()
    self._dataLoadedSignal = Signal.new()
    self._isStudio = game:GetService("RunService"):IsStudio()

    -- Initialize DataStore (may fail in Studio without API access)
    local success, result = pcall(function()
        return DataStoreService:GetDataStore(DATA_STORE_NAME)
    end)

    if success then
        self._dataStore = result
        print("[DataService] DataStore initialized")
    else
        warn("[DataService] Failed to initialize DataStore:", result)
        if self._isStudio then
            print("[DataService] Running in Studio - using local data only")
        end
    end

    print("[DataService] Initialized")
end

function DataService:KnitStart()
    -- Load data for existing players
    for _, player in Players:GetPlayers() do
        task.spawn(function()
            self:LoadPlayerData(player)
        end)
    end

    -- Handle new players
    Players.PlayerAdded:Connect(function(player)
        self:LoadPlayerData(player)
    end)

    -- Handle players leaving - save their data
    Players.PlayerRemoving:Connect(function(player)
        self:SavePlayerData(player)
        self._playerData[player] = nil
        self._lastSaveTime[player] = nil
    end)

    -- Periodic auto-save every 5 minutes
    task.spawn(function()
        while true do
            task.wait(300) -- 5 minutes
            self:SaveAllPlayers()
        end
    end)

    -- Save all on server shutdown
    game:BindToClose(function()
        self:SaveAllPlayers()
    end)

    print("[DataService] Started")
end

--[[
    Load player data from DataStore
    @param player - The player to load data for
]]
function DataService:LoadPlayerData(player: Player)
    local data: StatsTypes.PlayerData? = nil

    if self._dataStore then
        local key = DATA_KEY_PREFIX .. player.UserId

        for attempt = 1, RETRY_ATTEMPTS do
            local success, result = pcall(function()
                return self._dataStore:GetAsync(key)
            end)

            if success then
                data = result
                break
            else
                warn(string.format("[DataService] Load attempt %d failed for %s: %s",
                    attempt, player.Name, tostring(result)))
                if attempt < RETRY_ATTEMPTS then
                    task.wait(RETRY_DELAY)
                end
            end
        end
    end

    -- Use default data if nothing loaded
    if not data then
        data = StatsTypes.createDefaultPlayerData()
        print(string.format("[DataService] Created new data for %s", player.Name))
    else
        -- Migrate data if needed
        data = self:_migrateData(data)
        print(string.format("[DataService] Loaded data for %s (Level %d, %d XP)",
            player.Name, data.progression.level, data.progression.xp))
    end

    self._playerData[player] = data
    self._lastSaveTime[player] = tick()

    -- Fire signals
    self._dataLoadedSignal:Fire(player, data)
    self.Client.DataLoaded:Fire(player, {
        stats = data.stats,
        progression = data.progression,
    })
end

--[[
    Save player data to DataStore
    @param player - The player to save data for
    @param force - If true, ignore debounce timer
]]
function DataService:SavePlayerData(player: Player, force: boolean?)
    local data = self._playerData[player]
    if not data then
        return
    end

    -- Check debounce
    local lastSave = self._lastSaveTime[player] or 0
    if not force and (tick() - lastSave) < SAVE_DEBOUNCE then
        return
    end

    if self._dataStore then
        local key = DATA_KEY_PREFIX .. player.UserId

        for attempt = 1, RETRY_ATTEMPTS do
            local success, err = pcall(function()
                self._dataStore:SetAsync(key, data)
            end)

            if success then
                self._lastSaveTime[player] = tick()
                print(string.format("[DataService] Saved data for %s", player.Name))
                return
            else
                warn(string.format("[DataService] Save attempt %d failed for %s: %s",
                    attempt, player.Name, tostring(err)))
                if attempt < RETRY_ATTEMPTS then
                    task.wait(RETRY_DELAY)
                end
            end
        end
    elseif self._isStudio then
        -- In Studio without DataStore, just update the timestamp
        self._lastSaveTime[player] = tick()
        print(string.format("[DataService] (Studio) Data cached for %s", player.Name))
    end
end

--[[
    Save all players' data
]]
function DataService:SaveAllPlayers()
    for player in self._playerData do
        task.spawn(function()
            self:SavePlayerData(player, true)
        end)
    end
end

--[[
    Get a player's data
    @param player - The player to get data for
    @return PlayerData or nil if not loaded
]]
function DataService:GetPlayerData(player: Player): StatsTypes.PlayerData?
    return self._playerData[player]
end

--[[
    Update a player's stats
    @param player - The player to update
    @param statUpdates - Table of stat changes (values are deltas, not absolutes)
]]
function DataService:UpdateStats(player: Player, statUpdates: { [string]: number })
    local data = self._playerData[player]
    if not data then
        return
    end

    for stat, delta in statUpdates do
        if data.stats[stat] ~= nil then
            data.stats[stat] += delta
        end
    end
end

--[[
    Update a player's progression
    @param player - The player to update
    @param progressionUpdates - Table of progression changes
]]
function DataService:UpdateProgression(player: Player, progressionUpdates: { [string]: any })
    local data = self._playerData[player]
    if not data then
        return
    end

    for key, value in progressionUpdates do
        if data.progression[key] ~= nil then
            data.progression[key] = value
        end
    end
end

--[[
    Add XP to a player (handled by ProgressionService, this is just the data update)
    @param player - The player to update
    @param xpAmount - Amount of XP to add
]]
function DataService:AddXP(player: Player, xpAmount: number)
    local data = self._playerData[player]
    if not data then
        return
    end

    data.progression.xp += xpAmount
end

--[[
    Set a player's level
    @param player - The player to update
    @param level - The new level
]]
function DataService:SetLevel(player: Player, level: number)
    local data = self._playerData[player]
    if not data then
        return
    end

    data.progression.level = level
end

--[[
    Unlock a title for a player
    @param player - The player to update
    @param title - The title to unlock
]]
function DataService:UnlockTitle(player: Player, title: string)
    local data = self._playerData[player]
    if not data then
        return
    end

    if not table.find(data.progression.unlockedTitles, title) then
        table.insert(data.progression.unlockedTitles, title)
    end
end

--[[
    Set a player's selected title
    @param player - The player to update
    @param title - The title to select
]]
function DataService:SetSelectedTitle(player: Player, title: string)
    local data = self._playerData[player]
    if not data then
        return
    end

    -- Only allow selecting unlocked titles
    if table.find(data.progression.unlockedTitles, title) then
        data.progression.selectedTitle = title
    end
end

--[[
    Migrate data from older versions
    @param data - The data to migrate
    @return Updated data
]]
function DataService:_migrateData(data: any): StatsTypes.PlayerData
    local version = data.version or 0

    if version < 1 then
        -- Migration from version 0 to 1
        -- Ensure all required fields exist
        data.version = 1
        data.stats = data.stats or StatsTypes.DEFAULT_STATS
        data.progression = data.progression or {
            xp = 0,
            level = 1,
            selectedTitle = "Rookie",
            unlockedTitles = { "Rookie" },
        }

        -- Add any missing stats fields
        for key, defaultValue in StatsTypes.DEFAULT_STATS do
            if data.stats[key] == nil then
                data.stats[key] = defaultValue
            end
        end
    end

    if version < 2 then
        -- Migration from version 1 to 2: Add battery system
        data.version = 2

        -- Add inventory if missing
        if not data.inventory then
            data.inventory = {
                equippedFlashlight = "Standard",
                equippedSkin = nil,
                unlockedFlashlights = { "Standard" },
                unlockedSkins = { "Default" },
            }
        end

        -- Add achievements if missing
        if not data.achievements then
            data.achievements = {}
        end

        -- Add battery currency
        if data.batteries == nil then
            data.batteries = 0
        end

        -- Add stored batteries array
        if not data.storedBatteries then
            data.storedBatteries = {}
        end

        print("[DataService] Migrated data to version 2 (battery system)")
    end

    return data :: StatsTypes.PlayerData
end

--[[
    Subscribe to data loaded event
]]
function DataService:OnDataLoaded(callback: (player: Player, data: StatsTypes.PlayerData) -> ())
    return self._dataLoadedSignal:Connect(callback)
end

--[[
    Add currency batteries to a player
    @param player - The player to add batteries to
    @param amount - Amount of batteries to add
]]
function DataService:AddBatteries(player: Player, amount: number)
    local data = self._playerData[player]
    if not data then
        return
    end

    data.batteries = (data.batteries or 0) + amount
    print(string.format("[DataService] Added %d batteries to %s (total: %d)",
        amount, player.Name, data.batteries))
end

--[[
    Spend currency batteries
    @param player - The player spending batteries
    @param amount - Amount to spend
    @return boolean - Whether the purchase was successful
]]
function DataService:SpendBatteries(player: Player, amount: number): boolean
    local data = self._playerData[player]
    if not data then
        return false
    end

    local currentBatteries = data.batteries or 0
    if currentBatteries < amount then
        return false
    end

    data.batteries = currentBatteries - amount
    print(string.format("[DataService] %s spent %d batteries (remaining: %d)",
        player.Name, amount, data.batteries))
    return true
end

--[[
    Get a player's battery count
    @param player - The player to check
    @return number - Battery count
]]
function DataService:GetBatteries(player: Player): number
    local data = self._playerData[player]
    if not data then
        return 0
    end
    return data.batteries or 0
end

--[[
    Add a stored battery to a player's inventory
    @param player - The player
    @param effectId - The effect type (e.g., "Speed", "Stealth")
    @param sizeId - The battery size (e.g., "C", "D", "9V", "Lantern")
    @return boolean - Whether the battery was added (false if full)
]]
function DataService:AddStoredBattery(player: Player, effectId: string, sizeId: string): boolean
    local data = self._playerData[player]
    if not data then
        return false
    end

    -- Initialize if needed
    if not data.storedBatteries then
        data.storedBatteries = {}
    end

    -- Check capacity
    if #data.storedBatteries >= BatteryConfig.MAX_STORED_BATTERIES then
        return false
    end

    table.insert(data.storedBatteries, {
        effectId = effectId,
        sizeId = sizeId,
    })

    print(string.format("[DataService] %s stored a %s %s battery (slot %d)",
        player.Name, sizeId, effectId, #data.storedBatteries))
    return true
end

--[[
    Remove a stored battery from a player's inventory
    @param player - The player
    @param slotIndex - The slot to remove from (1-4)
    @return StoredBattery? - The removed battery, or nil if invalid
]]
function DataService:RemoveStoredBattery(player: Player, slotIndex: number): StatsTypes.StoredBattery?
    local data = self._playerData[player]
    if not data or not data.storedBatteries then
        return nil
    end

    if slotIndex < 1 or slotIndex > #data.storedBatteries then
        return nil
    end

    local battery = table.remove(data.storedBatteries, slotIndex)
    print(string.format("[DataService] %s used stored battery from slot %d",
        player.Name, slotIndex))
    return battery
end

--[[
    Get a player's stored batteries
    @param player - The player
    @return { StoredBattery } - Array of stored batteries
]]
function DataService:GetStoredBatteries(player: Player): { StatsTypes.StoredBattery }
    local data = self._playerData[player]
    if not data or not data.storedBatteries then
        return {}
    end
    return data.storedBatteries
end

--[[
    Clear all stored batteries and convert to currency (end of round)
    @param player - The player
    @return number - Amount of currency gained
]]
function DataService:ConvertStoredBatteriesToCurrency(player: Player): number
    local data = self._playerData[player]
    if not data or not data.storedBatteries then
        return 0
    end

    local totalValue = BatteryConfig.calculateConversionValue(data.storedBatteries)
    if totalValue > 0 then
        data.batteries = (data.batteries or 0) + totalValue
        print(string.format("[DataService] %s converted stored batteries to %d currency",
            player.Name, totalValue))
    end

    data.storedBatteries = {}
    return totalValue
end

--[[
    Get a player's inventory
    @param player - The player
    @return PlayerInventory? - The player's inventory
]]
function DataService:GetInventory(player: Player): StatsTypes.PlayerInventory?
    local data = self._playerData[player]
    if not data then
        return nil
    end
    return data.inventory
end

--[[
    Update a player's inventory
    @param player - The player
    @param inventory - The new inventory data
]]
function DataService:SetInventory(player: Player, inventory: StatsTypes.PlayerInventory)
    local data = self._playerData[player]
    if not data then
        return
    end
    data.inventory = inventory
end

-- Client methods
function DataService.Client:GetMyData(player: Player): { stats: StatsTypes.PlayerStats, progression: StatsTypes.ProgressionData }?
    local data = self.Server:GetPlayerData(player)
    if data then
        return {
            stats = data.stats,
            progression = data.progression,
        }
    end
    return nil
end

function DataService.Client:SelectTitle(player: Player, title: string)
    self.Server:SetSelectedTitle(player, title)
end

function DataService.Client:GetBatteries(player: Player): number
    return self.Server:GetBatteries(player)
end

function DataService.Client:GetStoredBatteries(player: Player): { StatsTypes.StoredBattery }
    return self.Server:GetStoredBatteries(player)
end

function DataService.Client:GetInventory(player: Player): StatsTypes.PlayerInventory?
    return self.Server:GetInventory(player)
end

return DataService
