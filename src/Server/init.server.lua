--!strict
--[[
    Server Entry Point
    Initializes Knit and all server services for Scorch
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for packages to load
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

-- Load all services
local Services = script:WaitForChild("Services")
for _, serviceModule in Services:GetChildren() do
    if serviceModule:IsA("ModuleScript") then
        require(serviceModule)
    end
end

-- Start Knit
Knit.Start():andThen(function()
    print("[Scorch] Server started successfully")
end):catch(function(err)
    warn("[Scorch] Server failed to start:", err)
end)
