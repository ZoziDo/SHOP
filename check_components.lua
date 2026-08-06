local component = require("component")
local computer = require("computer")

local requiredMethods = {
    pim = {"getInventoryName", "getStackInSlot", "getAllStacks", "pushItem"},
    me_interface = {"getAvailableItems", "getItemDetail", "exportItem"},
    openperipheral_selector = {"setSlot"},
    modem = {"open", "isOpen", "send"}
}

print("=== OpenComputers: найденные компоненты ===")
local found = {}
for address, componentType in component.list() do
    found[componentType] = address
    print(componentType .. " = " .. address)
end

print("")
print("Адрес компьютера = " .. computer.address())
if component.isAvailable("modem") then
    print("Адрес модема = " .. component.modem.address)
else
    print("Адрес модема = НЕ НАЙДЕН")
end

print("")
print("=== Проверка методов магазина ===")
for componentType, methods in pairs(requiredMethods) do
    local address = found[componentType]
    if not address then
        print("[НЕТ] " .. componentType)
    else
        local available = component.methods(address) or {}
        for _, methodName in ipairs(methods) do
            if available[methodName] then
                print("[OK]  " .. componentType .. "." .. methodName)
            else
                print("[НЕТ] " .. componentType .. "." .. methodName)
            end
        end
    end
end

print("")
print("Терминалу нужны: gpu, screen, modem, pim, me_interface, openperipheral_selector")
print("Серверу нужен: modem")
