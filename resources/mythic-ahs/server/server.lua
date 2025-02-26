------------------------ Main ------------------------

AddEventHandler("KR:Shared:DependencyUpdate", RetrieveComponents)
function RetrieveComponents()
	Database = exports["mythic-base"]:FetchComponent("Database")
	Logger = exports["mythic-base"]:FetchComponent("Logger")
	Callbacks = exports["mythic-base"]:FetchComponent("Callbacks")
	Execute = exports["mythic-base"]:FetchComponent("Execute")
    Inventory = exports["mythic-base"]:FetchComponent("Inventory")
    Chat = exports["mythic-base"]:FetchComponent("Chat")
    Fetch = exports['mythic-base']:FetchComponent('Fetch')
    Middleware = exports["mythic-base"]:FetchComponent("Middleware")

end

AddEventHandler("Core:Shared:Ready", function()
	exports["mythic-base"]:RequestDependencies("KR", {
		"Database",
		"Logger",
		"Callbacks",
        "Execute",
		"Inventory",
        "Chat",
        'Fetch',
        'Middleware'
	}, function(error)
		if #error > 0 then
            exports["mythic-base"]:FetchComponent("Logger"):Critical("KR", "Failed To Load All Dependencies")
			return
		end
        RetrieveComponents()
        kprint("WE Are Ready!")
        AddedCustomEntitys()
        LoadHouseStashes()
        LoadHousePolyZones()
        Middleware:Add("Characters:GetSpawnPoints", function(source, charId)        
            local p = promise.new()
            Database.Game:find({
                collection = "properties",
                query = {
                    [string.format("keys.%s", charId)] = { ["$exists"] = true },
                    foreclosed = { ["$ne"] = true },
                    type = { ["$nin"] = { "container", "warehouse" } }
                },
            }, function(success, results)        
                if not success or not results or #results == 0 then
                    p:resolve({})
                    return
                end
                local spawns = {}
                local HousesNames = {}
                for i, property in ipairs(results) do
                    if property.location and property.location.front and property.type == "real" then
                        kprint("Adding spawn for property:", property.label)
                        table.insert(HousesNames, property.label)
                        table.insert(spawns, {
                            id = property._id,
                            label = property.label,
                            location = {
                                x = property.location.front.x, 
                                y = property.location.front.y,
                                z = property.location.front.z,
                                h = property.location.front.h,
                            },
                            icon = "house",
                            event = "Characters:GlobalSpawn",
                        })
                    else
                        kprint("Property missing front location:", property.label)
                    end
                end
                kprint("Spawns",json.encode(spawns))
                GlobalState[string.format("AHS:Properties:%s", charId)] = HousesNames
                p:resolve(spawns)
            end)
            return Citizen.Await(p)
        end, 6)
        

        Middleware:Add('Characters:Spawning', function(source)
            ImNewIdotNotPlayer(source) -- just kidding <3
            LoadHousePolyZones(source)
        end)

        Middleware:Add("Characters:Logout", function(source)
            local char = Fetch:Source(source):GetData("Character")
            if char ~= nil then
                GlobalState[string.format("AHS:Properties:%s", char:GetData("ID"))] = nil
            end
        end)

        Chat:RegisterAdminCommand("addRealStash", function(source, args, rawCommand)
            local typee = tonumber(args[1])
            if typee == 1 then
                local id = args[2]
                local coords = GetEntityCoords(GetPlayerPed(source))
                local heading = GetEntityHeading(GetPlayerPed(source))

                AddRealStash(id, coords, heading, typee)
                Execute:Client(source, "Notification", "Success", "Real stash added successfully!")
                Wait(10000)
                Execute:Client(source, "Notification", "Success", "Real stashs:".. #_RealHouseList)
            elseif typee == 2 then
                local id = args[2]
                local coords = GetEntityCoords(GetPlayerPed(source))
                local heading = GetEntityHeading(GetPlayerPed(source))
                AddRealStash(id, coords, heading, typee)
                Execute:Client(source, "Notification", "Success", "Real stash added successfully!")
                Wait(10000)
                Execute:Client(source, "Notification", "Success", "Real stashs:".. #_RealHouseList)
            end
        end, {
            help = "Add a real stash with a specified ID",
            params = {
                {
                    name = "1/2",
                    help = "1 = polybox, 2 = targeting",
                },
                {
                    name = "House ID",
                    help = "ID of the house",
                },
            },
        }, 2)

        -- Callbacks:RegisterServerCallback('CheckPermForHouse', function(source, HouseLabel, cb)
        --     local player = Fetch:Source(source)
        --     if player then
        --         local char = player:GetData('Character')
        --         if char then
        --             local charID = char:GetData("ID")
        --             local havePerm = DoseHeHaveAccessToThisDoor(charID, HouseLabel)
        --             cb(havePerm)
        --         end
        --     end
        -- end)

    end)
end)

------------------------ Functions ------------------------

function vector3ToTable(v)
    return { x = v.x, y = v.y, z = v.z }
end

function tableToVector3(t)
    return vector3(t.x, t.y, t.z)
end

function saveToDatabase()
    kprint("Saving Real House and Custom Entity Data...")
    local realHouseListConverted = {}
    for _, house in pairs(_RealHouseList) do
        local houseCopy = {
            id = house.id,
            type = house.type,
            coords = vector3ToTable(house.coords),
            width = house.width,
            length = house.length,
            options = house.options,
            data = house.data
        }
        table.insert(realHouseListConverted, houseCopy)
    end

    Database.Game:findOneAndUpdate({
        collection = _collection,
        query = { config_id = "_RealHouseList" },
        update = {
            ["$set"] = { 
                config_id = "_RealHouseList", 
                real_house_list = realHouseListConverted
            }
        },
        options = {
            upsert = true,
        }
    }, function(success, result)
        if success then
            kprint("Successfully saved or updated Real House data.")

            Database.Game:findOneAndUpdate({
                collection = _collection,
                query = { config_id = "_CustomEntityList" },
                update = {
                    ["$set"] = { 
                        config_id = "_CustomEntityList", 
                        custom_entity_list = _CustomEntitysList
                    }
                },
                options = {
                    upsert = true,
                }
            }, function(success, result)
                if success then
                    kprint("Successfully saved or updated Custom Entity data.")
                else
                    kprint("Failed to save or update Custom Entity data.")
                end
            end)
        else
            kprint("Failed to save or update Real House data.")
        end
    end)
    Wait(2500)
    AddedCustomEntitys()
    LoadHouseStashes()
end

function AddRealStash(id, coords, heading, typee)
    if typee == 1 then
        for _, house in ipairs(_RealHouseList) do
            if house.id == id then
                kprint("House ID already exists!")
                return
            end
        end
        local newHouse = {
            id = id,
            type = "box",
            coords = vector3(coords.x, coords.y, coords.z),
            width = 2,
            length = 2,
            options = {
                heading = heading,
                minZ = coords.z - 1,
                maxZ = coords.z + 1,
            },
            data = {
                inventory = {
                    invType = (_CustomEntitysList[#_CustomEntitysList] and _CustomEntitysList[#_CustomEntitysList].id + 1) or 92220,
                    owner = id .. "-Storage",
                }
            }
        }
        table.insert(_RealHouseList, newHouse)
        local newEntity = {
            id = newHouse.data.inventory.invType,
            slots = 96,
            capacity = 1200,
            name = id .. " Stash",
            restriction = {
                IsOwnedHouse = { id = id }
            }
        }
        table.insert(_CustomEntitysList, newEntity)
        saveToDatabase()
        kprint("Added Real House Stash with ID: " .. id)
    elseif typee == 2 then
        for _, house in ipairs(_RealHouseList) do
            if house.id == id then
                kprint("House ID already exists!")
                return
            end
        end
        local newHouse = {
            id = id,
            coords = vector3(coords.x, coords.y, coords.z),
            width = 1,
            length = 1,
            options = {
                heading = heading,
                minZ = coords.z - 1,
                maxZ = coords.z + 0.5,
            },
            data = {
                inventory = {
                    invType = (_CustomEntitysList[#_CustomEntitysList] and _CustomEntitysList[#_CustomEntitysList].id + 1) or 92220,
                    owner = id .. "-Storage",
                }
            }
        }
        table.insert(_RealHouseList, newHouse)
        local newEntity = {
            id = newHouse.data.inventory.invType,
            slots = 96,
            capacity = 1200,
            name = id .. " Stash",
            restriction = {
                IsOwnedHouse = { id = id }
            }
        }
        table.insert(_CustomEntitysList, newEntity)
        saveToDatabase()
        kprint("Added Real House Stash with ID: " .. id)
    end
end

function DeleteRealStash(id)
    for i = #_RealHouseList, 1, -1 do
        if _RealHouseList[i].id == id then
            table.remove(_RealHouseList, i)
            break
        end
    end
    for i = #_CustomEntitysList, 1, -1 do
        if _CustomEntitysList[i].restriction.IsOwnedHouse.id == id then
            table.remove(_CustomEntitysList, i)
            break
        end
    end
    saveToDatabase()
    kprint("Deleted Real House Stash with ID: " .. id)
end

function AddedCustomEntitys()
    Database.Game:find({
        collection = _collection,
        query = { config_id = "_CustomEntityList" }
    }, function(success, result)
        if success and result and #result > 0 and result[1].custom_entity_list then
            _CustomEntitysList = result[1].custom_entity_list
            local count = 0
            local total = #_CustomEntitysList
            for _, customEntity in ipairs(_CustomEntitysList) do
                local houseId = customEntity.restriction.IsOwnedHouse.id
                Database.Game:find({
                    collection = "properties",
                    query = { label = houseId }
                }, function(success, propertyResult)
                    if success and propertyResult and #propertyResult > 0 then
                        local storageLevel = propertyResult[1].upgrades and propertyResult[1].upgrades.storage
                        local storageData = (storageLevel and _real[storageLevel]) or _real[1]
                        customEntity.slots = storageData.slots
                        customEntity.capacity = storageData.capacity
                    end
                    count = count + 1
                    if count == total then
                        TriggerEvent("inventory:addMoreEntityTypes", _CustomEntitysList)
                    end
                end)
            end
        end
    end)
end

function LoadHouseStashes()
    Database.Game:find({
        collection = _collection,
        query = { config_id = "_RealHouseList" }
    }, function(success, result)
        if success and result and #result > 0 and result[1].real_house_list then
            _RealHouseList = {}
            _TRealHouseList = {}
    
            for _, storage in ipairs(result[1].real_house_list) do
                local storageCopy = {
                    id = storage.id,
                    type = storage.type or false,
                    coords = tableToVector3(storage.coords),
                    width = storage.width,
                    length = storage.length,
                    options = storage.options,
                    data = storage.data
                }
  
                if storageCopy.type then
                    table.insert(_RealHouseList, storageCopy)
                else
                    table.insert(_TRealHouseList, storageCopy)
                end
            end

            for _, storage in ipairs(_RealHouseList) do
                Inventory.Poly:Create(storage)
            end
            TriggerClientEvent("AHS:Client:CreatePoly", -1, _TRealHouseList)
    
            kprint("Done Loading " .. #_RealHouseList .. " stashes!")
    
            if _DebugEnabled then
                TriggerClientEvent("receiveRealHouseList", -1, _RealHouseList, _TRealHouseList)
            end
        else
            kprint("No real house list found in the database.")
            kprint("Database result:", json.encode(result))
        end
    end)
end

function LoadHousePolyZones(source)
    if _RPolyzones and #_RPolyzones > 0 and source then
        TriggerClientEvent("AHS:Client:CreateFunPoly", source, _RPolyzones)
    elseif _RPolyzones and #_RPolyzones > 0 then
        TriggerClientEvent("AHS:Client:CreateFunPoly", -1, _RPolyzones)
    end
end

function ImNewIdotNotPlayer(source)
    TriggerClientEvent("AHS:Client:CreatePoly", source, _TRealHouseList)
    if _DebugEnabled then
        TriggerClientEvent("receiveRealHouseList", source, _RealHouseList, _TRealHouseList)
    end
end

------------------------ Exports ------------------------

exports('CheckPermForHouse', function(SID, HouseLabel)
    local char = Fetch:SID(SID):GetData("Character")
    local charID = char:GetData("ID")
    local havePerm = DoseHeHaveAccessToThisDoor(charID, HouseLabel)
    return havePerm
end)
------------------------ Debug stuff ------------------------

-- RegisterCommand("consoleAdd", function(source, args, rawCommand)
--     if source == 0 then
--         local id = args[1]
--         if not id then
--             kprint("Usage: /consoleAdd ID")
--             return
--         end
--         local coords = vec3(-74.380, -820.848, 326.175)
--         local heading = 138.32
--         AddRealStash(id, coords, heading)
--     end
-- end, false)

RegisterCommand("consoleDel", function(source, args, rawCommand)
    if source == 0 then
        local id = args[1]
        if not id then
            kprint("Usage: /consoleDel ID")
            return
        end
        DeleteRealStash(id)
    end
end, false)
