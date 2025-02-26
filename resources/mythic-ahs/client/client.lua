local isDebuggingHouses = false
local debugHandles = {}
local _HouseList = {}

AddEventHandler('KR:Shared:DependencyUpdate', RetrieveComponents)
function RetrieveComponents()
    Callbacks = exports['mythic-base']:FetchComponent('Callbacks')
    Logger = exports['mythic-base']:FetchComponent('Logger')
    Notification = exports['mythic-base']:FetchComponent('Notification')
    Inventory = exports["mythic-base"]:FetchComponent("Inventory")
    Targeting = exports["mythic-base"]:FetchComponent("Targeting")
    Polyzone = exports["mythic-base"]:FetchComponent("Polyzone")
end

AddEventHandler('Core:Shared:Ready', function()
    exports['mythic-base']:RequestDependencies('KR', {
        'Callbacks',
        'Logger',
        'Notification',
        "Inventory",
        "Targeting",
        "Polyzone"
    }, function(error)  
        if #error > 0 then
            exports["mythic-base"]:FetchComponent("Logger"):Critical("KR", "Failed To Load All Dependencies")
            return
        end
        RetrieveComponents()

    end)
end)

RegisterNetEvent("AHS:Client:CreateFunPoly", function(polys)
    kprint(json.encode(polys))
    while Polyzone == nil do 
        Wait(123) 
    end
    for i, polyData in ipairs(polys) do
        local polygon = polyData[1]
        local properties = polyData[2]

        if polygon and properties then
            local zoneName = string.format("AHS:HOUSE:%s:%d", properties.name, i)
            Polyzone.Create:Poly(zoneName, polygon, {
                minZ = properties.minZ,
                maxZ = properties.maxZ
            })
        end
    end
end)

local function extractHouseId(zoneId)
    if string.sub(zoneId, 1, 10) == "AHS:HOUSE:" then
        return string.match(zoneId, "AHS:HOUSE:([^:]+)")
    end
    return nil
end

AddEventHandler('Polyzone:Enter', function(id, point, insideZone, data)
    if string.sub(id, 1, 10) == "AHS:HOUSE:" then
        local houseId = extractHouseId(id)
        if houseId then
            Callbacks:ServerCallback("AHS:InHousePoly", houseId, function(state)
                if state then
                    kprint("Entered:", houseId)
                end
            end)
        end
    end
end)

AddEventHandler('Polyzone:Exit', function(id, point, insideZone, data)
    if string.sub(id, 1, 10) == "AHS:HOUSE:" then
        local houseId = extractHouseId(id)
        if houseId then
            kprint("Leaved:", houseId)
            TriggerEvent("AHS:OutHousePoly")
        end
    end
end)

RegisterNetEvent("AHS:Client:CreatePoly", function(stashes)
    for k, v in ipairs(stashes) do
        Targeting.Zones:AddBox(v.id, "box-archive", v.coords, v.width, v.length, v.options, {
            {
                icon = "box-archive",
                text = "Open Stash",
                event = "OpenRealStash",
                data = v,
                isEnabled = function()
                    return DoseHeHaveAccessToThisDoor(LocalPlayer.state.Character:GetData("ID"),v.id)
                end,                
            },
        }, 2.0, true)
    end
end)

RegisterNetEvent("OpenRealStash", function(data)
    kprint("Inventory Data: " .. json.encode(data.menu[1].data.data.inventory))
    Inventory.Dumbfuck:Open(data.menu[1].data.data.inventory)
end)

RegisterNetEvent('receiveRealHouseList', function(houseList, ThouseList)
    _HouseList = {}

    if houseList then table.move(houseList, 1, #houseList, #_HouseList + 1, _HouseList) end
    if ThouseList then table.move(ThouseList, 1, #ThouseList, #_HouseList + 1, _HouseList) end

    if _DebugEnabled then
        kprint("Ready!", #_HouseList)
    end
end)

function drawRectangle(coords, width, length, height, color)
    local halfWidth = width / 2
    local halfLength = length / 2
    local corners = {
        vector3(coords.x - halfWidth, coords.y - halfLength, coords.z),
        vector3(coords.x + halfWidth, coords.y - halfLength, coords.z),
        vector3(coords.x + halfWidth, coords.y + halfLength, coords.z),
        vector3(coords.x - halfWidth, coords.y + halfLength, coords.z)
    }
    for i = 1, #corners do
        local nextCorner = corners[(i % #corners) + 1]
        DrawLine(corners[i].x, corners[i].y, corners[i].z, nextCorner.x, nextCorner.y, nextCorner.z, color.r, color.g, color.b, color.a)
    end
end

function drawBox(coords, width, length, height, color)
    local halfWidth = width / 2
    local halfLength = length / 2
    local halfHeight = height / 2
    local corners = {
        vector3(coords.x - halfWidth, coords.y - halfLength, coords.z - halfHeight),
        vector3(coords.x + halfWidth, coords.y - halfLength, coords.z - halfHeight),
        vector3(coords.x + halfWidth, coords.y + halfLength, coords.z - halfHeight),
        vector3(coords.x - halfWidth, coords.y + halfLength, coords.z - halfHeight),
        vector3(coords.x - halfWidth, coords.y - halfLength, coords.z + halfHeight),
        vector3(coords.x + halfWidth, coords.y - halfLength, coords.z + halfHeight),
        vector3(coords.x + halfWidth, coords.y + halfLength, coords.z + halfHeight),
        vector3(coords.x - halfWidth, coords.y + halfLength, coords.z + halfHeight)
    }
    local edges = {
        {1, 2}, {2, 3}, {3, 4}, {4, 1},  -- Bottom face
        {5, 6}, {6, 7}, {7, 8}, {8, 5},  -- Top face
        {1, 5}, {2, 6}, {3, 7}, {4, 8}   -- Vertical edges
    }
    for _, edge in ipairs(edges) do
        local startCorner = corners[edge[1]]
        local endCorner = corners[edge[2]]
        DrawLine(startCorner.x, startCorner.y, startCorner.z, endCorner.x, endCorner.y, endCorner.z, color.r, color.g, color.b, color.a)
    end
end

function startShapeDebugDrawing()
    Citizen.CreateThread(function()
        while isDebuggingShapes do
            for _, house in ipairs(_HouseList) do
                local coords = vector3(house.coords.x, house.coords.y, house.coords.z)
                local width = house.width
                local length = house.length
                local height = house.options.maxZ - house.options.minZ
                local color = {r = 0, g = 255, b = 0, a = 255}

                drawBox(coords, width, length, height, color)
            end
            Citizen.Wait(0)
        end
    end)
end

function stopShapeDebugDrawing()
    debugHandles = {}
end

RegisterCommand("debugShapes", function()
    if _DebugEnabled then
        isDebuggingShapes = not isDebuggingShapes
        if isDebuggingShapes then
            kprint("Debug mode for shapes turned on.")
            startShapeDebugDrawing()
        else
            kprint("Debug mode for shapes turned off.")
            stopShapeDebugDrawing()
        end
    end
end, false)

exports('CheckPermForHouseClient', function(CharacterID, HouseLabel)
    local havePerm = DoseHeHaveAccessToThisDoor(CharacterID, HouseLabel)
    return havePerm
end)
