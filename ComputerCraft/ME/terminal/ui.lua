-- Конфигурация
local MODEM_SIDE = "back"
local PROTOCOL = "me_system_v3"
local SERVER_ID = nil
local DUMP_CHEST = "Unknown"
local PICKUP_CHEST = "Unknown"

-- Инициализация
if peripheral.isPresent(MODEM_SIDE) then
    rednet.open(MODEM_SIDE)
end

-- Поиск сервера
local function find_server()
    rednet.broadcast("discover", PROTOCOL)
    local start = os.epoch("utc")
    while os.epoch("utc") - start < 3000 do  -- 3 секунды
        local id, message = rednet.receive(PROTOCOL, 1)
        if id and message and message.type == "identity" then
            return id
        end
    end
    return nil
end

-- Регистрация терминала
local function register_terminal()
    rednet.send(SERVER_ID, {type = "register"}, PROTOCOL)
    local id, response = rednet.receive(PROTOCOL, 3)
    if id == SERVER_ID and response and response.type == "registered" then
        DUMP_CHEST = response.dump_chest or "Unknown"
        PICKUP_CHEST = response.pickup_chest or "Unknown"
        return true
    end
    return false
end

-- Поиск предметов
local function search_items(query)
    rednet.send(SERVER_ID, {
        type = "search",
        query = query
    }, PROTOCOL)
    
    local id, response = rednet.receive(PROTOCOL, 3)
    if id == SERVER_ID and response and response.type == "search" then
        return response.results
    end
    return nil
end

-- Извлечение предметов
local function extract_item(item, count)
    rednet.send(SERVER_ID, {
        type = "extract",
        item = item,
        count = count
    }, PROTOCOL)
    
    local id, response = rednet.receive(PROTOCOL, 5)
    if id == SERVER_ID and response and response.type == "extract" then
        return response
    end
    return nil
end

-- Сброс предметов
local function dump_items()
    rednet.send(SERVER_ID, {type = "dump"}, PROTOCOL)
    local id, response = rednet.receive(PROTOCOL, 5)
    if id == SERVER_ID and response and response.type == "dump" then
        return response.success
    end
    return false
end

-- Получение статуса системы
local function get_system_status()
    rednet.send(SERVER_ID, {type = "status"}, PROTOCOL)
    local id, response = rednet.receive(PROTOCOL, 3)
    if id == SERVER_ID and response and response.type == "status" then
        return response
    end
    return nil
end

-- Интерфейс поиска
local function search_interface()
    term.clear()
    term.setCursorPos(1, 1)
    term.write("Search query: ")
    local query = read()
    
    if query == "" then return end
    
    local results = search_items(query)
    if not results then
        print("Server not responding")
        sleep(2)
        return
    end
    
    term.clear()
    term.setCursorPos(1, 1)
    print("Search results for: "..query)
    print("----------------------------")
    
    local items = {}
    local i = 1
    for name, count in pairs(results) do
        if i <= 16 then  -- Ограничение вывода
            print(("%d) %s x%d"):format(i, name, count))
            items[i] = name
            i = i + 1
        end
    end
    
    if i == 1 then
        print("No items found")
        sleep(1.5)
        return
    end
    
    print("\nSelect item (1-"..(i-1)..") or [B]ack")
    term.write("> ")
    
    while true do
        local input = read()
        if input:lower() == "b" then
            return
        end
        
        local choice = tonumber(input)
        if choice and items[choice] then
            term.write("Amount (max 64): ")
            local amount = tonumber(read()) or 1
            amount = math.min(64, math.max(1, amount))
            
            local result = extract_item(items[choice], amount)
            if result and result.success then
                print(("Retrieved %dx %s"):format(result.extracted, items[choice]))
            else
                print("Retrieval failed!")
            end
            sleep(2)
            return
        else
            term.write("Invalid choice. Try again > ")
        end
    end
end

-- Главное меню
local function main_menu()
    while true do
        term.clear()
        term.setCursorPos(1, 1)
        print("=== ME Remote Terminal ===")
        print("Connected to: "..(SERVER_ID or "None"))
        print("Dump Chest: "..DUMP_CHEST)
        print("Pickup Chest: "..PICKUP_CHEST)
        print("----------------------------")
        print("1. Search items")
        print("2. Dump items to storage")
        print("3. System status")
        print("4. Reconnect to server")
        print("Q. Exit")
        print("----------------------------")
        term.write("Select option: ")
        
        local choice = read()
        
        if choice == "1" then
            search_interface()
        elseif choice == "2" then
            if dump_items() then
                print("Items dumped successfully!")
            else
                print("Dump failed!")
            end
            sleep(1.5)
        elseif choice == "3" then
            local status = get_system_status()
            term.clear()
            term.setCursorPos(1, 1)
            if status then
                print("=== System Status ===")
                print("Storage units: "..status.storage)
                print("Unique items: "..status.items)
                print("Dump Chest: "..(status.dump_chest or DUMP_CHEST))
                print("Pickup Chest: "..(status.pickup_chest or PICKUP_CHEST))
            else
                print("Failed to get status")
            end
            print("\nPress any key to continue...")
            os.pullEvent("key")
        elseif choice == "4" then
            SERVER_ID = find_server()
            if SERVER_ID then
                register_terminal()
                print("Reconnected successfully!")
            else
                print("Server not found")
            end
            sleep(1.5)
        elseif choice:lower() == "q" then
            term.clear()
            term.setCursorPos(1, 1)
            return
        end
    end
end

-- Основной цикл
while true do
    term.clear()
    term.setCursorPos(1, 1)
    
    if not SERVER_ID then
        print("Searching for ME Server...")
        SERVER_ID = find_server()
        
        if SERVER_ID then
            if register_terminal() then
                print("Connected to server ID: "..SERVER_ID)
                sleep(1)
                main_menu()
            else
                print("Registration failed")
                SERVER_ID = nil
                sleep(1.5)
            end
        else
            print("Server not found. Retrying...")
            sleep(2)
        end
    else
        main_menu()
        SERVER_ID = nil  -- Сброс соединения при выходе
    end
end
