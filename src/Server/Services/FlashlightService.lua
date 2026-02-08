--!strict
--[[
    FlashlightService.lua
    Server-authoritative flashlight detection
    Checks if runners are in seeker flashlight cones and freezes them

    Flashlight state is determined by Tool equip:
    - Tool in character (equipped) = flashlight ON
    - Tool in backpack (unequipped) = flashlight OFF
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))
local ConeDetection = require(Shared:WaitForChild("Utils"):WaitForChild("ConeDetection"))
local FlashlightTypes = require(Shared:WaitForChild("FlashlightTypes"))
local ItemConfig = require(Shared:WaitForChild("ItemConfig"))

local FlashlightService = Knit.CreateService({
    Name = "FlashlightService",

    Client = {
        FlashlightToggled = Knit.CreateSignal(),
        FlashlightUpdated = Knit.CreateSignal(),
    },

    _detectionLoop = nil :: thread?,
    _equippedStates = {} :: { [Player]: boolean }, -- Track for notifying other clients
})

function FlashlightService:KnitInit()
    self._equippedStates = {}

    -- Load flashlight models into ReplicatedStorage for clients to clone
    self:_loadFlashlightModels()

    print("[FlashlightService] Initialized")
end

--[[
    Load flashlight models into ReplicatedStorage
    First checks if models are already manually placed in ReplicatedStorage/FlashlightModels
    If not, attempts to load from Creator Store (requires asset to be trusted)
]]
function FlashlightService:_loadFlashlightModels()
    -- Create or find the models folder
    -- First, wait briefly for Rojo/assets to sync
    local modelsFolder = ReplicatedStorage:FindFirstChild("FlashlightModels")
    if not modelsFolder then
        -- Wait a moment for Rojo sync, then check again
        modelsFolder = ReplicatedStorage:WaitForChild("FlashlightModels", 2)
    end
    if not modelsFolder then
        modelsFolder = Instance.new("Folder")
        modelsFolder.Name = "FlashlightModels"
        modelsFolder.Parent = ReplicatedStorage
        print("[FlashlightService] Created FlashlightModels folder")
    end

    -- Debug: print what's in the folder
    print("[FlashlightService] FlashlightModels folder contents:")
    for _, child in modelsFolder:GetChildren() do
        print(string.format("  - %s (%s)", child.Name, child.ClassName))
    end

    -- Load each flashlight type's model
    for _, config in FlashlightTypes.getAll() do
        -- Skip if model already exists (manually placed in Studio)
        local existingModel = modelsFolder:FindFirstChild(config.name)
        if existingModel then
            print(string.format("[FlashlightService] Model '%s' already exists in FlashlightModels (class: %s)", config.name, existingModel.ClassName))
            self:_configureModelParts(existingModel)
            continue
        end

        if config.modelAssetId and config.modelAssetId > 0 then
            print(string.format("[FlashlightService] Loading model for %s (asset %d)", config.name, config.modelAssetId))

            local success, result = pcall(function()
                return InsertService:LoadAsset(config.modelAssetId)
            end)

            if success and result then
                -- Find the model inside the asset container
                local model = result:FindFirstChildOfClass("Model")
                    or result:FindFirstChildWhichIsA("Tool")
                    or result:FindFirstChild("Flashlight")

                if model then
                    -- If it's a Tool, extract the parts into a Model
                    if model:IsA("Tool") then
                        local toolModel = Instance.new("Model")
                        toolModel.Name = config.name

                        -- Move all parts from tool to new model
                        for _, child in model:GetChildren() do
                            if child:IsA("BasePart") or child:IsA("Model") or child:IsA("Folder") then
                                child.Parent = toolModel
                            end
                        end

                        -- Find handle for primary part
                        local handle = toolModel:FindFirstChild("Handle") or toolModel:FindFirstChildWhichIsA("BasePart")
                        if handle then
                            toolModel.PrimaryPart = handle :: BasePart
                        end

                        model:Destroy()
                        model = toolModel
                    else
                        model.Name = config.name
                        model.Parent = nil
                    end

                    self:_configureModelParts(model)
                    model.Parent = modelsFolder
                    print(string.format("[FlashlightService] Loaded model: %s", config.name))
                else
                    warn(string.format("[FlashlightService] No model found in asset %d", config.modelAssetId))
                end

                result:Destroy()
            else
                warn(string.format("[FlashlightService] Failed to load asset %d: %s", config.modelAssetId, tostring(result)))
                -- Create fallback model programmatically
                local fallbackModel = self:_createFallbackModel(config.name)
                if fallbackModel then
                    fallbackModel.Parent = modelsFolder
                    print(string.format("[FlashlightService] Created fallback model: %s", config.name))
                end
            end
        else
            -- No asset ID configured, create fallback model
            local fallbackModel = self:_createFallbackModel(config.name)
            if fallbackModel then
                fallbackModel.Parent = modelsFolder
                print(string.format("[FlashlightService] Created fallback model (no asset): %s", config.name))
            end
        end
    end
