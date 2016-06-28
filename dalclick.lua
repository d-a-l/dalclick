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
./chdkptp -e"exec mc=require('dalclick')" -e"exec return mc:main()"

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
    test_low_name = '_low'
    -- regnum = '',
}

defaults.dc_config_path = nil -- main(DIYCLICK_HOME)

local mc={}

-- ### Gnome automount ###


-- ### single cam functions ###

local function switch_mode(lcon,mode)
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

function identify_cam(lcon)

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

function refocus_cam(lcon)
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


local function get_zoom(lcon)

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

local function set_zoom(lcon) 
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

function init_cam(lcon)
-- set focus, zoom, and rec mode
    local opts = {}
    if p.state.zoom_pos ~= nil then
        opts = {
            zoom_pos = p.state.zoom_pos,
            log_format = 'serialized'
        }
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

-- ### multicam functions ###


function mc:camsound_plip()
    for i,lcon in ipairs(self.cams) do
        lcon:exec("play_sound(2)")
        sys.sleep(200) -- avoid running simultaneously
    end
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
        local status, data = switch_mode(lcon, mode)
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
            local status, zoom_pos, err = get_zoom(lcon)
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
            local status, data = set_zoom(lcon)
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
            local status, data = refocus_cam(lcon)
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

function get_cam_info(lcon, option)
       
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

function print_cam_info(data, depth, item)

    local depth = depth or 0
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
        --
        if value_descriptor ~= "" then
            print (tab..tostring(data.label)..": "..value_descriptor.." ("..tostring(data.value)..")")
        else
            print (tab..tostring(data.label)..": "..tostring(data.value)..tostring(data.units))
        end
        if data.help then
            print (tab..tostring(data.help))
        end
    end 
end

function mc:get_cam_info(option)
    if option == nil then
        print(" ERROR: mc:get_cam_info() no option param")
        return false
    end
    
    for i,lcon in ipairs(self.cams) do
        local status, data = get_cam_info(lcon, option)
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
        local status, data = refocus_cam(lcon)
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
        print(" Aparentemente no hay cámaras conectadas al equipo\n")
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

function mc:init_daemons()

    -- os.execute("ps aux | grep '[q]m_daemon.sh' > /tmp/qm_daemon_ps_info")
    -- if dcutls.localfs:file_exists('/tmp/qm_daemon_ps_info') then
    --     local content = dcutls.localfs:read_file('/tmp/qm_daemon_ps_info')
    --     if content ~= "" then
    --         print("proceso/s encontrado: "..tostring(content))
    --     end
    -- end

    print(" iniciando procesos en segundo plano...")
    os.execute("killall qm_daemon.sh 2>&1") -- TODO: q & d!!!! hay un bug y qm_daemon se inicia aunque haya otro daemos funcioando!
    
    if not dcutls.localfs:file_exists(p.settings.path_raw.odd) or not dcutls.localfs:file_exists(p.settings.path_raw.even) then
        print(" error: init_daemons: no existen path_raw... \n  "..p.settings.path_raw.odd.."\n  "..p.settings.path_raw.odd)
        return false
    end
    os.execute(p.dalclick.qm_daemon_path.." "..p.settings.path_raw.odd.." &")
    os.execute(p.dalclick.qm_daemon_path.." "..p.settings.path_raw.even.." &")
    return true

    -- para enviar un comando al queue
    -- os.execute(p.dalclick.qm_sendcmd_path..' "'..p.path_raw.even..'"')
end

function mc:kill_daemons()
    print(" terminando procesos en segundo plano...")
    os.execute("killall qm_daemon.sh 2>&1") -- TODO: qm_daemon se deberia apagar creando un archivo 'quit' en job folder
end

