-- Save as: craft.lua
-- Usage: craft <turtle_id> <item> [count]

local args = { ... }
if #args < 2 then
    print("Usage: craft <turtle_id> <item> [count]")
    print("Example: craft left minecraft:iron_ingot 5")
    return
end

local turtleID = args[1]
local itemName = args[2]
local craftCount = tonumber(args[3]) or 1

if not peripheral.isPresent(turtleID) or peripheral.getType(turtleID) ~= "turtle" then
    print("Error: Invalid turtle ID")
    return
end

-- Build craft command
local command = string.format("turtle.craft(%d, \"%s\")", craftCount, itemName)

-- Execute on turtle
local success, response = commands.exec(turtleID, command)

if success then
    print(("Successfully crafted %dx %s"):format(craftCount, itemName))
else
    print("Crafting failed! Reason: " .. tostring(response))
end