end

--[[
    Create a fallback flashlight model programmatically
    Used when InsertService fails or no asset is configured
]]
function FlashlightService:_createFallbackModel(name: string): Model?
    local model = Instance.new("Model")
    model.Name = name

    -- Create the handle (main body) - cylinder shape
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.4, 1.2, 0.4)
    handle.Shape = Enum.PartType.Cylinder
    handle.Color = Constants.FLASHLIGHT_BODY_COLOR
    handle.Material = Enum.Material.Metal
    handle.CanCollide = false
    handle.Massless = true
    handle.Anchored = false
    -- Rotate so cylinder is along grip axis (Y becomes the length)
    handle.CFrame = CFrame.Angles(0, 0, math.rad(90))
    handle.Parent = model

    -- Create the light head (front of flashlight)
    local lightHead = Instance.new("Part")
    lightHead.Name = "LightHead"
    lightHead.Size = Vector3.new(0.5, 0.3, 0.5)
    lightHead.Shape = Enum.PartType.Cylinder
    lightHead.Color = Constants.FLASHLIGHT_HEAD_COLOR
    lightHead.Material = Enum.Material.Metal
    lightHead.CanCollide = false
    lightHead.Massless = true
    lightHead.Anchored = false
    lightHead.Parent = model

    -- Weld light head to handle
    local headWeld = Instance.new("Weld")
    headWeld.Name = "HeadWeld"
    headWeld.Part0 = handle
    headWeld.Part1 = lightHead
    -- Position at front of handle
    headWeld.C0 = CFrame.new(0.6, 0, 0)
    headWeld.Parent = lightHead

    -- Create the lens (emits light)
    local lens = Instance.new("Part")
    lens.Name = "Lens"
    lens.Size = Vector3.new(0.4, 0.05, 0.4)
    lens.Shape = Enum.PartType.Cylinder
    lens.Color = Constants.FLASHLIGHT_LENS_COLOR
    lens.Material = Enum.Material.Neon
    lens.CanCollide = false
    lens.Massless = true
    lens.Anchored = false
    lens.Transparency = 0.3
    lens.Parent = model

    -- Weld lens to light head
    local lensWeld = Instance.new("Weld")
    lensWeld.Name = "LensWeld"
    lensWeld.Part0 = lightHead
    lensWeld.Part1 = lens
    -- Position at front of light head
    lensWeld.C0 = CFrame.new(0.15, 0, 0)
    lensWeld.Parent = lens

    -- Create the spotlight (attached to lens, facing forward)
    local spotlight = Instance.new("SpotLight")
    spotlight.Name = "SpotLight"
    spotlight.Brightness = Constants.FLASHLIGHT_BRIGHTNESS
    spotlight.Color = Constants.FLASHLIGHT_COLOR
    spotlight.Range = Constants.FLASHLIGHT_RANGE
    spotlight.Angle = Constants.FLASHLIGHT_ANGLE
    spotlight.Face = Enum.NormalId.Right  -- Right because cylinder is rotated
    spotlight.Shadows = true
    spotlight.Enabled = false
    spotlight.Parent = lens

    model.PrimaryPart = handle

    return model
