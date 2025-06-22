-- Save as: simplecraft.lua
-- Usage: simplecraft <turtle_side> <item> [count]

local args = { ... }
if #args < 2 then
    print("Usage: simplecraft <turtle_side> <item> [count]")
    print("Example: simplecraft left minecraft:iron_ingot 5")
    return
end

local turtleSide = args[1]
local itemName = args[2]
local craftCount = tonumber(args[3]) or 1

-- Проверка подключения черепашки
if not peripheral.isPresent(turtleSide) or peripheral.getType(turtleSide) ~= "turtle" then
    print("Error: Invalid turtle side")
    return
end

-- Получаем интерфейс черепашки
local turtle = peripheral.wrap(turtleSide)

-- Отправляем команду крафта напрямую на черепашку
local command = string.format("turtle.craft(%d, '%s')", craftCount, itemName)
local success, response = turtle.executeCommand(command)

-- Обработка результата
if success then
    print(("Crafted %dx %s successfully!"):format(craftCount, itemName))
else
    print(("Crafting failed: %s"):format(response))
end
