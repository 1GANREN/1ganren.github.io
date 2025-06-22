-- AUTOCRAFT COMPUTER v2.0
-- Handles user commands and sends requests to turtle

local modemSide = "back" -- Modem side on computer

-- Find modem and open channel
local modem = peripheral.find("modem")
if not modem then
    print("Modem not found! Check side: " .. modemSide)
    return
end

modem.open(123)
print("Autocraft system ready")
print("Command: craft <item>")

-- Main command loop
while true do
    write("> ")
    local command = read()
    if command:sub(1,5) == "craft" then
        local item = command:match("^craft%s+(.+)")
        if item then
            modem.transmit(123, 123, {cmd="craft", item=item})
            print("Request sent: "..item)
        else
            print("Error: Specify item name")
        end
    end
end
