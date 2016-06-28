        
function format_log(log, log_format)
    if log_format == 'serialized' then
        return serialize(log)
    else
        return log
    end
end

function dc_init_cam_alt(opts, log)
    local opts = opts or {}
    local log = log or {}
    local msg = ''
    
--  shoot_half and lock focus

    print('== dc_init_cam_alt ==')
    msg = "liberando foco..."
    table.insert(log, msg)   
    sleep(100); set_aflock(0); sleep(200)
    play_sound(2)
    sleep(100)

    msg = "poniendo en modo 'rec'"
    table.insert(log, msg) 
    log = dc_set_mode({ to_mode = "rec" }, log)
    
    msg = "fijando zoom..."
    table.insert(log, msg) 
    log = dc_set_zoom({ zoom_pos = opts.zoom_pos, zoom_sleep = opts.zoom_sleep }, log)
    
    msg = "enfocando..."
    table.insert(log, msg) 
    log = dc_refocus({ aflock = "already_unlock" }, log)

    return format_log(log, opts.log_format)
    
end

function dc_set_mode(opts, log)
    local opts = opts or {}
    local log = log or {}
    local msg = ''
    
    local rec,vid,mode = get_mode()
    if opts.to_mode == 'rec' then
        if rec == false then
            -- Set the camera to record mode
            switch_mode_usb(1)
            sleep(100)

            local i=0
            local capmode = require'capmode'

            while capmode.get() == 0 and i < 300 do
                sleep(10)
                i=i+1
            end

            msg = "Cámara en modo: "..tostring(capmode.get_name())
            table.insert(log, msg)

            if capmode.get() == 0 then
                msg = "ATENCION: No se pudo poner la cámara en 'record mode'"
                table.insert(log, msg)
            end
            msg = "tiempo de ejecución: "..tostring(i * 10).." mseg."
            table.insert(log, msg)
        else
            msg = "::cámara ya está en 'record mode'::"
            table.insert(log, msg)
        end
    elseif opts.to_mode == 'play' then
        if rec == false then
            msg = "::cámara ya está en 'play mode'::"
            table.insert(log, msg)
        else
            -- Set the camera to play mode
            switch_mode_usb(0)
            sleep(100)

            local i=0
            local capmode = require'capmode'

            while get_mode() == true and i < 300 do
                sleep(10)
                i=i+1
            end
            
            msg = "Cámara en modo: "..tostring(capmode.get_name()).." (get_mode = "..tostring(get_mode())..")"
            table.insert(log, msg)
            
            if capmode.get() == 1 then
                msg = "ATENCION: No se pudo poner la cámara en 'play mode'"
                table.insert(log, msg)
            end
            msg = "tiempo de ejecución: "..tostring(i * 10).." mseg."
            table.insert(log, msg)
        end
    end
    
    sleep(200)
    
    return format_log(log, opts.log_format)
end

function dc_set_zoom(opts, log)
    local opts = opts or {}
    local log = log or {}
    local msg = ''
    
    if opts.zoom_pos then
        local actual_zoom = get_zoom()
        msg = 'Valor de zoom actual: '..tostring(actual_zoom)
        table.insert(log, msg)
        
        local max_zoom = get_zoom_steps()
        msg = 'Valor de zoom máximo: '..tostring(max_zoom)
        table.insert(log, msg)
        
        if max_zoom ~= 'nil' and tonumber(opts.zoom_pos) > tonumber(max_zoom) then
            msg = 'Valor de zoom invalido '
                ..tostring(opts.zoom_pos)
                ..' (mayor al límite máximo)'
            table.insert(log, msg)
        elseif opts.zoom_pos == actual_zoom then
            msg = '::no se necesita ajustar el zoom::'
            table.insert(log, msg)            
        else
            set_zoom(opts.zoom_pos)
            msg = 'Ajustando zoom a: '..tostring(opts.zoom_pos)
            table.insert(log, msg)
            if opts.zoom_sleep ~= nil and tonumber(opts.zoom_sleep) > 0 then
                sleep(opts.zoom_sleep)
            else
                sleep(1000)
            end
        end
    end
    
    return format_log(log, opts.log_format)
end

