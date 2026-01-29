--!strict
--[[
    FlashlightModel.lua
    Handles the physical flashlight Tool and light control

    Uses Roblox's built-in Tool system:
    - Equipped = light ON
    - Unequipped = light OFF
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FlashlightTypes = require(Shared:WaitForChild("FlashlightTypes"))

type FlashlightConfig = FlashlightTypes.FlashlightConfig

local FlashlightModel = {}
FlashlightModel.__index = FlashlightModel

export type FlashlightModelInstance = {
    _config: FlashlightConfig,
    _player: Player?,
    _tool: Tool?,
    _spotlight: SpotLight?,
    _equippedConnection: RBXScriptConnection?,
    _unequippedConnection: RBXScriptConnection?,
}

--[[
    Create a new flashlight model instance
]]
function FlashlightModel.new(config: FlashlightConfig?): FlashlightModelInstance
    local self = setmetatable({}, FlashlightModel) :: any

    self._config = config or FlashlightTypes.getDefault()
    self._player = nil
    self._tool = nil
    self._spotlight = nil
    self._equippedConnection = nil
    self._unequippedConnection = nil

    return self
end

--[[
    Clone flashlight Tool from ReplicatedStorage
]]
function FlashlightModel:_cloneToolFromStorage(configName: string): Tool?
    local modelsFolder = ReplicatedStorage:FindFirstChild("FlashlightModels")
    if not modelsFolder then
        warn("[FlashlightModel] FlashlightModels folder not found")
        return nil
    end

    local template = modelsFolder:FindFirstChild(configName)
    if not template then
        warn(string.format("[FlashlightModel] Template '%s' not found", configName))
        return nil
    end

    if not template:IsA("Tool") then
        warn(string.format("[FlashlightModel] Template '%s' is not a Tool (is %s)", configName, template.ClassName))
        return nil
    end

    print(string.format("[FlashlightModel] Cloning Tool: %s", template.Name))

    local tool = template:Clone()
    tool.Name = "Flashlight"

    -- Configure parts (don't collide, massless)
    for _, desc in tool:GetDescendants() do
        if desc:IsA("BasePart") then
            desc.CanCollide = false
            desc.Massless = true
        end
    end

    return tool
end

--[[
    Find the spotlight in the tool
]]
function FlashlightModel:_findSpotlight(): SpotLight?
    if not self._tool then
        return nil
    end

    for _, descendant in self._tool:GetDescendants() do
        if descendant:IsA("SpotLight") then
            return descendant
        end
    end

    return nil
end

--[[
    Turn on the spotlight
]]
function FlashlightModel:_turnOn()
    if self._spotlight then
        self._spotlight.Enabled = true
        print("[FlashlightModel] Light ON")
    end
end

--[[
    Turn off the spotlight
]]
function FlashlightModel:_turnOff()
    if self._spotlight then
        self._spotlight.Enabled = false
        print("[FlashlightModel] Light OFF")
    end
end

--[[
    Give the flashlight tool to a player (puts in backpack)
    Returns true on success, false on failure
]]
function FlashlightModel:GiveToPlayer(player: Player): boolean
    if self._tool then
        self:Remove()
    end

    local backpack = player:FindFirstChild("Backpack")
    if not backpack then
        warn("[FlashlightModel] Player has no Backpack")
        return false
    end

    -- Clone tool from ReplicatedStorage
    self._tool = self:_cloneToolFromStorage(self._config.name)
    if not self._tool then
        warn("[FlashlightModel] Failed to clone flashlight tool")
        return false
    end

    self._player = player

    -- Find the spotlight and ensure it starts off
    self._spotlight = self:_findSpotlight()
    if self._spotlight then
        self._spotlight.Enabled = false
        print(string.format("[FlashlightModel] Found spotlight in: %s",
            self._spotlight.Parent and self._spotlight.Parent.Name or "unknown"))
    else
        warn("[FlashlightModel] No spotlight found in tool")
    end

    -- Connect to Equipped/Unequipped events
    self._equippedConnection = self._tool.Equipped:Connect(function()
        self:_turnOn()
    end)

    self._unequippedConnection = self._tool.Unequipped:Connect(function()
        self:_turnOff()
    end)

    -- Parent to backpack (player can equip via hotbar or pressing 1)
    self._tool.Parent = backpack

    print("[FlashlightModel] Gave flashlight to player")
    return true
end

--[[
    Equip flashlight to another player's character (for visual display)
    Returns the tool instance for cleanup, or nil on failure
]]
function FlashlightModel:EquipRemote(character: Model): Tool?
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        warn("[FlashlightModel] EquipRemote: Character has no Humanoid")
        return nil
    end

    -- Clone tool from ReplicatedStorage
    local tool = self:_cloneToolFromStorage(self._config.name)
    if not tool then
        warn("[FlashlightModel] EquipRemote: Failed to clone flashlight tool")
        return nil
    end

    tool.Name = "RemoteFlashlight"

    -- Find and enable the spotlight (it's equipped, so light is on)
    for _, descendant in tool:GetDescendants() do
        if descendant:IsA("SpotLight") then
            descendant.Enabled = true
            break
        end
    end

    -- Parent to character and equip
    tool.Parent = character
    humanoid:EquipTool(tool)

    print(string.format("[FlashlightModel] EquipRemote: Equipped flashlight to %s", character.Name))

    return tool
end

--[[
    Remove the flashlight from the player
]]
function FlashlightModel:Remove()
    if self._equippedConnection then
        self._equippedConnection:Disconnect()
        self._equippedConnection = nil
    end

    if self._unequippedConnection then
        self._unequippedConnection:Disconnect()
        self._unequippedConnection = nil
    end

    if self._tool then
        self._tool:Destroy()
        self._tool = nil
    end

    self._spotlight = nil
    self._player = nil

    print("[FlashlightModel] Removed flashlight")
end

--[[
    Check if the flashlight is currently equipped (in character, not backpack)
]]
function FlashlightModel:IsEquipped(): boolean
    if not self._tool or not self._player then
        return false
    end

    local character = self._player.Character
    if not character then
        return false
    end

    return self._tool.Parent == character
end

--[[
    Get the spotlight instance
]]
function FlashlightModel:GetSpotlight(): SpotLight?
    return self._spotlight
end

--[[
    Get the tool instance
]]
function FlashlightModel:GetTool(): Tool?
    return self._tool
end

--[[
    Destroy the flashlight model
]]
function FlashlightModel:Destroy()
    self:Remove()
end

return FlashlightModel
