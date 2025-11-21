-- DistillationMod_SandboxOptions.lua
-- Système de configuration Sandbox pour le mod de distillation
-- Version 1.2.1 - Fix Build 41 compatibility

-- ================================================
-- CONSTANTES PAR DÉFAUT
-- ================================================

DistillationMod = DistillationMod or {}

-- Valeurs par défaut (utilisées si sandbox désactivé)
DistillationMod.Config = {
    -- Production
    FuelYieldUnits = 30,      -- Unités d'essence produites (10-1000)
    CookingTimeMinutes = 120, -- Temps de cuisson en minutes (30-480)

    -- Craft Marmite
    RequireWelding = true, -- Nécessite compétence soudure
    WeldingLevel = 3,      -- Niveau requis (0-10)
    MetalPipeCount = 2,    -- Tuyaux métal requis (1-10)
    SheetMetalCount = 1,   -- Tôles requises (1-10)
    ScrewsCount = 10,      -- Vis requises (5-50)

    -- Craft Jerrycan
    BottleCount = 15,       -- Bouteilles vides requises (5-50)
    RequireDuctTape = true, -- Nécessite duct tape
    DuctTapeAmount = 0.5,   -- Quantité de duct tape requise (0.1-1.0)

    -- Préparation
    WaterUnitsRequired = 20, -- Eau minimum requise (10-25)
    LogCount = 3,            -- Bûches requises (1-10)

    -- Transfert
    TransferSpeedMultiplier = 1.0, -- Vitesse transfert (0.5-3.0)
}

-- ================================================
-- CHARGEMENT DES OPTIONS SANDBOX
-- ================================================

--- Charge les options sandbox si disponibles
function DistillationMod.LoadSandboxOptions()
    -- Vérifier si SandboxVars existe
    if not SandboxVars then
        print("[DistillationMod] SandboxVars not available, using defaults")
        return
    end

    local sandbox = SandboxVars.DistillationMod

    if not sandbox then
        print("[DistillationMod] Sandbox options not configured, using defaults")
        return
    end

    -- Production
    if sandbox.FuelYieldUnits then
        DistillationMod.Config.FuelYieldUnits = sandbox.FuelYieldUnits
    end
    if sandbox.CookingTimeMinutes then
        DistillationMod.Config.CookingTimeMinutes = sandbox.CookingTimeMinutes
    end

    -- Craft Marmite
    if sandbox.RequireWelding ~= nil then
        DistillationMod.Config.RequireWelding = sandbox.RequireWelding
    end
    if sandbox.WeldingLevel then
        DistillationMod.Config.WeldingLevel = sandbox.WeldingLevel
    end
    if sandbox.MetalPipeCount then
        DistillationMod.Config.MetalPipeCount = sandbox.MetalPipeCount
    end
    if sandbox.SheetMetalCount then
        DistillationMod.Config.SheetMetalCount = sandbox.SheetMetalCount
    end
    if sandbox.ScrewsCount then
        DistillationMod.Config.ScrewsCount = sandbox.ScrewsCount
    end

    -- Craft Jerrycan
    if sandbox.BottleCount then
        DistillationMod.Config.BottleCount = sandbox.BottleCount
    end
    if sandbox.RequireDuctTape ~= nil then
        DistillationMod.Config.RequireDuctTape = sandbox.RequireDuctTape
    end

    -- Duct Tape Amount
    if sandbox.DuctTapeAmount then
        DistillationMod.Config.DuctTapeAmount = sandbox.DuctTapeAmount
    end

    -- Préparation
    if sandbox.WaterUnitsRequired then
        DistillationMod.Config.WaterUnitsRequired = sandbox.WaterUnitsRequired
    end
    if sandbox.LogCount then
        DistillationMod.Config.LogCount = sandbox.LogCount
    end

    -- Transfert
    if sandbox.TransferSpeedMultiplier then
        DistillationMod.Config.TransferSpeedMultiplier = sandbox.TransferSpeedMultiplier
    end

    print("[DistillationMod] Sandbox options loaded successfully")
    print("[DistillationMod] Fuel yield: " .. DistillationMod.Config.FuelYieldUnits .. " units")
    print("[DistillationMod] Cooking time: " .. DistillationMod.Config.CookingTimeMinutes .. " minutes")
end

-- ================================================
-- CALCULS DYNAMIQUES
-- ================================================

--- Calcule le UseDelta basé sur les unités configurées
-- @return number Le UseDelta pour l'essence brute
function DistillationMod.CalculateUseDelta()
    local units = DistillationMod.Config.FuelYieldUnits
    return 1.0 / units
end

--- Retourne le texte du tooltip avec quantité dynamique
-- @return string Le texte du tooltip
function DistillationMod.GetFuelTooltip()
    local units = DistillationMod.Config.FuelYieldUnits

    -- Détection de la langue sans utiliser Locale (Build 41)
    local lang = getCore():getOptionLanguageName()

    if lang == "FR" then
        return string.format(
            "Essence artisanale brute (%d unites). Utilisable directement pour vehicules et generateurs. Clic droit pour remplir des conteneurs.",
            units
        )
    else
        return string.format(
            "Raw artisanal fuel (%d units). Can be used directly for vehicles and generators. Right-click to fill containers.",
            units
        )
    end
end

--- Retourne le temps de cuisson en secondes (pour TimedAction)
-- @return number Temps en secondes
function DistillationMod.GetCookingTimeSeconds()
    return DistillationMod.Config.CookingTimeMinutes * 60
end

--- Calcule le temps de transfert par unité
-- @return number Temps en dixièmes de seconde
function DistillationMod.GetTransferTime()
    local baseTime = 10 -- 1 seconde par unité par défaut
    return baseTime / DistillationMod.Config.TransferSpeedMultiplier
end

--- Vérifie si assez d'eau est disponible
-- @param item L'item à vérifier
-- @return boolean true si assez d'eau
function DistillationMod.HasEnoughWater(item)
    if not item then return false end

    local waterUnits = item:getDrainableUsesInt() or 0
    return waterUnits >= DistillationMod.Config.WaterUnitsRequired
end


--- Gère la consommation de duct tape lors du crafting
function DistillationMod.ConsumeDuctTape(items, result, player)
    if not items or not player then return end

    local inv = player:getInventory()
    local ductTapeAmount = DistillationMod.Config.DuctTapeAmount

    -- Chercher le duct tape
    for i = 0, items:size() - 1 do
        local item = items:get(i)

        if item and item:getType() == "DuctTape" then
            local currentUses = item:getDrainableUsesInt() or 0
            local useDelta = item:getUseDelta()

            -- Calculer nouvelle quantité
            local newUses = currentUses - (ductTapeAmount * (1 / useDelta))

            if newUses <= 0 then
                -- Consommer complètement
                inv:Remove(item)
            else
                -- Réduire
                item:setUsedDelta(newUses * useDelta)
            end

            break
        end
    end
end

-- ================================================
-- ÉVÉNEMENTS
-- ================================================

-- Charger les options au démarrage du jeu
Events.OnGameBoot.Add(function()
    print("[DistillationMod] Loading sandbox options...")
    DistillationMod.LoadSandboxOptions()
end)
