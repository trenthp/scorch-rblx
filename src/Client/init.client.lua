--!strict
--[[
    Client Entry Point
    Initializes Knit and all client controllers for Scorch
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for packages to load
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

-- Load all controllers
local Controllers = script:WaitForChild("Controllers")
for _, controllerModule in Controllers:GetChildren() do
    if controllerModule:IsA("ModuleScript") then
        require(controllerModule)
    end
end

-- Start Knit
Knit.Start():andThen(function()
    print("[Scorch] Client started successfully")
end):catch(function(err)
    warn("[Scorch] Client failed to start:", err)
end)
