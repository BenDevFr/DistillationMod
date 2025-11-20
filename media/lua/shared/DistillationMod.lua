-- DistillationMod.lua
-- Vérification pour la préparation de distillation

-- Vérifie que la Marmite de Distillation PLEINE est bien remplie (>= 80%)
function DistillationMod_CheckFullMarmite(item)
    if not item then return true end

    local success, fullType = pcall(function() return item:getFullType() end)
    if not success then return true end

    if fullType ~= "DistillationMod.MarmiteDistillationFull" then
        return true
    end

    local delta = item:getUsedDelta()
    return delta and delta >= 0.8
end
