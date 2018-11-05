-- local funtions fro multicam

local mc = {}

local function print_cam_info(data, depth, item, opts)

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
        os.execute("sleep 0.2")
    end
end

function mc:camsound_pip_pip_pip()
    for i,lcon in ipairs(self.cams) do
        lcon:exec("play_sound(4); sleep(150); play_sound(4); sleep(150); play_sound(4); sleep(150)")
        os.execute("sleep 0.4")
    end
end

function mc:camsound_ref_cam()
    for i,lcon in ipairs(self.cams) do
        if lcon.idname == current_project.settings.ref_cam then
            print("camara de referencia: '"..current_project.settings.ref_cam.."'")
            lcon:exec("play_sound(4); sleep(150); play_sound(4); sleep(150); play_sound(4); sleep(150)")
            os.execute("sleep 0.4")
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
    local menu = ""
    if current_project.session.noc_mode == 'odd-even' then
       menu = [[
 ====================================================================
 ATENCION: Se recomienda borrar todas las imágenes contenidas en las
 tarjetas SD de las cámaras antes de comenzar.
 ====================================================================

 opciones:

 [enter] para borrar todas las imágenes
 [c] para continuar sin borrar

]]
    else -- current_project.session.noc_mode == 'single'
       menu = [[
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
        command = "econvert -i "..saved_file.path.." --rotate "..current_project.state.rotate[idname].." -o "..current_project.session.base_path.."/"..current_project.paths.pre[idname].."/"..saved_file.basename.." > /dev/null 2>&1"

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

function mc:pre_filters_all()
    local command, path
    local command_fail = false
    for idname,saved_file in pairs(current_project.state.saved_files) do
        local thumbpath = current_project.session.base_path.."/"..current_project.paths.pre[idname].."/"..current_project.dalclick.thumbfolder_name
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
        local prefilters_param = ""
        for prefilter, value in pairs( current_project.settings.prefilters ) do
            prefilters_param = prefilters_param .. " --" .. prefilter .. " " .. value[idname]
        end
        command =
            "econvert -i "..saved_file.path
          ..( current_project.settings.rotate and " --rotate "..current_project.state.rotate[idname] or "")
          .. prefilters_param
          .." -o "..current_project.session.base_path.."/"..current_project.paths.pre[idname].."/"..saved_file.basename
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
        os.execute("sleep 0.1")
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
        os.execute("sleep 0.1")
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
                        if mc:pre_filters_all() then
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
                local prefilters_param = ""
                for prefilter, value in pairs( current_project.settings.prefilters ) do
                    prefilters_param = prefilters_param .. " --" .. prefilter .. " " .. value[idname]
                end
                local command =
                    "econvert"
                  .." -i "..command_paths[idname].src_path
                  ..( current_project.settings.rotate and " --rotate "..current_project.state.rotate[idname] or "")
                  .. prefilters_param
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
        os.execute("sleep 0.1")
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
        os.execute("sleep 1")
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
        os.execute("sleep 0.1")
    end
    --
    os.execute("sleep 0.3")
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

return mc
