--!strict
--[[
    TeamSelection.lua
    Team selection screen UI component
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

export type TeamSelectionObject = {
    frame: Frame,
    destroy: (self: TeamSelectionObject) -> (),
    show: (self: TeamSelectionObject) -> (),
    hide: (self: TeamSelectionObject) -> (),
    updateTimer: (self: TeamSelectionObject, seconds: number) -> (),
}

local TeamSelection = {}
TeamSelection.__index = TeamSelection

--[[
    Create a new team selection screen
    @param parent - The parent ScreenGui
    @return TeamSelectionObject
]]
function TeamSelection.new(parent: ScreenGui): TeamSelectionObject
    local self = setmetatable({}, TeamSelection)

    -- Main frame (fullscreen overlay)
    self.frame = Instance.new("Frame")
    self.frame.Name = "TeamSelection"
    self.frame.Size = UDim2.new(1, 0, 1, 0)
    self.frame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    self.frame.BackgroundTransparency = 0.3
    self.frame.Visible = false
    self.frame.Parent = parent

    -- Content container
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(0, 500, 0, 400)
    container.Position = UDim2.new(0.5, -250, 0.5, -200)
    container.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    container.BackgroundTransparency = 0.1
    container.Parent = self.frame

    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 20)
    containerCorner.Parent = container

    local containerStroke = Instance.new("UIStroke")
    containerStroke.Color = Color3.fromRGB(80, 80, 100)
    containerStroke.Thickness = 2
    containerStroke.Parent = container

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 60)
    title.Position = UDim2.new(0, 0, 0, 20)
    title.BackgroundTransparency = 1
    title.Text = "PREPARING ROUND"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 36
    title.Font = Enum.Font.GothamBold
    title.Parent = container

    -- Subtitle
    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Size = UDim2.new(1, 0, 0, 30)
    subtitle.Position = UDim2.new(0, 0, 0, 75)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Teams will be assigned randomly"
    subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
    subtitle.TextSize = 20
    subtitle.Font = Enum.Font.Gotham
    subtitle.Parent = container

    -- Team display row
    local teamsRow = Instance.new("Frame")
    teamsRow.Name = "TeamsRow"
    teamsRow.Size = UDim2.new(1, -60, 0, 150)
    teamsRow.Position = UDim2.new(0, 30, 0, 130)
    teamsRow.BackgroundTransparency = 1
    teamsRow.Parent = container

    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    rowLayout.Padding = UDim.new(0, 40)
    rowLayout.Parent = teamsRow

    -- Seeker team display
    local seekerFrame = Instance.new("Frame")
    seekerFrame.Name = "Seekers"
    seekerFrame.Size = UDim2.new(0, 180, 1, 0)
    seekerFrame.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
    seekerFrame.Parent = teamsRow

    local seekerCorner = Instance.new("UICorner")
    seekerCorner.CornerRadius = UDim.new(0, 12)
    seekerCorner.Parent = seekerFrame

    local seekerLabel = Instance.new("TextLabel")
    seekerLabel.Size = UDim2.new(1, 0, 0, 40)
    seekerLabel.Position = UDim2.new(0, 0, 0, 15)
    seekerLabel.BackgroundTransparency = 1
    seekerLabel.Text = "SEEKERS"
    seekerLabel.TextColor3 = Constants.SEEKER_COLOR.Color
    seekerLabel.TextSize = 24
    seekerLabel.Font = Enum.Font.GothamBold
    seekerLabel.Parent = seekerFrame

    local seekerIcon = Instance.new("TextLabel")
    seekerIcon.Size = UDim2.new(1, 0, 0, 50)
    seekerIcon.Position = UDim2.new(0, 0, 0, 55)
    seekerIcon.BackgroundTransparency = 1
    seekerIcon.Text = "🔦"
    seekerIcon.TextSize = 40
    seekerIcon.Parent = seekerFrame

    local seekerDesc = Instance.new("TextLabel")
    seekerDesc.Size = UDim2.new(1, -20, 0, 40)
    seekerDesc.Position = UDim2.new(0, 10, 1, -50)
    seekerDesc.BackgroundTransparency = 1
    seekerDesc.Text = "Freeze the runners!"
    seekerDesc.TextColor3 = Color3.fromRGB(200, 200, 200)
    seekerDesc.TextSize = 14
    seekerDesc.Font = Enum.Font.Gotham
    seekerDesc.TextWrapped = true
    seekerDesc.Parent = seekerFrame

    -- Runner team display
    local runnerFrame = Instance.new("Frame")
    runnerFrame.Name = "Runners"
    runnerFrame.Size = UDim2.new(0, 180, 1, 0)
    runnerFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
    runnerFrame.Parent = teamsRow

    local runnerCorner = Instance.new("UICorner")
    runnerCorner.CornerRadius = UDim.new(0, 12)
    runnerCorner.Parent = runnerFrame

    local runnerLabel = Instance.new("TextLabel")
    runnerLabel.Size = UDim2.new(1, 0, 0, 40)
    runnerLabel.Position = UDim2.new(0, 0, 0, 15)
    runnerLabel.BackgroundTransparency = 1
    runnerLabel.Text = "RUNNERS"
    runnerLabel.TextColor3 = Constants.RUNNER_COLOR.Color
    runnerLabel.TextSize = 24
    runnerLabel.Font = Enum.Font.GothamBold
    runnerLabel.Parent = runnerFrame

    local runnerIcon = Instance.new("TextLabel")
    runnerIcon.Size = UDim2.new(1, 0, 0, 50)
    runnerIcon.Position = UDim2.new(0, 0, 0, 55)
    runnerIcon.BackgroundTransparency = 1
    runnerIcon.Text = "🏃"
    runnerIcon.TextSize = 40
    runnerIcon.Parent = runnerFrame

    local runnerDesc = Instance.new("TextLabel")
    runnerDesc.Size = UDim2.new(1, -20, 0, 40)
    runnerDesc.Position = UDim2.new(0, 10, 1, -50)
    runnerDesc.BackgroundTransparency = 1
    runnerDesc.Text = "Hide and rescue friends!"
    runnerDesc.TextColor3 = Color3.fromRGB(200, 200, 200)
    runnerDesc.TextSize = 14
    runnerDesc.Font = Enum.Font.Gotham
    runnerDesc.TextWrapped = true
    runnerDesc.Parent = runnerFrame

    -- Timer
    self._timerLabel = Instance.new("TextLabel")
    self._timerLabel.Name = "Timer"
    self._timerLabel.Size = UDim2.new(1, 0, 0, 50)
    self._timerLabel.Position = UDim2.new(0, 0, 1, -70)
    self._timerLabel.BackgroundTransparency = 1
    self._timerLabel.Text = "Starting in 15..."
    self._timerLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    self._timerLabel.TextSize = 28
    self._timerLabel.Font = Enum.Font.GothamBold
    self._timerLabel.Parent = container

    return self :: TeamSelectionObject
end

--[[
    Show the team selection screen
]]
function TeamSelection:show()
    self.frame.Visible = true
    self.frame.BackgroundTransparency = 1

    TweenService:Create(self.frame, TweenInfo.new(0.3), {
        BackgroundTransparency = 0.3,
    }):Play()
end

--[[
    Hide the team selection screen
]]
function TeamSelection:hide()
    TweenService:Create(self.frame, TweenInfo.new(0.3), {
        BackgroundTransparency = 1,
    }):Play()

    task.delay(0.3, function()
        self.frame.Visible = false
    end)
end

--[[
    Update the countdown timer
]]
function TeamSelection:updateTimer(seconds: number)
    if self._timerLabel then
        self._timerLabel.Text = string.format("Starting in %d...", seconds)
    end
end

--[[
    Destroy the component
]]
function TeamSelection:destroy()
    self.frame:Destroy()
end

return TeamSelection
