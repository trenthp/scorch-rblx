--!strict
--[[
    ConeDetection.spec.lua
    Unit tests for the ConeDetection utility
]]

return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local ConeDetection
    beforeAll(function()
        -- Wait for module to be available
        local Shared = ReplicatedStorage:WaitForChild("Shared", 5)
        if Shared then
            local Utils = Shared:WaitForChild("Utils", 5)
            if Utils then
                ConeDetection = require(Utils:WaitForChild("ConeDetection", 5))
            end
        end
    end)

    describe("IsInCone", function()
        it("should return true when target is directly in front within range", function()
            local origin = Vector3.new(0, 0, 0)
            local direction = Vector3.new(0, 0, 1)
            local target = Vector3.new(0, 0, 10)

            local result = ConeDetection.IsInCone(origin, direction, target, 50, 45)
            expect(result).to.equal(true)
        end)

        it("should return false when target is behind the origin", function()
            local origin = Vector3.new(0, 0, 0)
            local direction = Vector3.new(0, 0, 1)
            local target = Vector3.new(0, 0, -10)

            local result = ConeDetection.IsInCone(origin, direction, target, 50, 45)
            expect(result).to.equal(false)
        end)

        it("should return false when target is outside range", function()
            local origin = Vector3.new(0, 0, 0)
            local direction = Vector3.new(0, 0, 1)
            local target = Vector3.new(0, 0, 100)

            local result = ConeDetection.IsInCone(origin, direction, target, 50, 45)
            expect(result).to.equal(false)
        end)

        it("should return true when target is within cone angle", function()
            local origin = Vector3.new(0, 0, 0)
            local direction = Vector3.new(0, 0, 1)
            -- 20 degrees off-center should be within 45 degree cone
            local angle = math.rad(20)
            local target = Vector3.new(math.sin(angle) * 10, 0, math.cos(angle) * 10)

            local result = ConeDetection.IsInCone(origin, direction, target, 50, 45)
            expect(result).to.equal(true)
        end)

        it("should return false when target is outside cone angle", function()
            local origin = Vector3.new(0, 0, 0)
            local direction = Vector3.new(0, 0, 1)
            -- 30 degrees off-center should be outside 45 degree cone (half-angle is 22.5)
            local angle = math.rad(30)
            local target = Vector3.new(math.sin(angle) * 10, 0, math.cos(angle) * 10)

            local result = ConeDetection.IsInCone(origin, direction, target, 50, 45)
            expect(result).to.equal(false)
        end)

        it("should return false when target is at origin", function()
            local origin = Vector3.new(0, 0, 0)
            local direction = Vector3.new(0, 0, 1)
            local target = Vector3.new(0, 0, 0)

            local result = ConeDetection.IsInCone(origin, direction, target, 50, 45)
            expect(result).to.equal(false)
        end)

        it("should handle non-unit direction vectors", function()
            local origin = Vector3.new(0, 0, 0)
            local direction = Vector3.new(0, 0, 5) -- Non-unit vector
            local target = Vector3.new(0, 0, 10)

            local result = ConeDetection.IsInCone(origin, direction, target, 50, 45)
            expect(result).to.equal(true)
        end)

        it("should work with negative coordinates", function()
            local origin = Vector3.new(-10, -10, -10)
            local direction = Vector3.new(-1, 0, 0)
            local target = Vector3.new(-20, -10, -10)

            local result = ConeDetection.IsInCone(origin, direction, target, 50, 45)
            expect(result).to.equal(true)
        end)
    end)

    describe("HasLineOfSight", function()
        it("should return true when no obstacles exist", function()
            local origin = Vector3.new(0, 100, 0)
            local target = Vector3.new(0, 100, 10)

            local result = ConeDetection.HasLineOfSight(origin, target, {})
            expect(result).to.equal(true)
        end)

        it("should return true when target is at same position", function()
            local origin = Vector3.new(0, 100, 0)
            local target = Vector3.new(0, 100, 0)

            local result = ConeDetection.HasLineOfSight(origin, target, {})
            expect(result).to.equal(true)
        end)
    end)

    describe("Edge cases", function()
        it("should handle zero range gracefully", function()
            local origin = Vector3.new(0, 0, 0)
            local direction = Vector3.new(0, 0, 1)
            local target = Vector3.new(0, 0, 1)

            local result = ConeDetection.IsInCone(origin, direction, target, 0, 45)
            expect(result).to.equal(false)
        end)

        it("should handle very small angle", function()
            local origin = Vector3.new(0, 0, 0)
            local direction = Vector3.new(0, 0, 1)
            local target = Vector3.new(0, 0, 10) -- Directly in front

            local result = ConeDetection.IsInCone(origin, direction, target, 50, 1)
            expect(result).to.equal(true)
        end)

        it("should handle 180 degree cone (hemisphere)", function()
            local origin = Vector3.new(0, 0, 0)
            local direction = Vector3.new(0, 0, 1)
            local target = Vector3.new(10, 0, 0.01) -- Almost perpendicular

            local result = ConeDetection.IsInCone(origin, direction, target, 50, 180)
            expect(result).to.equal(true)
        end)
    end)
end
