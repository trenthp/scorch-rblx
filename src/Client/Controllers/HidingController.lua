--!strict
--[[
    HidingController.lua
    Handles client-side hiding bush effects:
    - Visual tint when inside a bush
    - Audio cues for entering/exiting
    - Time limit for hiding in one spot
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

local LocalPlayer = Players.LocalPlayer

local HidingController = Knit.CreateController({
    Name = "HidingController",

    _isHiding = false,
    _currentBush = nil :: Model?,
    _hideStartTime = 0,
    _checkLoop = nil :: thread?,

    -- Visual effect instances
    _hidingGui = nil :: ScreenGui?,
    _vignetteFrame = nil :: Frame?,
    _warningFrame = nil :: Frame?,

    -- Audio
    _enterSound = nil :: Sound?,
    _exitSound = nil :: Sound?,
    _warningSound = nil :: Sound?,

    _warningPlayed = false,
})

-- Configuration (from Constants)
local HIDING_CHECK_RATE = Constants.HIDING.CHECK_RATE
local BUSH_DETECTION_RADIUS = Constants.HIDING.DETECTION_RADIUS
local MAX_HIDE_TIME = Constants.HIDING.MAX_HIDE_TIME
local WARNING_TIME = Constants.HIDING.WARNING_TIME

function HidingController:KnitInit()
    self:_createVisualEffects()
    self:_createSounds()
    print("[HidingController] Initialized")
end

function HidingController:KnitStart()
    local GameStateController = Knit.GetController("GameStateController")

    -- Only check hiding during gameplay
    GameStateController:OnStateChanged(function(newState, _oldState)
        if newState == Enums.GameState.GAMEPLAY then
            self:_startHidingCheck()
        else
            self:_stopHidingCheck()
            self:_exitHiding()
        end
    end)

    -- Check initial state
    if GameStateController:GetState() == Enums.GameState.GAMEPLAY then
        self:_startHidingCheck()
    end

    print("[HidingController] Started")
end

--[[
    Create the visual effect UI elements
]]
function HidingController:_createVisualEffects()
    -- Main ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = "HidingEffects"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 5

    -- Green vignette overlay for hiding
    local vignette = Instance.new("Frame")
    vignette.Name = "Vignette"
    vignette.Size = UDim2.fromScale(1, 1)
    vignette.Position = UDim2.fromScale(0, 0)
    vignette.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
    vignette.BackgroundTransparency = 1 -- Start invisible
    vignette.BorderSizePixel = 0
    vignette.Parent = gui

    -- Add gradient for vignette effect
    local gradient = Instance.new("UIGradient")
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.3, 0.7),
        NumberSequenceKeypoint.new(0.7, 0.7),
        NumberSequenceKeypoint.new(1, 0),
    })
    gradient.Offset = Vector2.new(0, 0)
    gradient.Parent = vignette

    -- Warning overlay (red tint when time running out)
    local warning = Instance.new("Frame")
    warning.Name = "Warning"
    warning.Size = UDim2.fromScale(1, 1)
    warning.Position = UDim2.fromScale(0, 0)
    warning.BackgroundColor3 = Color3.fromRGB(100, 30, 30)
    warning.BackgroundTransparency = 1
    warning.BorderSizePixel = 0
    warning.Parent = gui

    local warningGradient = Instance.new("UIGradient")
    warningGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.4, 0.8),
        NumberSequenceKeypoint.new(0.6, 0.8),
        NumberSequenceKeypoint.new(1, 0),
    })
    warningGradient.Parent = warning

    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    self._hidingGui = gui
    self._vignetteFrame = vignette
    self._warningFrame = warning
end

--[[
    Create audio cues
]]
function HidingController:_createSounds()
    local soundsFolder = SoundService:FindFirstChild("Sounds")
    if not soundsFolder then
        soundsFolder = Instance.new("Folder")
        soundsFolder.Name = "Sounds"
        soundsFolder.Parent = SoundService
    end

    -- Rustling sound when entering bush
    local enterSound = Instance.new("Sound")
    enterSound.Name = "BushEnter"
    enterSound.SoundId = "rbxassetid://395340995" -- Grass/foliage rustle
    enterSound.Volume = 0.8
    enterSound.PlaybackSpeed = 1.2
    enterSound.Parent = soundsFolder
    self._enterSound = enterSound

    -- Rustling sound when exiting
    local exitSound = Instance.new("Sound")
    exitSound.Name = "BushExit"
    exitSound.SoundId = "rbxassetid://124554515259136" -- Same rustling
    exitSound.Volume = 0.6
    exitSound.PlaybackSpeed = 0.9
    exitSound.Parent = soundsFolder
    self._exitSound = exitSound

    -- Warning sound when time running out
    local warningSound = Instance.new("Sound")
    warningSound.Name = "HidingWarning"
    warningSound.SoundId = "rbxassetid://6042053626" -- Alert tone
    warningSound.Volume = 0.5
    warningSound.Parent = soundsFolder
    self._warningSound = warningSound
end

--[[
    Start checking if player is hiding
]]
function HidingController:_startHidingCheck()
    if self._checkLoop then
        return
    end

    self._checkLoop = task.spawn(function()
        while true do
            self:_updateHidingState()
            task.wait(HIDING_CHECK_RATE)
        end
    end)
end

