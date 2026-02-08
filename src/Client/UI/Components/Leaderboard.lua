--!strict
--[[
    Leaderboard.lua
    Session leaderboard display showing top seekers and rescuers
    Shown during lobby and results phases
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))

export type LeaderboardObject = {
    frame: Frame,
    destroy: (self: LeaderboardObject) -> (),
    update: (self: LeaderboardObject, data: LeaderboardData) -> (),
    setVisible: (self: LeaderboardObject, visible: boolean) -> (),
    toggleMode: (self: LeaderboardObject) -> (),
}

export type LeaderboardEntry = {
    name: string,
    displayName: string,
    userId: number,
    freezes: number?,
    rescues: number?,
}

export type LeaderboardData = {
    topSeekers: { LeaderboardEntry },
    topRescuers: { LeaderboardEntry },
}

local Leaderboard = {}
Leaderboard.__index = Leaderboard

--[[
    Create a new leaderboard display
    @param parent - The parent ScreenGui
    @return LeaderboardObject
]]
function Leaderboard.new(parent: ScreenGui): LeaderboardObject
    local self = setmetatable({}, Leaderboard)

    self._mode = "seekers" -- "seekers" or "rescuers"

    -- Main frame (top right corner)
    self.frame = Instance.new("Frame")
    self.frame.Name = "Leaderboard"
    self.frame.Size = UDim2.new(0, 220, 0, 260)
    self.frame.Position = UDim2.new(1, -240, 0, 20)
    self.frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    self.frame.BackgroundTransparency = 0.15
    self.frame.Visible = false
    self.frame.Parent = parent

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 12)
    frameCorner.Parent = self.frame

    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Color3.fromRGB(80, 80, 100)
    frameStroke.Thickness = 2
    frameStroke.Parent = self.frame

    -- Header with toggle buttons
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundTransparency = 1
    header.Parent = self.frame

    -- Seekers tab button
    self._seekersTab = Instance.new("TextButton")
    self._seekersTab.Name = "SeekersTab"
    self._seekersTab.Size = UDim2.new(0.5, -5, 0, 30)
    self._seekersTab.Position = UDim2.new(0, 5, 0, 5)
    self._seekersTab.BackgroundColor3 = Color3.fromRGB(180, 80, 80)
    self._seekersTab.Text = "Top Seekers"
    self._seekersTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    self._seekersTab.TextSize = 12
    self._seekersTab.Font = Enum.Font.GothamBold
    self._seekersTab.Parent = header

    local seekersCorner = Instance.new("UICorner")
    seekersCorner.CornerRadius = UDim.new(0, 6)
    seekersCorner.Parent = self._seekersTab

    -- Rescuers tab button
    self._rescuersTab = Instance.new("TextButton")
    self._rescuersTab.Name = "RescuersTab"
    self._rescuersTab.Size = UDim2.new(0.5, -5, 0, 30)
    self._rescuersTab.Position = UDim2.new(0.5, 0, 0, 5)
    self._rescuersTab.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    self._rescuersTab.Text = "Top Rescuers"
    self._rescuersTab.TextColor3 = Color3.fromRGB(180, 180, 180)
    self._rescuersTab.TextSize = 12
    self._rescuersTab.Font = Enum.Font.GothamBold
    self._rescuersTab.Parent = header

    local rescuersCorner = Instance.new("UICorner")
    rescuersCorner.CornerRadius = UDim.new(0, 6)
    rescuersCorner.Parent = self._rescuersTab

    -- Entries container
    self._entriesContainer = Instance.new("Frame")
    self._entriesContainer.Name = "Entries"
    self._entriesContainer.Size = UDim2.new(1, -20, 1, -50)
    self._entriesContainer.Position = UDim2.new(0, 10, 0, 45)
    self._entriesContainer.BackgroundTransparency = 1
    self._entriesContainer.Parent = self.frame

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = self._entriesContainer

    -- Create entry frames
    self._entryFrames = {}
    for i = 1, 5 do
        local entry = self:_createEntryFrame(i)
        entry.Parent = self._entriesContainer
        table.insert(self._entryFrames, entry)
    end

    -- Tab click handlers
    self._seekersTab.MouseButton1Click:Connect(function()
        self._mode = "seekers"
        self:_updateTabs()
        self:_refreshDisplay()
    end)

    self._rescuersTab.MouseButton1Click:Connect(function()
        self._mode = "rescuers"
        self:_updateTabs()
        self:_refreshDisplay()
    end)

    self._data = nil :: LeaderboardData?

    return self :: LeaderboardObject
end

