-- ... (предыдущий код без изменений) ...

function startup()
  term.clear()
  term.setCursorPos(1,1)
  term.write("Search: ")
  term.setCursorBlink(true)

  silo.startup()
  silo.update_all_items()
  
  -- Переместим уведомление о черепашке вниз, чтобы не мешать вводу
  if peripheral.isPresent(TURTLE_NAME) then
    notify("Turtle connected: "..TURTLE_NAME)
  else
    notify("Turtle not found: "..TURTLE_NAME)
  end
end

-- ... (остальной код без изменений) ...

local word = ""
local itemChoices = listItems(word)
while true do
  local event, param1, param2 = os.pullEvent()

  if event == "char" then
    -- Обработка обычных символов
    word = word .. param1
    term.write(param1)
    itemChoices = listItems(word)
    
  elseif event == "key" then
    local key = keys.getName(param1)
    
    if key == "space" then
      word = word .. " "
      term.write(" ")
      itemChoices = listItems(word)
    elseif key == "backspace" then
      word = word:sub(1, #word-1)
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
    elseif param1 >= keys.one and param1 <= keys.nine then
      local sel = param1 - keys.one + 1
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
        notify(("grabbed %ix %s"):format(count, item))
      else
        notify(("%i is not an option"):format(sel))
      end
    end
  end
end
