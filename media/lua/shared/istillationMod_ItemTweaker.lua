-- DistillationMod_ItemTweaker.lua
-- Modifie les propriétés des items selon les options sandbox
-- Version 1.2.1 - Build 41 compatible

-- ================================================
-- MODIFICATION DYNAMIQUE DES ITEMS
-- ================================================

local function tweakItems()
    print("[DistillationMod] Tweaking items based on sandbox options...")

    local scriptManager = getScriptManager()
    if not scriptManager then
        print("[DistillationMod] ERROR: ScriptManager not available")
        return
    end

    -- Modifier l'essence distillée
    local essenceDistillee = scriptManager:getItem("DistillationMod.EssenceDistillee")
    if essenceDistillee then
        local useDelta = DistillationMod.CalculateUseDelta()
        essenceDistillee:DoParam("UseDelta = " .. tostring(useDelta))

        print("[DistillationMod] Essence Distillee UseDelta set to: " .. useDelta)
        print("[DistillationMod] This equals " .. DistillationMod.Config.FuelYieldUnits .. " units")
    end

    -- CRITIQUE : Fixer le temps de cuisson
    -- Le jeu utilise des "ticks" pas des minutes réelles
    local melangeDistillation = scriptManager:getItem("DistillationMod.MelangeDistillation")
    if melangeDistillation then
        local cookTime = DistillationMod.Config.CookingTimeMinutes

        -- IMPORTANT : MinutesToCook est en minutes IN-GAME
        -- 1 minute in-game = 1 minute réelle si vitesse normale
        melangeDistillation:DoParam("MinutesToCook = " .. tostring(cookTime))
        melangeDistillation:DoParam("MinutesToBurn = " .. tostring(cookTime + 60))

        print("[DistillationMod] Cooking time set to: " .. cookTime .. " in-game minutes")
    end

    print("[DistillationMod] Item tweaking complete")
end

-- Appliquer les modifications après chargement complet
Events.OnGameBoot.Add(function()
    print("[DistillationMod] OnGameBoot triggered")

    -- Charger les sandbox options d'abord
    if DistillationMod and DistillationMod.LoadSandboxOptions then
        DistillationMod.LoadSandboxOptions()
    end

    -- Puis modifier les items
    tweakItems()
end)
