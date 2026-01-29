--!strict
--[[
    HUD.lua
    Creates and manages the main heads-up display
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

export type HUDObject = {
    frame: Frame,
    timerLabel: TextLabel,
    roleLabel: TextLabel,
    frozenCountLabel: TextLabel,
    destroy: (self: HUDObject) -> (),
    updateTimer: (self: HUDObject, seconds: number) -> (),
    updateRole: (self: HUDObject, role: string) -> (),
    updateFrozenCount: (self: HUDObject, frozen: number, total: number) -> (),
    setVisible: (self: HUDObject, visible: boolean) -> (),
}

local HUD = {}
HUD.__index = HUD

--[[
    Create a new HUD instance
    @param parent - The ScreenGui to parent the HUD to
    @return HUDObject
]]
function HUD.new(parent: ScreenGui): HUDObject
    local self = setmetatable({}, HUD)

    -- Main frame
    self.frame = Instance.new("Frame")
    self.frame.Name = "HUD"
    self.frame.Size = UDim2.new(1, 0, 1, 0)
    self.frame.BackgroundTransparency = 1
    self.frame.Parent = parent

    -- Timer (top center)
    local timerContainer = Instance.new("Frame")
    timerContainer.Name = "TimerContainer"
    timerContainer.Size = UDim2.new(0, 160, 0, 60)
    timerContainer.Position = UDim2.new(0.5, -80, 0, 20)
    timerContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    timerContainer.BackgroundTransparency = 0.2
    timerContainer.Parent = self.frame

    local timerCorner = Instance.new("UICorner")
    timerCorner.CornerRadius = UDim.new(0, 12)
    timerCorner.Parent = timerContainer

    local timerStroke = Instance.new("UIStroke")
    timerStroke.Color = Color3.fromRGB(80, 80, 100)
    timerStroke.Thickness = 2
    timerStroke.Parent = timerContainer

    self.timerLabel = Instance.new("TextLabel")
    self.timerLabel.Name = "Timer"
    self.timerLabel.Size = UDim2.new(1, 0, 1, 0)
    self.timerLabel.BackgroundTransparency = 1
    self.timerLabel.Text = "3:00"
    self.timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.timerLabel.TextSize = 36
    self.timerLabel.Font = Enum.Font.GothamBold
    self.timerLabel.Parent = timerContainer

    -- Role indicator (top left)
    local roleContainer = Instance.new("Frame")
    roleContainer.Name = "RoleContainer"
    roleContainer.Size = UDim2.new(0, 140, 0, 45)
    roleContainer.Position = UDim2.new(0, 20, 0, 20)
    roleContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    roleContainer.BackgroundTransparency = 0.2
    roleContainer.Parent = self.frame

    local roleCorner = Instance.new("UICorner")
    roleCorner.CornerRadius = UDim.new(0, 10)
    roleCorner.Parent = roleContainer

    self.roleLabel = Instance.new("TextLabel")
    self.roleLabel.Name = "Role"
    self.roleLabel.Size = UDim2.new(1, 0, 1, 0)
    self.roleLabel.BackgroundTransparency = 1
    self.roleLabel.Text = "SPECTATOR"
    self.roleLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    self.roleLabel.TextSize = 22
    self.roleLabel.Font = Enum.Font.GothamBold
    self.roleLabel.Parent = roleContainer

    -- Frozen count (top right)
    local frozenContainer = Instance.new("Frame")
    frozenContainer.Name = "FrozenContainer"
    frozenContainer.Size = UDim2.new(0, 120, 0, 45)
    frozenContainer.Position = UDim2.new(1, -140, 0, 20)
    frozenContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frozenContainer.BackgroundTransparency = 0.2
    frozenContainer.Parent = self.frame

    local frozenCorner = Instance.new("UICorner")
    frozenCorner.CornerRadius = UDim.new(0, 10)
    frozenCorner.Parent = frozenContainer

    local frozenIcon = Instance.new("TextLabel")
    frozenIcon.Name = "Icon"
    frozenIcon.Size = UDim2.new(0, 30, 1, 0)
    frozenIcon.Position = UDim2.new(0, 5, 0, 0)
    frozenIcon.BackgroundTransparency = 1
    frozenIcon.Text = "❄"
    frozenIcon.TextColor3 = Constants.FREEZE_COLOR
    frozenIcon.TextSize = 24
    frozenIcon.Parent = frozenContainer

    self.frozenCountLabel = Instance.new("TextLabel")
    self.frozenCountLabel.Name = "Count"
    self.frozenCountLabel.Size = UDim2.new(1, -40, 1, 0)
    self.frozenCountLabel.Position = UDim2.new(0, 35, 0, 0)
    self.frozenCountLabel.BackgroundTransparency = 1
    self.frozenCountLabel.Text = "0/0"
    self.frozenCountLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
    self.frozenCountLabel.TextSize = 22
    self.frozenCountLabel.Font = Enum.Font.GothamBold
    self.frozenCountLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.frozenCountLabel.Parent = frozenContainer

    return self :: HUDObject
end

--[[
    Update the timer display
    @param seconds - Remaining seconds
]]
function HUD:updateTimer(seconds: number)
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    self.timerLabel.Text = string.format("%d:%02d", minutes, secs)

    -- Color based on time remaining
    if seconds <= 30 then
        self.timerLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    elseif seconds <= 60 then
        self.timerLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
    else
        self.timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

--[[
    Update the role display
    @param role - The player's role
]]
function HUD:updateRole(role: string)
    self.roleLabel.Text = string.upper(role)

    if role == Enums.PlayerRole.Seeker then
        self.roleLabel.TextColor3 = Constants.SEEKER_COLOR.Color
    elseif role == Enums.PlayerRole.Runner then
        self.roleLabel.TextColor3 = Constants.RUNNER_COLOR.Color
    else
        self.roleLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    end
end

--[[
    Update the frozen count display
    @param frozen - Number of frozen runners
    @param total - Total number of runners
]]
function HUD:updateFrozenCount(frozen: number, total: number)
    self.frozenCountLabel.Text = string.format("%d/%d", frozen, total)
end

--[[
    Show or hide the HUD
]]
function HUD:setVisible(visible: boolean)
    self.frame.Visible = visible
end

--[[
    Destroy the HUD
]]
function HUD:destroy()
    self.frame:Destroy()
end

return HUD
