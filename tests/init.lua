--!strict
--[[
    Test Runner Entry Point
    Runs all TestEZ specs for Scorch
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Wait for packages
local Packages = ReplicatedStorage:WaitForChild("Packages", 10)
if not Packages then
    warn("[Tests] Packages not found, skipping tests")
    return
end

local TestEZ = Packages:FindFirstChild("TestEZ")
if not TestEZ then
    warn("[Tests] TestEZ not found, skipping tests")
    return
end

local TestEZModule = require(TestEZ)

-- Collect all test modules
local testModules = {}

local testsFolder = script.Parent
for _, child in testsFolder:GetChildren() do
    if child:IsA("ModuleScript") and child.Name:match("%.spec$") then
        table.insert(testModules, child)
    end
end

if #testModules == 0 then
    print("[Tests] No test modules found")
    return
end

print(string.format("[Tests] Running %d test modules...", #testModules))

-- Run tests
local results = TestEZModule.TestBootstrap:run(testModules)

-- Print summary
print("\n========== TEST SUMMARY ==========")
print(string.format("Tests: %d passed, %d failed, %d skipped",
    results.successCount,
    results.failureCount,
    results.skippedCount
))

if results.failureCount > 0 then
    print("\n❌ TESTS FAILED")
else
    print("\n✅ ALL TESTS PASSED")
end
