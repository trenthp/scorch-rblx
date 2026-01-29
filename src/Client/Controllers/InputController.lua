--!strict
--[[
    InputController.lua
    Handles player input for flashlight and other actions
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))

local InputController = Knit.CreateController({
    Name = "InputController",

    _flashlightBound = false,
})

function InputController:KnitInit()
    print("[InputController] Initialized")
end

function InputController:KnitStart()
    local GameStateController = Knit.GetController("GameStateController")

    -- Bind flashlight toggle when game starts
    GameStateController:OnStateChanged(function(newState)
        if newState == Enums.GameState.GAMEPLAY then
            self:_bindFlashlightAction()
        else
            self:_unbindFlashlightAction()
        end
    end)

    -- Also bind on start if already in gameplay
    if GameStateController:GetState() == Enums.GameState.GAMEPLAY then
        self:_bindFlashlightAction()
    end

    print("[InputController] Started")
end

--[[
    Bind the flashlight toggle action
]]
function InputController:_bindFlashlightAction()
    if self._flashlightBound then
        return
    end

    ContextActionService:BindAction(
        "ToggleFlashlight",
        function(actionName, inputState, inputObject)
            return self:_handleFlashlightInput(actionName, inputState, inputObject)
        end,
        true, -- Create touch button on mobile
        Enum.KeyCode.F,
        Enum.KeyCode.ButtonY, -- Xbox controller
        Enum.UserInputType.MouseButton1 -- Also allow click for simplicity
    )

    -- Set up touch button appearance
    local button = ContextActionService:GetButton("ToggleFlashlight")
    if button then
        button.Image = "rbxassetid://6031068420" -- Flashlight icon
    end

    self._flashlightBound = true
    print("[InputController] Flashlight action bound")
end

--[[
    Unbind the flashlight toggle action
]]
function InputController:_unbindFlashlightAction()
    if not self._flashlightBound then
        return
    end

    ContextActionService:UnbindAction("ToggleFlashlight")
    self._flashlightBound = false
    print("[InputController] Flashlight action unbound")
end

--[[
    Handle flashlight input
]]
function InputController:_handleFlashlightInput(
    actionName: string,
    inputState: Enum.UserInputState,
    inputObject: InputObject
): Enum.ContextActionResult
    -- Only trigger on press, not release
    if inputState ~= Enum.UserInputState.Begin then
        return Enum.ContextActionResult.Pass
    end

    -- Don't trigger if typing in a text box
    if UserInputService:GetFocusedTextBox() then
        return Enum.ContextActionResult.Pass
    end

    local FlashlightController = Knit.GetController("FlashlightController")
    FlashlightController:ToggleFlashlight()

    return Enum.ContextActionResult.Sink
end

return InputController
