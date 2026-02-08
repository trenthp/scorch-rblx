--!strict
--[[
    ShopPanel.lua
    Shop interface for purchasing flashlights, skins, and battery packs

    Layout:
    ┌──────────────────────────────────────┐
    │ SHOP                    [X] 🔋 1,234 │
    ├──────────────────────────────────────┤
    │ [Flashlights] [Skins] [Batteries]    │
    ├──────────────────────────────────────┤
    │ ┌──────┐ ┌──────┐ ┌──────┐           │
    │ │ Item │ │ Item │ │ Item │           │
    │ │ 100🔋│ │ VIP  │ │ 50🔋 │           │
    │ └──────┘ └──────┘ └──────┘           │
    └──────────────────────────────────────┘
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemConfig = require(Shared:WaitForChild("ItemConfig"))

export type ShopPanelObject = {
    frame: Frame,
    show: (self: ShopPanelObject) -> (),
    hide: (self: ShopPanelObject) -> (),
    toggle: (self: ShopPanelObject) -> (),
    isVisible: (self: ShopPanelObject) -> boolean,
    destroy: (self: ShopPanelObject) -> (),
}

local Theme = {
    Background = Color3.fromRGB(15, 15, 22),
    Surface = Color3.fromRGB(25, 25, 35),
    SurfaceLight = Color3.fromRGB(35, 35, 48),
    SurfaceHover = Color3.fromRGB(45, 45, 60),
    Text = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(140, 140, 155),
    TextMuted = Color3.fromRGB(80, 80, 95),
    Accent = Color3.fromRGB(100, 180, 255),
    Success = Color3.fromRGB(85, 220, 120),
    Warning = Color3.fromRGB(255, 200, 85),
    Danger = Color3.fromRGB(255, 95, 95),
    Currency = Color3.fromRGB(255, 200, 85),
    VIP = Color3.fromRGB(255, 180, 50),
    Radius = UDim.new(0, 10),
    RadiusSmall = UDim.new(0, 6),
    Bold = Enum.Font.GothamBold,
    Medium = Enum.Font.GothamMedium,
    Regular = Enum.Font.Gotham,
    Fast = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Normal = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

local PANEL_WIDTH = 450
local PANEL_HEIGHT = 500
local ITEM_SIZE = 120
local ITEM_PADDING = 10

local ShopPanel = {}
ShopPanel.__index = ShopPanel

function ShopPanel.new(parent: ScreenGui): ShopPanelObject
    local self = setmetatable({}, ShopPanel)

    self._isVisible = false
    self._currentTab = "Flashlights"
    self._connections = {} :: { RBXScriptConnection }
    self._currencyAmount = 0

    -- Main frame (centered)
    self.frame = Instance.new("Frame")
    self.frame.Name = "ShopPanel"
    self.frame.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
    self.frame.Position = UDim2.new(0.5, -PANEL_WIDTH/2, 0.5, -PANEL_HEIGHT/2)
    self.frame.BackgroundColor3 = Theme.Background
    self.frame.Visible = false
    self.frame.ZIndex = 60
    self.frame.Parent = parent

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = Theme.Radius
    frameCorner.Parent = self.frame

    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Theme.SurfaceLight
    frameStroke.Thickness = 2
    frameStroke.Parent = self.frame

    -- Header
    self:_createHeader()

    -- Tabs
    self:_createTabs()

    -- Content area
    self:_createContentArea()

    -- Connect to controllers
    task.spawn(function()
        local BatteryController = Knit.GetController("BatteryController")
        local InventoryController = Knit.GetController("InventoryController")

        -- Currency updates
        table.insert(self._connections, BatteryController:OnCurrencyChanged(function(amount)
            self._currencyAmount = amount
            self:_updateCurrencyDisplay()
        end))

        -- Inventory updates
        table.insert(self._connections, InventoryController:OnInventoryChanged(function()
            self:_refreshCurrentTab()
        end))

        -- Purchase failures
        table.insert(self._connections, InventoryController:OnPurchaseFailed(function(reason)
            -- Could show a notification here
            warn("[ShopPanel] Purchase failed:", reason)
        end))

        -- Initialize
        self._currencyAmount = BatteryController:GetCurrency()
        self:_updateCurrencyDisplay()
    end)

    return self :: ShopPanelObject
end

--[[
    Create header with title, close button, and currency display
]]
function ShopPanel:_createHeader()
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundColor3 = Theme.Surface
    header.ZIndex = 61
    header.Parent = self.frame

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = Theme.Radius
    headerCorner.Parent = header

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(0, 100, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "SHOP"
    title.TextColor3 = Theme.Text
    title.TextSize = 20
    title.Font = Theme.Bold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 62
    title.Parent = header

    -- Currency display
    self._currencyLabel = Instance.new("TextLabel")
    self._currencyLabel.Name = "Currency"
    self._currencyLabel.Size = UDim2.new(0, 100, 0, 30)
    self._currencyLabel.Position = UDim2.new(1, -150, 0.5, -15)
    self._currencyLabel.BackgroundColor3 = Theme.SurfaceLight
    self._currencyLabel.Text = "0"
    self._currencyLabel.TextColor3 = Theme.Currency
    self._currencyLabel.TextSize = 14
    self._currencyLabel.Font = Theme.Bold
    self._currencyLabel.ZIndex = 62
    self._currencyLabel.Parent = header

    local currencyCorner = Instance.new("UICorner")
    currencyCorner.CornerRadius = UDim.new(0, 6)
    currencyCorner.Parent = self._currencyLabel

    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "Close"
    closeButton.Size = UDim2.new(0, 35, 0, 35)
    closeButton.Position = UDim2.new(1, -42, 0.5, -17)
    closeButton.BackgroundTransparency = 1
    closeButton.Text = "X"
    closeButton.TextColor3 = Theme.TextMuted
    closeButton.TextSize = 20
    closeButton.Font = Theme.Bold
    closeButton.ZIndex = 62
    closeButton.Parent = header

    closeButton.MouseEnter:Connect(function()
        closeButton.TextColor3 = Theme.Text
    end)
    closeButton.MouseLeave:Connect(function()
        closeButton.TextColor3 = Theme.TextMuted
    end)
    closeButton.MouseButton1Click:Connect(function()
        self:hide()
    end)
end

--[[
    Create tab buttons
]]
function ShopPanel:_createTabs()
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "Tabs"
    tabContainer.Size = UDim2.new(1, -20, 0, 40)
    tabContainer.Position = UDim2.new(0, 10, 0, 55)
    tabContainer.BackgroundTransparency = 1
    tabContainer.ZIndex = 61
    tabContainer.Parent = self.frame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.Padding = UDim.new(0, 5)
    layout.Parent = tabContainer

    self._tabButtons = {}
    local tabs = { "Flashlights", "Skins", "Batteries" }

    for _, tabName in tabs do
        local tab = Instance.new("TextButton")
        tab.Name = tabName
        tab.Size = UDim2.new(0, 130, 1, 0)
        tab.BackgroundColor3 = Theme.Surface
        tab.BackgroundTransparency = 1
        tab.Text = tabName
        tab.TextColor3 = Theme.TextMuted
        tab.TextSize = 14
        tab.Font = Theme.Medium
        tab.ZIndex = 62
        tab.Parent = tabContainer

        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = Theme.RadiusSmall
        tabCorner.Parent = tab

        tab.MouseEnter:Connect(function()
            if self._currentTab ~= tabName then
                TweenService:Create(tab, Theme.Fast, { BackgroundTransparency = 0.5 }):Play()
            end
        end)
        tab.MouseLeave:Connect(function()
            if self._currentTab ~= tabName then
                TweenService:Create(tab, Theme.Fast, { BackgroundTransparency = 1 }):Play()
            end
        end)
        tab.MouseButton1Click:Connect(function()
            self:_selectTab(tabName)
        end)

        self._tabButtons[tabName] = tab
    end

    -- Select default tab
    self:_selectTab("Flashlights")
end

--[[
    Select a tab
]]
function ShopPanel:_selectTab(tabName: string)
    self._currentTab = tabName

    -- Update tab buttons
    for name, tab in self._tabButtons do
        local isSelected = name == tabName
        tab.TextColor3 = isSelected and Theme.Text or Theme.TextMuted
        tab.BackgroundTransparency = isSelected and 0 or 1
    end

    -- Refresh content
    self:_refreshCurrentTab()
end

--[[
    Create content scroll area
]]
function ShopPanel:_createContentArea()
    self._contentFrame = Instance.new("ScrollingFrame")
    self._contentFrame.Name = "Content"
    self._contentFrame.Size = UDim2.new(1, -20, 1, -115)
    self._contentFrame.Position = UDim2.new(0, 10, 0, 105)
    self._contentFrame.BackgroundTransparency = 1
    self._contentFrame.ScrollBarThickness = 4
    self._contentFrame.ScrollBarImageColor3 = Theme.SurfaceLight
    self._contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    self._contentFrame.ZIndex = 61
    self._contentFrame.Parent = self.frame

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0, ITEM_SIZE, 0, ITEM_SIZE + 30)
    grid.CellPadding = UDim2.new(0, ITEM_PADDING, 0, ITEM_PADDING)
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
    grid.VerticalAlignment = Enum.VerticalAlignment.Top
    grid.Parent = self._contentFrame
end

--[[
    Refresh the current tab content
]]
function ShopPanel:_refreshCurrentTab()
    -- Clear existing items
    for _, child in self._contentFrame:GetChildren() do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    if self._currentTab == "Flashlights" then
        self:_populateFlashlights()
    elseif self._currentTab == "Skins" then
        self:_populateSkins()
    elseif self._currentTab == "Batteries" then
        self:_populateBatteryPacks()
    end
end

--[[
    Populate flashlight items
]]
function ShopPanel:_populateFlashlights()
    local InventoryController = Knit.GetController("InventoryController")
    local items = InventoryController:GetFlashlightList()

    for i, item in items do
        self:_createFlashlightItem(item.config, item.owned, item.equipped, i)
    end

    -- Update canvas size
    local rows = math.ceil(#items / 3)
    self._contentFrame.CanvasSize = UDim2.new(0, 0, 0, rows * (ITEM_SIZE + 30 + ITEM_PADDING))
end

--[[
    Create a flashlight item display
]]
function ShopPanel:_createFlashlightItem(config: ItemConfig.FlashlightConfig, owned: boolean, equipped: boolean, order: number)
    local item = Instance.new("Frame")
    item.Name = config.id
    item.BackgroundColor3 = Theme.Surface
    item.LayoutOrder = order
    item.ZIndex = 62
    item.Parent = self._contentFrame

    local itemCorner = Instance.new("UICorner")
    itemCorner.CornerRadius = Theme.RadiusSmall
    itemCorner.Parent = item

    -- Preview color indicator
    local preview = Instance.new("Frame")
    preview.Name = "Preview"
    preview.Size = UDim2.new(0, 50, 0, 50)
    preview.Position = UDim2.new(0.5, -25, 0, 10)
    preview.BackgroundColor3 = config.lightColor or Color3.new(1, 1, 0.9)
    preview.ZIndex = 63
    preview.Parent = item

    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0.5, 0)
    previewCorner.Parent = preview

    -- Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, -10, 0, 20)
    nameLabel.Position = UDim2.new(0, 5, 0, 65)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = config.name
    nameLabel.TextColor3 = Theme.Text
    nameLabel.TextSize = 12
    nameLabel.Font = Theme.Bold
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.ZIndex = 63
    nameLabel.Parent = item

    -- Status/Price
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, -10, 0, 18)
    statusLabel.Position = UDim2.new(0, 5, 0, 85)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextSize = 11
    statusLabel.Font = Theme.Medium
    statusLabel.ZIndex = 63
    statusLabel.Parent = item

    if equipped then
        statusLabel.Text = "EQUIPPED"
        statusLabel.TextColor3 = Theme.Success
    elseif owned then
        statusLabel.Text = "OWNED"
        statusLabel.TextColor3 = Theme.Accent
    elseif config.requiresVIP then
        statusLabel.Text = "VIP ONLY"
        statusLabel.TextColor3 = Theme.VIP
    elseif config.unlockLevel then
        local InventoryController = Knit.GetController("InventoryController")
        local DataService = Knit.GetService("DataService")
        local data = DataService:GetMyData()
        local playerLevel = data and data.progression.level or 1

        if playerLevel >= config.unlockLevel then
            statusLabel.Text = config.price and tostring(config.price) .. " batteries" or "FREE"
            statusLabel.TextColor3 = Theme.Currency
        else
            statusLabel.Text = "Level " .. tostring(config.unlockLevel)
            statusLabel.TextColor3 = Theme.TextMuted
        end
    elseif config.price then
        statusLabel.Text = tostring(config.price) .. " batteries"
        statusLabel.TextColor3 = Theme.Currency
    else
        statusLabel.Text = "FREE"
        statusLabel.TextColor3 = Theme.Success
    end

    -- Action button
    local actionButton = Instance.new("TextButton")
    actionButton.Name = "Action"
    actionButton.Size = UDim2.new(1, -10, 0, 25)
    actionButton.Position = UDim2.new(0, 5, 1, -30)
    actionButton.BackgroundColor3 = equipped and Theme.SurfaceLight or (owned and Theme.Accent or Theme.Success)
    actionButton.Text = equipped and "Equipped" or (owned and "Equip" or "Buy")
    actionButton.TextColor3 = Theme.Text
    actionButton.TextSize = 11
    actionButton.Font = Theme.Bold
    actionButton.ZIndex = 63
    actionButton.Parent = item

    local actionCorner = Instance.new("UICorner")
    actionCorner.CornerRadius = UDim.new(0, 4)
    actionCorner.Parent = actionButton

    if not equipped then
        actionButton.MouseEnter:Connect(function()
            TweenService:Create(actionButton, Theme.Fast, { BackgroundColor3 = Theme.SurfaceHover }):Play()
        end)
        actionButton.MouseLeave:Connect(function()
            TweenService:Create(actionButton, Theme.Fast, {
                BackgroundColor3 = owned and Theme.Accent or Theme.Success
            }):Play()
        end)
        actionButton.MouseButton1Click:Connect(function()
            local InventoryController = Knit.GetController("InventoryController")
            if owned then
                InventoryController:EquipFlashlight(config.id)
            else
                InventoryController:UnlockFlashlight(config.id)
            end
        end)
    else
        actionButton.AutoButtonColor = false
    end
end

--[[
    Populate skin items
]]
function ShopPanel:_populateSkins()
    local InventoryController = Knit.GetController("InventoryController")
    local items = InventoryController:GetSkinList()

    for i, item in items do
        self:_createSkinItem(item.config, item.owned, item.equipped, i)
    end

    local rows = math.ceil(#items / 3)
    self._contentFrame.CanvasSize = UDim2.new(0, 0, 0, rows * (ITEM_SIZE + 30 + ITEM_PADDING))
end

--[[
    Create a skin item display
]]
function ShopPanel:_createSkinItem(config: ItemConfig.SkinConfig, owned: boolean, equipped: boolean, order: number)
    local item = Instance.new("Frame")
    item.Name = config.id
    item.BackgroundColor3 = Theme.Surface
    item.LayoutOrder = order
    item.ZIndex = 62
    item.Parent = self._contentFrame

    local itemCorner = Instance.new("UICorner")
    itemCorner.CornerRadius = Theme.RadiusSmall
    itemCorner.Parent = item

    -- Color preview
    local preview = Instance.new("Frame")
    preview.Name = "Preview"
    preview.Size = UDim2.new(0, 50, 0, 50)
    preview.Position = UDim2.new(0.5, -25, 0, 10)
    preview.BackgroundColor3 = config.bodyColor
    preview.ZIndex = 63
    preview.Parent = item

    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0, 8)
    previewCorner.Parent = preview

    -- Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, -10, 0, 20)
    nameLabel.Position = UDim2.new(0, 5, 0, 65)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = config.name
    nameLabel.TextColor3 = Theme.Text
    nameLabel.TextSize = 12
    nameLabel.Font = Theme.Bold
    nameLabel.ZIndex = 63
    nameLabel.Parent = item

    -- Status/Price
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, -10, 0, 18)
    statusLabel.Position = UDim2.new(0, 5, 0, 85)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextSize = 11
    statusLabel.Font = Theme.Medium
    statusLabel.ZIndex = 63
    statusLabel.Parent = item

    if equipped then
        statusLabel.Text = "EQUIPPED"
        statusLabel.TextColor3 = Theme.Success
    elseif owned then
        statusLabel.Text = "OWNED"
        statusLabel.TextColor3 = Theme.Accent
    elseif config.requiresVIP then
        statusLabel.Text = "VIP ONLY"
        statusLabel.TextColor3 = Theme.VIP
    elseif config.price then
        statusLabel.Text = tostring(config.price) .. " batteries"
        statusLabel.TextColor3 = Theme.Currency
    else
        statusLabel.Text = "FREE"
        statusLabel.TextColor3 = Theme.Success
    end

    -- Action button
    local actionButton = Instance.new("TextButton")
    actionButton.Name = "Action"
    actionButton.Size = UDim2.new(1, -10, 0, 25)
    actionButton.Position = UDim2.new(0, 5, 1, -30)
    actionButton.BackgroundColor3 = equipped and Theme.SurfaceLight or (owned and Theme.Accent or Theme.Success)
    actionButton.Text = equipped and "Equipped" or (owned and "Equip" or "Buy")
    actionButton.TextColor3 = Theme.Text
    actionButton.TextSize = 11
    actionButton.Font = Theme.Bold
    actionButton.ZIndex = 63
    actionButton.Parent = item

    local actionCorner = Instance.new("UICorner")
    actionCorner.CornerRadius = UDim.new(0, 4)
    actionCorner.Parent = actionButton

    if not equipped then
        actionButton.MouseButton1Click:Connect(function()
            local InventoryController = Knit.GetController("InventoryController")
            if owned then
                InventoryController:EquipSkin(config.id)
            else
                InventoryController:UnlockSkin(config.id)
            end
        end)
    end
