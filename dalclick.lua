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
    qm_sendcmd_path = "/opt/src/dalclick/qm/qm_sendcmd.sh",
    qm_daemon_path = "/opt/src/dalclick/qm/qm_daemon.sh",
    empty_thumb_path = "/opt/src/dalclick/empty_g.jpg",
    empty_thumb_path_error = "/opt/src/dalclick/empty.jpg", --TODO debug!
    root_project_path = nil, -- -- main(DALCLICK_PROJECTS)
    left_cam_id_filename = "LEFT.TXT",
    right_cam_id_filename = "RIGHT.TXT",
    odd_name = "odd",
    even_name = "even",
    all_name = "all",
    raw_name = "raw",
    proc_name = "pre", -- processed
    doc_name = "done", -- destino final (pdf, epub, djvu, etc.)
    img_match = "%.JPG$", -- lua exp to match with images in the camera
    folder_match = "^%d", -- lua exp to match with camera folders (las que empiezan con un numero)
    capt_pre = "IMG_",
    capt_ext = "JPG",
    capt_type = 'S', -- D=direct shoot S=standart
    -- regnum = '',
}


defaults.dc_config_path = nil -- main(DIYCLICK_HOME)

local mc={}

-- ### Gnome automount ###


-- ### single cam functions ###

local function switch_mode(lcon,m,wait)
    if wait then
        local opts = {
            mode = m, -- 'play' or 'rec'
            return_mode = true,
        }
        -- print("switch_mode options: "..serialize(opts))
        local status, var1, var2 = lcon:execwait('return dc_set_mode('..util.serialize(opts)..')',{libs={'dalclick_utils'}})
        if status then
            return status, var1, var2 -- var1=mode var2=err
        else
            if var2 then 
                return status, var1, var2
            else 
                return status, false, var1 -- var1=err
            end
        end
    else
        local opts = {
            mode = m
        }
        local status, err = lcon:exec('dc_set_mode('..util.serialize(opts)..')',{libs={'dalclick_utils'}})
        return status, false, err
    end
-- TODO cambiar m por mode y false por nil?
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

function focus_info_cam(lcon)
    local status, var1, var2 = lcon:execwait('return dc_refocus()',{libs={'dalclick_utils'}})
    if status then
        return status, var1, var2
    else
        if var2 then
            return status, var1, var2
        else
            return status, false, var1
        end
    end
end

function refocus_cam(lcon)
    local status, err = lcon:execwait('return dc_refocus()',{libs={'dalclick_utils'}})
    if status then
        return true
    else
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
    local status, var1, var2, set_zoom_status
    print("  fijando zoom a '"..p.state.zoom_pos.."' en la cámara '"..lcon.idname.."'...")
    status, var1 = lcon:execwait('return set_zoom('..p.state.zoom_pos..')')

    local delay = 2
    if p.settings.mode == 'secure' then
        delay = 6
    elseif p.settings.mode == 'normal' then
        delay = 4
    end
    print(" esperando "..delay.." s...")
    for n = 0,delay,1 do
        sys.sleep(1000)
        print(".")
    end

    if status then
        set_zoom_status = "zoom modificado a: "..p.state.zoom_pos.."\n"
        if var1 then
            set_zoom_status = set_zoom_status.." "..tostring(var1).."\n" -- hubo errores o algo paso
        end
        status, var1 = refocus_cam(lcon)
        if var1 then
            return status, set_zoom_status.."\n "..tostring(var1)
        else
            return status, set_zoom_status
        end
    else
        return status, var1
    end
end

function init_cam(lcon)
-- set focus, zoom, and rec mode
    local opts = {}
    if p.state.zoom_pos ~= nil then
        opts = {
            zoom_pos = p.state.zoom_pos,
        }
    end
    local status, err = lcon:execwait('return dc_init_cam('..util.serialize(opts)..')',{libs={'dalclick_identify'}})
    return status, err
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
    
