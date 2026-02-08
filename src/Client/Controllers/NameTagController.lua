--!strict
--[[
    NameTagController.lua
    Manages player nametags with level badges and titles
    Hides enemy team player names during gameplay rounds
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))

local LocalPlayer = Players.LocalPlayer

local NameTagController = Knit.CreateController({
    Name = "NameTagController",

    _connections = {} :: { [Player]: RBXScriptConnection },
    _nameTags = {} :: { [Player]: BillboardGui },
    _isGameplay = false,
})

function NameTagController:KnitInit()
    print("[NameTagController] Initialized")
end

function NameTagController:KnitStart()
    local GameStateController = Knit.GetController("GameStateController")

    -- Listen for state changes
    GameStateController:OnStateChanged(function(newState, oldState)
        self:_onGameStateChanged(newState, oldState)
    end)

    -- Handle existing players
    for _, player in Players:GetPlayers() do
        self:_setupPlayer(player)
    end

    -- Handle new players joining
    Players.PlayerAdded:Connect(function(player)
        self:_setupPlayer(player)
    end)

    -- Handle players leaving
    Players.PlayerRemoving:Connect(function(player)
        self:_cleanupPlayer(player)
    end)

    -- Check initial state
    local currentState = GameStateController:GetState()
    if currentState == Enums.GameState.GAMEPLAY then
        self._isGameplay = true
        self:_updateAllNameTags()
    end

    -- Listen for progression updates to refresh nametags
    local ProgressionController = Knit.GetController("ProgressionController")
    ProgressionController:OnProgressionUpdated(function()
        self:_updateAllCustomNameTags()
    end)

    -- Listen for stealth changes to hide/show nametags
    local BatteryController = Knit.GetController("BatteryController")
    BatteryController:OnStealthChanged(function(player, active)
        self:_updatePlayerNameTag(player)
        self:_updateCustomNameTagVisibility(player)
    end)

    print("[NameTagController] Started")
end

--[[
    Handle game state changes
]]
function NameTagController:_onGameStateChanged(newState: string, _oldState: string)
    local wasGameplay = self._isGameplay
    self._isGameplay = (newState == Enums.GameState.GAMEPLAY)

    print("[NameTagController] Game state changed to:", newState, "isGameplay:", self._isGameplay)

    -- Update name tags when entering or leaving gameplay
    if self._isGameplay ~= wasGameplay then
        print("[NameTagController] Updating all name tags...")
        self:_updateAllNameTags()
    end
end

--[[
    Setup a player for name tag tracking
]]
function NameTagController:_setupPlayer(player: Player)
    -- Handle current character (including local player for custom nametag)
    if player.Character then
        self:_updatePlayerNameTag(player)
        self:_createCustomNameTag(player)
    end

    -- Handle character respawns
    local connection = player.CharacterAdded:Connect(function(_character)
        task.defer(function()
            self:_updatePlayerNameTag(player)
            self:_createCustomNameTag(player)
        end)
    end)

    self._connections[player] = connection
end

--[[
    Cleanup player connections
]]
function NameTagController:_cleanupPlayer(player: Player)
    local connection = self._connections[player]
    if connection then
        connection:Disconnect()
        self._connections[player] = nil
    end

    -- Cleanup custom nametag
    local nameTag = self._nameTags[player]
    if nameTag then
        nameTag:Destroy()
        self._nameTags[player] = nil
    end
end

--[[
    Update all player name tags
]]
function NameTagController:_updateAllNameTags()
    for _, player in Players:GetPlayers() do
        if player ~= LocalPlayer then
            self:_updatePlayerNameTag(player)
        end
        self:_updateCustomNameTagVisibility(player)
    end
end

--[[
    Update a single player's name tag visibility
]]
function NameTagController:_updatePlayerNameTag(player: Player)
    local character = player.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    if self._isGameplay then
        -- During gameplay, check if enemy team or stealthed
        local isEnemy = self:_isEnemyTeam(player)
        local isStealthed = self:_isPlayerStealthed(player)
        if isEnemy or isStealthed then
            -- Hide name for enemies and stealthed players
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        else
            -- Show name for teammates
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
            humanoid.NameDisplayDistance = 100
            humanoid.HealthDisplayDistance = 0 -- Hide health bar
        end
    else
        -- Outside gameplay, show all names
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
        humanoid.NameDisplayDistance = 100
        humanoid.HealthDisplayDistance = 0
    end
