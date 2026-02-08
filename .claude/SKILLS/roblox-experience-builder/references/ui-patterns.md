# UI Patterns

## Responsive UI Setup

```lua
-- StarterGui/UIController.client.lua
--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")

-- Detect device type
local function getDeviceType(): "Mobile" | "Tablet" | "Desktop" | "Console"
    if UserInputService.TouchEnabled then
        local viewport = workspace.CurrentCamera.ViewportSize
        if viewport.X < 600 then
            return "Mobile"
        else
            return "Tablet"
        end
    elseif UserInputService.GamepadEnabled then
        return "Console"
    else
        return "Desktop"
    end
end

local deviceType = getDeviceType()

-- Scale UI based on device
local function scaleForDevice(baseSize: UDim2): UDim2
    if deviceType == "Mobile" then
        return UDim2.new(
            baseSize.X.Scale * 1.3,
            baseSize.X.Offset * 1.3,
            baseSize.Y.Scale * 1.3,
            baseSize.Y.Offset * 1.3
        )
    end
    return baseSize
end
```

## HUD Layout

```lua
-- StarterGui/HUD/HUDSetup.client.lua
--!strict

-- Standard HUD positions
local HUD_LAYOUT = {
    -- Top left: Player info, health
    PlayerInfo = UDim2.new(0, 10, 0, 10),
    
    -- Top center: Notifications, announcements
    Notifications = UDim2.new(0.5, 0, 0, 10),
    
    -- Top right: Currency display
    Currency = UDim2.new(1, -10, 0, 10),
    
    -- Bottom left: Chat, social
    Social = UDim2.new(0, 10, 1, -10),
    
    -- Bottom center: Action buttons (mobile)
    Actions = UDim2.new(0.5, 0, 1, -100),
    
    -- Bottom right: Menu buttons
    Menu = UDim2.new(1, -10, 1, -10),
    
    -- Center: Popups, modals
    Center = UDim2.new(0.5, 0, 0.5, 0),
}
```

## Currency Display

```lua
-- StarterGui/HUD/CurrencyDisplay.client.lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = script.Parent

local coinsLabel = gui:WaitForChild("CoinsLabel") :: TextLabel
local gemsLabel = gui:WaitForChild("GemsLabel") :: TextLabel

local UpdateCurrency = ReplicatedStorage.Remotes.Events.UpdateCurrency :: RemoteEvent

-- Animated number change
local function animateNumber(label: TextLabel, targetValue: number, duration: number?)
    local currentValue = tonumber(label.Text:gsub(",", "")) or 0
    local startValue = currentValue
    local elapsed = 0
    local totalTime = duration or 0.5
    
    local connection
    connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
        elapsed += dt
        local progress = math.min(elapsed / totalTime, 1)
        
        -- Ease out
        local eased = 1 - (1 - progress) ^ 3
        local displayValue = math.floor(startValue + (targetValue - startValue) * eased)
        
        label.Text = formatNumber(displayValue)
        
        if progress >= 1 then
            connection:Disconnect()
        end
    end)
end

local function formatNumber(num: number): string
    if num >= 1000000000 then
        return string.format("%.1fB", num / 1000000000)
    elseif num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(num)
    end
end

-- Bounce effect on change
local function bounceEffect(label: TextLabel)
    local originalSize = label.Size
    local tween = TweenService:Create(label, TweenInfo.new(0.1), {
        Size = UDim2.new(
            originalSize.X.Scale * 1.2,
            originalSize.X.Offset,
            originalSize.Y.Scale * 1.2,
            originalSize.Y.Offset
        )
    })
    tween:Play()
    tween.Completed:Connect(function()
        TweenService:Create(label, TweenInfo.new(0.1), {Size = originalSize}):Play()
    end)
end

UpdateCurrency.OnClientEvent:Connect(function(currency: string, newValue: number)
    local label = currency == "Coins" and coinsLabel or gemsLabel
    bounceEffect(label)
    animateNumber(label, newValue)
end)
```

## Shop UI

