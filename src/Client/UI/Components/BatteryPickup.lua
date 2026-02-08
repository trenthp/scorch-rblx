--!strict
--[[
    BatteryPickup.lua
    UI component for battery pickup notifications

    Features:
    - BillboardGui on world battery objects
    - Shows effect icon and size
    - Float-up animation on instant pickup
    - Manages all battery visual effects
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BatteryConfig = require(Shared:WaitForChild("BatteryConfig"))

local LocalPlayer = Players.LocalPlayer

export type BatteryPickupManagerObject = {
    destroy: (self: BatteryPickupManagerObject) -> (),
}

local Theme = {
    Background = Color3.fromRGB(15, 15, 22),
    Text = Color3.fromRGB(255, 255, 255),
    Bold = Enum.Font.GothamBold,
    Medium = Enum.Font.GothamMedium,
}

local BatteryPickupManager = {}
BatteryPickupManager.__index = BatteryPickupManager

function BatteryPickupManager.new(screenGui: ScreenGui): BatteryPickupManagerObject
    local self = setmetatable({}, BatteryPickupManager)

    self._screenGui = screenGui
    self._connections = {} :: { RBXScriptConnection }
    self._batteryBillboards = {} :: { [string]: BillboardGui }

    -- Connect to BatteryService events
    task.spawn(function()
        local BatteryService = Knit.GetService("BatteryService")

        -- Battery spawned - create billboard
        table.insert(self._connections, BatteryService.BatterySpawned:Connect(function(batteryId, position, effectId, sizeId)
            self:_onBatterySpawned(batteryId, position, effectId, sizeId)
        end))

        -- Battery collected - show pickup notification
        table.insert(self._connections, BatteryService.BatteryCollected:Connect(function(batteryId, player)
            self:_onBatteryCollected(batteryId, player)
        end))

        -- Battery despawned - remove billboard
        table.insert(self._connections, BatteryService.BatteryDespawned:Connect(function(batteryId)
            self:_onBatteryDespawned(batteryId)
        end))
    end)

    return self :: BatteryPickupManagerObject
end

--[[
    Handle battery spawn - create billboard GUI
]]
function BatteryPickupManager:_onBatterySpawned(batteryId: string, position: Vector3, effectId: string, sizeId: string)
    local effect = BatteryConfig.getEffect(effectId)
    local sizeConfig = BatteryConfig.getBatterySize(sizeId)

    if not effect or not sizeConfig then
        return
    end

    -- Wait for the battery part to exist
    local batteriesFolder = Workspace:FindFirstChild("Batteries")
    if not batteriesFolder then
        return
    end

    -- Find the battery part
    local batteryPart = batteriesFolder:FindFirstChild(batteryId)
    if not batteryPart then
        -- May not exist yet, try waiting briefly
        task.delay(0.1, function()
            batteryPart = batteriesFolder:FindFirstChild(batteryId)
            if batteryPart then
                self:_createBillboard(batteryId, batteryPart :: BasePart, effect, sizeConfig)
            end
        end)
        return
    end

    self:_createBillboard(batteryId, batteryPart :: BasePart, effect, sizeConfig)
end

--[[
    Create billboard GUI for a battery
]]
function BatteryPickupManager:_createBillboard(batteryId: string, batteryPart: BasePart, effect: BatteryConfig.PowerUpEffect, sizeConfig: BatteryConfig.BatterySize)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "BatteryBillboard"
    billboard.Size = UDim2.new(0, 80, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 50
    billboard.Adornee = batteryPart
    billboard.Parent = batteryPart

    -- Background
    local bg = Instance.new("Frame")
    bg.Name = "Background"
    bg.Size = UDim2.new(1, 0, 0, 35)
    bg.Position = UDim2.new(0, 0, 0, 0)
    bg.BackgroundColor3 = effect.color
    bg.BackgroundTransparency = 0.2
    bg.Parent = billboard

    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 8)
    bgCorner.Parent = bg

    -- Effect name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.Position = UDim2.new(0, 0, 0, 3)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = effect.name
    nameLabel.TextColor3 = Theme.Background
    nameLabel.TextSize = 12
    nameLabel.Font = Theme.Bold
    nameLabel.Parent = bg

    -- Size label
    local sizeLabel = Instance.new("TextLabel")
    sizeLabel.Name = "Size"
    sizeLabel.Size = UDim2.new(1, 0, 0, 15)
    sizeLabel.Position = UDim2.new(0, 0, 0, 20)
    sizeLabel.BackgroundTransparency = 1
    sizeLabel.Text = sizeConfig.name
    sizeLabel.TextColor3 = Theme.Background
    sizeLabel.TextTransparency = 0.3
    sizeLabel.TextSize = 10
    sizeLabel.Font = Theme.Medium
    sizeLabel.Parent = bg

    self._batteryBillboards[batteryId] = billboard
end

--[[
    Handle battery collected - show notification
]]
function BatteryPickupManager:_onBatteryCollected(batteryId: string, player: Player)
    -- Remove billboard
    local billboard = self._batteryBillboards[batteryId]
    if billboard then
        billboard:Destroy()
        self._batteryBillboards[batteryId] = nil
    end

    -- Show pickup notification only for local player
    if player ~= LocalPlayer then
        return
    end

    -- Get battery info (we don't have direct access, so use a generic notification)
    self:_showPickupNotification()
end

--[[
    Handle battery despawned
]]
function BatteryPickupManager:_onBatteryDespawned(batteryId: string)
    local billboard = self._batteryBillboards[batteryId]
    if billboard then
        -- Fade out
        local bg = billboard:FindFirstChild("Background")
        if bg then
            TweenService:Create(bg, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
        end

        task.delay(0.3, function()
            billboard:Destroy()
        end)

        self._batteryBillboards[batteryId] = nil
    end
end

--[[
    Show a floating pickup notification
]]
function BatteryPickupManager:_showPickupNotification()
    -- Create floating text notification
    local notification = Instance.new("Frame")
    notification.Name = "PickupNotification"
    notification.Size = UDim2.new(0, 150, 0, 40)
    notification.Position = UDim2.new(0.5, -75, 0.7, 0)
    notification.BackgroundColor3 = Theme.Background
    notification.BackgroundTransparency = 0.3
    notification.ZIndex = 100
    notification.Parent = self._screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notification

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.Text = "Battery Collected!"
    text.TextColor3 = Theme.Text
    text.TextSize = 14
    text.Font = Theme.Bold
    text.ZIndex = 101
    text.Parent = notification

    -- Float up and fade out
    local startPos = notification.Position
    local endPos = UDim2.new(startPos.X.Scale, startPos.X.Offset, startPos.Y.Scale - 0.1, startPos.Y.Offset)

    TweenService:Create(notification, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = endPos,
        BackgroundTransparency = 1,
    }):Play()

    TweenService:Create(text, TweenInfo.new(1), {
        TextTransparency = 1,
    }):Play()

    task.delay(1, function()
        notification:Destroy()
    end)
end

--[[
    Destroy the manager
]]
function BatteryPickupManager:destroy()
    for _, connection in self._connections do
        connection:Disconnect()
    end

    for _, billboard in self._batteryBillboards do
        billboard:Destroy()
    end

    self._batteryBillboards = {}
end

return BatteryPickupManager