end

--[[
    Check if a player is on the enemy team relative to local player
]]
function NameTagController:_isEnemyTeam(otherPlayer: Player): boolean
    -- Get other player's team
    local myTeam = LocalPlayer.Team
    local otherTeam = otherPlayer.Team

    print("[NameTagController] Checking enemy team - MyTeam:", myTeam and myTeam.Name or "nil", "OtherTeam:", otherTeam and otherTeam.Name or "nil")

    -- If either has no team, consider them not enemy (spectator scenario)
    if not myTeam or not otherTeam then
        return false
    end

    -- Different teams = enemy
    return myTeam ~= otherTeam
end

--[[
    Create a custom nametag with level badge and title
]]
function NameTagController:_createCustomNameTag(player: Player)
    local character = player.Character
    if not character then
        return
    end

    local head = character:WaitForChild("Head", 3)
    if not head then
        return
    end

    -- Remove existing custom nametag
    local existing = self._nameTags[player]
    if existing then
        existing:Destroy()
    end

    -- Get player's level and title
    local ProgressionController = Knit.GetController("ProgressionController")
    local level = ProgressionController:GetPlayerLevel(player)
    local title = ProgressionController:GetPlayerTitle(player)
    local titleColor = ProgressionConfig.getTitleColor(title)

    -- Create BillboardGui
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CustomNameTag"
    billboard.Size = UDim2.new(0, 150, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = false
    billboard.MaxDistance = 100
    billboard.Parent = head

    -- Level badge container
    local badgeFrame = Instance.new("Frame")
    badgeFrame.Name = "Badge"
    badgeFrame.Size = UDim2.new(0, 24, 0, 24)
    badgeFrame.Position = UDim2.new(0.5, -60, 0, 0)
    badgeFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    badgeFrame.Parent = billboard

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0.5, 0)
    badgeCorner.Parent = badgeFrame

    local badgeStroke = Instance.new("UIStroke")
    badgeStroke.Color = titleColor
    badgeStroke.Thickness = 2
    badgeStroke.Parent = badgeFrame

    local levelLabel = Instance.new("TextLabel")
    levelLabel.Size = UDim2.new(1, 0, 1, 0)
    levelLabel.BackgroundTransparency = 1
    levelLabel.Text = tostring(level)
    levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    levelLabel.TextSize = 12
    levelLabel.Font = Enum.Font.GothamBold
    levelLabel.Parent = badgeFrame

    -- Title label
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(0, 100, 0, 18)
    titleLabel.Position = UDim2.new(0.5, -35, 0, 3)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = titleColor
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextStrokeTransparency = 0.5
    titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    titleLabel.Parent = billboard

    self._nameTags[player] = billboard

    -- Update visibility based on game state
    self:_updateCustomNameTagVisibility(player)
end

--[[
    Update custom nametag visibility based on game state
]]
function NameTagController:_updateCustomNameTagVisibility(player: Player)
    local billboard = self._nameTags[player]
    if not billboard then
        return
    end

    if self._isGameplay then
        -- During gameplay, hide enemy/stealthed nametags but show teammate nametags
        if player == LocalPlayer then
            -- Always hide own nametag (can't see it anyway)
            billboard.Enabled = false
        elseif self:_isEnemyTeam(player) or self:_isPlayerStealthed(player) then
            -- Hide enemy and stealthed player nametags
            billboard.Enabled = false
        else
            -- Show teammate nametags
            billboard.Enabled = true
        end
    else
        -- Outside gameplay, show all nametags (except own)
        billboard.Enabled = (player ~= LocalPlayer)
    end
end

--[[
    Check if a player has stealth active
]]
function NameTagController:_isPlayerStealthed(player: Player): boolean
    local success, BatteryController = pcall(function()
        return Knit.GetController("BatteryController")
    end)
    if success and BatteryController then
        return BatteryController:IsPlayerStealthed(player)
    end
    return false
end

--[[
    Update all custom nametags (for progression updates)
]]
function NameTagController:_updateAllCustomNameTags()
    for _, player in Players:GetPlayers() do
        self:_createCustomNameTag(player)
    end
end

return NameTagController
