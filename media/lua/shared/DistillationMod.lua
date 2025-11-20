-- DistillationMod.lua
-- Vérification pour la préparation de distillation
-- Version 1.1 - Multijoueur optimisé

-- ================================================
-- CONSTANTES DE CONFIGURATION
-- ================================================

-- Seuil minimum d'eau requis (70% = 20 unités sur 25)
local MINIMUM_WATER_THRESHOLD = 0.70

-- ================================================
-- RECETTE : Préparer Distillation
-- ================================================

--- Vérifie que la Marmite de Distillation est suffisamment remplie
-- @param item L'item à vérifier (MarmiteDistillationFull)
-- @return boolean true si la marmite a assez d'eau (>=70%)
function DistillationMod_CheckFullMarmite(item)
 -- Validation de base
 if not item then return true end
 
 -- Récupération sécurisée du type
 local success, fullType = pcall(function() return item:getFullType() end)
 if not success then return true end
 
 -- Vérification que c'est bien notre marmite pleine
 if fullType ~= "DistillationMod.MarmiteDistillationFull" then 
 return true 
 end
 
 -- Vérification du niveau d'eau
 local delta = item:getUsedDelta()
 if not delta then return false end
 
 return delta >= MINIMUM_WATER_THRESHOLD
end