function mc:init_cams_all(zoom)

    print(" Verificando conexión cámaras:")
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
    
    local init_fail = false
    local init_fail_err = ""
    local previous_cam_idname
    local count_cams = 0
    print(" Identificando cámaras")
    for i,lcon in ipairs(self.cams) do
        count_cams = count_cams + 1
        local status, idname, err = identify_cam(lcon)
        if idname then
            if previous_cam_idname then
                -- if there are two cameras, we need that are correctly identified
                if previous_cam_idname == idname then
                    print(" ["..i.."] no se puede inicializar, ambas cámaras estan identificadas con el mismo id\n[1] -> "..previous_cam_idname.." [2] -> "..idname)
                    init_fail = true
                    break
                end
                if previous_cam_idname == 'all' or idname == 'all' then
                    print(" ["..i.."] no se puede inicializar, las cámaras no están correctamente identificadas\n[1] -> "..previous_cam_idname.." [2] -> "..idname)
                    init_fail = true
                    break
                end
            else
                previous_cam_idname = idname
            end
            -- add identification values to lcon
            print(" ["..i.."] idname: "..tostring(idname))
            lcon.idname = idname
        else
            print(" ["..i.."] no se puedo inicializar:\n status: "..tostring(status).." err: "..tostring(err))
            init_fail = true
            break
        end
    end
    if count_cams == 1 then
        print()
        print(" Atención! Solo hay una cámara conectada")
        print()
    elseif count_cams == 0 then
        print()
        print(" Atención! No hay cámaras conectadas!")
        print()
    end
    print()
    --
    -- verify cams found with cams projects
    local found = false
    if type(p.state.counter) == 'table' then
        if next(p.state.counter) then -- comprueba que la tabla no está vacía?
            for id, num in pairs(p.state.counter) do
                for i,lcon in ipairs(self.cams) do
                    if lcon.idname == id then
                        found = true
                    end
                end
                if not found then
                    print(" El número de cámaras conectadas no coincide con la configuracion del proyecto.")
                    print(" No está encendida o no responde: '"..id.."'")
                    print(" Verifique que las dos cámaras esten encendidas, o apáguelas y vuelva a encenderlas.")
                    return false
                else
                    found = false
                end
            end
        end
    end
    --
    if init_fail then
        print("\n\n Alguna de las cámaras ha fallado, por favor apagarlas y volverlas a encender.\n")
        return false
    end
    --
    local restore_saved_counter = false
    if type(p.state.counter) == 'table' then
        local idname, count
        for idname, count in pairs(p.state.counter) do
            -- If the value is 0 or 1 means not yet made ​​any capture
            if count > 1 then restore_saved_counter = true end
        end
    end
    if not restore_saved_counter then
        print(" Contador reiniciado:")
        p.state.counter = {}
    else
        print(" Contador:")
    end
    for i,lcon in ipairs(self.cams) do
        if restore_saved_counter then
            if p.state.counter[lcon.idname] then
                lcon.count = p.state.counter[lcon.idname]
                print(" ["..i.."] cámara '"..lcon.idname.."': "..lcon.count)
            else
                print(" ["..i.."] Los nombres de las camaras no coinciden con los datos")
                print(" ["..i.."] guardados en la última sesión.")
                init_fail = true
                break
            end
        else
            if lcon.idname == p.dalclick.odd_name then
                p.state.counter[lcon.idname] = 1
            elseif lcon.idname == p.dalclick.even_name then
                p.state.counter[lcon.idname] = 0
            else
                p.state.counter[lcon.idname] = 1
            end
            print(" ["..i.."] cámara '"..lcon.idname.."': "..p.state.counter[lcon.idname])
        end
    end
    print()
    --
    if init_fail then
        print("\n\n Inicie un nuevo proyecto o corrija manualmente el problema.")
        return false
    end
    --
    if p.state.counter then
        print(" guardando estado de variables de cámaras...")
        if not p:save_state() then
            print(" error de lectura: No se pudieron guardar las variables del estado del contador en el disco (3)")
            return false
        end
    else
        print(" Error: No se ha podido inicializar el contador")
        return false
    end

    -- inicio de camaras

    -- check SD
    print()
    local check_status = mc:check_sdcams_options() 
    if check_status == nil then
        print(" Apagando cámaras...")
        if not mc:shutdown_all() then
            print("alguna de las cámaras deberá ser apagada manualmente")
        end
        sys.sleep(1000)
        return nil
    elseif check_status == false then
        print(" debug: check_sdcams_options() = false")
        return false
    end
    
    -- set cams
    --
    print()
    if type(zoom) == 'number' then
        p.state.zoom_pos = zoom
        print(" debug: zoom actualizado a "..tostring(zoom))
    end
    
    if type(p.state.zoom_pos) == "number" then
        if not p:save_state() then
            print(" error de lectura: No se pudieron guardar las variables del estado del contador en el disco (3)")
            return false
        end
    end

    if not p.state.rotate then
        p.state.rotate = {}
    end    
    if not p.state.rotate.odd or not p.state.rotate.even then
        p.state.rotate.odd = defaults.rotate_odd
        print(" asignada rotación por defecto para cámara de páginas impares: "..p.state.rotate.odd)
        p.state.rotate.even = defaults.rotate_even
        print(" asignada rotación por defecto para cámara de páginas pares: "..p.state.rotate.even)
        if not p:save_state() then
            print(" error de lectura: No se pudieron guardar las variables del estado del contador en el disco (3)")
            return false
        end
    end
    
    for i,lcon in ipairs(self.cams) do
        print(" ["..i.."] preparando cámara:")
        local status, var = init_cam(lcon)
        if status then
            local arr_data = util.unserialize(var)
            print_cam_info(arr_data, 1, '')
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

