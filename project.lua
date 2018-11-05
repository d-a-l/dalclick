local project = {}

project = {
    -- project state
    state = {},
    -- project session (valores se sesion que no se guardan como variables)
    session = {},
    -- project session (valores se sesion que no se guardan como variables)
    paths = {},
    -- project settings vars
    settings = {},
    settings_default = {},
    -- dalclick globals vars
    dalclick = {},
}

function project:init(globalconf)
    self.dalclick = globalconf
    --
    self.session.regnum = nil
    self.session.base_path = nil -- /abs/path/to/regnum
    self.session.root_path = nil -- /abs/path/to
    self.session.preview_counter = {}
    self.session.counter_max = {}
    self.session.counter_min = {}
    self.session.include_list = {}
    self.session.noc_mode = nil
    self.session.ppp = self.dalclick.ppp_default_name
    --
    self.version = nil
    --
    self.paths = globalconf.paths
    --
    self.settings_default.noc_mode = nil
    self.settings_default.ref_cam = nil
    self.settings_default.rotate = nil
    self.settings_default.mode = globalconf.delay_mode -- 'secure'

    self.settings.prefilters = {}
    -- self.settings.prefilters.contrast = nil  -- { odd = x, even = x, single = x} -- 0.0 a 1.0 aumenta contraste, 0.0 a -1.0 reduce comntraste, valores superiores o inferiores producen cosas raras
    -- self.settings.prefilters.brightness = nil
    -- self.settings.prefilters.lightness = nil
    -- self.settings.prefilters.gamma = nil
    -- self.settings.prefilters.normalize = nil
    -- self.settings.prefilters.colorspace = nil -- Valid values are: BW, BILEVEL, GRAY, GRAY1, GRAY2, GRAY4, RGB, YUV and CYMK.
    -- mas en https://manpages.debian.org/jessie/exactimage/econvert.1.en.html

    self.settings.title = nil
    self.settings.ref_cam = nil
    self.settings.rotate = nil
    self.settings.mode = self.settings_default.mode
    self.settings.last_noc_mode = nil
    --
    self.state.counter = {}
    self.state.zoom_pos = nil
    self.session.last_pdf_generated = nil
    self.state.saved_files = nil -- last capture paths
    -- self.state.focus = nil -- ojo puede no ser igual para las dos cams
    -- self.state.resolution = nil
    self.state.rotate = {
        odd = nil,
        even = nil,
        single = nil
    }
    return true
end

function project:delete_running_project()
    -- delete reference to existing running project (close)
    if dcutls.localfs:delete_file(self.dalclick.dc_config_path.."/running_project") then
        return true
    else
        print("no se pudo eliminar: "..self.dalclick.dc_config_path.."/running_project")
        return false
    end
end

function project:update_running_project(settings_path)
    -- update actual running project project reference
    if dcutls.localfs:file_exists(self.dalclick.dc_config_path.."/running_project") then
        if not dcutls.localfs:delete_file(self.dalclick.dc_config_path.."/running_project") then
            print(" Error: No se pudo eliminar: '"..self.dalclick.dc_config_path.."/running_project'.")
            return false
        end
    end
    if dcutls.localfs:create_file(self.dalclick.dc_config_path.."/running_project",settings_path) then
        return true -- running project actualizado con el path recibido
    else
        print(" Error: No se pudo crear: '"..self.dalclick.dc_config_path.."/running_project'.")
        return false
    end
end

function project:write()
    -- save existing project
    local state = util2.serialize(self.state)
    local settings = util2.serialize(self.settings)

    if dcutls.localfs:create_file(self.session.base_path.."/.dc_state", state) and dcutls.localfs:create_file(self.session.base_path.."/.dc_settings", settings) then
        -- print(" '"..self.session.regnum.."' guardado")
        return true
    else
        -- print("no se pudo guardar la configuracion del proyecto actual en:  "..self.session.base_path.."/")
        return false
    end
end

function project:open(defaults, options)
    local options = options or {}
    if type(options) ~= 'table' then return false end

    -- return true, 'opened':   proyecto abierto exitosamente
    -- return true, 'canceled': se cancelo la operacion o la seleccion no es valida -> continua el proyecto anterior
    -- return true, 'modified': proyecto abierto exitosamente pero con modificaciones -> guardar proyecto inmediatamente
    --                          si se desean guardar los cambios
    ---
    -- return false: no se pudo abrir el proyecto o contiene errores -> salir de dalclick o dar opcion de volver a abrior o crear
    --
    require( "iuplua" )
    local regnum_dir, status, folder, load_dir_error, a

    -- Creates a file dialog and sets its type, title, filter and filter info
    local fd = iup.filedlg{ dialogtype = "DIR",
                            title = "Seleccionar carpeta de proyecto",
                            directory = options.root_path,
                            -- parentdialog = iup.GetDialog(self)
                            }

    -- Shows file dialog in the center of the screen
    fd:popup(iup.ANYWHERE, iup.ANYWHERE)

    -- Gets file dialog status
    status = fd.status
    folder = fd.value

    fd:destroy()
    -- iup.Destroy(od)

    -- Check status
    load_dir_error = true
    if status == "0" then
      if type(folder) ~= 'string' then
          -- nota: solo con Alarm se pudo corregir el problema de que no se podia cerrar filedlg
          iup.Alarm("Cargando proyecto", "Error: Hubo un problema al intentar cargar '"..tostring(folder).."'" ,"Continuar")
      else
          if folder == self.session.regnum then
              iup.Alarm("Cargando proyecto", "El proyecto seleccionado es el proyecto abierto actualmente" ,"Continuar")
          else
              a = iup.Alarm("Cargando proyecto", "Carpeta seleccionada:\n"..folder ,"OK", "Cancelar")
              if a == 1 then
                  load_dir_error = false
                  regnum_dir = folder
              end
          end
      end
    elseif status == "-1" then
          iup.Alarm("Cargando proyecto", "Operación cancelada" , "Continuar")
    else
          iup.Alarm("Cargando proyecto", "Se produjo un error" ,"Continuar")
    end


    if load_dir_error then
        print(" [Abrir proyecto] Error: no se pudo seleccionar una carpeta de proyecto válida.")
        return true, 'canceled'
    end

    -- All ok, load project

    if dcutls.localfs:file_exists(regnum_dir.."/.dc_settings") then
        if not self:init(defaults) then
            return false
        end
        local load_status, project_status = self:load(regnum_dir.."/.dc_settings")
        if load_status == true then
            print(" Proyecto cargado con éxito desde '"..regnum_dir.."'." )
            -- guardar referencia al proyecto cargado como "running project"
            if self:update_running_project(regnum_dir.."/.dc_settings") then
                return true, project_status -- success!!
            else
                print(" [Abrir proyecto] Error: no se pudo actualizar la configuración interna de DALclick" )
                return false
            end
        else
            print(" [Abrir proyecto] Error: no se pudo cargar un proyecto desde '"..regnum_dir.."/.dc_settings'.")
            print(" [Abrir proyecto] La carpeta seleccionada contiene un proyecto DALclick con errores.")
            return false
        end
    else
            print(" [Abrir proyecto] La carpeta seleccionada no contiene un proyecto DALclick.")
            return false
    end
end

