--!strict
--[[
    RoundService.lua
    Manages round timing, countdown, and win conditions
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

local RoundService = Knit.CreateService({
    Name = "RoundService",

    Client = {
        CountdownTick = Knit.CreateSignal(),
        RoundTimerUpdate = Knit.CreateSignal(),
        RoundStarted = Knit.CreateSignal(),
        RoundEnded = Knit.CreateSignal(),
        SeekerUnfrozen = Knit.CreateSignal(),
    },

    _roundActive = false,
    _roundStartTime = 0,
    _roundEndTime = 0,
    _timerConnection = nil :: thread?,
    _roundEndedSignal = nil :: any,
    _lastWinner = nil :: string?,
    _lastEndReason = nil :: string?,
})

function RoundService:KnitInit()
    self._roundEndedSignal = Signal.new()
    print("[RoundService] Initialized")
end

function RoundService:KnitStart()
    print("[RoundService] Started")
end

--[[
    Start the countdown before the round
]]
function RoundService:StartCountdown()
    print("[RoundService] Starting countdown")

    local MapService = Knit.GetService("MapService")
    MapService:SpawnAllPlayers()

    -- Countdown from COUNTDOWN_DURATION to 1
    for i = Constants.COUNTDOWN_DURATION, 1, -1 do
        self.Client.CountdownTick:FireAll(i)
        task.wait(1)
    end

    self.Client.CountdownTick:FireAll(0)
end

--[[
    Start the actual gameplay round
]]
function RoundService:StartRound()
    print("[RoundService] Round starting")

    self._roundActive = true
    self._roundStartTime = tick()
    self._roundEndTime = self._roundStartTime + Constants.ROUND_DURATION

    -- Reset player states
    local PlayerStateService = Knit.GetService("PlayerStateService")
    PlayerStateService:ResetAllStates()

    -- Freeze seekers at start
    self:_freezeSeekersAtStart()

    -- Start the round timer
    self:_startRoundTimer()

    self.Client.RoundStarted:FireAll({
        startTime = self._roundStartTime,
        duration = Constants.ROUND_DURATION,
    })
end

--[[
    Freeze seekers at the start of the round
    Gives runners time to scatter
]]
function RoundService:_freezeSeekersAtStart()
    local TeamService = Knit.GetService("TeamService")
    local seekers = TeamService:GetSeekers()

    -- Freeze seeker movement temporarily
    for _, seeker in seekers do
        local character = seeker.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 0
                humanoid.JumpPower = 0
            end
        end
    end

    -- Unfreeze after delay
    task.delay(Constants.SEEKER_FREEZE_DURATION, function()
        if not self._roundActive then
            return
        end

        for _, seeker in seekers do
            local character = seeker.Character
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.WalkSpeed = 16
                    humanoid.JumpPower = 50
                end
            end
        end

        self.Client.SeekerUnfrozen:FireAll()
        print("[RoundService] Seekers unfrozen")
    end)
end

--[[
    Start the round timer loop
]]
function RoundService:_startRoundTimer()
    self._timerConnection = task.spawn(function()
        while self._roundActive do
            local remaining = math.max(0, self._roundEndTime - tick())

            self.Client.RoundTimerUpdate:FireAll(math.ceil(remaining))

            if remaining <= 0 then
                -- Time's up, runners win
                self:EndRound(Enums.WinnerTeam.Runners, Enums.RoundEndReason.TimeUp)
                return
            end

            task.wait(0.5) -- Update twice per second
        end
    end)
end

--[[
    End the round with a winner
    @param winner - "Seekers" or "Runners"
    @param reason - Why the round ended
]]
function RoundService:EndRound(winner: string, reason: string)
    if not self._roundActive then
        return
    end

    print(string.format("[RoundService] Round ended. Winner: %s, Reason: %s", winner, reason))

    self._roundActive = false
    self._lastWinner = winner
    self._lastEndReason = reason

    -- Stop timer
    if self._timerConnection then
        task.cancel(self._timerConnection)
        self._timerConnection = nil
    end

    -- Get round stats
    local PlayerStateService = Knit.GetService("PlayerStateService")
    local TeamService = Knit.GetService("TeamService")

    local frozenCount = PlayerStateService:GetFrozenCount()
    local totalRunners = #TeamService:GetRunners()

    local results = {
        winner = winner,
        reason = reason,
        frozenCount = frozenCount,
        totalRunners = totalRunners,
        duration = tick() - self._roundStartTime,
    }

    -- Notify clients
    self.Client.RoundEnded:FireAll(results)

    -- Fire internal signal
    self._roundEndedSignal:Fire(results)

    -- Unfreeze all players
    PlayerStateService:ResetAllStates()

    -- Transition to results state
    local GameStateService = Knit.GetService("GameStateService")
    GameStateService:SetState(Enums.GameState.RESULTS)
end

--[[
    Check if the round is currently active
]]
function RoundService:IsRoundActive(): boolean
    return self._roundActive
end

--[[
    Get remaining time in seconds
]]
function RoundService:GetRemainingTime(): number
    if not self._roundActive then
        return 0
    end
    return math.max(0, self._roundEndTime - tick())
end

--[[
    Subscribe to round ended event
]]
function RoundService:OnRoundEnded(callback: (results: any) -> ())
    return self._roundEndedSignal:Connect(callback)
end

-- Client methods
function RoundService.Client:GetRemainingTime(): number
    return self.Server:GetRemainingTime()
end

function RoundService.Client:IsRoundActive(): boolean
    return self.Server:IsRoundActive()
end

return RoundService
