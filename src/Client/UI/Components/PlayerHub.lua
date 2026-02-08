--!strict
--[[
    PlayerHub.lua
    Main player hub panel - toggleable side panel for player info and queue controls

    Tabs:
    - Play: Queue controls, status, quick stats
    - Stats: Detailed lifetime statistics
    - Progression: Level, titles, XP progress
    - Inventory: Placeholder for future content
    - Achievements: Placeholder for future content
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Constants = require(Shared:WaitForChild("Constants"))
local StatsTypes = require(Shared:WaitForChild("StatsTypes"))
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))

local LocalPlayer = Players.LocalPlayer

export type PlayerHubObject = {
    frame: Frame,
    toggleButton: TextButton,
    show: (self: PlayerHubObject) -> (),
    hide: (self: PlayerHubObject) -> (),
    toggle: (self: PlayerHubObject) -> (),
    isVisible: (self: PlayerHubObject) -> boolean,
    showInstant: (self: PlayerHubObject) -> (),
    isPlayMode: (self: PlayerHubObject) -> boolean,
    setPlayMode: (self: PlayerHubObject, isPlayMode: boolean) -> (),
    updateStats: (self: PlayerHubObject, stats: StatsTypes.PlayerStats, progression: StatsTypes.ProgressionData) -> (),
    updateQueueState: (self: PlayerHubObject, state: string, count: number) -> (),
    setLeaveGameCallback: (self: PlayerHubObject, callback: () -> ()) -> (),
    destroy: (self: PlayerHubObject) -> (),
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
    Seeker = Color3.fromRGB(255, 130, 85),
    Runner = Color3.fromRGB(85, 170, 255),
    Radius = UDim.new(0, 10),
    RadiusSmall = UDim.new(0, 6),
    Bold = Enum.Font.GothamBold,
    Medium = Enum.Font.GothamMedium,
    Regular = Enum.Font.Gotham,
    Fast = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Normal = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Slide = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

local PANEL_WIDTH = 320
local PANEL_HEIGHT_PERCENT = 0.85

local PlayerHub = {}
PlayerHub.__index = PlayerHub

--[[
    Create a new PlayerHub
    @param parent - The parent ScreenGui
    @return PlayerHubObject
]]
function PlayerHub.new(parent: ScreenGui): PlayerHubObject
    local self = setmetatable({}, PlayerHub)

    self._isVisible = false
    self._currentTab = "Play"
    self._queueState = Enums.QueueState.NotQueued
    self._queuedCount = 0
    self._leaveGameCallback = nil :: (() -> ())?
    self._connections = {} :: { RBXScriptConnection }
    self._isPlayMode = false -- false = Lobby mode, true = Play mode

    -- Toggle button (always visible)
    self.toggleButton = Instance.new("TextButton")
    self.toggleButton.Name = "PlayerHubToggle"
    self.toggleButton.Size = UDim2.new(0, 50, 0, 50)
    self.toggleButton.Position = UDim2.new(0, 15, 0.5, -25)
    self.toggleButton.BackgroundColor3 = Theme.Background
    self.toggleButton.Text = ">"
    self.toggleButton.TextColor3 = Theme.Text
    self.toggleButton.TextSize = 24
    self.toggleButton.Font = Theme.Bold
    self.toggleButton.ZIndex = 50
    self.toggleButton.Parent = parent

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = Theme.Radius
    toggleCorner.Parent = self.toggleButton

    local toggleStroke = Instance.new("UIStroke")
    toggleStroke.Color = Theme.SurfaceLight
    toggleStroke.Thickness = 2
    toggleStroke.Parent = self.toggleButton

    self.toggleButton.MouseEnter:Connect(function()
        TweenService:Create(self.toggleButton, Theme.Fast, { BackgroundColor3 = Theme.Surface }):Play()
    end)
    self.toggleButton.MouseLeave:Connect(function()
        TweenService:Create(self.toggleButton, Theme.Fast, { BackgroundColor3 = Theme.Background }):Play()
    end)
    self.toggleButton.MouseButton1Click:Connect(function()
        self:toggle()
    end)

    -- Main panel frame
    self.frame = Instance.new("Frame")
    self.frame.Name = "PlayerHub"
    self.frame.Size = UDim2.new(0, PANEL_WIDTH, PANEL_HEIGHT_PERCENT, 0)
    self.frame.Position = UDim2.new(0, -PANEL_WIDTH - 20, 0.5, 0)
    self.frame.AnchorPoint = Vector2.new(0, 0.5)
    self.frame.BackgroundColor3 = Theme.Background
    self.frame.Visible = false
    self.frame.ZIndex = 40
    self.frame.Parent = parent

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = Theme.Radius
    frameCorner.Parent = self.frame

    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Theme.SurfaceLight
    frameStroke.Thickness = 2
    frameStroke.Parent = self.frame

    -- Create sections
    self:_createHeader()
    self:_createTabs()
    self:_createTabContent()

    return self :: PlayerHubObject
end

--[[
    Create player info header
]]
function PlayerHub:_createHeader()
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, -20, 0, 70)
    header.Position = UDim2.new(0, 10, 0, 10)
    header.BackgroundColor3 = Theme.Surface
    header.ZIndex = 41
    header.Parent = self.frame

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = Theme.Radius
    headerCorner.Parent = header

    -- Avatar placeholder (simple circle)
    local avatar = Instance.new("Frame")
    avatar.Name = "Avatar"
    avatar.Size = UDim2.new(0, 50, 0, 50)
    avatar.Position = UDim2.new(0, 10, 0.5, -25)
    avatar.BackgroundColor3 = Theme.SurfaceLight
    avatar.ZIndex = 42
    avatar.Parent = header

    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(0.5, 0)
    avatarCorner.Parent = avatar

    -- Player avatar image
    local avatarImage = Instance.new("ImageLabel")
    avatarImage.Name = "AvatarImage"
    avatarImage.Size = UDim2.new(1, 0, 1, 0)
    avatarImage.BackgroundTransparency = 1
    avatarImage.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
    avatarImage.ZIndex = 43
    avatarImage.Parent = avatar

    local avatarImageCorner = Instance.new("UICorner")
    avatarImageCorner.CornerRadius = UDim.new(0.5, 0)
    avatarImageCorner.Parent = avatarImage

    -- Player name
    local playerName = Instance.new("TextLabel")
    playerName.Name = "PlayerName"
    playerName.Size = UDim2.new(1, -80, 0, 22)
    playerName.Position = UDim2.new(0, 70, 0, 12)
    playerName.BackgroundTransparency = 1
    playerName.Text = LocalPlayer.DisplayName
    playerName.TextColor3 = Theme.Text
    playerName.TextSize = 16
    playerName.Font = Theme.Bold
    playerName.TextXAlignment = Enum.TextXAlignment.Left
    playerName.TextTruncate = Enum.TextTruncate.AtEnd
    playerName.ZIndex = 42
    playerName.Parent = header

    -- Level and title
    self._headerLevel = Instance.new("TextLabel")
    self._headerLevel.Name = "Level"
    self._headerLevel.Size = UDim2.new(0, 35, 0, 18)
    self._headerLevel.Position = UDim2.new(0, 70, 0, 36)
    self._headerLevel.BackgroundColor3 = Theme.Accent
    self._headerLevel.Text = "Lv.1"
    self._headerLevel.TextColor3 = Theme.Text
    self._headerLevel.TextSize = 11
    self._headerLevel.Font = Theme.Bold
    self._headerLevel.ZIndex = 42
    self._headerLevel.Parent = header

    local levelCorner = Instance.new("UICorner")
    levelCorner.CornerRadius = UDim.new(0, 4)
    levelCorner.Parent = self._headerLevel

    self._headerTitle = Instance.new("TextLabel")
    self._headerTitle.Name = "Title"
    self._headerTitle.Size = UDim2.new(1, -115, 0, 18)
    self._headerTitle.Position = UDim2.new(0, 110, 0, 36)
    self._headerTitle.BackgroundTransparency = 1
    self._headerTitle.Text = "Rookie"
    self._headerTitle.TextColor3 = Theme.TextSecondary
    self._headerTitle.TextSize = 12
    self._headerTitle.Font = Theme.Medium
    self._headerTitle.TextXAlignment = Enum.TextXAlignment.Left
    self._headerTitle.ZIndex = 42
    self._headerTitle.Parent = header

    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "Close"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -38, 0, 5)
    closeButton.BackgroundTransparency = 1
    closeButton.Text = "X"
    closeButton.TextColor3 = Theme.TextMuted
    closeButton.TextSize = 18
    closeButton.Font = Theme.Bold
    closeButton.ZIndex = 42
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
    Create navigation tabs
]]
function PlayerHub:_createTabs()
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(1, -20, 0, 40)
    tabContainer.Position = UDim2.new(0, 10, 0, 90)
    tabContainer.BackgroundTransparency = 1
    tabContainer.ZIndex = 41
    tabContainer.Parent = self.frame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.Padding = UDim.new(0, 5)
    layout.Parent = tabContainer

    self._tabs = {}
    self._tabButtons = {}

    local tabNames = { "Play", "Stats", "Progression", "More" }

    for _, tabName in tabNames do
        local tab = Instance.new("TextButton")
        tab.Name = tabName
        tab.Size = UDim2.new(0, 70, 1, 0)
        tab.BackgroundColor3 = Theme.Surface
        tab.BackgroundTransparency = 1
        tab.Text = tabName
        tab.TextColor3 = Theme.TextMuted
        tab.TextSize = 12
        tab.Font = Theme.Medium
        tab.ZIndex = 42
        tab.Parent = tabContainer

        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = Theme.RadiusSmall
        tabCorner.Parent = tab

        local underline = Instance.new("Frame")
        underline.Name = "Underline"
        underline.Size = UDim2.new(0.8, 0, 0, 2)
        underline.Position = UDim2.new(0.1, 0, 1, -2)
        underline.BackgroundColor3 = Theme.Accent
        underline.BackgroundTransparency = 1
        underline.ZIndex = 43
        underline.Parent = tab

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

        self._tabButtons[tabName] = { button = tab, underline = underline }
    end

    -- Select default tab
    self:_selectTab("Play")