function project:create( options )
    local options = options or {}
    if type(options) ~= 'table' then return false end

    self.session.regnum = options.regnum
    self.session.root_path = options.root_path
    self.session.base_path = self.session.root_path.."/"..self.session.regnum

    self.settings.title = options.title
    if options.mode then self.settings.mode = options.mode end

    self.session.noc_mode = self.dalclick.noc_mode_default
    self.settings.last_noc_mode = self.session.noc_mode
    if self.session.noc_mode == 'odd-even' then
	    self.settings.ref_cam = self.dalclick.oddeven_default_ref_cam
	    self.settings.rotate = self.dalclick.oddeven_default_rotate
    else -- self.session.noc_mode == 'single'
	    self.settings.ref_cam = self.dalclick.single_default_ref_cam
	    self.settings.rotate = self.dalclick.single_default_rotate
    end

    self.settings.prefilters = {}

    print(" Se está creando un nuevo proyecto:\n")
    print(" === "..self.session.regnum.." ===")
    if self.settings.title ~= "" then print(" título: '"..self.settings.title.."'") end
    print()

    if self.session.regnum then
        local settings_path = self.session.base_path.."/.dc_settings"

        -- serialize table to save
        local content = util2.serialize(self.settings)

        -- create dir tree
        if not self.mkdir_tree(self.dalclick, self.session, self.paths) then
            return false
        end
        -- create settings file
        if not dcutls.localfs:create_file(settings_path, content) then
            return false
        end
        -- init project state
        local init_state_options = { zoom = options.zoom }
        self:init_state( init_state_options )
        if not self:save_state() then
            return false
        end
        -- create running_project
        if not self:update_running_project(settings_path) then
            print(" [Crear proyecto] Error: no se pudo actualizar la configuración interna de DALclick" )
            return false
        end
        return true -- all success!!
    else
        print("create_project_tree: no se ha recibido un número de registro válido!\n")
        return false
    end
end

function project:check_settings(opts)
    local opts = type(opts) == 'table' and opts or {}

    local log = ""
    local status = true

    if type(self.settings) ~= 'table' then
        self.settings = {}
        log = " * settings estaba sin definir\n"
        status = false
    end

    if type(self.settings.prefilters) ~= 'table' then
        self.settings.prefilters = {}
        log = " * settings prefilters estaba sin definir\n"
        status = false
    end

    if self.settings.mode and self.settings.mode ~= "" then
        --
    else
        self.settings.mode = self.settings_default.mode
        log = log .. " * Modo sin definir\n"
        status = false
    end
    if self.settings.last_noc_mode and self.settings.last_noc_mode ~= "" then
        --
    else
        self.settings.last_noc_mode = self.dalclick.noc_mode_undefined
        -- ojo, si no esta definido en los settings de un proyecto se asume que
        -- es un formato obsoleto cuando no existia noc_mode (entonces solo puede ser "odd-even")
        log = log .. " * Modo NOC sin definir\n"
        status = false
    end
    if self.settings.ref_cam and self.settings.ref_cam ~= "" then
        --
    else
		if self.session.noc_mode == "odd-even" then
        	self.settings.ref_cam = self.dalclick.oddeven_default_ref_cam
        else -- self.session.noc_mode == 'single'
        	self.settings.ref_cam = self.dalclick.single_default_ref_cam
        end
        log = log .. " * Cámara de referencia sin definir\n"
        status = false
    end
    if self.settings.rotate ~= nil then
        --
    else
		if self.session.noc_mode == "odd-even" then
        	self.settings.rotate = self.dalclick.oddeven_default_rotate
        else -- self.session.noc_mode == 'single'
        	self.settings.rotate = self.dalclick.single_default_rotate
        end
        log = log .. " * Rotar sin definir\n"
        status = false
    end
    if opts.upgrade then
        if type(self.settings.path_raw) == 'table' then
            -- por ahora desactivado por que si no pierde compatibilidad con versiones previas
            self.settings.path_raw  = nil
            self.settings.path_pre = nil
            self.settings.path_test = nil
            -- project_status = 'upgraded'
            log = log .. " ** UPGRADE paths\n"
            status = false
        end
    end
    return status, log
end

function project:check_state()
    local status = true
	if type(self.state) ~= 'table' then
	    status = false
	else
	    if type(self.state.counter) ~= 'table' then
	        status = false
	    else
            if self.session.noc_mode == 'odd-even' then
	            if type(self.state.counter.even) ~= 'number' or
	            type(self.state.counter.odd) ~= 'number' then
	                status = false
	            end
            else -- self.session.noc_mode == 'single'
	            if type(self.state.counter.single) ~= 'number' then
	                status = false
	            end
            end
	    end
	end
    return status
end

function project:load(settings_path, opts)
    local opts = type(opts) == 'table' and opts or {}

    local base_path, settings_name, ext = string.match(settings_path, "(.-)([^\\/]-%.?([^%.\\/]*))$")
    if base_path ~= nil and base_path:sub(-1) == "/" then base_path = base_path:sub(1, -2) end -- remove trailing slash if any
    -- base_path = string.match(base_path, "(.*)/$") -- remove trailing slash if any
    local root_path, regnum_name, ext = string.match(base_path, "(.-)([^\\/]-%.?([^%.\\/]*))$")
    if root_path ~= nil and root_path:sub(-1) == "/" then root_path = root_path:sub(1, -2) end -- remove trailing slash if any
    -- root_path = string.match(root_path, "(.*)/$") -- remove trailing slash if any

    -- if settings_name ~= ".dc_settings" then
    --     return false
    -- end
    -- es necesario hacer un init(defaults) antes de cargar un proyecto con :load
    -- devuelve project_status (o sea, 'modified' si se hicieron cambios o 'opened' si todo ok)
    if dcutls.localfs:file_exists(settings_path) then
        local content = dcutls.localfs:read_file(settings_path)
        if content then
            local project_status = 'opened'
            self.session.regnum    = regnum_name  -- regnum
            self.session.base_path = base_path    -- /ruta/a/regnum
            self.session.root_path = root_path    -- /ruta/a

            self:load_version() -- only needs session.base_path
            local status, msg = self:check_version()
            if not status then
               print(" Proyecto desactualizado, migrando de '"
                  ..tostring(self.version).."' a '"
                  ..tostring(self.dalclick.dalclick_project_version).."'"
               )
               local update_status, update_msg = self:update_version()
               if update_status then
                  print( update_msg )
               else
                  -- interrumpir carga
                  print( update_msg )
                  return false
               end
            end

            self.settings = util2.unserialize(content)
            local status, log = self:check_settings()
            if not status then
                print(" Reparado Settings")
                print( log )
            end

			self.session.noc_mode = self.settings.last_noc_mode
            local status = self:get_counter_max_min()

            print("\n Datos del proyecto cargado:\n")
            print(" ===================================================")
            print(" = Versión: "..self.version)
            print(" = ID:     "..self.session.regnum)
            if self.settings.title and self.settings.title ~= "" then
                print(" = Título: '"..self.settings.title.."'")
            end
            print(" = Modo: '"..self.settings.mode.."'")
            print(" = noc_mode: '"..self.session.noc_mode.."'")
            print(" = Cámara de referencia: '"..self.settings.ref_cam.."'")
            print(" = Rotar: '"..tostring(self.settings.rotate).."'")
            print()

            local load_state, check_state
            load_state = self:load_state()
            if load_state then
                check_state = self:check_state()
            end
            if load_state and check_state then
                if self.session.noc_mode == 'odd-even' then
                   print(" = cámara de páginas impares - próxima captura: "..self.state.counter.odd )
                   print(" = cámara de páginas pares - próxima captura: "..  self.state.counter.even)
                else -- self.session.noc_mode == 'single'
                   print(" = próxima captura: "..  self.state.counter.single)
                end
		        if not self.state.rotate then
		            self.state.rotate = {}
		        end
                if self.session.noc_mode == 'odd-even' then
		            if self.state.rotate.odd then
		                print(" = cámara de páginas impares - rotación: "..self.state.rotate.odd)
		            else
		                self.state.rotate.odd = self.dalclick.rotate_odd
		                print(" asignada rotación por defecto para cámara de páginas impares: "..self.state.rotate.odd)
		            end
		            if self.state.rotate.even then
		                print(" = cámara de páginas pares - rotación: "..self.state.rotate.even)
		            else
		                self.state.rotate.even = self.dalclick.rotate_even
		                print(" asignada rotación por defecto para cámara de páginas pares: "..self.state.rotate.even)
		            end
                else -- self.session.noc_mode == 'single'
		            if self.state.rotate.single then
		                print(" = rotación: "..self.state.rotate.single) -- si settings.rotate es false no importaria
		            else
		                self.state.rotate.single = self.dalclick.rotate_single
		                print(" asignada rotación por defecto: "..self.state.rotate.single)
		            end
                end
                 -- check state paths
                if self.session.noc_mode == 'odd-even' then
		            if type(self.state.saved_files) == 'table' and type(self.state.saved_files.even) == 'table' then
		                if not dcutls.localfs:file_exists(self.state.saved_files.even.path) or
		                   not dcutls.localfs:file_exists(self.state.saved_files.odd.path) then
		                    print()
		                    print(" ATENCION: alguna de las rutas temporales apuntan a archivos que no existen")
		                    print(" -> es probable que haya renombrado manualmente la carpeta o")
		                    print("    cambiado su ubicacion en el sistema")
		                    print()
		                    self.state.saved_files = nil
		                end
		            end
                else -- self.session.noc_mode == 'single'
		            if type(self.state.saved_files) == 'table' and type(self.state.saved_files.single) == 'table' then
		                if not dcutls.localfs:file_exists(self.state.saved_files.single.path) then
		                    print()
		                    print(" ATENCION: la ruta temporal apunta a un archivo que no existe")
		                    print(" -> es probable que haya renombrado manualmente la carpeta o")
		                    print("    cambiado su ubicacion en el sistema")
		                    print()
		                    self.state.saved_files = nil
		                end
		            end
				end
                -- save state!!!!
                self:save_state()
            else
                print(" ATENCION: no se ha podido cargar un estado de contador anterior.")
                self:init_state()
                self:save_state()
            end

            print(" ===================================================")
            print()

            -- verificar integridad de directorios
            local check_project_paths_status, check_status = self:check_project_paths()
            --
            if check_project_paths_status then
                return true, project_status
            else
                print(" ERROR: la estructura de directorios del proyecto no es válida y no se pudo reparar")
                return false
            end
        else
            return false
        end
    else
        print(" No existe un proyecto DALclick en la carpeta ingresada: "..settings_path)
        return false
    end
