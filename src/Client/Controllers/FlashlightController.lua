--!strict
--[[
    FlashlightController.lua
    Client-side flashlight controller

    The server handles:
    - Giving flashlight tools to seekers
    - Detecting equip/unequip state
    - Controlling the spotlight (replicates to all clients)
    - Running detection for freezing runners

    The client just needs to track local state for UI purposes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))

local LocalPlayer = Players.LocalPlayer

local FlashlightController = Knit.CreateController({
    Name = "FlashlightController",

    _isEquipped = false,
})

function FlashlightController:KnitInit()
    print("[FlashlightController] Initialized")
end

function FlashlightController:KnitStart()
    local FlashlightService = Knit.GetService("FlashlightService")

    -- Listen for flashlight toggle events from server
    FlashlightService.FlashlightToggled:Connect(function(player, enabled)
        if player == LocalPlayer then
            self._isEquipped = enabled
            print(string.format("[FlashlightController] My flashlight: %s", enabled and "ON" or "OFF"))
        end
    end)

    print("[FlashlightController] Started")
end

--[[
    Check if local player's flashlight is equipped (light is on)
]]
function FlashlightController:IsEquipped(): boolean
    return self._isEquipped
end

return FlashlightController