end

--[[
    Populate battery pack items
]]
function ShopPanel:_populateBatteryPacks()
    local InventoryController = Knit.GetController("InventoryController")
    local packs = InventoryController:GetBatteryPackList()

    for i, pack in packs do
        self:_createBatteryPackItem(pack, i)
    end

    local rows = math.ceil(#packs / 3)
    self._contentFrame.CanvasSize = UDim2.new(0, 0, 0, rows * (ITEM_SIZE + 30 + ITEM_PADDING))
end

--[[
    Create a battery pack item display
]]
function ShopPanel:_createBatteryPackItem(pack: ItemConfig.ShopItem, order: number)
    local item = Instance.new("Frame")
    item.Name = pack.id
    item.BackgroundColor3 = Theme.Surface
    item.LayoutOrder = order
    item.ZIndex = 62
    item.Parent = self._contentFrame

    local itemCorner = Instance.new("UICorner")
    itemCorner.CornerRadius = Theme.RadiusSmall
    itemCorner.Parent = item

    -- Battery icon (stylized)
    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 50, 0, 50)
    icon.Position = UDim2.new(0.5, -25, 0, 10)
    icon.BackgroundColor3 = Theme.Currency
    icon.Text = "+"
    icon.TextColor3 = Theme.Background
    icon.TextSize = 30
    icon.Font = Theme.Bold
    icon.ZIndex = 63
    icon.Parent = item

    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0.5, 0)
    iconCorner.Parent = icon

    -- Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, -10, 0, 20)
    nameLabel.Position = UDim2.new(0, 5, 0, 65)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = pack.name
    nameLabel.TextColor3 = Theme.Text
    nameLabel.TextSize = 12
    nameLabel.Font = Theme.Bold
    nameLabel.ZIndex = 63
    nameLabel.Parent = item

    -- Description
    local descLabel = Instance.new("TextLabel")
    descLabel.Name = "Desc"
    descLabel.Size = UDim2.new(1, -10, 0, 18)
    descLabel.Position = UDim2.new(0, 5, 0, 85)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = pack.description
    descLabel.TextColor3 = Theme.TextSecondary
    descLabel.TextSize = 10
    descLabel.Font = Theme.Medium
    descLabel.ZIndex = 63
    descLabel.Parent = item

    -- Purchase button with Robux price
    local purchaseButton = Instance.new("TextButton")
    purchaseButton.Name = "Purchase"
    purchaseButton.Size = UDim2.new(1, -10, 0, 25)
    purchaseButton.Position = UDim2.new(0, 5, 1, -30)
    purchaseButton.BackgroundColor3 = Theme.Success
    purchaseButton.Text = pack.robuxPrice and ("R$ " .. tostring(pack.robuxPrice)) or "Buy"
    purchaseButton.TextColor3 = Theme.Text
    purchaseButton.TextSize = 11
    purchaseButton.Font = Theme.Bold
    purchaseButton.ZIndex = 63
    purchaseButton.Parent = item

    local purchaseCorner = Instance.new("UICorner")
    purchaseCorner.CornerRadius = UDim.new(0, 4)
    purchaseCorner.Parent = purchaseButton

    purchaseButton.MouseButton1Click:Connect(function()
        local InventoryController = Knit.GetController("InventoryController")
        InventoryController:PurchaseBatteryPack(pack.id)
    end)
