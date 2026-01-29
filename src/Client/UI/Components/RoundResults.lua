--!strict
--[[
    RoundResults.lua
    Round results display UI component
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

export type RoundResultsObject = {
    frame: Frame,
    destroy: (self: RoundResultsObject) -> (),
    show: (self: RoundResultsObject, results: ResultsData) -> (),
    hide: (self: RoundResultsObject) -> (),
}

export type ResultsData = {
    winner: string,
    reason: string,
    frozenCount: number,
    totalRunners: number,
    duration: number,
}

local RoundResults = {}
RoundResults.__index = RoundResults

--[[
    Create a new round results screen
    @param parent - The parent ScreenGui
    @return RoundResultsObject
]]
function RoundResults.new(parent: ScreenGui): RoundResultsObject
    local self = setmetatable({}, RoundResults)

    -- Main frame (fullscreen overlay)
    self.frame = Instance.new("Frame")
    self.frame.Name = "RoundResults"
    self.frame.Size = UDim2.new(1, 0, 1, 0)
    self.frame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    self.frame.BackgroundTransparency = 0.2
    self.frame.Visible = false
    self.frame.Parent = parent

    -- Content container
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(0, 450, 0, 350)
    container.Position = UDim2.new(0.5, -225, 0.5, -175)
    container.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    container.BackgroundTransparency = 0.05
    container.Parent = self.frame

    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 20)
    containerCorner.Parent = container

    local containerStroke = Instance.new("UIStroke")
    containerStroke.Color = Color3.fromRGB(100, 100, 120)
    containerStroke.Thickness = 3
    containerStroke.Parent = container

    -- Winner text
    self._winnerLabel = Instance.new("TextLabel")
    self._winnerLabel.Name = "Winner"
    self._winnerLabel.Size = UDim2.new(1, 0, 0, 80)
    self._winnerLabel.Position = UDim2.new(0, 0, 0, 30)
    self._winnerLabel.BackgroundTransparency = 1
    self._winnerLabel.Text = "SEEKERS WIN!"
    self._winnerLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    self._winnerLabel.TextSize = 48
    self._winnerLabel.Font = Enum.Font.GothamBold
    self._winnerLabel.Parent = container

    -- Reason text
    self._reasonLabel = Instance.new("TextLabel")
    self._reasonLabel.Name = "Reason"
    self._reasonLabel.Size = UDim2.new(1, 0, 0, 30)
    self._reasonLabel.Position = UDim2.new(0, 0, 0, 100)
    self._reasonLabel.BackgroundTransparency = 1
    self._reasonLabel.Text = "All runners were frozen!"
    self._reasonLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    self._reasonLabel.TextSize = 20
    self._reasonLabel.Font = Enum.Font.Gotham
    self._reasonLabel.Parent = container

    -- Stats container
    local statsContainer = Instance.new("Frame")
    statsContainer.Name = "Stats"
    statsContainer.Size = UDim2.new(1, -60, 0, 100)
    statsContainer.Position = UDim2.new(0, 30, 0, 150)
    statsContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    statsContainer.Parent = container

    local statsCorner = Instance.new("UICorner")
    statsCorner.CornerRadius = UDim.new(0, 12)
    statsCorner.Parent = statsContainer

    -- Frozen count stat
    local frozenStatFrame = Instance.new("Frame")
    frozenStatFrame.Size = UDim2.new(0.5, 0, 1, 0)
    frozenStatFrame.BackgroundTransparency = 1
    frozenStatFrame.Parent = statsContainer

    local frozenIcon = Instance.new("TextLabel")
    frozenIcon.Size = UDim2.new(1, 0, 0, 40)
    frozenIcon.Position = UDim2.new(0, 0, 0, 10)
    frozenIcon.BackgroundTransparency = 1
    frozenIcon.Text = "❄"
    frozenIcon.TextSize = 32
    frozenIcon.Parent = frozenStatFrame

    self._frozenLabel = Instance.new("TextLabel")
    self._frozenLabel.Size = UDim2.new(1, 0, 0, 30)
    self._frozenLabel.Position = UDim2.new(0, 0, 0, 50)
    self._frozenLabel.BackgroundTransparency = 1
    self._frozenLabel.Text = "0/0 Frozen"
    self._frozenLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
    self._frozenLabel.TextSize = 18
    self._frozenLabel.Font = Enum.Font.GothamBold
    self._frozenLabel.Parent = frozenStatFrame

    -- Time stat
    local timeStatFrame = Instance.new("Frame")
    timeStatFrame.Size = UDim2.new(0.5, 0, 1, 0)
    timeStatFrame.Position = UDim2.new(0.5, 0, 0, 0)
    timeStatFrame.BackgroundTransparency = 1
    timeStatFrame.Parent = statsContainer

    local timeIcon = Instance.new("TextLabel")
    timeIcon.Size = UDim2.new(1, 0, 0, 40)
    timeIcon.Position = UDim2.new(0, 0, 0, 10)
    timeIcon.BackgroundTransparency = 1
    timeIcon.Text = "⏱"
    timeIcon.TextSize = 32
    timeIcon.Parent = timeStatFrame

    self._timeLabel = Instance.new("TextLabel")
    self._timeLabel.Size = UDim2.new(1, 0, 0, 30)
    self._timeLabel.Position = UDim2.new(0, 0, 0, 50)
    self._timeLabel.BackgroundTransparency = 1
    self._timeLabel.Text = "0:00"
    self._timeLabel.TextColor3 = Color3.fromRGB(255, 220, 150)
    self._timeLabel.TextSize = 18
    self._timeLabel.Font = Enum.Font.GothamBold
    self._timeLabel.Parent = timeStatFrame

    -- Next round text
    local nextLabel = Instance.new("TextLabel")
    nextLabel.Name = "NextRound"
    nextLabel.Size = UDim2.new(1, 0, 0, 30)
    nextLabel.Position = UDim2.new(0, 0, 1, -50)
    nextLabel.BackgroundTransparency = 1
    nextLabel.Text = "Next round starting soon..."
    nextLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    nextLabel.TextSize = 16
    nextLabel.Font = Enum.Font.Gotham
    nextLabel.Parent = container

    return self :: RoundResultsObject
end

--[[
    Show the results screen with data
    @param results - The round results data
]]
function RoundResults:show(results: ResultsData)
    -- Update winner text
    if results.winner == Enums.WinnerTeam.Seekers then
        self._winnerLabel.Text = "SEEKERS WIN!"
        self._winnerLabel.TextColor3 = Constants.SEEKER_COLOR.Color
    else
        self._winnerLabel.Text = "RUNNERS WIN!"
        self._winnerLabel.TextColor3 = Constants.RUNNER_COLOR.Color
    end

    -- Update reason text
    local reasonText = "Round complete!"
    if results.reason == Enums.RoundEndReason.AllFrozen then
        reasonText = "All runners were frozen!"
    elseif results.reason == Enums.RoundEndReason.TimeUp then
        reasonText = "Time ran out!"
    elseif results.reason == Enums.RoundEndReason.SeekersDisconnected then
        reasonText = "All seekers left the game"
    elseif results.reason == Enums.RoundEndReason.RunnersDisconnected then
        reasonText = "All runners left the game"
    end
    self._reasonLabel.Text = reasonText

    -- Update stats
    self._frozenLabel.Text = string.format("%d/%d Frozen", results.frozenCount, results.totalRunners)

    local minutes = math.floor(results.duration / 60)
    local seconds = math.floor(results.duration % 60)
    self._timeLabel.Text = string.format("%d:%02d", minutes, seconds)

    -- Show with animation
    self.frame.Visible = true
    self.frame.BackgroundTransparency = 1

    TweenService:Create(self.frame, TweenInfo.new(0.4), {
        BackgroundTransparency = 0.2,
    }):Play()

    -- Animate winner text
    self._winnerLabel.TextSize = 60
    TweenService:Create(self._winnerLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        TextSize = 48,
    }):Play()
end

--[[
    Hide the results screen
]]
function RoundResults:hide()
    TweenService:Create(self.frame, TweenInfo.new(0.3), {
        BackgroundTransparency = 1,
    }):Play()

    task.delay(0.3, function()
        self.frame.Visible = false
    end)
end

--[[
    Destroy the component
]]
function RoundResults:destroy()
    self.frame:Destroy()
end

return RoundResults