end

--[[
    Select a tab
]]
function PlayerHub:_selectTab(tabName: string)
    self._currentTab = tabName

    -- Update tab buttons
    for name, tabData in self._tabButtons do
        local isSelected = name == tabName
        tabData.button.TextColor3 = isSelected and Theme.Text or Theme.TextMuted
        tabData.button.BackgroundTransparency = isSelected and 0 or 1
        tabData.underline.BackgroundTransparency = isSelected and 0 or 1
    end

    -- Show/hide tab content
    for name, content in self._tabs do
        content.Visible = name == tabName
    end
end

--[[
    Create tab content areas
]]
function PlayerHub:_createTabContent()
    local contentContainer = Instance.new("Frame")
    contentContainer.Name = "Content"
    contentContainer.Size = UDim2.new(1, -20, 1, -145)
    contentContainer.Position = UDim2.new(0, 10, 0, 135)
    contentContainer.BackgroundTransparency = 1
    contentContainer.ClipsDescendants = true
    contentContainer.ZIndex = 41
    contentContainer.Parent = self.frame

    self:_createPlayTab(contentContainer)
    self:_createStatsTab(contentContainer)
    self:_createProgressionTab(contentContainer)
    self:_createMoreTab(contentContainer)
end

--[[
    Create Play tab content
]]
function PlayerHub:_createPlayTab(parent: Frame)
    local playTab = Instance.new("Frame")
    playTab.Name = "Play"
    playTab.Size = UDim2.new(1, 0, 1, 0)
    playTab.BackgroundTransparency = 1
    playTab.Visible = true
    playTab.ZIndex = 42
    playTab.Parent = parent

    self._tabs["Play"] = playTab

    -- Mode toggle (Lobby / Play)
    local toggleContainer = Instance.new("Frame")
    toggleContainer.Name = "ModeToggle"
    toggleContainer.Size = UDim2.new(1, 0, 0, 45)
    toggleContainer.Position = UDim2.new(0, 0, 0, 5)
    toggleContainer.BackgroundColor3 = Theme.Surface
    toggleContainer.ZIndex = 43
    toggleContainer.Parent = playTab

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = Theme.Radius
    toggleCorner.Parent = toggleContainer

    -- Lobby button (left)
    self._lobbyModeButton = Instance.new("TextButton")
    self._lobbyModeButton.Name = "LobbyMode"
    self._lobbyModeButton.Size = UDim2.new(0.5, -2, 1, -6)
    self._lobbyModeButton.Position = UDim2.new(0, 3, 0, 3)
    self._lobbyModeButton.BackgroundColor3 = Theme.Accent
    self._lobbyModeButton.Text = "LOBBY"
    self._lobbyModeButton.TextColor3 = Theme.Text
    self._lobbyModeButton.TextSize = 14
    self._lobbyModeButton.Font = Theme.Bold
    self._lobbyModeButton.ZIndex = 44
    self._lobbyModeButton.Parent = toggleContainer

    local lobbyCorner = Instance.new("UICorner")
    lobbyCorner.CornerRadius = UDim.new(0, 8)
    lobbyCorner.Parent = self._lobbyModeButton

    self._lobbyModeButton.MouseButton1Click:Connect(function()
        self:_setPlayMode(false)
    end)

    -- Play button (right)
    self._playModeButton = Instance.new("TextButton")
    self._playModeButton.Name = "PlayMode"
    self._playModeButton.Size = UDim2.new(0.5, -2, 1, -6)
    self._playModeButton.Position = UDim2.new(0.5, -1, 0, 3)
    self._playModeButton.BackgroundColor3 = Theme.SurfaceLight
    self._playModeButton.BackgroundTransparency = 0.5
    self._playModeButton.Text = "PLAY"
    self._playModeButton.TextColor3 = Theme.TextMuted
    self._playModeButton.TextSize = 14
    self._playModeButton.Font = Theme.Bold
    self._playModeButton.ZIndex = 44
    self._playModeButton.Parent = toggleContainer

    local playModeCorner = Instance.new("UICorner")
    playModeCorner.CornerRadius = UDim.new(0, 8)
    playModeCorner.Parent = self._playModeButton

    self._playModeButton.MouseButton1Click:Connect(function()
        self:_setPlayMode(true)
    end)

    -- Lobby mode content container
    self._lobbyContent = Instance.new("Frame")
    self._lobbyContent.Name = "LobbyContent"
    self._lobbyContent.Size = UDim2.new(1, 0, 1, -60)
    self._lobbyContent.Position = UDim2.new(0, 0, 0, 55)
    self._lobbyContent.BackgroundTransparency = 1
    self._lobbyContent.Visible = true
    self._lobbyContent.ZIndex = 43
    self._lobbyContent.Parent = playTab

    -- Welcome text for lobby
    local welcomeText = Instance.new("TextLabel")
    welcomeText.Name = "Welcome"
    welcomeText.Size = UDim2.new(1, 0, 0, 30)
    welcomeText.Position = UDim2.new(0, 0, 0, 10)
    welcomeText.BackgroundTransparency = 1
    welcomeText.Text = "Welcome to Scorch!"
    welcomeText.TextColor3 = Theme.Text
    welcomeText.TextSize = 18
    welcomeText.Font = Theme.Bold
    welcomeText.ZIndex = 44
    welcomeText.Parent = self._lobbyContent

    local browseText = Instance.new("TextLabel")
    browseText.Name = "BrowseText"
    browseText.Size = UDim2.new(1, 0, 0, 45)
    browseText.Position = UDim2.new(0, 0, 0, 40)
    browseText.BackgroundTransparency = 1
    browseText.Text = "Browse the lobby, check your stats, or switch to Play mode to join a game."
    browseText.TextColor3 = Theme.TextSecondary
    browseText.TextSize = 13
    browseText.Font = Theme.Regular
    browseText.TextWrapped = true
    browseText.ZIndex = 44
    browseText.Parent = self._lobbyContent

    -- Quick stats section (lobby mode)
    local lobbyQuickStatsTitle = Instance.new("TextLabel")
    lobbyQuickStatsTitle.Name = "QuickStatsTitle"
    lobbyQuickStatsTitle.Size = UDim2.new(1, 0, 0, 25)
    lobbyQuickStatsTitle.Position = UDim2.new(0, 0, 0, 100)
    lobbyQuickStatsTitle.BackgroundTransparency = 1
    lobbyQuickStatsTitle.Text = "Your Stats"
    lobbyQuickStatsTitle.TextColor3 = Theme.TextMuted
    lobbyQuickStatsTitle.TextSize = 12
    lobbyQuickStatsTitle.Font = Theme.Medium
    lobbyQuickStatsTitle.TextXAlignment = Enum.TextXAlignment.Left
    lobbyQuickStatsTitle.ZIndex = 44
    lobbyQuickStatsTitle.Parent = self._lobbyContent

    local lobbyQuickStats = Instance.new("Frame")
    lobbyQuickStats.Name = "QuickStats"
    lobbyQuickStats.Size = UDim2.new(1, 0, 0, 70)
    lobbyQuickStats.Position = UDim2.new(0, 0, 0, 125)
    lobbyQuickStats.BackgroundColor3 = Theme.Surface
    lobbyQuickStats.ZIndex = 44
    lobbyQuickStats.Parent = self._lobbyContent

    local lobbyQuickStatsCorner = Instance.new("UICorner")
    lobbyQuickStatsCorner.CornerRadius = Theme.Radius
    lobbyQuickStatsCorner.Parent = lobbyQuickStats

    -- Create lobby quick stat items
    self._lobbyStatLabels = {}
    local lobbyStatConfigs = {
        { key = "wins", label = "Wins", x = 0 },
        { key = "winRate", label = "Win Rate", x = 0.33 },
        { key = "gamesPlayed", label = "Games", x = 0.66 },
    }

    for _, config in lobbyStatConfigs do
        local statItem = Instance.new("Frame")
        statItem.Size = UDim2.new(0.33, 0, 1, 0)
        statItem.Position = UDim2.new(config.x, 0, 0, 0)
        statItem.BackgroundTransparency = 1
        statItem.ZIndex = 45
        statItem.Parent = lobbyQuickStats

        local value = Instance.new("TextLabel")
        value.Name = "Value"
        value.Size = UDim2.new(1, 0, 0, 30)
        value.Position = UDim2.new(0, 0, 0, 10)
        value.BackgroundTransparency = 1
        value.Text = "0"
        value.TextColor3 = Theme.Text
        value.TextSize = 20
        value.Font = Theme.Bold
        value.ZIndex = 46
        value.Parent = statItem

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 20)
        label.Position = UDim2.new(0, 0, 0, 40)
        label.BackgroundTransparency = 1
        label.Text = config.label
        label.TextColor3 = Theme.TextMuted
        label.TextSize = 11
        label.Font = Theme.Regular
        label.ZIndex = 46
        label.Parent = statItem

        self._lobbyStatLabels[config.key] = value
    end

    -- Play mode content container
    self._playContent = Instance.new("Frame")
    self._playContent.Name = "PlayContent"
    self._playContent.Size = UDim2.new(1, 0, 1, -60)
    self._playContent.Position = UDim2.new(0, 0, 0, 55)
    self._playContent.BackgroundTransparency = 1
    self._playContent.Visible = false
    self._playContent.ZIndex = 43
    self._playContent.Parent = playTab

    -- Queue status
    self._queueStatus = Instance.new("TextLabel")
    self._queueStatus.Name = "QueueStatus"
    self._queueStatus.Size = UDim2.new(1, 0, 0, 25)
    self._queueStatus.Position = UDim2.new(0, 0, 0, 5)
    self._queueStatus.BackgroundTransparency = 1
    self._queueStatus.Text = "Ready to play!"
    self._queueStatus.TextColor3 = Theme.Success
    self._queueStatus.TextSize = 14
    self._queueStatus.Font = Theme.Medium
    self._queueStatus.ZIndex = 44
    self._queueStatus.Parent = self._playContent

    -- Play button (big green)
    self._playButton = Instance.new("TextButton")
    self._playButton.Name = "PlayButton"
    self._playButton.Size = UDim2.new(1, 0, 0, 70)
    self._playButton.Position = UDim2.new(0, 0, 0, 35)
    self._playButton.BackgroundColor3 = Theme.Success
    self._playButton.Text = "JOIN GAME"
    self._playButton.TextColor3 = Theme.Text
    self._playButton.TextSize = 26
    self._playButton.Font = Theme.Bold
    self._playButton.ZIndex = 44
    self._playButton.Parent = self._playContent

    local playCorner = Instance.new("UICorner")
    playCorner.CornerRadius = Theme.Radius
    playCorner.Parent = self._playButton

    -- Play button glow effect
    local playGlow = Instance.new("UIStroke")
    playGlow.Name = "Glow"
    playGlow.Color = Theme.Success
    playGlow.Thickness = 2
    playGlow.Transparency = 0.5
    playGlow.Parent = self._playButton

    self._playButton.MouseEnter:Connect(function()
        print("[PlayerHub] Mouse entered JOIN GAME button")
        local hoverColor = Color3.fromRGB(100, 240, 140)
        TweenService:Create(self._playButton, Theme.Fast, { BackgroundColor3 = hoverColor }):Play()
        TweenService:Create(playGlow, Theme.Fast, { Transparency = 0 }):Play()
    end)
    self._playButton.MouseLeave:Connect(function()
        print("[PlayerHub] Mouse left JOIN GAME button")
        TweenService:Create(self._playButton, Theme.Fast, { BackgroundColor3 = Theme.Success }):Play()
        TweenService:Create(playGlow, Theme.Fast, { Transparency = 0.5 }):Play()
    end)
    self._playButton.MouseButton1Click:Connect(function()
        print("[PlayerHub] JOIN GAME button MouseButton1Click fired!")
        self:_handlePlayButtonClick()
    end)

    print("[PlayerHub] Play button created and events connected")

    -- Leave queue button (hidden by default)
    self._leaveQueueButton = Instance.new("TextButton")
    self._leaveQueueButton.Name = "LeaveQueueButton"
    self._leaveQueueButton.Size = UDim2.new(1, 0, 0, 45)
    self._leaveQueueButton.Position = UDim2.new(0, 0, 0, 115)
    self._leaveQueueButton.BackgroundColor3 = Theme.Surface
    self._leaveQueueButton.Text = "Leave Queue"
    self._leaveQueueButton.TextColor3 = Theme.TextSecondary
    self._leaveQueueButton.TextSize = 16
    self._leaveQueueButton.Font = Theme.Medium
    self._leaveQueueButton.Visible = false
    self._leaveQueueButton.ZIndex = 44
    self._leaveQueueButton.Parent = self._playContent

    local leaveQueueCorner = Instance.new("UICorner")
    leaveQueueCorner.CornerRadius = Theme.Radius
    leaveQueueCorner.Parent = self._leaveQueueButton

    local leaveQueueStroke = Instance.new("UIStroke")
    leaveQueueStroke.Color = Theme.SurfaceLight
    leaveQueueStroke.Thickness = 1
    leaveQueueStroke.Parent = self._leaveQueueButton

    self._leaveQueueButton.MouseEnter:Connect(function()
        TweenService:Create(self._leaveQueueButton, Theme.Fast, { BackgroundColor3 = Theme.SurfaceLight }):Play()
    end)
    self._leaveQueueButton.MouseLeave:Connect(function()
        TweenService:Create(self._leaveQueueButton, Theme.Fast, { BackgroundColor3 = Theme.Surface }):Play()
    end)
    self._leaveQueueButton.MouseButton1Click:Connect(function()
        self:_handleLeaveQueueClick()
    end)

    -- Leave game button (hidden by default)
    self._leaveGameButton = Instance.new("TextButton")
    self._leaveGameButton.Name = "LeaveGameButton"
    self._leaveGameButton.Size = UDim2.new(1, 0, 0, 50)
    self._leaveGameButton.Position = UDim2.new(0, 0, 0, 35)
    self._leaveGameButton.BackgroundColor3 = Theme.Danger
    self._leaveGameButton.Text = "LEAVE GAME"
    self._leaveGameButton.TextColor3 = Theme.Text
    self._leaveGameButton.TextSize = 18
    self._leaveGameButton.Font = Theme.Bold
    self._leaveGameButton.Visible = false
    self._leaveGameButton.ZIndex = 44
    self._leaveGameButton.Parent = self._playContent

    local leaveGameCorner = Instance.new("UICorner")
    leaveGameCorner.CornerRadius = Theme.Radius
    leaveGameCorner.Parent = self._leaveGameButton

    self._leaveGameButton.MouseEnter:Connect(function()
        local hoverColor = Color3.fromRGB(255, 120, 120)
        TweenService:Create(self._leaveGameButton, Theme.Fast, { BackgroundColor3 = hoverColor }):Play()
    end)
    self._leaveGameButton.MouseLeave:Connect(function()
        TweenService:Create(self._leaveGameButton, Theme.Fast, { BackgroundColor3 = Theme.Danger }):Play()
    end)
    self._leaveGameButton.MouseButton1Click:Connect(function()
        self:_handleLeaveGameClick()
    end)

    -- Quick stats section (play mode)
    local quickStatsTitle = Instance.new("TextLabel")
    quickStatsTitle.Name = "QuickStatsTitle"
    quickStatsTitle.Size = UDim2.new(1, 0, 0, 25)
    quickStatsTitle.Position = UDim2.new(0, 0, 0, 175)
    quickStatsTitle.BackgroundTransparency = 1
    quickStatsTitle.Text = "Quick Stats"
    quickStatsTitle.TextColor3 = Theme.TextMuted
    quickStatsTitle.TextSize = 12
    quickStatsTitle.Font = Theme.Medium
    quickStatsTitle.TextXAlignment = Enum.TextXAlignment.Left
    quickStatsTitle.ZIndex = 44
    quickStatsTitle.Parent = self._playContent

    local quickStats = Instance.new("Frame")
    quickStats.Name = "QuickStats"
    quickStats.Size = UDim2.new(1, 0, 0, 70)
    quickStats.Position = UDim2.new(0, 0, 0, 200)
    quickStats.BackgroundColor3 = Theme.Surface
    quickStats.ZIndex = 44
    quickStats.Parent = self._playContent

    local quickStatsCorner = Instance.new("UICorner")
    quickStatsCorner.CornerRadius = Theme.Radius
    quickStatsCorner.Parent = quickStats

    -- Create quick stat items
    self._quickStatLabels = {}
    local quickStatConfigs = {
        { key = "wins", label = "Wins", x = 0 },
        { key = "winRate", label = "Win Rate", x = 0.33 },
        { key = "gamesPlayed", label = "Games", x = 0.66 },
    }

    for _, config in quickStatConfigs do
        local statItem = Instance.new("Frame")
        statItem.Size = UDim2.new(0.33, 0, 1, 0)
        statItem.Position = UDim2.new(config.x, 0, 0, 0)
        statItem.BackgroundTransparency = 1
        statItem.ZIndex = 45
        statItem.Parent = quickStats

        local value = Instance.new("TextLabel")
        value.Name = "Value"
        value.Size = UDim2.new(1, 0, 0, 30)
        value.Position = UDim2.new(0, 0, 0, 10)
        value.BackgroundTransparency = 1
        value.Text = "0"
        value.TextColor3 = Theme.Text
        value.TextSize = 20
        value.Font = Theme.Bold
        value.ZIndex = 46
        value.Parent = statItem

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 20)
        label.Position = UDim2.new(0, 0, 0, 40)
        label.BackgroundTransparency = 1
        label.Text = config.label
        label.TextColor3 = Theme.TextMuted
        label.TextSize = 11
        label.Font = Theme.Regular
        label.ZIndex = 46
        label.Parent = statItem

        self._quickStatLabels[config.key] = value
    end
