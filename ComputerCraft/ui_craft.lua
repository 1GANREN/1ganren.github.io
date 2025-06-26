-- Рекомендации по настройке:
-- Каждый сундук должен касаться максимум 1 модема
-- Используйте плоский проводной модем для подключения к компьютеру

-- Укажите имена сундуков для сброса и выдачи (остальные сундуки будут использоваться как хранилище)
local DUMP_CHEST_NAME = "minecraft:chest_2"  -- Сундук для сброса предметов
local PICKUP_CHEST_NAME = "minecraft:chest_3"  -- Сундук для выдачи предметов

local tArgs = {...}
local width, height = term.getSize()  -- Получаем размеры терминала

if #tArgs > 0 then
  shell.run("clear")
  print("Введите текст для поиска предметов")
  print("Нажмите 1-9 для выбора предмета")
  print("Нажмите Tab для очистки сундуков выдачи/сброса")
  error()
end

-- Вспомогательные функции --
function all(tbl) 
  local prev_k = nil
  return function()
    local k,v = next(tbl, prev_k)
    prev_k = k
    return v
  end
end

-- Увеличение значения в таблице
function inc_tbl(tbl, key, val)
  assert(key, "Ключ не может быть false или nil")
  val = val or 1
  if not tbl[key] then
    tbl[key] = 0
  end
  tbl[key] = tbl[key] + val
end

-- Проверка начала строки
local function beginsWith(string, beginning)
  return string:sub(1,#beginning) == beginning
end

-- Применение функции к каждому элементу таблицы
function forEach(tbl, func)
  for val in all(tbl) do
    func(val)
  end
end

-- Основной объект хранилища
local silo = {
  dict = {},        -- Словарь предметов и их количества
  recipes = {},     -- Рецепты крафта
  loc = {},         -- Расположение предметов
  perf_cache = {},  -- Кэш периферийных устройств
  chest_names = {}, -- Имена сундуков
  show_crafts = true, -- Показывать крафт
  dump_chest = DUMP_CHEST_NAME,  -- Сундук сброса
  pickup_chest = PICKUP_CHEST_NAME, -- Сундук выдачи
}

-- Поиск всех подключенных сундуков
function silo.find_chests()
  silo.chest_names = {}
  for name in all(peripheral.getNames()) do
    if (beginsWith(name, "chest") or beginsWith(name, "ironchest")) and name ~= silo.dump_chest and name ~= silo.pickup_chest then
      table.insert(silo.chest_names, name)
    end
  end
end

-- Добавление предмета в словарь
function silo.add(item)
  inc_tbl(silo.dict, item.name, item.count)
end

-- Добавление информации о местоположении предмета
function silo.add_loc(item, target, slot)
  if not silo.loc[item.name] then
    silo.loc[item.name] = {}
  end
  local index = silo.get_peripheral_index(target)
  table.insert(silo.loc[item.name], index)
  table.insert(silo.loc[item.name], slot)
  table.insert(silo.loc[item.name], item.count)
end

-- Обновление информации о всех предметах
function silo.update_all_items()
  silo.dict = {}
  silo.loc = {}
  for name in all(silo.chest_names) do
    silo.update(name)
  end
end

-- Обновление информации о предметах в конкретном сундуке
function silo.update(target)
  local items = peripheral.call(target, "list")
  for i, item in pairs(items) do
    silo.add(item)
    silo.add_loc(item, target, i)
  end
end

-- Инициализация системы
function silo.startup()
  silo.find_chests()
end

-- Функция переноса предметов
function silo.grab(chest_name, slot, stack_size)
  peripheral.call(silo.pickup_chest, "pullItems", chest_name, slot, stack_size)
end

-- Получение предмета из хранилища
function silo.get_item(item_name, count, dest)  
  local rem = count
  dest = dest or silo.pickup_chest
  
  if not silo.loc[item_name] then
    if rem > 0 then
      error(("Нужно еще %s: %i"):format(item_name, rem), 0)
    end
    return
  end

  -- Логика переноса предметов...
end

-- Проверка возможности крафта
function silo.how_many(item_name)
  local yieldItemCount = silo.recipes[item_name]
  local craftable = {} 
  
  for i = 2,#yieldItemCount-1,2 do
    local item = yieldItemCount[i]
    local count = yieldItemCount[i + 1]
    if not silo.dict[item] then
      return 0, ("Нужно %s: %i"):format(item, count)
    end
    -- Дополнительная логика проверки...
  end
  
  return math.min(unpack(craftable)), "Нужно больше материалов"
end

-- Выполнение крафта
function silo.craft(item_name, num)
  local yieldItemCount = silo.recipes[item_name]
  assert(yieldItemCount, "Рецепт для "..tostring(item_name).. " не существует")
  -- Логика крафта...
end

-- Перенос предметов в хранилище
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

-- Поиск предметов
function silo.search(item_name)
  item_name = item_name:lower()
  for name in all(silo.chest_names) do
    local items = peripheral.call(name, "list")
    forEach(items, function(item) if item.name:find(item_name) then silo.add(item) end end)
  end
end

-- Проверка заполненности хранилища
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
  
  print("Занято слотов: ".. tostring(used_slots) .. "/" .. tostring(total_slots))
  print("Предметов: "..tostring(used_items) .. "/" .. tostring(total_slots*64))
end

-- Инициализация программы
function startup()
  term.clear()
  term.setCursorPos(1,1)
  term.write("Поиск: ")
  term.setCursorBlink(true)
  
  silo.startup()
  silo.update_all_items()
  silo.load_recipes()
end

-- Основной цикл программы
startup()
local word = ""
local itemChoices = listItems(word)
while true do
  local event,keyCode,isHeld = os.pullEvent("key")
  local key = keys.getName(keyCode)
    
  -- Обработка ввода пользователя...
end