--[[
    Stop the hiding check loop
]]
function HidingController:_stopHidingCheck()
    if self._checkLoop then
        task.cancel(self._checkLoop)
        self._checkLoop = nil
    end
end

--[[
    Update hiding state - check if player is in a bush
]]
function HidingController:_updateHidingState()
    local character = LocalPlayer.Character
    if not character then
        if self._isHiding then
            self:_exitHiding()
        end
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not rootPart then
        if self._isHiding then
            self:_exitHiding()
        end
        return
    end

    local playerPos = rootPart.Position
    local nearestBush, nearestDist = self:_findNearestHidingBush(playerPos)

    if nearestBush and nearestDist <= BUSH_DETECTION_RADIUS then
        if not self._isHiding then
            self:_enterHiding(nearestBush)
        elseif self._currentBush ~= nearestBush then
            -- Moved to different bush, reset timer
            self._currentBush = nearestBush
            self._hideStartTime = tick()
            self._warningPlayed = false
        end

        -- Check hiding time limit
        self:_checkHidingTimeLimit()
    else
        if self._isHiding then
            self:_exitHiding()
        end
    end
end

--[[
    Find the nearest hiding bush to a position
]]
function HidingController:_findNearestHidingBush(position: Vector3): (Model?, number)
    local sceneryFolder = Workspace:FindFirstChild("Scenery")
    if not sceneryFolder then
        return nil, math.huge
    end

    local nearestBush: Model? = nil
    local nearestDist = math.huge

    for _, obj in sceneryFolder:GetChildren() do
        if obj:IsA("Model") and obj.Name == "HidingBush" then
            if obj.PrimaryPart then
                local dist = (obj.PrimaryPart.Position - position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearestBush = obj
                end
            end
        end
    end

    return nearestBush, nearestDist
end

--[[
    Enter hiding state
]]
function HidingController:_enterHiding(bush: Model)
    self._isHiding = true
    self._currentBush = bush
    self._hideStartTime = tick()
    self._warningPlayed = false

    -- Play enter sound locally
    if self._enterSound then
        self._enterSound:Play()
    end

    -- Notify server with bush reference (for 3D sound and glow tracking)
    local HidingService = Knit.GetService("HidingService")
    HidingService:OnBushEnter(bush)

    -- Fade in vignette
    if self._vignetteFrame then
        local tween = TweenService:Create(
            self._vignetteFrame,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 0.7 }
        )
        tween:Play()
    end
end

--[[
    Exit hiding state
]]
function HidingController:_exitHiding()
    if not self._isHiding then
        return
    end

    local previousBush = self._currentBush

    self._isHiding = false
    self._currentBush = nil
    self._warningPlayed = false

    -- Play exit sound locally
    if self._exitSound then
        self._exitSound:Play()
    end

    -- Notify server with bush reference (for 3D sound and glow tracking)
    local HidingService = Knit.GetService("HidingService")
    HidingService:OnBushExit(previousBush)

    -- Fade out vignette
    if self._vignetteFrame then
        local tween = TweenService:Create(
            self._vignetteFrame,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 }
        )
        tween:Play()
    end

    -- Fade out warning
    if self._warningFrame then
        local tween = TweenService:Create(
            self._warningFrame,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 }
        )
        tween:Play()
    end
end

--[[
    Check if player has been hiding too long
]]
function HidingController:_checkHidingTimeLimit()
    local hideTime = tick() - self._hideStartTime
    local timeRemaining = MAX_HIDE_TIME - hideTime

    -- Warning phase
    if timeRemaining <= WARNING_TIME and timeRemaining > 0 then
        if not self._warningPlayed then
            self._warningPlayed = true
            if self._warningSound then
                self._warningSound:Play()
            end
        end

        -- Pulse warning effect
        local pulseIntensity = 1 - (timeRemaining / WARNING_TIME)
        local pulse = 0.6 + math.sin(tick() * 4) * 0.2 * pulseIntensity

        if self._warningFrame then
            self._warningFrame.BackgroundTransparency = pulse
        end
    end

    -- Time's up - force player out
    if timeRemaining <= 0 then
        self:_forceExitBush()
    end
end

--[[
    Force the player out of the bush (push them out)
]]
function HidingController:_forceExitBush()
    local character = LocalPlayer.Character
    if not character then
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if rootPart and humanoid and self._currentBush and self._currentBush.PrimaryPart then
        -- Calculate direction away from bush center
        local bushPos = self._currentBush.PrimaryPart.Position
        local playerPos = rootPart.Position
        local pushDir = (playerPos - bushPos).Unit

        -- If somehow at exact center, pick random direction
        if pushDir.Magnitude ~= pushDir.Magnitude then -- NaN check
            pushDir = Vector3.new(1, 0, 0)
        end

        -- Apply velocity to push player out
        local pushForce = pushDir * 30 + Vector3.new(0, 10, 0)
        rootPart.AssemblyLinearVelocity = pushForce
    end

    self:_exitHiding()
end

--[[
    Check if currently hiding
]]
function HidingController:IsHiding(): boolean
    return self._isHiding
end

--[[
    Get remaining hide time
]]
function HidingController:GetRemainingHideTime(): number
    if not self._isHiding then
        return MAX_HIDE_TIME
    end
    return math.max(0, MAX_HIDE_TIME - (tick() - self._hideStartTime))
end

return HidingController