end

--[[
    Set play mode (toggle between Lobby and Play views)
    When switching to Play: automatically join queue
    When switching to Lobby: leave queue/game
]]
function PlayerHub:_setPlayMode(isPlayMode: boolean)
    print("[PlayerHub] _setPlayMode called with:", isPlayMode)
    self._isPlayMode = isPlayMode

    -- Update toggle buttons
    if isPlayMode then
        -- Play mode active
        TweenService:Create(self._playModeButton, Theme.Fast, {
            BackgroundColor3 = Theme.Success,
            BackgroundTransparency = 0,
        }):Play()
        self._playModeButton.TextColor3 = Theme.Text

        TweenService:Create(self._lobbyModeButton, Theme.Fast, {
            BackgroundColor3 = Theme.SurfaceLight,
            BackgroundTransparency = 0.5,
        }):Play()
        self._lobbyModeButton.TextColor3 = Theme.TextMuted

        -- Show play content
        self._lobbyContent.Visible = false
        self._playContent.Visible = true

        -- Automatically join queue when switching to Play mode
        local success, QueueController = pcall(function()
            return Knit.GetController("QueueController")
        end)

        if not success then
            warn("[PlayerHub] Failed to get QueueController:", QueueController)
            return
        end

        local currentState = QueueController:GetQueueState()
        local isNotQueued = QueueController:IsNotQueued()
        print("[PlayerHub] Current queue state:", currentState, "IsNotQueued:", isNotQueued)

        if isNotQueued then
            print("[PlayerHub] Auto-joining queue...")
            local joinSuccess, joinResult = pcall(function()
                return QueueController:JoinQueue()
            end)
            if joinSuccess then
                print("[PlayerHub] JoinQueue returned:", joinResult)
            else
                warn("[PlayerHub] JoinQueue failed:", joinResult)
            end
        else
            print("[PlayerHub] Already queued or in game, skipping join")
        end
    else
        -- Lobby mode active
        TweenService:Create(self._lobbyModeButton, Theme.Fast, {
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 0,
        }):Play()
        self._lobbyModeButton.TextColor3 = Theme.Text

        TweenService:Create(self._playModeButton, Theme.Fast, {
            BackgroundColor3 = Theme.SurfaceLight,
            BackgroundTransparency = 0.5,
        }):Play()
        self._playModeButton.TextColor3 = Theme.TextMuted

        -- Show lobby content
        self._lobbyContent.Visible = true
        self._playContent.Visible = false

        -- Automatically leave queue/game when switching to Lobby mode
        local QueueController = Knit.GetController("QueueController")
        if QueueController:IsQueued() then
            print("[PlayerHub] Auto-leaving queue...")
            QueueController:LeaveQueue()
        elseif QueueController:IsInGame() then
            print("[PlayerHub] Player in game, triggering leave game callback...")
            if self._leaveGameCallback then
                self._leaveGameCallback()
            end
        end
    end
