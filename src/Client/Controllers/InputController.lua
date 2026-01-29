--!strict
--[[
    InputController.lua
    Handles player input for game actions

    Note: Flashlight is controlled via Roblox's built-in Tool equip system
    (press 1 or click on hotbar to equip/unequip)
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
})

function InputController:KnitInit()
    print("[InputController] Initialized")
end

function InputController:KnitStart()
    -- Future input bindings can be added here
    print("[InputController] Started")
end

return InputController