local function init_cams_or_retry(zoom)

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
 [e] para salir

==============================================================================]]

    while true do
        status = mc:init_cams_all(zoom) -- true: ok, seguir - false: error, reintentar - nil: se eligio salir
        if status == true then
            break
        elseif status == nil then
            return nil
        elseif status == false then
            print(menu)
            printf(" >> ")
            local key = io.stdin:read'*l'
            print()
            if key ~= "" then
                return false
            end
        end
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
                return nil
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
        command = "econvert -i "..saved_file.path.." --rotate "..p.state.rotate[idname].." -o "..p.settings.path_proc[idname].."/"..saved_file.basename.." > /dev/null 2>&1"
        print(" ["..idname.."] enviando comando (rotar) a la cola de acciones") 
        if not os.execute(p.dalclick.qm_sendcmd_path..' '..p.settings.path_raw[idname]..' "'..command..'"') then
            print(" error: falló: "..p.dalclick.qm_sendcmd_path..' '..p.settings.path_raw[idname]..' "'..command..'"')
            rotate_fail = true
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
        local thumbpath = p.settings.path_proc[idname].."/"..p.dalclick.thumbfolder_name
        if not dcutls.localfs:file_exists( thumbpath ) then
            if not dcutls.localfs:create_folder( thumbpath ) then
                print(" ERROR: no se pudo crear '"..thumbpath.."'")
                return false
            end
        end
        command = 
            "econvert -i "..saved_file.path
          .." --rotate "..p.state.rotate[idname]
          .." -o "..p.settings.path_proc[idname].."/"..saved_file.basename
          .." --thumbnail ".."0.125"
          .." -o "..thumbpath.."/"..saved_file.basename
          .." > /dev/null 2>&1"
        print(" ["..idname.."] enviando de comando de procesamiento a la cola de acciones ("..saved_file.basename..").") 
        if not os.execute(p.dalclick.qm_sendcmd_path..' '..p.settings.path_raw[idname]..' "'..command..'"') then
            print(" error: falló: "..p.dalclick.qm_sendcmd_path..' '..p.settings.path_raw[idname]..' "'..command..'"')
            rotate_fail = true
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

    if p:load_state() then
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

