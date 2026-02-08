---
name: roblox-dev
description: Roblox game development with Luau scripting. Use when creating Roblox games, writing Luau scripts, setting up client-server architecture, implementing data stores, creating game mechanics (tools, combat, UI, inventory), or working with Rojo external tooling. Triggers on keywords like Roblox, Luau, RemoteEvent, DataStore, ServerScriptService, ReplicatedStorage, or any Roblox Studio development task.
---

# Roblox Game Development

## Quick Reference

### Script Types
- **Script**: Server-side, place in `ServerScriptService`
- **LocalScript**: Client-side, place in `StarterPlayerScripts`, `StarterCharacterScripts`, or `StarterGui`
- **ModuleScript**: Shared code, returns a table. Place in `ReplicatedStorage` (shared) or `ServerStorage` (server-only)

### Key Services
```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")
```

## Project Structure

```
game
├── Workspace/              -- 3D world, parts, models
├── ReplicatedStorage/      -- Shared between client & server
│   ├── Modules/            -- Shared ModuleScripts
│   ├── Remotes/            -- RemoteEvents & RemoteFunctions
│   └── Assets/             -- Shared models, effects
├── ServerStorage/          -- Server-only assets
│   └── Modules/            -- Server-only modules
├── ServerScriptService/    -- Server Scripts
│   ├── Services/           -- Game logic modules
│   └── main.server.lua     -- Entry point (if using Rojo)
├── StarterPlayer/
│   ├── StarterPlayerScripts/  -- Client scripts (run once per player)
│   └── StarterCharacterScripts/ -- Scripts attached to character
├── StarterGui/             -- UI elements, LocalScripts for UI
└── ReplicatedFirst/        -- Loads before other content (loading screens)
```

## Client-Server Communication

### RemoteEvent (One-way, no response needed)
```lua
-- ReplicatedStorage/Remotes/DamageEvent.lua (create RemoteEvent instance)

-- Server (Script)
local DamageEvent = ReplicatedStorage.Remotes.DamageEvent
DamageEvent.OnServerEvent:Connect(function(player: Player, targetId: number, damage: number)
    -- ALWAYS validate on server - never trust client data
    if typeof(targetId) ~= "number" or typeof(damage) ~= "number" then return end
    if damage > MAX_DAMAGE then return end  -- Sanity check
    -- Process damage...
end)

-- Client (LocalScript)
local DamageEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DamageEvent")
DamageEvent:FireServer(targetId, damage)
```

### RemoteFunction (Two-way, returns response)
```lua
-- Server
local GetInventory = ReplicatedStorage.Remotes.GetInventory
GetInventory.OnServerInvoke = function(player: Player): {[string]: number}
    return PlayerData[player.UserId].Inventory
end

-- Client  
local inventory = GetInventory:InvokeServer()
```

### Key Rules
1. **Never trust client data** - Always validate on server
2. Use `WaitForChild()` on client to ensure objects exist
3. RemoteEvents for actions, RemoteFunctions only when response needed
4. Keep remote calls minimal - batch data when possible

## Data Storage

### Basic DataStoreService
```lua
--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v1")

local DEFAULT_DATA = {
    Coins = 0,
    Inventory = {},
    Level = 1,
}

local PlayerData: {[number]: typeof(DEFAULT_DATA)} = {}

local function loadData(player: Player)
    local userId = player.UserId
    local success, data = pcall(function()
        return PlayerDataStore:GetAsync(tostring(userId))
    end)
    
    if success and data then
        PlayerData[userId] = data
    else
        PlayerData[userId] = table.clone(DEFAULT_DATA)
    end
end

local function saveData(player: Player)
    local userId = player.UserId
    local data = PlayerData[userId]
    if not data then return end
    
    local success, err = pcall(function()
        PlayerDataStore:SetAsync(tostring(userId), data)
    end)
    
    if not success then
        warn("Failed to save data for", player.Name, err)
    end
end

Players.PlayerAdded:Connect(loadData)
Players.PlayerRemoving:Connect(saveData)
game:BindToClose(function()
    for _, player in Players:GetPlayers() do
        saveData(player)
    end
end)
```

