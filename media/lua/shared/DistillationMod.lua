-- DistillationMod.lua
-- Version 1.2 - Sandbox compatible

--- Vérifie que la Marmite de Distillation est suffisamment remplie
-- Utilise la config sandbox pour le seuil d'eau
function DistillationMod_CheckFullMarmite(item)
    if not item then return true end

    local success, fullType = pcall(function() return item:getFullType() end)
    if not success then return true end

    if fullType ~= "DistillationMod.MarmiteDistillationFull" then
        return true
    end

    -- Utilise la config sandbox
    return DistillationMod.HasEnoughWater(item)
end
