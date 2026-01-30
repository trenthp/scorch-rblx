--!strict
--[[
    UIController.lua
    Centralized UI system for Scorch

    UI Layout:
    ┌─────────────────────────────────────────┐
    │            [Status Bar]                 │  State info + role (during gameplay)
    ├─────────────────────────────────────────┤
    │                                         │
    │          [Center Display]               │  Countdown, announcements
    │                                         │
    └─────────────────────────────────────────┘
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

local LocalPlayer = Players.LocalPlayer

-- Design System
local Theme = {
    Background = Color3.fromRGB(15, 15, 22),
    Surface = Color3.fromRGB(25, 25, 35),
    SurfaceLight = Color3.fromRGB(35, 35, 48),

    Text = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(140, 140, 155),
    TextMuted = Color3.fromRGB(80, 80, 95),

    Seeker = Color3.fromRGB(255, 130, 85),
    Runner = Color3.fromRGB(85, 170, 255),
    Frozen = Color3.fromRGB(150, 210, 255),

    Success = Color3.fromRGB(85, 220, 120),
    Warning = Color3.fromRGB(255, 200, 85),
    Danger = Color3.fromRGB(255, 95, 95),

    Radius = UDim.new(0, 10),
    RadiusLarge = UDim.new(0, 14),

    Bold = Enum.Font.GothamBold,
    Medium = Enum.Font.GothamMedium,
    Regular = Enum.Font.Gotham,

    Fast = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Normal = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Bounce = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

local UIController = Knit.CreateController({
    Name = "UIController",

    _trove = nil :: any,
    _screenGui = nil :: ScreenGui?,
    _elements = {} :: { [string]: GuiObject },
    _currentState = Enums.GameState.LOBBY :: string,
    _currentPhase = nil :: string?,
    _currentRole = Enums.PlayerRole.Spectator :: string,
    _isFrozen = false,
})

function UIController:KnitInit()
    self._trove = Trove.new()
    self._elements = {}
    print("[UIController] Initialized")
end

function UIController:KnitStart()
    local GameStateService = Knit.GetService("GameStateService")
    local RoundService = Knit.GetService("RoundService")
    local TeamService = Knit.GetService("TeamService")
    local PlayerStateService = Knit.GetService("PlayerStateService")

    self:_createUI()

    -- Game state changes
    GameStateService.GameStateChanged:Connect(function(newState, oldState)
        self:_onStateChanged(newState, oldState)
    end)

    -- Team selection countdown
    GameStateService.NextRoundCountdown:Connect(function(seconds)
        self:_updateTeamSelectionCountdown(seconds)
    end)

    -- Gameplay phase changes
    RoundService.PhaseChanged:Connect(function(phase, data)
        self:_onPhaseChanged(phase, data)
    end)

    -- Round events
    RoundService.CountdownTick:Connect(function(count, phase)
        self:_onCountdownTick(count, phase)
    end)

    RoundService.RoundTimerUpdate:Connect(function(remaining)
        self:_updateRoundTimer(remaining)
    end)

    RoundService.RoundEnded:Connect(function(results)
        self:_showResults(results)
    end)

    -- Team assignment
    TeamService.TeamAssigned:Connect(function(role)
        self._currentRole = role
        self:_updateStatusBar()
    end)

    -- Freeze state
    PlayerStateService.PlayerFrozen:Connect(function(player)
        if player == LocalPlayer then
            self._isFrozen = true
            self:_showFreezeOverlay(true)
        end
    end)

    PlayerStateService.PlayerUnfrozen:Connect(function(player)
        if player == LocalPlayer then
            self._isFrozen = false
            self:_showFreezeOverlay(false)
        end
    end)

    -- Initial state
    self:_onStateChanged(Enums.GameState.LOBBY, Enums.GameState.LOBBY)

    print("[UIController] Started")
end

--==============================================================================
-- UI CREATION
--==============================================================================

function UIController:_createUI()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ScorchUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 10
    screenGui.Parent = playerGui

    self._screenGui = screenGui
    self._trove:Add(screenGui)

    self:_createStatusBar(screenGui)
    self:_createCenterDisplay(screenGui)
    self:_createFreezeOverlay(screenGui)
    self:_createResultsPanel(screenGui)
end

--[[
    Status Bar - Top center
    Shows different content based on state:
    - LOBBY: "Waiting for players (min 2)"
    - TEAM_SELECTION: "Starting in X..." with countdown
    - GAMEPLAY: Shows phase-appropriate content
    - RESULTS: "Round Over"
]]
function UIController:_createStatusBar(parent: ScreenGui)
    local bar = Instance.new("Frame")
    bar.Name = "StatusBar"
    bar.Size = UDim2.new(0, 220, 0, 48)
    bar.Position = UDim2.new(0.5, -110, 0, 12)
    bar.BackgroundColor3 = Theme.Background
    bar.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = Theme.Radius
    corner.Parent = bar

    local stroke = Instance.new("UIStroke")
    stroke.Name = "Stroke"
    stroke.Color = Theme.SurfaceLight
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = bar

    -- Status text (for non-gameplay states)
    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, 0, 1, 0)
    status.BackgroundTransparency = 1
    status.Text = "LOBBY"
    status.TextColor3 = Theme.TextSecondary
    status.TextSize = 14
    status.Font = Theme.Medium
    status.Parent = bar

    -- Gameplay container (role + timer)
    local gameplayContainer = Instance.new("Frame")
    gameplayContainer.Name = "GameplayContainer"
    gameplayContainer.Size = UDim2.new(1, 0, 1, 0)
    gameplayContainer.BackgroundTransparency = 1
    gameplayContainer.Visible = false
    gameplayContainer.Parent = bar

    -- Role section (left half, centered)
    local roleSection = Instance.new("Frame")
    roleSection.Name = "RoleSection"
    roleSection.Size = UDim2.new(0.5, -1, 1, 0)
    roleSection.Position = UDim2.new(0, 0, 0, 0)
    roleSection.BackgroundTransparency = 1
    roleSection.Parent = gameplayContainer

    local roleIcon = Instance.new("TextLabel")
    roleIcon.Name = "RoleIcon"
    roleIcon.Size = UDim2.new(0, 24, 1, 0)
    roleIcon.Position = UDim2.new(0.5, -42, 0, 0)
    roleIcon.BackgroundTransparency = 1
    roleIcon.Text = "🔦"
    roleIcon.TextSize = 18
    roleIcon.Parent = roleSection

    local roleLabel = Instance.new("TextLabel")
    roleLabel.Name = "RoleLabel"
    roleLabel.Size = UDim2.new(0, 60, 1, 0)
    roleLabel.Position = UDim2.new(0.5, -18, 0, 0)
    roleLabel.BackgroundTransparency = 1
    roleLabel.Text = "SEEKER"
    roleLabel.TextColor3 = Theme.Seeker
    roleLabel.TextSize = 12
    roleLabel.Font = Theme.Bold
    roleLabel.TextXAlignment = Enum.TextXAlignment.Left
    roleLabel.Parent = roleSection

    -- Divider (center)
    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.Size = UDim2.new(0, 1, 0, 24)
    divider.Position = UDim2.new(0.5, 0, 0.5, -12)
    divider.BackgroundColor3 = Theme.SurfaceLight
    divider.BorderSizePixel = 0
    divider.Parent = gameplayContainer

    -- Timer section (right half, centered)
    local timer = Instance.new("TextLabel")
    timer.Name = "Timer"
    timer.Size = UDim2.new(0.5, -1, 1, 0)
    timer.Position = UDim2.new(0.5, 1, 0, 0)
    timer.BackgroundTransparency = 1
    timer.Text = "3:00"
    timer.TextColor3 = Theme.Text
    timer.TextSize = 24
    timer.Font = Theme.Bold
    timer.TextXAlignment = Enum.TextXAlignment.Center
    timer.Parent = gameplayContainer

    self._elements.statusBar = bar
    self._elements.statusBarStroke = stroke
    self._elements.status = status
    self._elements.gameplayContainer = gameplayContainer
    self._elements.roleIcon = roleIcon
    self._elements.roleLabel = roleLabel
    self._elements.timer = timer
end

--[[
    Center Display - Middle of screen
    Shows: Countdown numbers, announcements, instructions
]]
function UIController:_createCenterDisplay(parent: ScreenGui)
    local center = Instance.new("Frame")
    center.Name = "CenterDisplay"
    center.Size = UDim2.new(0, 500, 0, 180)
    center.Position = UDim2.new(0.5, -250, 0.4, -90)
    center.BackgroundTransparency = 1
    center.Visible = false
    center.Parent = parent

    local mainText = Instance.new("TextLabel")
    mainText.Name = "MainText"
    mainText.Size = UDim2.new(1, 0, 0, 100)
    mainText.Position = UDim2.new(0, 0, 0, 0)
    mainText.BackgroundTransparency = 1
    mainText.Text = ""
    mainText.TextColor3 = Theme.Text
    mainText.TextSize = 90
    mainText.Font = Theme.Bold
    mainText.Parent = center

    local subText = Instance.new("TextLabel")
    subText.Name = "SubText"
    subText.Size = UDim2.new(1, 0, 0, 35)
    subText.Position = UDim2.new(0, 0, 0, 105)
    subText.BackgroundTransparency = 1
    subText.Text = ""
    subText.TextColor3 = Theme.TextSecondary
    subText.TextSize = 20
    subText.Font = Theme.Medium
    subText.Parent = center

    self._elements.centerDisplay = center
    self._elements.mainText = mainText
    self._elements.subText = subText
end

--[[
    Freeze Overlay - Full screen when frozen
]]
function UIController:_createFreezeOverlay(parent: ScreenGui)
    local overlay = Instance.new("Frame")
    overlay.Name = "FreezeOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Theme.Frozen
    overlay.BackgroundTransparency = 1
    overlay.Visible = false
    overlay.Parent = parent

    local box = Instance.new("Frame")
    box.Name = "Box"
    box.Size = UDim2.new(0, 260, 0, 130)
    box.Position = UDim2.new(0.5, -130, 0.4, -65)
    box.BackgroundColor3 = Theme.Background
    box.BackgroundTransparency = 0.1
    box.Parent = overlay

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = Theme.RadiusLarge
    boxCorner.Parent = box

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Color = Theme.Frozen
    boxStroke.Thickness = 2
    boxStroke.Parent = box

    local frozenIcon = Instance.new("TextLabel")
    frozenIcon.Size = UDim2.new(1, 0, 0, 40)
    frozenIcon.Position = UDim2.new(0, 0, 0, 15)
    frozenIcon.BackgroundTransparency = 1
    frozenIcon.Text = "❄️"
    frozenIcon.TextSize = 32
    frozenIcon.Parent = box

    local frozenTitle = Instance.new("TextLabel")
    frozenTitle.Size = UDim2.new(1, 0, 0, 30)
    frozenTitle.Position = UDim2.new(0, 0, 0, 52)
    frozenTitle.BackgroundTransparency = 1
    frozenTitle.Text = "FROZEN"
    frozenTitle.TextColor3 = Theme.Frozen
    frozenTitle.TextSize = 26
    frozenTitle.Font = Theme.Bold
    frozenTitle.Parent = box

    local frozenHint = Instance.new("TextLabel")
    frozenHint.Size = UDim2.new(1, -20, 0, 25)
    frozenHint.Position = UDim2.new(0, 10, 0, 88)
    frozenHint.BackgroundTransparency = 1
    frozenHint.Text = "Wait for a teammate to rescue you"
    frozenHint.TextColor3 = Theme.TextSecondary
    frozenHint.TextSize = 14
    frozenHint.Font = Theme.Regular
    frozenHint.Parent = box

    self._elements.freezeOverlay = overlay
end

--[[
    Results Panel - Shown at round end with close button
]]
function UIController:_createResultsPanel(parent: ScreenGui)
    local panel = Instance.new("Frame")
    panel.Name = "ResultsPanel"
    panel.Size = UDim2.new(0, 340, 0, 300)
    panel.Position = UDim2.new(0.5, -170, 0.5, -150)
    panel.BackgroundColor3 = Theme.Background
    panel.Visible = false
    panel.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = Theme.RadiusLarge
    corner.Parent = panel

    local stroke = Instance.new("UIStroke")
    stroke.Name = "Stroke"
    stroke.Color = Theme.SurfaceLight
    stroke.Thickness = 2
    stroke.Parent = panel

    local winner = Instance.new("TextLabel")
    winner.Name = "Winner"
    winner.Size = UDim2.new(1, 0, 0, 45)
    winner.Position = UDim2.new(0, 0, 0, 25)
    winner.BackgroundTransparency = 1
    winner.Text = "RUNNERS WIN"
    winner.TextColor3 = Theme.Runner
    winner.TextSize = 32
    winner.Font = Theme.Bold
    winner.Parent = panel

    local reason = Instance.new("TextLabel")
    reason.Name = "Reason"
    reason.Size = UDim2.new(1, 0, 0, 22)
    reason.Position = UDim2.new(0, 0, 0, 70)
    reason.BackgroundTransparency = 1
    reason.Text = "Time ran out!"
    reason.TextColor3 = Theme.TextSecondary
    reason.TextSize = 15
    reason.Font = Theme.Regular
    reason.Parent = panel

    local stats = Instance.new("Frame")
    stats.Name = "Stats"
    stats.Size = UDim2.new(1, -40, 0, 60)
    stats.Position = UDim2.new(0, 20, 0, 110)
    stats.BackgroundColor3 = Theme.Surface
    stats.Parent = panel

    local statsCorner = Instance.new("UICorner")
    statsCorner.CornerRadius = Theme.Radius
    statsCorner.Parent = stats

    local frozenStat = Instance.new("Frame")
    frozenStat.Size = UDim2.new(0.5, 0, 1, 0)
    frozenStat.BackgroundTransparency = 1
    frozenStat.Parent = stats

    local frozenValue = Instance.new("TextLabel")
    frozenValue.Name = "FrozenValue"
    frozenValue.Size = UDim2.new(1, 0, 0, 28)
    frozenValue.Position = UDim2.new(0, 0, 0, 8)
    frozenValue.BackgroundTransparency = 1
    frozenValue.Text = "0/0"
    frozenValue.TextColor3 = Theme.Frozen
    frozenValue.TextSize = 20
    frozenValue.Font = Theme.Bold
    frozenValue.Parent = frozenStat

    local frozenLabel = Instance.new("TextLabel")
    frozenLabel.Size = UDim2.new(1, 0, 0, 18)
    frozenLabel.Position = UDim2.new(0, 0, 0, 35)
    frozenLabel.BackgroundTransparency = 1
    frozenLabel.Text = "Frozen"
    frozenLabel.TextColor3 = Theme.TextMuted
    frozenLabel.TextSize = 12
    frozenLabel.Font = Theme.Regular
    frozenLabel.Parent = frozenStat

    local durationStat = Instance.new("Frame")
    durationStat.Size = UDim2.new(0.5, 0, 1, 0)
    durationStat.Position = UDim2.new(0.5, 0, 0, 0)
    durationStat.BackgroundTransparency = 1
    durationStat.Parent = stats

    local durationValue = Instance.new("TextLabel")
    durationValue.Name = "DurationValue"
    durationValue.Size = UDim2.new(1, 0, 0, 28)
    durationValue.Position = UDim2.new(0, 0, 0, 8)
    durationValue.BackgroundTransparency = 1
    durationValue.Text = "0:00"
    durationValue.TextColor3 = Theme.Warning
    durationValue.TextSize = 20
    durationValue.Font = Theme.Bold
    durationValue.Parent = durationStat

    local durationLabel = Instance.new("TextLabel")
    durationLabel.Size = UDim2.new(1, 0, 0, 18)
    durationLabel.Position = UDim2.new(0, 0, 0, 35)
    durationLabel.BackgroundTransparency = 1
    durationLabel.Text = "Duration"
    durationLabel.TextColor3 = Theme.TextMuted
    durationLabel.TextSize = 12
    durationLabel.Font = Theme.Regular
    durationLabel.Parent = durationStat

    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(1, -40, 0, 50)
    closeButton.Position = UDim2.new(0, 20, 1, -70)
    closeButton.BackgroundColor3 = Theme.Surface
    closeButton.Text = "CONTINUE"
    closeButton.TextColor3 = Theme.Text
    closeButton.TextSize = 18
    closeButton.Font = Theme.Bold
    closeButton.AutoButtonColor = true
    closeButton.Parent = panel

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = Theme.Radius
    closeCorner.Parent = closeButton

    local closeStroke = Instance.new("UIStroke")
    closeStroke.Color = Theme.SurfaceLight
    closeStroke.Thickness = 1
    closeStroke.Parent = closeButton

    -- Close button hover effect
    closeButton.MouseEnter:Connect(function()
        TweenService:Create(closeButton, Theme.Fast, { BackgroundColor3 = Theme.SurfaceLight }):Play()
    end)
    closeButton.MouseLeave:Connect(function()
        TweenService:Create(closeButton, Theme.Fast, { BackgroundColor3 = Theme.Surface }):Play()
    end)

    -- Close button click
    closeButton.MouseButton1Click:Connect(function()
        self:_closeResults()
    end)

    self._elements.resultsPanel = panel
    self._elements.resultsWinner = winner
    self._elements.resultsReason = reason
    self._elements.resultsFrozen = frozenValue
    self._elements.resultsDuration = durationValue
    self._elements.resultsStroke = stroke
    self._elements.closeButton = closeButton
end

--==============================================================================
-- STATE MANAGEMENT
--==============================================================================

function UIController:_onStateChanged(newState: string, oldState: string)
    self._currentState = newState
    self._currentPhase = nil

    -- Hide results panel when leaving results
    if oldState == Enums.GameState.RESULTS then
        self:_hideResults()
    end

    -- Hide freeze overlay on state change (except during gameplay)
    if newState ~= Enums.GameState.GAMEPLAY then
        self:_showFreezeOverlay(false)
        self._isFrozen = false
    end

    -- Reset role when leaving gameplay
    if oldState == Enums.GameState.GAMEPLAY then
        self._currentRole = Enums.PlayerRole.Spectator
    end

    -- Hide center display on state change
    self:_hideCenterDisplay()

    -- Update status bar for new state
    self:_updateStatusBar()
end

function UIController:_onPhaseChanged(phase: string, _data: any)
    self._currentPhase = phase
    self:_updateStatusBar()

    if phase == Enums.GameplayPhase.ACTIVE then
        -- Show "HUNT!" or role reminder when active gameplay starts
        local isSeeker = self._currentRole == Enums.PlayerRole.Seeker
        if isSeeker then
            self:_showCenterText("HUNT!", Theme.Seeker, 2)
        else
            self:_hideCenterDisplay()
        end
    end
end

--==============================================================================
-- STATUS BAR
--==============================================================================

function UIController:_updateStatusBar()
    local bar = self._elements.statusBar
    local stroke = self._elements.statusBarStroke
    local status = self._elements.status
    local gameplayContainer = self._elements.gameplayContainer
    local roleIcon = self._elements.roleIcon
    local roleLabel = self._elements.roleLabel

    if not bar then return end

    local state = self._currentState
    local phase = self._currentPhase

    -- Default to visible (LOBBY state will hide it)
    bar.Visible = true

    -- During ACTIVE gameplay phase, show role + timer
    if state == Enums.GameState.GAMEPLAY and phase == Enums.GameplayPhase.ACTIVE then
        status.Visible = false
        gameplayContainer.Visible = true

        local isSeeker = self._currentRole == Enums.PlayerRole.Seeker
        roleIcon.Text = isSeeker and "🔦" or "🏃"
        roleLabel.Text = isSeeker and "SEEKER" or "RUNNER"
        roleLabel.TextColor3 = isSeeker and Theme.Seeker or Theme.Runner
        stroke.Color = isSeeker and Theme.Seeker or Theme.Runner

        bar.Size = UDim2.new(0, 220, 0, 48)
        bar.Position = UDim2.new(0.5, -110, 0, 12)
    else
        -- Show status text for other states/phases
        status.Visible = true
        gameplayContainer.Visible = false
        stroke.Color = Theme.SurfaceLight

        if state == Enums.GameState.LOBBY then
            -- Hide status bar during lobby - lobby has its own status display
            bar.Visible = false
            return
        elseif state == Enums.GameState.TEAM_SELECTION then
            status.Text = "Starting in..."
            status.TextColor3 = Theme.TextSecondary
            bar.Size = UDim2.new(0, 140, 0, 48)
        elseif state == Enums.GameState.GAMEPLAY then
            -- During countdown/hiding phases
            local isSeeker = self._currentRole == Enums.PlayerRole.Seeker
            if isSeeker then
                status.Text = "🔦  You are the SEEKER"
                status.TextColor3 = Theme.Seeker
            else
                status.Text = "🏃  You are a RUNNER"
                status.TextColor3 = Theme.Runner
            end
            bar.Size = UDim2.new(0, 200, 0, 48)
        elseif state == Enums.GameState.RESULTS then
            status.Text = "Round Over"
            status.TextColor3 = Theme.TextSecondary
            bar.Size = UDim2.new(0, 180, 0, 48)
        else
            status.Text = state
            status.TextColor3 = Theme.TextSecondary
            bar.Size = UDim2.new(0, 160, 0, 48)
        end

        bar.Position = UDim2.new(0.5, -bar.Size.X.Offset / 2, 0, 12)
    end
end

function UIController:_updateTeamSelectionCountdown(seconds: number)
    local status = self._elements.status
    local bar = self._elements.statusBar
    if not status or not bar then return end

    if self._currentState == Enums.GameState.TEAM_SELECTION then
        status.Text = string.format("Starting in %d...", seconds)
    elseif self._currentState == Enums.GameState.RESULTS then
        -- Show countdown to next round during results
        status.Text = string.format("Next round in %d...", seconds)
        status.TextColor3 = Theme.TextSecondary
        bar.Size = UDim2.new(0, 180, 0, 48)
        bar.Position = UDim2.new(0.5, -90, 0, 12)
    end
end

function UIController:_updateRoundTimer(seconds: number)
    local timer = self._elements.timer
    if not timer then return end

    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    timer.Text = string.format("%d:%02d", mins, secs)

    -- Color based on urgency
    if seconds <= 10 then
        timer.TextColor3 = Theme.Danger
    elseif seconds <= 30 then
        timer.TextColor3 = Theme.Warning
    else
        timer.TextColor3 = Theme.Text
    end
end

--==============================================================================
-- CENTER DISPLAY
--==============================================================================

function UIController:_showCenterText(main: string, color: Color3?, duration: number?, sub: string?)
    local center = self._elements.centerDisplay
    local mainText = self._elements.mainText
    local subText = self._elements.subText

    if not center then return end

    mainText.Text = main
    mainText.TextColor3 = color or Theme.Text
    mainText.TextSize = if #main <= 3 then 90 else 42
    subText.Text = sub or ""

    center.Visible = true

    mainText.TextTransparency = 1
    TweenService:Create(mainText, Theme.Fast, { TextTransparency = 0 }):Play()

    if duration then
        task.delay(duration, function()
            if mainText.Text == main then
                TweenService:Create(mainText, Theme.Fast, { TextTransparency = 1 }):Play()
                task.delay(0.15, function()
                    if mainText.Text == main then
                        center.Visible = false
                    end
                end)
            end
        end)
    end
end

function UIController:_hideCenterDisplay()
    local center = self._elements.centerDisplay
    if center then
        center.Visible = false
    end
end

function UIController:_onCountdownTick(count: number, phase: string)
    local isSeeker = self._currentRole == Enums.PlayerRole.Seeker

    if phase == Enums.GameplayPhase.COUNTDOWN then
        -- Initial countdown - everyone frozen
        if count > 0 then
            local totalWait = Constants.GET_READY_DURATION + Constants.HIDING_DURATION
            local subText
            if isSeeker then
                subText = string.format("You'll be released in %d seconds", count + Constants.HIDING_DURATION)
            else
                subText = string.format("You can run in %d seconds", count)
            end

            self:_showCenterText(tostring(count), Theme.Text, nil, subText)

            local mainText = self._elements.mainText
            if mainText then
                mainText.TextSize = 110
                TweenService:Create(mainText, Theme.Bounce, { TextSize = 90 }):Play()
            end
        else
            -- End of countdown phase
            if isSeeker then
                self:_showCenterText("WAIT", Theme.Warning, 1, "Runners are hiding...")
            else
                self:_showCenterText("GO!", Theme.Success, 1.5, "Run and hide!")
            end
        end

    elseif phase == Enums.GameplayPhase.HIDING then
        -- Hiding phase - runners can move, seekers frozen
        if isSeeker then
            -- Seeker sees countdown until they can move
            if count > 0 then
                self:_showCenterText(tostring(count), Theme.Warning, nil, "Runners are hiding...")
            end
            -- count == 0 is handled by PhaseChanged -> ACTIVE
        else
            -- Runner sees hiding time remaining
            if count > 0 and count <= 5 then
                -- Only show last 5 seconds warning
                self:_showCenterText(tostring(count), Theme.Warning, nil, "Seeker releasing soon!")
            elseif count > 5 then
                -- Hide center display, let them focus on hiding
                self:_hideCenterDisplay()
            end
        end
    end
end

--==============================================================================
-- FREEZE OVERLAY
--==============================================================================

function UIController:_showFreezeOverlay(show: boolean)
    local overlay = self._elements.freezeOverlay
    if not overlay then return end

    if show then
        overlay.Visible = true
        overlay.BackgroundTransparency = 1
        TweenService:Create(overlay, Theme.Normal, { BackgroundTransparency = 0.75 }):Play()
    else
        TweenService:Create(overlay, Theme.Normal, { BackgroundTransparency = 1 }):Play()
        task.delay(0.25, function()
            if not self._isFrozen then
                overlay.Visible = false
            end
        end)
    end
end

--==============================================================================
-- RESULTS PANEL
--==============================================================================

function UIController:_showResults(results: any)
    local panel = self._elements.resultsPanel
    local winner = self._elements.resultsWinner
    local reason = self._elements.resultsReason
    local frozen = self._elements.resultsFrozen
    local duration = self._elements.resultsDuration
    local stroke = self._elements.resultsStroke

    if not panel then return end

    local isSeekersWin = results.winner == Enums.WinnerTeam.Seekers
    winner.Text = isSeekersWin and "SEEKERS WIN" or "RUNNERS WIN"
    winner.TextColor3 = isSeekersWin and Theme.Seeker or Theme.Runner
    stroke.Color = isSeekersWin and Theme.Seeker or Theme.Runner

    local reasons = {
        AllFrozen = "All runners were frozen!",
        TimeUp = "Time ran out!",
        SeekersDisconnected = "Seekers left the game",
        RunnersDisconnected = "Runners left the game",
    }
    reason.Text = reasons[results.reason] or "Round complete"

    frozen.Text = string.format("%d/%d", results.frozenCount, results.totalRunners)

    local mins = math.floor(results.duration / 60)
    local secs = math.floor(results.duration % 60)
    duration.Text = string.format("%d:%02d", mins, secs)

    panel.Visible = true
    panel.BackgroundTransparency = 1
    panel.Position = UDim2.new(0.5, -170, 0.5, -130)

    TweenService:Create(panel, Theme.Normal, {
        BackgroundTransparency = 0,
        Position = UDim2.new(0.5, -170, 0.5, -150),
    }):Play()
end

function UIController:_hideResults()
    local panel = self._elements.resultsPanel
    if not panel then return end

    TweenService:Create(panel, Theme.Fast, { BackgroundTransparency = 1 }):Play()
    task.delay(0.15, function()
        panel.Visible = false
    end)
end

function UIController:_closeResults()
    -- Just hide the panel locally - game will auto-advance after 30 seconds
    self:_hideResults()
end

--==============================================================================
-- PUBLIC API
--==============================================================================

function UIController:OnGameStateChanged(newState: string, oldState: string)
    self:_onStateChanged(newState, oldState)
end

return UIController
