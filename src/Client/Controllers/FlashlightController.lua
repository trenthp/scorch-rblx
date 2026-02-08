--!strict
--[[
    FlashlightController.lua
    Client-side flashlight controller

    The server handles:
    - Giving flashlight tools to seekers
    - Detecting equip/unequip state
    - Controlling the spotlight (replicates to all clients)
    - Running detection for freezing runners

    The client handles:
    - UI button for toggling flashlight
    - Tracking local equip state
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))

local LocalPlayer = Players.LocalPlayer

-- Keyboard shortcuts
local FLASHLIGHT_KEY = Enum.KeyCode.F
local FLASHLIGHT_KEY_ALT = Enum.KeyCode.One

local FlashlightController = Knit.CreateController({
    Name = "FlashlightController",

    _isEquipped = false,
    _canUseFlashlight = false,

    -- UI
    _flashlightButton = nil :: ImageButton?,
    _buttonGui = nil :: ScreenGui?,
})

function FlashlightController:KnitInit()
    -- Disable the default backpack UI so our button doesn't interfere
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

    self:_createFlashlightButton()
    print("[FlashlightController] Initialized")
end

function FlashlightController:KnitStart()
    local FlashlightService = Knit.GetService("FlashlightService")
    local GameStateController = Knit.GetController("GameStateController")

    -- Handle keyboard input
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        if input.KeyCode == FLASHLIGHT_KEY or input.KeyCode == FLASHLIGHT_KEY_ALT then
            self:_toggleFlashlight()
        end
    end)

    -- Listen for flashlight toggle events from server
    FlashlightService.FlashlightToggled:Connect(function(player, enabled)
        if player == LocalPlayer then
            self._isEquipped = enabled
            self:_updateButtonAppearance()
            print(string.format("[FlashlightController] My flashlight: %s", enabled and "ON" or "OFF"))
        end
    end)

    -- Track game state to enable/disable button
    GameStateController:OnStateChanged(function(newState, _oldState)
        if newState == Enums.GameState.GAMEPLAY then
            self:_updateFlashlightAvailability()
        else
            self._canUseFlashlight = false
            self:_updateButtonVisibility()
        end
    end)

    -- Check initial state
    if GameStateController:GetState() == Enums.GameState.GAMEPLAY then
        self:_updateFlashlightAvailability()
    end

    print("[FlashlightController] Started")
end

--[[
    Check if local player's flashlight is equipped (light is on)
]]
function FlashlightController:IsEquipped(): boolean
    return self._isEquipped
end

--[[
    Update whether player can use flashlight (only seekers during gameplay)
]]
function FlashlightController:_updateFlashlightAvailability()
    local GameStateController = Knit.GetController("GameStateController")
    local myRole = GameStateController:GetMyRole()

    -- Only seekers can use flashlight
    self._canUseFlashlight = (myRole == Enums.PlayerRole.Seeker)
    self:_updateButtonVisibility()
end

--[[
    Create the flashlight button UI (same style as crouch button)
]]
function FlashlightController:_createFlashlightButton()
    local gui = Instance.new("ScreenGui")
    gui.Name = "FlashlightButtonGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 10

    -- Button (tool position - bottom center)
    local button = Instance.new("ImageButton")
    button.Name = "FlashlightButton"
    button.Size = UDim2.fromOffset(70, 70)
    button.Position = UDim2.new(0.5, 0, 1, -50)
    button.AnchorPoint = Vector2.new(0.5, 1)
    button.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
    button.BackgroundTransparency = 0.3
    button.Visible = false
    button.Parent = gui

    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = button

    -- Stroke/border
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 200, 100)
    stroke.Thickness = 2
    stroke.Transparency = 0.5
    stroke.Parent = button

    -- Icon label (flashlight symbol)
    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.fromScale(1, 0.6)
    icon.Position = UDim2.fromScale(0, 0.05)
    icon.BackgroundTransparency = 1
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 32
    icon.TextColor3 = Color3.fromRGB(255, 220, 150)
    icon.Text = "🔦"
    icon.Parent = button

    -- Text label
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.fromScale(1, 0.35)
    label.Position = UDim2.fromScale(0, 0.6)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(220, 180, 120)
    label.Text = "FLASHLIGHT"
    label.Parent = button

    -- Button click handler
    button.MouseButton1Click:Connect(function()
        self:_toggleFlashlight()
    end)

    -- Touch support
    button.TouchTap:Connect(function()
        self:_toggleFlashlight()
    end)

    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    self._buttonGui = gui
    self._flashlightButton = button
end

--[[
    Toggle flashlight by equipping/unequipping the tool
]]
function FlashlightController:_toggleFlashlight()
    if not self._canUseFlashlight then
        return
    end

    local character = LocalPlayer.Character
    if not character then
        return
    end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if not humanoid then
        return
    end

    -- Check if flashlight is currently equipped (in character)
    local equippedTool = character:FindFirstChild("Flashlight")

    if equippedTool then
        -- Unequip by moving to backpack
        humanoid:UnequipTools()
    else
        -- Equip from backpack
        local backpackTool = backpack and backpack:FindFirstChild("Flashlight")
        if backpackTool then
            humanoid:EquipTool(backpackTool)
        end
    end
end

--[[
    Update button visibility based on flashlight availability
]]
function FlashlightController:_updateButtonVisibility()
    if self._flashlightButton then
        self._flashlightButton.Visible = self._canUseFlashlight
    end
end

--[[
    Update button appearance based on equipped state
]]
function FlashlightController:_updateButtonAppearance()
    if not self._flashlightButton then
        return
    end

    if self._isEquipped then
        -- Equipped - show "active" state (light on)
        self._flashlightButton.BackgroundColor3 = Color3.fromRGB(120, 100, 40)
        self._flashlightButton.BackgroundTransparency = 0.1

        local label = self._flashlightButton:FindFirstChild("Label") :: TextLabel?
        if label then
            label.Text = "LIGHT ON"
        end
    else
        -- Not equipped - show normal state
        self._flashlightButton.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
        self._flashlightButton.BackgroundTransparency = 0.3

        local label = self._flashlightButton:FindFirstChild("Label") :: TextLabel?
        if label then
            label.Text = "FLASHLIGHT"
        end
    end
end

return FlashlightController