end

--[[
    Create Stats tab content
]]
function PlayerHub:_createStatsTab(parent: Frame)
    local statsTab = Instance.new("ScrollingFrame")
    statsTab.Name = "Stats"
    statsTab.Size = UDim2.new(1, 0, 1, 0)
    statsTab.BackgroundTransparency = 1
    statsTab.Visible = false
    statsTab.ScrollBarThickness = 4
    statsTab.ScrollBarImageColor3 = Theme.SurfaceLight
    statsTab.CanvasSize = UDim2.new(0, 0, 0, 350)
    statsTab.ZIndex = 42
    statsTab.Parent = parent

    self._tabs["Stats"] = statsTab

    -- Stats grid
    self._statLabels = {}
    local statConfigs = {
        { key = "freezesMade", label = "Freezes Made" },
        { key = "rescues", label = "Rescues" },
        { key = "gamesPlayed", label = "Games Played" },
        { key = "wins", label = "Total Wins" },
        { key = "seekerWins", label = "Seeker Wins" },
        { key = "runnerWins", label = "Runner Wins" },
        { key = "timesFrozen", label = "Times Frozen" },
        { key = "timeSurvived", label = "Time Survived", format = "time" },
    }

    for i, config in statConfigs do
        local row = math.floor((i - 1) / 2)
        local col = (i - 1) % 2

        local statFrame = Instance.new("Frame")
        statFrame.Name = config.key
        statFrame.Size = UDim2.new(0.5, -5, 0, 60)
        statFrame.Position = UDim2.new(col * 0.5, col * 5, 0, row * 70 + 10)
        statFrame.BackgroundColor3 = Theme.Surface
        statFrame.ZIndex = 43
        statFrame.Parent = statsTab

        local corner = Instance.new("UICorner")
        corner.CornerRadius = Theme.RadiusSmall
        corner.Parent = statFrame

        local value = Instance.new("TextLabel")
        value.Name = "Value"
        value.Size = UDim2.new(1, -10, 0, 28)
        value.Position = UDim2.new(0, 5, 0, 8)
        value.BackgroundTransparency = 1
        value.Text = "0"
        value.TextColor3 = Theme.Text
        value.TextSize = 18
        value.Font = Theme.Bold
        value.TextXAlignment = Enum.TextXAlignment.Left
        value.ZIndex = 44
        value.Parent = statFrame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -10, 0, 18)
        label.Position = UDim2.new(0, 5, 0, 35)
        label.BackgroundTransparency = 1
        label.Text = config.label
        label.TextColor3 = Theme.TextMuted
        label.TextSize = 11
        label.Font = Theme.Regular
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 44
        label.Parent = statFrame

        self._statLabels[config.key] = { value = value, format = config.format }
    end
