--!strict
--[[
    StatsPanel.lua
    Personal stats panel showing player's lifetime statistics
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatsTypes = require(Shared:WaitForChild("StatsTypes"))
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))

export type StatsPanelObject = {
    frame: Frame,
    destroy: (self: StatsPanelObject) -> (),
    update: (self: StatsPanelObject, stats: StatsTypes.PlayerStats, progression: StatsTypes.ProgressionData) -> (),
    setVisible: (self: StatsPanelObject, visible: boolean) -> (),
    toggle: (self: StatsPanelObject) -> (),
}

local StatsPanel = {}
StatsPanel.__index = StatsPanel

--[[
    Create a new stats panel
    @param parent - The parent ScreenGui
    @return StatsPanelObject
]]
function StatsPanel.new(parent: ScreenGui): StatsPanelObject
    local self = setmetatable({}, StatsPanel)

    self._isVisible = false

    -- Main frame (left side, slide in/out)
    self.frame = Instance.new("Frame")
    self.frame.Name = "StatsPanel"
    self.frame.Size = UDim2.new(0, 280, 0, 400)
    self.frame.Position = UDim2.new(0, -300, 0.5, -200)
    self.frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    self.frame.BackgroundTransparency = 0.1
    self.frame.Visible = false
    self.frame.Parent = parent

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 16)
    frameCorner.Parent = self.frame

    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Color3.fromRGB(100, 100, 120)
    frameStroke.Thickness = 2
    frameStroke.Parent = self.frame

    -- Header
    local header = Instance.new("TextLabel")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 40)
    header.Position = UDim2.new(0, 0, 0, 10)
    header.BackgroundTransparency = 1
    header.Text = "YOUR STATS"
    header.TextColor3 = Color3.fromRGB(255, 220, 100)
    header.TextSize = 20
    header.Font = Enum.Font.GothamBold
    header.Parent = self.frame

    -- Level and Title section
    local levelSection = Instance.new("Frame")
    levelSection.Name = "LevelSection"
    levelSection.Size = UDim2.new(1, -30, 0, 60)
    levelSection.Position = UDim2.new(0, 15, 0, 50)
    levelSection.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    levelSection.Parent = self.frame

    local levelCorner = Instance.new("UICorner")
    levelCorner.CornerRadius = UDim.new(0, 10)
    levelCorner.Parent = levelSection

    -- Level badge
    self._levelBadge = Instance.new("Frame")
    self._levelBadge.Size = UDim2.new(0, 50, 0, 50)
    self._levelBadge.Position = UDim2.new(0, 5, 0.5, -25)
    self._levelBadge.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    self._levelBadge.Parent = levelSection

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0.5, 0)
    badgeCorner.Parent = self._levelBadge

    self._levelBadgeStroke = Instance.new("UIStroke")
    self._levelBadgeStroke.Color = Color3.fromRGB(100, 200, 255)
    self._levelBadgeStroke.Thickness = 3
    self._levelBadgeStroke.Parent = self._levelBadge

    self._levelLabel = Instance.new("TextLabel")
    self._levelLabel.Size = UDim2.new(1, 0, 1, 0)
    self._levelLabel.BackgroundTransparency = 1
    self._levelLabel.Text = "1"
    self._levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    self._levelLabel.TextSize = 24
    self._levelLabel.Font = Enum.Font.GothamBold
    self._levelLabel.Parent = self._levelBadge

    -- Title display
    self._titleLabel = Instance.new("TextLabel")
    self._titleLabel.Name = "Title"
    self._titleLabel.Size = UDim2.new(1, -70, 0, 25)
    self._titleLabel.Position = UDim2.new(0, 60, 0, 8)
    self._titleLabel.BackgroundTransparency = 1
    self._titleLabel.Text = "Rookie"
    self._titleLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    self._titleLabel.TextSize = 18
    self._titleLabel.Font = Enum.Font.GothamBold
    self._titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    self._titleLabel.Parent = levelSection

    -- XP display
    self._xpLabel = Instance.new("TextLabel")
    self._xpLabel.Name = "XP"
    self._xpLabel.Size = UDim2.new(1, -70, 0, 20)
    self._xpLabel.Position = UDim2.new(0, 60, 0, 33)
    self._xpLabel.BackgroundTransparency = 1
    self._xpLabel.Text = "0 XP"
    self._xpLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
    self._xpLabel.TextSize = 14
    self._xpLabel.Font = Enum.Font.Gotham
    self._xpLabel.TextXAlignment = Enum.TextXAlignment.Left
    self._xpLabel.Parent = levelSection

    -- Stats grid
    local statsGrid = Instance.new("Frame")
    statsGrid.Name = "StatsGrid"
    statsGrid.Size = UDim2.new(1, -30, 0, 220)
    statsGrid.Position = UDim2.new(0, 15, 0, 120)
    statsGrid.BackgroundTransparency = 1
    statsGrid.Parent = self.frame

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.5, -5, 0, 50)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.Parent = statsGrid

    -- Create stat displays
    self._statLabels = {}
    local statConfigs = {
        { key = "freezesMade", label = "Freezes Made", icon = "!" },
        { key = "rescues", label = "Rescues", icon = "+" },
        { key = "gamesPlayed", label = "Games Played", icon = "#" },
        { key = "wins", label = "Total Wins", icon = "*" },
        { key = "seekerWins", label = "Seeker Wins", icon = "S" },
        { key = "runnerWins", label = "Runner Wins", icon = "R" },
        { key = "timesFrozen", label = "Times Frozen", icon = "?" },
        { key = "timeSurvived", label = "Time Survived", icon = "@", format = "time" },
    }

    for _, config in statConfigs do
        local statFrame = self:_createStatFrame(config)
        statFrame.Parent = statsGrid
        self._statLabels[config.key] = {
            value = statFrame:FindFirstChild("Value") :: TextLabel,
            format = config.format,
        }
    end

    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "Close"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 16
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = self.frame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeButton

    closeButton.MouseButton1Click:Connect(function()
        self:setVisible(false)
    end)

    return self :: StatsPanelObject