### For Production: Use ProfileService
For production games, use [ProfileService](https://madstudioroblox.github.io/ProfileService/) which handles:
- Session locking (prevents duplication exploits)
- Auto-saving
- Data migration
- Throttle management

## Common Patterns

### ModuleScript Template
```lua
--!strict
local MyModule = {}

-- Types
export type ItemData = {
    id: string,
    name: string,
    quantity: number,
}

-- Private
local cache: {[string]: ItemData} = {}

-- Public API
function MyModule.GetItem(id: string): ItemData?
    return cache[id]
end

function MyModule.AddItem(data: ItemData)
    cache[data.id] = data
end

return MyModule
```

### Character Controller Pattern
```lua
-- StarterCharacterScripts/Movement.client.lua
--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

local isSprinting = false

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.LeftShift then
        isSprinting = true
        humanoid.WalkSpeed = 24
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift then
        isSprinting = false
        humanoid.WalkSpeed = 16
    end
end)
```

### Tool/Weapon Pattern
```lua
-- ServerScriptService/ToolHandler.server.lua
--!strict
local tool = script.Parent :: Tool
local damage = 10
local cooldown = 0.5
local lastUsed: {[Player]: number} = {}

tool.Activated:Connect(function()
    local player = Players:GetPlayerFromCharacter(tool.Parent)
    if not player then return end
    
    local now = tick()
    if lastUsed[player] and now - lastUsed[player] < cooldown then return end
    lastUsed[player] = now
    
    -- Raycast for hit detection
    local character = tool.Parent :: Model
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
    local direction = root.CFrame.LookVector * 10
    
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {character}
    
    local result = workspace:Raycast(root.Position, direction, params)
    if result and result.Instance then
        local targetChar = result.Instance:FindFirstAncestorOfClass("Model")
        local targetHumanoid = targetChar and targetChar:FindFirstChild("Humanoid") :: Humanoid?
        if targetHumanoid then
            targetHumanoid:TakeDamage(damage)
        end
    end
end)
```

## Luau Best Practices

### Type Annotations
```lua
--!strict  -- Enable strict type checking

-- Function types
local function greet(name: string): string
    return "Hello, " .. name
end

-- Table types
type PlayerStats = {
    health: number,
    mana: number,
    level: number,
}

-- Optional types
local function findPlayer(name: string): Player?
    return Players:FindFirstChild(name) :: Player?
end

-- Union types
local function process(value: string | number): string
    return tostring(value)
end
```

### Code Style
- Use `local` for all variables
- PascalCase for classes/modules, camelCase for functions/variables
- Avoid `wait()`, use `task.wait()` instead
- Avoid `spawn()`, use `task.spawn()` instead
- Always handle `pcall` errors for DataStore/HTTP operations
- Use `::` for type casting: `local part = workspace.Part :: BasePart`

## External Development (Rojo)

For version control and external editors, use Rojo:

### default.project.json
```json
{
  "name": "MyGame",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "Shared": { "$path": "src/shared" },
      "Remotes": { "$className": "Folder" }
    },
    "ServerScriptService": {
      "$className": "ServerScriptService",
      "Server": { "$path": "src/server" }
    },
    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts",
        "Client": { "$path": "src/client" }
      }
    }
  }
}
```

### File naming
- `script.server.lua` → Script
- `script.client.lua` → LocalScript  
- `init.lua` or `module.lua` → ModuleScript

### Recommended tools
- **Rojo** - Sync files to Studio
- **luau-lsp** - Language server for VS Code
- **Selene** - Linter
- **StyLua** - Formatter

## Anti-Cheat Considerations

1. **Never trust client values** - Validate everything server-side
2. **Rate limit remote calls** - Track timestamps per player
3. **Sanity check ranges** - Damage, teleport distances, currency changes
4. **Server authoritative** - Server decides outcomes, client only requests
5. **Validate ownership** - Check player owns items before transactions

## Performance Tips

1. Use `workspace:BulkMoveTo()` for moving many parts
2. Cache `GetService()` calls at script top
3. Avoid `Instance:FindFirstChild()` in loops - cache references
4. Use `task.defer()` to spread heavy work across frames
5. Profile with Script Profiler in Studio
6. Stream large maps with `StreamingEnabled`