end

--[[
    Configure model parts for use as handheld flashlight
    Minimal configuration - just ensure parts don't collide
    Keeps scripts and other elements intact to leverage Tool functionality
]]
function FlashlightService:_configureModelParts(model: Instance)
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.CanCollide = false
            descendant.Massless = true
        end
    end
end

function FlashlightService:KnitStart()
    -- Clean up on player leave
    Players.PlayerRemoving:Connect(function(player)
        self._equippedStates[player] = nil
    end)

    -- Subscribe to game state changes
    local GameStateService = Knit.GetService("GameStateService")
    GameStateService:OnStateChanged(function(newState)
        if newState == Enums.GameState.GAMEPLAY then
            self:_startDetectionLoop()
        else
            self:_stopDetectionLoop()
            -- Remove all flashlights when leaving gameplay
            self:_removeAllFlashlights()
        end
    end)

    -- Listen for team assignments to give flashlights to seekers
    local TeamService = Knit.GetService("TeamService")
    TeamService:OnPlayerTeamChanged(function(player, role)
        if role == Enums.PlayerRole.Seeker then
            self:_giveFlashlightToPlayer(player)
        else
            self:_removeFlashlightFromPlayer(player)
        end
    end)

    print("[FlashlightService] Started")
end

--[[
    Give a flashlight tool to a player (server-side for replication)
]]
function FlashlightService:_giveFlashlightToPlayer(player: Player)
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then
        warn("[FlashlightService] Player has no Backpack")
        return
    end

    -- Check if they already have a flashlight
    if backpack:FindFirstChild("Flashlight") then
        print("[FlashlightService] Player already has flashlight")
        return
    end

    local character = player.Character
    if character and character:FindFirstChild("Flashlight") then
        print("[FlashlightService] Player already has flashlight equipped")
        return
    end

    -- Clone the flashlight tool from ReplicatedStorage
    local modelsFolder = ReplicatedStorage:FindFirstChild("FlashlightModels")
    if not modelsFolder then
        warn("[FlashlightService] FlashlightModels folder not found")
        return
    end

    local config = FlashlightTypes.getDefault()
    local template = modelsFolder:FindFirstChild(config.name)
    if not template then
        warn("[FlashlightService] Flashlight template not found")
        return
    end

    local tool = template:Clone()
    tool.Name = "Flashlight"

    -- Remove scripts that might interfere with our equip-based light control
    -- Also configure parts
    local toDestroy = {}
    for _, desc in tool:GetDescendants() do
        if desc:IsA("BasePart") then
            desc.CanCollide = false
            desc.Massless = true
        elseif desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
            table.insert(toDestroy, desc)
        elseif desc:IsA("ClickDetector") or desc:IsA("ProximityPrompt") then
            table.insert(toDestroy, desc)
        elseif desc:IsA("SpotLight") then
            desc.Enabled = false
        end
    end

    for _, item in toDestroy do
        item:Destroy()
    end

    tool.Parent = backpack

    print(string.format("[FlashlightService] Gave flashlight to %s", player.Name))
end

--[[
    Remove flashlight from a player
]]
function FlashlightService:_removeFlashlightFromPlayer(player: Player)
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local tool = backpack:FindFirstChild("Flashlight")
        if tool then
            tool:Destroy()
        end
    end

    local character = player.Character
    if character then
        local tool = character:FindFirstChild("Flashlight")
        if tool then
            tool:Destroy()
        end
    end
end

