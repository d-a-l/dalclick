--[[
  Copyright (C) 2013 <juan at derechoaleer dot org>
  http://liberatorium.derechoaleer.org

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

]]

--[[
    DISCLAIMER:
    - I'm not developer
    - not know much about OO
]]

--[[
= enable disable automount in gnome desktop

disable

gsettings set org.gnome.desktop.media-handling automount "false"
gsettings set org.gnome.desktop.media-handling automount-open "false"

enable

gsettings set org.gnome.desktop.media-handling automount "true"
gsettings set org.gnome.desktop.media-handling automount-open "true"

= chdkptp command 

# en chdkptp
export LUA_PATH="./lua/?.lua;../dalclick/?.lua"
./chdkptp -e"exec mc=require('dalclick')" -e"exec return dc:main()"

gnome-terminal -e /opt/src/dalclick/dalclick

]]


dcutls = require('dcutls')
local rsalt = require('rsalt')
local p = require('project')

local defaults={
    -- qm_sendcmd_path = "/opt/src/dalclick/qm/qm_sendcmd.sh",
    -- qm_daemon_path = "/opt/src/dalclick/qm/qm_daemon.sh",
    -- empty_thumb_path = "/opt/src/dalclick/empty_g.jpg",
    -- empty_thumb_path_error = "/opt/src/dalclick/empty.jpg", --TODO debug!
    root_project_path = nil, -- -- main(DALCLICK_PROJECTS)
    left_cam_id_filename = "LEFT.TXT",
    right_cam_id_filename = "RIGHT.TXT",
    odd_name = "odd",
    even_name = "even",
    all_name = "all",
    raw_name = "raw",
    proc_name = "pre", -- processed
    doc_name = "done", -- destino final (pdf, epub, djvu, etc.)
    doc_filebase = "output",
    doc_fileext = "pdf",
    test_name = 'test',
    img_match = "%.JPG$", -- lua exp to match with images in the camera
    folder_match = "^%d", -- lua exp to match with camera folders (las que empiezan con un numero)
    capt_pre = "IMG_",
    capt_ext = "JPG",
    capt_type = 'S', -- D=direct shoot S=standart
    rotate_odd = '-90',
    rotate_even = '90',
    tempfolder_name = '.tmp',
    thumbfolder_name = '.previews',
    test_high_name = '_high',
    test_low_name = '_low',
    mode_enable_qm_daemon = false,
    autorestore_project_on_init = true
    -- regnum = '',
}

defaults.doc_filename = defaults.doc_filebase.."."..defaults.doc_fileext 

defaults.paths = {}

defaults.paths.raw_dir = defaults.raw_name
defaults.paths.raw = {
    even = defaults.raw_name.."/"..defaults.even_name,
    odd =  defaults.raw_name.."/"..defaults.odd_name,
    all =  defaults.raw_name.."/"..defaults.all_name,
}
defaults.paths.proc_dir = defaults.proc_name
defaults.paths.proc = {
    even = defaults.proc_name.."/"..defaults.even_name,
    odd =  defaults.proc_name.."/"..defaults.odd_name,
    all =  defaults.proc_name.."/"..defaults.all_name,
}
defaults.paths.test_dir = defaults.test_name
defaults.paths.test = {
    even = defaults.test_name.."/"..defaults.even_name,
    odd =  defaults.test_name.."/"..defaults.odd_name,
    all =  defaults.test_name.."/"..defaults.all_name,
}
defaults.paths.doc_dir = defaults.doc_name

local state = {
    cameras_status = nil,
    menu_mode = 'standart',
    projects_selection = {},
}
local config = {
    zoom_persistent = true -- persistent zoom parameter on new projects
}

defaults.dc_config_path = nil -- main(DIYCLICK_HOME)

local dc={}      -- dalclick main functions
local cam={}     -- single cam functions
local mc={}      --  multicam functions
local batch={}   --  batch projects processing functions

local loopmsg = ""

-- ### Gnome automount ###

