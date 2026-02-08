--!strict
--[[
    LevelUpNotification.lua
    Level up popup notification with optional title unlock display
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))

export type LevelUpNotificationObject = {
    frame: Frame,
    destroy: (self: LevelUpNotificationObject) -> (),
    show: (self: LevelUpNotificationObject, newLevel: number, unlockedTitle: string?) -> (),
    hide: (self: LevelUpNotificationObject) -> (),
}

local LevelUpNotification = {}
LevelUpNotification.__index = LevelUpNotification

--[[
    Create a new level up notification
    @param parent - The parent ScreenGui
    @return LevelUpNotificationObject
]]
function LevelUpNotification.new(parent: ScreenGui): LevelUpNotificationObject
    local self = setmetatable({}, LevelUpNotification)

    -- Main frame (center of screen, initially hidden)
    self.frame = Instance.new("Frame")
    self.frame.Name = "LevelUpNotification"
    self.frame.Size = UDim2.new(0, 350, 0, 200)
    self.frame.Position = UDim2.new(0.5, -175, 0.5, -100)
    self.frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    self.frame.BackgroundTransparency = 0.1
    self.frame.Visible = false
    self.frame.ZIndex = 100
    self.frame.Parent = parent

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 16)
    frameCorner.Parent = self.frame

    -- Glow effect
    local glow = Instance.new("ImageLabel")
    glow.Name = "Glow"
    glow.Size = UDim2.new(1, 100, 1, 100)
    glow.Position = UDim2.new(0.5, 0, 0.5, 0)
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.BackgroundTransparency = 1
    glow.Image = "rbxassetid://5028857084" -- Radial gradient
    glow.ImageColor3 = Color3.fromRGB(100, 200, 255)
    glow.ImageTransparency = 0.7
    glow.ZIndex = 99
    glow.Parent = self.frame

    -- "LEVEL UP!" header
    local header = Instance.new("TextLabel")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 40)
    header.Position = UDim2.new(0, 0, 0, 20)
    header.BackgroundTransparency = 1
    header.Text = "LEVEL UP!"
    header.TextColor3 = Color3.fromRGB(255, 220, 100)
    header.TextSize = 32
    header.Font = Enum.Font.GothamBold
    header.Parent = self.frame

    -- Level number
    self._levelLabel = Instance.new("TextLabel")
    self._levelLabel.Name = "Level"
    self._levelLabel.Size = UDim2.new(1, 0, 0, 60)
    self._levelLabel.Position = UDim2.new(0, 0, 0, 55)
    self._levelLabel.BackgroundTransparency = 1
    self._levelLabel.Text = "LEVEL 1"
    self._levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    self._levelLabel.TextSize = 48
    self._levelLabel.Font = Enum.Font.GothamBlack
    self._levelLabel.Parent = self.frame

    -- Title unlock text
    self._titleLabel = Instance.new("TextLabel")
    self._titleLabel.Name = "Title"
    self._titleLabel.Size = UDim2.new(1, 0, 0, 30)
    self._titleLabel.Position = UDim2.new(0, 0, 0, 120)
    self._titleLabel.BackgroundTransparency = 1
    self._titleLabel.Text = ""
    self._titleLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    self._titleLabel.TextSize = 20
    self._titleLabel.Font = Enum.Font.GothamBold
    self._titleLabel.Visible = false
    self._titleLabel.Parent = self.frame

    -- Subtitle
    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Size = UDim2.new(1, 0, 0, 25)
    subtitle.Position = UDim2.new(0, 0, 1, -35)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Keep playing to unlock more!"
    subtitle.TextColor3 = Color3.fromRGB(150, 150, 150)
    subtitle.TextSize = 14
    subtitle.Font = Enum.Font.Gotham
    subtitle.Parent = self.frame

    self._glow = glow

    return self :: LevelUpNotificationObject
end

--[[
    Show the level up notification
    @param newLevel - The new level reached
    @param unlockedTitle - Optional title that was unlocked
]]
function LevelUpNotification:show(newLevel: number, unlockedTitle: string?)
    -- Update level text
    self._levelLabel.Text = "LEVEL " .. tostring(newLevel)

    -- Handle title unlock
    if unlockedTitle then
        self._titleLabel.Text = "Title Unlocked: " .. unlockedTitle
        self._titleLabel.TextColor3 = ProgressionConfig.getTitleColor(unlockedTitle)
        self._titleLabel.Visible = true

        -- Adjust subtitle position
        self._titleLabel.Position = UDim2.new(0, 0, 0, 120)
    else
        self._titleLabel.Visible = false
    end

    -- Show with animation
    self.frame.Visible = true
    self.frame.BackgroundTransparency = 1
    self.frame.Size = UDim2.new(0, 50, 0, 50)
    self.frame.Position = UDim2.new(0.5, -25, 0.5, -25)

    -- Scale and fade in
    TweenService:Create(self.frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 350, 0, 200),
        Position = UDim2.new(0.5, -175, 0.5, -100),
        BackgroundTransparency = 0.1,
    }):Play()

    -- Animate glow
    self._glow.ImageTransparency = 0.3
    TweenService:Create(self._glow, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        ImageTransparency = 0.7,
        Size = UDim2.new(1, 150, 1, 150),
    }):Play()

    -- Auto-hide after 3 seconds
    task.delay(3, function()
        self:hide()
    end)
end

--[[
    Hide the notification
]]
function LevelUpNotification:hide()
    TweenService:Create(self.frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 250, 0, 150),
    }):Play()

    task.delay(0.3, function()
        self.frame.Visible = false
    end)
end

--[[
    Destroy the component
]]
function LevelUpNotification:destroy()
    self.frame:Destroy()
end

return LevelUpNotification
