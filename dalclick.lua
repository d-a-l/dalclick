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
current_project = require('project')
local cabildo = require('cabildo')

local defaults={
    -- qm_sendcmd_path = "/opt/src/dalclick/qm/qm_sendcmd.sh",
    -- qm_daemon_path = "/opt/src/dalclick/qm/qm_daemon.sh",
    -- empty_thumb_path = "/opt/src/dalclick/empty_g.jpg",
    -- empty_thumb_path_error = "/opt/src/dalclick/empty.jpg", --TODO debug!
    dalclick_project_version = 20180414, -- version compatible de proyecto
    root_project_path = nil, -- -- main(DALCLICK_PROJECTS)
    left_cam_id_filename = "LEFT.TXT",
    right_cam_id_filename = "RIGHT.TXT",
    noc_mode_default = 'odd-even',
    noc_mode_undefined = 'odd-even',
    oddeven_default_ref_cam = "even",
    single_default_ref_cam = "single",
    oddeven_default_rotate = true,
    single_default_rotate = true, --false,
    --rotate_default = true,
    --ref_cam_default = "even",
    odd_name = "odd",
    even_name = "even",
    all_name = "all",
    single_name = "single",
    raw_name = "raw",
    proc_name = "pre", -- pre-processed
    post_name = "proc", -- post-processed
    logs_name = ".logs", -- post-processed
    ppp_default_name = "Default", -- post-process project default name
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
    rotate_single = '180',
    tempfolder_name = '.tmp',
    thumbfolder_name = '.previews',
    test_high_name = '_high',
    test_low_name = '_low',
    mode_enable_qm_daemon = false,
    autorestore_project_on_init = true,
    -- delay_mode = 'secure',
    -- regnum = '',
}

defaults.doc_filename = defaults.doc_filebase.."."..defaults.doc_fileext

defaults.paths = {}

defaults.paths.raw_dir = defaults.raw_name
defaults.paths.raw = {
    even = defaults.raw_name.."/"..defaults.even_name,
    odd =  defaults.raw_name.."/"..defaults.odd_name,
    all =  defaults.raw_name.."/"..defaults.all_name,
    single = defaults.raw_name.."/"..defaults.single_name,
}
defaults.paths.proc_dir = defaults.proc_name
defaults.paths.proc = {
    even = defaults.proc_name.."/"..defaults.even_name,
    odd = defaults.proc_name.."/"..defaults.odd_name,
    all = defaults.proc_name.."/"..defaults.all_name,
    single = defaults.proc_name.."/"..defaults.single_name,
}
defaults.paths.test_dir = defaults.test_name
defaults.paths.test = {
    even = defaults.test_name.."/"..defaults.even_name,
    odd = defaults.test_name.."/"..defaults.odd_name,
    all = defaults.test_name.."/"..defaults.all_name,
    single = defaults.test_name.."/"..defaults.single_name,
}
defaults.paths.doc_dir = defaults.doc_name
defaults.paths.post_dir = defaults.post_name
defaults.paths.logs_dir = defaults.logs_name

