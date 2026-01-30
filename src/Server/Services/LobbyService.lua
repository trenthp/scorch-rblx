--!strict
--[[
    LobbyService.lua
    Manages the lobby platform above the play area
    - Handles player visibility (hidden during gameplay)
    - Teleports players between lobby and play area
    - Manages lobby spawns
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

-- Color palette - Night outdoors theme
local SignColors = {
    -- Backgrounds
    bgDark = Color3.fromRGB(18, 22, 28),
    bgMid = Color3.fromRGB(28, 34, 42),

    -- Text
    textPrimary = Color3.fromRGB(240, 235, 220),
    textSecondary = Color3.fromRGB(160, 155, 145),
    textMuted = Color3.fromRGB(100, 98, 92),

    -- Accents
    warmGlow = Color3.fromRGB(255, 180, 100),
    ember = Color3.fromRGB(255, 120, 60),
    forestGreen = Color3.fromRGB(76, 135, 102),
    warmBrown = Color3.fromRGB(180, 120, 80),
    moonlight = Color3.fromRGB(200, 210, 230),
}

local LobbyService = Knit.CreateService({
    Name = "LobbyService",

    Client = {
        StartTransition = Knit.CreateSignal(), -- Tell client to start fade
        TransitionComplete = Knit.CreateSignal(), -- Tell client fade is done, can fade in
    },

    _lobbyModel = nil :: Model?,
    _lobbySpawn = nil :: SpawnLocation?,
    _statusLabel = nil :: TextLabel?,
    _timerLabel = nil :: TextLabel?,
})

function LobbyService:KnitInit()
    -- Find or wait for lobby
    self._lobbyModel = Workspace:WaitForChild("Lobby", 5) :: Model?
    if self._lobbyModel then
        self._lobbySpawn = self._lobbyModel:FindFirstChild("LobbySpawn") :: SpawnLocation?
        print("[LobbyService] Found lobby structure")
    else
        warn("[LobbyService] Lobby structure not found, creating fallback")
        self:_createFallbackLobby()
    end

    -- Create lobby signs
    self:_createLobbySigns()

    print("[LobbyService] Initialized")
end

function LobbyService:KnitStart()
    local GameStateService = Knit.GetService("GameStateService")

    -- Handle state changes
    GameStateService:OnStateChanged(function(newState, oldState)
        self:_onStateChanged(newState, oldState)
    end)

    -- Handle new players
    Players.PlayerAdded:Connect(function(player)
        self:_setupCharacterHandler(player)
    end)

    -- Handle existing players
    for _, player in Players:GetPlayers() do
        self:_setupCharacterHandler(player)
    end

    print("[LobbyService] Started")
end

--[[
    Setup character spawn handling for a player
    Ensures players always spawn in the correct location based on game state
]]
function LobbyService:_setupCharacterHandler(player: Player)
    local GameStateService = Knit.GetService("GameStateService")
    local TeamService = Knit.GetService("TeamService")
    local MapService = Knit.GetService("MapService")

    player.CharacterAdded:Connect(function(character)
        local currentState = GameStateService:GetState()
        local role = TeamService:GetPlayerRole(player)

        task.defer(function()
            if currentState == Enums.GameState.GAMEPLAY then
                -- During gameplay, check if player has a role (was assigned before gameplay)
                if role == Enums.PlayerRole.Seeker then
                    -- Seeker respawning during gameplay - spawn at seeker spawn
                    MapService:SpawnPlayerAtSeeker(player)
                elseif role == Enums.PlayerRole.Runner then
                    -- Runner respawning during gameplay - spawn at runner spawn
                    MapService:SpawnPlayerAtRunner(player)
                else
                    -- Spectator or late joiner - send to lobby and hide
                    self:TeleportToLobby(player)
                    self:_setPlayerVisible(player, false)
                    print(string.format("[LobbyService] Late joiner %s sent to lobby as spectator", player.Name))
                end
            elseif currentState == Enums.GameState.TEAM_SELECTION then
                -- Team selection in progress - send to lobby (they missed the cutoff)
                self:TeleportToLobby(player)
                print(string.format("[LobbyService] Player %s joined during team selection, sent to lobby", player.Name))
            else
                -- LOBBY or RESULTS - send to lobby
                self:TeleportToLobby(player)
            end
        end)
    end)
end

--[[
    Create fallback lobby if not found in workspace
]]
function LobbyService:_createFallbackLobby()
    local lobby = Instance.new("Model")
    lobby.Name = "Lobby"

    -- Floor
    local floor = Instance.new("Part")
    floor.Name = "Floor"
    floor.Size = Vector3.new(Constants.LOBBY.PLATFORM_SIZE, 2, Constants.LOBBY.PLATFORM_SIZE)
    floor.Position = Vector3.new(0, Constants.LOBBY.HEIGHT, 0)
    floor.Anchored = true
    floor.Transparency = 0.5
    floor.BrickColor = BrickColor.new("Institutional white")
    floor.Material = Enum.Material.Glass
    floor.Parent = lobby

    -- Spawn
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "LobbySpawn"
    spawn.Size = Vector3.new(6, 1, 6)
    spawn.Position = Vector3.new(0, Constants.LOBBY.HEIGHT + 1.5, 0)
    spawn.Anchored = true
    spawn.Transparency = 1
    spawn.Enabled = true
    spawn.Neutral = true
    spawn.Parent = lobby

    -- Walls
    local wallHeight = Constants.LOBBY.WALL_HEIGHT
    local halfSize = Constants.LOBBY.PLATFORM_SIZE / 2 - 1
    local wallY = Constants.LOBBY.HEIGHT + wallHeight / 2 + 1

    local wallPositions = {
        { name = "WallNorth", size = Vector3.new(Constants.LOBBY.PLATFORM_SIZE, wallHeight, 2), pos = Vector3.new(0, wallY, -halfSize) },
        { name = "WallSouth", size = Vector3.new(Constants.LOBBY.PLATFORM_SIZE, wallHeight, 2), pos = Vector3.new(0, wallY, halfSize) },
        { name = "WallEast", size = Vector3.new(2, wallHeight, Constants.LOBBY.PLATFORM_SIZE), pos = Vector3.new(halfSize, wallY, 0) },
        { name = "WallWest", size = Vector3.new(2, wallHeight, Constants.LOBBY.PLATFORM_SIZE), pos = Vector3.new(-halfSize, wallY, 0) },
    }

    for _, wallData in wallPositions do
        local wall = Instance.new("Part")
        wall.Name = wallData.name
        wall.Size = wallData.size
        wall.Position = wallData.pos
        wall.Anchored = true
        wall.Transparency = 1
        wall.CanCollide = true
        wall.Parent = lobby
    end

    -- Signs folder
    local signs = Instance.new("Folder")
    signs.Name = "Signs"
    signs.Parent = lobby

    lobby.Parent = Workspace

    self._lobbyModel = lobby
    self._lobbySpawn = spawn

    print("[LobbyService] Created fallback lobby")
end

--[[
    Create lobby signs with branding and instructions
]]
function LobbyService:_createLobbySigns()
    if not self._lobbyModel then
        return
    end

    local signsFolder = self._lobbyModel:FindFirstChild("Signs")
    if not signsFolder then
        signsFolder = Instance.new("Folder")
        signsFolder.Name = "Signs"
        signsFolder.Parent = self._lobbyModel
    end

    -- Clear existing signs
    for _, child in signsFolder:GetChildren() do
        child:Destroy()
    end

    local lobbyHeight = Constants.LOBBY.HEIGHT

    -- Sign configurations - Minimal outdoorsy aesthetic
    -- Signs are positioned on walls and face INWARD toward lobby center
    local signs = {
        {
            name = "WelcomeSign",
            position = Vector3.new(0, lobbyHeight + 10, -35),
            size = Vector3.new(32, 14, 0.8),
            title = "SCORCH",
            subtitle = "Hide  ·  Seek  ·  Survive",
            titleSize = 140,
            subtitleSize = 48,
            style = "hero",
        },
        {
            name = "RunnerSign",
            position = Vector3.new(-35, lobbyHeight + 9, 0),
            size = Vector3.new(24, 14, 0.8),
            title = "Runners",
            instructions = {
                "Find cover in the bushes",
                "Crouch to stay hidden",
                "Rescue frozen teammates",
                "Survive until time runs out",
            },
            accentColor = Color3.fromRGB(76, 135, 102),
            style = "info",
        },
        {
            name = "SeekerSign",
            position = Vector3.new(35, lobbyHeight + 9, 0),
            size = Vector3.new(24, 14, 0.8),
            title = "Seekers",
            instructions = {
                "Equip your flashlight",
                "Shine light to freeze runners",
                "Freeze everyone to win",
                "Watch for movement",
            },
            accentColor = Color3.fromRGB(180, 90, 60),
            style = "info",
        },
    }

    for _, signData in signs do
        self:_createSign(signsFolder, signData)
    end

    print("[LobbyService] Created lobby signs")

    -- Create status display
    self:_createStatusDisplay(signsFolder)
end

--[[
    Create the game status/timer display - Clean billboard only
]]
function LobbyService:_createStatusDisplay(parent: Folder)
    local lobbyHeight = Constants.LOBBY.HEIGHT

    -- Invisible anchor part for the billboard
    local anchor = Instance.new("Part")
    anchor.Name = "StatusAnchor"
    anchor.Size = Vector3.new(1, 1, 1)
    anchor.Position = Vector3.new(0, lobbyHeight + 19, 0)
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.Transparency = 1
    anchor.Parent = parent

    -- Billboard GUI - always faces player
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "StatusBillboard"
    billboard.Size = UDim2.fromOffset(380, 120)
    billboard.StudsOffset = Vector3.new(0, 0, 0)
    billboard.AlwaysOnTop = false
    billboard.MaxDistance = 150
    billboard.Parent = anchor

    -- Status text - main
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, 0, 0.55, 0)
    statusLabel.Position = UDim2.new(0, 0, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 36
    statusLabel.TextColor3 = SignColors.warmGlow
    statusLabel.Text = "Waiting for Players"
    statusLabel.Parent = billboard

    -- Timer/subtext
    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name = "Timer"
    timerLabel.Size = UDim2.new(1, 0, 0.4, 0)
    timerLabel.Position = UDim2.new(0, 0, 0.55, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Font = Enum.Font.Gotham
    timerLabel.TextSize = 22
    timerLabel.TextColor3 = SignColors.textSecondary
    timerLabel.Text = "2 players needed to start"
    timerLabel.Parent = billboard

    -- Store references
    self._statusLabel = statusLabel
    self._timerLabel = timerLabel

    print("[LobbyService] Created status display")
end

--[[
    Update the status display text and styling based on state
]]
function LobbyService:UpdateStatus(status: string, timer: string?)
    if self._statusLabel then
        self._statusLabel.Text = status

        -- Subtle color shifts based on state (case-insensitive)
        local lowerStatus = string.lower(status)
        if string.find(lowerStatus, "waiting") then
            self._statusLabel.TextColor3 = SignColors.warmGlow
        elseif string.find(lowerStatus, "selecting") then
            self._statusLabel.TextColor3 = Color3.fromRGB(220, 200, 140)
        elseif string.find(lowerStatus, "progress") then
            self._statusLabel.TextColor3 = SignColors.ember
        elseif string.find(lowerStatus, "complete") then
            self._statusLabel.TextColor3 = SignColors.moonlight
        end
    end

    if self._timerLabel then
        self._timerLabel.Text = timer or ""
    end
end

--[[
    Create a single sign - Minimal outdoors/night aesthetic
]]
function LobbyService:_createSign(parent: Folder, data: {
    name: string,
    position: Vector3,
    size: Vector3,
    title: string,
    subtitle: string?,
    titleSize: number?,
    subtitleSize: number?,
    accentColor: Color3?,
    style: string?,
    instructions: {string}?,
    controls: {{key: string, action: string}}?,
})
    local style = data.style or "info"

    -- Create sign backing - dark wood/slate feel
    local sign = Instance.new("Part")
    sign.Name = data.name
    sign.Size = data.size

    local lobbyCenter = Vector3.new(0, data.position.Y, 0)
    sign.CFrame = CFrame.lookAt(data.position, lobbyCenter)

    sign.Anchored = true
    sign.CanCollide = false
    sign.Material = Enum.Material.Wood
    sign.Color = Color3.fromRGB(35, 30, 28)
    sign.Parent = parent

    -- Subtle frame border
    self:_createWoodFrame(sign, data.size)

    -- Create SurfaceGui
    local gui = Instance.new("SurfaceGui")
    gui.Name = "SignGui"
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 50
    gui.Parent = sign

    local pixelWidth = data.size.X * 50
    local pixelHeight = data.size.Y * 50

    -- Background
    local bgFrame = Instance.new("Frame")
    bgFrame.Name = "Background"
    bgFrame.Size = UDim2.fromScale(1, 1)
    bgFrame.BackgroundColor3 = SignColors.bgDark
    bgFrame.BorderSizePixel = 0
    bgFrame.Parent = gui

    -- Subtle vignette gradient
    local vignette = Instance.new("UIGradient")
    vignette.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 26, 32)),
        ColorSequenceKeypoint.new(0.3, Color3.fromRGB(18, 22, 28)),
        ColorSequenceKeypoint.new(0.7, Color3.fromRGB(18, 22, 28)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 18, 22)),
    })
    vignette.Rotation = 90
    vignette.Parent = bgFrame

    if style == "hero" then
        self:_createHeroSign(bgFrame, data, pixelWidth, pixelHeight)
    elseif style == "controls" then
        self:_createControlsSign(bgFrame, data, pixelWidth, pixelHeight)
    else
        self:_createInfoSign(bgFrame, data, pixelWidth, pixelHeight)
    end
