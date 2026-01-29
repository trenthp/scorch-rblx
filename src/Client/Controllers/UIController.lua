--!strict
--[[
    UIController.lua
    Manages all UI elements and screens
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

local UIController = Knit.CreateController({
    Name = "UIController",

    _trove = nil :: any,
    _screenGui = nil :: ScreenGui?,
    _hudFrame = nil :: Frame?,
    _timerLabel = nil :: TextLabel?,
    _roleLabel = nil :: TextLabel?,
    _stateLabel = nil :: TextLabel?,
    _countdownLabel = nil :: TextLabel?,
    _resultsFrame = nil :: Frame?,
})

function UIController:KnitInit()
    self._trove = Trove.new()
    print("[UIController] Initialized")
end

function UIController:KnitStart()
    local RoundService = Knit.GetService("RoundService")
    local TeamService = Knit.GetService("TeamService")

    -- Create all UI
    self:_createUI()

    -- Listen for round events
    RoundService.CountdownTick:Connect(function(count)
        self:_onCountdownTick(count)
    end)

    RoundService.RoundTimerUpdate:Connect(function(remaining)
        self:_onTimerUpdate(remaining)
    end)

    RoundService.RoundStarted:Connect(function(data)
        self:_onRoundStarted(data)
    end)

    RoundService.RoundEnded:Connect(function(results)
        self:_onRoundEnded(results)
    end)

    RoundService.SeekerUnfrozen:Connect(function()
        self:_onSeekerUnfrozen()
    end)

    -- Listen for team assignment
    TeamService.TeamAssigned:Connect(function(player, role)
        if player == LocalPlayer then
            self:_updateRoleDisplay(role)
        end
    end)

    print("[UIController] Started")
end

--[[
    Create all UI elements
]]
function UIController:_createUI()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")

    -- Main ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ScorchUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 10
    screenGui.Parent = playerGui

    self._screenGui = screenGui
    self._trove:Add(screenGui)

    -- Create HUD
    self:_createHUD(screenGui)

    -- Create countdown display
    self:_createCountdownDisplay(screenGui)

    -- Create results display
    self:_createResultsDisplay(screenGui)
end

--[[
    Create the HUD (timer, role, state)
]]
function UIController:_createHUD(parent: ScreenGui)
    local hudFrame = Instance.new("Frame")
    hudFrame.Name = "HUD"
    hudFrame.Size = UDim2.new(1, 0, 0, 100)
    hudFrame.Position = UDim2.new(0, 0, 0, 0)
    hudFrame.BackgroundTransparency = 1
    hudFrame.Parent = parent

    self._hudFrame = hudFrame

    -- Timer display (top center)
    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name = "Timer"
    timerLabel.Size = UDim2.new(0, 200, 0, 50)
    timerLabel.Position = UDim2.new(0.5, -100, 0, 20)
    timerLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    timerLabel.BackgroundTransparency = 0.3
    timerLabel.Text = "3:00"
    timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    timerLabel.TextSize = 36
    timerLabel.Font = Enum.Font.GothamBold
    timerLabel.Parent = hudFrame

    local timerCorner = Instance.new("UICorner")
    timerCorner.CornerRadius = UDim.new(0, 8)
    timerCorner.Parent = timerLabel

    self._timerLabel = timerLabel

    -- Role display (top left)
    local roleLabel = Instance.new("TextLabel")
    roleLabel.Name = "Role"
    roleLabel.Size = UDim2.new(0, 150, 0, 40)
    roleLabel.Position = UDim2.new(0, 20, 0, 20)
    roleLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    roleLabel.BackgroundTransparency = 0.3
    roleLabel.Text = "SPECTATOR"
    roleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    roleLabel.TextSize = 24
    roleLabel.Font = Enum.Font.GothamBold
    roleLabel.Parent = hudFrame

    local roleCorner = Instance.new("UICorner")
    roleCorner.CornerRadius = UDim.new(0, 8)
    roleCorner.Parent = roleLabel

    self._roleLabel = roleLabel

    -- State display (top right)
    local stateLabel = Instance.new("TextLabel")
    stateLabel.Name = "State"
    stateLabel.Size = UDim2.new(0, 150, 0, 40)
    stateLabel.Position = UDim2.new(1, -170, 0, 20)
    stateLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    stateLabel.BackgroundTransparency = 0.3
    stateLabel.Text = "LOBBY"
    stateLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    stateLabel.TextSize = 20
    stateLabel.Font = Enum.Font.Gotham
    stateLabel.Parent = hudFrame

    local stateCorner = Instance.new("UICorner")
    stateCorner.CornerRadius = UDim.new(0, 8)
    stateCorner.Parent = stateLabel

    self._stateLabel = stateLabel
end

--[[
    Create the countdown display
]]
function UIController:_createCountdownDisplay(parent: ScreenGui)
    local countdownLabel = Instance.new("TextLabel")
    countdownLabel.Name = "Countdown"
    countdownLabel.Size = UDim2.new(0, 300, 0, 200)
    countdownLabel.Position = UDim2.new(0.5, -150, 0.3, 0)
    countdownLabel.BackgroundTransparency = 1
    countdownLabel.Text = ""
    countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    countdownLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    countdownLabel.TextStrokeTransparency = 0.5
    countdownLabel.TextSize = 120
    countdownLabel.Font = Enum.Font.GothamBold
    countdownLabel.Visible = false
    countdownLabel.Parent = parent

    self._countdownLabel = countdownLabel
end

--[[
    Create the results display
]]
function UIController:_createResultsDisplay(parent: ScreenGui)
    local resultsFrame = Instance.new("Frame")
    resultsFrame.Name = "Results"
    resultsFrame.Size = UDim2.new(0, 400, 0, 300)
    resultsFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
    resultsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    resultsFrame.BackgroundTransparency = 0.1
    resultsFrame.Visible = false
    resultsFrame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = resultsFrame

    -- Winner text
    local winnerLabel = Instance.new("TextLabel")
    winnerLabel.Name = "Winner"
    winnerLabel.Size = UDim2.new(1, 0, 0, 80)
    winnerLabel.Position = UDim2.new(0, 0, 0, 30)
    winnerLabel.BackgroundTransparency = 1
    winnerLabel.Text = "SEEKERS WIN!"
    winnerLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    winnerLabel.TextSize = 48
    winnerLabel.Font = Enum.Font.GothamBold
    winnerLabel.Parent = resultsFrame

    -- Stats text
    local statsLabel = Instance.new("TextLabel")
    statsLabel.Name = "Stats"
    statsLabel.Size = UDim2.new(1, -40, 0, 100)
    statsLabel.Position = UDim2.new(0, 20, 0, 120)
    statsLabel.BackgroundTransparency = 1
    statsLabel.Text = "0/0 Runners Frozen\nTime: 0:00"
    statsLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    statsLabel.TextSize = 24
    statsLabel.Font = Enum.Font.Gotham
    statsLabel.TextYAlignment = Enum.TextYAlignment.Top
    statsLabel.Parent = resultsFrame

    -- Next round text
    local nextLabel = Instance.new("TextLabel")
    nextLabel.Name = "NextRound"
    nextLabel.Size = UDim2.new(1, 0, 0, 30)
    nextLabel.Position = UDim2.new(0, 0, 1, -50)
    nextLabel.BackgroundTransparency = 1
    nextLabel.Text = "Next round starting soon..."
    nextLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    nextLabel.TextSize = 18
    nextLabel.Font = Enum.Font.Gotham
    nextLabel.Parent = resultsFrame

    self._resultsFrame = resultsFrame
end

--[[
    Called when game state changes
]]
function UIController:OnGameStateChanged(newState: string, oldState: string)
    if self._stateLabel then
        self._stateLabel.Text = newState
    end

    -- Hide results when leaving results state
    if oldState == Enums.GameState.RESULTS and self._resultsFrame then
        self._resultsFrame.Visible = false
    end

    -- Show/hide HUD based on state
    if self._hudFrame then
        self._hudFrame.Visible = newState ~= Enums.GameState.LOBBY
    end
end

--[[
    Handle countdown tick
]]
function UIController:_onCountdownTick(count: number)
    if not self._countdownLabel then
        return
    end

    if count > 0 then
        self._countdownLabel.Text = tostring(count)
        self._countdownLabel.Visible = true

        -- Pop animation
        self._countdownLabel.TextSize = 150
        TweenService:Create(self._countdownLabel, TweenInfo.new(0.3), {
            TextSize = 120,
        }):Play()
    else
        self._countdownLabel.Text = "GO!"
        task.delay(0.5, function()
            if self._countdownLabel then
                self._countdownLabel.Visible = false
            end
        end)
    end
end

--[[
    Handle timer update
]]
function UIController:_onTimerUpdate(remaining: number)
    if not self._timerLabel then
        return
    end

    local minutes = math.floor(remaining / 60)
    local seconds = remaining % 60
    self._timerLabel.Text = string.format("%d:%02d", minutes, seconds)

    -- Change color when low on time
    if remaining <= 30 then
        self._timerLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    elseif remaining <= 60 then
        self._timerLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    else
        self._timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

--[[
    Handle round started
]]
function UIController:_onRoundStarted(data: any)
    print("[UIController] Round started")
end

--[[
    Handle round ended
]]
function UIController:_onRoundEnded(results: any)
    if not self._resultsFrame then
        return
    end

    local winnerLabel = self._resultsFrame:FindFirstChild("Winner") :: TextLabel?
    local statsLabel = self._resultsFrame:FindFirstChild("Stats") :: TextLabel?

    if winnerLabel then
        if results.winner == Enums.WinnerTeam.Seekers then
            winnerLabel.Text = "SEEKERS WIN!"
            winnerLabel.TextColor3 = Constants.SEEKER_COLOR.Color
        else
            winnerLabel.Text = "RUNNERS WIN!"
            winnerLabel.TextColor3 = Constants.RUNNER_COLOR.Color
        end
    end

    if statsLabel then
        local minutes = math.floor(results.duration / 60)
        local seconds = math.floor(results.duration % 60)
        statsLabel.Text = string.format(
            "%d/%d Runners Frozen\nTime: %d:%02d",
            results.frozenCount,
            results.totalRunners,
            minutes,
            seconds
        )
    end

    self._resultsFrame.Visible = true
end

--[[
    Handle seeker unfrozen notification
]]
function UIController:_onSeekerUnfrozen()
    local GameStateController = Knit.GetController("GameStateController")

    if GameStateController:AmISeeker() then
        -- Flash the screen or show message that they can now move
        if self._countdownLabel then
            self._countdownLabel.Text = "HUNT!"
            self._countdownLabel.Visible = true
            task.delay(1, function()
                if self._countdownLabel then
                    self._countdownLabel.Visible = false
                end
            end)
        end
    end
end

--[[
    Update role display
]]
function UIController:_updateRoleDisplay(role: string)
    if not self._roleLabel then
        return
    end

    self._roleLabel.Text = string.upper(role)

    if role == Enums.PlayerRole.Seeker then
        self._roleLabel.TextColor3 = Constants.SEEKER_COLOR.Color
    elseif role == Enums.PlayerRole.Runner then
        self._roleLabel.TextColor3 = Constants.RUNNER_COLOR.Color
    else
        self._roleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    end
end

return UIController
