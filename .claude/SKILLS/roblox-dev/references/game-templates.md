# Game Templates & Patterns

## Obby (Obstacle Course)

### Checkpoint System
```lua
-- ServerScriptService/CheckpointService.server.lua
--!strict
local Players = game:GetService("Players")
local checkpoints = workspace:WaitForChild("Checkpoints")

local playerCheckpoints: {[number]: number} = {}

local function onPlayerAdded(player: Player)
    playerCheckpoints[player.UserId] = 1
    
    player.CharacterAdded:Connect(function(character)
        local checkpoint = checkpoints:FindFirstChild(tostring(playerCheckpoints[player.UserId]))
        if checkpoint then
            local hrp = character:WaitForChild("HumanoidRootPart") :: BasePart
            hrp.CFrame = checkpoint.CFrame + Vector3.new(0, 3, 0)
        end
    end)
end

local function setupCheckpoint(checkpoint: BasePart)
    checkpoint.Touched:Connect(function(hit)
        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        if player then
            local num = tonumber(checkpoint.Name)
            if num and num > playerCheckpoints[player.UserId] then
                playerCheckpoints[player.UserId] = num
            end
        end
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, cp in checkpoints:GetChildren() do
    setupCheckpoint(cp :: BasePart)
end
```

## Simulator (Clicker/Tycoon)

### Currency System
```lua
-- ReplicatedStorage/Modules/CurrencyManager.lua
--!strict
local CurrencyManager = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpdateCurrency = ReplicatedStorage.Remotes.UpdateCurrency :: RemoteEvent

export type CurrencyData = {
    coins: number,
    gems: number,
}

local playerCurrency: {[number]: CurrencyData} = {}

function CurrencyManager.Init(player: Player, data: CurrencyData?)
    playerCurrency[player.UserId] = data or { coins = 0, gems = 0 }
end

function CurrencyManager.Get(player: Player): CurrencyData?
    return playerCurrency[player.UserId]
end

function CurrencyManager.Add(player: Player, currency: string, amount: number): boolean
    local data = playerCurrency[player.UserId]
    if not data then return false end
    
    if currency == "coins" then
        data.coins += amount
    elseif currency == "gems" then
        data.gems += amount
    else
        return false
    end
    
    UpdateCurrency:FireClient(player, currency, data[currency])
    return true
end

function CurrencyManager.Remove(player: Player, currency: string, amount: number): boolean
    local data = playerCurrency[player.UserId]
    if not data then return false end
    
    local current = if currency == "coins" then data.coins else data.gems
    if current < amount then return false end
    
    return CurrencyManager.Add(player, currency, -amount)
end

return CurrencyManager
```

### Rebirth System
```lua
-- ServerScriptService/RebirthService.server.lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurrencyManager = require(ReplicatedStorage.Modules.CurrencyManager)

local REBIRTH_COST = 1000000
local REBIRTH_MULTIPLIER = 1.5

local playerRebirths: {[number]: number} = {}

local function rebirth(player: Player): boolean
    local data = CurrencyManager.Get(player)
    if not data or data.coins < REBIRTH_COST then return false end
    
    CurrencyManager.Remove(player, "coins", data.coins)
    playerRebirths[player.UserId] = (playerRebirths[player.UserId] or 0) + 1
    
    return true
end

local function getMultiplier(player: Player): number
    local rebirths = playerRebirths[player.UserId] or 0
    return REBIRTH_MULTIPLIER ^ rebirths
end
```

## Combat System