end

--[[
    Hero sign - Main SCORCH branding
]]
function LobbyService:_createHeroSign(parent: Frame, data: any, width: number, height: number)
    -- Main title - large, warm typography
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, 0, 0, 220)
    titleLabel.Position = UDim2.new(0, 0, 0, height * 0.12)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBlack
    titleLabel.TextSize = data.titleSize or 140
    titleLabel.TextColor3 = SignColors.warmGlow
    titleLabel.Text = data.title
    titleLabel.Parent = parent

    -- Warm gradient on title
    local titleGradient = Instance.new("UIGradient")
    titleGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 120)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 160, 80)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 130, 60)),
    })
    titleGradient.Rotation = 90
    titleGradient.Parent = titleLabel

    -- Minimal divider line
    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.Size = UDim2.new(0.3, 0, 0, 3)
    divider.Position = UDim2.new(0.35, 0, 0, height * 0.52)
    divider.BackgroundColor3 = SignColors.warmBrown
    divider.BackgroundTransparency = 0.3
    divider.BorderSizePixel = 0
    divider.Parent = parent

    -- Tagline - spaced, light weight
    local subtitleLabel = Instance.new("TextLabel")
    subtitleLabel.Name = "Subtitle"
    subtitleLabel.Size = UDim2.new(1, 0, 0, 60)
    subtitleLabel.Position = UDim2.new(0, 0, 0, height * 0.6)
    subtitleLabel.BackgroundTransparency = 1
    subtitleLabel.Font = Enum.Font.Gotham
    subtitleLabel.TextSize = data.subtitleSize or 38
    subtitleLabel.TextColor3 = SignColors.textSecondary
    subtitleLabel.Text = data.subtitle or ""
    subtitleLabel.RichText = true
    subtitleLabel.Parent = parent

    -- Add subtle ambient glow behind sign
    self:_addAmbientGlow(parent:FindFirstAncestorOfClass("Part"), SignColors.ember, 0.3)
