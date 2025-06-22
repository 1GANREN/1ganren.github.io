-- recommend each chest only touching at most 1 modem
-- recommend flat wired modem for computer
print("welcome ccME")
sleep(3)
clear
-- specify name of dump chest and pickup chest (all other chests connected to modem network will be used as storage)
local DUMP_CHEST_NAME = "minecraft:chest_2"
local PICKUP_CHEST_NAME = "minecraft:chest_3"

local tArgs = {...}
local width, height = term.getSize()

if #tArgs > 0 then
  shell.run("clear")
  print("type to find items")
  print("press 1-9 to get that item")
  print("press tab to clear pickup/dropoff chests")
  error()
end

-- Имя периферии черепашки
local TURTLE_PERIPHERAL_NAME = "minecraft:turtle"

-- Программирование интерфейса с черепашкой
peripheral.attach(TURTLE_PERIPHERAL_NAME)

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
local silo = {
  dict = {},
  chest_names = {},
  dump_chest = DUMP_CHEST_NAME,
  pickup_chest = PICKUP_CHEST_NAME,
}

-- сканирует подключённые сундуки и добавляет их в таблицу
function silo.find_chests()
  silo.chest_names = {}
  for name in all(peripheral.getNames()) do
    if beginsWith(name, "minecraft:chest") and name ~= silo.dump_chest and name ~= silo.pickup_chest then
      table.insert(silo.chest_names, name)
    end
  end
end

-- добавляет элемент в запись
function silo.add(item)
  inc_tbl(silo.dict, item.name, item.count)
end

-- сканирует содержимое сундуков и заносит всё в словарь
function silo.update_all_items()
  silo.dict = {}
  for name in all(silo.chest_names) do
    silo.update(name)
  end
end

function silo.update(target)
  local items = peripheral.call(target, "list")
  forEach(items, function(item) silo.add(item) end)
end

function silo.startup()
  silo.find_chests()
end

function silo.grab(chest_name, slot, stack_size)
  peripheral.call(silo.pickup_chest, "pullItems", chest_name, slot, stack_size)
end

-- получение указанного элемента до тех пор, пока счётчик не достигнет нуля
function silo.get_item(item_name, count)
  local rem = count
  item_name = item_name:lower()
  for chest_name in all(silo.chest_names) do
    local items = peripheral.call(chest_name, "list")
    for i,item in pairs(items) do
      if item.name:find(item_name) then
        local amount = math.min(64, rem)
        silo.grab(chest_name, i, amount)
        rem = rem - amount
        if rem <= 0 then
          break
        end
      end
    end
  end
end

-- перекладывание содержимого из сундука выгрузки в другие сундуки
function silo.try_to_dump(slot, count, target)
  target = target or silo.dump_chest
  for chest_name in all(silo.chest_names) do
    local num = peripheral.call(target, "pushItems", chest_name, slot, count)
    if num >= count then
      return true
    end
  end
end

-- очищает весь сундук выгрузки
function silo.dump(target)
  target = target or silo.dump_chest
  local suck_this = peripheral.call(target, "list")
  for k,v in pairs(suck_this) do
    if not silo.try_to_dump(k,v.count,target) then
      return false
    end
  end
  return true
end

function silo.search(item_name)
  item_name = item_name:lower()
  for name in all(silo.chest_names) do
    local items = peripheral.call(name, "list")
    forEach(items, function(item) if item.name:find(item_name) then silo.add(item) end end)
  end
end

function silo.get_capacity()
  local total_slots = 0
  local used_slots = 0
  local used_items = 0

  for name in all(silo.chest_names) do
    total_slots = total_slots + peripheral.call(name, "size")
    local items = peripheral.call(name, "list")
    used_slots = used_slots + #items
    forEach(items, function(item) used_items = used_items + item.count end)
  end

  print("slots used ".. tostring(used_slots) .. "/" .. tostring(total_slots))
  print("items stored "..tostring(used_items) .. "/" .. tostring(total_slots*64))
end

-- Вспомогательные функции для работы с черепашкой

-- Проверка наличия достаточных ресурсов
function checkMaterials(recipe)
    for material, amount in pairs(recipe) do
        local currentStock = silo.dict[material] or 0
        if currentStock < amount then
            return false
        end
    end
    return true
end

-- Функция для подготовки ресурсов
function prepareIngredientsForCrafting(recipe)
    for material, amount in pairs(recipe) do
        silo.get_item(material, amount)
    end
end

-- Отправка ресурсов в инвентарь черепашки
function transferToTurtle(recipe)
    for material, amount in pairs(recipe) do
        -- Ищем подходящий сундук с нужным материалом
        local sourceChest = nil
        for _, chestName in ipairs(silo.chest_names) do
            local items = peripheral.call(chestName, "list")
            for slot, item in pairs(items) do
                if item.name == material then
                    sourceChest = {name = chestName, slot = slot}
                    break
                end
            end
            if sourceChest then break end
        end
        
        if sourceChest then
            -- Перемещение материала в инвентарь черепашки
            local transferred = peripheral.call(sourceChest.name, "transferTo", TURTLE_PERIPHERAL_NAME, sourceChest.slot, amount)
            if not transferred then
                notify("Ошибка переноса материала: " .. material)
                return false
            end
        else
            notify("Материал не найден: " .. material)
            return false
        end
    end
    return true
end

-- Расположение ресурсов в инвентаре черепашки
function arrangeIngredientsInTurtleSlots(recipe)
    -- перебор инвентаря черепашки и заполнение нужных слотов
    local inventory = peripheral.call(TURTLE_PERIPHERAL_NAME, "inventory")
    for slot, resourceData in pairs(inventory) do
        if resourceData.name == recipe["wood"] then
            -- помещаем дерево в первый слот
            peripheral.call(TURTLE_PERIPHERAL_NAME, "select", slot)
            peripheral.call(TURTLE_PERIPHERAL_NAME, "move", 1)
        end
    end
end

-- Автоматический крафт
function autoCraft(recipe, quantity)
    -- обновление запасов
    silo.update_all_items()
    
    -- проверка наличия ресурсов
    if not checkMaterials(recipe) then
        notify("Нехватка ресурсов для крафта.")
        return false
    end
    
    -- сборка ресурсов
    prepareIngredientsForCrafting(recipe)
    
    -- перемещение ресурсов в инвентарь черепашки
    if not transferToTurtle(recipe) then
        notify("Ошибка передачи ресурсов черепашке.")
        return false
    end
    
    -- расположение ресурсов в нужных слотах черепашки
    arrangeIngredientsInTurtleSlots(recipe)
    
    -- запускаем крафт
    peripheral.call(TURTLE_PERIPHERAL_NAME, "craft")
    
    -- ожидание завершения крафта
    os.sleep(5)
    
    -- возвращаем готовую продукцию обратно в сундук
    local finishedProduct = recipe.result
    silo.get_item(finishedProduct, quantity * recipe.amount)
    
    notify("Автоматический крафт завершён успешно!")
    return true
end

-- Пример рецепта для палочек
local stickRecipe = {
    wood = "minecraft:planks",
    sticks = "minecraft:stick",
    result = "minecraft:stick",
    amount = 4 -- один рецепт даёт 4 палочки
}

-- Основной цикл программы остаётся таким же
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