### Hitbox Detection
```lua
-- ServerScriptService/CombatService.server.lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttackRemote = ReplicatedStorage.Remotes.Attack :: RemoteEvent

local ATTACK_RANGE = 8
local ATTACK_DAMAGE = 25
local ATTACK_COOLDOWN = 0.8

local lastAttack: {[number]: number} = {}

local function getHitTargets(attacker: Model, range: number): {Humanoid}
    local root = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return {} end
    
    local hits: {Humanoid} = {}
    local params = OverlapParams.new()
    params.FilterDescendantsInstances = {attacker}
    
    local parts = workspace:GetPartBoundsInRadius(root.Position, range, params)
    for _, part in parts do
        local character = part:FindFirstAncestorOfClass("Model")
        if character then
            local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
            if humanoid and humanoid.Health > 0 and not table.find(hits, humanoid) then
                table.insert(hits, humanoid)
            end
        end
    end
    
    return hits
end

AttackRemote.OnServerEvent:Connect(function(player: Player)
    local now = tick()
    local userId = player.UserId
    
    if lastAttack[userId] and now - lastAttack[userId] < ATTACK_COOLDOWN then return end
    lastAttack[userId] = now
    
    local character = player.Character
    if not character then return end
    
    local targets = getHitTargets(character, ATTACK_RANGE)
    for _, humanoid in targets do
        humanoid:TakeDamage(ATTACK_DAMAGE)
    end
end)
```

### Knockback System
```lua
--!strict
local function applyKnockback(target: Model, direction: Vector3, force: number)
    local root = target:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end
    
    local attachment = Instance.new("Attachment")
    attachment.Parent = root
    
    local impulse = Instance.new("VectorForce")
    impulse.Attachment0 = attachment
    impulse.Force = direction.Unit * force
    impulse.RelativeTo = Enum.ActuatorRelativeTo.World
    impulse.Parent = root
    
    task.delay(0.1, function()
        impulse:Destroy()
        attachment:Destroy()
    end)
end
```

## UI Patterns

### Inventory UI
```lua
-- StarterGui/InventoryUI/InventoryController.client.lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = script.Parent :: ScreenGui
local frame = gui:WaitForChild("InventoryFrame") :: Frame
local template = frame:WaitForChild("ItemTemplate") :: Frame
local container = frame:WaitForChild("ItemContainer") :: ScrollingFrame

local GetInventory = ReplicatedStorage.Remotes.GetInventory :: RemoteFunction
local UpdateInventory = ReplicatedStorage.Remotes.UpdateInventory :: RemoteEvent

local function clearItems()
    for _, child in container:GetChildren() do
        if child:IsA("Frame") and child ~= template then
            child:Destroy()
        end
    end
end

local function renderInventory(inventory: {[string]: number})
    clearItems()
    
    for itemId, quantity in inventory do
        local item = template:Clone()
        item.Name = itemId
        item.Visible = true
        
        local nameLabel = item:FindFirstChild("ItemName") :: TextLabel?
        local quantityLabel = item:FindFirstChild("Quantity") :: TextLabel?
        
        if nameLabel then nameLabel.Text = itemId end
        if quantityLabel then quantityLabel.Text = tostring(quantity) end
        
        item.Parent = container
    end
end

-- Initial load
local inventory = GetInventory:InvokeServer()
renderInventory(inventory)

-- Listen for updates
UpdateInventory.OnClientEvent:Connect(renderInventory)
```

## Round-Based Game

### Round Manager
```lua
-- ServerScriptService/RoundManager.server.lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundStatus = ReplicatedStorage:WaitForChild("RoundStatus") :: StringValue
local GameEvents = ReplicatedStorage.Remotes.GameEvents :: RemoteEvent

local INTERMISSION_TIME = 15
local ROUND_TIME = 120
local MIN_PLAYERS = 2

local function getAlivePlayers(): {Player}
    local alive = {}
    for _, player in Players:GetPlayers() do
        local character = player.Character
        local humanoid = character and character:FindFirstChild("Humanoid") :: Humanoid?
        if humanoid and humanoid.Health > 0 then
            table.insert(alive, player)
        end
    end
    return alive
end

local function intermission()
    RoundStatus.Value = "Intermission"
    GameEvents:FireAllClients("Intermission", INTERMISSION_TIME)
    
    for i = INTERMISSION_TIME, 1, -1 do
        RoundStatus.Value = "Starting in " .. i
        task.wait(1)
        
        if #Players:GetPlayers() < MIN_PLAYERS then
            RoundStatus.Value = "Waiting for players..."
            repeat task.wait(1) until #Players:GetPlayers() >= MIN_PLAYERS
        end
    end
end

local function startRound()
    RoundStatus.Value = "Round Started!"
    GameEvents:FireAllClients("RoundStart")
    
    -- Teleport players to arena
    local spawns = workspace:WaitForChild("ArenaSpawns"):GetChildren()
    for i, player in Players:GetPlayers() do
        local character = player.Character
        if character then
            local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
            local spawn = spawns[(i - 1) % #spawns + 1] :: BasePart
            if hrp then
                hrp.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
            end
        end
    end
    
    -- Round timer
    for i = ROUND_TIME, 1, -1 do
        RoundStatus.Value = "Time: " .. i
        task.wait(1)
        
        local alive = getAlivePlayers()
        if #alive <= 1 then break end
    end
end

local function endRound()
    local alive = getAlivePlayers()
    local winner = alive[1]
    
    if winner then
        RoundStatus.Value = winner.Name .. " wins!"
        GameEvents:FireAllClients("RoundEnd", winner.Name)
    else
        RoundStatus.Value = "Draw!"
        GameEvents:FireAllClients("RoundEnd", nil)
    end
    
    task.wait(5)
end

-- Main game loop
while true do
    intermission()
    startRound()
    endRound()
end
```

