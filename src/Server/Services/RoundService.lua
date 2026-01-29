--!strict
--[[
    RoundService.lua
    Manages round timing, phases, and win conditions

    Gameplay phases:
    1. COUNTDOWN (5 sec) - All players frozen, countdown displayed
    2. HIDING (15 sec) - Runners can move, seekers still frozen
    3. ACTIVE (3 min) - Everyone can move, main gameplay
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
        PhaseChanged = Knit.CreateSignal(),      -- (phase: string, data: any)
        CountdownTick = Knit.CreateSignal(),     -- (seconds: number, phase: string)
        RoundTimerUpdate = Knit.CreateSignal(),  -- (seconds: number)
        RoundEnded = Knit.CreateSignal(),        -- (results: table)
    },

    _roundActive = false,
    _currentPhase = nil :: string?,
    _roundStartTime = 0,        -- When ACTIVE phase started
    _roundEndTime = 0,
    _timerConnection = nil :: thread?,
    _roundEndedSignal = nil :: any,
    _phaseChangedSignal = nil :: any,
    _countdownTickSignal = nil :: any,  -- For server-side audio
    _lastWinner = nil :: string?,
    _lastEndReason = nil :: string?,
})

function RoundService:KnitInit()
    self._roundEndedSignal = Signal.new()
    self._phaseChangedSignal = Signal.new()
    self._countdownTickSignal = Signal.new()
    print("[RoundService] Initialized")
end

function RoundService:KnitStart()
    print("[RoundService] Started")
end

--[[
    Start a new round - handles all phases internally
]]
function RoundService:StartRound()
    print("[RoundService] Starting round")

    self._roundActive = true

    -- Reset player states
    local PlayerStateService = Knit.GetService("PlayerStateService")
    PlayerStateService:ResetAllStates()

    -- Spawn all players to their team positions
    local MapService = Knit.GetService("MapService")
    MapService:SpawnAllPlayers()

    -- Freeze ALL players during countdown
    self:_freezeAllPlayers()

    -- Start the phase sequence
    task.spawn(function()
        -- Phase 1: COUNTDOWN (5 seconds)
        self:_runCountdownPhase()

        if not self._roundActive then return end

        -- Phase 2: HIDING (15 seconds) - Runners can move
        self:_runHidingPhase()

        if not self._roundActive then return end

        -- Phase 3: ACTIVE (3 minutes) - Everyone can move
        self:_runActivePhase()
    end)
end

--[[
    Phase 1: Countdown - All players frozen, showing countdown
]]
function RoundService:_runCountdownPhase()
    self._currentPhase = Enums.GameplayPhase.COUNTDOWN
    self.Client.PhaseChanged:FireAll(Enums.GameplayPhase.COUNTDOWN, {
        duration = Constants.GET_READY_DURATION,
    })
    self._phaseChangedSignal:Fire(Enums.GameplayPhase.COUNTDOWN)
    print("[RoundService] Phase: COUNTDOWN")

    -- Countdown from GET_READY_DURATION to 1
    for i = Constants.GET_READY_DURATION, 1, -1 do
        if not self._roundActive then return end
        self.Client.CountdownTick:FireAll(i, Enums.GameplayPhase.COUNTDOWN)
        self._countdownTickSignal:Fire(i, Enums.GameplayPhase.COUNTDOWN)
        task.wait(1)
    end

    self.Client.CountdownTick:FireAll(0, Enums.GameplayPhase.COUNTDOWN)
end

--[[
    Phase 2: Hiding - Runners can move, seekers frozen
]]
function RoundService:_runHidingPhase()
    self._currentPhase = Enums.GameplayPhase.HIDING
    self.Client.PhaseChanged:FireAll(Enums.GameplayPhase.HIDING, {
        duration = Constants.HIDING_DURATION,
    })
    self._phaseChangedSignal:Fire(Enums.GameplayPhase.HIDING)
    print("[RoundService] Phase: HIDING")

    -- Unfreeze runners only
    self:_unfreezeRunners()

    -- Countdown the hiding time
    for i = Constants.HIDING_DURATION, 1, -1 do
        if not self._roundActive then return end
        self.Client.CountdownTick:FireAll(i, Enums.GameplayPhase.HIDING)
        self._countdownTickSignal:Fire(i, Enums.GameplayPhase.HIDING)
        task.wait(1)
    end

    self.Client.CountdownTick:FireAll(0, Enums.GameplayPhase.HIDING)
end

--[[
    Phase 3: Active gameplay - Everyone can move, timer running
]]
function RoundService:_runActivePhase()
    self._currentPhase = Enums.GameplayPhase.ACTIVE
    self._roundStartTime = tick()
    self._roundEndTime = self._roundStartTime + Constants.ROUND_DURATION

    self.Client.PhaseChanged:FireAll(Enums.GameplayPhase.ACTIVE, {
        duration = Constants.ROUND_DURATION,
        startTime = self._roundStartTime,
    })
    self._phaseChangedSignal:Fire(Enums.GameplayPhase.ACTIVE)
    print("[RoundService] Phase: ACTIVE")

    -- Unfreeze seekers
    self:_unfreezeSeekers()

    -- Start the round timer
    self:_startRoundTimer()
end

