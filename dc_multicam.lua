local dc_multicam = {}

function dc_multicam:test_progress(progress,flags)
	for i=0,10000 do
		-- take one step in a long calculation
		-- update progress in some meaningful way
		progress.value = i / 10000
		-- allow the dialog to process any messages
		iup.LoopStep()
		-- notice the user wanting to cancel and do something meaningful
		if flags.cancelflag then break end
	end

end

function dc_multicam:shoot_and_download_all(progress, flags, cams, param, dlg)


    local result = {}
    result.warnings = {}


	-- result.status = number
      -- 0 exito!
		-- 1 - no se proporciono una conexion
		-- 2 - los parametros no son consistentes con la conexion
		-- 3 - fallo disparo en alguna camara
		-- 4 - fallo al intentar obtener el nombre de la captura
		-- 5 - si se proporciono control_path, se detecto coincidencia (se esta descargando una captura anterior)
		-- 6 - no existe el directorio de destino
		-- 7 - fallo la descarga
	-- result.successful[idname] = {} or nil
	-- 		path = ...la ruta completa en la pc donde se guardo la imagen
	-- 		basepath = ...la ruta al directorio donde se guardo la imagen
	-- 		basename = ...el nombre del archivo
	-- 		remote_path = ...la ruta remota del archivo en la camara
	-- 
	-- result.download_fail = string or nil
	--	  idname de la camara que fallo en una descarga
	-- result.cam_fail = string or nil 
	--	  idname de la camara que fallo o tuvo el problema
	-- result.remote_path_fail = string or nil
	--	  path remoto que se detecto ya descargado

    -- param.delay 1,2,4
    -- param.device[idname] = {}

    if type(cams) == 'table' and next(cams) then
		-- continue
    else
       print("cams en shoot_and_download_all: '"..type(cams).."'")
	   result.status = 1
       return result
    end

	progress.value = 0.05; dlg.title = "verificando parámetros"
	iup.LoopStep()
	if flags.cancelflag then result.status = 999; return result end

    local check_param = false
    if type(param) == 'table' and next(param) then
		if type(param.device) == 'table' and next(param.device) then
			for i,lcon in ipairs(cams) do
			   if param.device[lcon.idname] then
                   check_param = true				
			   end
			end
		end
	end
    if not check_param then
	   result.status = 2
	   return result
    end

	progress.value = 0.1; dlg.title = "capturando"
	iup.LoopStep()
	if flags.cancelflag then result.status = 999; return result end

    for i,lcon in ipairs(cams) do

        local status, err = lcon:exec([[
if get_raw() then
    set_raw(0)
    sleep(100)
end
sleep(100)
press('shoot_full_only'); sleep(100); release('shoot_full')
]] )
        if not status then
		   result.status = 3
		   result.cam_fail = lcon.idname
	       return result
        end
        sys.sleep(100)
    end

    local delay = param.delay or 2

	progress.value = 0.2; dlg.title = "esperando "..tostring(delay).." seg..."
	iup.LoopStep()
	if flags.cancelflag then result.status = 999; return result end
    
    local progr = 0.2
    local incr = 0.3 / (delay*10)
    for n=0, delay*10, 1 do
        sys.sleep(100)
        --print(".")
        progr = progr + incr
		progress.value = progr 
		iup.LoopStep()
		if flags.cancelflag then result.status = 999; return result end

    end
    --

	progress.value = 0.51; dlg.title = "obteniendo nombres"
	iup.LoopStep()
	if flags.cancelflag then result.status = 999; return result end

    for i,lcon in ipairs(cams) do
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
            if type(param.control_paths) == 'table' then
				if type(param.control_paths[lcon.idname]) == 'table' then
		            if param.control_paths[lcon.idname].remote_path == lcon.remote_path then
		                print(" ======================================================")
		                print(" ATENCION: no se esta descargando la ultima captura!!!!")
		                print(" ======================================================")
		                print(" Vuelva a intentarlo...")
		                print(" Si el problema persiste pruebe en modo 'seguro' ó 'normal'.")
		                print(" Verifique que se estén borrando las imágenes de la tarjeta SD de la cámara.")
						result.status = 5
						result.cam_fail = lcon.idname
						result.remote_path_fail = lcon.remote_path
						return result
		            end
				else
                    table.insert(result.warnings, "No existe idname en control_paths para '"..tostring(lcon.idname).."'")
				end
            end
        else
            print()
            print(" ATENCION: no se puedo obtener el nombre de la última captura") 
            print(" Vuelva a intentarlo...")
            print(" Si el problema persiste pruebe en modo 'seguro' ó 'normal'.")
            print()
            --"status: "..tostring(status)..", lastdir: "..tostring(lastdir)..", lastcapt: "..tostring(lastcapt)..", err: "..tostring(err))
		    result.status = 4
		    result.cam_fail = lcon.idname
	        return result
        end
        sys.sleep(100)
    	progress.value = 0.5 + (i * 0.05);
	    iup.LoopStep()
	    if flags.cancelflag then result.status = 999; return result end

    end
    --
    -- sys.sleep(300)
    --

	progress.value = 0.6; dlg.title = "descargando"
	iup.LoopStep()
	if flags.cancelflag then result.status = 999; return result end

   
    local download_fail = false
    result.successful = {}
    for i,lcon in ipairs(cams) do

        if not dcutls.localfs:file_exists( param.device[lcon.idname].dest_tmp_dir ) then
            result.status = 6
            return result
        end
        local dest_path = param.device[lcon.idname].dest_tmp_dir..param.device[lcon.idname].dest_filemame
        --
        printf(" ["..i.."] descargando... '"..lcon.remote_path.."' -> '"..param.device[lcon.idname].dest_filemame.."' ..")
        --
        local results,err = lcon:download(lcon.remote_path, dest_path)
        --
        if results and dcutls.localfs:file_exists(dest_path) then
            result.successful[lcon.idname] = {
                path = dest_path,
                basepath = param.device[lcon.idname].dest_tmp_dir,
                basename = param.device[lcon.idname].dest_filemame,
                remote_path = lcon.remote_path
            }
            print("OK")
        else
            download_fail = true
            result.download_fail = lcon.idname
            break
        end
    	progress.value = 0.6 + (i * 0.05);
	    iup.LoopStep()
	    if flags.cancelflag then result.status = 999; return result end

    end

    if download_fail then
        result.status = 7
    else
        -- todo ok
        result.status = 0
    end
	progress.value = 0.7; dlg.title = "borrando captura remota"
	iup.LoopStep()
	if flags.cancelflag then result.status = 999; return result end

    --
    -- remove remote files
    for i,lcon in ipairs(cams) do
        if lcon.remote_path ~= "" and lcon.remote_path ~= nil then
            local status, err = lcon:execwait('os.stat("'..lcon.remote_path..'")')
            if status ~= nil then
                printf(" ["..i.."] borrando de la cámara: '"..lcon.remote_path.."' ..")
                local status, err = lcon:execwait('os.remove("'..lcon.remote_path..'")')
                if status ~= nil then
                    print("OK")
                else
                    table.insert(result.warnings, "no se pudo borrar: '"..lcon.remote_path.."'")
                    print("     ATENCION: no se pudo borrar: '"..lcon.remote_path.."'")
                end
            else
                table.insert(result.warnings, "no existe: '"..lcon.remote_path.."'")
                print("     ATENCION: '"..lcon.remote_path.. "' no existe")
            end
        end
    end

    --nd
    return result
    --
end

return dc_multicam