end

function project:check_project_paths()
    print(" Chequeando integridad del proyecto ")
    local msg
    local log = ""
    local repared = false

    local paths_to_check = {}
    table.insert( paths_to_check, self.paths.raw_dir  )
    table.insert( paths_to_check, self.paths.pre_dir )
    table.insert( paths_to_check, self.paths.test_dir  )
    table.insert( paths_to_check, self.paths.doc_dir  )
    table.insert( paths_to_check, self.paths.post_dir  )
    table.insert( paths_to_check, self.paths.logs_dir  )
    table.insert( paths_to_check, self.paths.raw.even )
    table.insert( paths_to_check, self.paths.raw.odd )
    table.insert( paths_to_check, self.paths.raw.all )
    table.insert( paths_to_check, self.paths.raw.single )
    table.insert( paths_to_check, self.paths.pre.even )
    table.insert( paths_to_check, self.paths.pre.odd )
    table.insert( paths_to_check, self.paths.pre.all )
    table.insert( paths_to_check, self.paths.pre.single )
    table.insert( paths_to_check, self.paths.test.even )
    table.insert( paths_to_check, self.paths.test.odd )
    table.insert( paths_to_check, self.paths.test.all )
    table.insert( paths_to_check, self.paths.test.single )

    for index, path in pairs( paths_to_check ) do
        if not dcutls.localfs:file_exists( self.session.base_path.."/"..path ) then
            msg = " ATENCION: no existe '"..tostring(self.session.base_path.."/"..path).."'"
            print(msg); log = log..msg.."\n"
            printf(" reparando...")
            if dcutls.localfs:create_folder_quiet( self.session.base_path.."/"..path ) == false then
                msg = " - ERROR No se pudo crear el directorio!"; log = log..msg.."\n"
                return false,  "can't repared", log
            end
            msg = " - Reparado"; log = log..msg.."\n"
            print("OK")
            repared = true
        end
    end
    if repared == true then
        return true, 'repared', log -- 'modified'
    else
        return true --, 'opened'
    end

end

function project.mkdir_tree(dalclick,session,paths)

    if not dcutls.localfs:file_exists(session.base_path) then
        print(" Creando árbol de directorios del proyecto...\n")
        dcutls.localfs:create_folder( session.base_path )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.raw_dir )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.pre_dir )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.test_dir )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.doc_dir )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.post_dir )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.logs_dir )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.raw.odd )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.raw.even )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.raw.all )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.raw.single )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.pre.odd )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.pre.even )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.pre.all )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.pre.single )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.test.odd )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.test.even )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.test.all )
        dcutls.localfs:create_folder( session.base_path.."/"..paths.test.single )
        return true
    else
        print("warn: '"..session.base_path.."' ya existe\n")
        return false
    end
end

function project:forward(counter, max)
    if type(max) ~= 'number' then max = 9999 end
    local next_counter = {}
    local out_of_range = false

    if self.session.noc_mode == 'odd-even' then
		for idname,count in pairs(counter) do
         if idname ~= 'single' then
            count = count + 2
            next_counter[idname] = count
            if count > max then
                out_of_range = true
            elseif count == max then
                if out_of_range ~= true then out_of_range = nil end
            end
         end
		end
    else -- self.session.noc_mode == 'single'
		for idname,count in pairs(counter) do
            if idname == 'single' then
				count = count + 1
				next_counter[idname] = count
				if count > max then
				    out_of_range = true
				elseif count == max then
				    out_of_range = nil
				end
			end
		end
    end

	if out_of_range == false then
	    return next_counter, true, 'within_range'
	elseif out_of_range == true then
	    return counter, false, 'last'
	elseif out_of_range == nil then
	    return next_counter, true, 'last'
	end
end

function project:backward(counter, min)
    if type(min) ~= 'number' then min = 0 end
    local prev_counter = {}
    local out_of_range = false

    if self.session.noc_mode == 'odd-even' then
		for idname,count in pairs(counter) do
            if idname ~= 'single' then
				count = count - 2
				prev_counter[idname] = count
				if count < min then
				    out_of_range = true
				elseif count == min then
				    if out_of_range ~= true then out_of_range = nil end
				end
			end
		end
    else -- self.session.noc_mode == 'single'
		for idname,count in pairs(counter) do
            if idname == 'single' then
				count = count - 1
				prev_counter[idname] = count
				if count < min then
				    out_of_range = true
				elseif count == min then
				    out_of_range = nil
				end
            end
		end
    end

    if out_of_range == false then
        return prev_counter, true, 'within_range'
    elseif out_of_range == true then
        return counter, false, 'first'
    elseif out_of_range == nil then
        return prev_counter, true, 'first'
    end
end

function project:counter_next(max)
    self.state.counter, counter_updated, counter_status = self:forward(self.state.counter, max)
    return counter_updated, counter_status
end

function project:counter_prev(min)
    self.state.counter, counter_updated, counter_status = self:backward(self.state.counter, min)
    return counter_updated, counter_status
end

function project:preview_counter_next(max)
    self.session.preview_counter, counter_updated, counter_status = self:forward(self.session.preview_counter, max)
    return counter_updated
end

function project:preview_counter_prev(min)
    self.session.preview_counter, counter_updated, counter_status = self:backward(self.session.preview_counter, min)
    return counter_updated
end


