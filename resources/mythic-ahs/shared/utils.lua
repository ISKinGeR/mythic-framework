function DoseHeHaveAccessToThisDoor(CharacterID, HouseName)
    local key = string.format("AHS:Properties:%s", CharacterID)
    local propertyNames = GlobalState[key]

    if type(propertyNames) == "table" then
        if propertyNames[HouseName] ~= nil then
            return true
        else
            for _, name in ipairs(propertyNames) do
                if name == HouseName then
                    return true
                end
            end
        end
    end
    return false
end

function kprint(...)
    if _DebugEnabled then
        local args = {...}
        local messageToPrint = "[DEBUG] " .. table.concat(args, "   ")
        print(messageToPrint)
    end
end
