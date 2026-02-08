--!strict
--[[
    PowerUpBar.lua
    UI component for displaying active power-up effects and stored batteries

    Layout (bottom-right):
    ┌─────────────────────────────────┐
    │ [Active Effect Icons w/ timers] │
    ├─────────────────────────────────┤
    │ [1]🔋 [2]🔋 [3]🔋 [4]🔋        │
    │  Stored batteries (4 slots)     │
    └─────────────────────────────────┘
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BatteryConfig = require(Shared:WaitForChild("BatteryConfig"))

export type PowerUpBarObject = {
    frame: Frame,
    show: (self: PowerUpBarObject) -> (),
    hide: (self: PowerUpBarObject) -> (),
    destroy: (self: PowerUpBarObject) -> (),
}

local Theme = {
    Background = Color3.fromRGB(15, 15, 22),
    Surface = Color3.fromRGB(25, 25, 35),
    SurfaceLight = Color3.fromRGB(35, 35, 48),
    Text = Color3.fromRGB(255, 255, 255),
    TextMuted = Color3.fromRGB(80, 80, 95),
    Radius = UDim.new(0, 8),
    RadiusSmall = UDim.new(0, 6),
    Bold = Enum.Font.GothamBold,
    Medium = Enum.Font.GothamMedium,
    Regular = Enum.Font.Gotham,
    Fast = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

local SLOT_SIZE = 50
local EFFECT_SIZE = 45
local PADDING = 8

local PowerUpBar = {}
PowerUpBar.__index = PowerUpBar

function PowerUpBar.new(parent: ScreenGui): PowerUpBarObject
    local self = setmetatable({}, PowerUpBar)

    self._connections = {} :: { RBXScriptConnection }
    self._activeEffectFrames = {} :: { [string]: Frame }
    self._storedBatterySlots = {} :: { Frame }
    self._updateConnection = nil :: RBXScriptConnection?

    -- Main frame (bottom-right position)
    self.frame = Instance.new("Frame")
    self.frame.Name = "PowerUpBar"
    self.frame.Size = UDim2.new(0, 250, 0, 120)
    self.frame.Position = UDim2.new(1, -260, 1, -130)
    self.frame.BackgroundTransparency = 1
    self.frame.ZIndex = 30
    self.frame.Parent = parent

    -- Active effects container (top row)
    self._effectsContainer = Instance.new("Frame")
    self._effectsContainer.Name = "Effects"
    self._effectsContainer.Size = UDim2.new(1, 0, 0, EFFECT_SIZE)
    self._effectsContainer.Position = UDim2.new(0, 0, 0, 0)
    self._effectsContainer.BackgroundTransparency = 1
    self._effectsContainer.ZIndex = 31
    self._effectsContainer.Parent = self.frame

    local effectsLayout = Instance.new("UIListLayout")
    effectsLayout.FillDirection = Enum.FillDirection.Horizontal
    effectsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    effectsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    effectsLayout.Padding = UDim.new(0, PADDING)
    effectsLayout.Parent = self._effectsContainer

    -- Stored batteries container (bottom row)
    self._batteriesContainer = Instance.new("Frame")
    self._batteriesContainer.Name = "StoredBatteries"
    self._batteriesContainer.Size = UDim2.new(1, 0, 0, SLOT_SIZE + 10)
    self._batteriesContainer.Position = UDim2.new(0, 0, 0, EFFECT_SIZE + 10)
    self._batteriesContainer.BackgroundTransparency = 1
    self._batteriesContainer.ZIndex = 31
    self._batteriesContainer.Parent = self.frame

    local batteriesLayout = Instance.new("UIListLayout")
    batteriesLayout.FillDirection = Enum.FillDirection.Horizontal
    batteriesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    batteriesLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    batteriesLayout.Padding = UDim.new(0, PADDING)
    batteriesLayout.Parent = self._batteriesContainer

    -- Create 4 stored battery slots
    for i = 1, BatteryConfig.MAX_STORED_BATTERIES do
        self:_createBatterySlot(i)
    end

    -- Connect to BatteryController
    task.spawn(function()
        local BatteryController = Knit.GetController("BatteryController")

        -- Effect events
        table.insert(self._connections, BatteryController:OnEffectActivated(function(effectId, duration)
            self:_addActiveEffect(effectId, duration)
        end))

        table.insert(self._connections, BatteryController:OnEffectExpired(function(effectId)
            self:_removeActiveEffect(effectId)
        end))

        -- Stored batteries events
        table.insert(self._connections, BatteryController:OnStoredBatteriesChanged(function(batteries)
            self:_updateStoredBatteries(batteries)
        end))

        -- Initialize with current state
        local activeEffects = BatteryController:GetActiveEffects()
        for effectId, effectData in activeEffects do
            local remaining = effectData.endTime - tick()
            if remaining > 0 then
                self:_addActiveEffect(effectId, remaining)
            end
        end

        local storedBatteries = BatteryController:GetStoredBatteries()
        self:_updateStoredBatteries(storedBatteries)
    end)

    -- Start update loop for effect timers
    self._updateConnection = RunService.Heartbeat:Connect(function()
        self:_updateEffectTimers()
    end)

    return self :: PowerUpBarObject
end

--[[
    Create a battery slot UI
]]
function PowerUpBar:_createBatterySlot(slotIndex: number)
    local slot = Instance.new("Frame")
    slot.Name = "Slot" .. tostring(slotIndex)
    slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE + 15)
    slot.BackgroundTransparency = 1
    slot.LayoutOrder = slotIndex
    slot.ZIndex = 32
    slot.Parent = self._batteriesContainer

    -- Background (clickable button)
    local bg = Instance.new("TextButton")
    bg.Name = "Background"
    bg.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
    bg.Position = UDim2.new(0.5, -SLOT_SIZE/2, 0, 0)
    bg.BackgroundColor3 = Theme.Surface
    bg.Text = ""
    bg.AutoButtonColor = false
    bg.ZIndex = 33
    bg.Parent = slot

    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = Theme.Radius
    bgCorner.Parent = bg

    local bgStroke = Instance.new("UIStroke")
    bgStroke.Name = "Stroke"
    bgStroke.Color = Theme.SurfaceLight
    bgStroke.Thickness = 2
    bgStroke.Parent = bg

    -- Click to activate
    bg.MouseButton1Click:Connect(function()
        local BatteryController = Knit.GetController("BatteryController")
        BatteryController:ActivateStoredBattery(slotIndex)
    end)

    -- Hover effect
    bg.MouseEnter:Connect(function()
        if bg:GetAttribute("HasBattery") then
            TweenService:Create(bg, Theme.Fast, { BackgroundColor3 = Theme.SurfaceLight }):Play()
        end
    end)
    bg.MouseLeave:Connect(function()
        TweenService:Create(bg, Theme.Fast, { BackgroundColor3 = Theme.Surface }):Play()
    end)

    -- Effect color indicator (hidden by default)
    local colorIndicator = Instance.new("Frame")
    colorIndicator.Name = "ColorIndicator"
    colorIndicator.Size = UDim2.new(1, -8, 1, -8)
    colorIndicator.Position = UDim2.new(0, 4, 0, 4)
    colorIndicator.BackgroundColor3 = Color3.new(1, 1, 1)
    colorIndicator.BackgroundTransparency = 0.7
    colorIndicator.Visible = false
    colorIndicator.ZIndex = 34
    colorIndicator.Parent = bg

    local indicatorCorner = Instance.new("UICorner")
    indicatorCorner.CornerRadius = UDim.new(0, 6)
    indicatorCorner.Parent = colorIndicator

    -- Effect icon/text
    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(1, 0, 1, 0)
    icon.BackgroundTransparency = 1
    icon.Text = ""
    icon.TextColor3 = Theme.Text
    icon.TextSize = 20
    icon.Font = Theme.Bold
    icon.ZIndex = 35
    icon.Parent = bg

    -- Keybind label
    local keybind = Instance.new("TextLabel")
    keybind.Name = "Keybind"
    keybind.Size = UDim2.new(1, 0, 0, 15)
    keybind.Position = UDim2.new(0, 0, 1, 0)
    keybind.BackgroundTransparency = 1
    keybind.Text = tostring(slotIndex)
    keybind.TextColor3 = Theme.TextMuted
    keybind.TextSize = 12
    keybind.Font = Theme.Medium
    keybind.ZIndex = 33
    keybind.Parent = slot

    self._storedBatterySlots[slotIndex] = slot
end

--[[
    Update stored battery slots
]]
function PowerUpBar:_updateStoredBatteries(batteries: { BatteryConfig.StoredBattery })
    for i = 1, BatteryConfig.MAX_STORED_BATTERIES do
        local slot = self._storedBatterySlots[i]
        local bg = slot:FindFirstChild("Background")
        local colorIndicator = bg:FindFirstChild("ColorIndicator")
        local icon = bg:FindFirstChild("Icon")
        local stroke = bg:FindFirstChild("Stroke")

        if i <= #batteries then
            local battery = batteries[i]
            local effect = BatteryConfig.getEffect(battery.effectId)
            local sizeConfig = BatteryConfig.getBatterySize(battery.sizeId)

            if effect then
                -- Show filled slot
                colorIndicator.BackgroundColor3 = effect.color
                colorIndicator.Visible = true
                stroke.Color = effect.color
                bg:SetAttribute("HasBattery", true)

                -- Show first letter of effect
                icon.Text = string.sub(effect.name, 1, 1)

                -- Pulse animation
                TweenService:Create(colorIndicator, Theme.Fast, { BackgroundTransparency = 0.5 }):Play()
            end
        else
            -- Show empty slot
            colorIndicator.Visible = false
            stroke.Color = Theme.SurfaceLight
            bg:SetAttribute("HasBattery", false)
            icon.Text = ""
        end
    end
end

--[[
    Add an active effect display
]]
function PowerUpBar:_addActiveEffect(effectId: string, duration: number)
    local effect = BatteryConfig.getEffect(effectId)
    if not effect then
        return
    end

    -- Check if already exists
    if self._activeEffectFrames[effectId] then
        -- Just update the end time
        local existingFrame = self._activeEffectFrames[effectId]
        existingFrame:SetAttribute("EndTime", tick() + duration)
        return
    end

    -- Create effect display
    local effectFrame = Instance.new("Frame")
    effectFrame.Name = effectId
    effectFrame.Size = UDim2.new(0, EFFECT_SIZE, 0, EFFECT_SIZE)
    effectFrame.BackgroundColor3 = effect.color
    effectFrame.ZIndex = 32
    effectFrame:SetAttribute("EndTime", tick() + duration)
    effectFrame.Parent = self._effectsContainer

    local effectCorner = Instance.new("UICorner")
    effectCorner.CornerRadius = Theme.Radius
    effectCorner.Parent = effectFrame

    -- Effect icon (first letter)
    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(1, 0, 0, 25)
    icon.Position = UDim2.new(0, 0, 0, 5)
    icon.BackgroundTransparency = 1
    icon.Text = string.sub(effect.name, 1, 1)
    icon.TextColor3 = Theme.Background
    icon.TextSize = 18
    icon.Font = Theme.Bold
    icon.ZIndex = 33
    icon.Parent = effectFrame

    -- Timer text
    local timer = Instance.new("TextLabel")
    timer.Name = "Timer"
    timer.Size = UDim2.new(1, 0, 0, 15)
    timer.Position = UDim2.new(0, 0, 1, -18)
    timer.BackgroundTransparency = 1
    timer.Text = tostring(math.ceil(duration))
    timer.TextColor3 = Theme.Background
    timer.TextSize = 12
    timer.Font = Theme.Medium
    timer.ZIndex = 33
    timer.Parent = effectFrame

    -- Entry animation
    effectFrame.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(effectFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, EFFECT_SIZE, 0, EFFECT_SIZE),
    }):Play()

    self._activeEffectFrames[effectId] = effectFrame
