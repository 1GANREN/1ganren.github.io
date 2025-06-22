-- AUTOCRAFT TURTLE v2.0
-- Listens for craft requests and executes them

local modemSide = "back" -- Modem side on turtle

-- Find modem and open channel
local modem = peripheral.find("modem")
if not modem then
    print("Turtle modem not found! Check side: "..modemSide)
    return
end

modem.open(123)
print("Turtle ready. Waiting for commands...")

-- Helper: Pull items from chests
local function pullItems(itemName, needed)
    -- Check turtle's inventory first
    for slot=1,16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name == itemName then
            needed = needed - item.count
            if needed <= 0 then return true end
        end
    end
    
    -- Search connected chests
    for _,side in pairs(peripheral.getNames()) do
        if peripheral.hasType(side, "inventory") then
            local inv = peripheral.wrap(side)
            for slot=1,inv.size() do
                local item = inv.getItemDetail(slot)
                if item and item.name == itemName then
                    local toPull = math.min(item.count, needed)
                    turtle.pullItems(side, slot, toPull)
                    needed = needed - toPull
                    if needed <= 0 then return true end
                end
            end
        end
    end
    return false
end

-- Helper: Prepare crafting and execute
local function craftItem()
    -- Clear selection for crafting
    for i=1,16 do
        turtle.select(i)
        if not turtle.getItemDetail() then
            break
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
        
        if pullItems(item, 1) then
            print("Crafting "..item)
            if craftItem() then
                print("Crafting successful!")
            else
                print("Crafting failed - check recipe")
            end
        else
            print("Not enough resources for "..item)
        end
    end
end