end

--[[
    Info sign - Runner/Seeker instructions
]]
function LobbyService:_createInfoSign(parent: Frame, data: any, width: number, height: number)
    local accentColor = data.accentColor or SignColors.forestGreen

    -- Title with accent underline
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, 0, 0, 90)
    titleLabel.Position = UDim2.new(0, 0, 0, 25)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 64
    titleLabel.TextColor3 = SignColors.textPrimary
    titleLabel.Text = data.title
    titleLabel.Parent = parent

    -- Accent underline
    local underline = Instance.new("Frame")
    underline.Name = "Underline"
    underline.Size = UDim2.new(0.25, 0, 0, 4)
    underline.Position = UDim2.new(0.375, 0, 0, 115)
    underline.BackgroundColor3 = accentColor
    underline.BorderSizePixel = 0
    underline.Parent = parent

    -- Instructions list
    local instructions = data.instructions or {}
    local startY = 145
    local lineHeight = 85

    for i, instruction in ipairs(instructions) do
        local yPos = startY + (i - 1) * lineHeight

        -- Bullet point
        local bullet = Instance.new("TextLabel")
        bullet.Name = "Bullet" .. i
        bullet.Size = UDim2.fromOffset(50, 50)
        bullet.Position = UDim2.new(0, 45, 0, yPos + 8)
        bullet.BackgroundTransparency = 1
        bullet.Font = Enum.Font.Gotham
        bullet.TextSize = 36
        bullet.TextColor3 = accentColor
        bullet.Text = "—"
        bullet.Parent = parent

        -- Instruction text
        local instructionLabel = Instance.new("TextLabel")
        instructionLabel.Name = "Instruction" .. i
        instructionLabel.Size = UDim2.new(0.85, 0, 0, 60)
        instructionLabel.Position = UDim2.new(0, 100, 0, yPos)
        instructionLabel.BackgroundTransparency = 1
        instructionLabel.Font = Enum.Font.Gotham
        instructionLabel.TextSize = 44
        instructionLabel.TextColor3 = SignColors.textSecondary
        instructionLabel.TextXAlignment = Enum.TextXAlignment.Left
        instructionLabel.Text = instruction
        instructionLabel.Parent = parent
    end

    -- Subtle accent glow
    self:_addAmbientGlow(parent:FindFirstAncestorOfClass("Part"), accentColor, 0.15)
