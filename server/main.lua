local KGCore = exports['kg-core']:GetCoreObject()

KGCore.Functions.CreateCallback('kg-weed:server:getBuildingPlants', function(_, cb, building)
    local buildingPlants = {}

    MySQL.query('SELECT * FROM house_plants WHERE building = ?', { building }, function(plants)
        for i = 1, #plants, 1 do
            buildingPlants[#buildingPlants + 1] = plants[i]
        end

        cb(buildingPlants)
    end)
end)

RegisterNetEvent('kg-weed:server:placePlant', function(coords, sort, currentHouse)
    local random = math.random(1, 2)
    local gender = (random == 1) and 'man' or 'woman'

    MySQL.insert('INSERT INTO house_plants (building, coords, gender, sort, plantid) VALUES (?, ?, ?, ?, ?)',
        { currentHouse, coords, gender, sort, math.random(111111, 999999) })
    TriggerClientEvent('kg-weed:client:refreshHousePlants', -1, currentHouse)
end)

RegisterNetEvent('kg-weed:server:removeDeathPlant', function(building, plantId)
    MySQL.query('DELETE FROM house_plants WHERE plantid = ? AND building = ?', { plantId, building })
    TriggerClientEvent('kg-weed:client:refreshHousePlants', -1, building)
end)

RegisterServerEvent('kg-weed:server:removeSeed', function(itemslot, seed)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    exports['kg-inventory']:RemoveItem(src, seed, 1, itemslot, 'kg-weed:server:removeSeed')
end)

RegisterNetEvent('kg-weed:server:harvestPlant', function(house, amount, plantName, plantId)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    local weedBag = Player.Functions.GetItemByName('empty_weed_bag')
    local sndAmount = math.random(12, 16)
    if weedBag ~= nil and weedBag.amount >= sndAmount then
        if house ~= nil then
            local result = MySQL.query.await('SELECT * FROM house_plants WHERE plantid = ? AND building = ?', { plantId, house })
            if result[1] ~= nil then
                exports['kg-inventory']:AddItem(src, 'weed_' .. plantName .. '_seed', amount, false, false, 'kg-weed:server:harvestPlant')
                exports['kg-inventory']:AddItem(src, 'weed_' .. plantName, sndAmount, false, false, 'kg-weed:server:harvestPlant')
                exports['kg-inventory']:RemoveItem(src, 'empty_weed_bag', sndAmount, false, 'kg-weed:server:harvestPlant')
                MySQL.query('DELETE FROM house_plants WHERE plantid = ? AND building = ?', { plantId, house })
                TriggerClientEvent('KGCore:Notify', src, Lang:t('text.the_plant_has_been_harvested'), 'success', 3500)
                TriggerClientEvent('kg-weed:client:refreshHousePlants', -1, house)
            else
                TriggerClientEvent('KGCore:Notify', src, Lang:t('error.this_plant_no_longer_exists'), 'error', 3500)
            end
        else
            TriggerClientEvent('KGCore:Notify', src, Lang:t('error.house_not_found'), 'error', 3500)
        end
    else
        TriggerClientEvent('KGCore:Notify', src, Lang:t('error.you_dont_have_enough_resealable_bags'), 'error', 3500)
    end
end)

RegisterNetEvent('kg-weed:server:foodPlant', function(house, amount, plantName, plantId)
    local src = source
    local Player = KGCore.Functions.GetPlayer(src)
    local plantStats = MySQL.query.await('SELECT * FROM house_plants WHERE building = ? AND sort = ? AND plantid = ?',{ house, plantName, tostring(plantId) })
    local updatedFood = math.min(100, plantStats[1].food + amount)
    TriggerClientEvent('KGCore:Notify', src, KGWeed.Plants[plantName]['label'] ..' | Nutrition: ' .. plantStats[1].food .. '% + ' .. updatedFood - plantStats[1].food .. '% (' ..updatedFood .. '%)', 'success', 3500)
    MySQL.update('UPDATE house_plants SET food = ? WHERE building = ? AND plantid = ?',{ updatedFood, house, plantId })
    exports['kg-inventory']:RemoveItem(src, 'weed_nutrition', 1, false, 'kg-weed:server:foodPlant')
    TriggerClientEvent('kg-weed:client:refreshHousePlants', -1, house)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for plantName, _ in pairs(KGWeed.Plants) do
        KGCore.Functions.CreateUseableItem('weed_' .. plantName .. '_seed', function(source, item)
            TriggerClientEvent('kg-weed:client:placePlant', source, plantName, item)
        end)
    end
    KGCore.Functions.CreateUseableItem('weed_nutrition', function(source, item)
        TriggerClientEvent('kg-weed:client:foodPlant', source, item)
    end)
end)

CreateThread(function()
    local healthTick = false
    while true do
        local housePlants = MySQL.query.await('SELECT * FROM house_plants', {})
        for k, plant in pairs(housePlants) do
            if housePlants[k].health > 50 then
                local Grow = math.random(KGWeed.Progress.min, KGWeed.Progress.max)
                if housePlants[k].progress + Grow < 100 then
                    MySQL.update('UPDATE house_plants SET progress = ? WHERE plantid = ?',
                        { (housePlants[k].progress + Grow), housePlants[k].plantid })
                elseif housePlants[k].progress + Grow >= 100 then
                    if housePlants[k].stage ~= KGWeed.Plants[housePlants[k].sort]['highestStage'] then
                        MySQL.update('UPDATE house_plants SET stage = ?, progress = 0 WHERE plantid = ?',
                            { housePlants[k].stage + 1, housePlants[k].plantid })
                    end
                end
            end
            if healthTick then
                local plantFood = math.max(0, plant.food - KGWeed.FoodUsage)
                local plantHealth = (plantFood >= 50) and math.min(100, plant.health + 1) or math.max(0, plant.health - 1)

                MySQL.update('UPDATE house_plants SET food = ?, health = ? WHERE plantid = ?',
                    { plantFood, plantHealth, plant.plantid })
            end
        end

        TriggerClientEvent('kg-weed:client:refreshHousePlants', -1)
        healthTick = not healthTick
        Wait((60 * 1000) * KGWeed.GrowthTick)
    end
end)
