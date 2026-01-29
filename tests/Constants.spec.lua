--!strict
--[[
    Constants.spec.lua
    Unit tests for game constants validation
]]

return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local Constants
    beforeAll(function()
        local Shared = ReplicatedStorage:WaitForChild("Shared", 5)
        if Shared then
            Constants = require(Shared:WaitForChild("Constants", 5))
        end
    end)

    describe("Flashlight Constants", function()
        it("should have valid flashlight range", function()
            expect(Constants.FLASHLIGHT_RANGE).to.be.a("number")
            expect(Constants.FLASHLIGHT_RANGE > 0).to.equal(true)
            expect(Constants.FLASHLIGHT_RANGE <= 100).to.equal(true) -- Reasonable max
        end)

        it("should have valid flashlight angle", function()
            expect(Constants.FLASHLIGHT_ANGLE).to.be.a("number")
            expect(Constants.FLASHLIGHT_ANGLE > 0).to.equal(true)
            expect(Constants.FLASHLIGHT_ANGLE <= 180).to.equal(true)
        end)

        it("should have valid check rate", function()
            expect(Constants.FLASHLIGHT_CHECK_RATE).to.be.a("number")
            expect(Constants.FLASHLIGHT_CHECK_RATE > 0).to.equal(true)
            expect(Constants.FLASHLIGHT_CHECK_RATE <= 1).to.equal(true) -- At least 1 check/second
        end)
    end)

    describe("Round Constants", function()
        it("should have valid round duration", function()
            expect(Constants.ROUND_DURATION).to.be.a("number")
            expect(Constants.ROUND_DURATION >= 60).to.equal(true) -- At least 1 minute
            expect(Constants.ROUND_DURATION <= 600).to.equal(true) -- At most 10 minutes
        end)

        it("should have valid countdown duration", function()
            expect(Constants.COUNTDOWN_DURATION).to.be.a("number")
            expect(Constants.COUNTDOWN_DURATION >= 3).to.equal(true)
            expect(Constants.COUNTDOWN_DURATION <= 30).to.equal(true)
        end)

        it("should have valid seeker freeze duration", function()
            expect(Constants.SEEKER_FREEZE_DURATION).to.be.a("number")
            expect(Constants.SEEKER_FREEZE_DURATION >= 0).to.equal(true)
            expect(Constants.SEEKER_FREEZE_DURATION <= 30).to.equal(true)
        end)
    end)

    describe("Player Constants", function()
        it("should have valid minimum players", function()
            expect(Constants.MIN_PLAYERS).to.be.a("number")
            expect(Constants.MIN_PLAYERS >= 2).to.equal(true)
        end)

        it("should have valid seeker count", function()
            expect(Constants.SEEKER_COUNT).to.be.a("number")
            expect(Constants.SEEKER_COUNT >= 1).to.equal(true)
            -- Seeker count should be less than min players
            expect(Constants.SEEKER_COUNT < Constants.MIN_PLAYERS).to.equal(true)
        end)
    end)

    describe("Visual Constants", function()
        it("should have valid flashlight brightness", function()
            expect(Constants.FLASHLIGHT_BRIGHTNESS).to.be.a("number")
            expect(Constants.FLASHLIGHT_BRIGHTNESS > 0).to.equal(true)
        end)

        it("should have flashlight color as Color3", function()
            expect(typeof(Constants.FLASHLIGHT_COLOR)).to.equal("Color3")
        end)

        it("should have freeze color as Color3", function()
            expect(typeof(Constants.FREEZE_COLOR)).to.equal("Color3")
        end)

        it("should have valid freeze transparency", function()
            expect(Constants.FREEZE_TRANSPARENCY).to.be.a("number")
            expect(Constants.FREEZE_TRANSPARENCY >= 0).to.equal(true)
            expect(Constants.FREEZE_TRANSPARENCY <= 1).to.equal(true)
        end)
    end)

    describe("Team Colors", function()
        it("should have seeker color as BrickColor", function()
            expect(typeof(Constants.SEEKER_COLOR)).to.equal("BrickColor")
        end)

        it("should have runner color as BrickColor", function()
            expect(typeof(Constants.RUNNER_COLOR)).to.equal("BrickColor")
        end)

        it("should have lobby color as BrickColor", function()
            expect(typeof(Constants.LOBBY_COLOR)).to.equal("BrickColor")
        end)
    end)

    describe("Network Events", function()
        it("should have all required event names", function()
            expect(Constants.EVENTS).to.be.a("table")
            expect(Constants.EVENTS.GAME_STATE_CHANGED).to.be.ok()
            expect(Constants.EVENTS.PLAYER_FROZEN).to.be.ok()
            expect(Constants.EVENTS.PLAYER_UNFROZEN).to.be.ok()
            expect(Constants.EVENTS.ROUND_TIMER_UPDATE).to.be.ok()
            expect(Constants.EVENTS.FLASHLIGHT_TOGGLE).to.be.ok()
        end)
    end)
end