```lua
-- StarterGui/Shop/ShopUI.client.lua
--!strict
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = script.Parent
local shopFrame = gui:WaitForChild("ShopFrame") :: Frame
local tabContainer = shopFrame:WaitForChild("Tabs") :: Frame
local contentContainer = shopFrame:WaitForChild("Content") :: Frame
local closeButton = shopFrame:WaitForChild("CloseButton") :: TextButton

local isOpen = false

-- Tab data
local TABS = {
    { name = "Currency", icon = "rbxassetid://123456" },
    { name = "GamePasses", icon = "rbxassetid://123457" },
    { name = "Boosts", icon = "rbxassetid://123458" },
    { name = "Crates", icon = "rbxassetid://123459" },
}

local currentTab = "Currency"

-- Open/close animations
local function openShop()
    if isOpen then return end
    isOpen = true
    
    shopFrame.Visible = true
    shopFrame.Position = UDim2.new(0.5, 0, 1.5, 0)
    
    TweenService:Create(shopFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Position = UDim2.new(0.5, 0, 0.5, 0)
    }):Play()
end

local function closeShop()
    if not isOpen then return end
    
    local tween = TweenService:Create(shopFrame, TweenInfo.new(0.2), {
        Position = UDim2.new(0.5, 0, 1.5, 0)
    })
    tween:Play()
    tween.Completed:Connect(function()
        isOpen = false
        shopFrame.Visible = false
    end)
end

closeButton.MouseButton1Click:Connect(closeShop)

-- Tab switching
local function switchTab(tabName: string)
    currentTab = tabName
    
    -- Update tab visuals
    for _, tab in tabContainer:GetChildren() do
        if tab:IsA("TextButton") then
            tab.BackgroundColor3 = tab.Name == tabName 
                and Color3.fromRGB(80, 80, 80) 
                or Color3.fromRGB(50, 50, 50)
        end
    end
    
    -- Load tab content
    loadTabContent(tabName)
end

local function loadTabContent(tabName: string)
    -- Clear existing
    for _, child in contentContainer:GetChildren() do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Populate based on tab
    if tabName == "Currency" then
        loadCurrencyProducts()
    elseif tabName == "GamePasses" then
        loadGamePasses()
    elseif tabName == "Boosts" then
        loadBoosts()
    elseif tabName == "Crates" then
        loadCrates()
    end
end
```

## Notification System

```lua
-- StarterGui/Notifications/NotificationController.client.lua
--!strict
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gui = script.Parent
local container = gui:WaitForChild("NotificationContainer") :: Frame
local template = container:WaitForChild("Template") :: Frame

template.Visible = false

local NotificationController = {}

local queue: {{text: string, type: string, duration: number}} = {}
local isShowing = false

local COLORS = {
    Success = Color3.fromRGB(50, 200, 50),
    Error = Color3.fromRGB(200, 50, 50),
    Warning = Color3.fromRGB(200, 150, 50),
    Info = Color3.fromRGB(50, 150, 200),
    Reward = Color3.fromRGB(200, 150, 50),
}

local function showNotification(text: string, notifType: string, duration: number)
    local notif = template:Clone()
    notif.Name = "Notification"
    notif.Visible = true
    notif.BackgroundColor3 = COLORS[notifType] or COLORS.Info
    
    local textLabel = notif:FindFirstChild("Text") :: TextLabel
    textLabel.Text = text
    
    -- Start off-screen
    notif.Position = UDim2.new(0.5, 0, 0, -50)
    notif.Parent = container
    
    -- Slide in
    TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Position = UDim2.new(0.5, 0, 0, 10)
    }):Play()
    
    -- Wait then slide out
    task.delay(duration, function()
        local slideOut = TweenService:Create(notif, TweenInfo.new(0.2), {
            Position = UDim2.new(0.5, 0, 0, -50)
        })
        slideOut:Play()
        slideOut.Completed:Connect(function()
            notif:Destroy()
        end)
    end)
end

function NotificationController.Show(text: string, notifType: string?, duration: number?)
    table.insert(queue, {
        text = text,
        type = notifType or "Info",
        duration = duration or 3,
    })
    
    if not isShowing then
        processQueue()
    end
end

local function processQueue()
    if #queue == 0 then
        isShowing = false
        return
    end
    
    isShowing = true
    local notif = table.remove(queue, 1)
    showNotification(notif.text, notif.type, notif.duration)
    
    task.delay(notif.duration + 0.5, processQueue)
end

-- Listen for server notifications
local ShowNotification = ReplicatedStorage.Remotes.Events.ShowNotification :: RemoteEvent
ShowNotification.OnClientEvent:Connect(function(text, notifType, duration)
    NotificationController.Show(text, notifType, duration)
end)

return NotificationController
```