function project:reparar(clear)
    -- ATENCION solo funciona en modo odd-even!!!!!!!!! ToDo
    local log = ''
    local msg

    print("clear: "..tostring(clear))

    local status, check_settings_log = self:check_settings()
    if not status then
        msg = " Reparado Settings\n"
        msg = msg.."\n\n"..tostring(check_settings_log).."\n"
        print( msg )
        log = log.."\n"..msg
        printf("REPARADO ")
    end
    if clear then
            self:init_state()
            msg = " state reiniciado"
            print(msg)
            log = log.."\n"..msg
            printf("REPARADO ")
    else
        if not self:check_state() then
            self:init_state()
            msg = " state reiniciado"
            print(msg)
            log = log.."\n"..msg
            printf("REPARADO ")
        end
    end
    if self:write() then
        print("OK")
    else
        return false
    end

    ----

    printf("verificando integridad del arbol de directorios del proyecto...")
    local check_project_paths_status, check_status, check_project_log = self:check_project_paths()
    if check_project_paths_status then
        if check_status == 'repared' then
            print("OK")
            msg = " Se repararon directorios."
            print(msg)
            msg = msg.."\n\n"..tostring(check_project_log).."\n"
            log = log.."\n"..msg
        else
            print("OK")
        end
    else
        print("ERROR")
        msg ="  la estructura de directorios tenia errores pero no se pudieron reparar"
        print(msg)
        msg = msg.."\n\n"..tostring(check_project_log).."\n"
        log = log.."\n"..msg
    end

    ----

    local status = self:get_counter_max_min()
    local no_errors = true
    if status ~= true then
        msg = " Aparentemente este proyecto aun no tiene capturas\n o no se pueden leer las imagenes."
        print(msg)
        log = log.."\n"..msg
        -- sys.sleep(2000)
        return nil, false, log
    end
    -- TODO redundante desde que hacemos antes un check state? lo dejamos por las dudas
    if self.session.noc_mode == 'odd-even' then
        if self.state.rotate.odd == nil or self.state.rotate.even == nil then
            msg= " No esta definido en el proyecto como rotar las imagenes ( state.rotate[] )"
            print(msg)
            log = log.."\n"..msg
            -- sys.sleep(2000)
            return false, false, log
        end
    else
        if self.state.rotate.single == nil then
            msg= " No esta definido en el proyecto como rotar las imagenes ( state.rotate[single] )"
            print(msg)
            log = log.."\n"..msg
            -- sys.sleep(2000)
            return false, false, log
        end
    end
    if status == true then
        local counter_min_ref
        if self.session.noc_mode == 'odd-even' then
           counter_min_ref = 'even'
           counter_max_ref = 'odd'
        else
           counter_min_ref = 'single'
           counter_max_ref = 'single'
        end
        if self:set_counter(self.session.counter_min[counter_min_ref]) then
            -- TODO p.state.rotate[idname]
            msg = " iniciando reparacion desde contador en '"..tostring(self.state.counter[counter_max_ref]).."'"
            print(msg)
            log = log.."\n"..msg

            -- check preview folder
            for idname,count in pairs(self.state.counter) do
                local preview_folder = self.session.base_path.."/"..self.paths.pre[idname].."/"..self.dalclick.thumbfolder_name
                if not dcutls.localfs:file_exists( preview_folder ) then
                    if not dcutls.localfs:create_folder( preview_folder ) then
                        return false, false, log
                    end
                end
            end
            --
            local raw_path, pre_path, preview_path, filename_we, command

            while true do
            for idname,count in pairs(self.state.counter) do
                msg = " - captura "..tostring(count).." - ("..idname..")"
                print(msg)
                log = log.."\n"..msg
                if type(count) ~= 'number' then
                    msg = " Error: count"
                    print(msg)
                    log = log.."\n"..msg
                    return false, false, log
                end

                local portrait = false
                if self.settings.rotate then
                   if self.state.rotate[idname] == 180 or self.state.rotate[idname] == 0 then
                      portrait = false
                   else
                      portrait = true
                   end
                else
                   portrait = false
                end

                filename_we = string.format("%04d", count)..".jpg"
                raw_path = self.session.base_path.."/"..self.paths.raw[idname].."/"..filename_we
                pre_path = self.session.base_path.."/"..self.paths.pre[idname].."/"..filename_we
                preview_path = self.session.base_path.."/"..self.paths.pre[idname].."/"..self.dalclick.thumbfolder_name.."/"..filename_we

                if dcutls.localfs:file_exists( raw_path ) then
                    if not dcutls.localfs:file_exists( pre_path ) then
                        msg = " creando imagen preprocesada para... "..tostring(raw_path)
                        print(msg)
                        log = log.."\n"..msg
                        command =
                            "econvert -i "..raw_path
                          .." --rotate "..self.state.rotate[idname]
                          .." -o "..pre_path
                          .." --thumbnail "..( portrait and "0.125" or "0.167")
                          .." -o "..preview_path
                          .." > /dev/null 2>&1"
                        if not os.execute(command) then
                            msg = "ERROR\n    falló: '"..command.."'"
                            print(msg)
                            log = log.."\n"..msg
                            no_errors = false
                        else
                            if dcutls.localfs:file_exists( pre_path ) then
                                msg = " OK pre_path creado con exito "..tostring(pre_path)
                                print(msg)
                                log = log.."\n"..msg
                            else
                                msg = " ERROR pre_path "..tostring(pre_path)
                                print(msg)
                                log = log.."\n"..msg
                                no_errors = false
                            end
                            if dcutls.localfs:file_exists( preview_path ) then
                                msg = " OK preview_path creado con exito "..tostring(preview_path)
                                print(msg)
                                log = log.."\n"..msg
                            else
                                msg = " ERROR preview_path "..tostring(preview_path)
                                print(msg)
                                log = log.."\n"..msg
                                no_errors = false
                            end
                        end
                    elseif not dcutls.localfs:file_exists( preview_path ) then
                        command = "econvert -i "..pre_path.." --thumbnail "..( portrait and "0.125" or "0.167").." -o "..preview_path.." > /dev/null 2>&1"
                        if not os.execute(command) then
                            msg = "ERROR\n    falló: '"..command.."'"
                            print(msg)
                            log = log.."\n"..msg
                            no_errors = false
                        else
                            if dcutls.localfs:file_exists( preview_path ) then
                                msg = " OK preview_path creado con exito "..tostring(preview_path)
                                print(msg)
                                log = log.."\n"..msg
                            else
                                msg = " ERROR preview_path "..tostring(preview_path)
                                print(msg)
                                log = log.."\n"..msg
                                no_errors = false
                            end
                        end
                    end
                else
                    msg = " DEBUG no existia raw_path: "..tostring(raw_path)
                    print(msg)
                    log = log.."\n"..msg
                    no_errors = 'warning'
                end

            end -- for
            if self:counter_next(self.session.counter_max[counter_max_ref]) == false then
                break
            end
            end -- while
            msg = "\n Reparacion finalizada"
            print(msg)
            log = log.."\n"..msg
        end
        return true, no_errors, log
    else
        msg = " No se pudo obtener el listado de imagenes raw"
        print(msg)
        log = log.."\n"..msg
        return false, false, log
    end
end

function project:set_counter(pos)
    if pos == nil then return false end
    pos = tonumber(pos)
    local msg

    if self.session.noc_mode == 'odd-even' then
       if (pos % 2 == 0) then
          -- even
          self.state.counter[self.dalclick.even_name] = pos
          self.state.counter[self.dalclick.odd_name]  = pos + 1
          msg = "contador actualizado -> even: "..tostring(pos).." / odd: "..tostring(pos + 1)
       else
          -- odd
          self.state.counter[self.dalclick.even_name] = pos - 1
          self.state.counter[self.dalclick.odd_name]  = pos
          msg = "contador actualizado -> even: "..tostring(pos - 1).." / odd: "..tostring(pos)
       end
    else -- self.session.noc_mode == 'single'
       self.state.counter[self.dalclick.single_name] = pos
       msg = "contador actualizado -> "..tostring(pos)
    end
    return true, msg
