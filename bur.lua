-- Turtle Mining Program v1.2
-- Simple digging and quarry mining utility

-- Display welcome message
term.clear()
term.setCursorPos(1,1)
print("==== Turtle Miner ====")

-- Main menu function
local function showMenu()
    print("\nSelect mode:")
    print("1 - Dig straight tunnel")
    print("2 - Dig 6x14 quarry")
    print("3 - Check fuel level")
    print("0 - Exit")
    print("-------------------")
    write("Enter choice: ")
    return tonumber(read())
end

-- Fuel check function
local function checkFuel(needed)
    local fuel = turtle.getFuelLevel()
    if fuel < needed then
        print("Warning: Low fuel! ("..fuel..")")
        print("Refuel with turtle.refuel()")
        return false
    end
    return true
end

-- Tunnel digging function
local function digTunnel()
    -- Get parameters
    print("\nTunnel Digging Mode")
    write("Enter tunnel length: ")
    local length = tonumber(read()) or 0
    
    write("Dig up/down? (y/n): ")
    local digVertical = read():lower() == "y"
    
    -- Verify parameters
    if length <= 0 then
        print("Invalid length")
        return
    end
    
    if not checkFuel(length * 2) then return end
    
    -- Dig tunnel
    print("Digging tunnel...")
    for i = 1, length do
        -- Dig forward
        while turtle.detect() do
            turtle.dig()
        end
        
        -- Dig vertical if needed
        if digVertical then
            while turtle.detectUp() do
                turtle.digUp()
            end
            while turtle.detectDown() do
                turtle.digDown()
            end
        end
        
        -- Move forward
        turtle.forward()
    end
    
    print("Tunnel complete!")
end

-- Quarry digging function
local function digQuarry()
    print("\nQuarry Digging Mode")
    
    -- Get parameters
    write("Enter length (default 14): ")
    local length = tonumber(read()) or 14
    
    write("Enter width (default 6): ")
    local width = tonumber(read()) or 6
    
    write("Enter depth: ")
    local depth = tonumber(read()) or 1
    
    -- Verify parameters
    if length <= 0 or width <= 0 or depth <= 0 then
        print("Invalid dimensions")
        return
    end
    
    local estimatedFuel = length * width * depth * 3
    if not checkFuel(estimatedFuel) then return end
    
    -- Dig quarry
    print("Digging quarry "..width.."x"..length.."x"..depth)
    
    for d = 1, depth do
        print("Layer "..d.." of "..depth)
        
        for w = 1, width do
            -- Dig row
            for l = 1, length-1 do
                turtle.digDown()
                if turtle.detect() then turtle.dig() end
                turtle.forward()
            end
            turtle.digDown()
            
            -- Turn for next row
            if w < width then
                if w % 2 == 1 then
                    turtle.turnRight()
                    if turtle.detect() then turtle.dig() end
                    turtle.forward()
                    turtle.turnRight()
                else
                    turtle.turnLeft()
                    if turtle.detect() then turtle.dig() end
                    turtle.forward()
                    turtle.turnLeft()
                end
            end
        end
        
        -- Prepare for next layer
        if d < depth then
            turtle.turnLeft()
            turtle.turnLeft()
            turtle.digDown()
            turtle.down()
        end
    end
    
    print("Quarry complete!")
end

-- Main program loop
while true do
    local choice = showMenu()
    
    if choice == 0 then
        print("Exiting program...")
        break
    elseif choice == 1 then
        digTunnel()
    elseif choice == 2 then
        digQuarry()
    elseif choice == 3 then
        print("\nCurrent fuel: "..turtle.getFuelLevel())
    else
        print("Invalid choice")
    end
    
    sleep(1)
end
