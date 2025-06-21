rs.setOutput("bottom", false) -- изначально дверь закрыта

while true do
  if disk.isPresent("top") then
    if fs.exists("disk/.security/key") then
      local file = fs.open("disk/.security/key", "r")
      local pass = file.readLine()
      file.close()

      if pass == "lemmein" then
        rs.setOutput("bottom", true) -- открыть дверь
        sleep(3)
        rs.setOutput("bottom", false) -- закрыть дверь
      end
      disk.eject("top")
    else
      disk.eject("top")
    end
  end
  sleep(0.1)
end
