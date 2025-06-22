-- Конфигурация
local DUMP_CHEST_NAME = "minecraft:chest_2"
local PICKUP_CHEST_NAME = "minecraft:chest_3"
local MODEM_SIDE = "top"
local PROTOCOL = "me_system_v3"
local STORAGE_TYPES = {
    "minecraft:chest",
    "ironchest:iron_chest",
    "goldchest:gold_chest",
    "diamondchest:diamond_chest"
}

-- Глобальные функции
local function contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end

local function table_size(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

-- Структура silo
local silo = {
    dump_chest = DUMP_CHEST_NAME,
    pickup_chest = PICKUP_CHEST_NAME,
    chest_names = {},
    item_index = {},
    fast_access = {},
    terminals = {}
}

-- Поиск хранилищ
function silo.find_storage()
    silo.chest_names = {}
    local names = peripheral.getNames()
    for i = 1, #names do
        local name = names[i]
        local type = peripheral.getType(name)
        if contains(STORAGE_TYPES, type) and 
           name ~= silo.dump_chest and 
           name ~= silo.pickup_chest then
            table.insert(silo.chest_names, name)
        end
    end
end

-- Построение индекса предметов
function silo.build_index()
    silo.item_index = {}
    silo.fast_access = {}
    
    for i = 1, #silo.chest_names do
        local chest_name = silo.chest_names[i]
        local items = peripheral.call(chest_name, "list")
        
        for slot, item in pairs(items) do
            local name = item.name:lower()
            
            if not silo.item_index[name] then
                silo.item_index[name] = {
                    total = 0,
                    locations = {}
                }
            end
            
            silo.item_index[name].total = silo.item_index[name].total + item.count
            table.insert(silo.item_index[name].locations, {
                chest = chest_name,
                slot = slot,
                count = item.count
            })
            
            if not silo.fast_access[name] then
                silo.fast_access[name] = {}
            end
            table.insert(silo.fast_access[name], {
                chest = chest_name,
                slot = slot
            })
        end
    end
end

-- Извлечение предмета
function silo.get_item(item_name, count)
    local rem = count
    item_name = item_name:lower()
    
    -- Используем кэш быстрого доступа
    if silo.fast_access[item_name] then
        for j = 1, #silo.fast_access[item_name] do
            local entry = silo.fast_access[item_name][j]
            local amount = math.min(64, rem)
            local num = peripheral.call(
                silo.pickup_chest, 
                "pullItems", 
                entry.chest, 
                entry.slot, 
                amount
            )
            rem = rem - num
            if rem <= 0 then return count end
        end
    end
    
    -- Поиск по всем хранилищам
    for i = 1, #silo.chest_names do
        local chest_name = silo.chest_names[i]
        local items = peripheral.call(chest_name, "list")
        
        for slot, item in pairs(items) do
            if item.name:lower() == item_name then
                local amount = math.min(64, rem)
                local num = peripheral.call(
                    silo.pickup_chest, 
                    "pullItems", 
                    chest_name, 
                    slot, 
                    amount
                )
                rem = rem - num
                
                -- Обновляем кэш
                if not silo.fast_access[item_name] then
                    silo.fast_access[item_name] = {}
                end
                table.insert(silo.fast_access[item_name], {
                    chest = chest_name,
                    slot = slot
                })
                
                if rem <= 0 then break end
            end
        end
        if rem <= 0 then break end
    end
    
    return count - rem
end

-- Сброс предметов в хранилище
function silo.dump(target)
    target = target or silo.dump_chest
    local success = true
    local items = peripheral.call(target, "list")
    
    for slot, item in pairs(items) do
        local moved = 0
        for i = 1, #silo.chest_names do
            local storage = silo.chest_names[i]
            moved = moved + peripheral.call(
                target, 
                "pushItems", 
                storage, 
                slot, 
                item.count - moved
            )
            if moved >= item.count then break end
        end
        
        if moved < item.count then
            success = false
            break
        end
    end
    
    return success
end

-- Обработчик сетевых сообщений
local function handleRednetMessage(sender, message)
    if message.type == "search" then
        local results = {}
        for name, data in pairs(silo.item_index) do
            if name:find(message.query:lower()) then
                results[name] = data.total
            end
        end
        rednet.send(sender, {type = "search", results = results}, PROTOCOL)
    
    elseif message.type == "extract" then
        local success = false
        if silo.item_index[message.item] then
            local extracted = silo.get_item(message.item, message.count)
            success = (extracted > 0)
            
            if success then
                silo.item_index[message.item].total = silo.item_index[message.item].total - extracted
                if silo.item_index[message.item].total <= 0 then
                    silo.item_index[message.item] = nil
                end
            end
        end
        rednet.send(sender, {
            type = "extract",
            success = success,
            extracted = extracted or 0,
            item = message.item
        }, PROTOCOL)
    
    elseif message.type == "dump" then
        local dump_success = silo.dump(silo.dump_chest)
        local pickup_success = silo.dump(silo.pickup_chest)
        rednet.send(sender, {
            type = "dump",
            success = dump_success and pickup_success
        }, PROTOCOL)
        
        if dump_success and pickup_success then
            silo.build_index()
        end
    
    elseif message.type == "register" then
        table.insert(silo.terminals, sender)
        rednet.send(sender, {
            type = "registered",
            dump_chest = silo.dump_chest,
            pickup_chest = silo.pickup_chest
        }, PROTOCOL)
    
    elseif message.type == "status" then
        rednet.send(sender, {
            type = "status",
            storage = #silo.chest_names,
            items = table_size(silo.item_index),
            dump_chest = silo.dump_chest,
            pickup_chest = silo.pickup_chest
        }, PROTOCOL)
    end
end

-- Сетевая служба
local function network_service()
    while true do
        local id, message = rednet.receive(PROTOCOL)
        if type(message) == "table" then
            handleRednetMessage(id, message)
        end
    end
end

-- Локальный интерфейс
local function main_interface()
    local width, height = term.getSize()
    local word = ""
    local itemChoices = {}
    
    local function clearUnderSearch()
        local x, y = term.getCursorPos()
        for i = 2, height do
            term.setCursorPos(1, i)
            term.clearLine()
        end
        term.setCursorPos(x, y)
    end
    
    local function notify(msg)
        local x, y = term.getCursorPos()
        term.setCursorPos(1, height)
        term.clearLine()
        term.write(msg)
        term.setCursorPos(x, y)
    end
    
    local function listItems()
        clearUnderSearch()
        local x, y = term.getCursorPos()
        local line = 1
        itemChoices = {}
        
        for item, data in pairs(silo.item_index) do
            if item:find(word:lower()) then
                if line >= height-1 then break end
                term.setCursorPos(1, y + line)
                term.write(("%i) %ix %s"):format(line, data.total, item))
                itemChoices[line] = item
                line = line + 1
            end
        end
        term.setCursorPos(x, y)
    end
    
    term.clear()
    term.setCursorPos(1, 1)
    term.write("Search: ")
    listItems()
    
    while true do
        local event, keyCode = os.pullEvent("key")
        local key = keys.getName(keyCode)
        
        if #key == 1 then
            word = word .. key
            term.write(key)
            listItems()
        elseif key == "space" then
            word = word .. " "
            term.write(" ")
            listItems()
        elseif key == "backspace" then
            word = word:sub(1, #word - 1)
            local x, y = term.getCursorPos()
            if x > 8 then
                term.setCursorPos(x - 1, y)
                term.write(" ")
                term.setCursorPos(x - 1, y)
            end
            listItems()
        elseif key == "tab" then
            notify("Dumping items...")
            local dump_success = silo.dump(silo.dump_chest)
            local pickup_success = silo.dump(silo.pickup_chest)
            
            if dump_success and pickup_success then
                silo.build_index()
                listItems()
                notify("Dump successful!")
            else
                notify("Dump partially failed!")
            end
        elseif key == "enter" then
            -- Enter для ручного обновления
            silo.build_index()
            listItems()
            notify("Inventory updated!")
        elseif 49 <= keyCode and keyCode <= 57 then  -- Клавиши 1-9
            local sel = keyCode - 48
            if itemChoices[sel] then
                local item = itemChoices[sel]
                local count = silo.item_index[item].total
                if count > 64 then count = 64 end
                
                local extracted = silo.get_item(item, count)
                if extracted > 0 then
                    silo.item_index[item].total = silo.item_index[item].total - extracted
                    if silo.item_index[item].total <= 0 then
                        silo.item_index[item] = nil
                    end
                    listItems()
                    notify(("Grabbed %dx %s"):format(extracted, item))
                else
                    notify("Extraction failed!")
                end
            end
        end
    end
end

-- Запуск системы
function startup()
    term.clear()
    term.setCursorPos(1, 1)
    print("=== ME Storage System v3 ===")
    print("Dump Chest: "..silo.dump_chest)
    print("Pickup Chest: "..silo.pickup_chest)
    
    -- Инициализация сети
    if peripheral.isPresent(MODEM_SIDE) then
        rednet.open(MODEM_SIDE)
        print("Wireless: ON")
    else
        print("Wireless: OFF")
    end
    
    -- Поиск хранилищ
    silo.find_storage()
    print("Found "..#silo.chest_names.." storage units")
    
    -- Построение индекса
    silo.build_index()
    print("Indexed "..table_size(silo.item_index).." items")
    
    -- Запуск служб
    parallel.waitForAny(
        main_interface,
        network_service
    )
end

-- Запуск
startup()