--[[
    Remove all flashlights from all players
]]
function FlashlightService:_removeAllFlashlights()
    for _, player in Players:GetPlayers() do
        self:_removeFlashlightFromPlayer(player)
    end
end

--[[
    Check if a player has their flashlight tool equipped (in character, not backpack)
]]
function FlashlightService:_isFlashlightEquipped(player: Player): boolean
    local character = player.Character
    if not character then
        return false
    end

    -- Look for a tool named "Flashlight" in the character
    local tool = character:FindFirstChild("Flashlight")
    return tool ~= nil and tool:IsA("Tool")
end

--[[
    Get the flashlight direction from character facing
]]
function FlashlightService:_getFlashlightDirection(character: Model): Vector3?
    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if rootPart then
        return rootPart.CFrame.LookVector
    end
    return nil
end

--[[
    Check if a player's flashlight is enabled (equipped)
]]
function FlashlightService:IsFlashlightEnabled(player: Player): boolean
    return self:_isFlashlightEquipped(player)
end

--[[
    Start the detection loop during gameplay
]]
function FlashlightService:_startDetectionLoop()
    if self._detectionLoop then
        return
    end

    print("[FlashlightService] Starting detection loop")

    self._detectionLoop = task.spawn(function()
        while true do
            self:_processFlashlightDetection()
            self:_updateEquippedStates()
            task.wait(Constants.FLASHLIGHT_CHECK_RATE)
        end
    end)
end

--[[
    Stop the detection loop
]]
function FlashlightService:_stopDetectionLoop()
    if self._detectionLoop then
        task.cancel(self._detectionLoop)
        self._detectionLoop = nil
        print("[FlashlightService] Detection loop stopped")
    end

    -- Notify all clients that flashlights are off
    for player, wasEquipped in self._equippedStates do
        if wasEquipped then
            self.Client.FlashlightToggled:FireAll(player, false)
        end
    end
    self._equippedStates = {}
end

--[[
    Update equipped states, control spotlight, and notify clients of changes
    This allows other players to see when someone equips/unequips their flashlight
]]
function FlashlightService:_updateEquippedStates()
    local TeamService = Knit.GetService("TeamService")
    local seekers = TeamService:GetSeekers()

    for _, seeker in seekers do
        local isEquipped = self:_isFlashlightEquipped(seeker)
        local wasEquipped = self._equippedStates[seeker] or false

        if isEquipped ~= wasEquipped then
            self._equippedStates[seeker] = isEquipped

            -- Control the spotlight from server (replicates to all clients)
            self:_setSpotlightEnabled(seeker, isEquipped)

            -- Notify all clients of state change
            self.Client.FlashlightToggled:FireAll(seeker, isEquipped)
            print(string.format("[FlashlightService] %s flashlight: %s",
                seeker.Name, isEquipped and "ON" or "OFF"))
        end
    end
end

--[[
    Set the spotlight enabled state on a player's flashlight (server-side)
]]
function FlashlightService:_setSpotlightEnabled(player: Player, enabled: boolean)
    local character = player.Character
    if not character then
        return
    end

    local tool = character:FindFirstChild("Flashlight")
    if not tool then
        return
    end

    for _, desc in tool:GetDescendants() do
        if desc:IsA("SpotLight") then
            desc.Enabled = enabled
            break
        end
    end
end

--[[
    Get flashlight properties for a player based on their equipped flashlight type
    @param player - The player
    @return range, angle - The flashlight range and angle
]]
function FlashlightService:_getFlashlightProperties(player: Player): (number, number)
    local InventoryService = Knit.GetService("InventoryService")
    local inventory = InventoryService:GetInventory(player)

    if inventory then
        local flashlightConfig = ItemConfig.getFlashlight(inventory.equippedFlashlight)
        if flashlightConfig then
            return flashlightConfig.range, flashlightConfig.angle
        end
    end

    -- Default values
    return Constants.FLASHLIGHT_RANGE, Constants.FLASHLIGHT_ANGLE
end