-- # # # # # # # # # # # # # # # # # # # # # SINGLE CAM # # # # # # # # # # # # # # # # # # # # # # # # # # # 

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
        left_fn = p.dalclick.left_cam_id_filename,
        right_fn = p.dalclick.right_cam_id_filename,
        odd = p.dalclick.odd_name,
        even = p.dalclick.even_name,
        all = p.dalclick.all_name,
    }
    local status, idname, err = lcon:execwait('return dc_identify_cam('..util.serialize(opts)..')',{libs={'dalclick_identify'}})
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
    if type(p.state.zoom_pos) ~= 'number' then
        return false, "error: p.state.zoom_pos is not number!\n"
    end
    print("  fijando zoom a '"..p.state.zoom_pos.."' en la cámara '"..lcon.idname.."'...")
    -- status, var1 = lcon:execwait('return set_zoom('..p.state.zoom_pos..')')
    local opts = { 
	    zoom_pos = p.state.zoom_pos,
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
    sys.sleep(300)
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

-- # # # # # # # # # # # # # # # # # # # # # SINGLE CAM # # # # # # # # # # # # # # # # # # # # # # # # # # # 

-- local funtions fro multicam

function print_cam_info(data, depth, item, opts)

    local depth = depth or 0
    if type(opts) ~= 'table' then opts = {} end
    local tab = string.rep(" ", depth * 5)

    if type(data) ~= 'table' then
        print(" -WTF?- ")
        return
    end
    
    for i,k in ipairs(data) do
        if type(k) == 'table' then
            -- recursion
            print_cam_info(k, depth + 1, i)
        else
            print(tab..tostring(k))
        end
    end
    
    local value_descriptor = ""
    if data.value then
        if type(data.desc) == 'table' then
            for i,k in ipairs(data.desc) do
                local compare_val = k[1]
                local opp = k[2]
                local description = k[3]
                if data.value ~= nil and type(data.value) == type(compare_val) then
                    if opp == "=" then
                        if data.value == compare_val then
                            value_descriptor = value_descriptor..tostring(description).." "
                        end
                    elseif opp == "<" then
                        if data.value < compare_val then
                            value_descriptor = value_descriptor..tostring(description).." "
                        end
                    elseif opp == ">" then
                        if data.value > compare_val then
                            value_descriptor = value_descriptor..tostring(description).." "
                        end
                    end
                end
            end    
        end

        data.funcn = data.funcn or item
        data.label = data.label or data.funcn
        data.units = data.units or ""
        data.alt_value = data.alt_value or ""
        data.alt_units = data.alt_units or ""
        
        --
        if value_descriptor ~= "" then
            printf (tab..tostring(data.label)..": "..value_descriptor.." ("..tostring(data.value)..")")
        else
            printf (tab..tostring(data.label)..": "..tostring(data.value)..tostring(data.units))
        end
        if data.alt_value ~= "" then
            print ("( "..tostring(data.alt_value)..tostring(data.alt_units).." )")
        else
            printf("\n")
        end
        -- if data.help and opts.print_help == true then
        if data.help then
            print (tab..tostring(data.help))
        end
    end 
end

-- multicam functions

function mc:camsound_plip()
    if type(self.cams) ~= 'table' then
        return false
    end
    if not next(self.cams) then
        return nil
    end

    for i, lcon in ipairs(self.cams) do
        if lcon:is_connected() then
        else
            print()
            print(" Atención: cámara desconectada ["..i.."]")
            printf(" reconectando...")
            local status, err = lcon:connect()
            if status then
                print("OK")
            else
                print(' FALLÓ ('..'bus: '..tostring(lcon.condev.bus)..', dev: '..tostring(lcon.condev.dev)..")")
                return nil
            end
        end
    end
    
    for i,lcon in ipairs(self.cams) do
        lcon:exec("play_sound(2)")
        sys.sleep(200) -- avoid running simultaneously
    end
    return true
end

function mc:camsound_pip()
    for i,lcon in ipairs(self.cams) do
        lcon:exec("play_sound(4)")
        sys.sleep(200)
    end
end

function mc:camsound_pip_pip_pip()
    for i,lcon in ipairs(self.cams) do
        lcon:exec("play_sound(4); sleep(150); play_sound(4); sleep(150); play_sound(4); sleep(150)")
        sys.sleep(400)
    end
end

function mc:camsound_ref_cam()
    for i,lcon in ipairs(self.cams) do
        if lcon.idname == p.settings.ref_cam then
            print("camara de referencia: '"..p.settings.ref_cam.."'")
            lcon:exec("play_sound(4); sleep(150); play_sound(4); sleep(150); play_sound(4); sleep(150)")
            sys.sleep(400)
        end
    end
end

function mc:check_errors_all()
    -- from multicam.lua mc:check_errors
    for i,lcon in ipairs(self.cams) do
        local msg,err=lcon:read_msg()
        if msg then
            if msg.type ~= 'none' then
                if msg.script_id ~= lcon:get_script_id() then
                    warnf("%d: message from unexpected script %d %s\n",i,msg.script_id,chdku.format_script_msg(msg))
                elseif msg.type == 'user' then
                    warnf("%d: unexpected user message %s\n",i,chdku.format_script_msg(msg))
                elseif msg.type == 'return' then
                    warnf("%d: unexpected return message %s\n",i,chdku.format_script_msg(msg))
                elseif msg.type == 'error' then
                    warnf('%d:%s\n',i,msg.value)
                else
                    warnf("%d: unknown message type %s\n",i,tostring(msg.type))
                end
            end
        else
            warnf('%d:read_msg error %s\n',i,tostring(err))
        end
    end
end
    
function mc:switch_mode_all(mode)
    local setmode_fail = false
    for i,lcon in ipairs(self.cams) do
        print(" ["..i.."] Poniendo en modo '"..tostring(mode).."'")
        local status, data = cam:switch_mode(lcon, mode)
        if status then
            local arr_data = util.unserialize(data)
            if type(arr_data) ~= 'table' then
                print(" "..tostring(arr_data))
            else
                print_cam_info(arr_data, 1, '')
            end
        else
            local err = data
            print(" ERROR: "..tostring(err))
            setmode_fail = true
            break
        end
    end
    if setmode_fail then
        return false
    else
        return true        
    end
end

function format_focus_info(focus_info)
    return tostring(focus_info)
end

function mc:get_zoom_from_ref_cam()
    for i,lcon in ipairs(self.cams) do
        if lcon.idname == p.settings.ref_cam then
            local status, zoom_pos, err = cam:get_zoom(lcon)
            if type(zoom_pos) ~= 'boolean' and status then
                return true, tonumber(zoom_pos)
            else
                return false, false, err
            end
        end
    end
    return false, false, "No se encontró la cámara de referencia '"..p.settings.ref_cam.."'."
end


function mc:set_zoom_other()
    for i,lcon in ipairs(self.cams) do
        if lcon.idename ~= p.settings.ref_cam then
            print(" ["..i.."] fijando zoom")
            local status, data = cam:set_zoom(lcon)
            if status then
                local arr_data = util.unserialize(data)
                if type(arr_data) ~= 'table' then
                    print(" "..tostring(arr_data))
                else
                    print_cam_info(arr_data, 1, '')
                end
            else
                print(" error: no se pudo fijar el zoom en la otra cámara")
                return false
            end
            print(" ["..i.."] reenfocando")
            local status, data = cam:refocus_cam(lcon)
            if status then
                local arr_data = util.unserialize(data)
                if type(arr_data) ~= 'table' then
                    print(" "..tostring(arr_data))
                else
                    print_cam_info(arr_data, 1, '')
                end
                return true
            else
                print(" error: no se pudo enfocar luego de ajustar el zoom")
                return false
            end            
        end
    end
    return false
end

function mc:get_cam_info(option)
    if option == nil then
        print(" ERROR: mc:get_cam_info() no option param")
        return false
    end
    
    for i,lcon in ipairs(self.cams) do
        local status, data = cam:get_cam_info(lcon, option)
        if status then
            print(" ["..i.."] Show cam info ("..option..")")
            local arr_data = util.unserialize(data)
            if type(arr_data) ~= 'table' then
                print(" "..tostring(arr_data))
            else
                print_cam_info(arr_data, 0, option)
            end
        else
            local err = data
            print(" ["..i.."] ERROR! mensaje recibido desde la cámara:")
            print(" "..tostring(err))
        end 
        print()
    end
    return true
end

function mc:refocus_cam_all()
    local refocus_fail = false
    local info = ""
    for i,lcon in ipairs(self.cams) do
        local status, data = cam:refocus_cam(lcon)
        if not status then
            local err = data
            print("status: "..tostring(status)..", err: "..tostring(err))
            refocus_fail = true
        else
            print(" ["..i.."] Refocus script log:")
            local arr_data = util.unserialize(data)
            if type(arr_data) ~= 'table' then
                print(" "..tostring(arr_data))
            else
                print_cam_info(arr_data, 1, '')
            end
            print()
        end
    end
    if refocus_fail then
        return false, info
    else
        self:get_cam_info('focus')
        print(" Presione <enter> para continuar...")
        local key = io.stdin:read'*l'
        return true, info        
    end
end

function mc:check_cam_connection()
    if type(self.cams) == 'table' then
        for i, lcon in ipairs(self.cams) do
            if lcon:is_connected() then
                print(" ["..i.."] verificando...OK")
            else
                print(" ["..i.."] Atención: cámara desconectada")
                printf("     reconectando...")
                local status, err = lcon:connect()
                if status then
                    print("OK")
                else
                    print(' FALLÓ ('..'bus: '..tostring(lcon.condev.bus)..', dev: '..tostring(lcon.condev.dev))
                    return false
                end
            end
        end
        if not next(self.cams) then
            return nil
        end
        print()
        return true
    else
        return false
    end
end

function mc:connect_all()
    local connect_fail = false
    local devices = chdk.list_usb_devices()

    self.cams={}
    if not next(devices) then
        -- print(" Aparentemente no hay cámaras conectadas al equipo\n")
        return false
    end
    for i, devinfo in ipairs(devices) do
        if i > 2 then
            print(" hay mas de dos dispositivos detectados!")
            return false
        end
        local lcon,msg = chdku.connection(devinfo)
        -- if not already connected, try to connect
        if lcon:is_connected() then
            lcon:update_connection_info()
        else
            local status,err = lcon:connect()
            if not status then
                warnf('%d: connect failed dev:%s, bus:%s, err:%s\n',i,devinfo.dev,devinfo.bus,tostring(err))
                connect_fail = true
            end
        end
        -- if connection didn't fail
        if lcon:is_connected() then
            printf(' %d:%s bus=%s dev=%s sn=%s\n',
                i,
                lcon.ptpdev.model,
                lcon.condev.bus,
                lcon.condev.dev,
                tostring(lcon.ptpdev.serial_number))
            lcon.mc_id = string.format('%d:%s',i,lcon.ptpdev.model)
            lcon.sn = tostring(lcon.ptpdev.serial_number)
            -- -- --
            table.insert(self.cams,lcon)
            -- -- --
        end
    end
    print()
    if connect_fail then
        return false
    else
        return true
    end
end

function mc:shutdown_all()
    local shutdown_fail = false
    for i,lcon in ipairs(self.cams) do

        local status,err=lcon:exec('sleep(1000); shut_down()',{clobber=true})
        lcon:disconnect() -- disconnect camera while responding?
        if not status then
            shutdown_fail = true
            printf("[%i] ERROR: no se pudo apagar la cámara\n", i, err)
        end
    end
    if shutdown_fail then
        return false
    else
        return true
    end
end

function mc:init_cams_all()
   
    -- comprubea que haya conexion
    
    print("\n Verificando conexión cámaras:")
    local status = self:check_cam_connection()
    if not status then
        if status == false then
            print(" Reiniciar conexión...")
        else
            print(" Iniciar conexión...")
        end
        if not self:connect_all() then
            print(" falló el intento de conectarse a las cámaras")
            return false
        end
    end
    
    -- comprueba que haya dos camaras, una "odd" y otra "even"
    local init_fail = false
    local init_fail_err = ""
    local idnames = {}
    local count_cams = 0
    print(" Identificando cámaras")
    for i,lcon in ipairs(self.cams) do
        count_cams = count_cams + 1
        local status, idname, err = cam:identify_cam(lcon)
        if idname then
            if (idname ~= 'odd' and idname ~= 'even') then
                print(" ["..i.."] no se puede inicializar: alguna de las cámaras no están correctamente identificadas")
                print("           idname = "..tostring(idname))
                init_fail = true
                break
            end
            idnames[count_cams] = idname
            print(" ["..i.."] idname: "..tostring(idname))
            lcon.idname = idname
        else
            print(" ["..i.."] no se puedo inicializar:")
            print("           status: "..tostring(status).." err: "..tostring(err))
            init_fail = true
            break
        end
    end

    if type(idnames[1]) == 'string' and type(idnames[2]) == string then    
        if idnames[1] == idnames[2] then
            print(" ATENCION: las dos cámaras estan identificadas con el mismo nombre: '"
            ..idnames[1].."' y '"..idnames[2].."'")
            init_fail = true
        end
    end
    
    if count_cams == 1 then
        print()
        print(" Atención! Solo hay una cámara conectada")
        print()
        init_fail = true
    elseif count_cams == 0 then
        print()
        print(" Atención! No hay cámaras conectadas!")
        print()
        init_fail = true
    end
    print()
    
    if init_fail then return false end

    -- inicio de camaras

    -- check SD
    print()
    local check_status = mc:check_sdcams_options() 
    if check_status == 'exit' then
        print(" Apagando cámaras...")
        if not mc:shutdown_all() then
            print("alguna de las cámaras deberá ser apagada manualmente")
        end
        sys.sleep(1000)
        return 'exit'
    elseif check_status == false then
        print(" debug: check_sdcams_options() = false")
        return false
    end
    
    -- set cams
    --
    print()   
    if type(p.state.zoom_pos) ~= "number" then
        p.state.zoom_pos = nil
        if not p:save_state() then
            print(" error de lectura: No se pudieron guardar las variables del estado del contador en el disco (3)")
            return false
        end
    end
    
    for i,lcon in ipairs(self.cams) do
        print(" ["..i.."] preparando cámara:")
        local status, var = cam:init_cam(lcon, p.state.zoom_pos)
        if status then
            local arr_data = util.unserialize(var)
            if type(arr_data) == 'table' then
                print_cam_info(arr_data, 1, '')
            else
                print(" ! "..tostring(arr_data))
                print(" ATENCION: reinicie nuevamente las cámaras antes de comenzar!")
            end
            print()
        else
            init_fail = true
            init_fail_err = var
            break
        end
    end    
    print()
    --
    if init_fail then
        print(" Alguna de las cámaras ha fallado, por favor apagarlas y volverlas a encender.\n")
        print(" -> "..tostring(init_fail_err))
        return false
    end
    return true
end

function mc:check_sdcams_options()

    local empty = true
    local menu = [[
 ====================================================================
 ATENCION: Se recomienda borrar todas las imágenes contenidas en las 
 tarjetas SD de las cámaras antes de comenzar.
 ====================================================================

 opciones:

 [enter] para borrar todas las imágenes
 [c] para continuar sin borrar
 [e] para salir de dalclick ahora
 
]]

    print(" Verificando tarjetas SD..")
    local status, data = mc:check_if_sdcams_are_empty()
    if status then
        for i, adata in pairs(data) do
            if adata.count > 0 then
                print(" ["..i.."] no está vacía: "..tostring(adata.count).." archivo/s.")
                empty = false
            else
                print(" ["..i.."] vacía: "..tostring(adata.count))
            end
        end
    else
        print(" ERROR: no se pudo verificar si las tarjetas SD estan vacías")
    end

    if not empty then
        print()
        while true do

            print(menu)
            printf(" >> ")
            local key = io.stdin:read'*l'
            print()

            if key == "" then
                -- borrar
                print(" \nborrando....")
                local edata = mc:empty_sdcams()
                if type(edata) == 'table' and next(edata) then
                    for i, data in pairs(edata) do
                        if data.status then
                            print(" ["..i.."] eliminados "..data.count.." archivos:")
                            print(data.removed_files)
                            if data.err_log ~= "" then
                                print(" se produjeron errores al intentar borrar achivos en:")
                                print(data.err_log)
                            end
                        else
                            print(" ["..i.."] ERROR: no pudieron borrarse archivos.")
                        end
                    end
                else
                    print(" ERROR: no pudieron borrarse archivos.")
                end
                return true
            elseif key == "c" then
                return true
            elseif key == "e" then
                return 'exit'
            end            
            print(" no ha seleccionado ninguna opción válida!")
            print()
        end
    end
    
    -- print(" OK")
    return true
end

function mc:rotate_all()
    local command, path
    local rotate_fail = false
    for idname,saved_file in pairs(p.state.saved_files) do
        -- saved_files[lcon.idname] = {
        -- saved_file.path
        -- path = local_path..file_name
        -- basepath = local_path
        -- basename = file_name
        command = "econvert -i "..saved_file.path.." --rotate "..p.state.rotate[idname].." -o "..p.session.base_path.."/"..p.paths.proc[idname].."/"..saved_file.basename.." > /dev/null 2>&1"
        
        if defaults.mode_enable_qm_daemon then
            print(" ["..idname.."] enviando comando (rotar) a la cola de acciones") 
            if not os.execute(p.dalclick.qm_sendcmd_path..' '..p.session.base_path.."/"..p.paths.raw[idname]..' "'..command..'"') then
               print(" error: falló: "..p.dalclick.qm_sendcmd_path..' '..p.session.base_path.."/"..p.paths.raw[idname]..' "'..command..'"')
               rotate_fail = true
            end
        else
            printf(" ["..idname.."] rotando("..saved_file.basename..")...") -- sin testear!!
            if not os.execute(command) then
                print("ERROR")
                print("     falló: '"..command.."'")
                rotate_fail = true
            else
                print("OK")
            end
        end
    end
    if rotate_fail then
        return false
    else
        return true
    end
end

function mc:rotate_and_resize_all()
    local command, path
    local rotate_fail = false
    for idname,saved_file in pairs(p.state.saved_files) do
        local thumbpath = p.session.base_path.."/"..p.paths.proc[idname].."/"..p.dalclick.thumbfolder_name
        if not dcutls.localfs:file_exists( thumbpath ) then
            if not dcutls.localfs:create_folder( thumbpath ) then
                print(" ERROR: no se pudo crear '"..thumbpath.."'")
                return false
            end
        end
        command = 
            "econvert -i "..saved_file.path
          .." --rotate "..p.state.rotate[idname]
          .." -o "..p.session.base_path.."/"..p.paths.proc[idname].."/"..saved_file.basename
          .." --thumbnail ".."0.125"
          .." -o "..thumbpath.."/"..saved_file.basename
          .." > /dev/null 2>&1"
        if defaults.mode_enable_qm_daemon then
            print(" ["..idname.."] enviando de comando de procesamiento a la cola de acciones ("..saved_file.basename..").") 
            if not os.execute(p.dalclick.qm_sendcmd_path..' '..p.session.base_path.."/"..p.paths.raw[idname]..' "'..command..'"') then
                print(" error: falló: "..p.dalclick.qm_sendcmd_path..' '..p.session.base_path.."/"..p.paths.raw[idname]..' "'..command..'"')
                rotate_fail = true
            end
        else
            printf(" ["..idname.."] rotando y generando vista previa ("..saved_file.basename..")...") 
            if not os.execute(command) then
                print("ERROR")
                print("    falló: '"..command.."'")
                rotate_fail = true
            else
                print("OK")
            end
        end
    end
    if rotate_fail then
        return false
    else
        return true
    end
end

function mc:check_if_sdcams_are_empty()

    local out = {}
    for i,lcon in ipairs(self.cams) do
        local status, count, err = lcon:execwait([[
    dir = os.listdir("A/DCIM")
    sleep(100)
    count = 0
    if dir then
        for n, dname in ipairs(dir) do
            if string.match(dname,"^%d") then
                files = os.listdir("A/DCIM/"..dname)
                if files then
                    for n, fname in ipairs(files) do
                        if string.match(fname,"%.JPG$") then
                            count = count + 1
                        end
                    end
                end
            end
        end
    end

    return count
        ]] )
        if not status then
            return false, err
        end
        -- print(" mcdebug "..tostring(status)..", "..tostring(count)..", "..tostring(err))
        sys.sleep(100)
        out[i] = { count = tonumber(count), err = err }
    end
    return true, out
end

function mc:empty_sdcams()

    local out = {}
    for i,lcon in ipairs(self.cams) do
        local status, count, removed_files, err_log, err = lcon:execwait([[
dir = os.listdir("A/DCIM")
sleep(100)
count = 0
removed_files = ""
err_log = ""
if dir then
    for n, dname in ipairs(dir) do
        if string.match(dname,"^%d") then
            files = os.listdir("A/DCIM/"..dname)
            if files then
                for n, fname in ipairs(files) do
                    if string.match(fname,"%.JPG$") then
                        if os.remove("A/DCIM/"..dname.."/"..fname) then
                            count = count + 1
                            removed_files = removed_files.."   A/DCIM/"..dname.."/"..fname.."\n"
                        else
                            err_log = err_log.."   error: 'A/DCIM/"..dname.."/"..fname.."' can't be removed".."\n"
                        end
                    end
                end
            end
        end
    end
end

return count, removed_files, err_log
        ]] )
        sys.sleep(100)
        out[i] = { status = status, count = count, removed_files = removed_files, err_log = err_log }
    end
    return out
end

function mc:capt_all(mode)

    if p:load_state_secure() then
        if p.dalclick.capt_type == 'D' then
            -- TODO ojo cambio saved file!!! corregir!
            local shoot_fail, break_main_loop, saved_files = rsalt:direct_raw_shoot_all(p.dalclick, p.settings, p.state, self.cams)
            if not shoot_fail then
                p:counter_next()
                if p:save_state() then
                    print("OK")
                    mc:preprocess_raw( saved_files )
                else
                    print(" error de lectura: no se pudo guardar el estado del contador")
                end
            else
                print(" se produjeron errores en la captura en alguna de las cámaras")
                if break_main_loop then
                    return false
                end
            end
        else -- 'S' capt_type
            local shoot_fail, break_main_loop = mc:shoot_and_download_all(mode)
            if not shoot_fail then
                if mode == 'test' then
                    print(" modo test: contador desactivado")
                else
                    p:counter_next()
                    if not p.session.counter_max.odd or p.state.counter.odd > p.session.counter_max.odd then
                        p.session.counter_max = p.state.counter
                    end
                end
                if p:save_state() then
                    -- print(" Guardando estado actual del proyecto .. OK")
                    --print("DEBUG p.state.counter:\n"..util.serialize(p.state.counter))
                    --print("DEBUG p.state.zoom_pos:\n"..util.serialize(p.state.zoom_pos))
                    -- mc:rotate_all( saved_files )
                    if p.state.saved_files and p.settings.rotate == true then
                        if mc:rotate_and_resize_all() then
                        else
                            print(" Error: alguna de las imágenes no pudo ser rotada")
                            return false
                        end
                    end

                else
                    print("error de lectura: no se pudieron guardar las variables de estado en el disco (1)")
                end
            else
                print("se produjeron errores en la captura en alguna de las cámaras")
                if break_main_loop then
                    return false
                end
            end
        end
        return true
    else
        print("error de lectura: no se pudieron guardar las variables de estado en el disco (2)")
        return false
    end
end

function mc:capt_all_test_and_preview()

    if p:load_state_secure() then

        local shoot_fail, break_main_loop, saved_files = mc:shoot_and_download_all('test')
        if not shoot_fail then
            -- rotar y resize a test_paths test_preview_high.jpg test_preview_low.jpg
            if type(saved_files) ~= 'table' then
                print(" ERROR al intentar realizar la vista previa")
                return true
            end
            -- process captured test
            local command_fail = false
            local command_paths = {}
            local previews = {}
            for idname, saved_file in pairs(saved_files) do
                command_paths[idname] = {
                    src_path  =
                        p.session.base_path.."/"..p.paths.test[idname]
                        .."/"..saved_file.basename_without_ext..".jpg",
                    high_path =  
                        p.session.base_path.."/"..p.paths.test[idname]
                        .."/"..saved_file.basename_without_ext..defaults.test_high_name..".jpg",
                    low_path  =
                        p.session.base_path.."/"..p.paths.test[idname]
                        .."/"..saved_file.basename_without_ext..defaults.test_low_name..".jpg"
                }
                               
                local command = 
                    "econvert"
                  .." -i "..command_paths[idname].src_path
                  .." --rotate "..p.state.rotate[idname]
                  .." -o "..command_paths[idname].high_path
                  .." --thumbnail ".."0.125"
                  .." -o "..command_paths[idname].low_path
                  .." > /dev/null 2>&1"

                printf(" Procesando test '"..saved_file.basename_without_ext.."'...")
                if not os.execute(command) then
                    print("ERROR")
                    print("    falló: '"..command.."'")
                    command_fail = true
                else
                    print("OK")
                    previews[idname] = command_paths[idname].low_path
                end
            end
            -- show preview
            
            if not command_fail then
                -- preview
                p:show_capts('show_test', previews, {odd = 'PREVIEW', even = 'PREVIEW'})
            end
            -- remove test paths if any
            for idname, paths in pairs(command_paths) do
                dcutls.localfs:delete_file(paths.src_path)
                dcutls.localfs:delete_file(paths.high_path)
                dcutls.localfs:delete_file(paths.low_path)
            end      
        else
            print("se produjeron errores en la captura en alguna de las cámaras")
            if break_main_loop then
                return false
            end
        end
    else
        print("error de lectura: no se pudieron guardar las variables de estado en el disco (2)")
        return false
    end
    
    return true
end

function mc:shoot_and_download_all(mode)

    for i,lcon in ipairs(self.cams) do
        if lcon.idname == nil then
            loopmsg = " Las cámaras no estan inicializadas!!\n Use la opción [i] para inicializar"
            return true, false
        end
    end

    for i,lcon in ipairs(self.cams) do
        local status, err = lcon:exec([[
if get_raw() then
    set_raw(0)
    sleep(100)
end
sleep(100)
press('shoot_full_only'); sleep(100); release('shoot_full')
]] )
        if not status then
            return true, false
        end
        sys.sleep(100)
    end
    --
    local delay = 2
    if p.settings.mode == 'secure' then
        delay = 8
    elseif p.settings.mode == 'normal' then
        delay = 4
    end
    print(" esperando "..delay.." s...")
    for n = 0,delay,1 do
        sys.sleep(1000)
        print(".")
    end
    --
    for i,lcon in ipairs(self.cams) do
        printf(" ["..i.."] obteniendo nombre de captura... ")
        status, lastdir, lastcapt, err = lcon:execwait([[
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
    ]]    )
        if lastdir and lastcapt then
            print(" A/DCIM/"..lastdir.."/"..lastcapt)
            lcon.remote_path = "A/DCIM/"..lastdir.."/"..lastcapt
            if p.state.saved_files then
                local prev_capt = p.state.saved_files[lcon.idname]
                if prev_capt.remote_path == lcon.remote_path then
                    print(" ======================================================")
                    print(" ATENCION: no se esta descargando la ultima captura!!!!")
                    print(" ======================================================")
                    print(" Vuelva a intentarlo...")
                    print(" Si el problema persiste pruebe en modo 'seguro' ó 'normal'.")
                    print(" Verifique que se estén borrando las imágenes de la tarjeta SD de la cámara.")
                    return true, false
                end
            end
        else
            print()
            print(" ATENCION: no se puedo obtener el nombre de la última captura") 
            print(" Vuelva a intentarlo...")
            print(" Si el problema persiste pruebe en modo 'seguro' ó 'normal'.")
            print()
            --"status: "..tostring(status)..", lastdir: "..tostring(lastdir)..", lastcapt: "..tostring(lastcapt)..", err: "..tostring(err))
            return true, false
        end
        sys.sleep(100)
    end
    --
    sys.sleep(300)
    --
   
    local download_fail = false
    local saved_files = {}
    for i,lcon in ipairs(self.cams) do
        --
        local local_path, file_name_we, file_name
        file_name_we = string.format("%04d", p.state.counter[lcon.idname])
        file_name = file_name_we..".".."jpg"
        
        if mode == 'test' then -- yyyy
            local_path = p.session.base_path.."/"..p.paths.test[lcon.idname].."/"
        else
            local_path = p.session.base_path.."/"..p.paths.raw[lcon.idname].."/"
        end
        --
        if not dcutls.localfs:file_exists( local_path..defaults.tempfolder_name ) then
            if not dcutls.localfs:create_folder( local_path..defaults.tempfolder_name ) then
                return false
            end
        end
        --
        printf(" ["..i.."] descargando... '"..lcon.remote_path.."' -> '"..file_name.."' ..")
        --
        local results,err = lcon:download(lcon.remote_path, local_path..defaults.tempfolder_name.."/"..file_name)
        --
        if results and dcutls.localfs:file_exists(local_path..defaults.tempfolder_name.."/"..file_name) then
            saved_files[lcon.idname] = {
                path = local_path..file_name,
                basepath = local_path,
                basename = file_name,
                basename_without_ext = file_name_we,
                remote_path = lcon.remote_path,
            }
            print("OK")
        else
            download_fail = true
            break
        end
    end
    --
    -- remove remote files
    for i,lcon in ipairs(self.cams) do
        if lcon.remote_path ~= "" and lcon.remote_path ~= nil then
            local status, err = lcon:execwait('os.stat("'..lcon.remote_path..'")')
            if status ~= nil then
                printf(" ["..i.."] borrando de la cámara: '"..lcon.remote_path.."' ..")
                local status, err = lcon:execwait('os.remove("'..lcon.remote_path..'")')
                if status ~= nil then
                    print("OK")
                else
                    print("     ATENCION: no se pudo borrar: '"..lcon.remote_path.."'")
                end
            else
                print("     ATENCION: '"..lcon.remote_path.. "' no existe")
            end
        end
    end
    --
    if download_fail then
        -- remove captures from temporal folder if any
        for idname, saved_file in pairs(saved_files) do
            if type(saved_file) == 'table' then
                if saved_file.basepath ~= nil then -- quiza esta sea redundante
                    local tmppath = saved_file.basepath..defaults.tempfolder_name.."/"..saved_file.basename
                    if dcutls.localfs:delete_file(tmppath) then
                        print(" eliminando descarga carpeta temporal..OK")
                    else
                        print(" ATENCION: no se pudo eliminar '"..tmppath.."'")
                    end
                end
            end
        end
        return true, false -- capture is not performed but main_loop can continue
    else
        -- move from temporal folder to permanent raw folder and update project state
        for idname, saved_file in pairs(saved_files) do
            if saved_file.basepath ~= nil then
                local tmppath = saved_file.basepath..defaults.tempfolder_name.."/"..saved_file.basename
                local permpath = saved_file.basepath..saved_file.basename
                
                if os.rename(tmppath, permpath) then
                    print(" ["..idname.."] moviendo '"..saved_file.basename.."' desde carpeta temporal..OK")
                else
                    print(" ERROR: no se pudo mover '"..tmppath.."' a '".. permpath.."'")
                    return true, true
                end
            end
        end
        if mode == 'test' then
            return false,false, saved_files
        else
            p.state.saved_files = saved_files
            return false, false
        end
    end
    --
end

function mc:preprocess_raw()

    print("TODO untested!!!")
    local outtype = 'tiff'
    local outdepth = 8
    local command

    for idname,saved_file in pairs(p.state.saved_files) do
        command = "ufraw-batch --rotate "..p.state.rotate[idname].." --out-type="..outtype.." --out-depth="..outdepth.." --out-path="..saved_file.basepath.." "..saved_file.path
        print(command)
    end
end

-- # # # # # # # # # # # # # # # # # # # # # BATCH # # # # # # # # # # # # # # # # # # # # # # # # # # # 

local function count_files(folder)
    if dcutls.localfs:file_exists( folder ) then
        local count = 0
        for f in lfs.dir( folder ) do
            if lfs.attributes( folder.."/"..f, "mode") ~= "directory" then
                count = count + 1
            end
        end
        return count
    end
    return false
end
    
function batch:show_projects( projects )

    local paths = defaults.paths
    for index, project in pairs(projects) do    
        local content = dcutls.localfs:read_file(project.settings_path)
        if content then
            local settings = util.unserialize(content)
            settings = type(settings) == 'table' and settings or {}
            
            local stat_raw = 'raw: '
            if type(paths.raw) == 'table' then
                if paths.raw.even then
                    local c = count_files( project.path.."/"..paths.raw.even )
                    if c then
                        stat_raw = stat_raw..tostring(c)
                    end
                end
                if paths.raw.odd then
                    local c = count_files( project.path.."/"..paths.raw.odd )
                    if c then
                        stat_raw = stat_raw.."/"..tostring(c).." "
                    end
                end
            end        
            local margin = 16 - string.len(string.sub(stat_raw, 0, 16))             
            stat_raw = stat_raw..string.rep(".", margin)
            
            local stat_pre = "pre: "
            if type(paths.proc) == 'table' then
                if paths.proc.even then
                    local c = count_files( project.path.."/"..paths.proc.even )
                    if c then
                        stat_pre = stat_pre..tostring(c)
                    end
                end
                if paths.proc.odd then
                    local c = count_files( project.path.."/"..paths.proc.odd )
                    if c then
                        stat_pre = stat_pre.."/"..tostring(c).." "
                    end
                end
            end
            local margin = 16 - string.len(string.sub(stat_pre, 0, 16))             
            stat_pre = stat_pre..string.rep(".", margin)
            
            local stat_done = 'done: '
            if dcutls.localfs:file_exists( project.path.."/"..defaults.doc_name.."/"..defaults.doc_filename ) then
                stat_done = stat_done.."PDF"
            else
                stat_done = stat_done.."..."
            end
            
            local stat_line = ' '..stat_raw..' '..stat_pre..' '..stat_done
            
            -- 
            local mindex = 4 - string.len(index)
            local findex = string.rep(" ", mindex)..tostring(index)
            print(findex.." ["..tostring(project.id).."] '"..tostring(settings.title).."'")
            print("     ..."..stat_line)
            -- print()
        end
    end    
end

function batch:list_projects(projects)
    if type(projects) ~= 'table' then return false end
    print()
    for index,pdata in pairs(projects) do 
        print( tostring(index).." ["..pdata.id.."] " .. pdata.path )
    end
    print()
end

function batch:load_projects_list_from_path(opts)
    if type(opts) ~= 'table' then opts = {} end
    
    if type(opts.path) ~= 'string' then return false end
    if dcutls.localfs:file_exists( opts.path ) then		
        if lfs.attributes(opts.path,"mode") ~= "directory" then
            print(" Error: la ruta '"..tostring(opts.path).."' no es un directorio")
            return false
        end
    else
        print(" Error: la ruta '"..tostring(opts.path).."' no existe")
        return false
    end
    
    print(" Buscando proyectos en '"..tostring(opts.path).."'")
    local pl = {}
    for f in lfs.dir(opts.path) do
        if lfs.attributes(opts.path.."/"..f,"mode") == "directory" then
            if dcutls.localfs:file_exists( opts.path.."/"..f..'/.dc_settings' ) then
                -- it's dalclick project
                local insert_project = true              
                if dcutls.localfs:file_exists( opts.path.."/"..f..'/'..defaults.doc_name.."/"..defaults.doc_filename ) then
                    -- it's proc
           	        if opts.hide_proc == true then
               	        insert_project = false
           	        end
           	    else
                    -- it's noproc
                    if opts.hide_noproc == true then
           	            insert_project = false
           	        end           	    
                end
                if insert_project then
	                table.insert( pl, 
	                    { id = f,
	                      path = opts.path.."/"..f,
	                      settings_path = opts.path.."/"..f..'/.dc_settings'
	                    }
	                )
                end
            end
        end
    end
    
    if next(pl) then
       return true, pl
    else
       return nil, pl
    end
end

function batch:load_projects_list_from_file(opts)
    if type(opts) ~= 'table' then opts = {} end
    
    if type(opts.file) ~= 'string' then return false end
    if dcutls.localfs:file_exists( opts.file ) then
        if lfs.attributes(opts.file,"mode") ~= "file" then
            print(" Error: la ruta '"..tostring(opts.file).."' no es un archivo")
            return false
        end
    else
        print(" Error: la ruta '"..tostring(opts.file).."' no existe")
        return false
    end
    
    local content = dcutls.localfs:read_file_as_table(opts.file)
    
    local pl = {}
    if type(content) == 'table' then
        for id, line in pairs(content) do
           if line ~= nil and line:sub(-1) == "/" then line = line:sub(1, -2) end -- remove trailing slash if any
           line = string.gsub(line, 'file://', '')
           line = string.gsub(line, "\r", '')
           if dcutls.localfs:file_exists( line ) and lfs.attributes(line,"mode") == "directory" then
               -- print(line)
               if dcutls.localfs:file_exists( line..'/.dc_settings' ) then
                   local filepath, filename, fileext = string.match(line, "(.-)([^\\/]-%.?([^%.\\/]*))$")
                   if filename ~= "" then
     	               table.insert( pl, 
                          { id = filename,
                            path = line, 
                            settings_path = line..'/.dc_settings'
                          })
                   end
	           end
           end
        end
    end

    if next(pl) then
        self:list_projects(pl)
        print(" ¿Desea seleccionar los archivos listados? [s/n]")
        printf(">> ")
        local key = io.stdin:read'*l'
        if key == "S" or key == "s" then  
            return true, pl
        else
            return false, pl
        end
    else
       return nil, pl
    end
end

function batch:postprocess(projects)
    if type(projects) ~= 'table' then return false end
    
    local c_ok = 0
    local c_fail = 0
    local c_failload = 0
    for index,pdata in pairs(projects) do
        
        if not p:init(defaults) then
            print(" ERROR: no se pueden inicializar proyectos!")
            break
        end
        print("\n\n - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - ")
        print(" abriendo '"..tostring(pdata.settings_path).."'")
        local load_status, project_status = p:load(pdata.settings_path)
        if load_status then
            print(" Procesando: '"..tostring(pdata.settings_path).."'")
            print(" Proyecto abierto con exito. Estado: "..tostring(project_status)) 
            local status, msgs = p:send_post_proc_actions({ batch_processing = true }) 
            if status then
                print(" Proyecto enviado con éxito a la cola de post-procesamiento para generar pdf")
                c_ok = c_ok + 1
            else
                print(" -- "..tostring(msgs).." --")
                c_fail = c_fail + 1
            end
        else
            print(" Ha ocurrido un error mientras se intentaba cargar el proyecto")
            c_failload = c_failload + 1
        end
    end
    return "Resumen:\n"
            .."  "..tostring(c_ok).." proyectos enviados\n"
            .."  "..tostring(c_fail).." proyectos no enviados\n"
            .."  "..tostring(c_failload).." proyectos que no pudieron abrirse\n"
end

function batch:repair_projects(projects)

    local function rplog(string, path, show)
        if show then print(string) end
        if dcutls.localfs:file_exists(path) then
            local file = io.open(path, "a")
            io.output(file); io.write(string.."\n"); io.close(file)
        end
    end
       
    -- -- --
    if type(projects) ~= 'table' then return false end
    local fail = {}
    local success = {}
    for _,pdata in pairs(projects) do
        
        if not p:init(defaults) then
            print(" ERROR: no se pueden inicializar proyectos!")
            return false
        end
        
        -- create log file in project folder
        local log
        local continue = true
        if dcutls.localfs:file_exists(pdata.path) then
            log = pdata.path.."/.reparar-proyectos.log"
            if not dcutls.localfs:file_exists(log) then
                if dcutls.localfs:create_file(log, '') then
                    print(" Archivo de registro creado con exito en: "..tostring(log))
                else
                    print(" ATENCION: no se pudo crear un archivo de registro en: "..tostring(log))
                    continue = false
                end
            else
                print(" Ya existe un registro en '"..tostring(log).."'. Se continua ingresando información a continuación." )
            end                 
            rplog(" --------------- "..os.date().." --------------- ", log, false)
        else
            print(" ATENCION no se pudo crear un archivo de registro, no existe: "..tostring(pdata.path))
            continue = false
        end

        if continue then
            -- load and repair project
            local load_status, project_status = p:load(pdata.settings_path)
            if load_status then
                rplog(" Procesando: '"..tostring(pdata.settings_path).."'", log, true)
                rplog(" Proyecto abierto con exito. Estado: "..tostring(project_status), log, true)
                local status, no_errors, received_log = p:reparar() 
                if status == true then
                    if no_errors == true then
                        table.insert(success, pdata.path)
                        rplog(" Reparacion del proyecto exitosa.", log, true)
                    elseif no_errors == 'warning' then
                        table.insert(success, pdata.path.." - Atención: con observaciones.")
                        rplog(" Reparacion del proyecto exitosa, pero con observaciones.", log, true)
                    else
       		            table.insert(fail, pdata.path.." - Error: Hubo errores mientras se reparaba el proyecto.")
                        rplog(" Hubo errores al intentar reparar el proyecto.", log, true)
                    end
                elseif status == false then
                    table.insert(fail, pdata.path.." - Error: No se pudo reparar el proyecto.")
                    rplog(" No se pudo reparar el proyecto.", log, true)
                elseif status == nil then
                    table.insert(fail, pdata.path.." - SIN CAPTURAS")
                    rplog(" No se pudo reparar el proyecto.", log, true)
                end
                rplog(received_log, log, false)
            else
                rplog(" Ha ocurrido un error mientras se intentaba cargar el proyecto", log, true)
                table.insert(fail, pdata.path.." - Error: No se pudo cargar el proyecto")
            end
        end
    end
    return true, success, fail
end


-- # # # # # # # # # # # # # # # # # # # # # MAIN # # # # # # # # # # # # # # # # # # # # # # # # # # # 

-- local functions for main

local function check_overwrite(idname)
    local local_path, file_name_we, file_name
    file_name_we = string.format("%04d", p.state.counter[idname])
    file_name = file_name_we..".".."jpg"
    
    if dcutls.localfs:file_exists( p.session.base_path.."/"..p.paths.raw[idname].."/"..file_name ) then
        return true
    else
        return false
    end
end

local function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

local function get_project_newname()

    guisys.init()

    local scanf_regnum, scanf_title
    local regnum = "" -- default
    local title = "" -- default
    local format = "Iniciar Proyecto\nNúmero de registro: %100.30%s\nTítulo:%300.30%s\n"
    repeat
        scanf_regnum, scanf_title = iup.Scanf(format, regnum, title)
        if scanf_regnum == nil then 
            return nil, nil
        end
        if scanf_regnum == "" then 
            iup.Message("Iniciar Proyecto", "El campo 'Número de registro' es obligatorio para iniciar un proyecto")
        else
            if string.match(scanf_regnum, "^[%w-_]+$") then
                if dcutls.localfs:file_exists( defaults.root_project_path.."/"..scanf_regnum ) then
                    iup.Message("Iniciar Proyecto", "El 'Número de registro' corresponde a un proyecto existente")
                else
                    break -- success!!
                end
            else
                iup.Message("Iniciar Proyecto", "El campo 'Número de registro' solo permite caracteres alfanuméricos y guiones, no admite espacios, acentos u otros signos")
            end
        end
    until false

    return scanf_regnum, scanf_title
end

local function select_file(dir)
    require( "iuplua" )
    local regnum_dir, status, file, list, a

    -- Creates a file dialog and sets its type, title, filter and filter info
    local fd = iup.filedlg{ dialogtype = "FILE", 
                            title = "Seleccionar archivo", 
                            directory = dir,
                            -- parentdialog = iup.GetDialog(self)
                            }
  
    -- Shows file dialog in the center of the screen
    fd:popup(iup.ANYWHERE, iup.ANYWHERE)
    
    -- Gets file dialog status
    status = fd.status
    file = fd.value
    
    fd:destroy()    
    -- iup.Destroy(od)
    
    -- Check status
    local success = false
    if status == "0" then 
      if type(file) ~= 'string' then
          -- nota: solo con Alarm se pudo corregir el problema de que no se podia cerrar filedlg
          iup.Alarm("Seleccionando lista", "Error: Hubo un problema al intentar seleccionar '"..tostring(file).."'" ,"Continuar")
      else
          a = iup.Alarm("Seleccionando lista", "Archivo seleccionado:\n"..file ,"OK", "Cancelar")
          if a == 1 then 
              success = true
              list = file
          end
      end
    elseif status == "-1" then 
          iup.Alarm("Seleccionando lista", "Operación cancelada" , "Continuar")
    else
          iup.Alarm("Seleccionando lista", "Se produjo un error" ,"Continuar")
    end


    if not success then
        print(" [Abrir proyecto] Error: no se pudo seleccionar una carpeta de proyecto válida.")
        return nil
    end
    
    return true, list
end

local function open_thunar(path)
   if defaults.thunar_available then
       os.execute("thunar".." "..path.." &")
   else
        print()
        print("ATENCION: Su sistema debe ser configurado para poder usar esta opcion")
        print("No se encuentra la aplicación 'Thunar' para explorar archivos")
        print()
        sys.sleep(2000)
   end
end

local function open_evince(path_to_pdf)
   if defaults.evince_available then
       if type(path_to_pdf) == 'string' and dcutls.localfs:file_exists( path_to_pdf ) then
           os.execute("evince".." "..path_to_pdf.." &")
       end
   else
        print()
        print("ATENCION: Su sistema debe ser configurado para poder usar esta opcion")
        print("No se encuentra la aplicación 'Evince' para visualizar PDFs")
        print()
        sys.sleep(2000)
   end
end

local function open_scantailor_gui(path_to_scproject)
  if defaults.scantailor_available then
      if type(path_to_scproject) == 'string' and dcutls.localfs:file_exists( path_to_scproject ) then
          os.execute(defaults.scantailor_path.." "..path_to_scproject.." &") 
      end
  end
end

local function parse_pp_args(items)
    if items == nil or items == '' then return true, '+all', ' Acciones seleccionadas: postprocesado completo' end
    
    local errmsg = ""
    local wrong = false
    local scantailor = false; local ocr = false; local compile = false
    local sign
    
    for c in string.gmatch(items, "[^%s]+") do
        if c:sub(1,1) ~= "-" and c:sub(1,1) ~= "+" then
            c='+'..c
            sign = '+'
        elseif c:len() == 1 then
            errmsg = " los signos '+' ó '-' deben ir pegados a cada argumento, por ejemplo '+ocr'."
            wrong = true; break
        end
        -- if i'm here c begin with '+' or '-' and c:len > 1 !
        if not sign then
            sign = c:sub(1,1)
        elseif sign ~= c:sub(1,1) then
            errmsg = " no puede mezclar inclusiones y exclusiones (-) en los argumentos"
            wrong = true; break
        end                     
        if c:sub(2) == "scantailor" or c:sub(2) == "sc" then
            if not scantailor then
                scantailor = true
            else 
                errmsg = " 'scantailor' repetido"
                wrong = true; break 
            end
        elseif c:sub(2) == "ocr" then
            if not ocr then
                ocr = true
            else 
                errmsg = " 'ocr' repetido"
                wrong = true; break 
            end
        elseif c:sub(2) == "pdf" then
            if not compile then
                compile = true
            else
                errmsg = " 'pdf' repetido"
                wrong = true; break
            end
        else
           errmsg = " No se pudo reconocer el argumento '"..tostring(c).."'"
           wrong = true; break
        end
    end

    if wrong then
       return false, false, " pp: argumento con errores.\n  "..tostring(errmsg)
    end
    
    if not sign then sign = '+' end -- prevent '  ' args string
    
    local args = ""
    local msg = ""
    if scantailor then
        args = args..sign..'scantailor'
        msg = msg.."   "..sign.." procesar con scantailor\n"
    end
    if ocr then
        args = args..sign..'ocr'
        msg = msg.."   "..sign.." realizar OCR (reconocimiento de caracteres)\n"
    end
    if compile then                         
        args = args..sign..'compile'
        msg = msg.."   "..sign.." compilar PDF\n"
    end
    if args == "" then
        args = 'all'
        msg = msg.."   "..sign.." postprocesamiento completo\n"
    end
    
    if sign == "+" then
       return true, args, " Acciones seleccionadas:".."\n".. msg
    elseif sign == "-" then
       return true, args, " Se seleccionó ejecutar todo el postproceso menos:".."\n".. msg
    end
end

-- main funtions

function dc:init_daemons()

    -- os.execute("ps aux | grep '[q]m_daemon.sh' > /tmp/qm_daemon_ps_info")
    -- if dcutls.localfs:file_exists('/tmp/qm_daemon_ps_info') then
    --     local content = dcutls.localfs:read_file('/tmp/qm_daemon_ps_info')
    --     if content ~= "" then
    --         print("proceso/s encontrado: "..tostring(content))
    --     end
    -- end

    print(" iniciando procesos en segundo plano...")
    os.execute("killall qm_daemon.sh 2>&1") -- TODO: q & d!!!! hay un bug y qm_daemon se inicia aunque haya otro daemos funcioando!
    
    if not dcutls.localfs:file_exists(p.session.base_path.."/"..p.paths.raw.odd) or not dcutls.localfs:file_exists(p.session.base_path.."/"..p.paths.raw.even) then
        print(" error: init_daemons: no existen path_raw... \n  "..p.session.base_path.."/"..p.paths.raw.odd.."\n  "..p.session.base_path.."/"..p.paths.raw.even)
        return false
    end
    os.execute(p.dalclick.qm_daemon_path.." "..p.session.base_path.."/"..p.paths.raw.odd.." &")
    os.execute(p.dalclick.qm_daemon_path.." "..p.session.base_path.."/"..p.paths.raw.even.." &")
    return true

    -- para enviar un comando al queue
    -- os.execute(p.dalclick.qm_sendcmd_path..' "'..p.path_raw.even..'"')
end

function dc:kill_daemons()
    print(" terminando procesos en segundo plano...")
    os.execute("killall qm_daemon.sh 2>&1") -- TODO: qm_daemon se deberia apagar creando un archivo 'quit' en job folder
end

function dc:start_options(mode, options)

    local options = options or {}
    if type(options) ~= 'table' then return false end
    -- mode -> 'restore_project' ó 'new_project' (por ahora igual a '')
    -- iniciando la estructura para un proyecto
    if not p:init(defaults) then
        return false
    end

    -- iniciando proyecto (carga proyecto anterior o crea nuevo)
    local running_project_loaded = false

    if mode == "restore_project" then
        local settings_path
        if options.settings_path then
            settings_path = options.settings_path
        else
            settings_path = self:check_running_project() 
        end
        if settings_path then
            print("")
            print(" Restaurando proyecto...")
            local load_status, project_status = p:load(settings_path)
            if load_status then
                if project_status == 'opened' then
                    running_project_loaded = true
                    if p:update_running_project(settings_path) then
                        -- success!!
                    end
                else
                    print(" ATENCION: Está intentado cargar al inicio un proyecto en formato obsoleto.")
                    print(" Por favor cárguelo seleccionando la opción [o] a continuación.")
                    print()
                end
            else
                print(" Ha ocurrido un error mientras se intentaba restaurar el proyecto")
                sys.sleep(2000)
            end
        else
            print()
            print(" # Sin proyecto previo para restaurar #")
            print()
        end
    end
    
    local start_menu = [[

 == Nueva sesión de DALclick ==================================================

  Carpeta de proyectos: ']]..defaults.root_project_path..[['
 
  [n] crear nuevo proyecto        [o] abrir proyecto
  
  ---- seleccionar una lista de proyectos -------------------------------------

  [s]     seleccionar todos
  [s-pdf] seleccionar pendientes sin pdf 
  [s+pdf] seleccionar finalizados con pdf
  [a]     cargar una lista desde un archivo]]
  
    local start_menu_lote =[[   
  [pp] generar pdf   [reparar] reparar  [list] lista detallada

  [q] para salir

 ==============================================================================]]
    
    if not running_project_loaded then    
        local key
        local empty_list_msg = " Primero debe seleccionar una lista de proyectos!"
        local loopmsg = ""
        
        local function get_options()
            print(" - Seleccionados "..tostring(table.getn(state.projects_selection)).." proyectos.")
            print()
            print(" Puede abrir un proyecto ingresando el número de índice de la lista\n"
                .." ó aplicar las acciones por lote a los proyectos listados.\n"
                .." <enter> para más opciones..." )
            printf(">> ")
            local key = io.stdin:read'*l'
            if key == "" then
                return nil
            else
                return key
            end
        end
        
        local function list_projects_and_get_options(status, projects)
            if status == nil then
                print(" La carpeta no contiene proyectos")
            elseif status == false then
                print(" Se produjeron errores al intentar obtener una lista de proyectos")
            else
                state.projects_selection = projects
                print()
                batch:list_projects( state.projects_selection )
                print()
                print(" - Fin de la lista")
                return get_options()
            end 
        end
        
        repeat
            print("\n\n\n\n")
            print(start_menu)
            print()
            print("  ---- acciones en lote para "..tostring(table.getn(state.projects_selection)).." proyectos seleccionados --------------------")
            print(start_menu_lote)
            if next(state.projects_selection) then
                print("Puede abrir un proyecto ingresando el número de índice de la lista previa")
            end
            if loopmsg ~= "" then print(">> "..loopmsg) end
            loopmsg = ""
            printf(">> ")
            if not key then key = io.stdin:read'*l' end
            local moption = key
            key = nil
            
            -- ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

            if moption == "q" then
                return false
            elseif moption == "n" then
                print(); print(" Eligió: Crear Nuevo Proyecto...")
                local regnum, title = get_project_newname()
                if regnum ~= nil then
                    if not p:init(defaults) then
                        return false
                    end
                    local create_options = { regnum = regnum, title = title, root_path = defaults.root_project_path }
                    if config.zoom_persistent then
                        create_options.zoom = options.zoom
                    end
                    if p:create( create_options ) then
                        local cam_status = self:init_cams_or_retry()
                        if cam_status == 'exit' then
                            return 'exit' -- opcion explicita de salir de dalclick desde init_cams_or_retry()
                        end
                        break
                    end
                 end
                 -- state.projects_selection = {}
                 -- back to start options
            elseif moption == "o" then
                print(); print(" Eligió: Abrir Proyecto...")
                local open_status, project_status = p:open(defaults, { root_path = defaults.root_project_path })
                if open_status then
                    if project_status == 'modified' then
                        printf(" El formato del proyecto era obsoleto. Guardando proyecto actualizado...")
                        if p:write() then print("OK") else print("ERROR") end
                    end
                    if project_status ~= 'canceled' then
                        break
                    end
                    -- back to start options
                end
                -- state.projects_selection = {}
                -- back to start options
            elseif moption == "s" then
                print(" Eligió seleccionar todos los proyectos...")
                local status, projects = 
                    batch:load_projects_list_from_path({ 
                        path = defaults.root_project_path,
                        -- hide_proc = true 
                    })            
                 key = list_projects_and_get_options(status, projects)
            elseif moption == "s-pdf" then
                print(" Eligió seleccionar todos los proyectos sin pdf...")
                local status, projects = 
                    batch:load_projects_list_from_path({ 
                        path = defaults.root_project_path,
                        hide_proc = true 
                    })            
                 key = list_projects_and_get_options(status, projects)
            elseif moption == "s+pdf" then
                print(" Eligió seleccionar todos los proyectos que ya tienen pdf generado...")
                local status, projects = 
                    batch:load_projects_list_from_path({ 
                        path = defaults.root_project_path,
                        hide_noproc = true 
                    })            
                 key = list_projects_and_get_options(status, projects)
            elseif moption == "a" then
                print(" Eligió seleccionar proyectos desde una lista en un archivo...")
                local select_file_status, selected_file = select_file(defaults.root_project_path)
                if select_file_status == true then
                    print(" Archivo seleccionado: '"..selected_file.."'")
                    local status, projects = 
                        batch:load_projects_list_from_file({ 
                            file = selected_file
                        })
                    if status == nil then
                        print(" No pudo cargarse ningún proyecto de la lista proporcionada")
                    elseif status == false then
                        print(" Se canceló la operación o se produjeron errores")
                    else
                        state.projects_selection = projects
                        print()
                        key = get_options()
                    end 
                end
            elseif moption == "list" then
                print(" Seleccionó mostrar lista detallada:")
                if next(state.projects_selection) then
                    print()
                    batch:show_projects( state.projects_selection )
                    print()
                    key = get_options()
                else
                    loopmsg = empty_list_msg
                end
            elseif moption == "pp" then
                print(" Seleccionó enviar a la cola de post-proceso (para generar pdf)\n proyectos seleccionados:")
                if next(state.projects_selection) then
                    print()
                    batch:list_projects( state.projects_selection )
                    print()
                    print(" ¿Desea generar pdf en los proyectos listados? [s/n]")
                    printf(">> ")
                    local pkey = io.stdin:read'*l'
                    if pkey == "S" or pkey == "s" then
                        print(" Procesando lista de proyectos obtenida...")
                        local result = batch:postprocess( state.projects_selection )
                        print("\n"..tostring(result).."\n")
                        print(" <enter> para continuar")
                        printf(">> ")
                        pkey = io.stdin:read'*l'
                    end
                else
                    loopmsg = empty_list_msg
                end
            elseif moption == "reparar" then
                print(" Eligió reparar los proyectos seleccionados:")
                if next(state.projects_selection) then
                    print()
                    batch:list_projects( state.projects_selection )
                    print()
                    print(" ¿Desea reparar proyectos listados? [s/n]")
                    printf(">> ")
                    local pkey = io.stdin:read'*l'
                    if pkey == "S" or pkey == "s" then
                        print(" Procesando proyectos seleccionados...")
                        local repair_status, success, fail = batch:repair_projects( state.projects_selection )
                        if repair_status then
                            print(); 
                            print(" Proyectos reparados existosamente:")
                            print(" ----------------------------------")
                            print()
                            for _,b in pairs( success ) do print( " OK "..tostring(b) ) end
                            print()
                            print(" Proyectos que no pudieron ser reparados o generaron mensajes de error:")
                            print(" ----------------------------------------------------------------------")
                            print()
                            for _,b in pairs( fail ) do print( " ?? "..tostring(b) ) end
                            print()
                            print(" - Fin de la listas -")
                            print(" <enter> para continuar")
                            printf(">> ")
                            pkey = io.stdin:read'*l'
                        end
                    end
                else
                    loopmsg = empty_list_msg
                end
            else
                if next(state.projects_selection) then
                    if state.projects_selection[tonumber(moption)] ~= nil then
                        print()
                        print(" ¿Seguro que desea abrir el ítem "
                              ..tostring(moption)
                              .." '"..tostring(state.projects_selection[tonumber(moption)].id).."'"
                              .."? [S/n]")
                        print()
                        printf(">> ")
                        local confirm = io.stdin:read'*l'
                        if confirm == "S" or confirm == "s" then
                            local settings_path = state.projects_selection[tonumber(moption)].settings_path
                            local load_status, project_status = p:load(settings_path)
                            if load_status == true then
                                
                                print(" Proyecto cargado con éxito" )
                                -- guardar referencia al proyecto cargado como "running project"
                                if project_status == 'modified' then
                                    printf(" El formato del proyecto era obsoleto. Guardando proyecto actualizado...")
                                    if p:write() then print("OK") else print("ERROR") end
                                end
                                if p:update_running_project( settings_path ) then
                                    break
                                else
                                    print(" Error: no se pudo actualizar la configuración interna de DALclick" )
                                    sys.sleep(2000)
                                    return false
                                end
                            else
                                print(" Ha ocurrido un error mientras se cargar el proyecto")
                                sys.sleep(2000)
                                return false
                            end
                        end
                    else
                        print(" El índice "..tostring(moption).." no corresponde a ningún elemento de la lista")
                    end
                else
                    print(" Lista de proyectos vacía. Seleccione primero 'Listar proyectos' para cargarla.")
                end
            end
        until false
    end

    return true
end

function dc:dalclick_loop(mode)
    if mode then -- loop true
        if not dcutls.localfs:file_exists( defaults.dc_config_path.."/loop" ) then
            dcutls.localfs:create_file( defaults.dc_config_path.."/loop","" )
        end
    else
        if dcutls.localfs:file_exists( defaults.dc_config_path.."/loop" ) then
            dcutls.localfs:delete_file( defaults.dc_config_path.."/loop" )
        end
    end
end

function dc:init_cams_or_retry()

    local status
    local menu = [[
    
+ + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + 

 No se ha podido configurar correctamente alguna de las cámaras.
 Posibles problemas y soluciones:

 1) Alguna de las cámaras (o ambas) todavía está inicializando.
    Espere unos segundos y vuelva a intentarlo.
    
 2) Alguna de las cámaras (o ambas) se apagó o dejo de responder.
    Enciéndala nuevamente y vuelva a intentarlo.

== opciones ==================================================================

 [enter] para reintentar
 [c] continuar sin iniciar las cámaras
 [e] para salir

==============================================================================]]

    while true do
        status = mc:init_cams_all() -- true: ok, seguir - false: error, reintentar - nil: se eligio salir
        if status == true then
            break
        elseif status == 'exit' then
            return 'exit'
        elseif status == false then
            print(menu)
            printf(" >> ")
            local key = io.stdin:read'*l'
            print()
            if key == "" then
                -- continuar
            elseif key == "c" then
                return 'no_init_select'
            elseif key == "e" then
                return false
            end
        end
    end
    return true
    
