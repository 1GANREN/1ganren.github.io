-- recommend each chest only touching at most 1 modem
-- recommend flat wired modem for computer
term.clear()
print("welcome ccME")
sleep(3)
term.clear()
-- specify name of dump chest and pickup chest (all other chests connected to modem network will be used as storage)
local DUMP_CHEST_NAME = "minecraft:chest_2"
local PICKUP_CHEST_NAME = "minecraft:chest_3"

local TURTLE_NAME = "turtle_0"  

local tArgs = {...}
local width, height = term.getSize()


if #tArgs > 0 then
  if tArgs[1] == "auto" then
    if #tArgs < 2 then
      print("Usage: auto <item_name>")
      return
    end
    
    
    local function startup()
      term.clear()
      term.setCursorPos(1,1)
      print("Initializing system...")
      
      -- helper functions --
      function all(tbl)
        local prev_k = nil
        return function()
          local k,v = next(tbl, prev_k)
          prev_k = k
          return v
        end
      end
      
      function inc_tbl(tbl, key, val)
        assert(key, "key cannot be false or nil")
        val = val or 1
        if not tbl[key] then
          tbl[key] = 0
        end
        tbl[key] = tbl[key] + val
      end
      
      local function beginsWith(string, beginning)
        return string:sub(1,#beginning) == beginning
      end
      
      function forEach(tbl, func)
        for val in all(tbl) do
          func(val)
        end
      end
      
      -- silo singleton code --
      silo = {
        dict = {},
        chest_names = {},
        dump_chest = DUMP_CHEST_NAME,
        pickup_chest = PICKUP_CHEST_NAME,
      }
      
      -- scan through all connected chests and add to table
      function silo.find_chests()
        silo.chest_names = {}
        for _, name in ipairs(peripheral.getNames()) do
          if beginsWith(name, "minecraft:chest") and name ~= silo.dump_chest and name ~= silo.pickup_chest then
            table.insert(silo.chest_names, name)
          end
        end
      end
      
      -- add the item to the record
      function silo.add(item)
        inc_tbl(silo.dict, item.name, item.count)
      end
      
      -- scan through all invos and put into dict
      function silo.update_all_items()
        silo.dict = {}
        for _, name in ipairs(silo.chest_names) do
          silo.update(name)
        end
      end
      
      function silo.update(target)
        local items = peripheral.call(target, "list")
        if items then
          for _, item in pairs(items) do
            silo.add(item)
          end
        end
      end
      
      function silo.grab(chest_name, slot, stack_size)
        peripheral.call(silo.pickup_chest, "pullItems", chest_name, slot, stack_size)
      end
      
      -- go through all items and take the specified item until count rem <= 0
      function silo.get_item(item_name, count)
        local rem = count
        item_name = item_name:lower()
        for _, chest_name in ipairs(silo.chest_names) do
          local items = peripheral.call(chest_name, "list")
          if items then
            for slot, item in pairs(items) do
              if item.name:lower():find(item_name, 1, true) then
                local amount = math.min(item.count, rem)
                silo.grab(chest_name, slot, amount)
                rem = rem - amount
                if rem <= 0 then
                  return
                end
              end
            end
          end
        end
      end
      
      -- try to suck the slot of dump chest with storage chests
      function silo.try_to_dump(slot, count, target)
        target = target or silo.dump_chest
        for _, chest_name in ipairs(silo.chest_names) do
          local num = peripheral.call(target, "pushItems", chest_name, slot, count)
          if num >= count then
            return true
          end
        end
        return false
      end
      
      -- for all storage chest try to suck everythin in the dump chest
      function silo.dump(target)
        target = target or silo.dump_chest
        local suck_this = peripheral.call(target, "list")
        if suck_this then
          for slot, item in pairs(suck_this) do
            if not silo.try_to_dump(slot, item.count, target) then
              return false
            end
          end
        end
        return true
      end
      
      function silo.startup()
        silo.find_chests()
        silo.update_all_items()
        
        
        if peripheral.isPresent(TURTLE_NAME) then
          print("Turtle connected: "..TURTLE_NAME)
        else
          print("Turtle not found: "..TURTLE_NAME)
        end
      end
      
      silo.startup()
    end
    
    startup()
    
    
    print("Clearing pickup chest...")
    silo.dump(silo.pickup_chest)
    
    
    local item_name = table.concat(tArgs, " ", 2)
    print("Fetching: "..item_name)
    silo.get_item(item_name, 64)
    
    
    print("Transferring to turtle...")
    local pickup = peripheral.wrap(silo.pickup_chest)
    if pickup then
      local items = pickup.list()
      local transferred = false
      
      for slot, item in pairs(items) do
        if item.name:lower():find(item_name:lower(), 1, true) then
          
          local turtle = peripheral.wrap(TURTLE_NAME)
          if turtle then
            turtle.pullItems(peripheral.getName(pickup), slot, item.count)
            print(("Transferred %dx %s to turtle"):format(item.count, item.name))
            transferred = true
          else
            print("Turtle not found: "..TURTLE_NAME)
          end
        end
      end
      
      if not transferred then
        print("No items found for transfer")
      end
    else
      print("Pickup chest not found")
    end
    return
  else
    shell.run("clear")
    print("type to find items")
    print("press 1-9 to get that item")
    print("press tab to clear pickup/dropoff chests")
    print("Use: auto <item_name> to send items to turtle")
    error()
  end
end

-- helper functions --
function all(tbl)
  local prev_k = nil
  return function()
    local k,v = next(tbl, prev_k)
    prev_k = k
    return v
  end
end

function inc_tbl(tbl, key, val)
  assert(key, "key cannot be false or nil")
  val = val or 1
  if not tbl[key] then
    tbl[key] = 0
  end
  tbl[key] = tbl[key] + val
end

local function beginsWith(string, beginning)
  return string:sub(1,#beginning) == beginning
end

function forEach(tbl, func)
  for val in all(tbl) do
    func(val)
  end
end

function t2f(tbl, filename)
  filename = filename or "output"
  local h = io.open(filename, "w")
  h:write(textutils.serialize(tbl))
  h:close()
  shell.run("edit "..tostring(filename))
end


-- silo singleton code --
silo = {
  dict = {},
  chest_names = {},
  dump_chest = DUMP_CHEST_NAME,
  pickup_chest = PICKUP_CHEST_NAME,
}

-- scan through all connected chests and add to table
function silo.find_chests()
  silo.chest_names = {}
  for _, name in ipairs(peripheral.getNames()) do
    if beginsWith(name, "minecraft:chest") and name ~= silo.dump_chest and name ~= silo.pickup_chest then
      table.insert(silo.chest_names, name)
    end
  end
end

-- add the item to the record
function silo.add(item)
  inc_tbl(silo.dict, item.name, item.count)
end

-- scan through all invos and put into dict
function silo.update_all_items()
  silo.dict = {}
  for _, name in ipairs(silo.chest_names) do
    silo.update(name)
  end
end

function silo.update(target)
  local items = peripheral.call(target, "list")
  if items then
    for _, item in pairs(items) do
      silo.add(item)
    end
  end
end

function silo.grab(chest_name, slot, stack_size)
  peripheral.call(silo.pickup_chest, "pullItems", chest_name, slot, stack_size)
end

-- go through all items and take the specified item until count rem <= 0
function silo.get_item(item_name, count)
  local rem = count
  item_name = item_name:lower()
  for _, chest_name in ipairs(silo.chest_names) do
    local items = peripheral.call(chest_name, "list")
    if items then
      for slot, item in pairs(items) do
        if item.name:lower():find(item_name, 1, true) then
          local amount = math.min(item.count, rem)
          silo.grab(chest_name, slot, amount)
          rem = rem - amount
          if rem <= 0 then
            return
          end
        end
      end
    end
  end
end

-- try to suck the slot of dump chest with storage chests
function silo.try_to_dump(slot, count, target)
  target = target or silo.dump_chest
  for _, chest_name in ipairs(silo.chest_names) do
    local num = peripheral.call(target, "pushItems", chest_name, slot, count)
    if num >= count then
      return true
    end
  end
  return false
end

-- for all storage chest try to suck everythin in the dump chest
function silo.dump(target)
  target = target or silo.dump_chest
  local suck_this = peripheral.call(target, "list")
  if suck_this then
    for slot, item in pairs(suck_this) do
      if not silo.try_to_dump(slot, item.count, target) then
        return false
      end
    end
  end
  return true
end

function silo.search(item_name)
  item_name = item_name:lower()
  for _, name in ipairs(silo.chest_names) do
    local items = peripheral.call(name, "list")
    if items then
      for _, item in pairs(items) do
        if item.name:lower():find(item_name, 1, true) then
          silo.add(item)
        end
      end
    end
  end
end

function silo.get_capacity()
  local total_slots = 0
  local used_slots = 0
  local used_items = 0

  for _, name in ipairs(silo.chest_names) do
    total_slots = total_slots + peripheral.call(name, "size")
    local items = peripheral.call(name, "list")
    if items then
      used_slots = used_slots + #items
      for _, item in pairs(items) do
        used_items = used_items + item.count
      end
    end
  end

  print("slots used ".. tostring(used_slots) .. "/" .. tostring(total_slots))
  print("items stored "..tostring(used_items) .. "/" .. tostring(total_slots*64))
end

function startup()
  term.clear()
  term.setCursorPos(1,1)
  term.write("Search: ")
  term.setCursorBlink(true)

  silo.startup()
  silo.update_all_items()
end

function backspace(num)
  num = num or 1
  local x, y = term.getCursorPos()
  if x - num <= 8 then
    return
  end
  term.setCursorPos(x - num, y)
  for _ = 1, num do
    term.write(" ")
  end
  term.setCursorPos(x - num, y)
end

function printWord(word)
  local x,y = term.getCursorPos()
  term.setCursorPos(1,y+1)
  term.clearLine()
  term.write("word: "..word)
  term.setCursorPos(x,y)
end

function notify(msg)
  local x,y = term.getCursorPos()
  term.setCursorPos(1,height)
  term.clearLine()
  term.write(msg)
  term.setCursorPos(x,y)
end

function clearUnderSearch()
  local x,y = term.getCursorPos()
  for i=2,height do
    term.setCursorPos(1,i)
    term.clearLine()
  end
  term.setCursorPos(x,y)
end

function listItems(word)
  clearUnderSearch()
  local x,y = term.getCursorPos()
  local line = 1
  local itemChoices = {}
  word = word:lower()
  
  for item, count in pairs(silo.dict) do
    if item:lower():find(word, 1, true) then
      if line >= height-2 then
        term.setCursorPos(x,y)
        return itemChoices
      end
      term.setCursorPos(1,y+line)
      term.write(("%i) %ix %s"):format(line, count, item))
      itemChoices[line] = item
      line = line + 1
    end
  end
  
  term.setCursorPos(x,y)
  return itemChoices
end

function silo.startup()
  silo.find_chests()
  silo.update_all_items()
  

  if peripheral.isPresent(TURTLE_NAME) then
    print("Turtle connected: "..TURTLE_NAME)
  else
    print("Turtle not found: "..TURTLE_NAME)
  end
end

startup()

local word = ""
local itemChoices = listItems(word)
while true do
  local event,keyCode,isHeld = os.pullEvent("key")
  local key = keys.getName(keyCode)

  if #key == 1 then
    word = word .. key
    term.write(key)
    itemChoices = listItems(word)
  elseif key == "space" then
    word = word .. " "
    term.write(" ")
    itemChoices = listItems(word)
  elseif key == "backspace" then
    word = word:sub(1,#word-1)
    backspace()
    itemChoices = listItems(word)
  elseif key == "grave" then
    backspace(#word)
    word = ""
    itemChoices = listItems(word)
  elseif key == "semicolon" then
    word = word .. ":"
    term.write(":")
    itemChoices = listItems(word)
  elseif key == "tab" then
    notify("dumping...")
    local a = silo.dump(silo.dump_chest)
    local b = silo.dump(silo.pickup_chest)
    if a and b then
      silo.update_all_items()
      itemChoices = listItems(word)
      notify("dump successful")
    else
      notify("dump failed")
    end
  elseif 49 <= keyCode and keyCode <= 57 then
    local sel = keyCode - 48
    if sel <= #itemChoices then
      local item = itemChoices[sel]
      local count = silo.dict[item]
      if count and count > 64 then
        count = 64
      end
      silo.get_item(item, count)
      silo.dict[item] = silo.dict[item] - count
      if silo.dict[item] <= 0 then
        silo.dict[item] = nil
      end
      itemChoices = listItems(word)
      notify(("grabbed %ix %s"):format(count,item))
    else
      notify(("%i is not an option"):format(sel))
    end
  end
end