## Popup/Modal System

```lua
-- StarterGui/Modals/ModalController.client.lua
--!strict
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local gui = script.Parent
local modalFrame = gui:WaitForChild("ModalFrame") :: Frame
local backdrop = gui:WaitForChild("Backdrop") :: Frame
local contentFrame = modalFrame:WaitForChild("Content") :: Frame
local titleLabel = modalFrame:WaitForChild("Title") :: TextLabel
local closeButton = modalFrame:WaitForChild("CloseButton") :: TextButton

local ModalController = {}
local isOpen = false

local function openModal()
    if isOpen then return end
    isOpen = true
    
    backdrop.Visible = true
    modalFrame.Visible = true
    
    backdrop.BackgroundTransparency = 1
    modalFrame.Size = UDim2.new(0, 0, 0, 0)
    
    TweenService:Create(backdrop, TweenInfo.new(0.2), {
        BackgroundTransparency = 0.5
    }):Play()
    
    TweenService:Create(modalFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 400, 0, 300)
    }):Play()
end

local function closeModal()
    if not isOpen then return end
    
    TweenService:Create(backdrop, TweenInfo.new(0.2), {
        BackgroundTransparency = 1
    }):Play()
    
    local tween = TweenService:Create(modalFrame, TweenInfo.new(0.2), {
        Size = UDim2.new(0, 0, 0, 0)
    })
    tween:Play()
    tween.Completed:Connect(function()
        isOpen = false
        backdrop.Visible = false
        modalFrame.Visible = false
    end)
end

function ModalController.Show(title: string, content: GuiObject)
    -- Clear old content
    for _, child in contentFrame:GetChildren() do
        child:Destroy()
    end
    
    titleLabel.Text = title
    content.Parent = contentFrame
    openModal()
end

function ModalController.Confirm(title: string, message: string, onConfirm: () -> (), onCancel: (() -> ())?)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, 0, 0.6, 0)
    messageLabel.Text = message
    messageLabel.TextWrapped = true
    messageLabel.BackgroundTransparency = 1
    messageLabel.Parent = frame
    
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(1, 0, 0.4, 0)
    buttonFrame.Position = UDim2.new(0, 0, 0.6, 0)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.Parent = frame
    
    local confirmBtn = Instance.new("TextButton")
    confirmBtn.Size = UDim2.new(0.4, 0, 0.6, 0)
    confirmBtn.Position = UDim2.new(0.05, 0, 0.2, 0)
    confirmBtn.Text = "Confirm"
    confirmBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    confirmBtn.Parent = buttonFrame
    
    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0.4, 0, 0.6, 0)
    cancelBtn.Position = UDim2.new(0.55, 0, 0.2, 0)
    cancelBtn.Text = "Cancel"
    cancelBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    cancelBtn.Parent = buttonFrame
    
    confirmBtn.MouseButton1Click:Connect(function()
        closeModal()
        onConfirm()
    end)
    
    cancelBtn.MouseButton1Click:Connect(function()
        closeModal()
        if onCancel then onCancel() end
    end)
    
    ModalController.Show(title, frame)
end

closeButton.MouseButton1Click:Connect(closeModal)
backdrop.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        closeModal()
    end
end)

return ModalController
```

## Mobile Controls

