--!strict
--[[
    CrouchService.lua
    Server-side crouch state management
    - Tracks which players are crouching
    - Replicates crouch visuals to other players
    - Provides crouch state for flashlight detection
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

local CrouchService = Knit.CreateService({
    Name = "CrouchService",

    Client = {
        PlayerCrouchChanged = Knit.CreateSignal(), -- Fired to all clients when someone crouches
    },

    _crouchingPlayers = {} :: { [Player]: boolean },
    _animationTracks = {} :: { [Model]: AnimationTrack },
})

-- Configuration
local CROUCH_HIP_HEIGHT_MULTIPLIER = Constants.CROUCH.HIP_HEIGHT_MULTIPLIER
local CROUCH_SPEED_MULTIPLIER = Constants.CROUCH.SPEED_MULTIPLIER
local CROUCH_TWEEN_TIME = Constants.CROUCH.TWEEN_TIME
-- Animation disabled - set to empty string or valid ID if you have one
local CROUCH_ANIMATION_ID = "" -- Disabled until valid animation is provided

function CrouchService:KnitInit()
    self._crouchingPlayers = {}
    self._animationTracks = {}
    print("[CrouchService] Initialized")
end

function CrouchService:KnitStart()
    -- Clean up on player leave
    Players.PlayerRemoving:Connect(function(player)
        self._crouchingPlayers[player] = nil
    end)

    -- Reset crouch on death
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(_character)
            if self._crouchingPlayers[player] then
                self._crouchingPlayers[player] = false
                self.Client.PlayerCrouchChanged:FireAll(player, false)
            end
        end)
    end)

    -- Handle existing players
    for _, player in Players:GetPlayers() do
        player.CharacterAdded:Connect(function(_character)
            if self._crouchingPlayers[player] then
                self._crouchingPlayers[player] = false
                self.Client.PlayerCrouchChanged:FireAll(player, false)
            end
        end)
    end

    -- Subscribe to game state changes - stand everyone up when leaving gameplay
    local GameStateService = Knit.GetService("GameStateService")
    GameStateService:OnStateChanged(function(newState)
        if newState ~= Enums.GameState.GAMEPLAY then
            self:_standUpAllPlayers()
        end
    end)

    print("[CrouchService] Started")
end

--[[
    Stand up all crouching players
]]
function CrouchService:_standUpAllPlayers()
    for player, isCrouching in self._crouchingPlayers do
        if isCrouching then
            self._crouchingPlayers[player] = false
            self:_applyCrouchVisuals(player, false)
            self.Client.PlayerCrouchChanged:FireAll(player, false)
        end
    end
end

--[[
    Apply crouch visuals to a player's character (server-side for replication)
]]
function CrouchService:_applyCrouchVisuals(player: Player, isCrouching: boolean)
    local character = player.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    if isCrouching then
        -- Store original values as attributes if not already stored
        if not character:GetAttribute("OriginalHipHeight") then
            character:SetAttribute("OriginalHipHeight", humanoid.HipHeight)
            character:SetAttribute("OriginalWalkSpeed", humanoid.WalkSpeed)
            character:SetAttribute("OriginalJumpPower", humanoid.JumpPower)
        end

        local originalHipHeight = character:GetAttribute("OriginalHipHeight") :: number
        local originalWalkSpeed = character:GetAttribute("OriginalWalkSpeed") :: number

        humanoid.HipHeight = originalHipHeight * CROUCH_HIP_HEIGHT_MULTIPLIER
        humanoid.WalkSpeed = originalWalkSpeed * CROUCH_SPEED_MULTIPLIER
        humanoid.JumpPower = 0

        -- Play crouch animation
        self:_playCrouchAnimation(humanoid, true)
    else
        -- Restore original values
        local originalHipHeight = character:GetAttribute("OriginalHipHeight")
        local originalWalkSpeed = character:GetAttribute("OriginalWalkSpeed")
        local originalJumpPower = character:GetAttribute("OriginalJumpPower")

        if originalHipHeight then
            humanoid.HipHeight = originalHipHeight
        end
        if originalWalkSpeed then
            humanoid.WalkSpeed = originalWalkSpeed
        end
        if originalJumpPower then
            humanoid.JumpPower = originalJumpPower
        end

        -- Stop crouch animation
        self:_playCrouchAnimation(humanoid, false)
    end
end

--[[
    Play or stop the crouch animation on a humanoid
]]
function CrouchService:_playCrouchAnimation(humanoid: Humanoid, play: boolean)
    -- Skip if no animation ID configured
    if CROUCH_ANIMATION_ID == "" then
        return
    end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        return
    end

    local character = humanoid.Parent :: Model
    if not character then
        return
    end

    if play then
        -- Load and play animation
        local animation = Instance.new("Animation")
        animation.AnimationId = CROUCH_ANIMATION_ID

        local success, track = pcall(function()
            return animator:LoadAnimation(animation)
        end)

        if success and track then
            track.Priority = Enum.AnimationPriority.Action
            track.Looped = true
            track:Play(CROUCH_TWEEN_TIME)

            -- Store the track in a table for later access
            if not self._animationTracks then
                self._animationTracks = {}
            end
            self._animationTracks[character] = track
        else
            warn("[CrouchService] Failed to load crouch animation")
        end

        -- Clean up the animation instance
        animation:Destroy()
    else
        -- Stop animation
        if self._animationTracks and self._animationTracks[character] then
            self._animationTracks[character]:Stop(CROUCH_TWEEN_TIME)
            self._animationTracks[character] = nil
        end
    end
end

--[[
    Check if a player is crouching
]]
function CrouchService:IsCrouching(player: Player): boolean
    return self._crouchingPlayers[player] == true
end

--[[
    Get the detection height offset for a player (lower when crouching)
]]
function CrouchService:GetDetectionHeightOffset(player: Player): number
    if self:IsCrouching(player) then
        return Constants.CROUCH.DETECTION_HEIGHT_OFFSET
    end
    return 0
end

-- ============================================
-- CLIENT METHODS
-- ============================================

--[[
    Client calls this to set their crouch state
]]
function CrouchService.Client:SetCrouching(player: Player, isCrouching: boolean)
    -- Validate that player can crouch (must be a runner during gameplay)
    local GameStateService = Knit.GetService("GameStateService")
    local TeamService = Knit.GetService("TeamService")

    if GameStateService:GetState() ~= Enums.GameState.GAMEPLAY then
        return
    end

    local role = TeamService:GetPlayerRole(player)
    if role ~= Enums.PlayerRole.Runner then
        return -- Only runners can crouch
    end

    -- Update state
    local wasCrouching = self.Server._crouchingPlayers[player] == true
    self.Server._crouchingPlayers[player] = isCrouching

    -- Apply visuals if state changed
    if wasCrouching ~= isCrouching then
        self.Server:_applyCrouchVisuals(player, isCrouching)
        -- Notify all clients
        self.Server.Client.PlayerCrouchChanged:FireAll(player, isCrouching)
    end
end

function CrouchService.Client:IsCrouching(player: Player, targetPlayer: Player): boolean
    return self.Server:IsCrouching(targetPlayer)
end

return CrouchService