end

function project:insert_empty_in_counter() -- p.state.counter
-- check for postprocess!!
    local files_to_rename = { [self.dalclick.odd_name] = {}, [self.dalclick.even_name] = {} }
    local folders = { self.dalclick.odd_name, self.dalclick.even_name }
    for n, idname in pairs(folders) do
        print("listando en "..self.session.base_path.."/"..self.paths.raw[idname])
        for f in lfs.dir(self.session.base_path.."/"..self.paths.raw[idname]) do
            if lfs.attributes( self.session.base_path.."/"..self.paths.raw[idname].."/"..f, "mode") == "file" then
                if f:match("^(%d+)%.jpg$") or f:match("^(%d+)%.JPG$" ) then
                    local pos = tonumber(f:match("^(%d+)"))
                    if pos > self.state.counter[idname] then
                        table.insert( files_to_rename[idname], pos )
                    end
                end
            end
        end
        table.sort(files_to_rename[idname], function(a,b) return(a > b) end)
        print("se renombraran "..idname)
        for i, pos in ipairs(files_to_rename[idname]) do
             print(tostring(pos).."->"..tostring(pos+2))
-- self.session.base_path.."/"..self.paths.raw[idname]
-- self.session.base_path.."/"..self.paths.pre[idname]
-- string.format("%04d", p.state.counter.even)..".".."jpg"
-- check if newname exist
-- os.rename(oldname, newname)
        end
    end

end

function project:get_counter_max_min()

    local min, max
    local folders = {}
    if self.session.noc_mode == 'odd-even' then
        folders = { self.dalclick.odd_name, self.dalclick.even_name }
    else -- self.session.noc_mode == 'single'
        folders = { self.dalclick.single_name }
    end
    for n, idname in pairs(folders) do
        for f in lfs.dir(self.session.base_path.."/"..self.paths.raw[idname]) do
            if lfs.attributes( self.session.base_path.."/"..self.paths.raw[idname].."/"..f, "mode") == "file" then
                if f:match("^(%d+)%.jpg$") or f:match("^(%d+)%.JPG$" ) then
                    if min ~= nil then
                        if f < min.f then min = { f = f, idname = idname } end
                    else
                        min = { f = f, idname = idname }
                    end
                    if max ~= nil then
                        if f > max.f then max = { f = f, idname = idname} end
                    else
                        max = { f = f, idname = idname}
                    end
                end
            end
        end
    end
    if min == nil or max == nil then
       return nil
    else
       min.f = tonumber(min.f:match("^(%d+)%..+$"))
       max.f = tonumber(max.f:match("^(%d+)%..+$"))

       if self.session.noc_mode == 'odd-even' then
          if min.idname == self.dalclick.odd_name then
             self.session.counter_min = { [self.dalclick.even_name] = min.f - 1, [self.dalclick.odd_name] = min.f }
          elseif min.idname == self.dalclick.even_name then
             self.session.counter_min = { [self.dalclick.even_name] = min.f, [self.dalclick.odd_name] = min.f + 1 }
          end
          if max.idname == self.dalclick.odd_name then
             self.session.counter_max = { [self.dalclick.even_name] = max.f - 1, [self.dalclick.odd_name] = max.f }
          elseif max.idname == self.dalclick.even_name then
             self.session.counter_max = { [self.dalclick.even_name] = max.f, [self.dalclick.odd_name] = max.f + 1 }
          end
       else -- self.session.noc_mode == 'single'
          self.session.counter_min = { [self.dalclick.single_name] = min.f }
          self.session.counter_max = { [self.dalclick.single_name] = max.f }
       end
       return true
    end
end

function project:project_is_not_empty()
   if next(self.session.counter_max) == nil then
      return false
   else
      return true
   end
end

function project:list_and_select(opts)
    if type(opts) ~= 'table' then opts = {} end
    if opts.ext == nil then opts.ext = {".*"} end
    if opts.desc == nil then
        opts.desc = {}
        opts.desc.plural = "archivos"
        opts.desc.singular = "archivo"
    end

    local file_list = {}
    if dcutls.localfs:is_dir( opts.dir ) then
       for f in lfs.dir( opts.dir ) do
           if lfs.attributes( opts.dir.."/"..f, "mode") == "file" then
               for _,extension in pairs( opts.ext ) do
                   if f:match("^(.+)%."..extension.."$") then
                       table.insert( file_list, f )
                   end
               end
           end
       end
    end
    function print_dformat(str)
          if type(str) ~= 'string' then return end
          if str:len() > 74 then str = string.sub(str, 0, 71).."..." end
          print( "| "..str..string.rep(" ", 74 - str:len()).." |" )
    end
    if next(file_list) then
        local topbotline = "+----------------------------------------------------------------------------+"
        print()
        print(" "..opts.desc.plural.." encontrados en este proyecto:")
        print()
        print( topbotline )
        print_dformat("")
        for index,pdf_file in pairs(file_list) do
            print_dformat( tostring(index)..") "..pdf_file )
        end
        print_dformat("")
        print( topbotline )
        print()
        print(" Ingrese el número de índice del archivo para seleccionarlo")
        print(" o <enter> para no abrir ninguno")
        printf(">> ")
        local key = io.stdin:read'*l'
        if key == "" then
           return nil, nil, true, "Eligió no abrir ningún "..opts.desc.singular.."."
        end

        if file_list[tonumber(key)] ~= nil then
            return true, file_list[tonumber(key)], nil
        else
            return nil, nil, nil, "El numero seleccionado no corresponde a ningun ítem de la lista."
        end
    else
        return nil, nil, false, "No hay archivos del tipo buscado en la carpeta 'done'"
    end
end

function project:list_pdfs_and_select()
    local extensions = {"pdf", "PDF"}
    local description = { singular = "archivo PDF", plural = "archivos PDF"}
    local folder = self.session.base_path.."/"..self.paths.doc_dir
    local status, file_selected, result, msg = self:list_and_select({ext = extensions, desc = description, dir = folder})
    return status, file_selected, result, msg
end

function project:list_scantailors_and_select()
    local extensions = {"scantailor"}
    local description = { singular = "archivo de Proyecto Scantailor", plural = "archivos de Proyecto Scantailor"}
    local folder = self.session.base_path.."/"..self.paths.post_dir.."/"..self.session.ppp
    local status, file_selected, result, msg = self:list_and_select({ext = extensions, desc = description, dir = folder})
    return status, file_selected, result, msg
end

function project:delete_scantailor_project(sct_name)
    if type(sct_name) ~= 'string' or sct_name == '' then return false end

    local sct_path = self.session.base_path.."/"..self.paths.post_dir.."/"..self.session.ppp.."/"..sct_name
    if dcutls.localfs:delete_file( sct_path ) then
       return true
    else
       return false
    end
end

function project:delete_pdf(pdf_name)
    if type(pdf_name) ~= 'string' or pdf_name == '' then return false end

    local pdf_path = self.session.base_path.."/"..self.paths.doc_dir.."/"..pdf_name
    if dcutls.localfs:delete_file( pdf_path ) then
       return true
    else
       return false
    end
end