end

--[[
    Create Progression tab content
]]
function PlayerHub:_createProgressionTab(parent: Frame)
    local progressionTab = Instance.new("ScrollingFrame")
    progressionTab.Name = "Progression"
    progressionTab.Size = UDim2.new(1, 0, 1, 0)
    progressionTab.BackgroundTransparency = 1
    progressionTab.Visible = false
    progressionTab.ScrollBarThickness = 4
    progressionTab.ScrollBarImageColor3 = Theme.SurfaceLight
    progressionTab.CanvasSize = UDim2.new(0, 0, 0, 400)
    progressionTab.ZIndex = 42
    progressionTab.Parent = parent

    self._tabs["Progression"] = progressionTab

    -- Level section
    local levelSection = Instance.new("Frame")
    levelSection.Name = "LevelSection"
    levelSection.Size = UDim2.new(1, 0, 0, 100)
    levelSection.Position = UDim2.new(0, 0, 0, 10)
    levelSection.BackgroundColor3 = Theme.Surface
    levelSection.ZIndex = 43
    levelSection.Parent = progressionTab

    local levelCorner = Instance.new("UICorner")
    levelCorner.CornerRadius = Theme.Radius
    levelCorner.Parent = levelSection

    -- Large level display
    self._progressionLevel = Instance.new("TextLabel")
    self._progressionLevel.Name = "Level"
    self._progressionLevel.Size = UDim2.new(0, 80, 0, 60)
    self._progressionLevel.Position = UDim2.new(0, 15, 0, 20)
    self._progressionLevel.BackgroundColor3 = Theme.Accent
    self._progressionLevel.Text = "1"
    self._progressionLevel.TextColor3 = Theme.Text
    self._progressionLevel.TextSize = 36
    self._progressionLevel.Font = Theme.Bold
    self._progressionLevel.ZIndex = 44
    self._progressionLevel.Parent = levelSection

    local progressionLevelCorner = Instance.new("UICorner")
    progressionLevelCorner.CornerRadius = Theme.Radius
    progressionLevelCorner.Parent = self._progressionLevel

    -- XP info
    self._xpLabel = Instance.new("TextLabel")
    self._xpLabel.Name = "XP"
    self._xpLabel.Size = UDim2.new(1, -115, 0, 25)
    self._xpLabel.Position = UDim2.new(0, 105, 0, 15)
    self._xpLabel.BackgroundTransparency = 1
    self._xpLabel.Text = "0 / 100 XP"
    self._xpLabel.TextColor3 = Theme.Text
    self._xpLabel.TextSize = 14
    self._xpLabel.Font = Theme.Medium
    self._xpLabel.TextXAlignment = Enum.TextXAlignment.Left
    self._xpLabel.ZIndex = 44
    self._xpLabel.Parent = levelSection

    -- XP bar
    local xpBarBg = Instance.new("Frame")
    xpBarBg.Name = "XPBarBg"
    xpBarBg.Size = UDim2.new(1, -115, 0, 12)
    xpBarBg.Position = UDim2.new(0, 105, 0, 42)
    xpBarBg.BackgroundColor3 = Theme.SurfaceLight
    xpBarBg.ZIndex = 44
    xpBarBg.Parent = levelSection

    local xpBarBgCorner = Instance.new("UICorner")
    xpBarBgCorner.CornerRadius = UDim.new(0, 6)
    xpBarBgCorner.Parent = xpBarBg

    self._xpBar = Instance.new("Frame")
    self._xpBar.Name = "XPBar"
    self._xpBar.Size = UDim2.new(0, 0, 1, 0)
    self._xpBar.BackgroundColor3 = Theme.Accent
    self._xpBar.ZIndex = 45
    self._xpBar.Parent = xpBarBg

    local xpBarCorner = Instance.new("UICorner")
    xpBarCorner.CornerRadius = UDim.new(0, 6)
    xpBarCorner.Parent = self._xpBar

    -- Next unlock text
    self._nextUnlock = Instance.new("TextLabel")
    self._nextUnlock.Name = "NextUnlock"
    self._nextUnlock.Size = UDim2.new(1, -115, 0, 20)
    self._nextUnlock.Position = UDim2.new(0, 105, 0, 60)
    self._nextUnlock.BackgroundTransparency = 1
    self._nextUnlock.Text = "Next: Hunter (Lv.5)"
    self._nextUnlock.TextColor3 = Theme.TextMuted
    self._nextUnlock.TextSize = 11
    self._nextUnlock.Font = Theme.Regular
    self._nextUnlock.TextXAlignment = Enum.TextXAlignment.Left
    self._nextUnlock.ZIndex = 44
    self._nextUnlock.Parent = levelSection

    -- Title selector section
    local titleSection = Instance.new("Frame")
    titleSection.Name = "TitleSection"
    titleSection.Size = UDim2.new(1, 0, 0, 40)
    titleSection.Position = UDim2.new(0, 0, 0, 120)
    titleSection.BackgroundTransparency = 1
    titleSection.ZIndex = 43
    titleSection.Parent = progressionTab

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 20)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Selected Title"
    titleLabel.TextColor3 = Theme.TextMuted
    titleLabel.TextSize = 12
    titleLabel.Font = Theme.Medium
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 44
    titleLabel.Parent = titleSection

    -- Titles list
    self._titlesContainer = Instance.new("Frame")
    self._titlesContainer.Name = "Titles"
    self._titlesContainer.Size = UDim2.new(1, 0, 0, 220)
    self._titlesContainer.Position = UDim2.new(0, 0, 0, 165)
    self._titlesContainer.BackgroundTransparency = 1
    self._titlesContainer.ZIndex = 43
    self._titlesContainer.Parent = progressionTab

    local titlesLayout = Instance.new("UIListLayout")
    titlesLayout.Padding = UDim.new(0, 5)
    titlesLayout.Parent = self._titlesContainer

    self._titleButtons = {}