function mc:capt_all_test_and_preview() -- zzzz

    if p:load_state() then

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
                        p.settings.path_test[idname]
                        .."/"..saved_file.basename_without_ext..".jpg",
                    high_path =  
                        p.settings.path_test[idname]
                        .."/"..saved_file.basename_without_ext..defaults.test_high_name..".jpg",
                    low_path  =
                        p.settings.path_test[idname]
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

                print(" Procesando test '"..saved_file.basename_without_ext.."'")
                if not os.execute(command) then
                    print(" error: falló: "..command..'"')
                    command_fail = true
                else
                    previews[idname] = command_paths[idname].low_path
                end
            end
            -- show preview
            
            if not command_fail then
                -- preview
                p:show_capts(previews)
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
            local_path = p.dalclick.root_project_path..
                        "/"..p.settings.regnum.. 
                        "/"..p.dalclick.test_name..
                        "/"..lcon.idname.."/"
        else
            local_path = p.dalclick.root_project_path..
                        "/"..p.settings.regnum..
                        "/"..p.dalclick.raw_name..
                        "/"..lcon.idname.."/"            
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

local function remove_last(mode)
    local remove_fail = false
    if type(p.state.saved_files) == 'table' then
        if next(p.state.saved_files) then
            for idname, saved_file in pairs(p.state.saved_files) do
                if dcutls.localfs:delete_file(saved_file.path) then
                    print(" ["..idname.."] '"..saved_file.path.."' eliminado")
                    p.state.saved_files[idname].path = nil
                    --p.state.saved_files[idname].basepath = nil
                    p.state.saved_files[idname].basename = nil
                else
                    remove_fail = true
                end
            end
        else
            print(" error: remove_last() p.state.saved_files es una tabla vacía")
            return false
        end
    else
        print(" error: remove_last() p.state.saved_files no es una tabla")
        return false
    end
    if p:save_state() then
        print(" estado de cámaras guardado")
    else
        print(" Error: no se pudo escribir en el disco, estado de cámaras no fue guardado")
    end
    if remove_fail then
        return false
    else
        if mode == 'counter_prev' then
            if p:counter_prev() then
                print(" contador hacia atras... OK")
                if p:save_state() then
                    print(" estado de cámaras guardado")
                else
                    print(" Error: no se pudo escribir en el disco, estado de cámaras no fue guardado")
                end
                for idname,count in pairs(p.state.counter) do
                    print(" ["..idname.."]: "..count)
                end
                return true
            else
                print(" ERROR: el contador no se pudo modificar")
                for idname,count in pairs(p.state.counter) do
                    print(" ["..idname.."]: "..count)
                end
                return false
            end
        else
            return true
        end
    end
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

local function start_options(mode)
    -- 
    -- iniciando la estructura para un proyecto
    if not p:init(defaults) then
        return false
    end

    -- iniciando proyecto (carga proyecto anterior o crea nuevo)
    local running_project_loaded = false

    if mode == "restore_running_project" then    
        local settings_path = p:is_broken() -- get settings_path from saved running project
        if settings_path then
            print(" Se encontró un proyecto en ejecución.")
            print(" Restaurando proyecto...")
            if p:load(settings_path) then
                running_project_loaded = true
            else
                print(" Ha ocurrido un error mientras se intentaba restaurar el proyecto")
                sys.sleep(2000)
            end
        else
            print(" No se encontró un proyecto previo para restaurar")
            print()
        end
    end
    
    local start_menu = [[






== Opciones de Inicio=========================================================

 [n] Crear un nuevo proyecto
 [o] Abrir un proyecto existente
 
 [enter] Salir

==============================================================================]]

    if not running_project_loaded then    
        repeat
            print(start_menu)
            printf(">> ")
            local key = io.stdin:read'*l'

            if key == "" then
                return false
            elseif key == "n" then
                print(); print(" Seleccionó: Crear Nuevo Proyecto...")
                local regnum, title = p:get_project_newname()
                if regnum ~= nil then
                    if not p:init(defaults) then
                        return false
                    end
                    if p:create( regnum, title ) then
                        break
                    end
                end
            elseif key == "o" then
                print(); print(" Seleccionó: Abrir Proyecto...")
                if p:open(defaults) then
                    break
                end
            end
        until false
    end

    return true
end

local function dalclick_loop(mode)
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

