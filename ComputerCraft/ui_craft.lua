-- ... existing code ...

function silo.get_item(item_name, count, dest)
    local rem = count
    dest = dest or silo.pickup_chest

    -- Handle missing items gracefully
    if not silo.loc[item_name] then
        if rem > 0 then
            error(("Need %i more %s"):format(rem, item_name), 0)
        end
        return
    end

    local sources = silo.loc[item_name]
    while #sources > 0 and rem > 0 do
        local stack_size = table.remove(sources)
        local slot = table.remove(sources)
        local perf_index = table.remove(sources)
        local perf_name = silo.get_peripheral_name(perf_index)
        
        -- Get actual transfer amount
        local amount = math.min(stack_size, 64, rem)
        local actual = peripheral.call(perf_name, "pushItems", dest, slot, amount)
        
        -- Update counts with actual transferred amount
        stack_size = stack_size - actual
        rem = rem - actual
        silo.dict[item_name] = (silo.dict[item_name] or 0) - actual

        -- Return unused portion to sources
        if stack_size > 0 then
            table.insert(sources, perf_index)
            table.insert(sources, slot)
            table.insert(sources, stack_size)
        end
    end

    -- Clean up empty sources
    if #sources == 0 then
        silo.loc[item_name] = nil
    end

    -- Handle depleted items
    if silo.dict[item_name] and silo.dict[item_name] <= 0 then
        if not silo.recipes[item_name] then
            silo.dict[item_name] = nil
        else
            silo.dict[item_name] = 0
        end
    end

    if rem > 0 then
        error(("Need %i more %s"):format(rem, item_name), 0)
    end
end

function silo.update_all_items()
    -- PROPERLY reset dictionaries
    silo.dict = {}
    silo.loc = {}
    for name in all(silo.chest_names) do
        silo.update(name)
    end
end

function silo.load_recipes()
    for _, file in pairs(fs.list("patterns")) do
        if file:sub(-4) == ".lua" then  -- Only load Lua files
            local fileRoot = file:sub(1, -5)
            local success, nameYieldItemCount = pcall(function()
                return require("patterns/" .. fileRoot)
            end)
            
            if not success then
                printError("Failed to load pattern: " .. file)
                printError(nameYieldItemCount)  -- Error message
            else
                for name, yieldItemCount in pairs(nameYieldItemCount) do
                    table.insert(yieldItemCount, silo.get_peripheral_index(fileRoot))
                    silo.recipes[name] = yieldItemCount
                    if not silo.dict[name] then
                        silo.dict[name] = 0
                    end
                end
            end
        end
    end
end

-- ... in main loop crafting section ...
notify(("crafting %i %s"):format(num, item))
silo.craft(item, num)
notify(("crafted %i %s"):format(num, item))  -- Success notification
sleep(0.5)  -- Allow user to see message
itemChoices = listItems(word)

-- ... UI improvements ...
function notify(msg)
    local x, y = term.getCursorPos()
    -- Clear notification area (last 2 lines)
    for i = 0, 1 do
        term.setCursorPos(1, height - i)
        term.clearLine()
    end
    term.setCursorPos(1, height - 1)
    term.write(msg)
    term.setCursorPos(x, y)
end

-- ... removed unused functions ...