```lua
-- StarterGui/MobileControls/MobileController.client.lua
--!strict
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local gui = script.Parent
local controlsFrame = gui:WaitForChild("MobileControls") :: Frame

-- Only show on mobile
if not UserInputService.TouchEnabled then
    controlsFrame.Visible = false
    return
end

local jumpButton = controlsFrame:WaitForChild("JumpButton") :: ImageButton
local attackButton = controlsFrame:WaitForChild("AttackButton") :: ImageButton
local sprintButton = controlsFrame:WaitForChild("SprintButton") :: ImageButton

-- Jump
jumpButton.MouseButton1Down:Connect(function()
    local character = player.Character
    local humanoid = character and character:FindFirstChild("Humanoid") :: Humanoid?
    if humanoid then
        humanoid.Jump = true
    end
end)

-- Attack (fire remote)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AttackRemote = ReplicatedStorage.Remotes.Events.Attack :: RemoteEvent

attackButton.MouseButton1Click:Connect(function()
    AttackRemote:FireServer()
end)

-- Sprint (hold)
local isSprinting = false

sprintButton.MouseButton1Down:Connect(function()
    isSprinting = true
    local character = player.Character
    local humanoid = character and character:FindFirstChild("Humanoid") :: Humanoid?
    if humanoid then
        humanoid.WalkSpeed = 24
    end
end)

sprintButton.MouseButton1Up:Connect(function()
    isSprinting = false
    local character = player.Character
    local humanoid = character and character:FindFirstChild("Humanoid") :: Humanoid?
    if humanoid then
        humanoid.WalkSpeed = 16
    end
end)
```

## Loading Screen

```lua
-- ReplicatedFirst/LoadingScreen.client.lua
--!strict
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create loading screen
local loadingGui = Instance.new("ScreenGui")
loadingGui.Name = "LoadingScreen"
loadingGui.IgnoreGuiInset = true
loadingGui.ResetOnSpawn = false
loadingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local background = Instance.new("Frame")
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
background.Parent = loadingGui

local logo = Instance.new("ImageLabel")
logo.Size = UDim2.new(0, 200, 0, 200)
logo.Position = UDim2.new(0.5, -100, 0.4, -100)
logo.Image = "rbxassetid://YOUR_LOGO_ID"
logo.BackgroundTransparency = 1
logo.Parent = background

local loadingText = Instance.new("TextLabel")
loadingText.Size = UDim2.new(0.5, 0, 0, 30)
loadingText.Position = UDim2.new(0.25, 0, 0.65, 0)
loadingText.Text = "Loading..."
loadingText.TextColor3 = Color3.new(1, 1, 1)
loadingText.BackgroundTransparency = 1
loadingText.Parent = background

local progressBar = Instance.new("Frame")
progressBar.Size = UDim2.new(0.5, 0, 0, 10)
progressBar.Position = UDim2.new(0.25, 0, 0.7, 0)
progressBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
progressBar.Parent = background

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
progressFill.Parent = progressBar

loadingGui.Parent = playerGui

-- Hide default loading
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- Preload assets
local assetsToLoad = {}

-- Add your critical assets here
-- table.insert(assetsToLoad, game.Workspace.Map)

local loaded = 0
local total = math.max(#assetsToLoad, 1)

for _, asset in assetsToLoad do
    ContentProvider:PreloadAsync({asset}, function()
        loaded += 1
        local progress = loaded / total
        TweenService:Create(progressFill, TweenInfo.new(0.2), {
            Size = UDim2.new(progress, 0, 1, 0)
        }):Play()
        loadingText.Text = string.format("Loading... %d%%", math.floor(progress * 100))
    end)
end

-- Wait for character
if not player.Character then
    player.CharacterAdded:Wait()
end

-- Fade out
loadingText.Text = "Ready!"
task.wait(0.5)

TweenService:Create(background, TweenInfo.new(0.5), {
    BackgroundTransparency = 1
}):Play()

TweenService:Create(logo, TweenInfo.new(0.5), {
    ImageTransparency = 1
}):Play()

task.wait(0.5)
loadingGui:Destroy()
```
