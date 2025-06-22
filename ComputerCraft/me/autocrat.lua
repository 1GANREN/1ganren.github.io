-- Save as: autocraft.lua
-- Usage: autocraft <item> [count]

local args = { ... }
local itemName = args[1]
local craftCount = tonumber(args[2]) or 1

if not itemName then
    print("Usage: autocraft <item> [count]")
    print("Example: autocraft minecraft:iron_ingot 3")
    return
end

-- Find connected turtle
local turtleNames = {}
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "turtle" then
        table.insert(turtleNames, name)
    end
end

if #turtleNames == 0 then
    print("Error: No turtles found")
    return
end

local turtle = peripheral.wrap(turtleNames[1])
print("Using turtle: " .. turtleNames[1])

-- Get crafting recipe
local recipe = turtle.getRecipe(itemName)
if not recipe then
    print("Error: Recipe for " .. itemName .. " not found")
    return
end

-- Group ingredients
local ingredients = {}
for slot = 1, 9 do
    local item = recipe[slot]
    if item then
        ingredients[item.name] = (ingredients[item.name] or 0) + item.count * craftCount
    end
end

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
                        turtleNames[1],
                        slot,
                        toTake
                    )
                    
                    if transferred > 0 then
                        collected = collected + transferred
                        found = true
                        print("Transferred " .. transferred .. "x " .. item .. " from " .. chest.name)
                        
                        if collected >= needCount then break end
                    end
                end
            end
        end
        
        if not found and collected < needCount then
            print("Error: Not enough " .. item)
            print("Needed: " .. needCount .. ", Found: " .. collected)
            return
        end
    end
end

-- Perform crafting
if turtle.craft(craftCount) then
    print("Successfully crafted " .. craftCount .. "x " .. itemName)
else
    print("Crafting failed! Possible reasons:")
    print("1. Turtle inventory full")
    print("2. Incorrect items in crafting grid")
    print("3. No crafting table available")
end
