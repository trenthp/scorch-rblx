--!strict
--[[
    BoundaryController.lua
    Client-side boundary zone effects
    - Frost overlay that intensifies as cold increases
    - Movement slowdown as cold builds
    - Warning indicators
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

local LocalPlayer = Players.LocalPlayer

local BoundaryController = Knit.CreateController({
    Name = "BoundaryController",

    _currentCold = 0,
    _frostGui = nil :: ScreenGui?,
    _frostFrame = nil :: Frame?,
    _warningText = nil :: TextLabel?,
    _originalWalkSpeed = nil :: number?,
})

function BoundaryController:KnitInit()
    self:_createFrostOverlay()
    print("[BoundaryController] Initialized")
end

function BoundaryController:KnitStart()
    local BoundaryService = Knit.GetService("BoundaryService")

    -- Listen for cold updates
    BoundaryService.ColdUpdated:Connect(function(coldLevel: number)
        self:_onColdUpdated(coldLevel)
    end)

    -- Store original walk speed on character spawn
    LocalPlayer.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
        if humanoid then
            self._originalWalkSpeed = humanoid.WalkSpeed
        end
    end)

    if LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            self._originalWalkSpeed = humanoid.WalkSpeed
        end
    end

    print("[BoundaryController] Started")
end

--[[
    Create the frost overlay UI
]]
function BoundaryController:_createFrostOverlay()
    local gui = Instance.new("ScreenGui")
    gui.Name = "BoundaryFrost"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 10

    -- Frost overlay frame (ice blue tint from edges)
    local frostFrame = Instance.new("Frame")
    frostFrame.Name = "FrostOverlay"
    frostFrame.Size = UDim2.fromScale(1, 1)
    frostFrame.Position = UDim2.fromScale(0, 0)
    frostFrame.BackgroundColor3 = Color3.fromRGB(180, 220, 255)
    frostFrame.BackgroundTransparency = 1 -- Start invisible
    frostFrame.BorderSizePixel = 0
    frostFrame.Parent = gui

    -- Gradient for vignette effect (frost from edges)
    local gradient = Instance.new("UIGradient")
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.3, 0.5),
        NumberSequenceKeypoint.new(0.5, 1),
        NumberSequenceKeypoint.new(0.7, 0.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    gradient.Parent = frostFrame

    -- Warning text
    local warningText = Instance.new("TextLabel")
    warningText.Name = "WarningText"
    warningText.Size = UDim2.fromScale(1, 0.1)
    warningText.Position = UDim2.fromScale(0, 0.15)
    warningText.BackgroundTransparency = 1
    warningText.Font = Enum.Font.GothamBold
    warningText.TextSize = 28
    warningText.TextColor3 = Color3.fromRGB(200, 230, 255)
    warningText.TextStrokeColor3 = Color3.fromRGB(0, 50, 100)
    warningText.TextStrokeTransparency = 0.5
    warningText.Text = "FREEZING - RETURN TO PLAY AREA"
    warningText.TextTransparency = 1 -- Start invisible
    warningText.Parent = gui

    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    self._frostGui = gui
    self._frostFrame = frostFrame
    self._warningText = warningText
end

--[[
    Handle cold level updates
]]
function BoundaryController:_onColdUpdated(coldLevel: number)
    self._currentCold = coldLevel

    -- Update frost overlay
    self:_updateFrostOverlay(coldLevel)

    -- Update movement speed
    self:_updateMovementSpeed(coldLevel)

    -- Update warning text
    self:_updateWarningText(coldLevel)
end

--[[
    Update the frost overlay transparency based on cold level
]]
function BoundaryController:_updateFrostOverlay(coldLevel: number)
    if not self._frostFrame then
        return
    end

    -- Map cold (0-100) to transparency (1-0.3)
    -- At 0% cold: fully transparent (1)
    -- At 100% cold: fairly opaque (0.3)
    local targetTransparency = 1 - (coldLevel / 100) * 0.7

    -- Add pulsing effect when cold is high
    if coldLevel > 50 then
        local pulse = math.sin(tick() * 3) * 0.1 * (coldLevel / 100)
        targetTransparency = targetTransparency - pulse
    end

    targetTransparency = math.clamp(targetTransparency, 0.3, 1)

    -- Smooth transition
    local tween = TweenService:Create(
        self._frostFrame,
        TweenInfo.new(0.2, Enum.EasingStyle.Linear),
        { BackgroundTransparency = targetTransparency }
    )
    tween:Play()
end

--[[
    Slow down player movement as cold increases
]]
function BoundaryController:_updateMovementSpeed(coldLevel: number)
    local character = LocalPlayer.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    -- Get base walk speed (use stored original or current if not crouching)
    local baseSpeed = self._originalWalkSpeed or 16

    -- Apply Speed power-up multiplier if active
    local BatteryController = Knit.GetController("BatteryController")
    if BatteryController and BatteryController:HasEffect("Speed") then
        local speedMult = BatteryController:GetEffectMultiplier("Speed")
        baseSpeed = baseSpeed * speedMult
    end

    -- Check if crouching (already reduced speed)
    local CrouchController = Knit.GetController("CrouchController")
    if CrouchController and CrouchController:IsCrouching() then
        baseSpeed = baseSpeed * Constants.CROUCH.SPEED_MULTIPLIER
    end

    -- Reduce speed based on cold (0% = full speed, 100% = 20% speed)
    local speedMultiplier = 1 - (coldLevel / 100) * 0.8
    speedMultiplier = math.clamp(speedMultiplier, 0.2, 1)

    humanoid.WalkSpeed = baseSpeed * speedMultiplier
end

--[[
    Show/hide warning text based on cold level
]]
function BoundaryController:_updateWarningText(coldLevel: number)
    if not self._warningText then
        return
    end

    if coldLevel > 0 then
        -- Show warning with pulsing opacity
        local pulse = (math.sin(tick() * 4) + 1) / 2 -- 0 to 1
        local baseTransparency = 0.3
        local targetTransparency = baseTransparency + pulse * 0.3

        self._warningText.TextTransparency = targetTransparency
        self._warningText.TextStrokeTransparency = targetTransparency + 0.2

        -- Update text based on severity
        if coldLevel > 75 then
            self._warningText.Text = "CRITICAL - FREEZING IMMINENT"
            self._warningText.TextColor3 = Color3.fromRGB(255, 150, 150)
        elseif coldLevel > 50 then
            self._warningText.Text = "WARNING - FREEZING RAPIDLY"
            self._warningText.TextColor3 = Color3.fromRGB(255, 200, 150)
        else
            self._warningText.Text = "FREEZING - RETURN TO PLAY AREA"
            self._warningText.TextColor3 = Color3.fromRGB(200, 230, 255)
        end
    else
        -- Hide warning
        self._warningText.TextTransparency = 1
        self._warningText.TextStrokeTransparency = 1
    end
end

--[[
    Get current cold level
]]
function BoundaryController:GetCold(): number
    return self._currentCold
end

return BoundaryController