end

--[[
    Controls sign - Keyboard shortcuts
]]
function LobbyService:_createControlsSign(parent: Frame, data: any, width: number, height: number)
    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, 0, 0, 80)
    titleLabel.Position = UDim2.new(0, 0, 0, 25)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 56
    titleLabel.TextColor3 = SignColors.textPrimary
    titleLabel.Text = data.title
    titleLabel.Parent = parent

    -- Underline
    local underline = Instance.new("Frame")
    underline.Name = "Underline"
    underline.Size = UDim2.new(0.22, 0, 0, 3)
    underline.Position = UDim2.new(0.39, 0, 0, 105)
    underline.BackgroundColor3 = SignColors.warmBrown
    underline.BackgroundTransparency = 0.4
    underline.BorderSizePixel = 0
    underline.Parent = parent

    -- Control entries
    local controls = data.controls or {}
    local startY = 140
    local spacing = 130

    for i, control in ipairs(controls) do
        local yPos = startY + (i - 1) * spacing
        self:_createControlEntry(parent, control, yPos)
    end
end

--[[
    Single control entry - minimal key + action
]]
function LobbyService:_createControlEntry(parent: Frame, control: {key: string, action: string}, yPos: number)
    -- Key box - subtle, rounded
    local keyBox = Instance.new("Frame")
    keyBox.Name = "KeyBox_" .. control.key
    keyBox.Size = UDim2.fromOffset(80, 72)
    keyBox.Position = UDim2.new(0.5, -160, 0, yPos)
    keyBox.BackgroundColor3 = SignColors.bgMid
    keyBox.BorderSizePixel = 0
    keyBox.Parent = parent

    local keyCorner = Instance.new("UICorner")
    keyCorner.CornerRadius = UDim.new(0, 10)
    keyCorner.Parent = keyBox

    local keyStroke = Instance.new("UIStroke")
    keyStroke.Color = SignColors.textMuted
    keyStroke.Thickness = 2
    keyStroke.Transparency = 0.5
    keyStroke.Parent = keyBox

    -- Key letter
    local keyLabel = Instance.new("TextLabel")
    keyLabel.Name = "Key"
    keyLabel.Size = UDim2.fromScale(1, 1)
    keyLabel.BackgroundTransparency = 1
    keyLabel.Font = Enum.Font.GothamBold
    keyLabel.TextSize = 40
    keyLabel.TextColor3 = SignColors.textPrimary
    keyLabel.Text = control.key
    keyLabel.Parent = keyBox

    -- Action label
    local actionLabel = Instance.new("TextLabel")
    actionLabel.Name = "Action"
    actionLabel.Size = UDim2.fromOffset(200, 72)
    actionLabel.Position = UDim2.new(0.5, -65, 0, yPos)
    actionLabel.BackgroundTransparency = 1
    actionLabel.Font = Enum.Font.Gotham
    actionLabel.TextSize = 36
    actionLabel.TextColor3 = SignColors.textSecondary
    actionLabel.TextXAlignment = Enum.TextXAlignment.Left
    actionLabel.Text = control.action
    actionLabel.Parent = parent
