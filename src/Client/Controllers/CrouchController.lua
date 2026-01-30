--!strict
--[[
    CrouchController.lua
    Handles crouching for runners to hide better in bushes
    - Press C or Left Ctrl to toggle crouch
    - Lowers character stance
    - Reduces movement speed while crouching
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

local LocalPlayer = Players.LocalPlayer

local CrouchController = Knit.CreateController({
    Name = "CrouchController",

    _isCrouching = false,
    _canCrouch = false,
    _originalHipHeight = nil :: number?,
    _originalWalkSpeed = nil :: number?,
    _originalJumpPower = nil :: number?,
    _crouchTween = nil :: Tween?,

    -- Animation
    _crouchTrack = nil :: AnimationTrack?,
    _animator = nil :: Animator?,

    -- UI
    _crouchButton = nil :: ImageButton?,
    _buttonGui = nil :: ScreenGui?,
})

-- Configuration
local CROUCH_KEY = Enum.KeyCode.C
local CROUCH_KEY_ALT = Enum.KeyCode.LeftControl
local CROUCH_HIP_HEIGHT_MULTIPLIER = Constants.CROUCH.HIP_HEIGHT_MULTIPLIER
local CROUCH_SPEED_MULTIPLIER = Constants.CROUCH.SPEED_MULTIPLIER
local CROUCH_TWEEN_TIME = Constants.CROUCH.TWEEN_TIME

-- Crouch animation - disabled until valid animation is provided
-- Set to a valid rbxassetid:// if you have a crouch animation
local CROUCH_ANIMATION_ID = ""

function CrouchController:KnitInit()
    self:_createCrouchButton()
    print("[CrouchController] Initialized")
end

function CrouchController:KnitStart()
    local GameStateController = Knit.GetController("GameStateController")

    -- Handle input
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        if input.KeyCode == CROUCH_KEY or input.KeyCode == CROUCH_KEY_ALT then
            self:_toggleCrouch()
        end
    end)

    -- Track game state to enable/disable crouching
    GameStateController:OnStateChanged(function(newState, _oldState)
        if newState == Enums.GameState.GAMEPLAY then
            self:_updateCrouchAvailability()
        else
            self._canCrouch = false
            if self._isCrouching then
                self:_standUp()
            end
            self:_updateButtonVisibility()
        end
    end)

    -- Handle character respawns
    LocalPlayer.CharacterAdded:Connect(function(character)
        self:_onCharacterAdded(character)
    end)

    if LocalPlayer.Character then
        self:_onCharacterAdded(LocalPlayer.Character)
    end

    -- Check initial state
    if GameStateController:GetState() == Enums.GameState.GAMEPLAY then
        self:_updateCrouchAvailability()
    end

    print("[CrouchController] Started")
end

--[[
    Handle new character
]]
function CrouchController:_onCharacterAdded(character: Model)
    -- Reset crouch state
    self._isCrouching = false
    self._originalHipHeight = nil
    self._originalWalkSpeed = nil
    self._originalJumpPower = nil
    self._crouchTrack = nil
    self._animator = nil

    -- Wait for humanoid
    local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
    if humanoid then
        -- Store original values
        self._originalHipHeight = humanoid.HipHeight
        self._originalWalkSpeed = humanoid.WalkSpeed
        self._originalJumpPower = humanoid.JumpPower

        -- Setup animation
        self:_setupCrouchAnimation(humanoid)

        -- Handle death
        humanoid.Died:Connect(function()
            self._isCrouching = false
            self._canCrouch = false
            if self._crouchTrack then
                self._crouchTrack:Stop()
            end
        end)
    end
end

--[[
    Setup crouch animation for the character
]]
function CrouchController:_setupCrouchAnimation(humanoid: Humanoid)
    -- Skip if no animation ID configured
    if CROUCH_ANIMATION_ID == "" then
        return
    end

    -- Find or wait for Animator
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = humanoid:WaitForChild("Animator", 3) :: Animator?
    end

    if not animator then
        return
    end

    self._animator = animator

    -- Create the crouch animation
    local animation = Instance.new("Animation")
    animation.AnimationId = CROUCH_ANIMATION_ID

    -- Load the animation track
    local success, track = pcall(function()
        return animator:LoadAnimation(animation)
    end)

    if success and track then
        self._crouchTrack = track
        self._crouchTrack.Priority = Enum.AnimationPriority.Action
        self._crouchTrack.Looped = true
        print("[CrouchController] Crouch animation loaded")
    else
        warn("[CrouchController] Failed to load crouch animation")
    end

    -- Clean up animation instance
    animation:Destroy()
end

--[[
    Update whether player can crouch (only runners during gameplay)
]]
function CrouchController:_updateCrouchAvailability()
    local GameStateController = Knit.GetController("GameStateController")
    local myRole = GameStateController:GetMyRole()

    -- Only runners can crouch
    self._canCrouch = (myRole == Enums.PlayerRole.Runner)

    if not self._canCrouch and self._isCrouching then
        self:_standUp()
    end

    -- Show/hide crouch button based on availability
    self:_updateButtonVisibility()
end

--[[
    Create the crouch button UI
]]
function CrouchController:_createCrouchButton()
    local gui = Instance.new("ScreenGui")
    gui.Name = "CrouchButtonGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 10

    -- Button container (bottom right, above mobile controls)
    local button = Instance.new("ImageButton")
    button.Name = "CrouchButton"
    button.Size = UDim2.fromOffset(70, 70)
    button.Position = UDim2.new(1, -90, 1, -180)
    button.AnchorPoint = Vector2.new(0.5, 0.5)
    button.BackgroundColor3 = Color3.fromRGB(40, 60, 80)
    button.BackgroundTransparency = 0.3
    button.Visible = false -- Hidden by default
    button.Parent = gui

    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = button

    -- Stroke/border
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 150, 200)
    stroke.Thickness = 2
    stroke.Transparency = 0.5
    stroke.Parent = button

    -- Icon label (crouch symbol)
    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.fromScale(1, 0.6)
    icon.Position = UDim2.fromScale(0, 0.05)
    icon.BackgroundTransparency = 1
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 32
    icon.TextColor3 = Color3.fromRGB(200, 220, 255)
    icon.Text = "⬇" -- Down arrow as crouch symbol
    icon.Parent = button

    -- Text label
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.fromScale(1, 0.35)
    label.Position = UDim2.fromScale(0, 0.6)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(180, 200, 220)
    label.Text = "CROUCH"
    label.Parent = button

    -- Button click handler
    button.MouseButton1Click:Connect(function()
        self:_toggleCrouch()
    end)

    -- Touch support
    button.TouchTap:Connect(function()
        self:_toggleCrouch()
    end)

    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    self._buttonGui = gui
    self._crouchButton = button