function project:init_state( options )
    local options = options or {}
    if type(options) ~= 'table' then return false end

    self.state = {} -- asegurarse que no queda cargado un estado de un proyecto anterior

    self.state.counter = {}

    if self.session.noc_mode == 'odd-even' then
		if type(self.session.counter_max.even) == 'number' and type(self.session.counter_max.odd) == 'number' then
		    self.state.counter.even = self.session.counter_max.even + 1
		    print(" iniciado contador en nueva posición par (even) en: "..tostring(self.state.counter.even))
		    self.state.counter.odd  = self.session.counter_max.odd  + 1
		    print(" iniciado contador en nueva posición impar (odd) en: "..tostring(self.state.counter.odd))
		else
		    self.state.counter.even = 0
		    print(" iniciado contador par (even) en:"..tostring(self.state.counter.even))
		    self.state.counter.odd = 1
		    print(" iniciado contador impar (odd) en:"..tostring(self.state.counter.odd))
		end
    else -- self.session.noc_mode == 'single'
		if type(self.session.counter_max.single) == 'number' then
		    self.state.counter.single = self.session.counter_max.single + 1
		    print(" iniciado contador en nueva posición en: "..tostring(self.state.counter.single))
		else
		    self.state.counter.single = 1
		    print(" iniciado contador en:"..tostring(self.state.counter.single))
		end
    end

    self.state.rotate = {}
    if self.session.noc_mode == 'odd-even' then
		self.state.rotate.odd = self.dalclick.rotate_odd
		print(" asignada rotación por defecto para cámara de páginas impares: "..self.state.rotate.odd)
		self.state.rotate.even = self.dalclick.rotate_even
		print(" asignada rotación por defecto para cámara de páginas pares: "..self.state.rotate.even)
    else -- self.session.noc_mode == 'single'
		self.state.rotate.single = self.dalclick.rotate_single
		print(" asignada rotación por defecto: "..self.state.rotate.single)
    end

    if type(options.zoom) == 'number' then
        self.state.zoom_pos = options.zoom
        print(" asignado valor de zoom previo: "..tostring(options.zoom))
    end

    return true
end

function project:save_state()
    local content = util2.serialize(self.state)
    if dcutls.localfs:create_file(self.session.base_path.."/.dc_state", content) then
        return true
    else
        return false
    end
end

function project:load_version()
    local content = dcutls.localfs:read_file(self.session.base_path.."/.dc_version")
    if content then
        self.version = tonumber( util2.unserialize(content) )
    else
        -- aca metodos para deducir versiones antiguas
        self.version = 20180000
    end
    return true
end

function project:save_version()
   local content = util2.serialize(self.version)
   local version_file = self.session.base_path.."/.dc_version"
   if dcutls.localfs:create_file( version_file, content ) then
      return true
   else
      return false
   end
end

function project:check_version()
   if self.version < self.dalclick.dalclick_project_version then
      return false, "outdated"
   elseif self.version == self.dalclick.dalclick_project_version then
      return true, "updated"
   else
      return nil, ""
   end
end

function project:update_version()
   local migration_script = self.dalclick.dalclick_pwdir.."/migrations/"..self.version
   if dcutls.localfs:file_exists(migration_script) then
      local exit_status = os.execute( migration_script.." '"..self.session.base_path.."'" ) --" > /dev/null 2>&1 &"
      -- atencion, si el script devuelve '0' (exito) en lua 5.1 exit_status es '0' y en lua 5.2 'true'
      if exit_status then
          local prev_version = self.version
          self.version = self.dalclick.dalclick_project_version
          local msg = " Versión actualizada con éxito de '"
               ..tostring(prev_version).."' a '"..tostring(self.version).."'"
          new_version_data = {
             version = self.version,
             prev_version = prev_version,
             update_time = os.time(), -- unix time, para convertir: os.date("%c", unix_time) ej: "%Y/%m/%d %H:%M:%S" => 2018/04/15 20:04:59
             update_user = os.getenv("USER"),
             update_hostname = os.getenv("HOSTNAME"),
          }
          if self:save_version() and self:update_version_log( new_version_data ) then
             return true, msg
          else
             return nil, " ERROR: El proyecto fue actualizado con éxito pero fallo el registro la nueva versión!"
          end
      else
          msg = " ATENCION: No se puedo actualizar el proyecto!\n  "
          msg = msg .. " Su versión actual de Dalclick no es compatible con\n  "
          msg = msg .. " la versión del proyecto, se recomienda cerrar el proyecto\n  "
          msg = msg .. " hasta solucionar el problema."
          return false, msg
      end
   end
end

function project:update_version_log( new_version_data )
   if type(new_version_data) ~= 'table' then return false end

   local version_log_file = self.session.base_path.."/"..self.paths.logs_dir.."/.version_history"
   local version_log = {}
   if dcutls.localfs:file_exists( version_log_file ) then
      local content = dcutls.localfs:read_file( version_log_file )
      if content then
         version_log = util2.unserialize(content)
      end
   end
   table.insert(version_log, new_version_data)
   local content = util2.serialize(version_log)
   if dcutls.localfs:create_file( version_log_file, content ) then
      return true
   else
      return false
   end
end

function project:load_state()
    local content = dcutls.localfs:read_file(self.session.base_path.."/.dc_state")
    if content then
        self.state = util2.unserialize(content)
        return true
    else
        return false
    end
end

function project:load_state_secure()
    local state
    local content = dcutls.localfs:read_file(self.session.base_path.."/.dc_state")
    if not content then
        return false
    else
        state = util2.unserialize(content)
        if type(state) ~= 'table' then
            return false
        else
            if type(state.rotate) ~= 'table' or type(state.counter) ~= 'table' then
                return false
            else
                if self.session.noc_mode == 'odd-even' then
                	if not state.rotate.odd or not state.rotate.even then
                	    return false
                	else
                	    if type(state.counter.odd) ~= 'number' or type(state.counter.even) ~= 'number' then
                	        return false
                	    else
                	        self.state = state
                	        return true
                	    end
                	end
    			else -- self.session.noc_mode == 'single'
                	if not state.rotate.single then
                	    return false
                	else
                	    if type(state.counter.single) ~= 'number' then
                	        return false
                	    else
                	        self.state = state
                	        return true
                	    end
                	end
                end
            end
        end
    end

end

function project:get_include_strings(opts)
    if type(opts) ~= 'table' then opts = {} end

    if type(self.session.include_list) ~= 'table' or
        self.session.include_list.from == nil or self.session.include_list.to == nil then
        return false, nil, nil
    end

    local strlist = ""; local c = ""
    for i = self.session.include_list.from, self.session.include_list.to, 1 do
        strlist = strlist..c..string.format("%04d", i)
        c = ","
    end
    local suffix = "["
        ..string.format("%04d", self.session.include_list.from)
        .."-"
        ..string.format("%04d", self.session.include_list.to)
        .."]"
    return true, strlist, suffix
end