--[[
    Create an entry frame for a leaderboard position
]]
function Leaderboard:_createEntryFrame(rank: number): Frame
    local frame = Instance.new("Frame")
    frame.Name = "Entry" .. rank
    frame.Size = UDim2.new(1, 0, 0, 36)
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    frame.BackgroundTransparency = 0.3
    frame.LayoutOrder = rank

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    -- Rank badge
    local rankBadge = Instance.new("Frame")
    rankBadge.Name = "RankBadge"
    rankBadge.Size = UDim2.new(0, 24, 0, 24)
    rankBadge.Position = UDim2.new(0, 6, 0.5, -12)
    rankBadge.BackgroundColor3 = self:_getRankColor(rank)
    rankBadge.Parent = frame

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0.5, 0)
    badgeCorner.Parent = rankBadge

    local rankLabel = Instance.new("TextLabel")
    rankLabel.Name = "RankNumber"
    rankLabel.Size = UDim2.new(1, 0, 1, 0)
    rankLabel.BackgroundTransparency = 1
    rankLabel.Text = tostring(rank)
    rankLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    rankLabel.TextSize = 12
    rankLabel.Font = Enum.Font.GothamBold
    rankLabel.Parent = rankBadge

    -- Player name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "PlayerName"
    nameLabel.Size = UDim2.new(1, -80, 1, 0)
    nameLabel.Position = UDim2.new(0, 36, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "---"
    nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    nameLabel.TextSize = 14
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = frame

    -- Score
    local scoreLabel = Instance.new("TextLabel")
    scoreLabel.Name = "Score"
    scoreLabel.Size = UDim2.new(0, 40, 1, 0)
    scoreLabel.Position = UDim2.new(1, -46, 0, 0)
    scoreLabel.BackgroundTransparency = 1
    scoreLabel.Text = "0"
    scoreLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
    scoreLabel.TextSize = 16
    scoreLabel.Font = Enum.Font.GothamBold
    scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
    scoreLabel.Parent = frame

    return frame
end

--[[
    Get the color for a rank badge
]]
function Leaderboard:_getRankColor(rank: number): Color3
    if rank == 1 then
        return Color3.fromRGB(255, 215, 0) -- Gold
    elseif rank == 2 then
        return Color3.fromRGB(192, 192, 192) -- Silver
    elseif rank == 3 then
        return Color3.fromRGB(205, 127, 50) -- Bronze
    else
        return Color3.fromRGB(80, 80, 100) -- Default
    end
end

--[[
    Update tab appearance based on current mode
]]
function Leaderboard:_updateTabs()
    if self._mode == "seekers" then
        self._seekersTab.BackgroundColor3 = Color3.fromRGB(180, 80, 80)
        self._seekersTab.TextColor3 = Color3.fromRGB(255, 255, 255)
        self._rescuersTab.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        self._rescuersTab.TextColor3 = Color3.fromRGB(180, 180, 180)
    else
        self._seekersTab.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        self._seekersTab.TextColor3 = Color3.fromRGB(180, 180, 180)
        self._rescuersTab.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
        self._rescuersTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

--[[
    Refresh the display with current data and mode
]]
function Leaderboard:_refreshDisplay()
    if not self._data then
        return
    end

    local entries = if self._mode == "seekers" then self._data.topSeekers else self._data.topRescuers

    for i, frame in self._entryFrames do
        local entry = entries[i]
        local nameLabel = frame:FindFirstChild("PlayerName") :: TextLabel
        local scoreLabel = frame:FindFirstChild("Score") :: TextLabel

        if entry then
            nameLabel.Text = entry.displayName or entry.name
            if self._mode == "seekers" then
                scoreLabel.Text = tostring(entry.freezes or 0)
                scoreLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
            else
                scoreLabel.Text = tostring(entry.rescues or 0)
                scoreLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
            end
            frame.BackgroundTransparency = 0.3
        else
            nameLabel.Text = "---"
            scoreLabel.Text = "-"
            scoreLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
            frame.BackgroundTransparency = 0.6
        end
    end
end

--[[
    Update the leaderboard with new data
    @param data - The leaderboard data
]]
function Leaderboard:update(data: LeaderboardData)
    self._data = data
    self:_refreshDisplay()
end

--[[
    Toggle between seekers and rescuers mode
]]
function Leaderboard:toggleMode()
    self._mode = if self._mode == "seekers" then "rescuers" else "seekers"
    self:_updateTabs()
    self:_refreshDisplay()
end

--[[
    Set visibility
    @param visible - Whether to show the leaderboard
]]
function Leaderboard:setVisible(visible: boolean)
    if visible then
        self.frame.Visible = true
        self.frame.BackgroundTransparency = 1
        TweenService:Create(self.frame, TweenInfo.new(0.3), {
            BackgroundTransparency = 0.15,
        }):Play()
    else
        TweenService:Create(self.frame, TweenInfo.new(0.2), {
            BackgroundTransparency = 1,
        }):Play()
        task.delay(0.2, function()
            self.frame.Visible = false
        end)
    end
end

--[[
    Destroy the component
]]
function Leaderboard:destroy()
    self.frame:Destroy()
end

return Leaderboard