end

--[[
    Update button visibility based on crouch availability
]]
function CrouchController:_updateButtonVisibility()
    if self._crouchButton then
        self._crouchButton.Visible = self._canCrouch
    end
end

--[[
    Update button appearance based on crouch state
]]
function CrouchController:_updateButtonAppearance()
    if not self._crouchButton then
        return
    end

    if self._isCrouching then
        -- Crouching - show "active" state
        self._crouchButton.BackgroundColor3 = Color3.fromRGB(60, 100, 140)
        self._crouchButton.BackgroundTransparency = 0.1

        local icon = self._crouchButton:FindFirstChild("Icon") :: TextLabel?
        if icon then
            icon.Text = "⬆" -- Up arrow to indicate "stand up"
        end

        local label = self._crouchButton:FindFirstChild("Label") :: TextLabel?
        if label then
            label.Text = "STAND"
        end
    else
        -- Standing - show normal state
        self._crouchButton.BackgroundColor3 = Color3.fromRGB(40, 60, 80)
        self._crouchButton.BackgroundTransparency = 0.3

        local icon = self._crouchButton:FindFirstChild("Icon") :: TextLabel?
        if icon then
            icon.Text = "⬇"
        end

        local label = self._crouchButton:FindFirstChild("Label") :: TextLabel?
        if label then
            label.Text = "CROUCH"
        end
    end
end

--[[
    Toggle crouch state
]]
function CrouchController:_toggleCrouch()
    if not self._canCrouch then
        return
    end

    if self._isCrouching then
        self:_standUp()
    else
        self:_crouchDown()
    end
end

--[[
    Enter crouch stance
]]
function CrouchController:_crouchDown()
    if self._isCrouching then
        return
    end

    local character = LocalPlayer.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    self._isCrouching = true

    -- Store original values if not already stored
    if not self._originalHipHeight then
        self._originalHipHeight = humanoid.HipHeight
    end
    if not self._originalWalkSpeed then
        self._originalWalkSpeed = humanoid.WalkSpeed
    end
    if not self._originalJumpPower then
        self._originalJumpPower = humanoid.JumpPower
    end

    -- Calculate crouched values
    local crouchedHipHeight = self._originalHipHeight * CROUCH_HIP_HEIGHT_MULTIPLIER
    local crouchedWalkSpeed = self._originalWalkSpeed * CROUCH_SPEED_MULTIPLIER

    -- Cancel existing tween
    if self._crouchTween then
        self._crouchTween:Cancel()
    end

    -- Tween to crouch position
    self._crouchTween = TweenService:Create(
        humanoid,
        TweenInfo.new(CROUCH_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            HipHeight = crouchedHipHeight,
            WalkSpeed = crouchedWalkSpeed,
            JumpPower = 0, -- Can't jump while crouching
        }
    )
    self._crouchTween:Play()

    -- Play crouch animation
    if self._crouchTrack then
        self._crouchTrack:Play(CROUCH_TWEEN_TIME)
    end

    -- Update button appearance
    self:_updateButtonAppearance()

    -- Notify server about crouch state
    self:_notifyServer(true)
end

--[[
    Exit crouch stance
]]
function CrouchController:_standUp()
    if not self._isCrouching then
        return
    end

    local character = LocalPlayer.Character
    if not character then
        self._isCrouching = false
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        self._isCrouching = false
        return
    end

    self._isCrouching = false

    -- Cancel existing tween
    if self._crouchTween then
        self._crouchTween:Cancel()
    end

    -- Restore original values
    local targetHipHeight = self._originalHipHeight or 2
    local targetWalkSpeed = self._originalWalkSpeed or 16
    local targetJumpPower = self._originalJumpPower or 50

    -- Tween back to standing
    self._crouchTween = TweenService:Create(
        humanoid,
        TweenInfo.new(CROUCH_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            HipHeight = targetHipHeight,
            WalkSpeed = targetWalkSpeed,
            JumpPower = targetJumpPower,
        }
    )
    self._crouchTween:Play()

    -- Stop crouch animation
    if self._crouchTrack then
        self._crouchTrack:Stop(CROUCH_TWEEN_TIME)
    end

    -- Update button appearance
    self:_updateButtonAppearance()

    -- Notify server about crouch state
    self:_notifyServer(false)
end

--[[
    Notify server about crouch state (for other players to see)
]]
function CrouchController:_notifyServer(isCrouching: boolean)
    local CrouchService = Knit.GetService("CrouchService")
    CrouchService:SetCrouching(isCrouching)
end

--[[
    Check if currently crouching
]]
function CrouchController:IsCrouching(): boolean
    return self._isCrouching
end

--[[
    Force stand up (called externally if needed)
]]
function CrouchController:ForceStandUp()
    self:_standUp()
end

return CrouchController
