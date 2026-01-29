--!strict
--[[
    Timer.lua
    Standalone timer display component
]]

local TweenService = game:GetService("TweenService")

export type TimerObject = {
    frame: Frame,
    label: TextLabel,
    destroy: (self: TimerObject) -> (),
    setTime: (self: TimerObject, seconds: number) -> (),
    pulse: (self: TimerObject) -> (),
    setVisible: (self: TimerObject, visible: boolean) -> (),
}

local Timer = {}
Timer.__index = Timer

--[[
    Create a new timer component
    @param parent - The parent GUI element
    @return TimerObject
]]
function Timer.new(parent: GuiObject): TimerObject
    local self = setmetatable({}, Timer)

    -- Container frame
    self.frame = Instance.new("Frame")
    self.frame.Name = "TimerComponent"
    self.frame.Size = UDim2.new(0, 180, 0, 70)
    self.frame.Position = UDim2.new(0.5, -90, 0, 15)
    self.frame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    self.frame.BackgroundTransparency = 0.15
    self.frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = self.frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 80)
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = self.frame

    -- Gradient background
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 40)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 25)),
    })
    gradient.Rotation = 90
    gradient.Parent = self.frame

    -- Timer label
    self.label = Instance.new("TextLabel")
    self.label.Name = "TimeLabel"
    self.label.Size = UDim2.new(1, 0, 1, 0)
    self.label.BackgroundTransparency = 1
    self.label.Text = "3:00"
    self.label.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.label.TextSize = 42
    self.label.Font = Enum.Font.GothamBold
    self.label.Parent = self.frame

    return self :: TimerObject
end

--[[
    Set the displayed time
    @param seconds - Time in seconds
]]
function Timer:setTime(seconds: number)
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    self.label.Text = string.format("%d:%02d", minutes, secs)

    -- Update color based on urgency
    if seconds <= 10 then
        self.label.TextColor3 = Color3.fromRGB(255, 50, 50)
        -- Pulse when very low
        if seconds <= 5 then
            self:pulse()
        end
    elseif seconds <= 30 then
        self.label.TextColor3 = Color3.fromRGB(255, 100, 100)
    elseif seconds <= 60 then
        self.label.TextColor3 = Color3.fromRGB(255, 200, 100)
    else
        self.label.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

--[[
    Create a pulse animation
]]
function Timer:pulse()
    local originalSize = self.label.TextSize
    self.label.TextSize = originalSize + 8

    TweenService:Create(self.label, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextSize = originalSize,
    }):Play()
end

--[[
    Show or hide the timer
]]
function Timer:setVisible(visible: boolean)
    self.frame.Visible = visible
end

--[[
    Destroy the timer component
]]
function Timer:destroy()
    self.frame:Destroy()
end

return Timer
