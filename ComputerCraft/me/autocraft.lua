-- AutoCraft Turtle for ComputerCraft
-- Usage: craft <item_name>
-- The script runs on the main computer
-- Turtle and chests connected to the same modem network
-- The program:
--   - Searches connected chests for required materials
--   - Moves items to turtle
--   - Crafts requested item

local COMPONENT = "turtle"
local modemSide = "back"  -- side where modem is attached on the main computer
local turtleName = "left" -- adjust if turtle connected remotely or via wireless

local component = peripheral.wrap(turtleName)
local modem = peripheral.wrap(modemSide)

if not component or not modem then
  print("Turtle or modem not found, check connections")
  return
end

-- Helper: send message to turtle to craft item_name with 64 quantity max (can adjust)
local function sendCraftRequest(item)
  modem.transmit(123, 123, {cmd = "craft", item = item})
  print("Sent craft request for: " .. item)
end

-- Main program on Computer (listens for user commands and sends request)
local function main()
  modem.open(123) -- open channel
  print("Write command like: craft minecraft:iron_ingot")
  while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    
    if type(message) == "string" and message:sub(1,5) == "craft" then
      local item = message:match("^craft%s+(.+)$")
      if item then
        sendCraftRequest(item)
      else
        print("Invalid command. Use: craft <item_name>")
      end
    end
  end
end

-- Turtle side script, listening for commands from modem, pulling items and crafting

-- utility: find item count in chests on network from main computer side
local function scanChests()
  local items = {}
  for _, name in pairs(peripheral.getNames()) do
    if peripheral.hasType(name, "inventory") and name ~= turtleName then
      local inv = peripheral.wrap(name)
      local list = inv.list()
      for slot, item in pairs(list) do
        items[item.name] = (items[item.name] or 0) + item.count
      end
    end
  end
  return items
end

-- utility: pull items from chests to turtle inventory
local function pullItems(itemName, needed)
  local remain = needed
  -- iterate all inventories except turtle itself
  for _, name in pairs(peripheral.getNames()) do
    if peripheral.hasType(name, "inventory") and name ~= turtleName then
      local inv = peripheral.wrap(name)
      local list = inv.list()
      for slot, item in pairs(list) do
        if item.name == itemName and remain > 0 then
          local pullCount = math.min(item.count, remain)
          local pulled = inv.pushItems(turtleName, slot, pullCount)
          remain = remain - pulled
          if remain <= 0 then return true end
        end
      end
    end
  end
  return remain <= 0
end

-- utility: craft item (assumes items are in turtle inventory)
local function craft()
  if turtle.craft then  -- turtle.craft is in CC:Turtle 1.93+
    return turtle.craft()
  else
    print("Your turtle firmware does not support turtle.craft()")
    return false
  end
end

-- Turtle modem listener script: runs inside turtle
local function turtleListener()
  local modem = peripheral.wrap(modemSide)
  modem.open(123)
  print("Turtle modem listener started")
  
  while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    if channel == 123 and type(message) == "table" and message.cmd == "craft" then
      local item = message.item
      print("Received craft request for " .. item)
      local required = 1  -- default craft 1
      -- 1. Scan chests for required items
      local items = scanChests()
      -- 2. Pull needed items
      print("Pulling required items...")
      if pullItems(item, required) then
        -- 3. Craft the item
        print("Crafting " .. item)
        if craft() then
          print("Crafting successful!")
        else
          print("Crafting failed or not supported")
        end
      else
        print("Not enough materials for " .. item)
      end
    end
  end
end

-- Start Turtle listener in parallel (run this on turtle):
-- turtleListener()

-- Start main command listener (run on main computer):
-- main()
