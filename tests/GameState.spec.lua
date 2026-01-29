--!strict
--[[
    GameState.spec.lua
    Unit tests for game state transitions
]]

return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local Enums
    beforeAll(function()
        local Shared = ReplicatedStorage:WaitForChild("Shared", 5)
        if Shared then
            Enums = require(Shared:WaitForChild("Enums", 5))
        end
    end)

    describe("GameState Enum", function()
        it("should have all required states", function()
            expect(Enums.GameState.LOBBY).to.be.ok()
            expect(Enums.GameState.TEAM_SELECTION).to.be.ok()
            expect(Enums.GameState.COUNTDOWN).to.be.ok()
            expect(Enums.GameState.GAMEPLAY).to.be.ok()
            expect(Enums.GameState.RESULTS).to.be.ok()
        end)

        it("should have unique state values", function()
            local states = {}
            for name, value in Enums.GameState do
                expect(states[value]).to.equal(nil)
                states[value] = true
            end
        end)
    end)

    describe("PlayerRole Enum", function()
        it("should have all required roles", function()
            expect(Enums.PlayerRole.Seeker).to.be.ok()
            expect(Enums.PlayerRole.Runner).to.be.ok()
            expect(Enums.PlayerRole.Spectator).to.be.ok()
        end)
    end)

    describe("FreezeState Enum", function()
        it("should have Active and Frozen states", function()
            expect(Enums.FreezeState.Active).to.be.ok()
            expect(Enums.FreezeState.Frozen).to.be.ok()
        end)
    end)

    describe("RoundEndReason Enum", function()
        it("should have all end reasons", function()
            expect(Enums.RoundEndReason.AllFrozen).to.be.ok()
            expect(Enums.RoundEndReason.TimeUp).to.be.ok()
            expect(Enums.RoundEndReason.SeekersDisconnected).to.be.ok()
            expect(Enums.RoundEndReason.RunnersDisconnected).to.be.ok()
        end)
    end)

    describe("WinnerTeam Enum", function()
        it("should have Seekers and Runners", function()
            expect(Enums.WinnerTeam.Seekers).to.be.ok()
            expect(Enums.WinnerTeam.Runners).to.be.ok()
        end)
    end)
end