end

function dc:load_cam_scripts()
    local file = io.open(defaults.dalclick_pwdir.."/chdk_dalclick_utils.lua", "r")
    local dalclick_utils = file:read("*all")
    file:close()
    
    if dalclick_utils == nil then 
        return false
    else
        chdku.rlibs:register({
            name = 'dalclick_utils',
            code = dalclick_utils
        })
    end
    
    chdku.rlibs:register({
        name='dalclick_identify',
        code=[[
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
]],
    })
    return true
end

function dc:check_running_project()
    local running_project_fileinfo = defaults.dc_config_path.."/running_project"
    local running_project_path
    
    if dcutls.localfs:file_exists( running_project_fileinfo ) then
        running_project_path = dcutls.localfs:read_file( running_project_fileinfo )
        if dcutls.localfs:file_exists( running_project_path ) then
            return running_project_path
        else
            -- archivo running_project corrupto, no existe el proyecto
            print(" ATENCION: Dalclick encontro una referecnia a un proyecto previo que no existe.")
            print(" Eliminando referencia...")
            dcutls.localfs:delete_file( running_project_info )
        end
    end    
    return false
end

function dc:main(
    DALCLICK_HOME,
    DALCLICK_PROJECTS,
    DALCLICK_PWDIR,
    ROTATE_ODD_DEFAULT,
    ROTATE_EVEN_DEFAULT,
    DALCLICK_MODE,
    THUNAR,
    EVINCE,
    SCANTAILOR_PATH)

    -- debug
    if false then
        print("lua debug playroom!\n")
    end
    -- /debug

    if not DALCLICK_HOME or not DALCLICK_PROJECTS then 
        return false
    else
        defaults.dc_config_path = DALCLICK_HOME
        defaults.root_project_path = DALCLICK_PROJECTS
        print(" * dalclick home: '"..tostring(defaults.dc_config_path).."'")
        print(" * dalclick projects: '"..tostring(defaults.root_project_path).."'")
    end

    if DALCLICK_PWDIR then 
        defaults.dalclick_pwdir = DALCLICK_PWDIR
        print(" * dalclick pwdir: '"..tostring(defaults.dalclick_pwdir).."'")
    else
        defaults.dalclick_pwdir = '/opt/src/dalclick'
    end

    if THUNAR == "Yes" then 
        defaults.thunar_available = true
        print(" * thunar available")
    end
       
    if EVINCE == "Yes" then 
       defaults.evince_available = true
       print(" * evince available")
    end

    if SCANTAILOR_PATH ~= "" then 
       defaults.scantailor_available = true
       print(" * scantailor available")
       defaults.scantailor_path = SCANTAILOR_PATH
    end

    defaults.qm_sendcmd_path = defaults.dalclick_pwdir.."/qm/qm_sendcmd.sh"
    defaults.qm_daemon_path = defaults.dalclick_pwdir.."/qm/qm_daemon.sh"
    
    defaults.ppm_sendcmd_path = defaults.dalclick_pwdir.."/ppm/ppm_sendcmd.sh" -- post process mananager

    defaults.empty_thumb_path = defaults.dalclick_pwdir.."/empty_g.jpg"
    defaults.empty_thumb_path_error = defaults.dalclick_pwdir.."/empty.jpg"

    -- --
    if not self:load_cam_scripts() then
        print(' ERROR falló load_cam_scripts()')
        return false
    end
    -- --

    if ROTATE_ODD_DEFAULT then 
        defaults.rotate_odd = ROTATE_ODD_DEFAULT
    end
    if ROTATE_EVEN_DEFAULT then 
        defaults.rotate_even = ROTATE_EVEN_DEFAULT
    end
    
    self:dalclick_loop(false)



    local exit = false
    print()
    print(" ====================================")
    print('   ____   ___  _       _|_|     _')
    print('  |  _ \\ / _ \\| |  ___| |_  __| | _')
    print('  | | | | |_| | | /  _| | /  _| |/ /')
    print('  | |_| |  _  | |_| |_| | | |_|   (')
    print('  |___ /|_| |_|___\\___|_|_\\___|_|\\_\\')
    print()
    print(" ====================================")  
    print()  
    
    -- el objetivo de este bloque es que las camaras esten apagadas y se enciendan ahora
    local no_init_cam
    local running_project = self:check_running_project()
    
    if not mc:connect_all() then
        print(" DALclick se ha iniciado correctamente, ahora encienda las cámaras.\n")
        print()
        
        if running_project then
            local ppath, pname, pext = string.match(running_project, "(.-)([^\\/]-%.?([^%.\\/]*))$")
            print(" Se restaurará automáticamente el proyecto de la sesión anterior")
            print(" desde:")
            print()
            print("   '"..tostring(ppath).."'")
            print()
        end

        print(" [enter] seguir")
        print()
        
        if running_project then
            print(" [n] no restaurar, iniciar con un nuevo proyecto")
            print()
        end
        
        print(" [Ctrl+C] interrumpir la ejecución del programa")
        print()
        
        printf(">> ") 
        local key = io.stdin:read'*l'

        if key == "" then
            print(" o/")
        elseif key == "n" then
            defaults.autorestore_project_on_init = false
        else
            self:dalclick_loop(false)
            return false
        end
        
        if not mc:connect_all() then
            print("")
            print(" #######################################")
            print(" ## Las cámaras no fueron encendidas! ##")
            print(" #######################################")
            print()
            print(" [enter] para reintentar.")
            print()
            print(" [c] para continuar con las cámaras apagadas")
            print("     (puede encenderlas luego)")
            print("")
            printf(">> ") 
            local key = io.stdin:read'*l'

            if key ~= "c" then
                self:dalclick_loop(true)
                return true
            end
            
            no_init_cam = true
        end
    else
        print(" Para prevenir interferencias entre el sistema operativo y DALclick en la")
        print(" gestión de las cámaras digitales, es mejor comenzar con los dispositivos")
        print(" apagados y encenderlos cuando DALclick lo indique.")
        print()
        print(" [enter] Continuar luego de apagar las cámaras")
        print(" [c] Continuar sin apagar")
        print()
        
        if running_project then

            print(" Existe un proyecto de una sesión anterior de DALclick que se restaurará")
            print(" automáticamente.")
            print(" [n] para no restaurar")
            print()
        end


        print(" (Siempre que quiera salir del programa use Ctrl+C)")
        print()
        
        local key = io.stdin:read'*l'

        if key == "" then
            self:dalclick_loop(true)
            return true
        elseif key == "c" then
            -- continue
        elseif key == "cc" then
            no_init_cam = true
            -- continue
        elseif key == "n" then
            defaults.autorestore_project_on_init = false
        else
            self:dalclick_loop(false)
            return false
        end  
    end
    
    -- opciones al inicio
    if defaults.autorestore_project_on_init then
        if not self:start_options('restore_project') then
            self:dalclick_loop(false)
            return false
        end
    else
        print()
        print(" (Como seleccionó 'n' previamente DALclick se inicia sin restaurar")
        print(" el proyecto de la sesión anterior)")
        if not self:start_options('new_project') then
            self:dalclick_loop(false)
            return false
        end 
    end
    
    local init_st
    if no_init_cam then
        print(" Eligió no inicializar las cámaras.")
        init_st = 'no_init_select'
    else
        init_st = self:init_cams_or_retry()
    end
    
    local menu = {}
    menu.standart = [[
 [enter] capturar                                    [s] salir  [h] inicio

 [t] test de captura        [n] nuevo proyecto...    [z] sincronizar zoom 
                            [o] abrir proyecto...        desde la camara de
 [v] ver ultima captura     [w] guardar proyecto         referencia
 [e] explorador                                     [zz] ingresar valor de
                            [c] cerrar proyecto          zoom manualmente...
 [i] reiniciar cámaras      [x] cerrar y generar pdf
 [b] bip en cámara de      [xx] ídem, modo auto      [f] enfocar
     referencia                                      [m] modo seg/norm/rápido
 - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 [r] < retroceder una       [u] avanzar una >       [uu] avanzar al final >>>
                                                     [p] ir a página...
 - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 [1] opciones avanzadas     [2] opciones scantailor [3] opciones generar PDF
]]

    local thunar_option = ""
    if defaults.thunar_available then 
        thunar_option = "  [dir]     abrir el proyecto en el explorador de archivos\n"
    end
    local evince_option = ""
    if defaults.evince_available then 
        evince_option = "  [pdf abrir]    ver último pdf generado\n"
    end
    
    menu.advanced = [[
 [enter] volver a opciones
 
 Reparación de proyectos:
  [reparar] reparar y checkear integridad del proyecto

 Rango o subselección de páginas:
  [rango]         ingresar valores "desde/hasta" manualmente
  [rango borrar]  eliminar rango
 
 Explorar archivos:
]]..thunar_option..
[[ 
 Funciones avanzadas de cámaras
  [ifocus]  mostrar info de foco
  [iexpo]   mostrar info de exposición
  [chdk]    recargar script chdk

]]

    menu.scantailor = [[
 [enter]   volver a opciones

 Opciones Scantailor
  [sc abrir]     abrir en scantailor (edicion manual)
  [sc borrar]    borrar el proyecto scantailor

 Opciones Scantailor para rango de páginas
  [scr abrir]    ídem para rango de páginas seleccionadas
  
 Opciones generales
  [sc listar]    listar los proyectos Scantailor generados
  [sc ayuda]     Ver ayuda para scantailor
  
]]

    menu.scantailor_help = [[
 [enter]   volver a opciones

   Scantailor es uno de los componentes de nuestro sistema de postprocesamiento
 y se encarga de optimizar las capturas y formatearlas para el documento PDF
 final. El resultado intermedio producido por Scantailor es una colección de ar-
 chivos 'tif'. Para llegar al PDF final estos 'tifs' deben continuar siendo pro-
 cesados por otros componentes del sistema de postproceso. Si bien Scantailor se
 ejecuta de modo automático dentro de nuestro postproceso, de ser necesario es 
 posible abrir el proyecto en su interfaz gráfica para realizar ajustes manuales
 y luego recompilar el PDF con las correcciones realizadas.

   El método usual para realizar un ajuste manual a través de la interfaz gráfi-
 ca de Scantailor consiste en enviar normalmente a la cola de procesamiento el 
 proyecto por medio de la opción [pp], que luego de procesado habrá generado 
 automáticamente, además del PDF, un "proyecto Scantailor" que podrá ser abierto
 en modo interfaz gráfica usando la opción [sc abrir].
 
  [.] seguir...
]]

    menu.pdf_help = [[
 [enter]   volver a opciones
 
 La opción [pp] se puede combinar con tres componentes: 
  - scantailor (también se puede usar 'sc')
  - ocr
  - pdf 
 Si explicita uno o más sólo se ejecutaran los explicitados, por ejemplo:
 
  [pp ocr pdf]               -> ejecuta 'ocr' y 'compilar'
  [pp scantailor] ó [pp sc]  -> ejecuta sólo 'scantailor'

 Si le coloca un signo '-' como prefijo se ejecutara todo el proceso menos el
 o los indicados, ejemplos:

  [pp -scantailor]      -> ejecuta todo menos 'scantailor'
  [pp -scantailor -ocr] -> ejecuta todo menos 'scantailor' y 'ocr'
  
 Si usa [pp] sin argumentos se ejecuta todo el proceso.
]]

    menu.scantailor_help_01 = [[ 
 [enter]   volver a opciones

 Luego de corregir lo necesario en el modo gráfico existen dos opciones para 
 continuar: 1) terminar el procesamiento correspondiente a Scantailor dentro de 
 la interfaz gráfica de Scantailor o 2) guardar el proyecto y repetir la ejecu-
 ción en modo automático desde Dalclick, incluyendo la parte de Scantailor.
 
 Para el caso 1) presione el botón play del filtro '6' (dentro de la interfaz 
 grafica de Scantailor) para actualizar todas las páginas, o si sólo necesita 
 modificar unas pocas puede ejecutar el filtro 6 en cada página individualmente.
 El "filtro 6" es el que actualiza los 'tif' de salida de Scantailor con las co-
 rreciones realizadas. Finalizado este paso, guarde, cierre Scantailor y desde
 Dalclick ejecute [pp ocr pdf], que realizará el resto de los pasos necesarios 
 para actualizar los cambios en el PDF. Si no necesita el OCR use [pp pdf].
 
 Para el caso 2) deberá usar [pp scantailor ocr pdf], ya que necesita volver a
 generar los 'tif' de salida de Scantailor con las correcciones realizadas. Pue-
 de excluir OCR como el caso anterior con [pp scantailor pdf].
 
 [.] seguir...
]] 

    menu.scantailor_help_02 = [[ 
 [enter]   volver a opciones

 Nota importante sobre [sc abrir]: Tenga en cuenta que si abre el proyecto en la
 interfaz gráfica de Scantailor sin haber realizado ningún paso del procesamien-
 to automático previo, [sc abrir] abrirá de todas formas el proyecto, pero no
 habrá ningun ajuste automático realizado sobre el documento, y deberá realizar
 este paso desde la interfaz de usuario.

   También puede ser útil -para no tener que abrir todo el documento- realizar 
 una selección de las páginas a retocar con la opción [rango] y trabajar sólo 
 con esa selección. Para esto use [ppr scantailor] para aplicarle los ajustes
 automáticos al rango de páginas elegido y luego [scr abrir] para editar en la
 interfaz grafica de Scantailor. Las imagenes 'tif' generadas por este "minipro-
 yecto" sobrescribirán las imágenes del procesamiento anterior y podrán ser com-
 piladas nuevamente en el pdf usando [pp pdf]. Tenga en cuenta que los ajustes 
 manuales que realize con este método quedarán guardados solo en este "minipro-
 yecto" parcial y no en el general.
]]

    menu.pdf = [[
 [enter]   volver a opciones

 Opciones para generación de PDF:
  [pp]                           generar pdf (postproceso completo)
  [pp scantailor ocr pdf]   realiza sólo las opciones explicitadas.
  [pp -scantailor -ocr -pdf]     con el prefijo '-', omitir el componenete.
  
  [pp ocr-p]   realizar OCR 'perezoso' sin sobrescribir OCR previo
  [pp pdf-p]   compilar PDF en modo 'perezoso' sin reprocesar imágenes
  
 Opciones PDF para rango de páginas
  [ppr]   generar pdf parcial sólo del rango de páginas seleccionado,
          también se puede usar [ppr -scantailor], [ppr ocr] etc.

 Opciones generales 
  [pdf listar]   abrir pdf desde una lista de los pdfs generados
]]..evince_option..
[[  [pdf ayuda]   ver una ayuda para el comando 'pp'

]]

    if init_st == false then
        print(" No se pudieron inicializar correctamente las cámaras.")
        -- self:dalclick_loop(false)
        -- return false
    elseif init_st == 'exit' then
        print(" Eligió salir.")
        self:dalclick_loop(false)
        return false
    else

        -- init daemons
        if defaults.mode_enable_qm_daemon then
            self:init_daemons()
        end
               
        local status
        local e_overwt, o_overwt, margin, top_bar, the_title
        local loopmsg = ""
        while true do
            
            o_overwt = false; e_overwt = false
       
            state.cameras_status = mc:camsound_plip()
            if state.cameras_status == true then
                cam_msg = "=================="
            elseif state.cameras_status == false then
                cam_msg = " CÁMARAS APAGADAS "
            elseif state.cameras_status == nil then
                cam_msg = " cámaras apagadas "
            end


            if check_overwrite(defaults.even_name) then
                e_overwt = true
            end
            if check_overwrite(defaults.odd_name) then
                o_overwt = true
            end
            print()
            print()
            print(" Proyecto: ["..p.session.regnum.."]" )
            if next(p.session.counter_min) and next(p.session.counter_max) then
                printf(" Capturas realizadas: "
                    ..string.format("%04d", p.session.counter_min.even)
                    .."-"
                    ..string.format("%04d", p.session.counter_min.odd)
                    )
                if p.session.counter_min.even ~= p.session.counter_max.even then
                    print(" a "
                    ..string.format("%04d", p.session.counter_max.even)
                    .."-"
                    ..string.format("%04d", p.session.counter_max.odd)
                    )
                end
            end
            if p.state.zoom_pos then
                print(" Valor del Zoom: "..tostring(p.state.zoom_pos))
            else
                print(" Valor del Zoom: Sin definir")
            end
            print()
            if string.match(state.menu_mode, "pdf_help") then 
                the_title = "Ayuda postproceso (PDF)" 
            elseif string.match(state.menu_mode, "scantailor_help") then 
                the_title = "Ayuda Scantailor" 
            else the_title = p.settings.title end
            margin = math.floor( ( 76 - string.len(string.sub(the_title, 0, 50)) ) / 2 )
            top_bar = string.rep("=", margin).." "..string.sub(the_title, 0, 50).." "..string.rep("=", margin)
            print( top_bar )
            print("")
            print(menu[state.menu_mode])
            print(
                "= "
                ..string.format("%04d", p.state.counter.even)
                ..(e_overwt and " ##RECAPT## " or " ===========")
                .."============"..cam_msg.."============"
                ..(o_overwt and " ##RECAPT## " or "=========== ")
                ..string.format("%04d", p.state.counter.odd)
                .." ="
                )
            if p.session.include_list.from or p.session.include_list.to then
                print(" -- Rango seleccionado: desde '"
                    ..tostring(p.session.include_list.from or '..')
                    .."' hasta '"
                    ..tostring(p.session.include_list.to or '..')
                    .."' --")
            end
            if loopmsg ~= "" then 
                print()
                print(">>"..loopmsg)
                loopmsg = ""
            end
            printf(">> ")
            local key = io.stdin:read'*l'
            
            -- ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

            if key == "" then
                if state.menu_mode == 'standart' then
                    if state.cameras_status then
                        print("capturando...")
                        if mc:capt_all() then
                            sys.sleep(500)
                        else
                            exit = true
                            break
                        end
                    else
                        loopmsg = " Encienda o reinicie las cámaras para poder efectuar esta operación."
                    end
                else
                    state.menu_mode = 'standart'
                end
            elseif key == "1" then
                state.menu_mode = 'advanced'
            elseif key == "2" then
                state.menu_mode = 'scantailor'
            elseif key == "3" then
                state.menu_mode = 'pdf'
            elseif key == "sc ayuda" then
                state.menu_mode = 'scantailor_help'
            elseif key == "pdf ayuda" then
                state.menu_mode = 'pdf_help'
            elseif key == "." then
                if state.menu_mode == 'scantailor_help' then
                    state.menu_mode = 'scantailor_help_01'
                elseif state.menu_mode == 'scantailor_help_01' then
                    state.menu_mode = 'scantailor_help_02'
                end
            elseif key == "t" then
                if state.cameras_status then
                    print("captura de test a test.jpg...")
                    if mc:capt_all_test_and_preview() then
                    -- if mc:capt_all('test') then
                        sys.sleep(500)
                    else
                        exit = true
                        break
                    end
                else
                    loopmsg = " Encienda o reinicie las cámaras para poder efectuar esta operación."
                end
            elseif key == "m" then
                if p.settings.mode == 'secure' then
                    p.settings.mode = 'normal'
                    loopmsg = " modo cambiado a 'normal' (4s)"
                elseif p.settings.mode == 'normal' then
                    p.settings.mode = 'fast'
                    loopmsg = " modo cambiado a 'rápido' (2s)"
                else
                    p.settings.mode = 'secure'
                    loopmsg = " modo cambiado a 'seguro' (8s)"
                end

            elseif key == "f" then
                if state.cameras_status then
                    print(" refocus...")
                    print()
                    local status, info = mc:refocus_cam_all()
                    if status then
                        loopmsg = info
                    else
                        loopmsg = " Alguna de las cámaras no pudo reenfocar, por favor apáguelas y reinicie el programa\n"..info
                    end
                else
                    loopmsg = " Encienda o reinicie las cámaras para poder efectuar esta operación."
                end
            elseif key == "r" then
                printf(" retrocediendo un lugar para volver a realizar la captura...")
                -- p.state.counter[defaults.odd_name] = p.state.counter[defaults.odd_name] - 2
                -- p.state.counter[defaults.even_name] = p.state.counter[defaults.even_name] - 2
                if p:counter_prev() ~= false then
                    print('OK')
                    p:save_state()
                else
                    loopmsg =  " No se puede retroceder, está al inicio de la lista"
                end
            elseif key == "u" then
                printf(" avanzando un lugar hacia adelante...")
                -- p.state.counter[defaults.odd_name] = p.state.counter[defaults.odd_name] + 2
                -- p.state.counter[defaults.even_name] = p.state.counter[defaults.even_name] + 2
                if p:counter_next(p.session.counter_max.odd) ~= false then
                    print('OK')
                    p:save_state()
                else
                    loopmsg = " No se puede avanzar mas, está al final de la lista"
                end
                p:save_state()
            elseif key == "uu" then
                if p.session.counter_max.odd ~= nil and p.session.counter_max.even ~= nil then
                    p.state.counter.odd =  p.session.counter_max.odd  + 2
                    p.state.counter.even = p.session.counter_max.even + 2
                    p:save_state()
                else
                    loopmsg = " No se puede avanzar al final porque todavía no hay capturas"
                end
            elseif key == "p" then
                print(" Ir a la pagina...")
                print(" ingresar valor numérico, no es necesario agregar ceros a la izquierda:")
                printf(">> ")
                local pos = io.stdin:read'*l'
                if pos ~= "" and pos ~= nil then
                    local status, msg = p:set_counter(pos)
                    p:save_state()
                    loopmsg = " "..tostring(msg)
                end
            elseif key == "rec" then
                mc:switch_mode_all('rec')
            elseif key == "play" then
                mc:switch_mode_all('play')
            elseif key == "z" then
                if state.cameras_status then
                    local status, zoom_pos, err = mc:get_zoom_from_ref_cam()
                    if status and zoom_pos then
                        p.state.zoom_pos = zoom_pos 
                        loopmsg = "Valor zoom leído de cámara de referencia: "..zoom_pos.."\n"
                        if p:save_state() then
                            print(" nuevo valor de zoom guardado")
                            print(" Reiniciando camaras... ")
                            local cam_status = self:init_cams_or_retry()
                            -- cam_status == 'no_init_select' or cam_status == true --> continue
                            if cam_status == 'exit' or cam_status == false then
                                exit = true
                                break
                            end
                        else
                            loopmsg = " Error: no se pudieron guardar las variables de estado en el disco"
                        end
                    else
                        loopmsg = " Error: no se pudo leer el valor de zoom de la cámara de referencia.\n error: "..err.."\n"
                    end
                else
                    loopmsg = " Encienda o reinicie las cámaras para poder efectuar esta operación."
                end
            elseif key == "zz" then 
                if state.cameras_status then
                    print("ingrese un valor para el zoom:")
                    printf(">> ")
                    local zkey = io.stdin:read'*l'
                    if zkey ~= "" and zkey ~= nil then
                        local zoom = tonumber(zkey)
                        print(" Valor de zoom ingresado: "..tostring(zoom))
                        if zoom >= 0 then
                            p.state.zoom_pos = zoom
                            if p:save_state() then
                                print(" nuevo valor de zoom guardado")
                                print(" Reiniciando camaras... ")
                                local cam_status = self:init_cams_or_retry()
                                -- cam_status == 'no_init_select' or cam_status == true --> continue
                                if cam_status == 'exit' or cam_status == false then
                                    exit = true
                                    break
                                end
                            else
                                loopmsg = " Error: no se pudieron guardar las variables de estado en el disco"
                            end
                        end
                    end
                else
                    loopmsg = " Encienda o reinicie las cámaras para poder efectuar esta operación."
                end
            elseif key == "b" then
                if state.cameras_status then
                    mc:camsound_ref_cam()
                    sys.sleep(2000)
                else
                    loopmsg = " Encienda o reinicie las cámaras para poder efectuar esta operación."
                end
            elseif key == "sinc" then -- sincronizar zoom testear!
                if state.cameras_status then
                    mc:switch_mode_all('rec')
                    local status, zoom_pos, err = mc:get_zoom_from_ref_cam()
                    if status and zoom_pos then
                        print(" Valor zoom leído de cámara de referencia: "..zoom_pos)
                        p.state.zoom_pos = zoom_pos
                        if p:save_state() then
                            if mc:set_zoom_other() then
                                print(" OK: zoom fijado en: "..zoom_pos)
                            else
                                print(" error: No se pudo posicionar el zoom en la otra cámara")
                                print(" Apague las cámaras y vuelva a iniciar DALclick")
                            end
                        else
                            print(" error: no se pudieron guardar las variables de estado en el disco")
                        end
                    else
                        print(" No se pudo leer el valor de zoom de la cámara de referencia.")
                    end
                else
                    loopmsg = " Encienda o reinicie las cámaras para poder efectuar esta operación."
                end
            elseif key == "n" then
                local previous_zoom = p.state.zoom_pos
                local regnum, title = get_project_newname()
                if regnum ~= nil then                
                    printf(" Guardando proyecto anterior... ")
                    if not p:write() then
                        print(" ERROR\n    no se pudo guardar el proyecto actual.")
                        exit = true; break
                    else
                        print("OK")
                    end
                    
                    if not p:init(defaults) then
                        print(" ERROR: no se puedo iniciar el proyecto")
                        exit = true; break
                    end
                    
                    local create_options = { regnum = regnum, title = title, root_path = defaults.root_project_path }
                    if config.zoom_persistent then
                        create_options.zoom = previous_zoom
                    end
                    if p:create( create_options ) then
                        print(" Reiniciando cámaras... ")
                        local cam_status = self:init_cams_or_retry()
                        if cam_status == 'exit' or cam_status == false then
                            exit = true
                            break
                        end
                        if defaults.mode_enable_qm_daemon then
                            self:init_daemons()
                        end
                    end
                 end
            elseif key == "o" then
                local previous_settings_path = self:check_running_project()
                local status
                local open_options = { root_path = defaults.root_project_path }
                print(); status, project_status = p:open(defaults,open_options); print()
                sys.sleep(2000) -- pausa para dejar ver los mensajes
                if status then
                    if project_status == 'canceled' then
                        -- no se hace nada
                    elseif project_status == 'modified' then
                        printf(" El formato del proyecto era obsoleto. Guardando proyecto actualizado...")
                        if p:write() then print("OK") else print("ERROR") end
                        print(" Reiniciando cámaras... ")
                        local cam_status = self:init_cams_or_retry()
                        -- cam_status == 'no_init_select' or cam_status == true --> continue
                        if cam_status == 'exit' or cam_status == false then
                            exit = true
                            break
                        end
                        if defaults.mode_enable_qm_daemon then
                            self:init_daemons()
                        end                 
                    elseif project_status == 'opened' then
                        print(" Reiniciando cámaras... ")
                        local cam_status = self:init_cams_or_retry()
                        -- cam_status == 'no_init_select' or cam_status == true --> continue
                        if cam_status == 'exit' or cam_status == false then
                            exit = true
                            break
                        end
                        if defaults.mode_enable_qm_daemon then
                            self:init_daemons()
                        end                    
                    end
                else                  
                    if p:delete_running_project() then
                        print(" proyecto fallido cerrado")
                        print()
                    end
                    sys.sleep(500)
                    print(" Se restaurará el proyecto previo")
                    local options = { settings_path = previous_settings_path }
                    if not self:start_options('restore_project', options) then
                        exit = true
                        break
                    end
                end
            elseif key == "w" then
                if p:write() then
                    loopmsg = " Proyecto guardado con éxito."
                else
                    loopmsg = " ERROR: El proyecto no pudo guardarse!"
                end
            elseif key == "rec2" then
                -- set to rec mode without waiting (only for testing)
                mc:switch_mode_all('rec')
            elseif key == "play2" then
                -- set to play mode without waiting (only for testing)
                mc:switch_mode_all('play')
            elseif key == "v" then
                if type(p.state.saved_files) == 'table' then
                    if next(p.state.saved_files) then
                        -- print("1) p.state.saved_files: "..util.serialize(p.state.saved_files))
                        local status, previews, filenames = p:make_preview(p.state.saved_files)
                        if status then
                            -- print("2) previews: "..util.serialize(previews))
                            p:show_capts( 'view_last_capture', previews, filenames )
                        end
                     else
                        loopmsg = " El registro de la última captura esta vacío."
                     end
                else
                    loopmsg = " No hay registro de última captura."
                end
            elseif key == "e" then
                if next(p.session.counter_max) then
                    p:show_capts( "explorer" )
                end
            elseif key == "s" then
                if not p:save_state() then
                    print(" error: no se pudieron guardar las variables de estado en el disco")
                    -- print("debug: zoom_pos: "..tostring(p.state.zoom_pos))
                end
                if not mc:shutdown_all() then
                    print("alguna de las cámaras deberá ser apagada manualmente")
                end
                sys.sleep(3000)
                print(" saliendo...")
                exit = true
                break
            elseif key == "c" then
                if p:delete_running_project() then
                    print(" Proyecto '"..p.settings.title.."' cerrado.")
                end
                sys.sleep(2000)
                if not self:start_options('new_project') then
                    exit = true
                    break
                end
            elseif key == "h" then
                if not self:start_options('new_project') then
                    exit = true
                    break
                end
            elseif key == "x" or key == "xx"  then
                local new_project_options = { zoom = p.state.zoom_pos }
                local status, msg
                if key == "xx" then
                    status, msg = p:send_post_proc_actions({ batch_processing = true })
                else
                    status, msg = p:send_post_proc_actions()
                end
                if status then
                    print("\n Proyecto "..p.session.regnum.. ": '"..p.settings.title.."' enviado.")
                    if p:delete_running_project() then
                        print(" Cerrando proyecto..OK")
                    end
                    sys.sleep(2000)
                    
                    if not self:start_options('new_project', new_project_options) then
                        exit = true
                        break
                    end
                end
                if type(msg) == 'string' and msg  ~= "" then loopmsg = " "..tostring(msg) end
            elseif key == "i" then
                print(" Reiniciando cámaras... ")
                local cam_status = self:init_cams_or_retry()
                -- cam_status == 'no_init_select' or cam_status == true --> continue
                if cam_status == 'exit' or cam_status == false then
                    exit = true
                    break
                end
                if defaults.mode_enable_qm_daemon then
                    self:init_daemons()
                end 
            elseif key == "desde" then
                if type(p.state.counter) == 'table' then
                    if p.state.counter.even then
                        if p.state.counter.even <= p.session.counter_max.even then 
                            p.session.include_list.from = p.state.counter.even
                            loopmsg = " Valor 'desde' actualizado ("..tostring(p.session.include_list.from)..")"
                        else
                            loopmsg = " No puede marcarse esta posición (aun no se realizó la captura)"
                        end
                    else
                        loopmsg = " ERROR: el contador no registra valores"
                    end
                end
            elseif key == "hasta" then
                if type(p.state.counter) == 'table' then
                    if p.state.counter.odd then 
                        if p.state.counter.odd <= p.session.counter_max.odd then 
                            p.session.include_list.to = p.state.counter.odd
                            loopmsg = " Valor 'hasta' actualizado ("..tostring(p.session.include_list.to)..")"
                        else
                            loopmsg = " No puede marcarse esta posición (aun no se realizó la captura)"
                        end
                    else
                        loopmsg = " ERROR: el contador no registra valores"
                    end
                end
            elseif key == "reparar" then
                local status, no_errors, log = p:reparar() 
                if status then
                    if no_errors == true then
                        loopmsg = " Reparacion del proyecto exitosa."
                    elseif no_errors == 'warning' then
                        loopmsg = " Reparacion del proyecto exitosa, pero con observaciones."
                    elseif no_errors == false then
                        loopmsg = " Hubo errores al intentar reparar el proyecto."
                    else
                        loopmsg = " Hubo errores al intentar reparar el proyecto."
                    end
                else
                        loopmsg = " No se pudo reparar el proyecto."
                end
                sys.sleep(1000)
            elseif key == "ifocus" then
                if state.cameras_status then
                    mc:get_cam_info('focus')
                    print()
                    print(" Presione <enter> para continuar...")
                    local key = io.stdin:read'*l'
                else
                    loopmsg = " Encienda o reinicie las cámaras para poder efectuar esta operación."
                end
            elseif key == "iexpo" then
                if state.cameras_status then
                    mc:get_cam_info('expo')
                    print()
                    print(" Presione <enter> para continuar...")
                    local key = io.stdin:read'*l'
                else
                    loopmsg = " Encienda o reinicie las cámaras para poder efectuar esta operación."
                end
            elseif key == "dir" then
                open_thunar(p.session.base_path)
            elseif key == "pdf abrir" then
                if p.state.last_pdf_generated then
                    local pdf_path = p.session.base_path.."/"..p.paths.doc_dir.."/"..p.state.last_pdf_generated
                    if dcutls.localfs:file_exists( pdf_path ) then
                       print(" abriendo.. '"..pdf_path.."'")
                       open_evince( pdf_path )
                    else
                       loopmsg = " No existe '"..p.state.last_pdf_generated.."'\n"
                               .."   El archivo PDF no se ha terminado de generar o ha sido eliminado.\n"
                               .."   Para más opciones use 'pdf listar' (verá una lista de los PDFs)"
                    end
                else
                    loopmsg = " Todavía no se ha creado ningún PDF en este proyecto.\n"
                            .."   Para más opciones use 'pdf listar' (verá una lista de los PDFs)"
                end
            elseif key == "pdf listar" then                
                local status, pdf_filename, result, msg = p:list_pdfs_and_select()
                if status == true then
                    local pdf_path = p.session.base_path.."/"..p.paths.doc_dir.."/"..pdf_filename
                    if dcutls.localfs:file_exists( pdf_path ) then
                       print(" abriendo.. '"..pdf_path.."'")
                       open_evince( pdf_path )
                    else
                    end
                elseif status == nil then
                    loopmsg = " "..tostring(msg)
                else
                    
                    loopmsg = " Ha ocurrido un error inesperado."
                end
            elseif key == "pdf borrar" then
                local status, pdf_filename, result, msg = p:list_pdfs_and_select()
                if status == true then
                    print()
                    print(" Borrar '"..pdf_filename.."'? [S/n]")
                    local confirmar = io.stdin:read'*l'
                    if confirmar == "S" or confirmar == "s" then
                        if p:delete_pdf(pdf_filename) then
                            loopmsg = " El archivo '"..tostring(pdf_filename).."' fue borrado"
                        else
                            loopmsg = " El archivo '"..tostring(pdf_filename).."' no pudo borrarse"
                        end
                    end
                elseif status == nil then
                    loopmsg = " "..tostring(msg)
                else
                    loopmsg = " Ha ocurrido un error inesperado."
                end
            elseif key == "scr abrir" or key == "sc abrir" then -- abre sc si existe, de lo contrario lo crea (include)
                local status, strlist, suffix = p:get_include_strings()
                if key == "scr abrir" and not status then
                    loopmsg = " Debe seleccionar un rango de páginas primero para seleccionar esta opción."
                else
                    if key == "sc abrir" then suffix = nil; strlist = nil; end
                    suffix = suffix or ""
                    local sct_name = p.dalclick.doc_filebase..suffix..".scantailor"
                    local sct_path = p.session.base_path.."/"..p.paths.doc_dir.."/"..sct_name
                    if dcutls.localfs:file_exists( sct_path ) then
                       print(" abriendo.. '"..sct_path.."'")
                       open_scantailor_gui( sct_path )
                    else
                        local this_thing = strlist and "este rango seleccionado!" or "este proyecto!"
                        print()
                        print(" No existe un proyecto Scantailor para "..this_thing)
                        print("'"..sct_name.."'")
                        print()
                        print(" Importante! a continuación se creará un nuevo proyecto Scantailor para ser")
                        print(" configurado manualmente desde la interfaz gráfica. Pero si desea que la con-")
                        print(" figuración se lleve a cabo automáticamente y dejar para la operación manual")
                        print(" sólo los ajustes y corrección de errores (recomendado), entonces responda no")
                        print(" y luego use [pp scantailor].")
                        print()
                        print(" Crear proyecto nuevo '"..sct_name.."' [S/n]")
                        local crear = io.stdin:read'*l'
                        if crear == "S" or crear == "s" then
                            local include = strlist and true or false
                            if p:send_post_proc_actions({
                                    scantailor_create_project = true, 
                                    include_list              = include,
                                }) then
                                print(" abriendo.. '"..sct_path.."'")
                                open_scantailor_gui( sct_path )
                            else
                                loopmsg = " No pudo crearse un nuevo proyecto Scantailor '"..tostring(sct_path).."'."
                            end
                        end
                    end
                end
            elseif key == "sc borrar" then
                local status, sc_filename, result, msg = p:list_scantailors_and_select()
                if status == true then
                    print()
                    print(" Borrar '"..sc_filename.."'? [S/n]")
                    local confirmar = io.stdin:read'*l'
                    if confirmar == "S" or confirmar == "s" then
                        if p:delete_scantailor_project(sc_filename) then
                            loopmsg = " El archivo '"..tostring(sc_filename).."' fue borrado"
                        else
                            loopmsg = " El archivo '"..tostring(sc_filename).."' no pudo borrarse"
                        end
                    end
                elseif status == nil then
                    loopmsg = " "..tostring(msg)
                else
                    loopmsg = " Ha ocurrido un error inesperado."
                end
            elseif key == "sc listar" then
                local status, sc_filename, result, msg = p:list_scantailors_and_select()
                if status == true then
                    local stproject_path = p.session.base_path.."/"..p.paths.doc_dir.."/"..sc_filename
                    if dcutls.localfs:file_exists( stproject_path ) then
                       print(" abriendo.. '"..stproject_path.."'")
                       open_scantailor_gui( stproject_path )
                    end
                elseif status == nil then
                    loopmsg = " "..tostring(msg)
                    if result == false then
                        print()
                        print(" Lista vacía!")
                        print()
                        print(" Todavía no ha ejecutado ningun paso del postproceso que haya generado")
                        print(" un archivo Scantailor. Puede crear uno con:")
                        print(" - 'pp scantailor'")
                        print()
                        print(" Presione <enter> para continuar...")
                        local key = io.stdin:read'*l'
                    end
                else
                    loopmsg = " Ha ocurrido un error inesperado."
                end
            elseif key == "rango" then
                if tonumber(p.session.counter_max.odd) > 1 then
                    print("ingrese un valor para 'desde'")
                    printf(">> ")
                    local continue = false
                    local desde = io.stdin:read'*l'
                    if desde ~= "" and desde ~= nil and tonumber(desde) >= 0 then
                        p.session.include_list.from = tonumber(desde)
                        print(" Valor 'desde' ingresado: "..tostring(p.session.include_list.from))
                        continue = true
                    end
                    if continue then
                        print("ingrese un valor para 'hasta'")
                        printf(">> ")
                        local hasta = io.stdin:read'*l'
                        if hasta ~= "" and hasta ~= nil then
                            hasta = tonumber(hasta)
                            if hasta > p.session.include_list.from then
                                if hasta < tonumber(p.session.counter_max.odd) then
                                    p.session.include_list.to = hasta
                                    print(" Valor 'desde' ingresado: "..tostring(p.session.include_list.to))
                                else
                                print(" El valor de 'hasta' debe ser menor a la ultima imagen")
                                end
                            else
                                print(" El valor de 'hasta' debe ser mayor a 'desde'")
                            end
                        end
                    end
                end
            elseif key == "rango borrar" then
                if p.session.include_list.from and p.session.include_list.to then
                    p.session.include_list = {}
                    loopmsg = " Rango de páginas borrado!"
                else
                    loopmsg = " Todavia no se seleccionó ningún rango de páginas."
                end
            elseif key == "pp" or key == "ppr" or key:sub(0,3) == "pp " or key:sub(0,4) == "ppr " or key == "scantailor" then
                if key == "scantailor" then key = "pp scantailor" end
                local include_list_exists = false
                local suffix
                if p.session.include_list.from and p.session.include_list.to then
                    include_list_exists = true
                    suffix = "["..string.format("%04d", p.session.include_list.from).."-"
                                ..string.format("%04d", p.session.include_list.to).."]"
                end
                local ppr = false
                if key:sub(0,4) == "ppr " or key == "ppr" then
                    ppr = true
                end
                if ppr and not include_list_exists then
                    loopmsg = " Debe seleccionar un rango 'desde/hasta' primero"
                else
                    local args
                    if ppr then 
                        args = key:sub(5) 
                    else 
                        args = key:sub(4) 
                        suffix = nil
                        include_list_exists = false
                    end
                    local status, pp_args, msg = parse_pp_args( args )
                    if status then
                        print()
                        print( msg )
                        print()
                        if ppr then print(" procesamiento parcial de rango: "..tostring(suffix).."\n") end
                        print( " ¿Enviar estas acciones a la cola de procesamiento? (S/n)")
                        printf(">> ")
                        local confirm = io.stdin:read'*l'
                        if confirm == "S" or confirm == "s" then
                            if p:send_post_proc_actions({ 
                                pp_mode      = true, 
                                pp           = 'pp='..pp_args, 
                                include_list = include_list_exists,
                            }) then
                                suffix = suffix or ""
                                loopmsg = 
                                    " Proyecto '"..p.session.regnum
                                  .."' ('"..p.settings.title.."') enviado "
                                  ..suffix..pp_args.." OK."
                            else
                                loopmsg = " Hubo errores y el proyecto no pudo ser enviado."
                            end
                        end
                    else
                        loopmsg = msg
                    end
                end
            elseif key == "chdk" then
                if state.cameras_status then
                    print(" recargando chdk scripts...")
                    if not self:load_cam_scripts() then
                        print(' ERROR falló load_cam_scripts()')
                        exit = true
                        break
                    end
                else
                    loopmsg = " Encienda o reinicie las cámaras para poder efectuar esta operación."
                end
            elseif key == "load_secure" then
                if p:load_state_secure() then
                    loopmsg = "load_state_secure: OK"                    
                else
                    loopmsg = "load_state_secure: no se pudo cargar '.dc_state' correctamente"
                end
            else
                loopmsg = " El texto ingresado no corresponde a ninguna opción del menú! ¯\\_(ツ)_/¯"
            end
        end -- /while loop 
        
        if defaults.mode_enable_qm_daemon then
            self:kill_daemons()
        end
        
    end
    if exit == true then
        self:dalclick_loop(false)
    else
        self:dalclick_loop(true)
    end
end




--[[
function dc_set_mode(opts)
    if opts.mode == 'play' then
        if get_mode() then
            switch_mode_usb(0)
        end
    else
        if not get_mode() then
            switch_mode_usb(1)
        end
    end
--
    local i=0
    if opts.mode == 'play' then
        while get_mode() and i < 300 do
            sleep(10)
            i=i+1
        end
    else
        while not get_mode() and i < 300 do
            sleep(10)
            i=i+1
        end
    end
--
    local capmode = require'capmode'
    play_sound(4)
    sleep(100)
    if opts.return_mode then
        return capmode.get_name()
    end
end
]]--

-- ########################

return dc

