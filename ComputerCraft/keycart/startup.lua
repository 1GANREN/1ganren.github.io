local side = "right"  -- side with the door (redstone output)
local keyName = "disk/key"  -- file path on the disk

if not disk.isPresent() then
    print("Please insert a disk with the key")
    return
end

local file = fs.open(keyName, "r")
if not file then
    print("Key file not found on disk")
    return
end

local keyCode = file.readLine()
file.close()

local masterKey = "lemmein"  -- secret key code

if keyCode == masterKey then
    print("Door opened")
    redstone.setOutput(side, true)  -- activate door
    sleep(5)  -- keep door open 5 seconds
    redstone.setOutput(side, false)  -- close door
else
    print("Invalid key")
    redstone.setOutput(side, false)
end