end

--[[
    Update currency display
]]
function ShopPanel:_updateCurrencyDisplay()
    if self._currencyLabel then
        self._currencyLabel.Text = tostring(self._currencyAmount)
    end
end

--[[
    Show the panel
]]
function ShopPanel:show()
    self._isVisible = true
    self.frame.Visible = true
    self:_refreshCurrentTab()

    -- Entry animation
    self.frame.Size = UDim2.new(0, PANEL_WIDTH * 0.9, 0, PANEL_HEIGHT * 0.9)
    self.frame.BackgroundTransparency = 0.5
    TweenService:Create(self.frame, Theme.Normal, {
        Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT),
        BackgroundTransparency = 0,
    }):Play()
end

--[[
    Hide the panel
]]
function ShopPanel:hide()
    self._isVisible = false

    TweenService:Create(self.frame, Theme.Fast, {
        Size = UDim2.new(0, PANEL_WIDTH * 0.9, 0, PANEL_HEIGHT * 0.9),
        BackgroundTransparency = 0.5,
    }):Play()

    task.delay(0.15, function()
        if not self._isVisible then
            self.frame.Visible = false
        end
    end)
end

--[[
    Toggle visibility
]]
function ShopPanel:toggle()
    if self._isVisible then
        self:hide()
    else
        self:show()
    end
end

--[[
    Check visibility
]]
function ShopPanel:isVisible(): boolean
    return self._isVisible
end

--[[
    Destroy the component
]]
function ShopPanel:destroy()
    for _, conn in self._connections do
        conn:Disconnect()
    end
    self.frame:Destroy()
end

return ShopPanel
