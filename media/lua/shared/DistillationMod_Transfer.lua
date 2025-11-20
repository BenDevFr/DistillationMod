-- DistillationMod_Transfer.lua
-- Système de transfert d'essence entre conteneurs
-- Version 1.1 - Synchronisation multijoueur améliorée

require "TimedActions/ISBaseTimedAction"

-- ================================================
-- CONSTANTES
-- ================================================

-- Temps par unité transférée (en dixièmes de seconde)
-- 10 = 1 seconde par unité
local TRANSFER_TIME_PER_UNIT = 10

-- ================================================
-- TimedAction : Transvaser Essence
-- ================================================

ISTransferEssence = ISBaseTimedAction:derive("ISTransferEssence")

--- Vérifie que l'action de transfert est toujours valide
function ISTransferEssence:isValid()
 -- Vérifier que la source existe
 if not self.source then return false end
 
 -- Vérifier que la source est toujours dans l'inventaire
 if not self.character:getInventory():contains(self.source) then return false end
 
 -- Vérifier la quantité disponible
 local sourceAmount = self.source:getDrainableUsesInt()
 if not sourceAmount or sourceAmount <= 0 then return false end
 
 return true
end

--- Met à jour la progression du transfert
function ISTransferEssence:update()
 if self.target then
 self.target:setJobDelta(self:getJobDelta())
 end
 
 -- Calcul de la progression
 local actionCurrent = math.floor(self.itemStart + (self.itemTarget - self.itemStart) * self:getJobDelta() + 0.001)
 local itemCurrent = math.floor(self.target:getUsedDelta() / self.target:getUseDelta() + 0.001)
 
 -- Mise à jour des deltas si progression
 if actionCurrent > itemCurrent then
 local sourceUses = self.source:getDrainableUsesInt()
 if sourceUses then
 self.source:setUsedDelta((sourceUses - (actionCurrent - itemCurrent)) * self.source:getUseDelta())
 self.target:setUsedDelta(actionCurrent * self.target:getUseDelta())
 end
 end
end

--- Démarre l'action de transfert
function ISTransferEssence:start()
 -- Si conteneur vide, créer le conteneur plein correspondant
 if self.wasEmpty then
 local chr = self.character
 local emptyCan = self.targetEmpty
 local newType = emptyCan:getReplaceType("PetrolSource")
 
 -- Fallback si getReplaceType échoue
 if not newType then
 if emptyCan:getType() == "EmptyPetrolCan" then
 newType = "Base.PetrolCan"
 elseif emptyCan:getType() == "PopBottleEmpty" then
 newType = "Base.PetrolPopBottle"
 elseif emptyCan:getType() == "WaterBottleEmpty" then
 newType = "Base.WaterBottlePetrol"
 elseif emptyCan:getType() == "BleachEmpty" then
 newType = "Base.PetrolBleachBottle"
 elseif emptyCan:getType() == "WhiskeyEmpty" then
 newType = "Base.WhiskeyPetrol"
 elseif emptyCan:getType() == "WineEmpty" then
 newType = "Base.WinePetrol"
 else
 newType = "Base.PetrolCan"
 end
 end
 
 -- Créer le nouveau conteneur plein
 self.target = chr:getInventory():AddItem(newType)
 self.target:setUsedDelta(0)
 self.target:setCondition(emptyCan:getCondition())
 self.target:setFavorite(emptyCan:isFavorite())
 
 -- Remplacer dans les mains si équipé
 if chr:getPrimaryHandItem() == emptyCan then
 chr:setPrimaryHandItem(self.target)
 end
 if chr:getSecondaryHandItem() == emptyCan then
 chr:setSecondaryHandItem(self.target)
 end
 
 -- Retirer le conteneur vide
 chr:getInventory():Remove(emptyCan)
 end
 
 -- Configuration de l'action
 self.target:setJobType(getText("ContextMenu_Remplir"))
 self.target:setJobDelta(0.0)
 
 -- Calcul du temps nécessaire
 local sourceUses = self.source:getDrainableUsesInt() or 0
 local itemCurrent = math.floor(self.target:getUsedDelta() / self.target:getUseDelta() + 0.001)
 local itemMax = math.floor(1 / self.target:getUseDelta() + 0.001)
 local take = math.min(sourceUses, itemMax - itemCurrent)
 
 self.action:setTime(take * TRANSFER_TIME_PER_UNIT)
 self.itemStart = itemCurrent
 self.itemTarget = itemCurrent + take
 
 -- Animation et son
 self:setActionAnim("Pour")
 self.sound = self.character:playSound("PourLiquid")
end

--- Arrête l'action prématurément
function ISTransferEssence:stop()
 if self.sound and self.character then
 self.character:stopOrTriggerSound(self.sound)
 end
 if self.target then
 self.target:setJobDelta(0.0)
 end
 ISBaseTimedAction.stop(self)
end