function mc:switch_mode_all(mode,wait)
    print(" set all cams to "..mode.." mode...")
    local setmode_fail = false
    for i,lcon in ipairs(self.cams) do
        local status, return_mode, err = switch_mode(lcon, mode, wait)
        if not status then
            printf(" status: %s, return_mode: %s, err: %s, \n", tostring(status), tostring(return_mode), tostring(err))
            setmode_fail = true
            break
        else
            if return_mode then
                printf("[%i] this cam is now in '%s' mode\n",i,tostring(return_mode))
            end
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
            if set_zoom(lcon) then
                return true
            else
                print(" error: no se pudo fijar el zoom en la otra cámara")
                return false
            end
        end
    end
    return false
end



function mc:refocus_cam_all()
    print("refocus all cams...")
    local refocus_fail = false
    local info = ""
    for i,lcon in ipairs(self.cams) do
        -- local status, focus_info, err = refocus_cam(lcon)
        local status, err = refocus_cam(lcon)
        if not status then
            -- print("status: "..tostring(status)..", focus_info: "..tostring(focus_info)..", err: "..tostring(err))
            print("status: "..tostring(status)..", err: "..tostring(err))
            refocus_fail = true
        else
            -- if focus_info then
            --    if type(focus_info) == 'table' then
            --        info = info.." ["..i.."] focus info:\n"..util.serialize(focus_info).."\n"
            --    else
            --        info = info.." ["..i.."] focus info:\n"..tostring(focus_info).."\n"
            --    end
                -- print("["..i.."] focus info:\n"..format_focus_info(focus_info))
            -- end
        end
    end
    if refocus_fail then
        return false, info
    else
        return true, info        
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
                lcon.condev.dev,
                lcon.condev.bus,
                tostring(lcon.ptpdev.serial_number))
            lcon.mc_id = string.format('%d:%s',i,lcon.ptpdev.model)
            lcon.sn = tostring(lcon.ptpdev.serial_number)
            table.insert(self.cams,lcon)
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
    os.execute("killall qm_daemon.sh") -- TODO: q & d!!!! hay un bug y qm_daemon se inicia aunque haya otro daemos funcioando!
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



function mc:init_cams_all()

    print(" Iniciando cámaras...\n")
    if not mc:connect_all() then
        print(" Revise la conexión de las cámaras y si están encendidas.\n")
        return false
    end

    local init_fail = false
    local previous_cam_idname
    local count_cams = 0
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
        if next(p.state.counter) then
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
        print(" [contador] se reiniciará:")
        p.state.counter = {}
    else
        print(" [contador]:")
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
    for i,lcon in ipairs(self.cams) do
        if type(p.state.zoom_pos) == "number" then
            print(" ["..i.."] poniendo modo 'rec', fijando el zoom a "..p.state.zoom_pos.." y enfocando... ")
        else
            print(" ["..i.."] poniendo modo 'rec' y enfocando... ")
        end
        local status, err = init_cam(lcon)
        if not status then
            init_fail = true
            break
        end
    end
    print()
    --
    if init_fail then
        print("\n\n Alguna de las cámaras ha fallado, por favor apagarlas y volverlas a encender.\n")
        return false
    end
    return true
end

