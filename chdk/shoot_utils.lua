-- shoot utils

function dalclick_shootfull()
	if get_raw() then
		set_raw(0)
		sleep(100)
	end
	sleep(100)
	press('shoot_full_only'); sleep(100); release('shoot_full')
end

function get_lastimg()
    dir = os.listdir("A/DCIM")
    sleep(100)
    if dir then
        for n, name in ipairs(dir) do
            if string.match(name,"^%d") then
                if lastname then
                    if name > lastname then
                        lastname = name
                    end
                else
                    lastname = name
                end
            end
        end
        lastdir = lastname
    end
    lastname = ""
    if lastdir then
        files = os.listdir("A/DCIM/"..lastdir)
        if files then
            for n, name in ipairs(files) do
                if string.match(name,"%.JPG$") then
                    if lastname then
                        if name > lastname then
                            lastname = name
                        end
                    else
                        lastname = name
                    end
                end
            end
            lastcapt = lastname 
        end
    end

    return lastdir, lastcapt
end
