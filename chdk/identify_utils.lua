-- identify utils
function dc_identify_cam(opts)
--     identify cam and return id name
    files = os.listdir("A/")
    if files then
        for n, name in ipairs(files) do
            if name == opts.left_fn then 
                idname = opts.odd
            end
            if name == opts.right_fn then 
                idname = opts.even
            end
        end
    end
    if not idname then
        play_sound(2); sleep(150)
        idname = opts.all
    end
    return idname
end

function dc_pip_cam()
   play_sound(2); sleep(150)
   local rec,vid,mode = get_mode()
   if rec then 
      rec = "rec"
   else
      rec = ""
   end
   return rec
end

function dc_init_cam(opts)
--  shoot_half and lock focus
    play_sound(2)
    sleep(200)
    if not get_mode() then
        switch_mode_usb(1)
    end
    local i=0
    local capmode = require'capmode'
    while capmode.get() == 0 and i < 300 do
        sleep(10)
        i=i+1
    end
--
    sleep(1000); set_aflock(0); sleep(200)
--
    if opts.zoom_pos then
        set_zoom(opts.zoom_pos)
        sleep(1500)
    end

    press('shoot_half')
    i=0
    while get_shooting() do
        sleep(10)
        if i > 300 then
            break
        end
        i=i+1
    end
    sleep(100)
    set_aflock(1)
    sleep(100)
    release('shoot_half')
--
    sleep(1000)
    play_sound(4); sleep(150); play_sound(4); sleep(150); play_sound(4)
    sleep(200) 
--
end
