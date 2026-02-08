--!strict
--[[
    XPBar.lua
    XP progress bar UI component
    Shows current level, XP progress, and XP gains
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))

export type XPBarObject = {
    frame: Frame,
    destroy: (self: XPBarObject) -> (),
    update: (self: XPBarObject, level: number, xp: number, progress: number) -> (),
    showXPGain: (self: XPBarObject, amount: number, reason: string) -> (),
    setVisible: (self: XPBarObject, visible: boolean) -> (),
}

local XPBar = {}
XPBar.__index = XPBar

-- XP gain reason display names
local REASON_NAMES = {
    freeze = "+%d XP (Freeze)",
    rescue = "+%d XP (Rescue)",
    survive = "+%d XP (Survived)",
    win_seeker = "+%d XP (Victory)",
    win_runner = "+%d XP (Victory)",
    participate = "+%d XP (Participated)",
}

--[[
    Create a new XP bar
    @param parent - The parent ScreenGui
    @return XPBarObject
]]
function XPBar.new(parent: ScreenGui): XPBarObject
    local self = setmetatable({}, XPBar)

    -- Main container (bottom center of screen)
    self.frame = Instance.new("Frame")
    self.frame.Name = "XPBar"
    self.frame.Size = UDim2.new(0, 300, 0, 50)
    self.frame.Position = UDim2.new(0.5, -150, 1, -70)
    self.frame.BackgroundTransparency = 1
    self.frame.Visible = true
    self.frame.Parent = parent

    -- Background bar
    local bgBar = Instance.new("Frame")
    bgBar.Name = "Background"
    bgBar.Size = UDim2.new(1, 0, 0, 8)
    bgBar.Position = UDim2.new(0, 0, 0.5, 10)
    bgBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    bgBar.BorderSizePixel = 0
    bgBar.Parent = self.frame

    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 4)
    bgCorner.Parent = bgBar

    -- Progress fill bar
    self._progressBar = Instance.new("Frame")
    self._progressBar.Name = "Progress"
    self._progressBar.Size = UDim2.new(0, 0, 1, 0)
    self._progressBar.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    self._progressBar.BorderSizePixel = 0
    self._progressBar.Parent = bgBar

    local progressCorner = Instance.new("UICorner")
    progressCorner.CornerRadius = UDim.new(0, 4)
    progressCorner.Parent = self._progressBar

    -- Level badge (left side)
    local levelBadge = Instance.new("Frame")
    levelBadge.Name = "LevelBadge"
    levelBadge.Size = UDim2.new(0, 40, 0, 40)
    levelBadge.Position = UDim2.new(0, -50, 0.5, -8)
    levelBadge.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    levelBadge.Parent = self.frame

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0.5, 0)
    badgeCorner.Parent = levelBadge

    local badgeStroke = Instance.new("UIStroke")
    badgeStroke.Color = Color3.fromRGB(100, 200, 255)
    badgeStroke.Thickness = 2
    badgeStroke.Parent = levelBadge

    self._levelLabel = Instance.new("TextLabel")
    self._levelLabel.Name = "Level"
    self._levelLabel.Size = UDim2.new(1, 0, 1, 0)
    self._levelLabel.BackgroundTransparency = 1
    self._levelLabel.Text = "1"
    self._levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    self._levelLabel.TextSize = 18
    self._levelLabel.Font = Enum.Font.GothamBold
    self._levelLabel.Parent = levelBadge

    -- XP text (right side)
    self._xpLabel = Instance.new("TextLabel")
    self._xpLabel.Name = "XPText"
    self._xpLabel.Size = UDim2.new(0, 100, 0, 20)
    self._xpLabel.Position = UDim2.new(1, 10, 0.5, 0)
    self._xpLabel.BackgroundTransparency = 1
    self._xpLabel.Text = "0 / 100"
    self._xpLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    self._xpLabel.TextSize = 12
    self._xpLabel.Font = Enum.Font.Gotham
    self._xpLabel.TextXAlignment = Enum.TextXAlignment.Left
    self._xpLabel.Parent = self.frame

    -- XP gain notification (floats up)
    self._xpGainContainer = Instance.new("Frame")
    self._xpGainContainer.Name = "XPGainContainer"
    self._xpGainContainer.Size = UDim2.new(0, 200, 0, 100)
    self._xpGainContainer.Position = UDim2.new(0.5, -100, 0, -50)
    self._xpGainContainer.BackgroundTransparency = 1
    self._xpGainContainer.Parent = self.frame

    return self :: XPBarObject
end

--[[
    Update the XP bar display
    @param level - Current level
    @param xp - Total XP
    @param progress - Progress to next level (0.0 to 1.0)
]]
function XPBar:update(level: number, xp: number, progress: number)
    -- Update level badge
    self._levelLabel.Text = tostring(level)

    -- Update progress bar with animation
    TweenService:Create(self._progressBar, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Size = UDim2.new(progress, 0, 1, 0),
    }):Play()

    -- Update XP text
    local currentLevelXP = ProgressionConfig.getXPForLevel(level)
    local nextLevelXP = ProgressionConfig.getXPForNextLevel(level)

    if nextLevelXP > 0 then
        local xpIntoLevel = xp - currentLevelXP
        local xpForLevel = nextLevelXP - currentLevelXP
        self._xpLabel.Text = string.format("%d / %d", xpIntoLevel, xpForLevel)
    else
        self._xpLabel.Text = "MAX"
    end

    -- Update progress bar color based on level
    local titleAtLevel = ProgressionConfig.getTitleAtLevel(level)
    if titleAtLevel then
        local color = ProgressionConfig.getTitleColor(titleAtLevel)
        self._progressBar.BackgroundColor3 = color
    end
end

--[[
    Show an XP gain notification
    @param amount - XP amount gained
    @param reason - Reason for the gain
]]
function XPBar:showXPGain(amount: number, reason: string)
    local template = REASON_NAMES[reason] or "+%d XP"
    local text = string.format(template, amount)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 24)
    label.Position = UDim2.new(0, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(100, 255, 150)
    label.TextSize = 16
    label.Font = Enum.Font.GothamBold
    label.TextStrokeTransparency = 0.5
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = self._xpGainContainer

    -- Animate floating up and fading
    local startPos = label.Position
    local endPos = UDim2.new(0, 0, 0, -50)

    TweenService:Create(label, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = endPos,
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }):Play()

    task.delay(1.5, function()
        label:Destroy()
    end)
end

--[[
    Set visibility
    @param visible - Whether to show the bar
]]
function XPBar:setVisible(visible: boolean)
    self.frame.Visible = visible
end

--[[
    Destroy the component
]]
function XPBar:destroy()
    self.frame:Destroy()
end

return XPBar
