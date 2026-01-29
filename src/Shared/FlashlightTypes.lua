--!strict
--[[
    FlashlightTypes.lua
    Defines different flashlight configurations
    Add new flashlight types here for future expansion
]]

export type FlashlightConfig = {
    name: string,
    displayName: string,

    -- Detection properties (used by server for cone detection)
    range: number,
    angle: number,

    -- Model asset ID from Creator Store
    -- The model should have:
    --   - A part named "Handle" (where player grips)
    --   - A SpotLight inside
    modelAssetId: number,
}

local FlashlightTypes = {}

-- Default flashlight
FlashlightTypes.Standard = {
    name = "Standard",
    displayName = "Standard Flashlight",

    -- Detection properties
    range = 50,
    angle = 45,

    -- Creator Store model (manually placed in ReplicatedStorage/FlashlightModels)
    modelAssetId = 15430976589,
} :: FlashlightConfig

-- Get a flashlight config by name
function FlashlightTypes.get(name: string): FlashlightConfig?
    return (FlashlightTypes :: any)[name]
end

-- Get the default flashlight
function FlashlightTypes.getDefault(): FlashlightConfig
    return FlashlightTypes.Standard
end

-- List all available flashlight types
function FlashlightTypes.getAll(): { FlashlightConfig }
    local configs = {}
    for key, value in FlashlightTypes :: any do
        if type(value) == "table" and value.name then
            table.insert(configs, value)
        end
    end
    return configs
end

return FlashlightTypes
