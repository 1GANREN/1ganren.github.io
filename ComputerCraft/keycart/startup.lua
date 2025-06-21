local side = "right" -- сторона куда подключена дверь (редстоун)
local keyName = "disk/key" -- путь к файлу на дискете

-- Проверяем есть ли дискета
if not disk.isPresent() then
    print("Вставьте диск с ключом")
    return
end

-- Читаем ключ с дискеты
local file = fs.open(keyName, "r")
if not file then
    print("Ключ не найден на диске")
    return
end

local keyCode = file.readLine()
file.close()

local masterKey = "lemmein" -- секретный код

if keyCode == masterKey then
    print("Дверь открыта")
    redstone.setOutput(side, true) -- подаем сигнал (открываем дверь)
    sleep(5) -- держим дверь открытой 5 секунд
    redstone.setOutput(side, false) -- закрываем дверь
else
    print("Неверный ключ")
    redstone.setOutput(side, false)
end
