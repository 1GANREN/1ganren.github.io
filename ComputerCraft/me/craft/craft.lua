-- AUTOCRAFT TURTLE v2.1 (FIXED)
-- Listens for craft requests with better item handling

local modemSide = "back" -- Modem side on turtle

-- Find modem and open channel
local modem = peripheral.find("modem")
if not modem then
    print("Turtle modem not found! Check side: "..modemSide)
    return
end

modem.open(123)
print("Turtle ready. Waiting for commands...")

-- Helper: Pull items from chests (IMPROVED)
local function pullItems(itemName, needed)
    -- 1. Check turtle's inventory first
    for slot=1,16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name == itemName then
            needed = needed - item.count
            if needed <= 0 then return true end
        end
    end
    
    -- 2. Search connected chests (WITH DEBUG)
    print("Searching chests for: "..itemName)
    local foundAny = false
    
    for _,side in pairs(peripheral.getNames()) do
        if peripheral.hasType(side, "inventory") then
            print(" - Checking inventory: "..side)
            local inv = peripheral.wrap(side)
            local size = inv.size()
            
            for slot=1,size do
                local item = inv.getItemDetail(slot)
                if item then
                    print("   Slot "..slot..": "..item.name.." x"..item.count)
                    if item.name == itemName then
                        local toPull = math.min(item.count, needed)
                        print("   FOUND! Pulling "..toPull.." from "..side)
                        turtle.pullItems(side, slot, toPull)
                        needed = needed - toPull
                        if needed <= 0 then return true end
                        foundAny = true
                    end
                end
            end
        end
    end
    
    print("Search complete. Still need: "..needed)
    return false, foundAny
end

-- Helper: Prepare crafting and execute
local function craftItem()
    -- Clear selection for crafting
    turtle.select(1)
    for i=1,16 do
        if turtle.getItemCount(i) > 0 then
            turtle.select(i)
        end
    end
    return turtle.craft()
end

-- Main listener loop
while true do
    local event, side, ch, rc, msg, dist = os.pullEvent("modem_message")
    if ch == 123 and type(msg) == "table" and msg.cmd == "craft" then
        local item = msg.item
        print("Received craft request: "..item)
        
        local success, foundItems = pullItems(item, 1)
        if success then
            print("Crafting "..item)
            if craftItem() then
                print("Crafting successful!")
            else
                print("Crafting failed - check recipe")
            end
        else
            if foundItems then
                print("Partial resources found but not enough")
            else
                print("No resources found for "..item)
            end
        end
    end
end
