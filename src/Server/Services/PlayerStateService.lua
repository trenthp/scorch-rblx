--!strict
--[[
    PlayerStateService.lua
    Tracks player freeze states and manages state transitions
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))

type PlayerStateData = {
    freezeState: string,
    frozenBy: Player?,
    frozenAt: number?,
}

local PlayerStateService = Knit.CreateService({
    Name = "PlayerStateService",

    Client = {
        PlayerFrozen = Knit.CreateSignal(),
        PlayerUnfrozen = Knit.CreateSignal(),
        StateChanged = Knit.CreateSignal(),
    },

    _playerStates = {} :: { [Player]: PlayerStateData },
    _frozenSignal = nil :: any,
    _unfrozenSignal = nil :: any,
})

function PlayerStateService:KnitInit()
    self._frozenSignal = Signal.new()
    self._unfrozenSignal = Signal.new()
    self._playerStates = {}
    print("[PlayerStateService] Initialized")
end

function PlayerStateService:KnitStart()
    Players.PlayerAdded:Connect(function(player)
        self:_initPlayerState(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self:_cleanupPlayer(player)
    end)

    -- Initialize existing players
    for _, player in Players:GetPlayers() do
        self:_initPlayerState(player)
    end

    print("[PlayerStateService] Started")
end

--[[
    Clean up player state (called on disconnect or mid-game leave)
]]
function PlayerStateService:_cleanupPlayer(player: Player)
    local state = self._playerStates[player]
    if state and state.freezeState == Enums.FreezeState.Frozen then
        -- Notify clients that player was unfrozen (left game)
        self.Client.PlayerUnfrozen:FireAll(player, player)
    end
    self._playerStates[player] = nil
end

--[[
    Handle player leaving game mid-round
    Called by QueueService when player voluntarily leaves
]]
function PlayerStateService:HandlePlayerLeaveGame(player: Player)
    local state = self._playerStates[player]
    if not state then
        return
    end

    -- If player was frozen, unfreeze them before cleanup
    if state.freezeState == Enums.FreezeState.Frozen then
        self:_applyFreezeToCharacter(player, false)
        self.Client.PlayerUnfrozen:FireAll(player, player)
        self.Client.StateChanged:Fire(player, Enums.FreezeState.Active)
    end

    -- Reset their state
    self._playerStates[player] = {
        freezeState = Enums.FreezeState.Active,
        frozenBy = nil,
        frozenAt = nil,
    }

    -- Remove from team and check win conditions
    local TeamService = Knit.GetService("TeamService")
    TeamService:RemovePlayerFromRound(player)
end

--[[
    Initialize a player's state
]]
function PlayerStateService:_initPlayerState(player: Player)
    self._playerStates[player] = {
        freezeState = Enums.FreezeState.Active,
        frozenBy = nil,
        frozenAt = nil,
    }
end

--[[
    Freeze a player (called by FlashlightService when hit)
    @param player - The player to freeze
    @param frozenBy - The seeker who froze them
]]
function PlayerStateService:FreezePlayer(player: Player, frozenBy: Player)
    local state = self._playerStates[player]
    if not state then
        return
    end

    -- Already frozen, ignore
    if state.freezeState == Enums.FreezeState.Frozen then
        return
    end

    -- Check for Shield effect (blocks freeze for runners)
    local BatteryService = Knit.GetService("BatteryService")
    if BatteryService:HasEffect(player, "Shield") then
        -- Consume the shield and block the freeze
        BatteryService:ConsumeShield(player, true)  -- true = defensive use
        print(string.format("[PlayerStateService] %s's shield blocked freeze from %s", player.Name, frozenBy.Name))
        return
    end

    -- Check if seeker has Shield effect (instant freeze)
    if BatteryService:HasEffect(frozenBy, "Shield") then
        -- Consume the shield for instant freeze bonus
        BatteryService:ConsumeShield(frozenBy, false)  -- false = offensive use
        print(string.format("[PlayerStateService] %s used shield for instant freeze on %s", frozenBy.Name, player.Name))
    end

    state.freezeState = Enums.FreezeState.Frozen
    state.frozenBy = frozenBy
    state.frozenAt = tick()

    -- Apply freeze effect to character
    self:_applyFreezeToCharacter(player, true)

    -- Fire signals
    self._frozenSignal:Fire(player, frozenBy)
    self.Client.PlayerFrozen:FireAll(player, frozenBy)
    self.Client.StateChanged:Fire(player, Enums.FreezeState.Frozen)

    print(string.format("[PlayerStateService] %s was frozen by %s", player.Name, frozenBy.Name))

    -- Check win condition
    self:_checkAllFrozen()
end

--[[
    Unfreeze a player (called by FreezeService when rescued)
    @param player - The player to unfreeze
    @param unfrozenBy - The runner who rescued them
]]
function PlayerStateService:UnfreezePlayer(player: Player, unfrozenBy: Player)
    local state = self._playerStates[player]
    if not state then
        return
    end

    -- Not frozen, ignore
    if state.freezeState ~= Enums.FreezeState.Frozen then
        return
    end

    state.freezeState = Enums.FreezeState.Active
    state.frozenBy = nil
    state.frozenAt = nil

    -- Remove freeze effect from character
    self:_applyFreezeToCharacter(player, false)

    -- Fire signals
    self._unfrozenSignal:Fire(player, unfrozenBy)
    self.Client.PlayerUnfrozen:FireAll(player, unfrozenBy)
    self.Client.StateChanged:Fire(player, Enums.FreezeState.Active)

    print(string.format("[PlayerStateService] %s was unfrozen by %s", player.Name, unfrozenBy.Name))
end

--[[
    Check if a player is frozen
]]
function PlayerStateService:IsFrozen(player: Player): boolean
    local state = self._playerStates[player]
    return state ~= nil and state.freezeState == Enums.FreezeState.Frozen
end

--[[
    Get a player's freeze state
]]
function PlayerStateService:GetFreezeState(player: Player): string
    local state = self._playerStates[player]
    if state then
        return state.freezeState
    end
    return Enums.FreezeState.Active
end

--[[
    Reset all player states (for new round)
]]
function PlayerStateService:ResetAllStates()
    for player, state in self._playerStates do
        -- Notify clients if player was frozen
        if state.freezeState == Enums.FreezeState.Frozen then
            self.Client.PlayerUnfrozen:FireAll(player, player) -- unfrozenBy self
            self.Client.StateChanged:Fire(player, Enums.FreezeState.Active)
        end

        self._playerStates[player] = {
            freezeState = Enums.FreezeState.Active,
            frozenBy = nil,
            frozenAt = nil,
        }
        self:_applyFreezeToCharacter(player, false)
    end
    print("[PlayerStateService] All player states reset")
end

--[[
    Get count of frozen runners
]]
function PlayerStateService:GetFrozenCount(): number
    local count = 0
    local TeamService = Knit.GetService("TeamService")

    for player, state in self._playerStates do
        if TeamService:IsRunner(player) and state.freezeState == Enums.FreezeState.Frozen then
            count += 1
        end
    end

    return count
end

--[[
    Apply freeze/unfreeze effect to character
]]
function PlayerStateService:_applyFreezeToCharacter(player: Player, frozen: boolean)
    local character = player.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?

    if frozen then
        -- Freeze the character
        if humanoid then
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
            humanoid.JumpHeight = 0
        end
        if rootPart then
            rootPart.Anchored = true
        end
    else
        -- Unfreeze the character
        if humanoid then
            humanoid.WalkSpeed = 16 -- Default walk speed
            humanoid.JumpPower = 50 -- Default jump power
            humanoid.JumpHeight = 7.2 -- Default jump height
        end
        if rootPart then
            rootPart.Anchored = false
        end
    end
end

--[[
    Check if all runners are frozen (win condition)
]]
function PlayerStateService:_checkAllFrozen()
    local TeamService = Knit.GetService("TeamService")
    local runners = TeamService:GetRunners()

    if #runners == 0 then
        return
    end

    local allFrozen = true
    for _, runner in runners do
        if not self:IsFrozen(runner) then
            allFrozen = false
            break
        end
    end

    if allFrozen then
        local RoundService = Knit.GetService("RoundService")
        RoundService:EndRound(Enums.WinnerTeam.Seekers, Enums.RoundEndReason.AllFrozen)
    end
end

--[[
    Subscribe to frozen events
]]
function PlayerStateService:OnPlayerFrozen(callback: (player: Player, frozenBy: Player) -> ())
    return self._frozenSignal:Connect(callback)
end

--[[
    Subscribe to unfrozen events
]]
function PlayerStateService:OnPlayerUnfrozen(callback: (player: Player, unfrozenBy: Player) -> ())
    return self._unfrozenSignal:Connect(callback)
end

-- Client methods
function PlayerStateService.Client:GetMyState(player: Player): string
    return self.Server:GetFreezeState(player)
end

function PlayerStateService.Client:IsFrozen(player: Player): boolean
    return self.Server:IsFrozen(player)
end

return PlayerStateService
