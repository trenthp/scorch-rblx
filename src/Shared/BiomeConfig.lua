--!strict
--[[
    BiomeConfig.lua
    Color palettes, lighting settings, and materials per biome
]]

export type BiomeLighting = {
    ClockTime: number,
    Brightness: number,
    Ambient: Color3,
    OutdoorAmbient: Color3,
    FogColor: Color3,
    FogStart: number,
    FogEnd: number,
}

export type BiomeColors = {
    ground: Color3,
    groundMaterial: Enum.Material,
    trunkColors: { BrickColor },
    foliageColors: { BrickColor },
    rockColors: { BrickColor },
    bushColors: { BrickColor },
    hidingBushColors: { BrickColor },
    grassColors: { BrickColor },
}

export type BiomeConfig = {
    name: string,
    lighting: BiomeLighting,
    colors: BiomeColors,
    fogEnabled: boolean,
    atmosphereConfig: {
        Density: number,
        Color: Color3,
        Haze: number,
    }?,
    -- Runner gets a slight brightness/ambient boost (since they have no flashlight)
    runnerLightingBoost: {
        Brightness: number,      -- Added to base brightness
        AmbientBoost: number,    -- RGB boost to ambient colors (0-50 range)
    }?,
}

local BiomeConfigs: { [string]: BiomeConfig } = {
    -- ===========================================
    -- FOREST (Default)
    -- Night, lush greens
    -- ===========================================
    Forest = {
        name = "Forest",
        lighting = {
            ClockTime = 21.5,            -- Evening/night
            Brightness = 1,              -- Normal brightness
            Ambient = Color3.fromRGB(120, 125, 120),
            OutdoorAmbient = Color3.fromRGB(110, 115, 110),
            FogColor = Color3.fromRGB(100, 110, 100),
            FogStart = 100,
            FogEnd = 1000,
        },
        colors = {
            ground = Color3.fromRGB(76, 97, 47),
            groundMaterial = Enum.Material.Grass,
            trunkColors = {
                BrickColor.new("Brown"),
                BrickColor.new("Reddish brown"),
                BrickColor.new("Pine Cone"),
            },
            foliageColors = {
                BrickColor.new("Forest green"),
                BrickColor.new("Dark green"),
                BrickColor.new("Camo"),
            },
            rockColors = {
                BrickColor.new("Dark stone grey"),
                BrickColor.new("Medium stone grey"),
                BrickColor.new("Flint"),
            },
            bushColors = {
                BrickColor.new("Forest green"),
                BrickColor.new("Dark green"),
                BrickColor.new("Earth green"),
            },
            hidingBushColors = {
                BrickColor.new("Dark green"),
                BrickColor.new("Earth green"),
                BrickColor.new("Forest green"),
            },
            grassColors = {
                BrickColor.new("Bright green"),
                BrickColor.new("Lime green"),
                BrickColor.new("Forest green"),
            },
        },
        fogEnabled = false,
        atmosphereConfig = {
            Density = 0.2,
            Color = Color3.fromRGB(80, 90, 80),
            Haze = 0.5,
        },
        -- Runners can see a bit better
        runnerLightingBoost = {
            Brightness = 0.2,
            AmbientBoost = 30,
        },
    },

    -- ===========================================
    -- SNOW
    -- Night, whites and greys, blue tint
    -- ===========================================
    Snow = {
        name = "Snow",
        lighting = {
            ClockTime = 21.5,            -- Evening/night
            Brightness = 1,              -- Normal brightness
            Ambient = Color3.fromRGB(130, 135, 150),
            OutdoorAmbient = Color3.fromRGB(120, 125, 140),
            FogColor = Color3.fromRGB(140, 145, 160),
            FogStart = 100,
            FogEnd = 800,
        },
        colors = {
            ground = Color3.fromRGB(235, 240, 250),
            groundMaterial = Enum.Material.Snow,
            trunkColors = {
                BrickColor.new("Dark stone grey"),
                BrickColor.new("Medium stone grey"),
                BrickColor.new("Brown"),
            },
            foliageColors = {
                BrickColor.new("White"),
                BrickColor.new("Institutional white"),
                BrickColor.new("Light stone grey"),
            },
            rockColors = {
                BrickColor.new("Ghost grey"),
                BrickColor.new("Light stone grey"),
                BrickColor.new("Medium stone grey"),
            },
            bushColors = {
                BrickColor.new("White"),
                BrickColor.new("Institutional white"),
                BrickColor.new("Ghost grey"),
            },
            hidingBushColors = {
                BrickColor.new("White"),
                BrickColor.new("Light stone grey"),
                BrickColor.new("Ghost grey"),
            },
            grassColors = {
                BrickColor.new("White"),
                BrickColor.new("Institutional white"),
                BrickColor.new("Ghost grey"),
            },
        },
        fogEnabled = false,
        atmosphereConfig = {
            Density = 0.25,
            Color = Color3.fromRGB(120, 125, 140),
            Haze = 1,
        },
        -- Runners can see a bit better
        runnerLightingBoost = {
            Brightness = 0.2,
            AmbientBoost = 30,
        },
    },

    -- ===========================================
    -- WAREHOUSE
    -- Industrial, concrete and metal
    -- ===========================================
    Warehouse = {
        name = "Warehouse",
        lighting = {
            ClockTime = 21.5,            -- Evening/night
            Brightness = 1,              -- Normal brightness
            Ambient = Color3.fromRGB(120, 115, 110),
            OutdoorAmbient = Color3.fromRGB(110, 105, 100),
            FogColor = Color3.fromRGB(90, 85, 80),
            FogStart = 100,
            FogEnd = 900,
        },
        colors = {
            ground = Color3.fromRGB(90, 85, 80),
            groundMaterial = Enum.Material.Concrete,
            trunkColors = {
                -- Metal pillars/supports
                BrickColor.new("Dark stone grey"),
                BrickColor.new("Medium stone grey"),
                BrickColor.new("Dirt brown"),
            },
            foliageColors = {
                -- Metal sheets, tarps, crates
                BrickColor.new("Dark stone grey"),
                BrickColor.new("Rust"),
                BrickColor.new("Sand red"),
            },
            rockColors = {
                -- Concrete blocks, debris
                BrickColor.new("Medium stone grey"),
                BrickColor.new("Dark stone grey"),
                BrickColor.new("Brick yellow"),
            },
            bushColors = {
                -- Crates, boxes, pallets
                BrickColor.new("Dirt brown"),
                BrickColor.new("Dark orange"),
                BrickColor.new("Reddish brown"),
            },
            hidingBushColors = {
                -- Large crates for hiding
                BrickColor.new("Brown"),
                BrickColor.new("Dirt brown"),
                BrickColor.new("Dark taupe"),
            },
            grassColors = {
                -- Debris, small items
                BrickColor.new("Dark stone grey"),
                BrickColor.new("Medium stone grey"),
                BrickColor.new("Dirt brown"),
            },
        },
        fogEnabled = false,
        atmosphereConfig = {
            Density = 0.2,
            Color = Color3.fromRGB(70, 65, 60),
            Haze = 0.5,
        },
        -- Runners can see a bit better
        runnerLightingBoost = {
            Brightness = 0.2,
            AmbientBoost = 30,
        },
    },
}