## NPC/AI Patterns

### Basic Pathfinding NPC
```lua
-- ServerScriptService/NPCController.server.lua
--!strict
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

local npc = workspace:WaitForChild("NPC") :: Model
local humanoid = npc:WaitForChild("Humanoid") :: Humanoid
local root = npc:WaitForChild("HumanoidRootPart") :: BasePart

local CHASE_RANGE = 50
local ATTACK_RANGE = 5

local function findNearestPlayer(): Player?
    local nearest: Player? = nil
    local nearestDist = CHASE_RANGE
    
    for _, player in Players:GetPlayers() do
        local character = player.Character
        local playerRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if playerRoot then
            local dist = (playerRoot.Position - root.Position).Magnitude
            if dist < nearestDist then
                nearest = player
                nearestDist = dist
            end
        end
    end
    
    return nearest
end

local function moveTo(target: Vector3)
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
    })
    
    local success = pcall(function()
        path:ComputeAsync(root.Position, target)
    end)
    
    if success and path.Status == Enum.PathStatus.Success then
        for _, waypoint in path:GetWaypoints() do
            humanoid:MoveTo(waypoint.Position)
            if waypoint.Action == Enum.PathWaypointAction.Jump then
                humanoid.Jump = true
            end
            humanoid.MoveToFinished:Wait()
        end
    end
end

-- Main AI loop
while humanoid.Health > 0 do
    local target = findNearestPlayer()
    if target and target.Character then
        local targetRoot = target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if targetRoot then
            local dist = (targetRoot.Position - root.Position).Magnitude
            if dist <= ATTACK_RANGE then
                -- Attack logic here
            else
                moveTo(targetRoot.Position)
            end
        end
    end
    task.wait(0.5)
end
```

## Shop System

### Server-Side Shop Handler
```lua
-- ServerScriptService/ShopService.server.lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurrencyManager = require(ReplicatedStorage.Modules.CurrencyManager)

local PurchaseItem = ReplicatedStorage.Remotes.PurchaseItem :: RemoteFunction

type ShopItem = {
    id: string,
    price: number,
    currency: string,
}

local SHOP_ITEMS: {ShopItem} = {
    { id = "sword", price = 100, currency = "coins" },
    { id = "shield", price = 150, currency = "coins" },
    { id = "potion", price = 10, currency = "gems" },
}

local function getItem(itemId: string): ShopItem?
    for _, item in SHOP_ITEMS do
        if item.id == itemId then return item end
    end
    return nil
end

PurchaseItem.OnServerInvoke = function(player: Player, itemId: string): (boolean, string)
    local item = getItem(itemId)
    if not item then return false, "Item not found" end
    
    local success = CurrencyManager.Remove(player, item.currency, item.price)
    if not success then return false, "Insufficient funds" end
    
    -- Grant item to player (implement your inventory system)
    -- InventoryManager.AddItem(player, itemId)
    
    return true, "Purchase successful"
end
```
