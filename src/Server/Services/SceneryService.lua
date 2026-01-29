--!strict
--[[
    SceneryService.lua
    Procedurally generates forest scenery (trees, rocks, bushes, etc.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

export type SceneryConfig = {
    bounds: { min: Vector3, max: Vector3 },
    density: number,
    seed: number?,
}

local SceneryService = Knit.CreateService({
    Name = "SceneryService",
    Client = {},

    _sceneryFolder = nil :: Folder?,
    _random = nil :: Random?,
    _generated = false,
})

-- Scenery template definitions
local SCENERY_TEMPLATES = {
    -- Trees (various sizes)
    Tree_Large = {
        weight = 15,
        minScale = 0.8,
        maxScale = 1.2,
        groundOffset = 0,
        create = function(random: Random): Model
            return SceneryService:_createTree(random, "large")
        end,
    },
    Tree_Medium = {
        weight = 25,
        minScale = 0.7,
        maxScale = 1.0,
        groundOffset = 0,
        create = function(random: Random): Model
            return SceneryService:_createTree(random, "medium")
        end,
    },
    Tree_Small = {
        weight = 20,
        minScale = 0.5,
        maxScale = 0.8,
        groundOffset = 0,
        create = function(random: Random): Model
            return SceneryService:_createTree(random, "small")
        end,
    },
    -- Rocks
    Rock_Large = {
        weight = 10,
        minScale = 0.8,
        maxScale = 1.5,
        groundOffset = -0.5,
        create = function(random: Random): Model
            return SceneryService:_createRock(random, "large")
        end,
    },
    Rock_Medium = {
        weight = 20,
        minScale = 0.5,
        maxScale = 1.0,
        groundOffset = -0.3,
        create = function(random: Random): Model
            return SceneryService:_createRock(random, "medium")
        end,
    },
    Rock_Small = {
        weight = 25,
        minScale = 0.3,
        maxScale = 0.7,
        groundOffset = -0.2,
        create = function(random: Random): Model
            return SceneryService:_createRock(random, "small")
        end,
    },
    -- Bushes
    Bush = {
        weight = 30,
        minScale = 0.6,
        maxScale = 1.2,
        groundOffset = -0.2,
        create = function(random: Random): Model
            return SceneryService:_createBush(random)
        end,
    },
    -- Fallen logs
    FallenLog = {
        weight = 8,
        minScale = 0.7,
        maxScale = 1.3,
        groundOffset = 0,
        create = function(random: Random): Model
            return SceneryService:_createFallenLog(random)
        end,
    },
    -- Mushroom clusters
    Mushrooms = {
        weight = 15,
        minScale = 0.5,
        maxScale = 1.0,
        groundOffset = 0,
        create = function(random: Random): Model
            return SceneryService:_createMushrooms(random)
        end,
    },
    -- Tall grass patches
    TallGrass = {
        weight = 35,
        minScale = 0.6,
        maxScale = 1.0,
        groundOffset = 0,
        create = function(random: Random): Model
            return SceneryService:_createTallGrass(random)
        end,
    },
    -- Stumps
    Stump = {
        weight = 10,
        minScale = 0.6,
        maxScale = 1.0,
        groundOffset = 0,
        create = function(random: Random): Model
            return SceneryService:_createStump(random)
        end,
    },
}

function SceneryService:KnitInit()
    -- Create or find scenery folder
    self._sceneryFolder = Workspace:FindFirstChild("Scenery") :: Folder?
    if not self._sceneryFolder then
        self._sceneryFolder = Instance.new("Folder")
        self._sceneryFolder.Name = "Scenery"
        self._sceneryFolder.Parent = Workspace
    end

    self._random = Random.new(Constants.SCENERY.SEED or os.time())
    print("[SceneryService] Initialized")
end

function SceneryService:KnitStart()
    -- Generate scenery on start if auto-generate is enabled
    if Constants.SCENERY.AUTO_GENERATE then
        self:GenerateScenery()
    end
    print("[SceneryService] Started")
end

--[[
    Generate all scenery based on configuration
]]
function SceneryService:GenerateScenery(config: SceneryConfig?)
    if self._generated then
        self:ClearScenery()
    end

    local bounds = if config then config.bounds else Constants.SCENERY.BOUNDS
    local density = if config then config.density else Constants.SCENERY.DENSITY

    if config and config.seed then
        self._random = Random.new(config.seed)
    end

    local minPos = bounds.min
    local maxPos = bounds.max
    local areaSize = (maxPos.X - minPos.X) * (maxPos.Z - minPos.Z)
    local objectCount = math.floor(areaSize * density / 100)

    print(string.format("[SceneryService] Generating %d scenery objects...", objectCount))

    -- Calculate total weight for weighted random selection
    local totalWeight = 0
    for _, template in SCENERY_TEMPLATES do
        totalWeight += template.weight
    end

    -- Generate objects
    local placed = 0
    local attempts = 0
    local maxAttempts = objectCount * 3

    while placed < objectCount and attempts < maxAttempts do
        attempts += 1

        -- Pick random position
        local x = self._random:NextNumber(minPos.X, maxPos.X)
        local z = self._random:NextNumber(minPos.Z, maxPos.Z)

        -- Raycast to find ground
        local groundY = self:_findGroundHeight(x, z)
        if groundY then
            -- Check minimum spacing from other scenery
            local position = Vector3.new(x, groundY, z)
            if self:_checkSpacing(position, Constants.SCENERY.MIN_SPACING) then
                -- Weighted random template selection
                local template = self:_selectWeightedTemplate(totalWeight)
                if template then
                    local success = self:_placeSceneryObject(template, position)
                    if success then
                        placed += 1
                    end
                end
            end
        end
    end

    self._generated = true
    print(string.format("[SceneryService] Generated %d scenery objects (%d attempts)", placed, attempts))

    -- Generate hiding bushes separately
    self:_generateHidingBushes(bounds)
end

--[[
    Generate hiding bushes that runners can hide inside
    These are larger, denser bushes that block flashlight line-of-sight
]]
function SceneryService:_generateHidingBushes(bounds: { min: Vector3, max: Vector3 })
    local hidingBushCount = Constants.SCENERY.HIDING_BUSH_COUNT
    local minSpacing = Constants.SCENERY.HIDING_BUSH_MIN_SPACING

    print(string.format("[SceneryService] Generating %d hiding bushes...", hidingBushCount))

    local minPos = bounds.min
    local maxPos = bounds.max

    local placed = 0
    local attempts = 0
    local maxAttempts = hidingBushCount * 5

    while placed < hidingBushCount and attempts < maxAttempts do
        attempts += 1

        local x = self._random:NextNumber(minPos.X, maxPos.X)
        local z = self._random:NextNumber(minPos.Z, maxPos.Z)

        local groundY = self:_findGroundHeight(x, z)
        if groundY then
            local position = Vector3.new(x, groundY, z)

            -- Check spacing from other scenery AND other hiding bushes
            if self:_checkSpacing(position, minSpacing) then
                local bush = self:_createHidingBush(self._random)
                if bush then
                    local scale = self._random:NextNumber(0.9, 1.2)
                    self:_scaleModel(bush, scale)

                    local rotation = self._random:NextNumber(0, math.pi * 2)
                    if bush.PrimaryPart then
                        bush:PivotTo(CFrame.new(position) * CFrame.Angles(0, rotation, 0))
                    end

                    bush.Parent = self._sceneryFolder
                    placed += 1
                end
            end
        end
    end

    print(string.format("[SceneryService] Generated %d hiding bushes (%d attempts)", placed, attempts))
end

--[[
    Clear all generated scenery
]]
function SceneryService:ClearScenery()
    if self._sceneryFolder then
        for _, child in self._sceneryFolder:GetChildren() do
            child:Destroy()
        end
    end
    self._generated = false
    print("[SceneryService] Cleared scenery")
end

--[[
    Regenerate scenery with new seed
]]
function SceneryService:RegenerateScenery(newSeed: number?)
    local seed = newSeed or os.time()
    self._random = Random.new(seed)
    self:GenerateScenery()
end

--[[
    Find the ground height at a given X, Z position via raycast
]]
function SceneryService:_findGroundHeight(x: number, z: number): number?
    local rayOrigin = Vector3.new(x, 500, z)
    local rayDirection = Vector3.new(0, -1000, 0)

    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = { self._sceneryFolder :: Instance }
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude

    local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if result then
        return result.Position.Y
    end
    return nil
end

--[[
    Check if position has enough spacing from existing scenery
]]
function SceneryService:_checkSpacing(position: Vector3, minSpacing: number): boolean
    if not self._sceneryFolder then
        return true
    end

    -- Check distance from existing scenery
    for _, child in self._sceneryFolder:GetChildren() do
        if child:IsA("Model") and child.PrimaryPart then
            local distance = (child.PrimaryPart.Position - position).Magnitude
            if distance < minSpacing then
                return false
            end
        end
    end

    -- Check distance from spawn points
    local spawnExclusion = Constants.SCENERY.SPAWN_EXCLUSION_RADIUS
    local spawnTags = { Constants.SEEKER_SPAWN_TAG, Constants.RUNNER_SPAWN_TAG, Constants.LOBBY_SPAWN_TAG }

    for _, tag in spawnTags do
        for _, spawn in CollectionService:GetTagged(tag) do
            if spawn:IsA("BasePart") then
                local distance = (spawn.Position - position).Magnitude
                if distance < spawnExclusion then
                    return false
                end
            end
        end
    end

    -- Also check SpawnPoints folder
    local spawnFolder = Workspace:FindFirstChild("SpawnPoints")
    if spawnFolder then
        for _, spawn in spawnFolder:GetChildren() do
            if spawn:IsA("BasePart") then
                local distance = (spawn.Position - position).Magnitude
                if distance < spawnExclusion then
                    return false
                end
            end
        end
    end

    return true
end

--[[
    Select a weighted random template
]]
function SceneryService:_selectWeightedTemplate(totalWeight: number): typeof(SCENERY_TEMPLATES.Tree_Large)?
    local roll = self._random:NextNumber(0, totalWeight)
    local cumulative = 0

    for _, template in SCENERY_TEMPLATES do
        cumulative += template.weight
        if roll <= cumulative then
            return template
        end
    end

    return nil
end

--[[
    Place a scenery object at position
]]
function SceneryService:_placeSceneryObject(template: typeof(SCENERY_TEMPLATES.Tree_Large), position: Vector3): boolean
    local model = template.create(self._random)
    if not model then
        return false
    end

    -- Apply random scale
    local scale = self._random:NextNumber(template.minScale, template.maxScale)
    self:_scaleModel(model, scale)

    -- Apply random Y rotation
    local rotation = self._random:NextNumber(0, math.pi * 2)

    -- Position with ground offset
    local finalPosition = position + Vector3.new(0, template.groundOffset * scale, 0)

    if model.PrimaryPart then
        model:PivotTo(CFrame.new(finalPosition) * CFrame.Angles(0, rotation, 0))
    end

    model.Parent = self._sceneryFolder
    return true
end

--[[
    Scale a model uniformly
]]
function SceneryService:_scaleModel(model: Model, scale: number)
    if model.PrimaryPart then
        local primaryCFrame = model.PrimaryPart.CFrame

        for _, part in model:GetDescendants() do
            if part:IsA("BasePart") then
                part.Size = part.Size * scale

                -- Reposition relative to primary part
                local offset = primaryCFrame:ToObjectSpace(part.CFrame)
                local scaledOffset = CFrame.new(offset.Position * scale) * (offset - offset.Position)
                part.CFrame = primaryCFrame * scaledOffset
            end
        end
    end
end

-- ============================================
-- SCENERY CREATION FUNCTIONS
-- ============================================

--[[
    Create a tree model
]]
function SceneryService:_createTree(random: Random, size: string): Model
    local model = Instance.new("Model")
    model.Name = "Tree_" .. size

    -- Trunk dimensions based on size
    local trunkHeight, trunkWidth, foliageSize
    if size == "large" then
        trunkHeight = random:NextNumber(12, 18)
        trunkWidth = random:NextNumber(1.5, 2.5)
        foliageSize = random:NextNumber(8, 12)
    elseif size == "medium" then
        trunkHeight = random:NextNumber(8, 12)
        trunkWidth = random:NextNumber(1, 1.8)
        foliageSize = random:NextNumber(5, 8)
    else -- small
        trunkHeight = random:NextNumber(4, 7)
        trunkWidth = random:NextNumber(0.6, 1.2)
        foliageSize = random:NextNumber(3, 5)
    end

    -- Trunk
    local trunk = Instance.new("Part")
    trunk.Name = "Trunk"
    trunk.Size = Vector3.new(trunkWidth, trunkHeight, trunkWidth)
    trunk.Position = Vector3.new(0, trunkHeight / 2, 0)
    trunk.Anchored = true
    trunk.BrickColor = BrickColor.new("Brown")
    trunk.Material = Enum.Material.Wood
    trunk.Parent = model

    -- Foliage (multiple spherical parts for natural look)
    local foliageColors = {
        BrickColor.new("Forest green"),
        BrickColor.new("Dark green"),
        BrickColor.new("Camo"),
    }

    local numFoliage = random:NextInteger(3, 5)
    for i = 1, numFoliage do
        local foliage = Instance.new("Part")
        foliage.Name = "Foliage" .. i
        foliage.Shape = Enum.PartType.Ball
        local fSize = foliageSize * random:NextNumber(0.6, 1.0)
        foliage.Size = Vector3.new(fSize, fSize * 0.8, fSize)
        foliage.Position = Vector3.new(
            random:NextNumber(-foliageSize / 3, foliageSize / 3),
            trunkHeight + random:NextNumber(0, foliageSize / 2),
            random:NextNumber(-foliageSize / 3, foliageSize / 3)
        )
        foliage.Anchored = true
        foliage.BrickColor = foliageColors[random:NextInteger(1, #foliageColors)]
        foliage.Material = Enum.Material.Grass
        foliage.Parent = model
    end

    model.PrimaryPart = trunk
    return model
end

--[[
    Create a rock model
]]
function SceneryService:_createRock(random: Random, size: string): Model
    local model = Instance.new("Model")
    model.Name = "Rock_" .. size

    local baseSize
    if size == "large" then
        baseSize = random:NextNumber(4, 7)
    elseif size == "medium" then
        baseSize = random:NextNumber(2, 4)
    else
        baseSize = random:NextNumber(0.8, 2)
    end

    local rockColors = {
        BrickColor.new("Dark stone grey"),
        BrickColor.new("Medium stone grey"),
        BrickColor.new("Flint"),
    }

    -- Main rock body
    local rock = Instance.new("Part")
    rock.Name = "RockBody"
    rock.Size = Vector3.new(
        baseSize * random:NextNumber(0.8, 1.2),
        baseSize * random:NextNumber(0.5, 0.9),
        baseSize * random:NextNumber(0.8, 1.2)
    )
    rock.Position = Vector3.new(0, rock.Size.Y / 2, 0)
    rock.Anchored = true
    rock.BrickColor = rockColors[random:NextInteger(1, #rockColors)]
    rock.Material = Enum.Material.Slate
    rock.Parent = model

    -- Add smaller rocks around it for larger sizes
    if size ~= "small" then
        local numExtra = random:NextInteger(1, 3)
        for i = 1, numExtra do
            local extra = Instance.new("Part")
            extra.Name = "RockExtra" .. i
            local extraSize = baseSize * random:NextNumber(0.2, 0.5)
            extra.Size = Vector3.new(
                extraSize * random:NextNumber(0.7, 1.3),
                extraSize * random:NextNumber(0.5, 1.0),
                extraSize * random:NextNumber(0.7, 1.3)
            )
            extra.Position = Vector3.new(
                random:NextNumber(-baseSize / 2, baseSize / 2),
                extra.Size.Y / 2,
                random:NextNumber(-baseSize / 2, baseSize / 2)
            )
            extra.Anchored = true
            extra.BrickColor = rockColors[random:NextInteger(1, #rockColors)]
            extra.Material = Enum.Material.Slate
            extra.Parent = model
        end
    end

    model.PrimaryPart = rock
    return model
end

--[[
    Create a bush model
]]
function SceneryService:_createBush(random: Random): Model
    local model = Instance.new("Model")
    model.Name = "Bush"

    local bushColors = {
        BrickColor.new("Forest green"),
        BrickColor.new("Dark green"),
        BrickColor.new("Earth green"),
    }

    local baseSize = random:NextNumber(1.5, 3)
    local numParts = random:NextInteger(3, 6)

    local mainPart: Part? = nil

    for i = 1, numParts do
        local part = Instance.new("Part")
        part.Name = "BushPart" .. i
        part.Shape = Enum.PartType.Ball
        local pSize = baseSize * random:NextNumber(0.5, 1.0)
        part.Size = Vector3.new(pSize, pSize * 0.7, pSize)
        part.Position = Vector3.new(
            random:NextNumber(-baseSize / 2, baseSize / 2),
            pSize / 2 + random:NextNumber(0, 0.5),
            random:NextNumber(-baseSize / 2, baseSize / 2)
        )
        part.Anchored = true
        part.BrickColor = bushColors[random:NextInteger(1, #bushColors)]
        part.Material = Enum.Material.Grass
        part.Parent = model

        if i == 1 then
            mainPart = part
        end
    end

    model.PrimaryPart = mainPart
    return model
end

--[[
    Create a fallen log model
]]
function SceneryService:_createFallenLog(random: Random): Model
    local model = Instance.new("Model")
    model.Name = "FallenLog"

    local length = random:NextNumber(6, 12)
    local diameter = random:NextNumber(0.8, 1.8)

    -- Main log
    local log = Instance.new("Part")
    log.Name = "Log"
    log.Shape = Enum.PartType.Cylinder
    log.Size = Vector3.new(length, diameter, diameter)
    log.CFrame = CFrame.new(0, diameter / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
    log.Anchored = true
    log.BrickColor = BrickColor.new("Brown")
    log.Material = Enum.Material.Wood
    log.Parent = model

    -- Add some moss patches
    local numMoss = random:NextInteger(1, 3)
    for i = 1, numMoss do
        local moss = Instance.new("Part")
        moss.Name = "Moss" .. i
        moss.Size = Vector3.new(
            random:NextNumber(1, 2),
            0.1,
            random:NextNumber(0.5, 1)
        )
        moss.Position = Vector3.new(
            random:NextNumber(-length / 3, length / 3),
            diameter / 2 + 0.05,
            random:NextNumber(-diameter / 4, diameter / 4)
        )
        moss.Anchored = true
        moss.BrickColor = BrickColor.new("Moss")
        moss.Material = Enum.Material.Grass
        moss.Parent = model
    end

    model.PrimaryPart = log
    return model
end

--[[
    Create mushroom cluster
]]
function SceneryService:_createMushrooms(random: Random): Model
    local model = Instance.new("Model")
    model.Name = "Mushrooms"

    local mushroomColors = {
        BrickColor.new("Brick red"),
        BrickColor.new("Brown"),
        BrickColor.new("Nougat"),
        BrickColor.new("Bright red"),
    }

    local numMushrooms = random:NextInteger(2, 5)
    local mainPart: Part? = nil

    for i = 1, numMushrooms do
        local height = random:NextNumber(0.3, 0.8)
        local capSize = random:NextNumber(0.4, 0.9)

        -- Stem
        local stem = Instance.new("Part")
        stem.Name = "Stem" .. i
        stem.Shape = Enum.PartType.Cylinder
        stem.Size = Vector3.new(height, capSize * 0.3, capSize * 0.3)
        local xOff = random:NextNumber(-1, 1)
        local zOff = random:NextNumber(-1, 1)
        stem.CFrame = CFrame.new(xOff, height / 2, zOff) * CFrame.Angles(0, 0, math.rad(90))
        stem.Anchored = true
        stem.BrickColor = BrickColor.new("Institutional white")
        stem.Material = Enum.Material.SmoothPlastic
        stem.Parent = model

        -- Cap
        local cap = Instance.new("Part")
        cap.Name = "Cap" .. i
        cap.Shape = Enum.PartType.Ball
        cap.Size = Vector3.new(capSize, capSize * 0.5, capSize)
        cap.Position = Vector3.new(xOff, height, zOff)
        cap.Anchored = true
        cap.BrickColor = mushroomColors[random:NextInteger(1, #mushroomColors)]
        cap.Material = Enum.Material.SmoothPlastic
        cap.Parent = model

        if i == 1 then
            mainPart = stem
        end
    end

    model.PrimaryPart = mainPart
    return model
end

--[[
    Create tall grass patch
]]
function SceneryService:_createTallGrass(random: Random): Model
    local model = Instance.new("Model")
    model.Name = "TallGrass"

    local grassColors = {
        BrickColor.new("Bright green"),
        BrickColor.new("Lime green"),
        BrickColor.new("Forest green"),
    }

    local numBlades = random:NextInteger(5, 12)
    local mainPart: Part? = nil

    for i = 1, numBlades do
        local height = random:NextNumber(0.8, 1.8)
        local width = random:NextNumber(0.05, 0.15)

        local blade = Instance.new("Part")
        blade.Name = "Blade" .. i
        blade.Size = Vector3.new(width, height, width)
        blade.Position = Vector3.new(
            random:NextNumber(-0.8, 0.8),
            height / 2,
            random:NextNumber(-0.8, 0.8)
        )
        -- Slight random tilt
        blade.CFrame = blade.CFrame * CFrame.Angles(
            random:NextNumber(-0.2, 0.2),
            random:NextNumber(0, math.pi * 2),
            random:NextNumber(-0.2, 0.2)
        )
        blade.Anchored = true
        blade.BrickColor = grassColors[random:NextInteger(1, #grassColors)]
        blade.Material = Enum.Material.Grass
        blade.CanCollide = false
        blade.Parent = model

        if i == 1 then
            mainPart = blade
        end
    end

    model.PrimaryPart = mainPart
    return model
end

--[[
    Create tree stump
]]
function SceneryService:_createStump(random: Random): Model
    local model = Instance.new("Model")
    model.Name = "Stump"

    local diameter = random:NextNumber(1.5, 3)
    local height = random:NextNumber(0.5, 1.5)

    -- Main stump
    local stump = Instance.new("Part")
    stump.Name = "Stump"
    stump.Shape = Enum.PartType.Cylinder
    stump.Size = Vector3.new(height, diameter, diameter)
    stump.CFrame = CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
    stump.Anchored = true
    stump.BrickColor = BrickColor.new("Brown")
    stump.Material = Enum.Material.Wood
    stump.Parent = model

    -- Top rings texture (decal simulation with smaller cylinder)
    local top = Instance.new("Part")
    top.Name = "StumpTop"
    top.Shape = Enum.PartType.Cylinder
    top.Size = Vector3.new(0.1, diameter * 0.9, diameter * 0.9)
    top.CFrame = CFrame.new(0, height, 0) * CFrame.Angles(0, 0, math.rad(90))
    top.Anchored = true
    top.BrickColor = BrickColor.new("Nougat")
    top.Material = Enum.Material.Wood
    top.Parent = model

    -- Maybe add some mushrooms on stump
    if random:NextNumber() > 0.5 then
        local mushroom = Instance.new("Part")
        mushroom.Name = "StumpMushroom"
        mushroom.Shape = Enum.PartType.Ball
        mushroom.Size = Vector3.new(0.3, 0.2, 0.3)
        mushroom.Position = Vector3.new(diameter / 2 - 0.1, height * 0.6, 0)
        mushroom.Anchored = true
        mushroom.BrickColor = BrickColor.new("Brown")
        mushroom.Material = Enum.Material.SmoothPlastic
        mushroom.Parent = model
    end

    model.PrimaryPart = stump
    return model
end

--[[
    Create a hiding bush - larger, denser bush that players can hide inside
    CanCollide = false allows players to walk through
    CanQuery = true (default) allows flashlight raycasts to be blocked
]]
function SceneryService:_createHidingBush(random: Random): Model
    local model = Instance.new("Model")
    model.Name = "HidingBush"

    -- Darker greens to distinguish from decorative bushes
    local bushColors = {
        BrickColor.new("Dark green"),
        BrickColor.new("Earth green"),
        BrickColor.new("Forest green"),
    }

    -- Size large enough to hide a player (player is ~5 studs tall, ~2 studs wide)
    local baseWidth = random:NextNumber(6, 8)
    local baseHeight = random:NextNumber(5, 7)

    -- Create dense overlapping spheres for the main body
    local numMainParts = random:NextInteger(8, 12)
    local mainPart: Part? = nil

    for i = 1, numMainParts do
        local part = Instance.new("Part")
        part.Name = "HidingBushPart" .. i
        part.Shape = Enum.PartType.Ball

        -- Vary sizes but keep them substantial
        local pWidth = baseWidth * random:NextNumber(0.4, 0.7)
        local pHeight = baseHeight * random:NextNumber(0.3, 0.6)
        part.Size = Vector3.new(pWidth, pHeight, pWidth)

        -- Position parts to create a dense, hollow-ish center
        local angle = (i / numMainParts) * math.pi * 2
        local radius = baseWidth * random:NextNumber(0.15, 0.35)
        local xOff = math.cos(angle) * radius
        local zOff = math.sin(angle) * radius
        local yOff = random:NextNumber(0, baseHeight * 0.4)

        part.Position = Vector3.new(xOff, pHeight / 2 + yOff, zOff)
        part.Anchored = true
        part.CanCollide = false -- Players can walk through
        part.CanQuery = true -- Flashlight raycasts will hit this
        part.CastShadow = true
        part.BrickColor = bushColors[random:NextInteger(1, #bushColors)]
        part.Material = Enum.Material.Grass
        part.Parent = model

        if i == 1 then
            mainPart = part
        end
    end

    -- Add top canopy parts
    local numTopParts = random:NextInteger(4, 6)
    for i = 1, numTopParts do
        local part = Instance.new("Part")
        part.Name = "HidingBushTop" .. i
        part.Shape = Enum.PartType.Ball

        local pSize = baseWidth * random:NextNumber(0.5, 0.8)
        part.Size = Vector3.new(pSize, pSize * 0.6, pSize)

        part.Position = Vector3.new(
            random:NextNumber(-baseWidth * 0.3, baseWidth * 0.3),
            baseHeight * random:NextNumber(0.5, 0.8),
            random:NextNumber(-baseWidth * 0.3, baseWidth * 0.3)
        )
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = true
        part.CastShadow = true
        part.BrickColor = bushColors[random:NextInteger(1, #bushColors)]
        part.Material = Enum.Material.Grass
        part.Parent = model
    end

    -- Add some berries/flowers as visual indicator this is a hiding spot
    local numBerries = random:NextInteger(3, 6)
    local berryColors = {
        BrickColor.new("Bright red"),
        BrickColor.new("Bright violet"),
        BrickColor.new("Bright blue"),
    }

    for i = 1, numBerries do
        local berry = Instance.new("Part")
        berry.Name = "Berry" .. i
        berry.Shape = Enum.PartType.Ball
        berry.Size = Vector3.new(0.3, 0.3, 0.3)

        local angle = random:NextNumber(0, math.pi * 2)
        local radius = baseWidth * random:NextNumber(0.3, 0.5)
        berry.Position = Vector3.new(
            math.cos(angle) * radius,
            random:NextNumber(1, baseHeight * 0.6),
            math.sin(angle) * radius
        )
        berry.Anchored = true
        berry.CanCollide = false
        berry.CanQuery = false -- Don't block raycasts with tiny berries
        berry.BrickColor = berryColors[random:NextInteger(1, #berryColors)]
        berry.Material = Enum.Material.SmoothPlastic
        berry.Parent = model
    end

    model.PrimaryPart = mainPart
    return model
end

-- ============================================
-- CLIENT METHODS
-- ============================================

function SceneryService.Client:GetSceneryCount(): number
    if self.Server._sceneryFolder then
        return #self.Server._sceneryFolder:GetChildren()
    end
    return 0
end

function SceneryService.Client:IsGenerated(): boolean
    return self.Server._generated
end

return SceneryService