end

--[[
    Create wooden frame border
]]
function LobbyService:_createWoodFrame(sign: Part, size: Vector3)
    local frameThickness = 0.25
    local frameColor = Color3.fromRGB(55, 45, 38)

    local frames = {
        { -- Top
            size = Vector3.new(size.X + frameThickness * 2, frameThickness, size.Z + 0.1),
            offset = Vector3.new(0, size.Y / 2 + frameThickness / 2, 0),
        },
        { -- Bottom
            size = Vector3.new(size.X + frameThickness * 2, frameThickness, size.Z + 0.1),
            offset = Vector3.new(0, -size.Y / 2 - frameThickness / 2, 0),
        },
        { -- Left
            size = Vector3.new(frameThickness, size.Y, size.Z + 0.1),
            offset = Vector3.new(-size.X / 2 - frameThickness / 2, 0, 0),
        },
        { -- Right
            size = Vector3.new(frameThickness, size.Y, size.Z + 0.1),
            offset = Vector3.new(size.X / 2 + frameThickness / 2, 0, 0),
        },
    }

    for i, frameData in ipairs(frames) do
        local frame = Instance.new("Part")
        frame.Name = "Frame" .. i
        frame.Size = frameData.size
        frame.CFrame = sign.CFrame * CFrame.new(frameData.offset)
        frame.Anchored = true
        frame.CanCollide = false
        frame.Material = Enum.Material.Wood
        frame.Color = frameColor
        frame.Parent = sign
    end