local function load_cam_scripts()
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

function mc:main(DALCLICK_HOME,DALCLICK_PROJECTS,DALCLICK_PWDIR,ROTATE_ODD_DEFAULT,ROTATE_EVEN_DEFAULT)

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
    end

    if DALCLICK_PWDIR then 
        defaults.dalclick_pwdir = DALCLICK_PWDIR
    else
        defaults.dalclick_pwdir = '/opt/src/dalclick'
    end
    
    defaults.qm_sendcmd_path = defaults.dalclick_pwdir.."/qm/qm_sendcmd.sh"
    defaults.qm_daemon_path = defaults.dalclick_pwdir.."/qm/qm_daemon.sh"
    defaults.empty_thumb_path = defaults.dalclick_pwdir.."/empty_g.jpg"
    defaults.empty_thumb_path_error = defaults.dalclick_pwdir.."/empty.jpg"

    -- --
    if not load_cam_scripts() then
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
    
    dalclick_loop(false)

    local exit = false
    print()
    print(" =========================")
    print(" = Bienvenido a DALclick =")
    print(" =========================")
    print()
    
    -- el objetivo de este bloque es que las camaras esten apagadas y se enciendan ahora
    local no_init_cam
    if not mc:connect_all() then
        print(" Por favor, encienda las cámaras.\n")
        printf(" luego presione <enter>")
        local key = io.stdin:read'*l'
        if key == "" then
            print(" o/")
        else
            dalclick_loop(false)
            return false
        end
    else
        print(" DALclick debe iniciarse con las cámaras apagadas.")
        print(" Por favor apáguelas y luego presione <enter>.")
        print()
        print(" (Para continuar sin apagar: [c] y luego <enter>)")
        print(" (Para continuar sin apagar ni reiniciar: [cc] y luego <enter>)")
        local key = io.stdin:read'*l'

        if key == "" then
            dalclick_loop(false)
            return false
        elseif key == "c" then
            -- continue
        elseif key == "cc" then
            no_init_cam = true
            -- continue
        end   
    end
    
    -- opciones al inicio
    if not start_options('restore_running_project') then
        dalclick_loop(false)
        return false
    end
    
    local init_st
    if no_init_cam then
        print(" Eligió no inicializar las cámaras.")
        init_st = true
    else
        init_st = init_cams_or_retry()
    end

    -- ToDo: el siguiente bloque parece redundante, no deberia poder cargarse un proyecto sin su contador ok
    --[[
    if p.state.counter then
        print(" guardando estado de variables de cámaras...")
        if not p:save_state() then
            print(" error de lectura: No se pudieron las variables df estado del contador en el disco (3)")
            dalclick_loop(false)
            return false
        end
    else
        print(" Error: No se ha podido inicializar el contador")
        dalclick_loop(false)
        return false
    end
    ]]

    -- print("init_cs: "..tostring(init_cs))
    -- print("init_cs: "..util.serialize(init_cs))
    -- print("status: "..tostring(status))
    -- print("counter_state: "..tostring(p.state.counter))
    -- print(util.serialize(p.settings))
    -- print(util.serialize(p.dalclick))