function project:send_post_proc_actions(opts)
    if type(opts) ~= 'table' then opts = {} end

    local dc_pp = self.dalclick.dalclick_pwdir.."/".."dc_pp"
    if dcutls.localfs:file_exists( dc_pp ) then
        local last_pdf_generated
        local status = self:get_counter_max_min()
        if status == nil then
            return false, "Aún no hay capturas para procesar en el proyecto"
        end

        local dcpp_command =
            dc_pp
            .." 'project="..self.session.base_path.."'"
            .." 'even="..   self.session.base_path.."/"..self.paths.pre.even.."'"
            .." 'odd="..    self.session.base_path.."/"..self.paths.pre.odd.."'"
            .." 'single=".. self.session.base_path.."/"..self.paths.pre.single.."'"
            .." 'all="..    self.session.base_path.."/"..self.paths.pre.all.."'"
            .." 'done="..   self.session.base_path.."/"..self.paths.doc_dir .."'"
            .." 'post="..   self.session.base_path.."/"..self.paths.post_dir.."'"
            .." 'ppp="..    self.session.ppp.."'"
            .." 'title="..  self.settings.title:gsub("'",'').."'"
            .." 'noc-mode="..opts.noc_mode.."'"
            .." 'pdf-layout=TwoPageRight'" -- TwoPageRight(PDF 1.5) Display the pages two at a time,
                                           -- with odd-numbered pages on the right
        local last_pdf_generated

        local pdf_name = self.dalclick.doc_filebase.."_"..self.session.ppp
        local pdf_ext = "."..self.dalclick.doc_fileext
        if opts.include_list then
            local status, strlist, suffix = self:get_include_strings()
            if not status then
                return false
            else
                local pdf_filename = pdf_name..suffix..pdf_ext
                dcpp_command = dcpp_command.." 'output_name="..pdf_filename.."'"
                dcpp_command = dcpp_command.." 'include="..strlist.."'"
                last_pdf_generated = pdf_filename
                local sct_filename = self.dalclick.doc_filebase..suffix..".".."scantailor"
                dcpp_command = dcpp_command.." 'scantailor_name="..sct_filename.."'"
            end
        else
            dcpp_command = dcpp_command.." 'output_name=".. pdf_name..pdf_ext.."'"

            last_pdf_generated = pdf_name..pdf_ext
            local sct_filename = self.dalclick.doc_filebase..".".."scantailor"
            dcpp_command = dcpp_command.." 'scantailor_name="..sct_filename.."'"
        end

        if opts.batch_processing then
            dcpp_command = dcpp_command.." quiet"
        end

        if self.dalclick.pdfbeads_default_quality then
            dcpp_command = dcpp_command.." pdfbeads-default-quality="..self.dalclick.pdfbeads_default_quality
        end
        -- dcpp special modes
        if opts.scantailor_create_project then
            dcpp_command = dcpp_command.." create-new-scantailor-project"
        elseif opts.scantailor_process_and_exit then
            dcpp_command = dcpp_command.." pp=+scantailor"
        elseif opts.pp_mode then
            dcpp_command = dcpp_command.." "..opts.pp -- opts.pp_mode=true => se envia opts.pp (que contiene el comando)
            if not opts.include_list then
                dcpp_command = dcpp_command.." post-actions-enabled"
            end
        else -- standart mode (no sabemnos si esta es una opcion obsoleta!)
            if not opts.include_list then
                dcpp_command = dcpp_command.." post-actions-enabled"
            end
        end

        local exit_status = os.execute(dcpp_command)
        -- print()
        -- print(" DEBUG: script exit status: "..tostring(exit_status))
        -- print(" DEBUG: type(exit status): "..type(exit_status))

        if exit_status == 0 then
            self.state.last_pdf_generated = last_pdf_generated
            self:save_state()
            return true
        else
            if opts.pp_mode then --usability improving
                print()
                print(" Presione <enter> para continuar...")
                local key = io.stdin:read'*l'
                if key == 'd' then
                  print()
                  print( "DEBUG: dcpp_command: "..tostring(dcpp_command) )
                  print()
                  print(" Presione <enter> para continuar...")
                  local key = io.stdin:read'*l'
                end
            end
            return false, "El proyecto no pudo ser enviado a la cola de postprocesamiento"
        end
    else
        return false, "ERROR: La ruta al script de post-procesamiento no esta correctamente configurada:\n '"..tostring(dc_pp).."'"
    end
end

function project:get_thumb_path(idname, filename)

    local preview_folder = self.session.base_path.."/"..self.paths.pre[idname].."/"..self.dalclick.thumbfolder_name
    if not dcutls.localfs:file_exists( preview_folder ) then
        if dcutls.localfs:create_folder( preview_folder ) then
        else
            return nil
        end
    end

    local thumb_path = preview_folder.."/"..filename
    local big_path = self.session.base_path.."/"..self.paths.pre[idname].."/"..filename

    local portrait = false
    if self.settings.rotate then
       if self.state.rotate[idname] == 180 or self.state.rotate[idname] == 0 then
          portrait = false
       else
          portrait = true
       end
    else
       portrait = false
    end

    if dcutls.localfs:file_exists( big_path ) then
        if dcutls.localfs:file_exists( thumb_path ) then
            return thumb_path
        else
            print(" creando vista previa para... "..thumb_path)
            os.execute("econvert -i "..big_path.." --thumbnail "..( portrait and "0.125" or "0.167").." -o "..thumb_path.." > /dev/null 2>&1")
            if dcutls.localfs:file_exists( thumb_path ) then
                return thumb_path
            else
               if portrait then
                  return self.dalclick.empty_thumb_path_error
               else
                  return self.dalclick.empty_thumb_path_landscapebig_error
               end
            end
        end
    else
		if portrait then
	        return self.dalclick.empty_thumb_path
		else
	        return self.dalclick.empty_thumb_path_landscapebig
		end
    end
end

function project:make_preview(pair_even_odd)
    local pair_even_odd = pair_even_odd or self.session.preview_counter

    local previews = {}
    local filenames = {}
    for idname, val in pairs( pair_even_odd ) do
        local filename_we
        if type(val) == 'table' then -- saved files no es un par even-odd
            filename_we = val.basename
        else
            filename_we = string.format("%04d", val)..".jpg"
        end
        previews[idname] = self:get_thumb_path(idname, filename_we)
        filenames[idname] = filename_we
    end

    return true, previews, filenames
end

