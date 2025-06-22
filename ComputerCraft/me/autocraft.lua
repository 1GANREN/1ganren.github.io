-- Save as: autocraft.lua
-- Usage: autocraft <item> [count]
-- Example: autocraft minecraft:iron_ingot 5

local args = { ... }
local itemName = args[1]
local craftCount = tonumber(args[2]) or 1

if not itemName then
    print("Usage: autocraft <item> [count]")
    print("Example: autocraft minecraft:iron_ingot 5")
    return
end

-- Find connected turtle
local turtleID
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "turtle" then
        turtleID = name
        break
    end
end

if not turtleID then
    print("Error: No connected turtle found")
    return
end
print("Using turtle: " .. turtleID)

-- Find connected chests
local chests = {}
for _, name in ipairs(peripheral.getNames()) do
    local pType = peripheral.getType(name)
    if pType:find("chest") or pType:find("inventory") then
        table.insert(chests, {
            name = name,
            peripheral = peripheral.wrap(name)
        })
    end
end

if #chests == 0 then
    print("Error: No chests found")
    return
end

-- Get recipe from turtle
local command = string.format([[
    local recipe = turtle.getRecipe("%s")
    if not recipe then
        return false, "Recipe not found"
    end
    
    local result = {}
    for slot = 1, 9 do
        local item = recipe[slot]
        if item then
            table.insert(result, {
                name = item.name,
                count = item.count
            })
        end
    end
    
    return true, textutils.serialize(result)
]], itemName)

local success, recipeData = commands.exec(turtleID, "lua", "-e", command)

if not success then
    print("Error: " .. tostring(recipeData))
    return
end

local recipeItems = textutils.unserialize(recipeData)
if not recipeItems then
    print("Error: Failed to parse recipe data")
    return
end

if #recipeItems == 0 then
    print("Error: Empty recipe for " .. itemName)
    return
end

-- Calculate needed ingredients
local ingredients = {}
for _, item in ipairs(recipeItems) do
    ingredients[item.name] = (ingredients[item.name] or 0) + item.count * craftCount
end

-- Transfer items from chests to turtle
for item, needCount in pairs(ingredients) do
    local collected = 0
    
    while collected < needCount do
        local found = false
        
        for _, chest in ipairs(chests) do
            if collected >= needCount then break end
            
            local size = chest.peripheral.size()
            for slot = 1, size do
                local stack = chest.peripheral.getItemDetail(slot)
                if stack and stack.name == item then
                    local toTake = math.min(needCount - collected, stack.count)
                    local transferred = chest.peripheral.pushItems(
                        turtleID,
                        slot,
                        toTake
                    )
                    
                    if transferred > 0 then
                        collected = collected + transferred
                        found = true
                        print(("Transferred %dx %s from %s"):format(transferred, item, chest.name))
                        
                        if collected >= needCount then break end
                    end
                end
            end
        end
        
        if not found and collected < needCount then
            print(("Error: Not enough %s (needed: %d, found: %d)"):format(item, needCount, collected))
            return
        end
    end
end

-- Perform crafting
local craftCommand = string.format("turtle.craft(%d)", craftCount)
local craftSuccess, craftResponse = commands.exec(turtleID, craftCommand)

if craftSuccess then
    print(("Successfully crafted %dx %s"):format(craftCount, itemName))
else
    print(("Crafting failed: %s"):format(tostring(craftResponse)))
end