end

--[[
    Create More tab content (Shop, Inventory, Achievements)
]]
function PlayerHub:_createMoreTab(parent: Frame)
    local moreTab = Instance.new("ScrollingFrame")
    moreTab.Name = "More"
    moreTab.Size = UDim2.new(1, 0, 1, 0)
    moreTab.BackgroundTransparency = 1
    moreTab.Visible = false
    moreTab.ScrollBarThickness = 4
    moreTab.ScrollBarImageColor3 = Theme.SurfaceLight
    moreTab.CanvasSize = UDim2.new(0, 0, 0, 350)
    moreTab.ZIndex = 42
    moreTab.Parent = parent

    self._tabs["More"] = moreTab

    -- Currency display at top
    local currencySection = Instance.new("Frame")
    currencySection.Name = "Currency"
    currencySection.Size = UDim2.new(1, 0, 0, 50)
    currencySection.Position = UDim2.new(0, 0, 0, 5)
    currencySection.BackgroundColor3 = Theme.Surface
    currencySection.ZIndex = 43
    currencySection.Parent = moreTab

    local currencyCorner = Instance.new("UICorner")
    currencyCorner.CornerRadius = Theme.Radius
    currencyCorner.Parent = currencySection

    local currencyIcon = Instance.new("TextLabel")
    currencyIcon.Size = UDim2.new(0, 30, 0, 30)
    currencyIcon.Position = UDim2.new(0, 15, 0.5, -15)
    currencyIcon.BackgroundColor3 = Theme.Warning
    currencyIcon.Text = "B"
    currencyIcon.TextColor3 = Theme.Background
    currencyIcon.TextSize = 16
    currencyIcon.Font = Theme.Bold
    currencyIcon.ZIndex = 44
    currencyIcon.Parent = currencySection

    local currencyIconCorner = Instance.new("UICorner")
    currencyIconCorner.CornerRadius = UDim.new(0.5, 0)
    currencyIconCorner.Parent = currencyIcon

    self._currencyLabel = Instance.new("TextLabel")
    self._currencyLabel.Name = "CurrencyAmount"
    self._currencyLabel.Size = UDim2.new(0, 100, 1, 0)
    self._currencyLabel.Position = UDim2.new(0, 55, 0, 0)
    self._currencyLabel.BackgroundTransparency = 1
    self._currencyLabel.Text = "0 Batteries"
    self._currencyLabel.TextColor3 = Theme.Warning
    self._currencyLabel.TextSize = 18
    self._currencyLabel.Font = Theme.Bold
    self._currencyLabel.TextXAlignment = Enum.TextXAlignment.Left
    self._currencyLabel.ZIndex = 44
    self._currencyLabel.Parent = currencySection

    -- Shop button
    local shopButton = Instance.new("TextButton")
    shopButton.Name = "ShopButton"
    shopButton.Size = UDim2.new(1, 0, 0, 60)
    shopButton.Position = UDim2.new(0, 0, 0, 65)
    shopButton.BackgroundColor3 = Theme.Success
    shopButton.Text = ""
    shopButton.ZIndex = 43
    shopButton.Parent = moreTab

    local shopCorner = Instance.new("UICorner")
    shopCorner.CornerRadius = Theme.Radius
    shopCorner.Parent = shopButton

    local shopLabel = Instance.new("TextLabel")
    shopLabel.Size = UDim2.new(1, 0, 0, 25)
    shopLabel.Position = UDim2.new(0, 0, 0, 10)
    shopLabel.BackgroundTransparency = 1
    shopLabel.Text = "SHOP"
    shopLabel.TextColor3 = Theme.Text
    shopLabel.TextSize = 18
    shopLabel.Font = Theme.Bold
    shopLabel.ZIndex = 44
    shopLabel.Parent = shopButton

    local shopDesc = Instance.new("TextLabel")
    shopDesc.Size = UDim2.new(1, 0, 0, 20)
    shopDesc.Position = UDim2.new(0, 0, 0, 35)
    shopDesc.BackgroundTransparency = 1
    shopDesc.Text = "Flashlights, Skins & Battery Packs"
    shopDesc.TextColor3 = Theme.Text
    shopDesc.TextTransparency = 0.3
    shopDesc.TextSize = 11
    shopDesc.Font = Theme.Regular
    shopDesc.ZIndex = 44
    shopDesc.Parent = shopButton

    shopButton.MouseEnter:Connect(function()
        local hoverColor = Color3.fromRGB(100, 240, 140)
        TweenService:Create(shopButton, Theme.Fast, { BackgroundColor3 = hoverColor }):Play()
    end)
    shopButton.MouseLeave:Connect(function()
        TweenService:Create(shopButton, Theme.Fast, { BackgroundColor3 = Theme.Success }):Play()
    end)
    shopButton.MouseButton1Click:Connect(function()
        self:_openShop()
    end)

    -- Inventory section
    local inventorySection = Instance.new("Frame")
    inventorySection.Name = "Inventory"
    inventorySection.Size = UDim2.new(1, 0, 0, 80)
    inventorySection.Position = UDim2.new(0, 0, 0, 135)
    inventorySection.BackgroundColor3 = Theme.Surface
    inventorySection.ZIndex = 43
    inventorySection.Parent = moreTab

    local invCorner = Instance.new("UICorner")
    invCorner.CornerRadius = Theme.Radius
    invCorner.Parent = inventorySection

    local invLabel = Instance.new("TextLabel")
    invLabel.Size = UDim2.new(1, 0, 0, 25)
    invLabel.Position = UDim2.new(0, 0, 0, 10)
    invLabel.BackgroundTransparency = 1
    invLabel.Text = "Equipped Items"
    invLabel.TextColor3 = Theme.Text
    invLabel.TextSize = 14
    invLabel.Font = Theme.Bold
    invLabel.ZIndex = 44
    invLabel.Parent = inventorySection

    self._equippedFlashlightLabel = Instance.new("TextLabel")
    self._equippedFlashlightLabel.Size = UDim2.new(0.5, -10, 0, 20)
    self._equippedFlashlightLabel.Position = UDim2.new(0, 10, 0, 40)
    self._equippedFlashlightLabel.BackgroundTransparency = 1
    self._equippedFlashlightLabel.Text = "Flashlight: Standard"
    self._equippedFlashlightLabel.TextColor3 = Theme.TextSecondary
    self._equippedFlashlightLabel.TextSize = 11
    self._equippedFlashlightLabel.Font = Theme.Medium
    self._equippedFlashlightLabel.TextXAlignment = Enum.TextXAlignment.Left
    self._equippedFlashlightLabel.ZIndex = 44
    self._equippedFlashlightLabel.Parent = inventorySection

    self._equippedSkinLabel = Instance.new("TextLabel")
    self._equippedSkinLabel.Size = UDim2.new(0.5, -10, 0, 20)
    self._equippedSkinLabel.Position = UDim2.new(0, 10, 0, 55)
    self._equippedSkinLabel.BackgroundTransparency = 1
    self._equippedSkinLabel.Text = "Skin: Default"
    self._equippedSkinLabel.TextColor3 = Theme.TextSecondary
    self._equippedSkinLabel.TextSize = 11
    self._equippedSkinLabel.Font = Theme.Medium
    self._equippedSkinLabel.TextXAlignment = Enum.TextXAlignment.Left
    self._equippedSkinLabel.ZIndex = 44
    self._equippedSkinLabel.Parent = inventorySection

    -- Achievements placeholder
    local achievementSection = Instance.new("Frame")
    achievementSection.Name = "Achievements"
    achievementSection.Size = UDim2.new(1, 0, 0, 80)
    achievementSection.Position = UDim2.new(0, 0, 0, 225)
    achievementSection.BackgroundColor3 = Theme.Surface
    achievementSection.ZIndex = 43
    achievementSection.Parent = moreTab

    local achCorner = Instance.new("UICorner")
    achCorner.CornerRadius = Theme.Radius
    achCorner.Parent = achievementSection

    local achLabel = Instance.new("TextLabel")
    achLabel.Size = UDim2.new(1, 0, 0, 25)
    achLabel.Position = UDim2.new(0, 0, 0, 10)
    achLabel.BackgroundTransparency = 1
    achLabel.Text = "Achievements"
    achLabel.TextColor3 = Theme.Text
    achLabel.TextSize = 14
    achLabel.Font = Theme.Bold
    achLabel.ZIndex = 44
    achLabel.Parent = achievementSection

    local achComingSoon = Instance.new("TextLabel")
    achComingSoon.Size = UDim2.new(1, 0, 0, 25)
    achComingSoon.Position = UDim2.new(0, 0, 0, 35)
    achComingSoon.BackgroundTransparency = 1
    achComingSoon.Text = "Coming Soon"
    achComingSoon.TextColor3 = Theme.Warning
    achComingSoon.TextSize = 12
    achComingSoon.Font = Theme.Medium
    achComingSoon.ZIndex = 44
    achComingSoon.Parent = achievementSection

    local achDesc = Instance.new("TextLabel")
    achDesc.Size = UDim2.new(1, -20, 0, 20)
    achDesc.Position = UDim2.new(0, 10, 0, 55)
    achDesc.BackgroundTransparency = 1
    achDesc.Text = "Unlock badges and track milestones!"
    achDesc.TextColor3 = Theme.TextMuted
    achDesc.TextSize = 10
    achDesc.Font = Theme.Regular
    achDesc.ZIndex = 44
    achDesc.Parent = achievementSection

    -- Connect to controllers for updates
    task.spawn(function()
        local BatteryController = Knit.GetController("BatteryController")
        local InventoryController = Knit.GetController("InventoryController")

        -- Currency updates
        BatteryController:OnCurrencyChanged(function(amount)
            if self._currencyLabel then
                self._currencyLabel.Text = tostring(amount) .. " Batteries"
            end
        end)

        -- Inventory updates
        InventoryController:OnInventoryChanged(function(inventory)
            if self._equippedFlashlightLabel then
                self._equippedFlashlightLabel.Text = "Flashlight: " .. (inventory.equippedFlashlight or "Standard")
            end
            if self._equippedSkinLabel then
                self._equippedSkinLabel.Text = "Skin: " .. (inventory.equippedSkin or "Default")
            end
        end)

        -- Initialize
        local currency = BatteryController:GetCurrency()
        if self._currencyLabel then
            self._currencyLabel.Text = tostring(currency) .. " Batteries"
        end

        local inventory = InventoryController:GetInventory()
        if inventory then
            if self._equippedFlashlightLabel then
                self._equippedFlashlightLabel.Text = "Flashlight: " .. (inventory.equippedFlashlight or "Standard")
            end
            if self._equippedSkinLabel then
                self._equippedSkinLabel.Text = "Skin: " .. (inventory.equippedSkin or "Default")
            end
        end
    end)
