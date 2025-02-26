local minZ, maxZ = nil, nil
local TempPoint = {}

local function handleInput(center)
  local rot = GetGameplayCamRot(2)
  center = handleArrowInput(center, rot.z)
  return center
end

function polySStart(name)
  local coords = GetEntityCoords(PlayerPedId())
  createdZone = PolyZone:Create({vector2(coords.x, coords.y)}, {name = tostring(name), useGrid=false})
  CreateThread(function()
    while createdZone do
      -- Have to convert the point to a vector3 prior to calling handleInput,
      -- then convert it back to vector2 afterwards
      lastPoint = createdZone.points[#createdZone.points]
      lastPoint = vector3(lastPoint.x, lastPoint.y, 0.0)
      lastPoint = handleInput(lastPoint)
      createdZone.points[#createdZone.points] = lastPoint.xy
      Wait(0)
    end
  end)
  minZ, maxZ = coords.z - 2.5, coords.z +2.5
end

function polySFinish()
  TriggerServerEvent("polyzone:printPoly",
    {name=createdZone.name, points=createdZone.points, minZ=minZ, maxZ=maxZ})
end

RegisterNetEvent("polyzone:pzadd")
AddEventHandler("polyzone:pzadd", function(coords)
  if createdZone == nil or createdZoneType ~= 'polyS' then
    return
  end

  if (coords.z > maxZ) then
    maxZ = coords.z
  end

  if (coords.z < minZ) then
    minZ = coords.z
  end

  createdZone.points[#createdZone.points + 1] = vector2(coords.x, coords.y)
end)

RegisterNetEvent("polyzone:pzundo")
AddEventHandler("polyzone:pzundo", function()
  if createdZone == nil or createdZoneType ~= 'polyS' then
    return
  end

  createdZone.points[#createdZone.points] = nil
  if #createdZone.points == 0 then
    TriggerEvent("polyzone:pzcancel")
  end
end)

RegisterCommand("createPOLYS", function()
    if createdZone == nil or createdZoneType ~= 'polyS' then
      return
    end
    lib.showTextUI("Press [E] to add point \nPress [Esc] to cancel.")

    Citizen.CreateThread(function()
        while true do
            DisablePlayerFiring(PlayerId(), true)

            local hit, _, coords = lib.raycast.cam(1|16)

            if hit then
                DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.2, 0.2, 0.2, 255, 42, 24, 100, false, false, 0, true, false, false, false)
            end

            if hit and IsControlJustPressed(0, 38) then -- 38 = "E"
                TriggerEvent('polyzone:pzadd', coords)
                print("Point added!")
                Citizen.Wait(500)
            end

            if IsControlJustPressed(0, 322) then -- 322 = "Esc"
                lib.hideTextUI()
                print("canceled.")
                break
            end

            Citizen.Wait(0)
        end
    end)
end)