function project:show_capts(mode, previews, filenames )

    if mode ~= "explorer" then
        if type(filenames) ~= 'table' or type(previews) ~= 'table' then
            return false
        end
    end

    self.session.preview_counter = self.state.counter

    local left = {}
    local right = {}
    local single = {}

    local noc_mode = self.session.noc_mode

    local gbtn = {}
    local button_prev_init_active = "YES"
    local button_next_init_active = "YES"

    if mode == "explorer" then
        if next(self.session.counter_max) == nil then
            -- no hay capturas
            return false
        end
        -- definir estado inicial
        if noc_mode == 'odd-even' then
           if self.session.preview_counter.odd > self.session.counter_max.odd then
               self.session.preview_counter = self.session.counter_max
           end
        else
           if self.session.preview_counter.single > self.session.counter_max.single then
               self.session.preview_counter = self.session.counter_max
           end
        end

        local status
        status, previews, filenames = self:make_preview()

        if noc_mode == 'odd-even' then
           if self.session.preview_counter.odd == self.session.counter_max.odd then
               button_next_init_active = "NO"
           end
           if self.session.preview_counter.even == self.session.counter_min.even then
               button_prev_init_active = "NO"
           end
        else
           if self.session.preview_counter.single == self.session.counter_max.single then
               button_next_init_active = "NO"
           end
           if self.session.preview_counter.single == self.session.counter_min.single then
               button_prev_init_active = "NO"
           end
        end
    end

    require("imlua")
    require("cdlua")
    require("cdluaim")
    require("iuplua")
    require("iupluacd")
    require("iupluaimglib")

    if noc_mode == 'odd-even' then
       left.image = im.FileImageLoad( previews.even )
       left.cnv = iup.canvas{rastersize = left.image:Width().."x"..left.image:Height(), border = "YES"}

       function left.cnv:map_cb()       -- the CD canvas can only be created when the IUP canvas is mapped
           self.canvas = cd.CreateCanvas(cd.IUP, self)
       end
       function left.cnv:action()          -- called everytime the IUP canvas needs to be repainted
         self.canvas:Activate()
         self.canvas:Clear()
         left.image:cdCanvasPutImageRect(self.canvas, 0, 0, 0, 0, 0, 0, 0, 0) -- use default values
       end

       right.image = im.FileImageLoad( previews.odd )
       right.cnv = iup.canvas{rastersize = right.image:Width().."x"..right.image:Height(), border = "YES"}

       function right.cnv:map_cb()       -- the CD canvas can only be created when the IUP canvas is mapped
           self.canvas = cd.CreateCanvas(cd.IUP, self)
       end
       function right.cnv:action()          -- called everytime the IUP canvas needs to be repainted
         self.canvas:Activate()
         self.canvas:Clear()
         right.image:cdCanvasPutImageRect(self.canvas, 0, 0, 0, 0, 0, 0, 0, 0) -- use default values
       end
    else
       single.image = im.FileImageLoad( previews.single )
       single.cnv = iup.canvas{rastersize = single.image:Width().."x"..single.image:Height(), border = "YES"}

       function single.cnv:map_cb()       -- the CD canvas can only be created when the IUP canvas is mapped
           self.canvas = cd.CreateCanvas(cd.IUP, self)
       end
       function single.cnv:action()          -- called everytime the IUP canvas needs to be repainted
         self.canvas:Activate()
         self.canvas:Clear()
         single.image:cdCanvasPutImageRect(self.canvas, 0, 0, 0, 0, 0, 0, 0, 0) -- use default values
       end
    end

    -- left.cnv:action(); right.cnv:action()
    -------

    if noc_mode == 'odd-even' then
       left.label = iup.label{
           title = filenames.even --, expand = "HORIZONTAL", padding = "10x5"
       }

       right.label = iup.label{
           title = filenames.odd --, expand = "HORIZONTAL", padding = "10x5"
       }
    else
       single.label = iup.label{
           title = filenames.single --, expand = "HORIZONTAL", padding = "10x5"
       }
    end

    -- with 'guest' counter mode (contador "interno" solo actualiza state.counter al hacer click en return)

    gbtn.gbtn_prev = iup.button {
        image = "IUP_ArrowLeft",
        flat = "Yes",
        action =
            function()
                local counter_updated = self:preview_counter_prev( 0 )
                if counter_updated ~= false then
                    local status, previews, filenames = self:make_preview()
                    gbtn:gbtn_action_callback(counter_updated, previews, filenames, 'prev')
                end
            end,
        canfocus="No",
        tip = "Previous",
        padding = '5x5',
        active = button_prev_init_active
    }

    gbtn.gbtn_next = iup.button{
        image = "IUP_ArrowRight",
        flat = "Yes",
        action =
            function()
                local counter_updated
                if noc_mode == 'odd-even' then
                   counter_updated = self:preview_counter_next( self.session.counter_max.odd )
                else
                   counter_updated = self:preview_counter_next( self.session.counter_max.single )
                end
                if counter_updated ~= false then
                    local status, previews, filenames = self:make_preview()
                    gbtn:gbtn_action_callback(counter_updated, previews, filenames, 'next')
                end
            end,
        canfocus="No",
        tip = "Next",
        padding = '5x5',
        active = button_next_init_active
    }

    gbtn.gbtn_go = iup.button{
        title = "Ir",
        flat = "No",
        padding = "15x2",
        action = function()  end,
        canfocus="No",
        tip = "",
    }

    gbtn.gbtn_cancel = iup.button{
        title = "Cancelar",
        flat = "No",
        padding = "15x2",
        canfocus="No",
        tip = "Cancelar",
    }

    gbtn.gbtn_from = iup.button {
        image = "IUP_MediaGotoBegin",
        flat = "No",
        padding = "15x2",
        canfocus="No",
        padding = '5x5',
        tip = "Seleccionar desde aqui",
    }

    gbtn.gbtn_to = iup.button {
        image = "IUP_MediaGoToEnd",
        flat = "No",
        padding = "15x2",
        canfocus="No",
        padding = '5x5',
        tip = "Seleccionar hasta aquí",
    }

    function gbtn:gbtn_action_callback(counter_updated, previews, filenames, action)
       if noc_mode == 'odd-even' then
          left.image =  im.FileImageLoad( previews.even ); left.cnv:action()
          right.image = im.FileImageLoad( previews.odd ); right.cnv:action()
          left.label.title = filenames.even
          right.label.title = filenames.odd
       -- gbtn_go.tip = "Go to "..filenames.even.." | "..filenames.odd
       else
          single.image =  im.FileImageLoad( previews.single ); single.cnv:action()
          single.label.title = filenames.single
       end

       if counter_updated == nil then
          if action == 'next' then
              gbtn.gbtn_next.active = "NO"
              gbtn.gbtn_prev.active = "YES"
          else
              gbtn.gbtn_prev.active = "NO"
              gbtn.gbtn_next.active = "YES"
          end
       else
           gbtn.gbtn_next.active = "YES"
           gbtn.gbtn_prev.active = "YES"
       end
    end

    -- print("DEBUG: odd "..tostring(self.session.preview_counter.odd)..".."..tostring(self.session.counter_max.odd))
    -- print("DEBUG: even "..tostring(self.session.preview_counter.even)..".."..tostring(self.session.counter_max.even))

    -------
    local viewers, labelbar
    if noc_mode == 'odd-even' then
       viewers = iup.hbox{
           left.cnv,
           right.cnv
       }

       labelbar = iup.hbox{
           left.label,
           iup.fill {
               expand="HORIZONTAL"
           },
           right.label,
           -- margin = "10x10",
           -- gap = 2,
       }
    else
       viewers = iup.hbox{
           single.cnv
       }

       labelbar = iup.hbox{
           single.label
       }
    end



    local bottombar = iup.hbox{
        btn_previous,
        iup.fill {
            expand="HORIZONTAL"
        },
        btn_next,
        margin = "10x10",
        gap = 2,
    }

    --

    local gcenter_buttons = iup.hbox{
        gbtn.gbtn_go,
        gbtn.gbtn_cancel,
        iup.label{separator="VERTICAL"},
        gbtn.gbtn_from,
        gbtn.gbtn_to,
    }

    local bottombar_guest = iup.hbox{
        gbtn.gbtn_prev,
        iup.fill {
            expand="HORIZONTAL"
        },
        gcenter_buttons,
        iup.fill {
            expand="HORIZONTAL"
        },
        gbtn.gbtn_next,
        margin = "10x10",
        gap = 2,
    }

    -- -- -- --

    local dlg
    if mode == "explorer" then
        dlg = iup.dialog{
            iup.vbox{
                viewers,
                labelbar,
                bottombar_guest
            },
            title="DALclick",
            margin="5x5",
            gap=10
        }
    else
        dlg = iup.dialog{
            iup.vbox{
                viewers,
                labelbar
            },
            title="DALclick",
            margin="5x5",
            gap=10
        }
    end


    local function destroy_dialog()
        -- print(" cerrando  ...")
        if noc_mode == 'odd-even' then
           right.image:Destroy()
           right.cnv.canvas:Kill()
           left.image:Destroy()
           left.cnv.canvas:Kill()
        else
           single.image:Destroy()
           single.cnv.canvas:Kill()
        end
        iup.ExitLoop() -- should be removed if used inside a bigger application
        dlg:destroy()
    end

    local function set_counter()
        self.state.counter = self.session.preview_counter
        self:save_state()
        if noc_mode == 'odd-even' then
           print(" Se actualizó el contador a: "..tostring(self.state.counter.even).."|"..tostring(self.state.counter.odd))
        else
           print(" Se actualizó el contador a: "..tostring(self.state.counter.single))
        end
    end

    function gbtn.gbtn_go:action()
        set_counter()
        destroy_dialog()
        return iup.IGNORE -- because we destroy the dialog
    end

    function gbtn.gbtn_cancel:action()
        destroy_dialog()
        return iup.IGNORE -- because we destroy the dialog
    end

    function dlg:close_cb() -- si se cierra desde la ventana
        destroy_dialog()
        return iup.IGNORE -- because we destroy the dialog
    end

    ----


    dlg:show()
    iup.MainLoop()
    --iup.Close()
end

return project