end

--[[
    Open the shop panel
]]
function PlayerHub:_openShop()
    local InventoryController = Knit.GetController("InventoryController")
    InventoryController:ShowShop()
end

--[[
    Handle play button click
]]
function PlayerHub:_handlePlayButtonClick()
    print("[PlayerHub] Play button clicked!")
    local QueueController = Knit.GetController("QueueController")
    print("[PlayerHub] Got QueueController, calling JoinQueue...")
    local success = QueueController:JoinQueue()
    print("[PlayerHub] JoinQueue returned:", success)
end

--[[
    Handle leave queue button click
]]
function PlayerHub:_handleLeaveQueueClick()
    local QueueController = Knit.GetController("QueueController")
    QueueController:LeaveQueue()
end

--[[
    Handle leave game button click
]]
function PlayerHub:_handleLeaveGameClick()
    if self._leaveGameCallback then
        self._leaveGameCallback()
    end
end

--[[
    Update queue state and button visibility
]]
function PlayerHub:updateQueueState(state: string, count: number)
    self._queueState = state
    self._queuedCount = count

    -- Auto-switch to play mode when queued or in game
    if state == Enums.QueueState.Queued or state == Enums.QueueState.InGame then
        if not self._isPlayMode then
            self:_setPlayMode(true)
        end
    end

    -- Update status text
    if state == Enums.QueueState.NotQueued then
        self._queueStatus.Text = "Ready to play!"
        self._queueStatus.TextColor3 = Theme.Success
    elseif state == Enums.QueueState.Queued then
        if count >= Constants.MIN_PLAYERS then
            self._queueStatus.Text = "Starting soon..."
            self._queueStatus.TextColor3 = Theme.Success
        else
            self._queueStatus.Text = string.format("Waiting... %d/%d players", count, Constants.MIN_PLAYERS)
            self._queueStatus.TextColor3 = Theme.Warning
        end
    elseif state == Enums.QueueState.InGame then
        self._queueStatus.Text = "Currently in game"
        self._queueStatus.TextColor3 = Theme.Accent
    end

    -- Update button visibility
    self._playButton.Visible = state == Enums.QueueState.NotQueued
    self._leaveQueueButton.Visible = state == Enums.QueueState.Queued
    self._leaveGameButton.Visible = state == Enums.QueueState.InGame
end

