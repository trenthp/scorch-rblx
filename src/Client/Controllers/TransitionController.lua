--!strict
--[[
    TransitionController.lua
    Handles screen transition effects (fade to black, fade in)
    Used for lobby <-> gameplay transitions
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local LocalPlayer = Players.LocalPlayer

local TransitionController = Knit.CreateController({
    Name = "TransitionController",

    _transitionGui = nil :: ScreenGui?,
    _fadeFrame = nil :: Frame?,
    _isTransitioning = false,
})

function TransitionController:KnitInit()
    self:_createTransitionGui()
    print("[TransitionController] Initialized")
end

function TransitionController:KnitStart()
    local LobbyService = Knit.GetService("LobbyService")

    -- Listen for transition signals
    LobbyService.StartTransition:Connect(function(direction: string)
        if direction == "out" then
            self:FadeOut()
        else
            self:FadeIn()
        end
    end)

    LobbyService.TransitionComplete:Connect(function()
        self:FadeIn()
    end)

    print("[TransitionController] Started")
end

--[[
    Create the transition GUI elements
]]
function TransitionController:_createTransitionGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "TransitionGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 100 -- On top of everything

    local fadeFrame = Instance.new("Frame")
    fadeFrame.Name = "FadeFrame"
    fadeFrame.Size = UDim2.fromScale(1, 1)
    fadeFrame.Position = UDim2.fromScale(0, 0)
    fadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    fadeFrame.BackgroundTransparency = 1 -- Start transparent
    fadeFrame.BorderSizePixel = 0
    fadeFrame.ZIndex = 100
    fadeFrame.Parent = gui

    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    self._transitionGui = gui
    self._fadeFrame = fadeFrame
end

--[[
    Fade screen to black
]]
function TransitionController:FadeOut(duration: number?): ()
    if not self._fadeFrame then
        return
    end

    local fadeTime = duration or Constants.LOBBY.FADE_TIME
    self._isTransitioning = true

    local tween = TweenService:Create(
        self._fadeFrame,
        TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 0 }
    )

    tween:Play()
    tween.Completed:Wait()
end

--[[
    Fade screen from black to clear
]]
function TransitionController:FadeIn(duration: number?): ()
    if not self._fadeFrame then
        return
    end

    local fadeTime = duration or Constants.LOBBY.FADE_TIME

    local tween = TweenService:Create(
        self._fadeFrame,
        TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { BackgroundTransparency = 1 }
    )

    tween:Play()
    tween.Completed:Connect(function()
        self._isTransitioning = false
    end)
end

--[[
    Check if currently transitioning
]]
function TransitionController:IsTransitioning(): boolean
    return self._isTransitioning
end

--[[
    Instant fade (no animation)
]]
function TransitionController:SetFade(opacity: number)
    if self._fadeFrame then
        self._fadeFrame.BackgroundTransparency = 1 - opacity
    end
end

return TransitionController