--[[
    Process flashlight cone detection for all seekers with equipped flashlights
]]
function FlashlightService:_processFlashlightDetection()
    local RoundService = Knit.GetService("RoundService")
    if not RoundService:IsRoundActive() then
        return
    end

    local TeamService = Knit.GetService("TeamService")
    local PlayerStateService = Knit.GetService("PlayerStateService")

    local seekers = TeamService:GetSeekers()
    local runners = TeamService:GetRunners()

    -- Check each seeker's flashlight
    for _, seeker in seekers do
        -- Check if flashlight is equipped (tool in character)
        if not self:_isFlashlightEquipped(seeker) then
            continue
        end

        local seekerCharacter = seeker.Character
        if not seekerCharacter then
            continue
        end

        -- Get flashlight origin and direction from character
        local origin = self:_getFlashlightOrigin(seekerCharacter)
        local direction = self:_getFlashlightDirection(seekerCharacter)
        if not origin or not direction then
            continue
        end

        -- Get flashlight properties based on equipped type
        local flashlightRange, flashlightAngle = self:_getFlashlightProperties(seeker)

        -- Build ignore list for raycasts
        local ignoreList = { seekerCharacter }

        -- Check each runner
        for _, runner in runners do
            -- Skip already frozen runners
            if PlayerStateService:IsFrozen(runner) then
                continue
            end

            local runnerCharacter = runner.Character
            if not runnerCharacter then
                continue
            end

            -- Get target position (adjusted for crouching)
            local targetPos = ConeDetection.GetCharacterTargetPosition(runnerCharacter)
            if not targetPos then
                continue
            end

            -- Lower detection point if runner is crouching
            local CrouchService = Knit.GetService("CrouchService")
            local crouchOffset = CrouchService:GetDetectionHeightOffset(runner)
            targetPos = targetPos + Vector3.new(0, crouchOffset, 0)

            -- Add runner to ignore list for LOS check
            local fullIgnoreList = table.clone(ignoreList)
            table.insert(fullIgnoreList, runnerCharacter)

            -- Check if runner is in flashlight cone with line of sight
            -- Use player-specific flashlight range and angle
            local inCone = ConeDetection.IsTargetInConeWithLOS(
                origin,
                direction,
                targetPos,
                flashlightRange,
                flashlightAngle,
                fullIgnoreList
            )

            if inCone then
                -- Freeze the runner!
                PlayerStateService:FreezePlayer(runner, seeker)
            end
        end
    end
end

--[[
    Get the flashlight origin point from a character
    Uses hand position to match where the flashlight model is held
]]
function FlashlightService:_getFlashlightOrigin(character: Model): Vector3?
    -- Try R15 right hand first (where flashlight is actually held)
    local rightHand = character:FindFirstChild("RightHand") :: BasePart?
    if rightHand then
        -- Offset forward from hand to approximate flashlight lens position
        return rightHand.Position + rightHand.CFrame.LookVector * 0.5
    end

    -- Try R6 right arm
    local rightArm = character:FindFirstChild("Right Arm") :: BasePart?
    if rightArm then
        -- Offset forward and down from arm to approximate hand position
        return rightArm.Position + rightArm.CFrame.LookVector * 0.5 - Vector3.new(0, 0.5, 0)
    end

    -- Final fallback: approximate hand position from HumanoidRootPart
    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if rootPart then
        -- Approximate right hand position: to the right, slightly forward, slightly down
        local rightOffset = rootPart.CFrame.RightVector * 1.5
        local forwardOffset = rootPart.CFrame.LookVector * 0.5
        local downOffset = Vector3.new(0, -0.5, 0)
        return rootPart.Position + rightOffset + forwardOffset + downOffset
    end

    return nil
end

-- Client methods
function FlashlightService.Client:IsFlashlightEnabled(player: Player): boolean
    return self.Server:IsFlashlightEnabled(player)
end

return FlashlightService