end

--[[
    Create a stat display frame
]]
function StatsPanel:_createStatFrame(config: { key: string, label: string, icon: string, format: string? }): Frame
    local frame = Instance.new("Frame")
    frame.Name = config.key
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    -- Icon
    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 20, 0, 20)
    icon.Position = UDim2.new(0, 5, 0, 5)
    icon.BackgroundTransparency = 1
    icon.Text = config.icon
    icon.TextColor3 = Color3.fromRGB(150, 150, 180)
    icon.TextSize = 14
    icon.Font = Enum.Font.GothamBold
    icon.Parent = frame

    -- Value
    local value = Instance.new("TextLabel")
    value.Name = "Value"
    value.Size = UDim2.new(1, -30, 0, 22)
    value.Position = UDim2.new(0, 25, 0, 3)
    value.BackgroundTransparency = 1
    value.Text = "0"
    value.TextColor3 = Color3.fromRGB(255, 255, 255)
    value.TextSize = 16
    value.Font = Enum.Font.GothamBold
    value.TextXAlignment = Enum.TextXAlignment.Left
    value.Parent = frame

    -- Label
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, -10, 0, 18)
    label.Position = UDim2.new(0, 5, 0, 28)
    label.BackgroundTransparency = 1
    label.Text = config.label
    label.TextColor3 = Color3.fromRGB(120, 120, 140)
    label.TextSize = 10
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Parent = frame

    return frame
end

--[[
    Format a stat value
]]
function StatsPanel:_formatValue(value: number, format: string?): string
    if format == "time" then
        local hours = math.floor(value / 3600)
        local minutes = math.floor((value % 3600) / 60)
        local seconds = math.floor(value % 60)

        if hours > 0 then
            return string.format("%dh %dm", hours, minutes)
        elseif minutes > 0 then
            return string.format("%dm %ds", minutes, seconds)
        else
            return string.format("%ds", seconds)
        end
    else
        -- Format as number with commas
        local formatted = tostring(math.floor(value))
        local k
        while true do
            formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
            if k == 0 then break end
        end
        return formatted
    end
end

--[[
    Update the stats panel with new data
    @param stats - The player's stats
    @param progression - The player's progression data
]]
function StatsPanel:update(stats: StatsTypes.PlayerStats, progression: StatsTypes.ProgressionData)
    -- Update level
    self._levelLabel.Text = tostring(progression.level)

    -- Update title with color
    self._titleLabel.Text = progression.selectedTitle
    local titleColor = ProgressionConfig.getTitleColor(progression.selectedTitle)
    self._titleLabel.TextColor3 = titleColor
    self._levelBadgeStroke.Color = titleColor

    -- Update XP
    self._xpLabel.Text = string.format("%s XP", self:_formatValue(progression.xp))

    -- Update stats
    for key, labelData in self._statLabels do
        local value = stats[key]
        if value ~= nil then
            labelData.value.Text = self:_formatValue(value, labelData.format)
        end
    end
end

--[[
    Set visibility with slide animation
    @param visible - Whether to show the panel
]]
function StatsPanel:setVisible(visible: boolean)
    self._isVisible = visible

    if visible then
        self.frame.Visible = true
        TweenService:Create(self.frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 20, 0.5, -200),
        }):Play()
    else
        TweenService:Create(self.frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0, -300, 0.5, -200),
        }):Play()
        task.delay(0.2, function()
            if not self._isVisible then
                self.frame.Visible = false
            end
        end)
    end
end

--[[
    Toggle visibility
]]
function StatsPanel:toggle()
    self:setVisible(not self._isVisible)
end

--[[
    Destroy the component
]]
function StatsPanel:destroy()
    self.frame:Destroy()
end

return StatsPanel
