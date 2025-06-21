rs.setOutput ("bottom", true)
while true do
    if disk.isPresent("top") then
        if fs.exists("disk/.security/key") then
            shell.run("disk/.security/key")
            if pass == "lemmein" then
                disk.eject("top")
                rs.setOutput("bottom", false)
                sleep(3)
                rs.setOutput("bottom", true)
            else
                disk.eject("top")
            end
        else
            disk.eject("top")
        end
    end
    sleep(0.1)
end