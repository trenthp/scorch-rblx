--!strict
--[[
    BatteryService.lua
    Server-side battery spawning, pickup, and power-up effect management

    Features:
    - Spawn batteries on freeze/rescue events
    - Handle instant vs storable battery pickups
    - Apply and track active power-up effects
    - Convert unused batteries to currency at round end
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BatteryConfig = require(Shared:WaitForChild("BatteryConfig"))
local Enums = require(Shared:WaitForChild("Enums"))

type ActiveEffect = {
    effectId: string,
    endTime: number,
    connection: thread?,
}

type SpawnedBattery = {
    id: string,
    part: BasePart,
    effectId: string,
    sizeId: string,
    spawnTime: number,
    touchConnection: RBXScriptConnection?,
}

local BatteryService = Knit.CreateService({
    Name = "BatteryService",

    Client = {
        BatterySpawned = Knit.CreateSignal(),       -- (batteryId, position, effectId, sizeId)
        BatteryCollected = Knit.CreateSignal(),     -- (batteryId, player)
        BatteryDespawned = Knit.CreateSignal(),     -- (batteryId)
        PowerUpActivated = Knit.CreateSignal(),     -- (player, effectId, duration)
        PowerUpExpired = Knit.CreateSignal(),       -- (player, effectId)
        StoredBatteryUpdated = Knit.CreateSignal(), -- (player, storedBatteries)
        CurrencyUpdated = Knit.CreateSignal(),      -- (player, newAmount)
        ShieldConsumed = Knit.CreateSignal(),       -- (player, wasDefensive)
    },

    _spawnedBatteries = {} :: { [string]: SpawnedBattery },
    _activeEffects = {} :: { [Player]: { [string]: ActiveEffect } },
    _batteryIdCounter = 0,
    _batteriesFolder = nil :: Folder?,
    _cleanupConnection = nil :: thread?,
    _randomSpawnConnection = nil :: thread?,

    -- Internal signals for server-side subscriptions
    _shieldConsumedSignal = nil :: any,
})

function BatteryService:KnitInit()
    self._spawnedBatteries = {}
    self._activeEffects = {}
    self._batteryIdCounter = 0
    self._shieldConsumedSignal = Signal.new()

    -- Create folder for battery objects
    self._batteriesFolder = Instance.new("Folder")
    self._batteriesFolder.Name = "Batteries"
    self._batteriesFolder.Parent = Workspace

    print("[BatteryService] Initialized")
end

function BatteryService:KnitStart()
    -- Hook into freeze/unfreeze events for battery spawning
    local PlayerStateService = Knit.GetService("PlayerStateService")

    PlayerStateService:OnPlayerFrozen(function(frozenPlayer, seeker)
        -- Spawn battery for seeker when they freeze someone
        local character = frozenPlayer.Character
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
            if rootPart then
                self:SpawnBattery(rootPart.Position)
            end
        end
    end)

    PlayerStateService:OnPlayerUnfrozen(function(rescuedPlayer, rescuer)
        -- Spawn battery for rescuer when they save someone
        local character = rescuer.Character
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
            if rootPart then
                self:SpawnBattery(rootPart.Position)
            end
        end
    end)

    -- Hook into round end for currency conversion
    local RoundService = Knit.GetService("RoundService")
    RoundService:OnRoundEnded(function()
        self:_onRoundEnded()
    end)

    -- Subscribe to game state changes
    local GameStateService = Knit.GetService("GameStateService")
    GameStateService:OnStateChanged(function(newState)
        if newState == Enums.GameState.GAMEPLAY then
            self:_startCleanupLoop()
        else
            self:_stopRandomSpawnLoop()
            self:_stopCleanupLoop()
            self:_clearAllBatteries()
            self:_clearAllEffects()
        end
    end)

    -- Subscribe to gameplay phase changes for random drops
    local RoundService = Knit.GetService("RoundService")
    RoundService:OnPhaseChanged(function(phase)
        if phase == Enums.GameplayPhase.ACTIVE then
            self:_startRandomSpawnLoop()
        else
            self:_stopRandomSpawnLoop()
        end
    end)

    -- Clean up on player leave
    Players.PlayerRemoving:Connect(function(player)
        self._activeEffects[player] = nil
    end)

    print("[BatteryService] Started")
end

--[[
    Spawn a battery at a position with random effect and size
    @param position - World position to spawn at
    @param effectId - Optional specific effect (random if nil)
    @param sizeId - Optional specific size (random if nil)
]]
function BatteryService:SpawnBattery(position: Vector3, effectId: string?, sizeId: string?)
    local finalEffectId = effectId or BatteryConfig.rollEffect()
    local finalSizeId = sizeId or BatteryConfig.rollBatterySize()

    local effect = BatteryConfig.getEffect(finalEffectId)
    local size = BatteryConfig.getBatterySize(finalSizeId)

    if not effect or not size then
        warn("[BatteryService] Invalid effect or size:", finalEffectId, finalSizeId)
        return
    end

    -- Generate unique ID
    self._batteryIdCounter += 1
    local batteryId = "battery_" .. tostring(self._batteryIdCounter)

    -- Create the battery part
    local part = Instance.new("Part")
    part.Name = batteryId
    part.Size = BatteryConfig.BATTERY_SIZE
    part.Shape = Enum.PartType.Cylinder
    part.Color = effect.color
    part.Material = Enum.Material.Neon
    part.CanCollide = false
    part.Anchored = true
    part.Position = position + Vector3.new(0, BatteryConfig.SPAWN_HEIGHT_OFFSET, 0)
    part.CFrame = part.CFrame * CFrame.Angles(0, 0, math.rad(90))  -- Rotate to stand upright
    part.Parent = self._batteriesFolder

    -- Add glow effect
    local pointLight = Instance.new("PointLight")
    pointLight.Color = effect.color
    pointLight.Brightness = BatteryConfig.BATTERY_GLOW_INTENSITY
    pointLight.Range = 8
    pointLight.Parent = part

    -- Add hover/bob animation
    local startY = part.Position.Y
    task.spawn(function()
        local elapsed = 0
        while part.Parent do
            elapsed += task.wait()
            local newY = startY + math.sin(elapsed * BatteryConfig.BATTERY_BOB_SPEED * math.pi * 2) * BatteryConfig.BATTERY_BOB_AMPLITUDE
            part.CFrame = CFrame.new(part.Position.X, newY, part.Position.Z) * CFrame.Angles(0, elapsed * BatteryConfig.BATTERY_ROTATION_SPEED * math.pi * 2, math.rad(90))
        end
    end)

    -- Create touch connection for pickup
    local touchConnection = part.Touched:Connect(function(hit)
        self:_onBatteryTouched(batteryId, hit)
    end)

    -- Store battery data
    local batteryData: SpawnedBattery = {
        id = batteryId,
        part = part,
        effectId = finalEffectId,
        sizeId = finalSizeId,
        spawnTime = tick(),
        touchConnection = touchConnection,
    }
    self._spawnedBatteries[batteryId] = batteryData

    -- Notify clients
    self.Client.BatterySpawned:FireAll(batteryId, part.Position, finalEffectId, finalSizeId)

    print(string.format("[BatteryService] Spawned %s %s battery at %s",
        finalSizeId, finalEffectId, tostring(position)))
end

--[[
    Handle battery pickup
]]
function BatteryService:_onBatteryTouched(batteryId: string, hit: BasePart)
    local battery = self._spawnedBatteries[batteryId]
    if not battery then
        return
    end

    -- Get the player who touched
    local character = hit.Parent
    if not character then
        return
    end

    local player = Players:GetPlayerFromCharacter(character)
    if not player then
        return
    end

    -- Check if player is in the game
    local TeamService = Knit.GetService("TeamService")
    if not TeamService:IsInGame(player) then
        return
    end

    -- Process the pickup
    self:_collectBattery(player, batteryId)
end

--[[
    Process battery collection
]]
function BatteryService:_collectBattery(player: Player, batteryId: string)
    local battery = self._spawnedBatteries[batteryId]
    if not battery then
        return
    end

    local sizeConfig = BatteryConfig.getBatterySize(battery.sizeId)
    if not sizeConfig then
        return
    end

    -- Determine if instant or storable
    if sizeConfig.isInstant then
        -- Apply effect immediately
        local duration = BatteryConfig.getEffectDuration(battery.sizeId)
        self:ApplyEffect(player, battery.effectId, duration)
    else
        -- Try to store the battery
        local DataService = Knit.GetService("DataService")
        local success = DataService:AddStoredBattery(player, battery.effectId, battery.sizeId)

        if success then
            -- Notify client of updated storage
            local storedBatteries = DataService:GetStoredBatteries(player)
            self.Client.StoredBatteryUpdated:Fire(player, storedBatteries)
        else
            -- Storage full - could give currency instead or reject
            print(string.format("[BatteryService] %s's battery storage is full", player.Name))
            return  -- Don't collect if can't store
        end
    end

    -- Remove the battery from the world
    self:_removeBattery(batteryId)

    -- Notify clients
    self.Client.BatteryCollected:FireAll(batteryId, player)

    print(string.format("[BatteryService] %s collected %s %s battery",
        player.Name, battery.sizeId, battery.effectId))
end

--[[
    Remove a battery from the world
]]
function BatteryService:_removeBattery(batteryId: string)
    local battery = self._spawnedBatteries[batteryId]
    if not battery then
        return
    end

    if battery.touchConnection then
        battery.touchConnection:Disconnect()
    end

    if battery.part then
        battery.part:Destroy()
    end

    self._spawnedBatteries[batteryId] = nil
end

--[[
    Activate a stored battery
    @param player - The player activating
    @param slotIndex - The slot to activate (1-4)
    @return boolean - Whether activation was successful
]]
function BatteryService:ActivateStoredBattery(player: Player, slotIndex: number): boolean
    local DataService = Knit.GetService("DataService")
    local battery = DataService:RemoveStoredBattery(player, slotIndex)

    if not battery then
        return false
    end

    -- Apply the effect
    local duration = BatteryConfig.getEffectDuration(battery.sizeId)
    self:ApplyEffect(player, battery.effectId, duration)

    -- Notify client of updated storage
    local storedBatteries = DataService:GetStoredBatteries(player)
    self.Client.StoredBatteryUpdated:Fire(player, storedBatteries)

    return true
end

--[[
    Apply a power-up effect to a player
    @param player - The player to affect
    @param effectId - The effect type
    @param duration - Duration in seconds
]]
function BatteryService:ApplyEffect(player: Player, effectId: string, duration: number)
    local effect = BatteryConfig.getEffect(effectId)
    if not effect then
        return
    end

    -- Initialize player's effects table
    if not self._activeEffects[player] then
        self._activeEffects[player] = {}
    end

    -- Cancel existing effect of same type
    local existing = self._activeEffects[player][effectId]
    if existing and existing.connection then
        task.cancel(existing.connection)
    end

    -- Apply the effect
    self:_applyEffectToPlayer(player, effectId)

    -- Set up expiration
    local endTime = tick() + duration
    local expirationThread = task.delay(duration, function()
        self:_removeEffectFromPlayer(player, effectId)
    end)

    self._activeEffects[player][effectId] = {
        effectId = effectId,
        endTime = endTime,
        connection = expirationThread,
    }

    -- Notify clients
    self.Client.PowerUpActivated:FireAll(player, effectId, duration)

    print(string.format("[BatteryService] Applied %s effect to %s for %d seconds",
        effectId, player.Name, duration))
end

--[[
    Apply effect mechanics to a player
]]
function BatteryService:_applyEffectToPlayer(player: Player, effectId: string)
    local effect = BatteryConfig.getEffect(effectId)
    if not effect then
        return
    end

    local TeamService = Knit.GetService("TeamService")
    local isRunner = TeamService:IsRunner(player)
    local modifier = isRunner and effect.runnerModifier or effect.seekerModifier

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if effectId == "Speed" then
        -- Increase walk speed
        if humanoid then
            humanoid.WalkSpeed = humanoid.WalkSpeed * modifier
        end
    elseif effectId == "Stealth" then
        -- Stealth is handled client-side for footsteps and nametag
        -- Server just tracks the effect state
    elseif effectId == "Vision" then
        -- Vision highlighting is handled client-side
    elseif effectId == "Rescue" then
        -- Rescue speed is checked in FreezeService
    elseif effectId == "Shield" then
        -- Shield is checked in PlayerStateService/BatteryService
    end
end

--[[
    Remove effect from a player (on expiration or manual removal)
]]
function BatteryService:_removeEffectFromPlayer(player: Player, effectId: string)
    if not self._activeEffects[player] then
        return
    end

    local activeEffect = self._activeEffects[player][effectId]
    if not activeEffect then
        return
    end

    local effect = BatteryConfig.getEffect(effectId)
    if not effect then
        return
    end

    local TeamService = Knit.GetService("TeamService")
    local isRunner = TeamService:IsRunner(player)
    local modifier = isRunner and effect.runnerModifier or effect.seekerModifier

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if effectId == "Speed" then
        -- Restore walk speed
        if humanoid then
            humanoid.WalkSpeed = humanoid.WalkSpeed / modifier
        end
    end

    -- Clear the effect
    if activeEffect.connection then
        task.cancel(activeEffect.connection)
    end
    self._activeEffects[player][effectId] = nil

    -- Notify clients
    self.Client.PowerUpExpired:FireAll(player, effectId)

    print(string.format("[BatteryService] %s effect expired for %s", effectId, player.Name))
end

--[[
    Check if a player has an active effect
    @param player - The player to check
    @param effectId - The effect to check for
    @return boolean - Whether the effect is active
]]
function BatteryService:HasEffect(player: Player, effectId: string): boolean
    if not self._activeEffects[player] then
        return false
    end
    return self._activeEffects[player][effectId] ~= nil
end

--[[
    Get the remaining duration of an effect
    @param player - The player
    @param effectId - The effect
    @return number - Remaining seconds (0 if not active)
]]
function BatteryService:GetEffectRemainingTime(player: Player, effectId: string): number
    if not self._activeEffects[player] then
        return 0
    end

    local activeEffect = self._activeEffects[player][effectId]
    if not activeEffect then
        return 0
    end

    return math.max(0, activeEffect.endTime - tick())
end

--[[
    Get the effect modifier for a player
    @param player - The player
    @param effectId - The effect type
    @return number - The modifier (1.0 if not active)
]]
function BatteryService:GetEffectMultiplier(player: Player, effectId: string): number
    if not self:HasEffect(player, effectId) then
        return 1.0
    end

    local effect = BatteryConfig.getEffect(effectId)
    if not effect then
        return 1.0
    end

    local TeamService = Knit.GetService("TeamService")
    local isRunner = TeamService:IsRunner(player)
    return isRunner and effect.runnerModifier or effect.seekerModifier
end

--[[
    Consume a player's shield effect (called when shield blocks something)
    @param player - The player
    @param wasDefensive - True if blocked a freeze, false if used for instant freeze
    @return boolean - Whether shield was consumed
]]
function BatteryService:ConsumeShield(player: Player, wasDefensive: boolean): boolean
    if not self:HasEffect(player, "Shield") then
        return false
    end

    -- Remove the shield effect immediately
    self:_removeEffectFromPlayer(player, "Shield")

    -- Notify
    self.Client.ShieldConsumed:Fire(player, wasDefensive)
    self._shieldConsumedSignal:Fire(player, wasDefensive)

    print(string.format("[BatteryService] %s's shield was consumed (%s)",
        player.Name, wasDefensive and "blocked freeze" or "instant freeze"))
    return true
end

--[[
    Subscribe to shield consumed events (server-side)
]]
function BatteryService:OnShieldConsumed(callback: (player: Player, wasDefensive: boolean) -> ())
    return self._shieldConsumedSignal:Connect(callback)
end

--[[
    Called when round ends - convert stored batteries to currency
]]
function BatteryService:_onRoundEnded()
    local DataService = Knit.GetService("DataService")
    local TeamService = Knit.GetService("TeamService")

    -- Convert batteries for all players who were in the game
    local allPlayers = {}
    for _, p in TeamService:GetSeekers() do
        table.insert(allPlayers, p)
    end
    for _, p in TeamService:GetRunners() do
        table.insert(allPlayers, p)
    end

    for _, player in allPlayers do
        local amountGained = DataService:ConvertStoredBatteriesToCurrency(player)
        if amountGained > 0 then
            local newTotal = DataService:GetBatteries(player)
            self.Client.CurrencyUpdated:Fire(player, newTotal)
            self.Client.StoredBatteryUpdated:Fire(player, {})
        end
    end

    print("[BatteryService] Converted all stored batteries to currency")
end

--[[
    Start the random battery spawn loop during active gameplay
]]
function BatteryService:_startRandomSpawnLoop()
    if self._randomSpawnConnection then
        return
    end

    print("[BatteryService] Starting random battery drops")

    self._randomSpawnConnection = task.spawn(function()
        -- Initial delay before first drop
        task.wait(BatteryConfig.RANDOM_DROP_INTERVAL * 0.5)

        while true do
            -- Check world battery cap
            local worldCount = 0
            for _ in self._spawnedBatteries do
                worldCount += 1
            end

            if worldCount < BatteryConfig.MAX_WORLD_BATTERIES then
                -- Roll how many to spawn
                local minCount = BatteryConfig.RANDOM_DROP_COUNT[1]
                local maxCount = BatteryConfig.RANDOM_DROP_COUNT[2]
                local count = math.random(minCount, maxCount)

                local bounds = BatteryConfig.RANDOM_DROP_BOUNDS
                for _ = 1, count do
                    local x = math.random() * (bounds.max.X - bounds.min.X) + bounds.min.X
                    local z = math.random() * (bounds.max.Z - bounds.min.Z) + bounds.min.Z

                    -- Raycast down to find ground level
                    local rayOrigin = Vector3.new(x, 200, z)
                    local rayDirection = Vector3.new(0, -400, 0)
                    local rayParams = RaycastParams.new()
                    rayParams.FilterType = Enum.RaycastFilterType.Exclude
                    rayParams.FilterDescendantsInstances = { self._batteriesFolder }

                    local result = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
                    local spawnY = result and result.Position.Y or 0

                    self:SpawnBattery(Vector3.new(x, spawnY, z))
                end
            end

            task.wait(BatteryConfig.RANDOM_DROP_INTERVAL)
        end
    end)
end

--[[
    Stop the random battery spawn loop
]]
function BatteryService:_stopRandomSpawnLoop()
    if self._randomSpawnConnection then
        task.cancel(self._randomSpawnConnection)
        self._randomSpawnConnection = nil
    end
end

--[[
    Start the cleanup loop for despawning old batteries
]]
function BatteryService:_startCleanupLoop()
    if self._cleanupConnection then
        return
    end

    self._cleanupConnection = task.spawn(function()
        while true do
            task.wait(5)  -- Check every 5 seconds

            local now = tick()
            local toRemove = {}

            for batteryId, battery in self._spawnedBatteries do
                if now - battery.spawnTime >= BatteryConfig.BATTERY_LIFETIME then
                    table.insert(toRemove, batteryId)
                end
            end

            for _, batteryId in toRemove do
                self:_removeBattery(batteryId)
                self.Client.BatteryDespawned:FireAll(batteryId)
            end
        end
    end)
end

--[[
    Stop the cleanup loop
]]
function BatteryService:_stopCleanupLoop()
    if self._cleanupConnection then
        task.cancel(self._cleanupConnection)
        self._cleanupConnection = nil
    end
end

--[[
    Clear all spawned batteries
]]
function BatteryService:_clearAllBatteries()
    for batteryId in self._spawnedBatteries do
        self:_removeBattery(batteryId)
    end
    self._spawnedBatteries = {}
end

--[[
    Clear all active effects
]]
function BatteryService:_clearAllEffects()
    for player, effects in self._activeEffects do
        for effectId in effects do
            self:_removeEffectFromPlayer(player, effectId)
        end
    end
    self._activeEffects = {}
end

-- Client methods
function BatteryService.Client:ActivateStoredBattery(player: Player, slotIndex: number): boolean
    return self.Server:ActivateStoredBattery(player, slotIndex)
end

function BatteryService.Client:HasEffect(player: Player, effectId: string): boolean
    return self.Server:HasEffect(player, effectId)
end

function BatteryService.Client:GetEffectRemainingTime(player: Player, effectId: string): number
    return self.Server:GetEffectRemainingTime(player, effectId)
end

function BatteryService.Client:GetEffectMultiplier(player: Player, effectId: string): number
    return self.Server:GetEffectMultiplier(player, effectId)
end

return BatteryService
