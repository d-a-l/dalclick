
-- TODO dejar aqui solo las funciones de control de camaras, llevar a otro lado las que manejan
-- filtros posteriores (rotar etc.)
-- # # # # # # # # # # # # # # # # # # # # # SINGLE CAM # # # # # # # # # # # # # # # # # # # # # # # # # # #

local cam = {}

function cam:switch_mode(lcon,mode)
    if mode == "play" or mode == "rec" then
        local opts = {
            to_mode = mode,
            log_format = "serialized"
        }
        local status, data = lcon:execwait('return dc_set_mode('..util.serialize(opts)..')',{libs={'dalclick_utils', 'serialize'}})
        return status, data
    end
    print(" ERROR: mode: "..tostring(mode))
    return false
end

function cam:identify_cam(lcon)

    local opts = {
        left_fn = current_project.dalclick.left_cam_id_filename,
        right_fn = current_project.dalclick.right_cam_id_filename,
        odd = current_project.dalclick.odd_name,
        even = current_project.dalclick.even_name,
        single = current_project.dalclick.single_name,
    }
    local status, idname, err = lcon:execwait('return dc_identify_cam('..util.serialize(opts)..')',{libs={'identify_utils'}})
    if status then
        return status, idname, err
    else
        if err then
            return status, idname, err
        else
            return status, false
        end
    end
end

function cam:refocus_cam(lcon)
    local opts = {
        log_format = "serialized"
    }
    -- -- --
    local status, data = lcon:execwait('return dc_refocus('..util.serialize(opts)..')',{libs={'dalclick_utils','serialize'}})
    -- -- --
    if status then
        return true, data
    else
        local err = data
        return status, err
    end
end


function cam:get_zoom(lcon)

    local status, var1, var2 = lcon:execwait('return get_zoom()')
    if status then
        return status, var1, var2
    else
        if var2 then
            return status, false, var2
        else
            return status, false, var1
        end
    end
end

function cam:set_zoom(lcon)
    if type(current_project.state.zoom_pos) ~= 'number' then
        return false, "error: current_project.state.zoom_pos is not number!\n"
    end
    print("  fijando zoom a '"..current_project.state.zoom_pos.."' en la cámara '"..lcon.idname.."'...")
    -- status, var1 = lcon:execwait('return set_zoom('..current_project.state.zoom_pos..')')
    local opts = {
	    zoom_pos = current_project.state.zoom_pos,
	    -- zoom_sleep = 1000
	    log_format = "serialized"
    }
    local status, data = lcon:execwait('return dc_set_zoom('..util.serialize(opts)..')',{libs={'dalclick_utils', 'serialize'}})

    if status then
        return true, data
    else
        err = data
        return status, err
    end
end

function cam:init_cam(lcon, zoom)
-- set focus, zoom, and rec mode
    local opts = {}
    opts.log_format = 'serialized'
    if zoom ~= nil then
        opts.zoom_pos = zoom
    end
    if not lcon:is_connected() then
        print(" Atención: cámara desconectada")
        printf(" reconectando...")
        local status, err = lcon:connect()
        if status then
            print("OK")
        else
            print(' no se pudo conectar ('..'bus: '..tostring(lcon.condev.bus)..', dev: '..tostring(lcon.condev.dev))
            return false
        end
    end
    os.execute("sleep 0.3")
    local status, var = lcon:execwait('return dc_init_cam_alt('..util.serialize(opts)..')',{libs={'dalclick_utils', 'serialize'}})
    return status, var
end

function cam:get_cam_info(lcon, option)

    if not lcon:is_connected() then return false end

    if option == "focus" then
        command = 'return dc_focus_info()'
    elseif option == "expo" then
        command = 'return dc_expo_info()'
    else
        return nil
    end
    -- -- --
    local status, data = lcon:execwait(command,{libs={'dalclick_utils','serialize'}})
    -- -- --
    if not status then
        err = data
        return false, err
    elseif type(data) ~= 'string' then
        return false, "return data error or no data!"
    else
        return true, data
    end

end

return cam