--- Finalise le transfert
function ISTransferEssence:perform()
 if self.sound and self.character then
 self.character:stopOrTriggerSound(self.sound)
 end
 
 if self.target then
 self.target:setJobDelta(0.0)
 end
 
 -- Mise à jour finale des quantités
 local itemCurrent = math.floor(self.target:getUsedDelta() / self.target:getUseDelta() + 0.001)
 if self.itemTarget > itemCurrent then
 local diff = self.itemTarget - itemCurrent
 self.target:setUsedDelta(self.itemTarget * self.target:getUseDelta())
 
 local sourceUses = self.source:getDrainableUsesInt()
 if sourceUses then
 self.source:setUsedDelta((sourceUses - diff) * self.source:getUseDelta())
 end
 
 -- CRITIQUE : Synchronisation multijoueur
 if isClient() then
 self.source:sendObjectChange('usedDelta')
 if self.target then
 self.target:sendObjectChange('usedDelta')
 end
 end
 end
 
 ISBaseTimedAction.perform(self)
end

--- Constructeur
function ISTransferEssence:new(character, source, target, wasEmpty, targetEmpty)
 local o = {}
 setmetatable(o, self)
 self.__index = self
 o.character = character
 o.source = source
 o.target = target
 o.wasEmpty = wasEmpty
 o.targetEmpty = targetEmpty
 o.stopOnWalk = true
 o.stopOnRun = true
 o.maxTime = 100
 return o
end

-- ================================================
-- Helper Functions
-- ================================================

--- Vérifie si un item est un conteneur essence vide
local function predicateEmptyPetrol(item)
 return item:hasTag("EmptyPetrol") or item:getType() == "EmptyPetrolCan"
end

--- Vérifie si un conteneur essence n'est pas plein
local function predicatePetrolNotFull(item)
 if not item:hasTag("Petrol") then return false end
 if not instanceof(item, "DrainableComboItem") then return false end
 
 local current = item:getDrainableUsesInt() or 0
 local max = math.floor(1 / item:getUseDelta() + 0.001)
 
 return current < max
end

-- ================================================
-- Callbacks Actions
-- ================================================

--- Lance le transfert vers un conteneur unique
local function onTransferToOne(playerObj, essenceBrute, container)
 local wasEmpty = predicateEmptyPetrol(container)
 local targetEmpty = wasEmpty and container or nil
 local target = wasEmpty and nil or container
 
 ISTimedActionQueue.add(ISTransferEssence:new(playerObj, essenceBrute, target, wasEmpty, targetEmpty))
end

--- Lance le transfert vers tous les conteneurs disponibles
local function onTransferToAll(playerObj, essenceBrute, containers)
 for _, container in ipairs(containers) do
 local wasEmpty = predicateEmptyPetrol(container)
 local targetEmpty = wasEmpty and container or nil
 local target = wasEmpty and nil or container
 
 ISTimedActionQueue.add(ISTransferEssence:new(playerObj, essenceBrute, target, wasEmpty, targetEmpty))
 end
end

-- ================================================
-- Menu Contextuel
-- ================================================

--- Crée le menu contextuel de transfert
local function createTransferContextMenu(player, context, worldobjects, essenceBrute)
 -- Vérification que c'est bien notre essence brute
 if essenceBrute:getFullType() ~= "DistillationMod.PotDistillationCooked" then
 return
 end
 
 local playerObj = getSpecificPlayer(player)
 local sourceUses = essenceBrute:getDrainableUsesInt() or 0
 
 -- Pas de transfert si vide
 if sourceUses <= 0 then
 return
 end
 
 -- Recherche des conteneurs disponibles (optimisée)
 local containers = {}
 local inv = playerObj:getInventory()
 local items = inv:getItems()
 
 for i = 0, items:size() - 1 do
 local item = items:get(i)
 
 -- Exclure la source elle-même (évite duplication)
 if item and item ~= essenceBrute then
 if predicateEmptyPetrol(item) or predicatePetrolNotFull(item) then
 table.insert(containers, item)
 end
 end
 end
 
 -- Pas de conteneurs disponibles
 if #containers == 0 then
 return
 end
 
 -- Création du menu principal
 local mainOption = context:addOption(getText("ContextMenu_RemplirEssence"), playerObj, nil)
 local subMenu = ISContextMenu:getNew(context)
 context:addSubMenu(mainOption, subMenu)
 
 -- Option 1 : Tous les conteneurs (si plusieurs)
 if #containers > 1 then
 subMenu:addOption(getText("ContextMenu_TousConteneurs", #containers), playerObj, onTransferToAll, essenceBrute, containers)
 subMenu:addOption("---", nil, nil)
 end
 
 -- Option 2+ : Chaque conteneur individuellement
 for _, container in ipairs(containers) do
 local name = container:getDisplayName()
 local current = 0
 local max = 0
 
 -- Afficher niveau si partiellement plein
 if predicatePetrolNotFull(container) then
 current = container:getDrainableUsesInt() or 0
 max = math.floor(1 / container:getUseDelta() + 0.001)
 name = name .. " (" .. current .. "/" .. max .. ")"
 end
 
 subMenu:addOption(name, playerObj, onTransferToOne, essenceBrute, container)
 end
end

--- Hook sur le menu contextuel d'inventaire
local function onFillInventoryObjectContextMenu(player, context, items)
 if not items or #items == 0 then return end
 
 local essenceBrute = nil
 
 -- Recherche de l'essence brute dans la sélection
 for i, item in ipairs(items) do
 if not instanceof(item, "InventoryItem") then
 item = item.items[1]
 end
 
 if item and item:getFullType() == "DistillationMod.PotDistillationCooked" then
 essenceBrute = item
 break
 end
 end
 
 if essenceBrute then
 createTransferContextMenu(player, context, nil, essenceBrute)
 end
end

-- Enregistrement de l'événement
Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)