-- Biome rotation order
local BIOME_ROTATION = { "Forest", "Snow", "Warehouse" }

local BiomeConfigModule = {
    configs = BiomeConfigs,
    rotation = BIOME_ROTATION,
}

--[[
    Get config for a specific biome
    @param biome - The biome name
    @return BiomeConfig
]]
function BiomeConfigModule.getConfig(biome: string): BiomeConfig
    return BiomeConfigs[biome] or BiomeConfigs.Forest
end

--[[
    Get the next biome in rotation
    @param currentBiome - The current biome name
    @return Next biome name
]]
function BiomeConfigModule.getNextBiome(currentBiome: string): string
    for i, biome in BIOME_ROTATION do
        if biome == currentBiome then
            local nextIndex = (i % #BIOME_ROTATION) + 1
            return BIOME_ROTATION[nextIndex]
        end
    end
    return BIOME_ROTATION[1]
end

--[[
    Get all available biomes
    @return Array of biome names
]]
function BiomeConfigModule.getAllBiomes(): { string }
    return table.clone(BIOME_ROTATION)
end

--[[
    Get a random color from a color array
    @param colors - Array of BrickColors
    @param random - Random object (optional)
    @return BrickColor
]]
function BiomeConfigModule.getRandomColor(colors: { BrickColor }, random: Random?): BrickColor
    local rng = random or Random.new()
    return colors[rng:NextInteger(1, #colors)]
end

return BiomeConfigModule
