-- DistillationMod_Transfer.lua
-- Système de transfert d'essence avec menu de sélection

require "TimedActions/ISBaseTimedAction"

-- ================================================
-- TimedAction : Transvaser Essence
-- ================================================

ISTransferEssence = ISBaseTimedAction:derive("ISTransferEssence")

function ISTransferEssence:isValid()
    local sourceAmount = self.source:getDrainableUsesInt() or 0
    return sourceAmount > 0
end

function ISTransferEssence:update()
    if self.target then
        self.target:setJobDelta(self:getJobDelta())
    end

    local actionCurrent = math.floor(self.itemStart + (self.itemTarget - self.itemStart) * self:getJobDelta() + 0.001)
    local itemCurrent = math.floor(self.target:getUsedDelta() / self.target:getUseDelta() + 0.001)

    if actionCurrent > itemCurrent then
        local sourceUses = self.source:getDrainableUsesInt()
        self.source:setUsedDelta((sourceUses - (actionCurrent - itemCurrent)) * self.source:getUseDelta())
        self.target:setUsedDelta(actionCurrent * self.target:getUseDelta())
    end
end

function ISTransferEssence:start()
    if self.wasEmpty then
        local chr = self.character
        local emptyCan = self.targetEmpty
        local newType = emptyCan:getReplaceType("PetrolSource")

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

        self.target = chr:getInventory():AddItem(newType)
        self.target:setUsedDelta(0)
        self.target:setCondition(emptyCan:getCondition())
        self.target:setFavorite(emptyCan:isFavorite())

        if chr:getPrimaryHandItem() == emptyCan then
            chr:setPrimaryHandItem(self.target)
        end
        if chr:getSecondaryHandItem() == emptyCan then
            chr:setSecondaryHandItem(self.target)
        end

        chr:getInventory():Remove(emptyCan)
    end

    self.target:setJobType("Transvaser")
    self.target:setJobDelta(0.0)

    local sourceUses = self.source:getDrainableUsesInt() or 0
    local itemCurrent = math.floor(self.target:getUsedDelta() / self.target:getUseDelta() + 0.001)
    local itemMax = math.floor(1 / self.target:getUseDelta() + 0.001)
    local take = math.min(sourceUses, itemMax - itemCurrent)

    self.action:setTime(take * 50) -- Temps de remplissage (n ticks par unité)
    self.itemStart = itemCurrent
    self.itemTarget = itemCurrent + take

    self:setActionAnim("Pour")
    self.sound = self.character:playSound("PourLiquid")
end

function ISTransferEssence:stop()
    if self.sound and self.character then
        self.character:stopOrTriggerSound(self.sound)
    end
    if self.target then
        self.target:setJobDelta(0.0)
    end
    ISBaseTimedAction.stop(self)
end

function ISTransferEssence:perform()
    if self.sound and self.character then
        self.character:stopOrTriggerSound(self.sound)
    end
    self.target:setJobDelta(0.0)

    local itemCurrent = math.floor(self.target:getUsedDelta() / self.target:getUseDelta() + 0.001)
    if self.itemTarget > itemCurrent then
        local diff = self.itemTarget - itemCurrent
        self.target:setUsedDelta(self.itemTarget * self.target:getUseDelta())

        local sourceUses = self.source:getDrainableUsesInt()
        self.source:setUsedDelta((sourceUses - diff) * self.source:getUseDelta())
    end

    ISBaseTimedAction.perform(self)
end

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

local function predicateEmptyPetrol(item)
    return item:hasTag("EmptyPetrol") or item:getType() == "EmptyPetrolCan"
end

local function predicatePetrolNotFull(item)
    if not item:hasTag("Petrol") then return false end
    if not instanceof(item, "DrainableComboItem") then return false end

    local current = item:getDrainableUsesInt() or 0
    local max = math.floor(1 / item:getUseDelta() + 0.001)

    return current < max
end

-- ================================================
-- Context Menu avec Sous-Menu
-- ================================================

-- Transvaser vers UN conteneur spécifique
local function onTransferToOne(playerObj, essenceBrute, container)
    if predicateEmptyPetrol(container) then
        ISTimedActionQueue.add(ISTransferEssence:new(playerObj, essenceBrute, nil, true, container))
    elseif predicatePetrolNotFull(container) then
        ISTimedActionQueue.add(ISTransferEssence:new(playerObj, essenceBrute, container, false, nil))
    end
end

-- Transvaser vers TOUS les conteneurs
local function onTransferToAll(playerObj, essenceBrute, containerList)
    for _, container in ipairs(containerList) do
        if predicateEmptyPetrol(container) then
            ISTimedActionQueue.add(ISTransferEssence:new(playerObj, essenceBrute, nil, true, container))
        elseif predicatePetrolNotFull(container) then
            ISTimedActionQueue.add(ISTransferEssence:new(playerObj, essenceBrute, container, false, nil))
        end
    end
end

local function createTransferContextMenu(player, context, worldobjects, essenceBrute)
    if essenceBrute:getFullType() ~= "DistillationMod.PotDistillationCooked" then
        return
    end

    local playerObj = getSpecificPlayer(player)
    local sourceUses = essenceBrute:getDrainableUsesInt() or 0

    if sourceUses <= 0 then return end

    -- Collecte tous les conteneurs compatibles (SAUF l'essence brute elle-même)
    local containers = {}
    local inv = playerObj:getInventory()

    for i = 0, inv:getItems():size() - 1 do
        local item = inv:getItems():get(i)

        if item and item ~= essenceBrute then -- ← AJOUTÉ : Exclut la source
            if predicateEmptyPetrol(item) or predicatePetrolNotFull(item) then
                table.insert(containers, item)
            end
        end
    end

    if #containers == 0 then return end

    -- Crée l'option principale "Transvaser..."
    local mainOption = context:addOption("Transvaser...", nil, nil)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(mainOption, subMenu)

    -- Option 1 : Remplir TOUS les conteneurs
    if #containers > 1 then
        subMenu:addOption("Tous les conteneurs (" .. #containers .. ")", playerObj, onTransferToAll, essenceBrute,
            containers)
        subMenu:addOption("---", nil, nil) -- Séparateur
    end

    -- Option 2+ : Chaque conteneur individuellement
    for _, container in ipairs(containers) do
        local name = container:getDisplayName()
        local current = 0
        local max = 0

        if predicatePetrolNotFull(container) then
            current = container:getDrainableUsesInt() or 0
            max = math.floor(1 / container:getUseDelta() + 0.001)
            name = name .. " (" .. current .. "/" .. max .. ")"
        end

        subMenu:addOption(name, playerObj, onTransferToOne, essenceBrute, container)
    end
end

local function onFillInventoryObjectContextMenu(player, context, items)
    if not items or #items == 0 then return end

    local essenceBrute = nil

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

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
