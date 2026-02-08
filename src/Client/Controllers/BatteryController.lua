--!strict
--[[
    BatteryController.lua
    Client-side battery and power-up management

    Features:
    - Listen to battery spawn/collect events
    - Handle keybinds for stored battery activation (1-4)
    - Track active effects locally for UI updates
    - Manage PowerUpBar UI component
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))
local Signal = require(Packages:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BatteryConfig = require(Shared:WaitForChild("BatteryConfig"))

local LocalPlayer = Players.LocalPlayer

type LocalActiveEffect = {
    effectId: string,
    endTime: number,
    duration: number,
}

local BatteryController = Knit.CreateController({
    Name = "BatteryController",

    _activeEffects = {} :: { [string]: LocalActiveEffect },
    _storedBatteries = {} :: { BatteryConfig.StoredBattery },
    _currencyAmount = 0,
    _powerUpBar = nil :: any,

    -- Vision effect: highlights on enemy characters
    _visionHighlights = {} :: { [Player]: Highlight },

    -- Track stealth status for ALL players (not just local)
    _stealthPlayers = {} :: { [Player]: boolean },

    -- Signals for UI components
    _effectActivatedSignal = nil :: any,
    _effectExpiredSignal = nil :: any,
    _storedBatteriesChangedSignal = nil :: any,
    _currencyChangedSignal = nil :: any,
    _stealthChangedSignal = nil :: any,
})

function BatteryController:KnitInit()
    self._activeEffects = {}
    self._storedBatteries = {}
    self._currencyAmount = 0

    self._effectActivatedSignal = Signal.new()
    self._effectExpiredSignal = Signal.new()
    self._storedBatteriesChangedSignal = Signal.new()
    self._currencyChangedSignal = Signal.new()
    self._stealthChangedSignal = Signal.new()
    self._visionHighlights = {}
    self._stealthPlayers = {}

    print("[BatteryController] Initialized")
end

function BatteryController:KnitStart()
    local BatteryService = Knit.GetService("BatteryService")
    local DataService = Knit.GetService("DataService")

    -- Listen for power-up activations (track ALL players for stealth/vision)
    BatteryService.PowerUpActivated:Connect(function(player, effectId, duration)
        if player == LocalPlayer then
            self:_onEffectActivated(effectId, duration)
        end
        -- Track stealth for all players
        if effectId == "Stealth" then
            self._stealthPlayers[player] = true
            self._stealthChangedSignal:Fire(player, true)
        end
    end)

    -- Listen for power-up expirations
    BatteryService.PowerUpExpired:Connect(function(player, effectId)
        if player == LocalPlayer then
            self:_onEffectExpired(effectId)
        end
        -- Track stealth removal for all players
        if effectId == "Stealth" then
            self._stealthPlayers[player] = nil
            self._stealthChangedSignal:Fire(player, false)
        end
    end)

    -- Clean up on player leave
    Players.PlayerRemoving:Connect(function(player)
        self._stealthPlayers[player] = nil
        self:_removeVisionHighlight(player)
    end)

    -- Listen for stored battery updates (targeted Fire, no player arg on client)
    BatteryService.StoredBatteryUpdated:Connect(function(storedBatteries)
        self._storedBatteries = storedBatteries
        self._storedBatteriesChangedSignal:Fire(storedBatteries)
    end)

    -- Listen for currency updates (targeted Fire, no player arg on client)
    BatteryService.CurrencyUpdated:Connect(function(newAmount)
        self._currencyAmount = newAmount
        self._currencyChangedSignal:Fire(newAmount)
    end)

    -- Listen for shield consumed (targeted Fire, no player arg on client)
    BatteryService.ShieldConsumed:Connect(function(wasDefensive)
        self:_onShieldConsumed(wasDefensive)
    end)

    -- Load initial data
    task.spawn(function()
        local data = DataService:GetMyData()
        if data then
            -- Get initial battery count
            local batteries = DataService:GetBatteries()
            self._currencyAmount = batteries
            self._currencyChangedSignal:Fire(batteries)

            -- Get initial stored batteries
            local stored = DataService:GetStoredBatteries()
            self._storedBatteries = stored
            self._storedBatteriesChangedSignal:Fire(stored)
        end
    end)

    -- Set up keybinds for stored battery activation
    self:_setupKeybinds()

    print("[BatteryController] Started")
end

--[[
    Set up keybinds for activating stored batteries
]]
function BatteryController:_setupKeybinds()
    local keybinds = {
        { name = "ActivateBattery1", key = Enum.KeyCode.One, slot = 1 },
        { name = "ActivateBattery2", key = Enum.KeyCode.Two, slot = 2 },
        { name = "ActivateBattery3", key = Enum.KeyCode.Three, slot = 3 },
        { name = "ActivateBattery4", key = Enum.KeyCode.Four, slot = 4 },
    }

    for _, bind in keybinds do
        ContextActionService:BindAction(
            bind.name,
            function(actionName, inputState, inputObject)
                if inputState == Enum.UserInputState.Begin then
                    self:ActivateStoredBattery(bind.slot)
                end
            end,
            false,
            bind.key
        )
    end
end

--[[
    Activate a stored battery by slot
    @param slotIndex - The slot to activate (1-4)
]]
function BatteryController:ActivateStoredBattery(slotIndex: number)
    -- Check if slot has a battery
    if slotIndex > #self._storedBatteries then
        return
    end

    -- Request activation from server
    local BatteryService = Knit.GetService("BatteryService")
    local success = BatteryService:ActivateStoredBattery(slotIndex)

    if success then
        print(string.format("[BatteryController] Activated battery in slot %d", slotIndex))
    end
end

--[[
    Handle effect activation
]]
function BatteryController:_onEffectActivated(effectId: string, duration: number)
    local endTime = tick() + duration

    self._activeEffects[effectId] = {
        effectId = effectId,
        endTime = endTime,
        duration = duration,
    }

    self._effectActivatedSignal:Fire(effectId, duration)

    -- Apply client-side effects
    if effectId == "Vision" then
        self:_applyVisionEffect()
    elseif effectId == "Stealth" then
        self:_applyStealthEffect(true)
    end

    print(string.format("[BatteryController] Effect activated: %s for %d seconds", effectId, duration))
end

--[[
    Handle effect expiration
]]
function BatteryController:_onEffectExpired(effectId: string)
    self._activeEffects[effectId] = nil
    self._effectExpiredSignal:Fire(effectId)

    -- Remove client-side effects
    if effectId == "Vision" then
        self:_removeAllVisionHighlights()
    elseif effectId == "Stealth" then
        self:_applyStealthEffect(false)
    end

    print(string.format("[BatteryController] Effect expired: %s", effectId))
end

--[[
    Handle shield consumed
]]
function BatteryController:_onShieldConsumed(wasDefensive: boolean)
    -- Effect removal is handled by _onEffectExpired
    if wasDefensive then
        print("[BatteryController] Shield blocked a freeze!")
    else
        print("[BatteryController] Shield used for instant freeze!")
    end
end

--[[
    Check if local player has an active effect
    @param effectId - The effect to check
    @return boolean - Whether the effect is active
]]
function BatteryController:HasEffect(effectId: string): boolean
    return self._activeEffects[effectId] ~= nil
end

--[[
    Get remaining time for an effect
    @param effectId - The effect
    @return number - Remaining seconds (0 if not active)
]]
function BatteryController:GetEffectRemainingTime(effectId: string): number
    local effect = self._activeEffects[effectId]
    if not effect then
        return 0
    end
    return math.max(0, effect.endTime - tick())
end

--[[
    Get all active effects
    @return { [string]: LocalActiveEffect }
]]
function BatteryController:GetActiveEffects(): { [string]: LocalActiveEffect }
    return self._activeEffects
end

--[[
    Get stored batteries
    @return { StoredBattery }
]]
function BatteryController:GetStoredBatteries(): { BatteryConfig.StoredBattery }
    return self._storedBatteries
end

--[[
    Get current currency amount
    @return number
]]
function BatteryController:GetCurrency(): number
    return self._currencyAmount
end

--[[
    Get the effect multiplier (for local calculations like stealth)
    @param effectId - The effect
    @return number - The modifier (1.0 if not active)
]]
function BatteryController:GetEffectMultiplier(effectId: string): number
    if not self:HasEffect(effectId) then
        return 1.0
    end

    local effect = BatteryConfig.getEffect(effectId)
    if not effect then
        return 1.0
    end

    -- Determine role using Team objects (client-safe)
    local myTeam = LocalPlayer.Team
    local isRunner = myTeam and myTeam.Name == "Runners"
    return isRunner and effect.runnerModifier or effect.seekerModifier
end

--[[
    Subscribe to effect activated events
]]
function BatteryController:OnEffectActivated(callback: (effectId: string, duration: number) -> ())
    return self._effectActivatedSignal:Connect(callback)
end

--[[
    Subscribe to effect expired events
]]
function BatteryController:OnEffectExpired(callback: (effectId: string) -> ())
    return self._effectExpiredSignal:Connect(callback)
end

--[[
    Subscribe to stored batteries changed events
]]
function BatteryController:OnStoredBatteriesChanged(callback: (storedBatteries: { BatteryConfig.StoredBattery }) -> ())
    return self._storedBatteriesChangedSignal:Connect(callback)
end

--[[
    Subscribe to currency changed events
]]
function BatteryController:OnCurrencyChanged(callback: (amount: number) -> ())
    return self._currencyChangedSignal:Connect(callback)
end

--[[
    Set the PowerUpBar UI component reference
]]
function BatteryController:SetPowerUpBar(powerUpBar: any)
    self._powerUpBar = powerUpBar
end

--==============================================================================
-- VISION EFFECT (highlight enemies through walls)
--==============================================================================

function BatteryController:_applyVisionEffect()
    self:_removeAllVisionHighlights()

    local TeamService = Knit.GetService("TeamService")
    local myTeam = LocalPlayer.Team

    for _, player in Players:GetPlayers() do
        if player ~= LocalPlayer and player.Team ~= myTeam then
            self:_addVisionHighlight(player)
        end
    end
end

function BatteryController:_addVisionHighlight(player: Player)
    local character = player.Character
    if not character then
        return
    end

    -- Remove existing highlight
    self:_removeVisionHighlight(player)

    local highlight = Instance.new("Highlight")
    highlight.Name = "VisionHighlight"
    highlight.Adornee = character
    highlight.FillColor = Color3.fromRGB(85, 220, 255)
    highlight.FillTransparency = 0.6
    highlight.OutlineColor = Color3.fromRGB(85, 220, 255)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = character

    self._visionHighlights[player] = highlight
end

function BatteryController:_removeVisionHighlight(player: Player)
    local highlight = self._visionHighlights[player]
    if highlight then
        highlight:Destroy()
        self._visionHighlights[player] = nil
    end
end

function BatteryController:_removeAllVisionHighlights()
    for player in self._visionHighlights do
        self:_removeVisionHighlight(player)
    end
    self._visionHighlights = {}
end

--==============================================================================
-- STEALTH EFFECT (hide nametag from enemies)
--==============================================================================

function BatteryController:_applyStealthEffect(active: boolean)
    -- Hide local player's overhead display name when stealthed
    local character = LocalPlayer.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    if active then
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    else
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
        humanoid.NameDisplayDistance = 100
    end
end

--[[
    Check if a player has stealth active (used by NameTagController)
]]
function BatteryController:IsPlayerStealthed(player: Player): boolean
    return self._stealthPlayers[player] == true
end

--[[
    Subscribe to stealth state changes for any player
]]
function BatteryController:OnStealthChanged(callback: (player: Player, active: boolean) -> ())
    return self._stealthChangedSignal:Connect(callback)
end

return BatteryController