function mc:rotate_all()
    local command, path
    local rotate_fail = false
    local rotate = {}
    rotate['even'] = "90"
    rotate['odd'] = "-90"
    rotate['all'] = "0"
    for idname,saved_file in pairs(p.state.saved_files) do
        -- saved_files[lcon.idname] = {
        -- saved_file.path
        -- path = local_path..file_name
        -- basepath = local_path
        -- basename = file_name
        command = "econvert -i "..saved_file.path.." --rotate "..rotate[idname].." -o "..p.settings.path_proc[idname].."/"..saved_file.basename.." > /dev/null 2>&1"
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
                    print("OK")
                    --print("DEBUG p.state.counter:\n"..util.serialize(p.state.counter))
                    --print("DEBUG p.state.zoom_pos:\n"..util.serialize(p.state.zoom_pos))
                    -- mc:rotate_all( saved_files )
                    if p.state.saved_files and p.settings.rotate == true then
                        if mc:rotate_all() then
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
        print(" ["..i.."] obteniendo nombre de captura... ")
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
            print("      -> A/DCIM/"..lastdir.."/"..lastcapt)
            lcon.remote_path = "A/DCIM/"..lastdir.."/"..lastcapt
            if p.state.saved_files then
                local prev_capt = p.state.saved_files[lcon.idname]
                if prev_capt.remote_path == lcon.remote_path then
                    print(" ======================================================")
                    print(" ATENCION: no se esta descargando la ultima captura!!!!")
                    print(" ======================================================")
                    print(" Vuelva a intentarlo...")
                    print(" Si el problema persiste pruebe en modo 'seguro' ó 'normal'")
                    return true, false
                end
            end
        else
            print(" no se puedo obtener el nombre de la última captura\n status: "..tostring(status)..", lastdir: "..tostring(lastdir)..", lastcapt: "..tostring(lastcapt)..", err: "..tostring(err))
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
        local local_path = p.dalclick.root_project_path.."/"..p.settings.regnum.."/"..p.dalclick.raw_name.."/"..lcon.idname.."/"
        local file_name
        if mode == 'test' then
            file_name = "test.jpg"
        else
            file_name = string.format("%04d", p.state.counter[lcon.idname])..".".."jpg"
        end
        --
        print(" ["..i.."] descargando... "..lcon.remote_path.."\n     "..file_name)
        local results,err = lcon:download(lcon.remote_path, local_path..file_name)
        if results and dcutls.localfs:file_exists(local_path..file_name) then
            saved_files[lcon.idname] = {
                path = local_path..file_name,
                basepath = local_path,
                basename = file_name,
                remote_path = lcon.remote_path,
            }
            print("     OK")
        else
            download_fail = true
            break
        end
    end
    --
    if download_fail then
        -- for practical purposes remove all captures downloaded of this loop
        for idname, saved_file in pairs(saved_files) do
            if remove_last() then
                print(" se borró la captura incompleta")
            end
        end
        return true, false -- capture is not performed but main_loop can continue
    else
        p.state.saved_files = saved_files
        return false, false
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
    local rotate = 0
    local outtype = 'tiff'
    local outdepth = 8
    local command

    for idname,saved_file in pairs(p.state.saved_files) do
        if idname == p.dalclick.odd_name then
            rotate = 90
        elseif idname == p.dalclick.even_name then
            rotate = -90
        end

        command = "ufraw-batch --rotate "..rotate.." --out-type="..outtype.." --out-depth="..outdepth.." --out-path="..saved_file.basepath.." "..saved_file.path
        print(command)
    end
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

function mc:main(DALCLICK_HOME,DALCLICK_PROJECTS)

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

    dalclick_loop(false)

    local exit = false
    print()
    print(" =========================")
    print(" = Bienvenido a DALclick =")
    print(" =========================")
    print()
    
    if not mc:connect_all() then
        print(" Por favor, encienda las cámaras.\n")
        io.write(" luego presione <enter>")
        local key = io.stdin:read'*l'
        if key == "" then
            print(" o/")
        else
            dalclick_loop(false)
            return false
        end
    else
        print(" DALclick debe iniciarse con las cámaras apagadas.\n Por favor apáguelas y luego presione <enter>.\n")
        local key = io.stdin:read'*l'
        dalclick_loop(true)
        return false
    end
    

    --local g = {}
    local status

    if not p:init(defaults) then
        dalclick_loop(false)
        return false
    end

    local settings_path = p:is_broken()
    if settings_path then
        print(" Se encontró un proyecto en ejecución.")
        print(" Restaurando proyecto...")
        status = p:load(settings_path)
        if not status then
            print(" Ha ocurrido un error mientras se intentaba restaurar un proyecto")
        end
    else
        print(" Creando proyecto nuevo...")
        status = p:create()
        if not status then
            print("No se ha podido crear un proyecto")
            return false
        end
    end


    --
    local init_st
    while true do
        init_st = mc:init_cams_all()
        if init_st then
            break
        else
            print(" Ingrese <enter> para reintentar, o\n 'e' + <enter> para salir")
            printf(" >> ")
            local key = io.stdin:read'*l'
            print()
            if key ~= "" then
                dalclick_loop(false)
                return false
            end
        end
    end
    --

    if p.state.counter then
        print(" guardando estado de variables de cámaras...")
        if not p:save_state() then
            print(" error de lectura: No se pudieron las variables df estado del contador en el disco (3)")
            dalclick_loop(false)
            return false
        end
    else
        print(" Error: No se a podido inicializar el contador")
        dalclick_loop(false)
        return false
    end

    -- print("init_cs: "..tostring(init_cs))
    -- print("init_cs: "..util.serialize(init_cs))
    -- print("status: "..tostring(status))
    -- print("counter_state: "..tostring(p.state.counter))
    -- print(util.serialize(p.settings))
    -- print(util.serialize(p.dalclick))
--if 1 then return false end

    local menu = [[

==============================================================================

 -- cámaras --               -- proyectos --          -- varios --

 [enter] capturar            [n] nuevo proyecto       [z] leer zoom de cámara
 [t] test de captura         [o] abrir proyecto           de referencia
 [f] refocus                 [w] guardar proyecto     [b] bip bip bip cámara
 [s] sincronizar zoom        [q] salir de DALclick        de referencia
 [d] borrar última captura   [barra] reinic. camaras  [r] modo 'rec'
 [v] preview última captura                           [p] modo 'play'
 [x] apagar cámaras                                   [m] modo seg/norm/rápido

]]
    if not init_st then
        print("No se pudieron inicializar correctamente las cámaras")
        dalclick_loop(false)
        return false
    else

        -- init daemons!
        mc:init_daemons()

        local loopmsg = ""
        while true do
            mc:camsound_plip()
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
                if mc:capt_all('test') then
                    sys.sleep(500)
                else
                    exit = true
                    break
                end
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
                print("refocus...")
                local status, info = mc:refocus_cam_all()
                if status then
                    loopmsg = info
                else
                    loopmsg = "alguna de las cámaras no pudo reenfocar, por favor apáguelas y reinicie el programa\n"..info
                end
            elseif key == "d" then
                print("borrando última captura...")
                remove_last('counter_prev')
            elseif key == "r" then
                mc:switch_mode_all('rec',true)
            elseif key == "p" then
                mc:switch_mode_all('play',true)
            elseif key == "z" then
                mc:switch_mode_all('rec',true)
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
                mc:switch_mode_all('rec',true)
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
                if p:write() then
                    if p:clear() then
                        print(" listo para crear nuevo proyecto...")
                        break
                    else
                        print(" error: no se puede iniciar nuevo proyecto.")
                        exit = true
                        break
                    end
                else
                    print(" error: no se pudo guardar el proyecto actual.")
                end
            elseif key == "o" then
                p:open()
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
                exit = true
                print("exit...")
                break
            end
        end
    end
    if exit == true then
        dalclick_loop(false)
    else
        dalclick_loop(true)
    end
end


local function init()
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
    chdku.rlibs:register({
        name='dalclick_utils',
        code=[[
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

function dc_refocus()
    sleep(200)
    set_aflock(0)
    sleep(500)
    press('shoot_half')
    i=0
    while get_shooting() do
        sleep(10)
        if i > 300 then
            break
        end
        i=i+1
    end
    sleep(200)
    set_aflock(1)
    sleep(200)
    release('shoot_half')
--
    sleep(1000)
    play_sound(4); sleep(150); play_sound(4); sleep(150); play_sound(4)
    sleep(200) 
--
end

function dc_focus_info()
    sleep(200)
    focus_info = {}
    focus_info.focus_state = get_focus_state() -- 0 = OK
    sleep(100)
    focus_info.focus = get_focus() -- val
    sleep(100)
    focus_info.focus_mode = get_focus_mode() -- 0=auto, 1=MF, 3=inf., 4=macro, 5=supermacro 
    sleep(100)
    focus_info.IS_mode = get_IS_mode() -- 0,1,2,3 = continous, shoot only, panning, off 
    sleep(100)
--
    sleep(1000)
    play_sound(4); sleep(150); play_sound(4); sleep(150); play_sound(4)
    sleep(200) 
--
    return focus_info
end
]],
    })
end

init()


-- ########################

return mc