--if 1 then return false end

    local menu = [[

 -- cámaras --               -- proyectos --          -- varios --

 [enter] capturar            [n] nuevo proyecto       [z] leer zoom de cámara
 [t] test de captura         [o] abrir proyecto           de referencia
 [f] refocus                 [w] guardar proyecto     [b] bip bip bip cámara
 [s] sincronizar zoom        [c] cerrar proyecto          de referencia
 [d] borrar última captura       y salir             [zz] ingresar un valor
 [v] preview última captura  [i] reiniciar cámaras        de zoom manualmente
 [x] apagar cámaras          [q] salir                [m] modo seg/norm/rápido

]]
    if init_st == false then
        print(" No se pudieron inicializar correctamente las cámaras.")
        dalclick_loop(false)
        return false
    elseif init_st == nil then
        print(" Eligió salir.")
        dalclick_loop(false)
        return false
    else

        -- init daemons
        mc:init_daemons()
               
        local loopmsg = ""
        local margin
        local status, counter_min, counter_max
        while true do

            status, counter_min, counter_max = p:get_counter_max_min()
            if not status then
                print(" ERROR: no se puede actualizar la lista de capturas realizadas.")
            end
        
            mc:camsound_plip()

            print()
            print(" Proyecto: ["..p.settings.regnum.."]" )
            if counter_min and counter_max then
                printf(" Capturas realizadas: "
                    ..string.format("%04d", counter_min[defaults.even_name])
                    .."-"
                    ..string.format("%04d", counter_min[defaults.odd_name])
                    )
                if counter_min[defaults.even_name] ~= counter_max[defaults.even_name] then
                    print(" a "
                    ..string.format("%04d", counter_max[defaults.even_name])
                    .."-"
                    ..string.format("%04d", counter_max[defaults.odd_name])
                    )
                end
            end
            print()
            margin = math.floor( ( 76 - string.len(string.sub(p.settings.title, 0, 50)) ) / 2 )
            print( string.rep("=", margin).." "..string.sub(p.settings.title, 0, 50).." "..string.rep("=", margin))
            print()
            print(menu)
            print("= "..string.format("%04d", p.state.counter['even']).." ================================================================ "..string.format("%04d", p.state.counter['odd']).." =")
            if loopmsg ~= "" then 
                print(loopmsg)
                loopmsg = ""
            end
            printf(">> ")
            local key = io.stdin:read'*l'

            if key == "" then
                print("capturando...")
                if mc:capt_all() then
                    sys.sleep(500)
                else
                    exit = true
                    break
                end
            elseif key == "t" then
                print("captura de test a test.jpg...")
                if mc:capt_all_test_and_preview() then
                -- if mc:capt_all('test') then
                    sys.sleep(500)
                else
                    exit = true
                    break
                end
            elseif key == "tt" then
                local status, err = mc:testthis()
                if status then
                    sys.sleep(500)
                else
                    print("ERROR!")
                    print(err)
                end
                local key = io.stdin:read'*l'
            elseif key == "m" then
                if p.settings.mode == 'secure' then
                    p.settings.mode = 'normal'
                    loopmsg = "modo cambiado a 'normal' (4s)"
                elseif p.settings.mode == 'normal' then
                    p.settings.mode = 'fast'
                    loopmsg = "modo cambiado a 'rápido' (2s)"
                else
                    p.settings.mode = 'secure'
                    loopmsg = "modo cambiado a 'seguro' (8s)"
                end

            elseif key == "f" then
                print(" refocus...")
                print()
                local status, info = mc:refocus_cam_all()
                if status then
                    loopmsg = info
                else
                    loopmsg = "alguna de las cámaras no pudo reenfocar, por favor apáguelas y reinicie el programa\n"..info
                end
            elseif key == "ff" then
                mc:get_cam_info('focus')
                print()
                print(" Presione <enter> para continuar...")
                local key = io.stdin:read'*l'
            elseif key == "ee" then
                mc:get_cam_info('expo')
                print()
                print(" Presione <enter> para continuar...")
                local key = io.stdin:read'*l'
            elseif key == "d" then
                print("borrando última captura...")
                remove_last('counter_prev')
            elseif key == "gg" then
                print(" recargando chdk scripts...")
                if not load_cam_scripts() then
                    print(' ERROR falló load_cam_scripts()')
                    exit = true
                    break
                end
            elseif key == "zz" then                
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
                        else
                            print(" error: no se pudieron guardar las variables de estado en el disco")
                        end
                        print(" Reiniciando camaras... ")
                        if not init_cams_or_retry() then
                            exit = true
                            break
                        end 
                    end
                end
            elseif key == "r" then
                mc:switch_mode_all('rec')
            elseif key == "p" then
                mc:switch_mode_all('play')
            elseif key == "z" then
                mc:switch_mode_all('rec')
                local status, zoom_pos, err = self:get_zoom_from_ref_cam()
                if status and zoom_pos then
                    p.state.zoom_pos = zoom_pos 
                    loopmsg = "Valor zoom leído de cámara de referencia: "..zoom_pos.."\n"
                    if p:save_state() then
                        print(" nuevo valor de zoom guardado")
                    else
                        print(" error: no se pudieron guardar las variables de estado en el disco")
                    end
                else
                    loopmsg = " Error: No se pudo leer el valor de zoom de la cámara de referencia.\n error: "..err.."\n"
                end
            elseif key == "b" then
                mc:camsound_ref_cam()
                sys.sleep(2000)
            elseif key == "s" then -- sincronizar zoom
                mc:switch_mode_all('rec')
                local status, zoom_pos, err = self:get_zoom_from_ref_cam()
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
            elseif key == "x" then
                print("apagando cámaras...")
                if not mc:shutdown_all() then
                    print("alguna de las cámaras deberá ser apagada manualmente")
                end
                sys.sleep(1000)
                exit = true
                break
            elseif key == "n" then
                local zoom = p.state.zoom_pos
                print("debug: zoom ----> "..tostring(zoom).." - "..type(zoom))
                local status = p:save_current_and_create_new_project(defaults)
                if status == nil then
                    -- continue
                elseif status == false then
                    exit = true
                    break
                else                
                    if init_cams_or_retry(zoom) then
                        mc:init_daemons()
                    else
                        exit = true
                        break
                    end
                    --[[
                    if p.state.counter then
                        if not p:save_state() then
                            print(" Error: no se pudo actualizar la configuración interna de DALclick")
                            exit = true
                            break
                        end
                    else
                        print(" Error: No se a podido inicializar el nuevo contador")
                        exit = true
                        break
                    end
                    ]]
                end
            elseif key == "o" then
                local status
                print(); status = p:open(defaults); print()
                sys.sleep(2000) -- pausa para dejar ver los mensajes
                if status == true then
                    if init_cams_or_retry() then
                       mc:init_daemons()
                    else
                       exit = true
                       break
                    end
                elseif status == false then
                    print(" saliendo...")
                    sys.sleep(3000)
                    exit = true
                    break
                -- con status == nil continua (significa que el usuario cancelo la operacion)
                end
            elseif key == "w" then
                p:write()
            elseif key == "rr" then
                -- set to rec mode without waiting (only for testing)
                mc:switch_mode_all('rec')
            elseif key == "pp" then
                -- set to play mode without waiting (only for testing)
                mc:switch_mode_all('play')
            elseif key == "v" then
                -- external commands testing
                -- os.execute("echo 'test'; sleep 3")
                -- os.execute("/opt/src/test &")
                if p.state.saved_files then
                    -- debug print("1) p.state.saved_files: "..util.serialize(p.state.saved_files))
                    local status, previews = p:make_preview()
                    if status then
                        -- debug print("2) previews: "..util.serialize(previews))
                        p:show_capts( previews )
                    end
                end
            elseif key == " " then
                print(" Apague las cámaras, luego presiona <enter>")
                printf(">> ")
                local key = io.stdin:read'*l'
                print("reinciando cámaras...")
                break
            elseif key == "q" then
                if not p:save_state() then
                    print(" error: no se pudieron guardar las variables de estado en el disco")
                    print("debug: zoom_pos: "..tostring(p.state.zoom_pos))
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
                if not start_options() then
                    if not mc:shutdown_all() then
                        print(" Error: Alguna de las cámaras deberá ser apagada manualmente.")
                        sys.sleep(3000)
                    end
                    print(" Saliendo de DALclick...")
                    exit = true
                    break
                end
                if not init_cams_or_retry() then
                   exit = true
                   break
                end
            elseif key == "i" then
                if not init_cams_or_retry() then
                   exit = true
                   break
                end
            end
        end -- /while loop 
        
        mc:kill_daemons()
        
    end
    if exit == true then
        dalclick_loop(false)
    else
        dalclick_loop(true)
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

return mc