function dc_refocus(opts, log)
    local opts = opts or {}
    local log = log or {}
    local msg, focus_state
    local focus_init_sleep = 100

    if opts.aflock ~= 'already_unlock' then
        sleep(150)
        set_aflock(0) 
        sleep(150)
    else
        msg = "::foco ya liberado::"
        table.insert(log, msg)
    end
    
    print('enfocando:')
    press('shoot_half')
    sleep(focus_init_sleep)
        
    local i=0
    while not get_shooting() do
        sleep(10)
       if i > 300 then
            break
       end
       i=i+1
    end

    sleep(150)
    set_aflock(1)
    sleep(150)

    release('shoot_half')
    sleep(150)
    
    focus_state = get_focus_state()
    print("debug get_focus_state()")

    if focus_state > 0 then
        msg = "focus_state: ".."focus successful ("..tostring(focus_state)..")"
        print(msg)
        table.insert(log, msg)
    elseif focus_state == 0 then
        msg = "focus_state: ".."focus not successful ("..tostring(focus_state)..")"
        print(msg)
        table.insert(log, msg)
    elseif focus_state < 0 then
        msg = "focus_state: ".."manual focus ("..tostring(focus_state)..")"
        print(msg)
        table.insert(log, msg)
    end
    
    msg = "tiempo de ejecución: "..tostring(i * 10 + focus_init_sleep).." mseg."
    print(msg)
    table.insert(log, msg)

    msg = "::foco fijado::"
    print(msg)
    table.insert(log, msg)
--
    if focus_state == 0 then
        play_sound(6); sleep(200)
    else
        sleep(200)
        play_sound(4); sleep(150); play_sound(4); sleep(150); play_sound(4)
        sleep(200) 
    end
--
    return format_log(log, opts.log_format)
end

function dc_expo_info()

    local aperture = { value = get_av96() }
    aperture.label = "Aperture in APEX96"
    aperture.funcn  = "get_av96"

    sleep(100)
    
    local brightness = { value = get_bv96() }
    brightness.label = "Brightness in APEX96"
    brightness.funcn  = "get_bv96"

    sleep(100)

    local speed = { value = get_sv96() }
    speed.label = "Speed in APEX96"
    speed.funcn  = "get_sv96"

    sleep(100)
    
    local timev = { value = get_tv96() }
    timev.label = "Time in APEX96"
    timev.funcn  = "get_tv96"
    timev.help = "Time Value (shutter speed) of the camera in APEX96 units."

    sleep(100)

    local realiso = { value = get_iso_real() }
    realiso.label = "Real 'value' ISO"
    realiso.funcn  = "get_iso_real"

--
    play_sound(4)
    sleep(100) 
--    
    return serialize( {aperture, brightness, speed, timev, realiso} )    
    
end

function dc_focus_info()

    local focus_state = { value = get_focus_state() }
    focus_state.label = "Focus state"
    focus_state.funcn  = "get_focus_state"
    focus_state.desc = {
        { 0, "<", "MF (manual focus)" }, 
        { 0, "=", "not successful" }, 
        { 0, ">", "focus successful" }
    }
    sleep(100)
    
    local focus = { value = get_focus() }
    focus.units = "mm"
    focus.label = "Focus"
    focus.funcn  = "get_focus"
    sleep(100)

    local focus_mode = { value = get_focus_mode() }
    focus_mode.label = "Focus mode"
    focus_mode.funcn  = "get_focus_mode"
    focus_mode.desc = {
        { 0, "=", "Auto" },
        { 1, "=", "MF - Manual Focus" },
        { 3, "=", "Infinite" },
        { 4, "=", "Macro" },
        { 5, "=", "Supermacro" }
    }
    sleep(100)

    local IS_mode = { value = get_IS_mode() }
    IS_mode.label = "IS mode"
    IS_mode.funcn  = "get_IS_mode"
    IS_mode.desc = {
        { 0, "=", "Continous" },
        { 2, "=", "Shoot only" },
        { 3, "=", "Panning" },
        { 4, "=", "Off" },
    }
    -- older cams -> 0 continous, 1 shoot only, 2 panning, 3 off
    sleep(100)

    local over_modes = { value = get_sd_over_modes() }
    over_modes.label = "SD over modes"
    over_modes.funcn  = "get_sd_over_modes"
    -- TODO comparar bits "0x01|AutoFocus,0x02|AFL,0x04|MF (manual focus)"
    sleep(100)
        
    local dofinfo = get_dofinfo()
    
    local dof = { value = dofinfo.dof }   
    dof.units = "mm"
    dof.label = "Depth of sharpness"
    dof.funcn  = "get_dofinfo"
    
    sleep(100)
          
    local nearl = { value = dofinfo.near }
    nearl.units = "mm"
    nearl.label = "Near limit"
    nearl.funcn  = "get_near_limit"
    -- nearl.help = "The closest distance that is within the range of acceptable sharpness."
    
    sleep(100)
    
    local farl = { value = dofinfo.far }
    farl.units = "mm"
    farl.label = "Far limit"
    farl.funcn  = "get_far_limit"
    -- farl.help = "The maximum distance of acceptable sharpness."

    sleep(100)
--
    play_sound(4)
    sleep(100) 
--    
    return serialize( {focus, focus_state, focus_mode, IS_mode, over_modes, dof, nearl, farl} )

end

