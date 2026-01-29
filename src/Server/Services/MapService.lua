--!strict
--[[
    MapService.lua
    Manages map loading and player spawning
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages:WaitForChild("Knit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

local MapService = Knit.CreateService({
    Name = "MapService",

    Client = {},

    _currentMap = nil :: Model?,
    _seekerSpawns = {} :: { BasePart },
    _runnerSpawns = {} :: { BasePart },
    _lobbySpawns = {} :: { BasePart },
})

function MapService:KnitInit()
    self._seekerSpawns = {}
    self._runnerSpawns = {}
    self._lobbySpawns = {}
    print("[MapService] Initialized")
end

function MapService:KnitStart()
    -- Find spawn points in workspace
    self:_findSpawnPoints()
    print("[MapService] Started")
end

--[[
    Find all spawn points in the workspace
]]
function MapService:_findSpawnPoints()
    -- Find tagged spawn points
    self._seekerSpawns = CollectionService:GetTagged(Constants.SEEKER_SPAWN_TAG) :: { BasePart }
    self._runnerSpawns = CollectionService:GetTagged(Constants.RUNNER_SPAWN_TAG) :: { BasePart }
    self._lobbySpawns = CollectionService:GetTagged(Constants.LOBBY_SPAWN_TAG) :: { BasePart }

    -- Also look in SpawnPoints folder
    local spawnFolder = workspace:FindFirstChild("SpawnPoints")
    if spawnFolder then
        for _, child in spawnFolder:GetChildren() do
            if child:IsA("BasePart") then
                if child.Name == "SeekerSpawn" or child:HasTag(Constants.SEEKER_SPAWN_TAG) then
                    if not table.find(self._seekerSpawns, child) then
                        table.insert(self._seekerSpawns, child)
                    end
                elseif child.Name == "RunnerSpawn" or child:HasTag(Constants.RUNNER_SPAWN_TAG) then
                    if not table.find(self._runnerSpawns, child) then
                        table.insert(self._runnerSpawns, child)
                    end
                elseif child.Name == "LobbySpawn" or child:HasTag(Constants.LOBBY_SPAWN_TAG) then
                    if not table.find(self._lobbySpawns, child) then
                        table.insert(self._lobbySpawns, child)
                    end
                end
            end
        end
    end

    -- Create default spawns if none exist
    if #self._seekerSpawns == 0 then
        local defaultSeeker = self:_createDefaultSpawn("SeekerSpawn", Vector3.new(0, 5, 0))
        table.insert(self._seekerSpawns, defaultSeeker)
    end

    if #self._runnerSpawns == 0 then
        local defaultRunner = self:_createDefaultSpawn("RunnerSpawn", Vector3.new(20, 5, 0))
        table.insert(self._runnerSpawns, defaultRunner)
    end

    if #self._lobbySpawns == 0 then
        local defaultLobby = self:_createDefaultSpawn("LobbySpawn", Vector3.new(-20, 5, 0))
        table.insert(self._lobbySpawns, defaultLobby)
    end

    print(string.format("[MapService] Found spawns - Seeker: %d, Runner: %d, Lobby: %d",
        #self._seekerSpawns, #self._runnerSpawns, #self._lobbySpawns))
end

--[[
    Create a default spawn point
]]
function MapService:_createDefaultSpawn(name: string, position: Vector3): BasePart
    local spawnFolder = workspace:FindFirstChild("SpawnPoints")
    if not spawnFolder then
        spawnFolder = Instance.new("Folder")
        spawnFolder.Name = "SpawnPoints"
        spawnFolder.Parent = workspace
    end

    local spawn = Instance.new("Part")
    spawn.Name = name
    spawn.Size = Vector3.new(4, 1, 4)
    spawn.Position = position
    spawn.Anchored = true
    spawn.CanCollide = false
    spawn.Transparency = 0.5
    spawn.BrickColor = if name == "SeekerSpawn" then Constants.SEEKER_COLOR
        elseif name == "RunnerSpawn" then Constants.RUNNER_COLOR
        else Constants.LOBBY_COLOR
    spawn.Parent = spawnFolder

    return spawn
end

--[[
    Spawn all players at their appropriate spawn points
]]
function MapService:SpawnAllPlayers()
    local TeamService = Knit.GetService("TeamService")

    local seekers = TeamService:GetSeekers()
    local runners = TeamService:GetRunners()

    -- Spawn seekers
    for i, seeker in seekers do
        local spawnPoint = self._seekerSpawns[((i - 1) % #self._seekerSpawns) + 1]
        self:_spawnPlayerAt(seeker, spawnPoint)
    end

    -- Spawn runners
    for i, runner in runners do
        local spawnPoint = self._runnerSpawns[((i - 1) % #self._runnerSpawns) + 1]
        self:_spawnPlayerAt(runner, spawnPoint)
    end

    print("[MapService] All players spawned")
end

--[[
    Spawn a specific player at a spawn point
]]
function MapService:_spawnPlayerAt(player: Player, spawnPoint: BasePart)
    local character = player.Character
    if not character then
        -- Load character if needed
        player:LoadCharacter()
        character = player.Character or player.CharacterAdded:Wait()
    end

    local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
    if humanoidRootPart then
        -- Teleport to spawn point with slight Y offset
        local spawnPosition = spawnPoint.Position + Vector3.new(0, 3, 0)

        -- Add some randomness to prevent stacking
        local randomOffset = Vector3.new(
            math.random(-2, 2),
            0,
            math.random(-2, 2)
        )

        humanoidRootPart.CFrame = CFrame.new(spawnPosition + randomOffset)
    end
end

--[[
    Get a random seeker spawn point
]]
function MapService:GetRandomSeekerSpawn(): BasePart?
    if #self._seekerSpawns == 0 then
        return nil
    end
    return self._seekerSpawns[math.random(1, #self._seekerSpawns)]
end

--[[
    Get a random runner spawn point
]]
function MapService:GetRandomRunnerSpawn(): BasePart?
    if #self._runnerSpawns == 0 then
        return nil
    end
    return self._runnerSpawns[math.random(1, #self._runnerSpawns)]
end

--[[
    Get a random lobby spawn point
]]
function MapService:GetRandomLobbySpawn(): BasePart?
    if #self._lobbySpawns == 0 then
        return nil
    end
    return self._lobbySpawns[math.random(1, #self._lobbySpawns)]
end

-- Client methods
function MapService.Client:GetSpawnCounts(): { seeker: number, runner: number, lobby: number }
    return {
        seeker = #self.Server._seekerSpawns,
        runner = #self.Server._runnerSpawns,
        lobby = #self.Server._lobbySpawns,
    }
end

return MapService