local state = {
    cameras_status = nil,
    cameras_status_msg = "",
    show_cam_status_info = false,
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
local actions={} --  user actions func

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

-- Envia un plip a las camaras y obtiene datos de su estado

-- 1 detectada (detectada en el usb) gris
-- 2 operativa (inicializada e identificada por dalclick/chdk) amarilla
-- 3 lista (modo y objetivo desplegado para click) verde

-- 4 desconfigurada o mal configurada: lcon:connect() -> false rojo1
-- 5 idem: c_pip_cam() -> status false rojo2

    local dalclick_detected = {}
    local usb_conected = {}


    if type(self.cams) ~= 'table' then
        -- ninguna camara operativa, nunca inicializadas
        dalclick_detected = false
    else
       if not next(self.cams) then
           -- ninguna camara operativa
          dalclick_detected = nil
       else
          for i, lcon in ipairs(self.cams) do
             dalclick_detected[i] = {}
             dalclick_detected[i].idname = lcon.idname
             if type(lcon.condev) == 'table'
                and lcon.condev.dev and lcon.condev.bus then
                dalclick_detected[i].devbus = lcon.condev.dev..lcon.condev.bus
             end
             -- print("dalclick_detected[i].devbus: '"..tostring(dalclick_detected[i].devbus).."'")
             local is_connected
             if lcon:is_connected() then
                is_connected = true
             else
                local status,err = lcon:connect()
                if not status then
                   -- warnf('%d: connect failed dev:%s, bus:%s, err:%s\n',i,devinfo.dev,devinfo.bus,tostring(err))
                   -- connect_fail
                   is_connected = false
                   dalclick_detected[i].status = 4
                else
                   is_connected = true
                end
             end
             -- test conection
             if is_connected then
                local status, mode, err = lcon:execwait('return dc_pip_cam()',{libs={'identify_utils'}})
                if status then
                    if mode == "rec" then
                       dalclick_detected[i].status = 3
                    else
                       dalclick_detected[i].status = 2
                    end
                else
                    dalclick_detected[i].status = 5
                    if err then
                       dalclick_detected[i].err = err
                    end
                end
             end
          end --for
       end
    end

    local devices = chdk.list_usb_devices()
    if type(devices) == 'table' and next(devices) then
       for i, dev in ipairs(devices) do
          local duplicated = false
          local devbus = tostring(dev.dev)..tostring(dev.bus)
          -- print("devbus: "..devbus)
          if dalclick_detected then
             for i, prevdev in ipairs(dalclick_detected) do
                -- print("prevdev.devbus: "..prevdev.devbus)
                if prevdev.devbus == devbus then
                   duplicated = true
                end
             end
          end
          if not duplicated then
             usb_conected[i] = {}
             usb_conected[i].status = 1
          end
       end
    else
       usb_conected = false
    end
    return dalclick_detected, usb_conected

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
        if lcon.idname == current_project.settings.ref_cam then
            print("camara de referencia: '"..current_project.settings.ref_cam.."'")
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
        if lcon.idname == current_project.settings.ref_cam then
            local status, zoom_pos, err = cam:get_zoom(lcon)
            if type(zoom_pos) ~= 'boolean' and status then
                return true, tonumber(zoom_pos)
            else
                return false, false, err
            end
        end
    end
    return false, false, "No se encontró la cámara de referencia '"..current_project.settings.ref_cam.."'."
end


function mc:set_zoom_other()
    for i,lcon in ipairs(self.cams) do
        if lcon.idename ~= current_project.settings.ref_cam then
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

function mc:get_cam_status()
-- detected
--     dev type: string, bus type: string, vendor_id type: number, product_id type: number
-- connected
--
-- inconcluso1!!!
    print("-- self.cams --")

    if type(self.cams) == 'table' then
       print("self.cams == {}")
       if next(self.cams) then
          for i, lconnection in ipairs(self.cams) do
             if lconnection:is_connected() then
                --lconnection:update_connection_info()
                print("camara conectada en self.cams ["..i.."]")
             else
                print("camara NO conectada en self.cams ["..i.."]")
             end
             if type(lconnection) == 'table' then
                print( "ptpdev.model: "..(type(lconnection.ptpdev) == 'table' and lconnection.ptpdev.model or 'nil'))
                print( "condev.bus: "  ..(type(lconnection.condev) == 'table' and lconnection.condev.bus or 'nil'))
                print( "condev.dev: "  ..(type(lconnection.condev) == 'table' and lconnection.condev.dev or 'nil'))
                print( "condev.dev: "  ..(type(lconnection.ptpdev) == 'table' and tostring(lconnection.ptpdev.serial_number) or 'nil'))
                print( "idname: "..lconnection.idname)
             else
                print("lconnection type:"..type(lconnection))
             end
          end
       else
           print("no hay camaras *iniciadas* en self.cams")
       end
    else
       print("self.cams == nil")
    end
    print("-- chdk.list_usb_devices() --")

    local devices = chdk.list_usb_devices()

    if not next(devices) then
        -- print(" Aparentemente no hay cámaras conectadas al equipo\n")
        print("no hay camaras *conectadas y encendidas* al equipo")
        print()
        return false
    end

    for i, devinfo in ipairs(devices) do
       print("camara detectada ["..i.."]")
       print("devinfo type:"..type(devinfo))
       print("devinfo:"..tostring(devinfo))
       print()
       for j, info in pairs(devinfo) do
          print(j.." type: "..type(info).." - '"..tostring(info).."'")
       end
       print()
       local lcon,msg = chdku.connection(devinfo)
       print("chdku.connection(devinfo) msg: '"..tostring(msg).."'")
       if lcon:is_connected() then
          print("is_connected: true")
       else
          print("is_connected: false")
       end
       if type(lcon) == 'table' then
          print( "ptpdev.model: "..(type(lcon.ptpdev) == 'table' and lcon.ptpdev.model or 'nil'))
          print( "condev.bus: "  ..(type(lcon.condev) == 'table' and lcon.condev.bus or 'nil'))
          print( "condev.dev: "  ..(type(lcon.condev) == 'table' and lcon.condev.dev or 'nil'))
          print( "ptpdev.serial_number: "  ..(type(lcon.ptpdev) == 'table' and tostring(lcon.ptpdev.serial_number) or 'nil'))
          print( "idname: "..tostring(lcon.idname))
       else
          print("lcon type:"..type(lcon))
       end
       print()
    end

end

function mc:detect_all()

    -- detecta camaras conectadas via usb, no importa si estan conectadas via chdk
    local detect_cam = false
    local devices = chdk.list_usb_devices()
    if type(devices) == 'table' and next(devices) then
       for i, dev in ipairs(devices) do
          io.write(" ["..i.."] - Cámara conectada en"
               .." USB BUS: "..dev.bus.." ".."DEV:"..dev.dev.." "
               ..string.format("%04x", dev.vendor_id)..":"..string.format("%04x", dev.product_id))
          local lcon,msg = chdku.connection(dev)
          if lcon:is_connected() then
             io.write(" [chdk]")
          end
          print("\n")
          detect_cam = true
       end
       return detect_cam
    else
        -- print(" No hay cámaras conectadas al equipo, o estan apagadas")
        return false
    end
end

function mc:camera_status(dalclick_detected, usb_conected)
   -- true  ready - CAMARAS OPERATIVAS
   -- nil   reiniciar camras - ACTIVAR CAMARAS
   -- false apagadas o mal configuradas - SIN CAMARAS

-- 1 detectada (detectada en el usb) gris
-- 2 operativa (inicializada e identificada por dalclick/chdk) amarilla
-- 3 lista (modo y objetivo desplegado para click) verde

-- 4 no se puede conectar -- desconfigurada o mal configurada: lcon:connect() -> false rojo1
-- 5 sin respuesta -- idem: c_pip_cam() -> status false rojo2

  local cam_status = {[1] = 'sin activar', [2] = 'modo play', [3] = 'operativa', [4] = 'no conecta', [5] = 'no responde',}

   if type(dalclick_detected) == "table" and next(dalclick_detected) then
      -- continue
   else
      if type(usb_conected) == "table" and next(usb_conected) then
         return nil, "Hay cámaras conectadas al equipo pero no han sido inicializadas desde\n dalclick, o no responden. Use la función '[a] activar cámaras'"
      else
         return false, "No se detectan cámaras. Están apagadas o el cable USB desconectado.\n Encienda las camaras o verifique el cable USB."
      end
   end

   if current_project.session.noc_mode == 'odd-even' then
      local unnamed = false; local oddname = false; local evenname = false; local evenrepeat = false; local oddrepeat = false
      local oddstatus; local evenstatus
      for i, cam_item in ipairs(dalclick_detected) do
         if cam_item.idname == "odd" then
            if oddname then oddrepeat = true else oddname = true; oddstatus = cam_item.status end
         elseif cam_item.idname == "even" then
            if evenname then evenrepeat = true else evenname = true; evenstatus = cam_item.status end
         else unnamed = true end
      end
      if oddname == true and evenname == true and unnamed == false then
         -- estructura de camaras ok
         if oddstatus == 3 and evenstatus == 3 then
            if type(usb_conected) == "table" and next(usb_conected) then
               return nil, "Las configuración de las cámaras es correcta y están operativas, pero se\n detectan más conexiones. Use la función '[a] activar cámaras' y\n verifique que no haya dispositivos extra conectados."
            else
               return true, "Las cámaras están operativas."
            end
         else
            return nil, "Las configuración de las cámaras es correcta, pero su estado no es operativo:\n derecha: '"..cam_status[evenstatus].."' / izquierda: '"..cam_status[oddstatus].."'. Use la función '[a] activar cámaras'.\n Si persiste el problema apague y vuelva a encender las cámaras."
         end
      else
         -- estructura de camaras no coincide
         if unnamed == true then
            return false, "Se ha detectado al menos una cámara cuya configuración no corresponde con la\n configuración del proyecto (no está identificada como 'derecha' o 'izquierda').\n Verifique la configuracion de las cámaras."
         elseif evenrepeat == true or oddrepeat == true then
            return false, "Hay más de una cámara con la misma identificación (dos "..(oddrepeat and "izquierdas" or "derechas")..") conectadas\n al equipo. Verifique la configuracion de las cámaras."
         elseif oddname == false or evenname == false then
            return false, "La cámara "..(oddname and "izquierda" or "derecha").." no está siendo reconocida por Dalclick.\n Verifique el cable USB de la cámara "..(oddname and "izquierda" or "derecha").." y que esté encendida.\n Luego reinicie las cámaras en dalclick."
         else
            return false, "debug: un error interno de programa no permite reconocer el problema."
         end
      end
   else
      local singlename = false
      local singlestatus; local extracam = false
      for i, cam_item in ipairs(dalclick_detected) do
         if cam_item.idname == "single" then
            singlename = true; singlestatus = cam_item.status
         end
         if i > 1 then extracam = true end
      end
      if singlename == true and extracam == false then
         -- estructura de camaras ok
         if singlestatus == 3 then
            if type(usb_conected) == "table" and next(usb_conected) then
               return nil, "Las configuración de la cámara es correcta y está operativas, pero se detectan\n más conexiones. Use la función '[a] activar cámaras' y verifique que no\n haya dispositivos extra conectados."
            else
               return true, "Cámara operativa."
            end
         else
            return nil, "La configuración de la cámara es correcta, pero su estado no es operativo:\n '"..cam_status[singlestatus].."'. Use la función '[a] activar cámaras'.\n Si persiste el problema apague y vuelva a encender las cámaras."
         end
      else
         -- estructura de camaras no coincide
         if extracam == true then
            return false, "Se ha detectado al menos una cámara extra que no corresponde con la\n configuración del proyecto. Verifique la configuracion de las cámaras."
         elseif singlename == false then
            return false, "La cámara no esta correctamente configurada. Verifique la configuracion de\n las cámaras."
         else
            return false, "debug (single): un error interno de programa no permite reconocer el problema."
         end
      end
   end
end

function mc:connect_all()

    -- print("mc:connect_all()")
    -- local key = io.stdin:read'*l'

    local connect_fail = false
    self.cams={}

    local devices = chdk.list_usb_devices()

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
    print("-- test devices --")
    for i, devinfo in ipairs(devices) do
       local lcon,msg = chdku.connection(devinfo)
       print("["..i.."] - lcon: '"..tostring(lcon).."'")
       print("["..i.."] - mc_id: '"..tostring(lcon.mc_id).."'")
       print("["..i.."] - sn: '"..tostring(lcon.sn).."'")
       for j, el in pairs(lcon) do
          print("["..j.."] ("..type(el).."): '"..tostring(el).."'")
       end
       print()
       for j, el in pairs(getmetatable(lcon)) do
          print("["..j.."] ("..type(el).."): '"..tostring(el).."'")
       end
       print()
    end
    print("-- test selt.cams --")
    for i, lcon in ipairs(self.cams) do
       print("["..i.."] - lcon: '"..tostring(lcon).."'")
       print("["..i.."] - mc_id: '"..tostring(lcon.mc_id).."'")
       print("["..i.."] - sn: '"..tostring(lcon.sn).."'")
       for j, el in pairs(lcon) do
          print("["..j.."] ("..type(el).."): '"..tostring(el).."'")
       end
       print()
       for j, el in pairs(getmetatable(lcon)) do
          print("["..j.."] ("..type(el).."): '"..tostring(el).."'")
       end
       print()
    end
    print("-- /test --")
    print()
    if connect_fail then
        return false
    else
        return true
    end
end

function mc:shutdown_all()

	if type(self.cams) == 'table' and next(self.cams) then
        print(" Apagando camaras...")
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
    else
		-- las camaras no estan encendida/activas
        return nil
	end
end

function mc:init_cams_all()

    -- print("mc:init_cams_all()")
    -- local key = io.stdin:read'*l'

    -- comprueba que haya conexion

    print("\n Verificando conexión cámaras:")
    local status = self:check_cam_connection()
    if not status then
        if status == false then
            print(" Reiniciar conexión...")
        else
            print(" Iniciar conexión...")
        end
        if not self:connect_all() then
            print(" falló el intento de conectarse a la/las cámara/s")
            return false
        end
    end

    -- comprueba que haya una o dos camaras, segun noc_mode

    local init_fail = false
    local init_fail_err = ""
    local idnames = {}
    local count_cams = 0
    if current_project.session.noc_mode then
        noc_mode =  current_project.session.noc_mode
    else
        noc_mode = defaults.noc_mode_default
    end
    print(" Identificando cámaras")

    if noc_mode == 'odd-even' then
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

    else -- noc_mode == 'single'
      print(" Modo cámara única")
		for i,lcon in ipairs(self.cams) do
		    count_cams = count_cams + 1
		    print(" ["..i.."] idname: "..defaults.single_name)
          lcon.idname = defaults.single_name
		end

		if count_cams == 2 then
		    print()
		    print(" Atención! Hay dos cámaras conectadas")
		    print()
		    init_fail = true
		elseif count_cams == 0 then
		    print()
		    print(" Atención! No hay cámaras conectadas!")
		    print()
		    init_fail = true
		end
		print()
	end

    -- modo multi? (como minimo una camara, si hay dos, con distinto nombre y que sea 'all' 'even' 'odd')
    -- ToDo...

    if init_fail then return false end

    -- inicio de camaras

    -- check SD
    print()
    local check_status = mc:check_sdcams_options()
    if check_status == false then
        print(" debug: check_sdcams_options() = false")
        return false
    end

    -- set cams
    --
    print()
    if type(current_project.state.zoom_pos) ~= "number" then
        current_project.state.zoom_pos = nil
        if not current_project:save_state() then
            print(" error de lectura: No se pudieron guardar las variables del estado del contador en el disco (3)")
            return false
        end
    end

    for i,lcon in ipairs(self.cams) do
        print(" ["..i.."] preparando cámara:")
        local status, var = cam:init_cam(lcon, current_project.state.zoom_pos)
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
       if current_project.session.noc_mode == 'odd-even' then
           print(" Alguna de las cámaras ha fallado, por favor apagarlas y volverlas a encender.\n")
       else -- current_project.session.noc_mode == 'single'
           print(" La cámara ha fallado al inicializar, por favor apaguela y vuelva a encenderla.\n")
       end
       print(" -> "..tostring(init_fail_err))
       return false
    end
    return true
end

function mc:check_sdcams_options()

    -- print("mc:check_sdcams_options()")
    -- local key = io.stdin:read'*l'

    local empty = true
    if current_project.session.noc_mode == 'odd-even' then
       local menu = [[
 ====================================================================
 ATENCION: Se recomienda borrar todas las imágenes contenidas en las
 tarjetas SD de las cámaras antes de comenzar.
 ====================================================================

 opciones:

 [enter] para borrar todas las imágenes
 [c] para continuar sin borrar

]]
    else -- current_project.session.noc_mode == 'single'
       local menu = [[
 ====================================================================
 ATENCION: Se recomienda borrar todas las imágenes contenidas en la
 tarjeta SD de la cámara antes de comenzar.
 ====================================================================

 opciones:

 [enter] para borrar todas las imágenes
 [c] para continuar sin borrar

]]
    end

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
                -- NO borrar
                return true
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
    local command_fail = false
    for idname,saved_file in pairs(current_project.state.saved_files) do
        -- saved_files[lcon.idname] = {
        -- saved_file.path
        -- path = local_path..file_name
        -- basepath = local_path
        -- basename = file_name
        command = "econvert -i "..saved_file.path.." --rotate "..current_project.state.rotate[idname].." -o "..current_project.session.base_path.."/"..current_project.paths.proc[idname].."/"..saved_file.basename.." > /dev/null 2>&1"

        if defaults.mode_enable_qm_daemon then
            print(" ["..idname.."] enviando comando (rotar) a la cola de acciones")
            if not os.execute(current_project.dalclick.qm_sendcmd_path..' '..current_project.session.base_path.."/"..current_project.paths.raw[idname]..' "'..command..'"') then
               print(" error: falló: "..current_project.dalclick.qm_sendcmd_path..' '..current_project.session.base_path.."/"..current_project.paths.raw[idname]..' "'..command..'"')
               command_fail = true
            end
        else
            printf(" ["..idname.."] rotando("..saved_file.basename..")...") -- sin testear!!
            if not os.execute(command) then
                print("ERROR")
                print("     falló: '"..command.."'")
                command_fail = true
            else
                print("OK")
            end
        end
    end
    if command_fail then
        return false
    else
        return true
    end
end

function mc:rotate_and_resize_all()
    local command, path
    local command_fail = false
    for idname,saved_file in pairs(current_project.state.saved_files) do
        local thumbpath = current_project.session.base_path.."/"..current_project.paths.proc[idname].."/"..current_project.dalclick.thumbfolder_name
        if not dcutls.localfs:file_exists( thumbpath ) then
            if not dcutls.localfs:create_folder( thumbpath ) then
                print(" ERROR: no se pudo crear '"..thumbpath.."'")
                return false
            end
        end
        local portrait = false
        if current_project.settings.rotate then
           if tonumber(current_project.state.rotate[idname]) == 180 or tonumber(current_project.state.rotate[idname]) == 0 then
              portrait = false
           else
              portrait = true
           end
        else
             portrait = false
        end
        command =
            "econvert -i "..saved_file.path
          ..( current_project.settings.rotate and " --rotate "..current_project.state.rotate[idname] or "")
          .." -o "..current_project.session.base_path.."/"..current_project.paths.proc[idname].."/"..saved_file.basename
          .." --thumbnail "..( portrait and "0.125" or "0.167")
          .." -o "..thumbpath.."/"..saved_file.basename
          .." > /dev/null 2>&1"
        if defaults.mode_enable_qm_daemon then
            print(" ["..idname.."] enviando de comando de procesamiento a la cola de acciones ("..saved_file.basename..").")
            if not os.execute(current_project.dalclick.qm_sendcmd_path..' '..current_project.session.base_path.."/"..current_project.paths.raw[idname]..' "'..command..'"') then
                print(" error: falló: "..current_project.dalclick.qm_sendcmd_path..' '..current_project.session.base_path.."/"..current_project.paths.raw[idname]..' "'..command..'"')
                command_fail = true
            end
        else
            printf(" ["..idname.."] "..(current_project.settings.rotate and "rotando y " or "").."generando vista previa ("..saved_file.basename..")...")
            if not os.execute(command) then
                print("ERROR")
                print("    falló: '"..command.."'")
                command_fail = true
            else
                print("OK")
            end
        end
    end
    if command_fail then
        return false
    else
        return true
    end
end

function mc:check_if_sdcams_are_empty()

    -- print("mc:check_if_sdcams_are_empty()")
    -- local key = io.stdin:read'*l'

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

    -- print("mc:check_if_sdcams_are_empty()")
    -- local key = io.stdin:read'*l'

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

    if current_project:load_state_secure() then
        if current_project.dalclick.capt_type == 'D' then
            -- TODO ojo cambio saved file!!! corregir!
            local shoot_fail, break_main_loop, saved_files = rsalt:direct_raw_shoot_all(current_project.dalclick, current_project.settings, current_project.state, self.cams)
            if not shoot_fail then
                current_project:counter_next()
                if current_project:save_state() then
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
                    current_project:counter_next()
                    if current_project.session.noc_mode == 'odd-even' then
                       if not current_project.session.counter_max.odd or current_project.state.counter.odd > current_project.session.counter_max.odd then
                           current_project.session.counter_max = current_project.state.counter
                       end
                    else
                       if not current_project.session.counter_max.single or current_project.state.counter.single > current_project.session.counter_max.single then
                           current_project.session.counter_max = current_project.state.counter
                       end
                    end
                end
                if current_project:save_state() then
                    -- print(" Guardando estado actual del proyecto .. OK")
                    --print("DEBUG current_project.state.counter:\n"..util.serialize(current_project.state.counter))
                    --print("DEBUG current_project.state.zoom_pos:\n"..util.serialize(current_project.state.zoom_pos))
                    -- mc:rotate_all( saved_files )
                    -- if current_project.state.saved_files and current_project.settings.rotate == true then
                    if current_project.state.saved_files then
                        if mc:rotate_and_resize_all() then
                        else
                            print(" Error: alguna de las imágenes no pudo ser rotada")
                            return false
                        end
                    else
                        print("ATENCION: solo se guardo en raw!!")
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

    if current_project:load_state_secure() then

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
                        current_project.session.base_path.."/"..current_project.paths.test[idname]
                        .."/"..saved_file.basename_without_ext..".jpg",
                    high_path =
                        current_project.session.base_path.."/"..current_project.paths.test[idname]
                        .."/"..saved_file.basename_without_ext..defaults.test_high_name..".jpg",
                    low_path  =
                        current_project.session.base_path.."/"..current_project.paths.test[idname]
                        .."/"..saved_file.basename_without_ext..defaults.test_low_name..".jpg"
                }
                local portrait = false
                if current_project.settings.rotate then
                  if current_project.state.rotate[idname] == 180 or current_project.state.rotate[idname] == 0 then
                     portrait = false
                  else
                     portrait = true
                  end
                else
                     portrait = false
                end
                local command =
                    "econvert"
                  .." -i "..command_paths[idname].src_path
                  ..( current_project.settings.rotate and " --rotate "..current_project.state.rotate[idname] or "")
                  .." -o "..command_paths[idname].high_path
                  .." --thumbnail "..( current_project.settings.rotate and "0.125" or "0.167")
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
               if current_project.session.noc_mode == 'odd-even' then
                  current_project:show_capts('show_test', previews, {odd = 'PREVIEW', even = 'PREVIEW'})
               else
                  current_project:show_capts('show_test', previews, {single = 'PREVIEW'})
               end
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
    if current_project.settings.mode == 'secure' then
        delay = 8
    elseif current_project.settings.mode == 'normal' then
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
            if current_project.state.saved_files then
                local prev_capt = current_project.state.saved_files[lcon.idname]
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
        file_name_we = string.format("%04d", current_project.state.counter[lcon.idname])
        file_name = file_name_we..".".."jpg"

        if mode == 'test' then -- yyyy
            local_path = current_project.session.base_path.."/"..current_project.paths.test[lcon.idname].."/"
        else
            local_path = current_project.session.base_path.."/"..current_project.paths.raw[lcon.idname].."/"
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
            current_project.state.saved_files = saved_files
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

    for idname,saved_file in pairs(current_project.state.saved_files) do
        command = "ufraw-batch --rotate "..current_project.state.rotate[idname].." --out-type="..outtype.." --out-depth="..outdepth.." --out-path="..saved_file.basepath.." "..saved_file.path
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
    local l_fail = ""
    local c_failload = 0
    local l_failload = ""
    for index,pdata in pairs(projects) do

        if not current_project:init(defaults) then
            print(" ERROR: no se pueden inicializar proyectos!")
            break
        end
        print("\n\n - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - ")
        print(" abriendo '"..tostring(pdata.settings_path).."'")
        local load_status, project_status = current_project:load(pdata.settings_path)
        if load_status then
            print(" Procesando: '"..tostring(pdata.settings_path).."'")
            print(" Proyecto abierto con exito. Estado: "..tostring(project_status))
            local status, msgs = current_project:send_post_proc_actions({ batch_processing = true })
            if status then
                print(" Proyecto enviado con éxito a la cola de post-procesamiento para generar pdf")
                c_ok = c_ok + 1
            else
                print(" -- "..tostring(msgs).." --")
                c_fail = c_fail + 1
                l_fail = l_fail.."     "..pdata.settings_path.."\n"
            end
        else
            print(" Ha ocurrido un error mientras se intentaba cargar el proyecto")
            c_failload = c_failload + 1
            l_failload = l_failload.."     "..pdata.settings_path.."\n"
        end
    end
    return "Resumen:\n"
            .."  "..tostring(c_ok).." proyectos enviados\n"
            .."  "..tostring(c_fail).." proyectos no enviados\n"
            ..l_fail
            .."  "..tostring(c_failload).." proyectos que no pudieron abrirse\n"
            ..l_failload
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

        if not current_project:init(defaults) then
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
            local load_status, project_status = current_project:load(pdata.settings_path)
            if load_status then
                rplog(" Procesando: '"..tostring(pdata.settings_path).."'", log, true)
                rplog(" Proyecto abierto con exito. Estado: "..tostring(project_status), log, true)
                local status, no_errors, received_log = current_project:reparar()
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
    file_name_we = string.format("%04d", current_project.state.counter[idname])
    file_name = file_name_we..".".."jpg"

    if dcutls.localfs:file_exists( current_project.session.base_path.."/"..current_project.paths.raw[idname].."/"..file_name ) then
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

local function modify_title(title)
   guisys.init()

   local scanf_title
   local format = "Modificar título\nTítulo:%300.30%s\n"
   scanf_title = iup.Scanf(format, title)
   if scanf_title == nil then return false end

   if scanf_title == title then
      return nil
   else
      return true, scanf_title
   end
end

local function modify_rotation(rotation)
   guisys.init()

   local scanf_rotation
   local format = "Modificar rotación\nRotación:%5.5%s\n"
   repeat
      scanf_rotation = iup.Scanf(format, tostring(rotation))
      if scanf_rotation == nil then return false end

      if scanf_rotation == rotation then
         return nil
      else
         if scanf_rotation == "90" or scanf_rotation == "-90" or scanf_rotation == "180" or scanf_rotation == "0" then
            return true, scanf_rotation
         else
            --print("debug: '"..scanf_rotation.."'")
            iup.Message("Modificar rotación", "Los valores admitidos son '90','-90','180' ó '0'")
         end
      end
   until false
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

local function open_file_browser(path)
   if defaults.file_browser_available then
       os.execute(defaults.file_browser_path.." "..path.." > /dev/null 2>&1 &")
   else
        print()
        print("ATENCIÓN: Su sistema debe ser configurado para poder usar esta opción.")
        print("Revise la configuración en el archivo CONFIG.")
        print()
        sys.sleep(2000)
   end
end

local function open_pdf_viewer(path_to_pdf)
   if defaults.pdf_viewer_available then
       if type(path_to_pdf) == 'string' and dcutls.localfs:file_exists( path_to_pdf ) then
           os.execute(defaults.pdf_viewer_path.." "..path_to_pdf.." &")  --" > /dev/null 2>&1 &"
       end
   else
        print()
        print("ATENCIÓN: Su sistema debe ser configurado para poder usar esta opción.")
        print("Revise la configuración en el archivo CONFIG.")
        print()
        sys.sleep(2000)
   end
end

local function open_scantailor_gui(path_to_scproject)
  if defaults.scantailor_available then
      if type(path_to_scproject) == 'string' and dcutls.localfs:file_exists( path_to_scproject ) then
          os.execute(defaults.scantailor_path.." "..path_to_scproject.." &") --" > /dev/null 2>&1 &"
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

    if not dcutls.localfs:file_exists(current_project.session.base_path.."/"..current_project.paths.raw.odd) or not dcutls.localfs:file_exists(current_project.session.base_path.."/"..current_project.paths.raw.even) then
        print(" error: init_daemons: no existen path_raw... \n  "..current_project.session.base_path.."/"..current_project.paths.raw.odd.."\n  "..current_project.session.base_path.."/"..current_project.paths.raw.even)
        return false
    end
    os.execute(current_project.dalclick.qm_daemon_path.." "..current_project.session.base_path.."/"..current_project.paths.raw.odd.." &")
    os.execute(current_project.dalclick.qm_daemon_path.." "..current_project.session.base_path.."/"..current_project.paths.raw.even.." &")
    return true

    -- para enviar un comando al queue
    -- os.execute(current_project.dalclick.qm_sendcmd_path..' "'..current_project.path_raw.even..'"')
end

function dc:kill_daemons()
    print(" terminando procesos en segundo plano...")
    os.execute("killall qm_daemon.sh 2>&1") -- TODO: qm_daemon se deberia apagar creando un archivo 'quit' en job folder
end



function dc:start_options(options)

    local options = options or {}
    if type(options) ~= 'table' then return false end

    local saved_project  = false
    local ppath, pname, pext
    if not options.disable_restore_option then
		saved_project  = self:check_running_project()
		if saved_project  then
		  ppath, pname, pext = string.match(saved_project , "(.-)([^\\/]-%.?([^%.\\/]*))$")
		end
    end

	local logo_lmargin = "                   "
    local dalclick_logo = " =============================================================================\n"
          ..logo_lmargin..'   ____   ___  _       _|_|     _\n'
          ..logo_lmargin..'  |  _ \\ / _ \\| |  ___| |_  __| | _\n'
          ..logo_lmargin..'  | | | | |_| | | /  _| | /  _| |/ /\n'
          ..logo_lmargin..'  | |_| |  _  | |_| |_| | | |_|   (\n'
          ..logo_lmargin..'  |___ /|_| |_|___\\___|_|_\\___|_|\\_\\\n'
          ..logo_lmargin..'\n'
          .." ================================  Inicio  ==================================="
    -- Carpeta de proyectos: ']]..defaults.root_project_path..[['
    local start_menu = ""
    if saved_project  then
       start_menu = "  [enter] restaurar: '"..ppath.."'\n\n"
    end
    start_menu = start_menu.."  [n] crear nuevo proyecto        [o] abrir proyecto\n"

    local start_menu_more = "  [m] más opciones"

    local start_menu_advanced = [[

  ---- Selección multiple de proyectos -------------------------------------

  [s]     seleccionar todos
  [s-pdf] seleccionar pendientes sin pdf
  [s+pdf] seleccionar finalizados con pdf
  [a]     cargar una lista desde un archivo]]

    local start_menu_lote =[[
  [pp] generar pdf   [reparar] reparar  [list] lista detallada

  [q] para salir]]

    local start_menu_footer =[[

 ==============================================================================]]

    local more = false
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
        if not more then
           print(dalclick_logo)
        else
           print("================================ DALclick ===================================")
        end
        print()
        print(start_menu)
        if more then
           print(start_menu_advanced)
           print()
           print("  ---- acciones en lote para "..tostring(table.getn(state.projects_selection)).." proyectos seleccionados --------------------")
           print(start_menu_lote)
           print(start_menu_footer)
        else
           print(start_menu_more)
           print(start_menu_footer)
           print("\n")
        end

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
        if moption == "" then
			if saved_project  then
		        print(); print(" Eligió: Restaurar '"..ppath.."'...")
				-- limpiando estructura de proyecto
				if not current_project:init(defaults) then
					return false
				end
				local load_status, project_status = current_project:load(saved_project )
				if load_status then
					if project_status == 'opened' then
					    if current_project:update_running_project(saved_project ) then
					        -- success!!
					    end
                        break
					else
					    print(" ATENCION: Está intentado cargar al inicio un proyecto en formato obsoleto.")
					    print(" Por favor cárguelo seleccionando la opción [o]")
					    print()
					end
				else
					print(" Ha ocurrido un error mientras se intentaba restaurar el proyecto")
					sys.sleep(2000)
				end
		    end
        elseif moption == "q" then
            return false
        elseif moption == "m" then
            more = true
            print("\n\n\n\n")
        elseif moption == "n" then
            print(); print(" Eligió: Crear Nuevo Proyecto...")
            local regnum, title = get_project_newname()
            if regnum ~= nil then
                if not current_project:init(defaults) then
                    return false
                end
                local create_options = { regnum = regnum, title = title, root_path = defaults.root_project_path }
                if config.zoom_persistent then
                    create_options.zoom = options.zoom
                end
                if current_project:create( create_options ) then
                    -- local cam_status = self:init_cams_or_retry()
                    -- if cam_status == 'exit' then
                    --    return 'exit' -- opcion explicita de salir de dalclick desde init_cams_or_retry()
                    -- end
                    break
                end
             end
             -- state.projects_selection = {}
             -- back to start options
        elseif moption == "o" then
            print(); print(" Eligió: Abrir Proyecto...")
            local open_status, project_status = current_project:open(defaults, { root_path = defaults.root_project_path })
            if open_status then
                if project_status == 'modified' then
                    printf(" El formato del proyecto era obsoleto. Guardando proyecto actualizado...")
                    if current_project:write() then print("OK") else print("ERROR") end
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
                        local load_status, project_status = current_project:load(settings_path)
                        if load_status == true then

                            print(" Proyecto cargado con éxito" )
                            -- guardar referencia al proyecto cargado como "running project"
                            if project_status == 'modified' then
                                printf(" El formato del proyecto era obsoleto. Guardando proyecto actualizado...")
                                if current_project:write() then print("OK") else print("ERROR") end
                            end
                            if current_project:update_running_project( settings_path ) then
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
    local menu
    if current_project.session.noc_mode == 'odd-even' then
       menu = [[

+ + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + +

 No se ha podido activar correctamente alguna de las cámaras.
 Posibles problemas y soluciones:

  - Alguna de las cámaras (o ambas) estan apagadas.
    Verifique que estén encendidas y la conexión del cable USB.

  - Alguna de las cámaras (o ambas) todavía está inicializando.
    Espere unos segundos y vuelva a intentarlo.

  - Alguna de las cámaras (o ambas) dejo de responder.
    Enciéndala nuevamente y vuelva a intentarlo.

== opciones ==================================================================

 [enter] para reintentar
 [c] continuar sin iniciar las cámaras

==============================================================================]]
    else -- current_project.session.noc_mode == 'single'
       menu = [[

+ + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + +

 No se ha podido configurar correctamente las cámara.
 Posibles problemas y soluciones:

  - La cámara todavía está inicializando.
    Espere unos segundos y vuelva a intentarlo.

  - La cámara se apagó o dejo de responder.
    Enciéndala nuevamente y vuelva a intentarlo.

== opciones ==================================================================

 [enter] para reintentar
 [c] continuar sin iniciar las cámaras

==============================================================================]]
    end
    while true do
        status = mc:init_cams_all() -- true: ok, seguir - false: error, reintentar -
        if status == true then
            break
        elseif status == false then
            print(menu)
            printf(" >> ")
            local key = io.stdin:read'*l'
            print()
            if key == "" then
                -- continuar
            elseif key == "c" then
                return 'no_init_select'
            else
                print("["..key.."]: opción inválida!")
            end
        end
    end
    return true

end

function dc:load_cam_scripts()
    local libs = {'dalclick_utils', 'shoot_utils', 'identify_utils'}
	for i, lib_name in pairs(libs) do
		local file = io.open(defaults.dalclick_pwdir.."/chdk/"..lib_name..".lua", "r")
		local lib_code = file:read("*all")
		file:close()

		if lib_code == nil then
		    return false
		else
		    chdku.rlibs:register({
		        name = lib_name,
		        code = lib_code
		    })
		end
	end
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
            print(" ATENCION: Dalclick encontro una referencia a un proyecto previo que no existe.")
            print(" Eliminando referencia...")
            dcutls.localfs:delete_file( running_project_fileinfo )
        end
    end
    return false
end

function dc:get_cam_icons(dalclick_detected, usb_conected)

   local str_t = ""
   local str_b = ""
   local str_f = ""

   if dalclick_detected then
      for i, detected in ipairs(dalclick_detected) do
         if     detected.status == 1 then b = "\27[90m[o]\27[0m"; t = "\27[90m _ \27[0m"
         elseif detected.status == 2 then b = "\27[33m[o]\27[0m"; t = "\27[33m _ \27[0m"
         elseif detected.status == 3 then b = "\27[32m[o]\27[0m"; t = "\27[32m _ \27[0m"
         elseif detected.status == 4 then b = "\27[31m[x]\27[0m"; t = "\27[31m _ \27[0m"
         elseif detected.status == 5 then b = "\27[31m[x]\27[0m"; t = "\27[31m _ \27[0m"
         else b = "???"; t = "   "   end

         if     detected.idname == "even"   then f = " R "
         elseif detected.idname == "odd"    then f = " L "
         elseif detected.idname == "single" then f = " S "
         else f = "   " end
         str_t = str_t.." "..t
         str_b = str_b.." "..b
         str_f = str_f.." "..f
      end
   end
   if usb_conected then
      for i, conected in ipairs(usb_conected) do
         if     conected.status == 1 then b = "\27[90m[o]\27[0m"; t = "\27[90m _ \27[0m"
         elseif conected.status == 2 then b = "\27[33m[o]\27[0m"; t = "\27[33m _ \27[0m"
         elseif conected.status == 3 then b = "\27[32m[o]\27[0m"; t = "\27[32m _ \27[0m"
         elseif conected.status == 4 then b = "\27[31m[x]\27[0m"; t = "\27[31m _ \27[0m"
         else b = "???"; t = "   "   end
         f = " ? "
         str_t = str_t.." "..t
         str_b = str_b.." "..b
         str_f = str_f.." "..f
      end
   end
   return str_t, str_b, str_f
end

function dc:main(
    DALCLICK_HOME,
    DALCLICK_PROJECTS,
    DALCLICK_PWDIR,
    ROTATE_ODD_DEFAULT,
    ROTATE_EVEN_DEFAULT,
    ROTATE_SINGLE_DEFAULT,
    DALCLICK_MODE,
    FILE_BROWSER,
    PDF_VIEWER,
    SCANTAILOR_PATH,
    PDFBEADS_PATH,
    PDFBEADS_QUALITY,
    NOC_MODE,
    DELAY_MODE)

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

    if FILE_BROWSER ~= "" then
        defaults.file_browser_available = true
        defaults.file_browser_path = tostring(FILE_BROWSER)
        print(" * File Browser: "..tostring(FILE_BROWSER))
    end

    if PDF_VIEWER ~= "" then
       defaults.pdf_viewer_available = true
       defaults.pdf_viewer_path = PDF_VIEWER
       print(" * PDF Viewer: "..tostring(PDF_VIEWER))
    end

    if SCANTAILOR_PATH ~= "" then
       defaults.scantailor_available = true
       print(" * Scantailor available")
       defaults.scantailor_path = SCANTAILOR_PATH
    end

    if PDFBEADS_PATH ~= "" then
       defaults.pdfbeads_path = PDFBEADS_PATH
       print(" * Pdfbeads path: '"..defaults.pdfbeads_path.."'")
    end

    if PDFBEADS_QUALITY ~= "" then
       defaults.pdfbeads_default_quality = PDFBEADS_QUALITY
       print(" * Pdfbeads quality: "..defaults.pdfbeads_default_quality )
    end

    if NOC_MODE then
        defaults.noc_mode_default = NOC_MODE
        print(" * NOC_MODE: '"..tostring(defaults.noc_mode_default).."'")
    end

    if DELAY_MODE == 'secure' or DELAY_MODE == 'normal' or DELAY_MODE == 'fast' then
        defaults.delay_mode = DELAY_MODE
        print(" * DELAY_MODE: '"..tostring(defaults.delay_mode).."'")
    else
        defaults.delay_mode = 'secure'
    end
    defaults.qm_sendcmd_path = defaults.dalclick_pwdir.."/qm/qm_sendcmd.sh"
    defaults.qm_daemon_path = defaults.dalclick_pwdir.."/qm/qm_daemon.sh"

    defaults.ppm_sendcmd_path = defaults.dalclick_pwdir.."/ppm/ppm_sendcmd.sh" -- post process mananager

    defaults.empty_thumb_path = defaults.dalclick_pwdir.."/img/empty.jpg"
    defaults.empty_thumb_path_error = defaults.dalclick_pwdir.."/img/empty_g.jpg"

    defaults.empty_thumb_path_landscape = defaults.dalclick_pwdir.."/img/empty-landscape.jpg"
    defaults.empty_thumb_path_landscape_error = defaults.dalclick_pwdir.."/img/empty_g-landscape.jpg"

    defaults.empty_thumb_path_landscapebig = defaults.dalclick_pwdir.."/img/empty-landscape-big.jpg"
    defaults.empty_thumb_path_landscapebig_error = defaults.dalclick_pwdir.."/img/empty_g-landscape-big.jpg"

    -- --
    if not self:load_cam_scripts() then
        print(' ERROR falló load_cam_scripts()')
        return false
    end
    -- --

    -- Todo: ojo, comprobar si da true con ROTATE_ODD_DEFAULT=""
    if ROTATE_ODD_DEFAULT then
        defaults.rotate_odd = ROTATE_ODD_DEFAULT
    end
    if ROTATE_EVEN_DEFAULT then
        defaults.rotate_even = ROTATE_EVEN_DEFAULT
    end
    if ROTATE_SINGLE_DEFAULT then
        defaults.rotate_single = ROTATE_SINGLE_DEFAULT
    end
    self:dalclick_loop(false)

    local exit = false

    -- el objetivo de este bloque es que las camaras esten apagadas
    -- o dalclick no inicie hasta que el usuairo las apague

    local cameras_turned_off
    local running_project = self:check_running_project()

    print("\n\n\n\n\n")
    while true do
       if mc:detect_all() then
           print("          =====================================================")
           print("          = Por favor apague las cámaras que estén encendidas =")
           print("          =====================================================")
           print()
           print(" Para prevenir interferencias entre el sistema operativo y DALclick en la")
           print(" gestión de las cámaras digitales, es mejor comenzar con los dispositivos")
           print(" apagados y encenderlos luego de iniciar DALclick.")
           print()
           print(" [enter] Continuar luego de apagar las cámaras")
           print("\n\n\n\n\n")
           printf(">> ")
           cameras_turned_off = false
           local key = io.stdin:read'*l'

           print("\n\n\n\n\n")
           if key == "c" then
              -- para seguir sin apagar las camaras (funcion oculta)
              break
           end
       else
           cameras_turned_off = true
           break
       end
    end

    print(" DALclick se ha iniciado correctamente.\n")

    local start_options_options = {}
    if not defaults.autorestore_project_on_init then
        start_options_options.disable_restore_option = true
    end
    if not self:start_options(start_options_options) then
        self:dalclick_loop(false)
        return false
    end

    -- check if user turn on cam while initial menus
    if mc:detect_all() then
       cameras_turned_off = false
       self:init_cams_or_retry()
    else
       cameras_turned_off = true
    end

	-- Todo: sacar las variables
    local menu = {}
    menu.standart = [[
 [enter] capturar                                    [s] salir  [h] inicio

 [t] test de captura       [n] nuevo proyecto...     [z] sincronizar zoom
 [v] ver ultima captura    [o] abrir proyecto...         desde la camara de
 [e] explorador            [w] guardar proyecto          referencia
                           [c] cerrar proyecto      [zz] ingresar valor de
 [a] activar camaras       [cl] clonar proyecto           zoom manualmente...
 [i] informacion sobre
     las cámaras           [x] generar pdf y cerrar  [f] enfocar
 [b] bip en cámara de      [l] generar pdf y clonar  [m] modo seg/norm/rápido
     referencia            [ll] ídem, pdf modo auto
 - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 [r][u] retroceder/avanzar    [uu] ir al final       [p] ir a página...
 - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 [1] opciones avanzadas     [2] opciones scantailor [3] opciones generar PDF
]]
-- [xx] ídem, pdf modo auto

    local fileb_option = ""
    if defaults.file_browser_available then
        fileb_option = "  [dir]     abrir el proyecto en el explorador de archivos\n"
    end
    local pdfview_option = ""
    if defaults.pdf_viewer_available then
        pdfview_option = "  [pdf abrir]    ver último pdf generado\n"
    end

    menu.advanced = [[
 [enter] volver a opciones

 Modificar proyecto
  [modificar titulo] [modificar rotacion]
  [reparar] reparar y checkear integridad del proyecto

 Rango o subselección de páginas:
  [rango]         ingresar valores "desde/hasta" manualmente
  [rango borrar]  eliminar rango

 Explorar archivos:
]]..fileb_option..
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
]]..pdfview_option..
[[  [pdf ayuda]   ver una ayuda para el comando 'pp'

]]

    -- init daemons
    if defaults.mode_enable_qm_daemon then
        self:init_daemons()
    end

    -- project loop
    local status
    local e_overwt, o_overwt, s_overwt, margin, top_bar, the_title
    local loopmsg = ""
    while true do

        o_overwt = false; e_overwt = false; s_overwt = false

        local dalclick_detected, usb_conected = mc:camsound_plip()
        local iconline_t, iconline_b, iconline_f = dc:get_cam_icons(dalclick_detected, usb_conected)
        state.cameras_status, state.cameras_status_msg = mc:camera_status(dalclick_detected, usb_conected)
        if state.cameras_status == true then
            cam_msg = " CAMARAS OPERATIVAS"
        elseif state.cameras_status == false then
            cam_msg = " SIN CÁMARAS ======"
        elseif state.cameras_status == nil then
            cam_msg = " ACTIVAR CAMARAS =="
        end

        if current_project.session.noc_mode == 'odd-even' then
           if check_overwrite(defaults.even_name) then
               e_overwt = true
           end
           if check_overwrite(defaults.odd_name) then
               o_overwt = true
           end
        else -- current_project.session.noc_mode == 'single'
           if check_overwrite(defaults.single_name) then
               s_overwt = true
           end
        end

        print()
        local regnum_line, capt_line, zoom_line

        regnum_line = string.sub(" Proyecto: ["..current_project.session.regnum.."]", 0, 50)

        if current_project.session.noc_mode == 'odd-even' then
           if next(current_project.session.counter_min) and next(current_project.session.counter_max) then
               capt_line = " Capturas realizadas: "
                   ..string.format("%04d", current_project.session.counter_min.even)
                   .."-"
                   ..string.format("%04d", current_project.session.counter_min.odd)
               if current_project.session.counter_min.even ~= current_project.session.counter_max.even then
                   capt_line = capt_line
                   .." a "
                   ..string.format("%04d", current_project.session.counter_max.even)
                   .."-"
                   ..string.format("%04d", current_project.session.counter_max.odd)
                   .." (odd-even mode)"
               end
           else
              capt_line = " Capturas realizadas: Ninguna"
           end
        else -- current_project.session.noc_mode == 'single'
           if next(current_project.session.counter_min) and next(current_project.session.counter_max) then
               capt_line = " Capturas realizadas: "
                   ..string.format("%04d", current_project.session.counter_min.single)
               if current_project.session.counter_min.single ~= current_project.session.counter_max.single then
                   capt_line = capt_line
                   .." a "
                   ..string.format("%04d", current_project.session.counter_max.single)
                   .." (single mode)"
               end
           else
              capt_line = " Capturas realizadas: Ninguna"
           end
        end

        if current_project.state.zoom_pos then
            zoom_line = " Valor del Zoom: "..tostring(current_project.state.zoom_pos)
        else
            zoom_line = " Valor del Zoom: Sin definir"
        end

        if current_project.settings.mode then
            delaymode_line = " Modo: "..tostring(current_project.settings.mode)
        else
            delaymode_line = ""
        end

        zoom_line = zoom_line .. delaymode_line

        print( regnum_line.." "..string.rep(" ", 65 - string.len(regnum_line))
              ..string.rep(" ", 12 - string.len(iconline_f))..iconline_t
        )
        print(   capt_line.." "..string.rep(" ", 65 - string.len(capt_line))
              ..string.rep(" ", 12 - string.len(iconline_f))..iconline_b
        )
        print(   zoom_line.." "..string.rep(" ", 65 - string.len(zoom_line))
              ..string.rep(" ", 12 - string.len(iconline_f))..iconline_f
        )
        if string.match(state.menu_mode, "pdf_help") then
            the_title = "Ayuda postproceso (PDF)"
        elseif string.match(state.menu_mode, "scantailor_help") then
            the_title = "Ayuda Scantailor"
        else the_title = current_project.settings.title..( current_project:project_is_not_empty() and "" or " [vacio]") end
        margin = math.floor( ( 76 - string.len(string.sub(the_title, 0, 50)) ) / 2 )
        top_bar = string.rep("=", margin).." "..string.sub(the_title, 0, 50).." "..string.rep("=", margin)
        print( top_bar )
        print("")
        print(menu[state.menu_mode])
        if current_project.session.noc_mode == 'odd-even' then
           print(
               "= "
               ..string.format("%04d", current_project.state.counter.even)
               ..(e_overwt and " ##RECAPT## " or " ===========")
               .."=========="..cam_msg.." ========="
               ..(o_overwt and " ##RECAPT## " or "=========== ")
               ..string.format("%04d", current_project.state.counter.odd)
               .." ="
               )
        else -- current_project.session.noc_mode == 'single'
           print(
               "=================================== "
               ..string.format("%04d", current_project.state.counter.single)
               ..(s_overwt and " ##RECAPT## " or " ===========")
               .."======"..cam_msg..""
               )
        end

        if current_project.session.include_list.from or current_project.session.include_list.to then
            print(" -- Rango seleccionado: desde '"
                ..tostring(current_project.session.include_list.from or '..')
                .."' hasta '"
                ..tostring(current_project.session.include_list.to or '..')
                .."' --")
        end
        if state.show_cam_status_info == true then
           loopmsg = " "..state.cameras_status_msg
           state.show_cam_status_info = false
        end
        if loopmsg ~= "" then
            -- print()
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
        elseif key == "cab" then
            cabildo:gui(mc.cams)
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
            if current_project.settings.mode == 'secure' then
                current_project.settings.mode = 'normal'
                loopmsg = " modo cambiado a 'normal' (4s)"
            elseif current_project.settings.mode == 'normal' then
                current_project.settings.mode = 'fast'
                loopmsg = " modo cambiado a 'rápido' (2s)"
            else
                current_project.settings.mode = 'secure'
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
            if current_project:counter_prev() ~= false then
                print('OK')
                current_project:save_state()
            else
                loopmsg =  " No se puede retroceder, está al inicio de la lista"
            end
        elseif key == "u" then
            printf(" avanzando un lugar hacia adelante...")
            if current_project.session.noc_mode == 'odd-even' then
               local countermax = current_project.session.counter_max.odd
            else -- current_project.session.noc_mode == 'single'
               local countermax = current_project.session.counter_max.single
            end
            if current_project:counter_next(countermax) ~= false then
                print('OK')
                current_project:save_state()
            else
                loopmsg = " No se puede avanzar mas, está al final de la lista"
            end
            current_project:save_state()
        elseif key == "uu" then
           if current_project.session.noc_mode == 'odd-even' then
               if current_project.session.counter_max.odd ~= nil and current_project.session.counter_max.even ~= nil then
                   current_project.state.counter.odd =  current_project.session.counter_max.odd  + 2
                   current_project.state.counter.even = current_project.session.counter_max.even + 2
                   current_project:save_state()
               else
                   loopmsg = " No se puede avanzar al final porque todavía no hay capturas"
               end
           else -- current_project.session.noc_mode == 'single'
               if current_project.session.counter_max.single ~= nil then
                   current_project.state.counter.single = current_project.session.counter_max.single + 1
                   current_project:save_state()
               else
                   loopmsg = " No se puede avanzar al final porque todavía no hay capturas"
               end
           end
        elseif key == "p" then
            print(" Ir a la pagina...")
            print(" ingresar valor numérico, no es necesario agregar ceros a la izquierda:")
            printf(">> ")
            local pos = io.stdin:read'*l'
            if pos ~= "" and pos ~= nil then
                local status, msg = current_project:set_counter(pos)
                current_project:save_state()
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
                    current_project.state.zoom_pos = zoom_pos
                    loopmsg = "Valor zoom leído de cámara de referencia: "..zoom_pos.."\n"
                    if current_project:save_state() then
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
                        current_project.state.zoom_pos = zoom
                        if current_project:save_state() then
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
                    current_project.state.zoom_pos = zoom_pos
                    if current_project:save_state() then
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
            local previous_zoom = current_project.state.zoom_pos
            local regnum, title = get_project_newname()
            if regnum ~= nil then
                printf(" Guardando proyecto anterior... ")
                if not current_project:write() then
                    print(" ERROR\n    no se pudo guardar el proyecto actual.")
                    exit = true; break
                else
                    print("OK")
                end

                if not current_project:init(defaults) then
                    print(" ERROR: no se puedo iniciar el proyecto")
                    exit = true; break
                end

                local create_options = { regnum = regnum, title = title, root_path = defaults.root_project_path }
                if config.zoom_persistent then
                    create_options.zoom = previous_zoom
                end
                if current_project:create( create_options ) then
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
            print(); status, project_status = current_project:open(defaults,open_options); print()
            sys.sleep(2000) -- pausa para dejar ver los mensajes
            if status then
                if project_status == 'canceled' then
                    -- no se hace nada
                elseif project_status == 'modified' then
                    printf(" El formato del proyecto era obsoleto. Guardando proyecto actualizado...")
                    if current_project:write() then print("OK") else print("ERROR") end
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
                if current_project:delete_running_project() then
                    print(" proyecto fallido cerrado")
                    print()
                end
                sys.sleep(500)

                print(" Se restaurará el proyecto previo")
                local restoring_fail = false
                local options = { settings_path = previous_settings_path }

				if not current_project:init(defaults) then
				    exit = true
				    break
				end
				local load_status, project_status = current_project:load(previous_settings_path)
				if load_status then
					if project_status == 'opened' then
					    running_project_loaded = true
					    if current_project:update_running_project(previous_settings_path) then
					        -- success!!
					    end
					else
						print(" No se pudo restaurar correctamente el proyecto")
						sys.sleep(2000)
				        restoring_fail = true
					end
				else
					print(" Ha ocurrido un error mientras se intentaba restaurar el proyecto")
					sys.sleep(2000)
				    restoring_fail = true
				end
				if restoring_fail then
					if not self:start_options({ [disable_restore_option] = true }) then
						exit = true
						break
					end
				end
            end
        elseif key == "w" then
            if current_project:write() then
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
            if type(current_project.state.saved_files) == 'table' then
                if next(current_project.state.saved_files) then
                    -- print("1) current_project.state.saved_files: "..util.serialize(current_project.state.saved_files))
                    local status, previews, filenames = current_project:make_preview(current_project.state.saved_files)
                    if status then
                        -- print("2) previews: "..util.serialize(previews))
                        current_project:show_capts( 'view_last_capture', previews, filenames )
                    end
                 else
                    loopmsg = " El registro de la última captura esta vacío."
                 end
            else
                loopmsg = " No hay registro de última captura."
            end
        elseif key == "e" then
            if next(current_project.session.counter_max) then
                current_project:show_capts( "explorer" )
            end
        elseif key == "s" then
            if not current_project:save_state() then
                print(" error: no se pudieron guardar las variables de estado en el disco")
                -- print("debug: zoom_pos: "..tostring(current_project.state.zoom_pos))
            end
            if mc:shutdown_all() == false then
                print("alguna de las cámaras deberá ser apagada manualmente")
            end
            print(" saliendo...")
            sys.sleep(1000)
            exit = true
            break
        elseif key == "c" then
            if current_project:delete_running_project() then
                print("\n\n\n Proyecto '"..current_project.settings.title.."' cerrado.")
            end
            sys.sleep(2000)
            if not self:start_options() then
                exit = true
                break
            end
        elseif key == "h" then
            if not self:start_options() then
                exit = true
                break
            end
        elseif key == "x" or key == "xx"  then
            local new_project_options = { zoom = current_project.state.zoom_pos }
            local status, msg
            if key == "xx" then
                -- quiet, default options
                status, msg = current_project:send_post_proc_actions({ batch_processing = true })
            else
                status, msg = current_project:send_post_proc_actions()
            end
            if status then
                print("\n Proyecto "..current_project.session.regnum.. ": '"..current_project.settings.title.."' enviado.")
                if current_project:delete_running_project() then
                    print(" Cerrando proyecto..OK")
                end
                sys.sleep(2000)

                if not self:start_options(new_project_options) then
                    exit = true
                    break
                end
            end
            if type(msg) == 'string' and msg  ~= "" then loopmsg = " "..tostring(msg) end
        elseif key == "l" or key == "ll" or key == "cl" then
            local clone_project = true
            if key == "ll" or key == "l" then
               local status, msg
               if key == "ll" then
                   status, msg = current_project:send_post_proc_actions({ batch_processing = true })
               elseif key == "l" then
                   status, msg = current_project:send_post_proc_actions()
               end
               if status then
                   print("\n Proyecto "..current_project.session.regnum.. ": '"..current_project.settings.title.."' enviado.")
               else
                   print("\n ERROR: Proyecto "..current_project.session.regnum.. ": '"..current_project.settings.title.."' no pudo enviarse.")
                   clone_project = false
               end
            end
            if clone_project then
                print(" Iniciando clonar proyecto")
                local regnum, title = get_project_newname()

                if regnum ~= nil then
                   local pzoom = current_project.state.zoom_pos
                   local pmode = current_project.settings.mode
                   if current_project:delete_running_project() then
                       print(" Cerrando proyecto previo..OK")
                   end
                   sys.sleep(2000)

                   if not current_project:init(defaults) then
                       exit = true
                       break
                   else
                      local clone_options = { regnum = regnum, title = title, root_path = defaults.root_project_path,
                                              zoom = pzoom, mode = pmode }
                      if current_project:create( clone_options ) then
                         print(" Proyecto clonado como '"..title.."'..OK")
                      else
                         exit = true
                         break
                      end
                   end
                else
                   print(" Eligió cancelar!")
                   msg = "El proyecto no ha sido clonado. Se sigue en: '"..current_project.settings.title.."'."
                end
            end
            if type(msg) == 'string' and msg  ~= "" then loopmsg = " "..tostring(msg) end
        elseif key == "a" then
            print(" Activando cámaras... ")
            local cam_status = self:init_cams_or_retry()
            -- cam_status == 'no_init_select' or cam_status == true --> continue
            if cam_status == 'exit' or cam_status == false then
                exit = true
                break
            end
            if defaults.mode_enable_qm_daemon then
                self:init_daemons()
            end
        elseif key == "i" then
              state.show_cam_status_info = true
        elseif key == "ins" then
           if current_project.session.noc_mode == 'odd-even' then
               print(" Insertando espacio vacio en "..string.format("%04d", current_project.state.counter.even).."-"..string.format("%04d", current_project.state.counter.odd))
           else -- current_project.session.noc_mode == 'single'
               print(" Insertando espacio vacio en "..string.format("%04d", current_project.state.counter.single))
           end
            current_project:insert_empty_in_counter()
                print()
                print(" Presione <enter> para continuar...")
                local key = io.stdin:read'*l'
        elseif key == "desde" then
            if type(current_project.state.counter) == 'table' then
               if current_project.session.noc_mode == 'odd-even' then
                  if current_project.state.counter.even and current_project.session.counter_max.even then
                     if current_project.state.counter.even <= current_project.session.counter_max.even then
                        current_project.session.include_list.from = current_project.state.counter.even
                        loopmsg = " Valor 'desde' actualizado ("..tostring(current_project.session.include_list.from)..")"
                     else
                        loopmsg = " No puede marcarse esta posición (aun no se realizó la captura)"
                     end
                  else
                     loopmsg = " ERROR: el contador no registra valores o no esta establecido counter_max"
                  end
               else -- current_project.session.noc_mode == 'single'
                  if current_project.state.counter.single and current_project.session.counter_max.single then
                     if current_project.state.counter.single <= current_project.session.counter_max.single then
                        current_project.session.include_list.from = current_project.state.counter.single
                        loopmsg = " Valor 'desde' actualizado ("..tostring(current_project.session.include_list.from)..")"
                     else
                        loopmsg = " No puede marcarse esta posición (aun no se realizó la captura)"
                     end
                  else
                     loopmsg = " ERROR: el contador no registra valores o no esta establecido counter_max"
                  end
               end
            end
        elseif key == "hasta" then
            if type(current_project.state.counter) == 'table' then
               if current_project.session.noc_mode == 'odd-even' then
                  if current_project.state.counter.odd and current_project.session.counter_max.odd then
                     if current_project.state.counter.odd <= current_project.session.counter_max.odd then
                        current_project.session.include_list.to = current_project.state.counter.odd
                        loopmsg = " Valor 'hasta' actualizado ("..tostring(current_project.session.include_list.to)..")"
                     else
                        loopmsg = " No puede marcarse esta posición (aun no se realizó la captura)"
                     end
                  else
                     loopmsg = " ERROR: el contador no registra valores o no esta establecido counter_max"
                  end
               else -- current_project.session.noc_mode == 'single'
                  if current_project.state.counter.single and current_project.session.counter_max.single then
                     if current_project.state.counter.single <= current_project.session.counter_max.single then
                        current_project.session.include_list.to = current_project.state.counter.single
                        loopmsg = " Valor 'desde' actualizado ("..tostring(current_project.session.include_list.to)..")"
                     else
                        loopmsg = " No puede marcarse esta posición (aun no se realizó la captura)"
                     end
                  else
                     loopmsg = " ERROR: el contador no registra valores o no esta establecido counter_max"
                  end
               end
            end
        elseif key == "reparar" then
            local status, no_errors, log = current_project:reparar()
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
        elseif key == "regenerar" then
            -- borra subcarpetas 'pre' (single, odd o even, segun noc_mode)
            -- e ignorando state previo regenera 'pre' a partir de lo que haya en 'raw'

            local folders = {}
            if current_project.session.noc_mode == 'odd-even' then
                folders = { 'odd', 'even' }
            else -- self.session.noc_mode == 'single'
                folders = { 'single' }
            end
            for n, idname in pairs(folders) do
                local command = "rm -r "..current_project.session.base_path.."/"..current_project.paths.proc[idname].." > /dev/null 2>&1"
                print(command)
                if not os.execute(command) then
                   print("ERROR\n    falló: '"..command.."'")
                end
            end
            local status, no_errors, log = current_project:reparar(true)
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
            open_file_browser(current_project.session.base_path)
        elseif key == "modificar titulo" or key == "modificar título" then
            local status, new_title = modify_title(current_project.settings.title)
            if status == true then
               current_project.settings.title = new_title
               loopmsg = " El título ahora es: '"..current_project.settings.title.."'"
               if not current_project:write() then
                  print(" ERROR\n    no se pudo guardar el proyecto actual.")
               end
            elseif status == nil then
               loopmsg = " El valor del título no fue modificado"
            else
               loopmsg = " Cancelado"
            end
        elseif key == "modificar rotacion" or key == "modificar rotación" then
           if current_project.session.noc_mode == 'single' then
              local status, new_rotation = modify_rotation(current_project.state.rotate.single)
              if status == true then
                current_project.state.rotate.single = new_rotation
                loopmsg = " La rotación ahora es: '"..current_project.state.rotate.single.."'"
                current_project:save_state()
              elseif status == nil then
                loopmsg = " El valor de la rotación no fue modificado"
              else
                loopmsg = " Cancelado"
              end
           else
             loopmsg = " Esta opción sólo es válida para proyectos en modo 'single'"
           end
        elseif key == "pdf abrir" then
            if current_project.state.last_pdf_generated then
                local pdf_path = current_project.session.base_path.."/"..current_project.paths.doc_dir.."/"..current_project.state.last_pdf_generated
                if dcutls.localfs:file_exists( pdf_path ) then
                   print(" abriendo.. '"..pdf_path.."'")
                   open_pdf_viewer( pdf_path )
                else
                   loopmsg = " No existe '"..current_project.state.last_pdf_generated.."'\n"
                           .."   El archivo PDF no se ha terminado de generar o ha sido eliminado.\n"
                           .."   Para más opciones use 'pdf listar' (verá una lista de los PDFs)"
                end
            else
                loopmsg = " Todavía no se ha creado ningún PDF en este proyecto.\n"
                        .."   Para más opciones use 'pdf listar' (verá una lista de los PDFs)"
            end
        elseif key == "pdf listar" then
            local status, pdf_filename, result, msg = current_project:list_pdfs_and_select()
            if status == true then
                local pdf_path = current_project.session.base_path.."/"..current_project.paths.doc_dir.."/"..pdf_filename
                if dcutls.localfs:file_exists( pdf_path ) then
                   print(" abriendo.. '"..pdf_path.."'")
                   open_pdf_viewer( pdf_path )
                else
                end
            elseif status == nil then
                loopmsg = " "..tostring(msg)
            else

                loopmsg = " Ha ocurrido un error inesperado."
            end
        elseif key == "pdf borrar" then
            local status, pdf_filename, result, msg = current_project:list_pdfs_and_select()
            if status == true then
                print()
                print(" Borrar '"..pdf_filename.."'? [S/n]")
                local confirmar = io.stdin:read'*l'
                if confirmar == "S" or confirmar == "s" then
                    if current_project:delete_pdf(pdf_filename) then
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
            local status, strlist, suffix = current_project:get_include_strings()
            if key == "scr abrir" and not status then
                loopmsg = " Debe seleccionar un rango de páginas primero para seleccionar esta opción."
            else
                if key == "sc abrir" then suffix = nil; strlist = nil; end
                suffix = suffix or ""
                local sct_name = current_project.dalclick.doc_filebase..suffix..".scantailor"
                local sct_path = current_project.session.base_path.."/"..current_project.paths.post_dir.."/"..current_project.session.ppp.."/"..sct_name
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
                        if current_project:send_post_proc_actions({
                                scantailor_create_project = true,
                                include_list              = include,
                                noc_mode = current_project.session.noc_mode,
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
            local status, sc_filename, result, msg = current_project:list_scantailors_and_select()
            if status == true then
                print()
                print(" Borrar '"..sc_filename.."'? [S/n]")
                local confirmar = io.stdin:read'*l'
                if confirmar == "S" or confirmar == "s" then
                    if current_project:delete_scantailor_project(sc_filename) then
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
            local status, sc_filename, result, msg = current_project:list_scantailors_and_select()
            if status == true then
                local stproject_path = current_project.session.base_path.."/"..current_project.paths.post_dir.."/"..current_project.session.ppp.."/"..sc_filename
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
            if current_project:project_is_not_empty() then
                print("ingrese un valor para 'desde'")
                printf(">> ")
                local continue = false
                local desde = io.stdin:read'*l'
                if desde ~= "" and desde ~= nil and tonumber(desde) >= 0 then
                    current_project.session.include_list.from = tonumber(desde)
                    print(" Valor 'desde' ingresado: "..tostring(current_project.session.include_list.from))
                    continue = true
                else
                    print(" Valor 'desde' ingresado inválido! ("..tostring(current_project.session.include_list.from)..")")
                end
                if continue then
                    print("ingrese un valor para 'hasta'")
                    printf(">> ")
                    local hasta = io.stdin:read'*l'
                    if hasta ~= "" and hasta ~= nil then
                        hasta = tonumber(hasta)
                        if hasta > current_project.session.include_list.from then
                            if hasta <= current_project.session.counter_max.odd then
                                current_project.session.include_list.to = hasta
                                print(" Valor 'desde' ingresado: "..tostring(current_project.session.include_list.to))
                            else
                                print(" El valor de 'hasta' debe ser menor o igual a la ultima imagen capturada")
                            end
                        else
                            print(" El valor de 'hasta' debe ser mayor a 'desde'")
                        end
                    else
                       print(" Valor 'hasta' ingresado inválido! ("..tostring(current_project.session.include_list.from)..")")
                    end
                end
            end
        elseif key == "rango borrar" then
            if current_project.session.include_list.from and current_project.session.include_list.to then
                current_project.session.include_list = {}
                loopmsg = " Rango de páginas borrado!"
            else
                loopmsg = " Todavia no se seleccionó ningún rango de páginas."
            end
        elseif key == "pp" or key == "ppr" or key:sub(0,3) == "pp " or key:sub(0,4) == "ppr " or key == "scantailor" then
            if key == "scantailor" then key = "pp scantailor" end
            -- TODO lista de postprocesos en '/post' / poder de seleccionar un postproceso de lista
            -- crear nuevo posproceso / opcion mas simple: trabajar sobre el postproceso 'Default'
            -- 'n' crear nuevo postproceso, 'o' abrir existosamente
            -- concepto de 'current' para los posprocesos, el current inicial es 'Default'
            -- en dalclick debe aparecer en la seccion pp el nombre del 'current'
            local include_list_exists = false
            local suffix
            if current_project.session.include_list.from and current_project.session.include_list.to then
                include_list_exists = true
                suffix = "["..string.format("%04d", current_project.session.include_list.from).."-"
                            ..string.format("%04d", current_project.session.include_list.to).."]"
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
                    print(" Proyecto de postprocesado: '"..tostring( current_project.session.ppp ).."'")
                    print()
                    print( msg )
                    print()
                    if ppr then print(" procesamiento parcial de rango: "..tostring(suffix).."\n") end
                    print( " ¿Enviar estas acciones a la cola de procesamiento? (S/n)")
                    printf(">> ")
                    local confirm = io.stdin:read'*l'
                    if confirm == "S" or confirm == "s" then
                        if current_project:send_post_proc_actions({
                            pp_mode      = true,
                            pp           = 'pp='..pp_args,
                            include_list = include_list_exists,
                            noc_mode     = current_project.session.noc_mode,
                        }) then
                            suffix = suffix or ""
                            loopmsg =
                                " Proyecto '"..current_project.session.regnum
                              .."' / '"..current_project.settings.title.."' enviado "
                              .."('"..current_project.session.noc_mode.."') "
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
            if current_project:load_state_secure() then
                loopmsg = "load_state_secure: OK"
            else
                loopmsg = "load_state_secure: no se pudo cargar '.dc_state' correctamente"
            end
        elseif key == "version" then
           if current_project:load_version() then
                loopmsg = " Versión del proyecto: "..tostring(current_project.version)
                loopmsg = loopmsg.."\n  "
                        .." Versión compatible actual: "..tostring(defaults.dalclick_project_version)
                local status = current_project:check_version()
                if status then
                   loopmsg = loopmsg.."\n  "
                        .." OK: versión actual"
                else
                   if status == nil then
                      loopmsg = loopmsg.."\n  "
                        .." ERROR!"
                   else
                      loopmsg = loopmsg.."\n  "
                        .." OUTDATED!"
                   end
                end
           else
                loopmsg = " Este proyecto no tiene versión!"
           end
        else
            loopmsg = " El texto ingresado no corresponde a ninguna opción del menú! ¯\\_(ツ)_/¯"
        end
    end -- /while loop

    if defaults.mode_enable_qm_daemon then
        self:kill_daemons()
    end

    --
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
