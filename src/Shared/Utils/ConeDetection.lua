--!strict
--[[
    ConeDetection.lua
    Utility for detecting if a target is within a cone (flashlight beam)
    Uses dot product for efficient angle checking
]]

local ConeDetection = {}

--[[
    Check if a point is within a cone
    @param origin - The origin point of the cone (flashlight position)
    @param direction - The direction the cone is facing (unit vector)
    @param targetPosition - The position to check
    @param range - Maximum distance of the cone
    @param angleInDegrees - Full cone angle in degrees
    @return boolean - Whether the target is within the cone
]]
function ConeDetection.IsInCone(
    origin: Vector3,
    direction: Vector3,
    targetPosition: Vector3,
    range: number,
    angleInDegrees: number
): boolean
    -- Vector from origin to target
    local toTarget = targetPosition - origin
    local distance = toTarget.Magnitude

    -- Check range first (early exit)
    if distance > range or distance < 0.01 then
        return false
    end

    -- Normalize the vector to target
    local toTargetNormalized = toTarget.Unit

    -- Normalize direction if not already
    local dirNormalized = direction.Unit

    -- Calculate dot product (cosine of angle between vectors)
    local dotProduct = dirNormalized:Dot(toTargetNormalized)

    -- Convert angle to half-angle and then to cosine threshold
    -- We use half the angle because the cone extends angleInDegrees/2 in each direction
    local halfAngleRadians = math.rad(angleInDegrees / 2)
    local cosineThreshold = math.cos(halfAngleRadians)

    -- If dot product is greater than cosine of half-angle, point is within cone
    return dotProduct >= cosineThreshold
end

--[[
    Check if a target is visible from origin (raycast line-of-sight check)
    @param origin - The origin point
    @param targetPosition - The target position to check
    @param ignoreList - Optional list of instances to ignore
    @return boolean - Whether the target is visible (no obstacles)
]]
function ConeDetection.HasLineOfSight(
    origin: Vector3,
    targetPosition: Vector3,
    ignoreList: { Instance }?
): boolean
    local direction = targetPosition - origin
    local distance = direction.Magnitude

    if distance < 0.01 then
        return true
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = ignoreList or {}
    raycastParams.IgnoreWater = true

    local result = workspace:Raycast(origin, direction, raycastParams)

    -- If no hit or hit is past the target, we have line of sight
    if not result then
        return true
    end

    return result.Distance >= distance - 0.5 -- Small tolerance
end

--[[
    Full cone check with line-of-sight verification
    @param origin - The origin point of the cone
    @param direction - The direction the cone is facing
    @param targetPosition - The position to check
    @param range - Maximum distance
    @param angleInDegrees - Full cone angle in degrees
    @param ignoreList - Instances to ignore for raycast
    @return boolean - Whether target is in cone AND visible
]]
function ConeDetection.IsTargetInConeWithLOS(
    origin: Vector3,
    direction: Vector3,
    targetPosition: Vector3,
    range: number,
    angleInDegrees: number,
    ignoreList: { Instance }?
): boolean
    -- First check if in cone (cheap)
    if not ConeDetection.IsInCone(origin, direction, targetPosition, range, angleInDegrees) then
        return false
    end

    -- Then check line of sight (more expensive)
    return ConeDetection.HasLineOfSight(origin, targetPosition, ignoreList)
end

--[[
    Get the closest point on a character for cone detection
    Uses HumanoidRootPart or torso as the target point
    @param character - The character model to get position from
    @return Vector3? - The position, or nil if character is invalid
]]
function ConeDetection.GetCharacterTargetPosition(character: Model): Vector3?
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if humanoidRootPart then
        return humanoidRootPart.Position
    end

    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if torso and torso:IsA("BasePart") then
        return torso.Position
    end

    return nil
end

return ConeDetection