--[[
    Freeze all players (used at round start)
]]
function RoundService:_freezeAllPlayers()
    local TeamService = Knit.GetService("TeamService")
    local allPlayers = {}

    for _, player in TeamService:GetSeekers() do
        table.insert(allPlayers, player)
    end
    for _, player in TeamService:GetRunners() do
        table.insert(allPlayers, player)
    end

    for _, player in allPlayers do
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 0
                humanoid.JumpPower = 0
            end
        end
    end
end

--[[
    Unfreeze runners only
]]
function RoundService:_unfreezeRunners()
    local TeamService = Knit.GetService("TeamService")
    local runners = TeamService:GetRunners()

    for _, runner in runners do
        local character = runner.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 16
                humanoid.JumpPower = 50
            end
        end
    end
    print("[RoundService] Runners unfrozen")
end

--[[
    Unfreeze seekers
]]
function RoundService:_unfreezeSeekers()
    local TeamService = Knit.GetService("TeamService")
    local seekers = TeamService:GetSeekers()

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
    print("[RoundService] Seekers unfrozen - HUNT!")
end

--[[
    Start the round timer loop (only during ACTIVE phase)
]]
function RoundService:_startRoundTimer()
    print("[RoundService] Starting timer loop")

    local lastTickSecond = -1  -- Track last countdown tick to avoid duplicates

    self._timerConnection = task.spawn(function()
        while self._roundActive and self._currentPhase == Enums.GameplayPhase.ACTIVE do
            local now = tick()
            local remaining = self._roundEndTime - now
            local remainingSeconds = math.ceil(remaining)

            -- Send update to clients
            self.Client.RoundTimerUpdate:FireAll(math.max(0, remainingSeconds))

            -- Fire countdown tick for last 15 seconds (for audio)
            if remainingSeconds <= 15 and remainingSeconds > 0 and remainingSeconds ~= lastTickSecond then
                lastTickSecond = remainingSeconds
                self._countdownTickSignal:Fire(remainingSeconds, Enums.GameplayPhase.ACTIVE)
            end

            -- Check if time is up
            if remaining <= 0 then
                print("[RoundService] Time's up! Ending round...")
                self:EndRound(Enums.WinnerTeam.Runners, Enums.RoundEndReason.TimeUp)
                return
            end

            task.wait(0.5)
        end
        print("[RoundService] Timer loop exited")
    end)
end

--[[
    End the round with a winner
    @param winner - "Seekers" or "Runners"
    @param reason - Why the round ended
]]
function RoundService:EndRound(winner: string, reason: string)
    print(string.format("[RoundService] EndRound called. Winner: %s, Reason: %s, Active: %s",
        winner, reason, tostring(self._roundActive)))

    if not self._roundActive then
        print("[RoundService] Round not active, ignoring EndRound call")
        return
    end

    print(string.format("[RoundService] Round ended. Winner: %s, Reason: %s", winner, reason))

    self._roundActive = false
    self._currentPhase = nil
    self._lastWinner = winner
    self._lastEndReason = reason

    -- Stop timer (use pcall since we might be calling from within the timer thread itself)
    if self._timerConnection then
        pcall(function()
            task.cancel(self._timerConnection)
        end)
        self._timerConnection = nil
    end

    -- Get round stats
    local PlayerStateService = Knit.GetService("PlayerStateService")
    local TeamService = Knit.GetService("TeamService")

    local frozenCount = PlayerStateService:GetFrozenCount()
    local totalRunners = #TeamService:GetRunners()

    -- Calculate duration based on when we actually started active gameplay
    local duration = 0
    if self._roundStartTime > 0 then
        duration = tick() - self._roundStartTime
    end

    local results = {
        winner = winner,
        reason = reason,
        frozenCount = frozenCount,
        totalRunners = totalRunners,
        duration = duration,
    }

    -- Notify clients
    self.Client.RoundEnded:FireAll(results)

    -- Fire internal signal
    self._roundEndedSignal:Fire(results)

    -- Unfreeze all players
    PlayerStateService:ResetAllStates()

    -- Restore all player movement
    local seekers = TeamService:GetSeekers()
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

    local runners = TeamService:GetRunners()
    for _, runner in runners do
        local character = runner.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 16
                humanoid.JumpPower = 50
            end
        end
    end

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
    Get current gameplay phase
]]
function RoundService:GetCurrentPhase(): string?
    return self._currentPhase
end

--[[
    Get remaining time in seconds (only valid during ACTIVE phase)
]]
function RoundService:GetRemainingTime(): number
    if not self._roundActive or self._currentPhase ~= Enums.GameplayPhase.ACTIVE then
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

--[[
    Subscribe to phase changed event (for server-side subscribers)
]]
function RoundService:OnPhaseChanged(callback: (phase: string) -> ())
    return self._phaseChangedSignal:Connect(callback)
end

--[[
    Subscribe to countdown tick event (for server-side audio)
    Fires during COUNTDOWN, HIDING, and last 15 seconds of ACTIVE phase
]]
function RoundService:OnCountdownTick(callback: (seconds: number, phase: string) -> ())
    return self._countdownTickSignal:Connect(callback)
end

-- Client methods
function RoundService.Client:GetRemainingTime(): number
    return self.Server:GetRemainingTime()
end

function RoundService.Client:IsRoundActive(): boolean
    return self.Server:IsRoundActive()
end

function RoundService.Client:GetCurrentPhase(): string?
    return self.Server:GetCurrentPhase()
end

return RoundService