--[[
    Update stats display
]]
function PlayerHub:updateStats(stats: StatsTypes.PlayerStats, progression: StatsTypes.ProgressionData)
    -- Update header
    self._headerLevel.Text = "Lv." .. tostring(progression.level)
    self._headerTitle.Text = progression.selectedTitle
    self._headerTitle.TextColor3 = ProgressionConfig.getTitleColor(progression.selectedTitle)

    -- Update quick stats (both lobby and play mode)
    local winRateText = "-"
    if stats.gamesPlayed > 0 then
        local winRate = math.floor((stats.wins / stats.gamesPlayed) * 100)
        winRateText = winRate .. "%"
    end

    -- Play mode stats
    self._quickStatLabels.wins.Text = tostring(stats.wins)
    self._quickStatLabels.gamesPlayed.Text = tostring(stats.gamesPlayed)
    self._quickStatLabels.winRate.Text = winRateText

    -- Lobby mode stats
    self._lobbyStatLabels.wins.Text = tostring(stats.wins)
    self._lobbyStatLabels.gamesPlayed.Text = tostring(stats.gamesPlayed)
    self._lobbyStatLabels.winRate.Text = winRateText

    -- Update stats tab
    for key, labelData in self._statLabels do
        local value = stats[key]
        if value ~= nil then
            if labelData.format == "time" then
                labelData.value.Text = self:_formatTime(value)
            else
                labelData.value.Text = self:_formatNumber(value)
            end
        end
    end

    -- Update progression tab
    self._progressionLevel.Text = tostring(progression.level)

    local currentXP = progression.xp
    local currentThreshold = ProgressionConfig.getXPForLevel(progression.level)
    local nextThreshold = ProgressionConfig.getXPForNextLevel(progression.level)

    if nextThreshold > 0 then
        local xpIntoLevel = currentXP - currentThreshold
        local xpNeeded = nextThreshold - currentThreshold
        self._xpLabel.Text = string.format("%s / %s XP", self:_formatNumber(xpIntoLevel), self:_formatNumber(xpNeeded))

        local progress = ProgressionConfig.calculateProgress(currentXP, progression.level)
        TweenService:Create(self._xpBar, Theme.Normal, {
            Size = UDim2.new(progress, 0, 1, 0),
        }):Play()
    else
        self._xpLabel.Text = "MAX LEVEL"
        self._xpBar.Size = UDim2.new(1, 0, 1, 0)
    end

    -- Find next title unlock
    local nextTitle = nil
    local nextTitleLevel = nil
    for level, title in ProgressionConfig.TITLES do
        if level > progression.level then
            if nextTitleLevel == nil or level < nextTitleLevel then
                nextTitleLevel = level
                nextTitle = title
            end
        end
    end

    if nextTitle then
        self._nextUnlock.Text = string.format("Next: %s (Lv.%d)", nextTitle, nextTitleLevel)
    else
        self._nextUnlock.Text = "All titles unlocked!"
    end

    -- Update titles list
    self:_updateTitlesList(progression.unlockedTitles, progression.selectedTitle)
end

--[[
    Update titles list in progression tab
]]
function PlayerHub:_updateTitlesList(unlockedTitles: { string }, selectedTitle: string)
    -- Clear existing buttons
    for _, button in self._titleButtons do
        button:Destroy()
    end
    self._titleButtons = {}

    -- Get all titles sorted by level
    local allTitles = {}
    for level, title in ProgressionConfig.TITLES do
        table.insert(allTitles, { level = level, title = title })
    end
    table.sort(allTitles, function(a, b) return a.level < b.level end)

    for i, titleData in allTitles do
        local isUnlocked = table.find(unlockedTitles, titleData.title) ~= nil
        local isSelected = titleData.title == selectedTitle

        local button = Instance.new("TextButton")
        button.Name = titleData.title
        button.Size = UDim2.new(1, 0, 0, 40)
        button.BackgroundColor3 = isSelected and Theme.Accent or Theme.Surface
        button.Text = ""
        button.ZIndex = 44
        button.Parent = self._titlesContainer

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = Theme.RadiusSmall
        buttonCorner.Parent = button

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -60, 1, 0)
        titleLabel.Position = UDim2.new(0, 10, 0, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = titleData.title
        titleLabel.TextColor3 = isUnlocked and ProgressionConfig.getTitleColor(titleData.title) or Theme.TextMuted
        titleLabel.TextSize = 14
        titleLabel.Font = Theme.Bold
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.ZIndex = 45
        titleLabel.Parent = button

        local levelLabel = Instance.new("TextLabel")
        levelLabel.Size = UDim2.new(0, 45, 1, 0)
        levelLabel.Position = UDim2.new(1, -50, 0, 0)
        levelLabel.BackgroundTransparency = 1
        levelLabel.Text = isUnlocked and "" or "Lv." .. titleData.level
        levelLabel.TextColor3 = Theme.TextMuted
        levelLabel.TextSize = 11
        levelLabel.Font = Theme.Regular
        levelLabel.ZIndex = 45
        levelLabel.Parent = button

        if isUnlocked and not isSelected then
            button.MouseEnter:Connect(function()
                TweenService:Create(button, Theme.Fast, { BackgroundColor3 = Theme.SurfaceHover }):Play()
            end)
            button.MouseLeave:Connect(function()
                TweenService:Create(button, Theme.Fast, { BackgroundColor3 = Theme.Surface }):Play()
            end)
            button.MouseButton1Click:Connect(function()
                local ProgressionController = Knit.GetController("ProgressionController")
                ProgressionController:SelectTitle(titleData.title)
            end)
        end

        self._titleButtons[titleData.title] = button
    end

    -- Update canvas size
    self._titlesContainer.Parent.CanvasSize = UDim2.new(0, 0, 0, 165 + (#allTitles * 45))
end

--[[
    Format time value
]]
function PlayerHub:_formatTime(seconds: number): string
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, secs)
    else
        return string.format("%ds", secs)
    end
end

--[[
    Format number with commas
]]
function PlayerHub:_formatNumber(value: number): string
    local formatted = tostring(math.floor(value))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

--[[
    Set the leave game callback (for confirmation dialog)
]]
function PlayerHub:setLeaveGameCallback(callback: () -> ())
    self._leaveGameCallback = callback
end

--[[
    Show the panel
]]
function PlayerHub:show()
    self._isVisible = true
    self.frame.Visible = true
    self.toggleButton.Text = "<"

    TweenService:Create(self.frame, Theme.Slide, {
        Position = UDim2.new(0, 15, 0.5, 0),
    }):Play()

    TweenService:Create(self.toggleButton, Theme.Normal, {
        Position = UDim2.new(0, PANEL_WIDTH + 25, 0.5, -25),
    }):Play()
end

--[[
    Hide the panel
]]
function PlayerHub:hide()
    self._isVisible = false
    self.toggleButton.Text = ">"

    TweenService:Create(self.frame, Theme.Normal, {
        Position = UDim2.new(0, -PANEL_WIDTH - 20, 0.5, 0),
    }):Play()

    TweenService:Create(self.toggleButton, Theme.Normal, {
        Position = UDim2.new(0, 15, 0.5, -25),
    }):Play()

    task.delay(0.25, function()
        if not self._isVisible then
            self.frame.Visible = false
        end
    end)
end

--[[
    Toggle panel visibility
]]
function PlayerHub:toggle()
    if self._isVisible then
        self:hide()
    else
        self:show()
    end
end

--[[
    Check if panel is visible
]]
function PlayerHub:isVisible(): boolean
    return self._isVisible
end

--[[
    Show panel immediately without animation (for initial load)
]]
function PlayerHub:showInstant()
    self._isVisible = true
    self.frame.Visible = true
    self.frame.Position = UDim2.new(0, 15, 0.5, 0)
    self.toggleButton.Text = "<"
    self.toggleButton.Position = UDim2.new(0, PANEL_WIDTH + 25, 0.5, -25)
end

--[[
    Get current play mode state
]]
function PlayerHub:isPlayMode(): boolean
    return self._isPlayMode
end

--[[
    Set play mode externally
]]
function PlayerHub:setPlayMode(isPlayMode: boolean)
    self:_setPlayMode(isPlayMode)
end

--[[
    Destroy the component
]]
function PlayerHub:destroy()
    for _, conn in self._connections do
        conn:Disconnect()
    end
    self.frame:Destroy()
    self.toggleButton:Destroy()
end

return PlayerHub