end

--[[
    Add subtle ambient glow to sign
]]
function LobbyService:_addAmbientGlow(sign: Part, color: Color3, brightness: number)
    if not sign then return end

    local light = Instance.new("PointLight")
    light.Name = "AmbientGlow"
    light.Color = color
    light.Brightness = brightness
    light.Range = 8
    light.Shadows = false
    light.Parent = sign
end

--[[
    Handle game state changes
]]
function LobbyService:_onStateChanged(newState: string, oldState: string)
    if newState == Enums.GameState.GAMEPLAY then
        -- Transition players from lobby to play area
        self:_transitionToGameplay()
        self:UpdateStatus("Round in Progress", "")
    elseif newState == Enums.GameState.LOBBY then
        -- Transition players back to lobby
        if oldState == Enums.GameState.RESULTS then
            self:_transitionToLobby()
        end
        self:UpdateStatus("Waiting for Players", "2 players needed to start")
    elseif newState == Enums.GameState.TEAM_SELECTION then
        self:UpdateStatus("SELECTING TEAMS", "Assigning roles...")
    elseif newState == Enums.GameState.RESULTS then
        -- Make lobby players visible again
        self:_setAllPlayersVisible(true)
        self:UpdateStatus("ROUND COMPLETE", "")
    end
end

--[[
    Transition all players to gameplay (from lobby to spawn points)
]]
function LobbyService:_transitionToGameplay()
    local TeamService = Knit.GetService("TeamService")
    local MapService = Knit.GetService("MapService")

    for _, player in Players:GetPlayers() do
        -- Start fade on client
        self.Client.StartTransition:Fire(player, "out")

        task.delay(Constants.LOBBY.FADE_TIME, function()
            -- Get role and teleport to appropriate spawn
            local role = TeamService:GetPlayerRole(player)

            if role == Enums.PlayerRole.Seeker then
                MapService:SpawnPlayerAtSeeker(player)
            elseif role == Enums.PlayerRole.Runner then
                MapService:SpawnPlayerAtRunner(player)
            end

            -- Hide player from lobby view (they're now in gameplay)
            self:_setPlayerVisible(player, true)

            -- Complete transition
            self.Client.TransitionComplete:Fire(player)
        end)
    end
end

--[[
    Transition all players back to lobby
]]
function LobbyService:_transitionToLobby()
    for _, player in Players:GetPlayers() do
        -- Start fade on client
        self.Client.StartTransition:Fire(player, "out")

        task.delay(Constants.LOBBY.FADE_TIME, function()
            self:TeleportToLobby(player)
            self:_setPlayerVisible(player, true)

            -- Complete transition
            self.Client.TransitionComplete:Fire(player)
        end)
    end
end

--[[
    Teleport a player to the lobby spawn
]]
function LobbyService:TeleportToLobby(player: Player)
    local character = player.Character
    if not character then
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not rootPart then
        return
    end

    local spawnPos = Vector3.new(0, Constants.LOBBY.HEIGHT + 5, 0)

    if self._lobbySpawn then
        spawnPos = self._lobbySpawn.Position + Vector3.new(0, 3, 0)
    end

    rootPart.CFrame = CFrame.new(spawnPos)
end

--[[
    Set a player's character visibility
    Stores original transparency values to restore properly
]]
function LobbyService:_setPlayerVisible(player: Player, visible: boolean)
    local character = player.Character
    if not character then
        return
    end

    -- Parts that should stay invisible (internal parts)
    local alwaysInvisible = {
        ["HumanoidRootPart"] = true,
    }

    for _, part in character:GetDescendants() do
        if part:IsA("BasePart") then
            -- Skip parts that should always be invisible
            if alwaysInvisible[part.Name] then
                continue
            end

            if visible then
                -- Restore original transparency
                local originalTransparency = part:GetAttribute("OriginalTransparency")
                if originalTransparency ~= nil then
                    part.Transparency = originalTransparency
                else
                    part.Transparency = 0
                end
            else
                -- Store original transparency before hiding
                if part:GetAttribute("OriginalTransparency") == nil then
                    part:SetAttribute("OriginalTransparency", part.Transparency)
                end
                part.Transparency = 1
            end
        elseif part:IsA("Decal") then
            if visible then
                local originalTransparency = part:GetAttribute("OriginalTransparency")
                if originalTransparency ~= nil then
                    part.Transparency = originalTransparency
                else
                    part.Transparency = 0
                end
            else
                if part:GetAttribute("OriginalTransparency") == nil then
                    part:SetAttribute("OriginalTransparency", part.Transparency)
                end
                part.Transparency = 1
            end
        end
    end

    -- Handle accessories/hats
    for _, accessory in character:GetChildren() do
        if accessory:IsA("Accessory") then
            local handle = accessory:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                if visible then
                    local originalTransparency = handle:GetAttribute("OriginalTransparency")
                    if originalTransparency ~= nil then
                        handle.Transparency = originalTransparency
                    else
                        handle.Transparency = 0
                    end
                else
                    if handle:GetAttribute("OriginalTransparency") == nil then
                        handle:SetAttribute("OriginalTransparency", handle.Transparency)
                    end
                    handle.Transparency = 1
                end
            end
        end
    end
end

--[[
    Set all players' visibility
]]
function LobbyService:_setAllPlayersVisible(visible: boolean)
    for _, player in Players:GetPlayers() do
        self:_setPlayerVisible(player, visible)
    end
end

--[[
    Hide lobby spectators from ground players during gameplay
    Called by client to hide specific lobby players
]]
function LobbyService:HideLobbySpectators()
    local GameStateService = Knit.GetService("GameStateService")
    if GameStateService:GetState() ~= Enums.GameState.GAMEPLAY then
        return
    end

    -- Find players still in lobby (spectators, late joiners)
    for _, player in Players:GetPlayers() do
        local character = player.Character
        if not character then
            continue
        end

        local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not rootPart then
            continue
        end

        -- If player is above ground level (in lobby), hide them
        if rootPart.Position.Y > 50 then
            self:_setPlayerVisible(player, false)
        end
    end
end

-- ============================================
-- CLIENT METHODS
-- ============================================

function LobbyService.Client:GetLobbyPosition(_player: Player): Vector3
    return Vector3.new(0, Constants.LOBBY.HEIGHT + 5, 0)
end

return LobbyService