end

--[[
    Remove an active effect display
]]
function PowerUpBar:_removeActiveEffect(effectId: string)
    local effectFrame = self._activeEffectFrames[effectId]
    if not effectFrame then
        return
    end

    -- Exit animation
    TweenService:Create(effectFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
    }):Play()

    task.delay(0.2, function()
        effectFrame:Destroy()
    end)

    self._activeEffectFrames[effectId] = nil
end

--[[
    Update effect timers
]]
function PowerUpBar:_updateEffectTimers()
    local now = tick()

    for effectId, effectFrame in self._activeEffectFrames do
        local endTime = effectFrame:GetAttribute("EndTime") or now
        local remaining = math.max(0, endTime - now)

        local timer = effectFrame:FindFirstChild("Timer") :: TextLabel?
        if timer then
            timer.Text = tostring(math.ceil(remaining))
        end

        -- Flash when low on time
        if remaining <= 3 and remaining > 0 then
            local flash = math.sin(now * 10) > 0
            effectFrame.BackgroundTransparency = flash and 0.3 or 0
        else
            effectFrame.BackgroundTransparency = 0
        end
    end
end

--[[
    Show the power-up bar
]]
function PowerUpBar:show()
    self.frame.Visible = true
end

--[[
    Hide the power-up bar
]]
function PowerUpBar:hide()
    self.frame.Visible = false
end

--[[
    Destroy the component
]]
function PowerUpBar:destroy()
    if self._updateConnection then
        self._updateConnection:Disconnect()
    end

    for _, connection in self._connections do
        connection:Disconnect()
    end

    self.frame:Destroy()
end

return PowerUpBar
