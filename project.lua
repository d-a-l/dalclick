local project = {}

project = {
    -- project state
    state = {},
    -- project settings vars
    settings = {},
    -- dalclick globals vars
    dalclick = {}, 
}

function project:init(globalconf)
    self.dalclick = globalconf
    --
    self.settings.regnum = nil
    self.settings.path_raw = {
        even = nil,
        odd = nil,
        all = nil,
    }
    self.settings.path_proc = {
        even = nil,
        odd = nil,
        all = nil,
    }
    self.settings.path_test = {
        even = nil,
        odd = nil,
        all = nil,
    }
    self.settings.title = nil
    self.settings.out_img_format = 'dng'
    self.settings.ref_cam = "even"
    self.settings.rotate = true
    self.settings.mode = 'secure'
    --
    self.state.counter = nil
    self.state.zoom_pos = nil
    self.state.saved_files = nil -- last capture paths
    -- self.state.focus = nil -- ojo puede no ser igual para las dos cams
    -- self.state.resolution = nil
    self.state.rotate = {
        odd = nil,
        even = nil
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
    local state = util.serialize(self.state)
    local settings = util.serialize(self.settings)

    if dcutls.localfs:create_file(self.dalclick.root_project_path.."/"..self.settings.regnum.."/.dc_state",state) and dcutls.localfs:create_file(self.dalclick.root_project_path.."/"..self.settings.regnum.."/.dc_settings",settings) then
        -- print(" '"..self.settings.regnum.."' guardado")
        return true    
    else
        -- print("no se pudo guardar la configuracion del proyecto actual en:  "..self.dalclick.root_project_path.."/"..self.settings.regnum.."/")
        return false
    end
end

function project:open(defaults)
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
                            directory = self.dalclick.root_project_path,
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
          if folder == self.settings.regnum then
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


function project:get_project_newname()

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
                if dcutls.localfs:file_exists( self.dalclick.root_project_path.."/"..scanf_regnum ) then
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

function project:create( options )
    local options = options or {}
    if type(options) ~= 'table' then return false end
    
    self.settings.regnum = options.regnum
    self.settings.title = options.title
    
    print(" Se está creando un nuevo proyecto:\n")
    print(" === "..self.settings.regnum.." ===")
    if self.settings.title ~= "" then print(" título: '"..self.settings.title.."'") end
    print()

    if self.settings.regnum then
        local settings_path = self.dalclick.root_project_path.."/"..self.settings.regnum.."/.dc_settings"

        self.settings.path_raw.odd  = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.raw_name.."/"..self.dalclick.odd_name
        self.settings.path_raw.even = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.raw_name.."/"..self.dalclick.even_name
        self.settings.path_raw.all  = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.raw_name.."/"..self.dalclick.all_name

        self.settings.path_proc.odd  = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.proc_name.."/"..self.dalclick.odd_name
        self.settings.path_proc.even = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.proc_name.."/"..self.dalclick.even_name
        self.settings.path_proc.all  = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.proc_name.."/"..self.dalclick.all_name

        self.settings.path_test.odd  = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.test_name.."/"..self.dalclick.odd_name
        self.settings.path_test.even = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.test_name.."/"..self.dalclick.even_name
        self.settings.path_test.all  = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.test_name.."/"..self.dalclick.all_name

        -- serialize table to save
        local content = util.serialize(self.settings)
        
        -- create dir tree
        if not self.mkdir_tree(self.dalclick, self.settings) then
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

function project:print_self_p()
    print("self.settings: "..tostring(self.settings))
    print("self.settings: "..util.serialize(self.settings))
end

function project:load(settings_path)
    -- es necesario hacer un init(defaults) antes de cargar un proyecto con :load
    -- devuelve project_status (o sea, 'modified' si se hicieron cambios o 'opened' si todo ok)
    if dcutls.localfs:file_exists(settings_path) then
        local content = dcutls.localfs:read_file(settings_path)
        if content then
        
            self.settings = util.unserialize(content)
            print("\n Datos del proyecto cargado:\n")
            print(" ===================================================")
            print(" = ID:     "..self.settings.regnum)
            if self.settings.title ~= "" then print(" = Título: '"..self.settings.title.."'") end
            print()
            if settings_path ~= self.dalclick.root_project_path.."/"..self.settings.regnum.."/.dc_settings" then
                print()
                print(" Atencion! el archivo de configuracion del proyecto podría estar corrupto")
                print("  "..settings_path)
                print("  "..self.dalclick.root_project_path.."/"..self.settings.regnum.."/.dc_settings")
                print()
                return false
            end
            -- para compatibiliadad con proyectos anteriores, checkear carpeta 'test'
            self:check_project_test_paths()
            --
            local status = self:load_state()
            if status then
                local idname, count
                for idname, count in pairs(self.state.counter) do
                    if idname == 'odd' then
                        print(" = cámara de páginas impares - próxima captura: "..count)
                    elseif idname == 'even' then
                        print(" = cámara de páginas pares - próxima captura: "..count)
                    end
                end
                
                if not self.state.rotate then
                    self.state.rotate = {}
                end
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
                
                 -- check state paths
                if type(self.state.saved_files) == 'table' and type(self.state.saved_files.even) == 'table' then
                    local check = string.match(
                        self.state.saved_files.even.basepath,
                        "^(.+)/"..self.settings.regnum.."/"..self.dalclick.raw_name.."/.+$"
                        )
                    if check == nil then
                        print(" ATENCION: las rutas cargadas de la configuración del proyecto no coinciden\n con su ubicación actual")
                        self.state.saved_files = nil
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
            
            -- para compatibiliadad con proyectos anteriores, checkear rutas de 'settings'
            local check_project_paths_status, project_status = self:check_project_paths()
            --
            if check_project_paths_status then
                return true, project_status                              
            else
                print(" ERROR: las rutas indicadas en la configuracion del proyecto no son validas")
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


function project:check_project_test_paths() 

    local test_folder_path = self.dalclick.root_project_path
        .."/"..self.settings.regnum
        .."/"..self.dalclick.test_name
                       
    if self.settings.path_test == nil or self.settings.path_test.even == nil then
        self.settings.path_test = {}
        self.settings.path_test.even = test_folder_path.."/"..self.dalclick.even_name
        self.settings.path_test.odd  = test_folder_path.."/"..self.dalclick.odd_name
        self.settings.path_test.all  = test_folder_path.."/"..self.dalclick.all_name
    end

    if not dcutls.localfs:file_exists( test_folder_path ) then
        if not dcutls.localfs:create_folder( test_folder_path ) then
            return false
        end
    end

    for idname, path in pairs(self.settings.path_test) do
        if not dcutls.localfs:file_exists( path ) then
            if not dcutls.localfs:create_folder( path ) then
                return false
            end
        end
    end
end

function project:fix_paths(paths, pattern, rootpath)
   local fixed = {}
   local there_are_fixed_paths = false
   pattern = pattern:gsub("%-", '%%-')
    -- por las dudas
   pattern = pattern:gsub("%+", '%%+')
   pattern = pattern:gsub("%*", '%%*')
   pattern = pattern:gsub("%.", '%%.')
   pattern = pattern:gsub("%[", '%%[')
   pattern = pattern:gsub("%]", '%%]')
   pattern = pattern:gsub("%(", '%%(')
   pattern = pattern:gsub("%)", '%%)')
        
   for idname,path in pairs(paths) do
       local rootpath_to_check = path:match("^(.+)/"..pattern.."/.+$")
       if rootpath_to_check ~= rootpath then
           print("!")
           print(" "..tostring(rootpath_to_check).." <-> "..tostring(rootpath))
           there_are_fixed_paths = true
           -- print(" ATENCION: las rutas cargadas de la configuración del proyecto no coinciden\n con su ubicación actual")
           print("    ----> '"..path.."'")
           local relpath = path:match("^.+("..pattern..".+)$")
           if tostring(relpath) == "" or relpath == nil then
               print(" DEBUG: Se produjo un error inesperado al intentar reparar las rutas")
               print( relpath, pattern, rootpath, rootpath_to_check, path )
               return false
           end
           fixed[idname] = rootpath.."/"..relpath
       else
           printf(".")        
       end
   end
   -- print()
   if there_are_fixed_paths then
       return fixed
   else
       return nil
   end
end
    
function project:check_project_paths() 

    printf(" Chequeando integridad del proyecto\n ")
    local paths_modified = false
    fixed = self:fix_paths(
                self.settings.path_proc, 
                self.settings.regnum.."/"..self.dalclick.proc_name, 
                self.dalclick.root_project_path)
    if fixed == false then return false end
    if fixed then
        print(" NOTA: Es probable que se hayan cambiado la ruta base donde guardan los proyectos.")
        print()
        self.settings.path_proc = fixed
        paths_modified = true
    end
    
    printf("\n ")
    fixed = self:fix_paths(
                self.settings.path_raw,
                self.settings.regnum.."/"..self.dalclick.raw_name, 
                self.dalclick.root_project_path)
    if fixed == false then return false end
    if fixed then
        print(" NOTA: Es probable que se hayan cambiado la ruta base donde guardan los proyectos.")
        print()
        self.settings.path_raw = fixed
        paths_modified = true
    end

    printf("\n ")
    fixed = self:fix_paths(
                self.settings.path_test,
                self.settings.regnum.."/"..self.dalclick.test_name, 
                self.dalclick.root_project_path)
    if fixed == false then return false end
    if fixed then
        print(" NOTA: Es probable que se hayan cambiado la ruta base donde guardan los proyectos.")
        print()
        self.settings.path_test = fixed
        paths_modified = true
    end    

    print()   
    if paths_modified == true then
        return true, 'modified'
    else
        return true, 'opened'
    end
end

function project.mkdir_tree(g,s)

    if not dcutls.localfs:file_exists(g.root_project_path.."/"..s.regnum) then
        print(" Creando árbol de directorios del proyecto...\n")
        dcutls.localfs:create_folder( g.root_project_path.."/"..s.regnum)
        dcutls.localfs:create_folder( g.root_project_path.."/"..s.regnum.."/"..g.raw_name)
        dcutls.localfs:create_folder( g.root_project_path.."/"..s.regnum.."/"..g.proc_name)
        dcutls.localfs:create_folder( g.root_project_path.."/"..s.regnum.."/"..g.doc_name)
        dcutls.localfs:create_folder( g.root_project_path.."/"..s.regnum.."/"..g.test_name)
        dcutls.localfs:create_folder( s.path_raw.odd )
        dcutls.localfs:create_folder( s.path_raw.even )
        dcutls.localfs:create_folder( s.path_raw.all )
        dcutls.localfs:create_folder( s.path_proc.odd )
        dcutls.localfs:create_folder( s.path_proc.even )
        dcutls.localfs:create_folder( s.path_proc.all )
        dcutls.localfs:create_folder( s.path_test.odd )
        dcutls.localfs:create_folder( s.path_test.even )
        dcutls.localfs:create_folder( s.path_test.all )
        return true
    else
        print("warn: '"..g.root_project_path.."/"..s.regnum.."' ya existe\n")
        return false
    end
end

function project:counter_next(max)
    local next_counter = {}
    for idname,count in pairs(self.state.counter) do
        count = count + 2 -- TODO we need count cameras!!!
        if type(max) == 'number' and count > max then
            print(" el contador llegó al valor maximo")
            return false
        else
            next_counter[idname] = count
        end
    end
    self.state.counter = next_counter
    return true
end

function project:counter_prev()
    local prev_counter = {}
    for idname,count in pairs(self.state.counter) do
        count = count - 2 -- TODO we need count cameras!!!
        if count < 0 then
            print(" el contador llegó al valor de inicio")
            return false
        else
            prev_counter[idname] = count
        end
    end
    self.state.counter = prev_counter
    return true
end

function project:reparar()
    local log = ''
    local msg
    local status, counter_min, counter_max = self:get_counter_max_min()
    local no_errors = true
    if type(counter_min) ~= 'table' or type(counter_max) ~= 'table' then
        msg = " Aparentemente este proyecto aun no tiene capturas\n o no se pueden leer las imagenes."
        print(msg)
        log = log.."\n"..msg
        sys.sleep(2000)
        return false, false, log
    end
    if self.state.rotate.odd == nil or self.state.rotate.even == nil then
        msg= " No esta definido en el proyecto como rotar las imagenes ( state.rotate[] )"
        print(msg)
        log = log.."\n"..msg
        sys.sleep(2000)
        return false, false, log
    end
    if status == true then
        if self:set_counter(counter_min.odd) then
            -- TODO p.state.rotate[idname]
            msg = " iniciando reparacion desde"..tostring(self.state.counter.even).."/"..tostring(self.state.counter.odd)
            print(msg)
            log = log.."\n"..msg

            -- check preview folder
            for idname,count in pairs(self.state.counter) do
                local preview_folder = self.settings.path_proc[idname].."/"..self.dalclick.thumbfolder_name
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
                msg = " -- "..tostring(count)
                print(msg)
                log = log.."\n"..msg
                if type(count) ~= 'number' then 
                    msg = " Error: count"
                    print(msg)
                    log = log.."\n"..msg
                    return false, false, log
                end
                
                filename_we = string.format("%04d", count)..".jpg"
                raw_path = self.settings.path_raw[idname].."/"..filename_we
                pre_path = self.settings.path_proc[idname].."/"..filename_we
                preview_path = self.settings.path_proc[idname].."/"..self.dalclick.thumbfolder_name.."/"..filename_we
                
                if dcutls.localfs:file_exists( raw_path ) then
                    if not dcutls.localfs:file_exists( pre_path ) then
                        msg = " creando imagen preprocesada para... "..tostring(raw_path)
                        print(msg)
                        log = log.."\n"..msg
                        command = 
                            "econvert -i "..raw_path
                          .." --rotate "..self.state.rotate[idname]
                          .." -o "..pre_path
                          .." --thumbnail ".."0.125"
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
                        command = "econvert -i "..pre_path.." --thumbnail ".."0.125".." -o "..preview_path.." > /dev/null 2>&1"
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
            if not project:counter_next(counter_max.odd) then
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
    return true, msg
end

function project:get_counter_max_min()

    local min, max, counter_min, counter_max
    for idname, n in pairs(self.state.counter) do
        if idname == self.dalclick.odd_name or idname == self.dalclick.even_name then
            for f in lfs.dir(self.settings.path_raw[idname]) do
                if lfs.attributes(self.settings.path_raw[idname].."/"..f,"mode") == "file" then
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
        else
            return false, nil, nil
        end
    end
    if min == nil or max == nil then
        return true, nil, nil
    else
        min.f = tonumber(min.f:match("^(%d+)%..+$"))
        max.f = tonumber(max.f:match("^(%d+)%..+$"))
        if min.idname == self.dalclick.odd_name then
            counter_min = { [self.dalclick.even_name] = min.f - 1, [self.dalclick.odd_name] = min.f }
        elseif min.idname == self.dalclick.even_name then
            counter_min = { [self.dalclick.even_name] = min.f, [self.dalclick.odd_name] = min.f + 1 }
        end
        if max.idname == self.dalclick.odd_name then
            counter_max = { [self.dalclick.even_name] = max.f - 1, [self.dalclick.odd_name] = max.f }
        elseif max.idname == self.dalclick.even_name then
            counter_max = { [self.dalclick.even_name] = max.f, [self.dalclick.odd_name] = max.f + 1 }
        end
        return true, counter_min, counter_max
    end

end

function project:init_state( options )
    local options = options or {}
    if type(options) ~= 'table' then return false end    

    self.state = {} -- asegurarse que no queda cargado un estado de un proyecto anterior
   
    self.state.counter = {}
    self.state.counter.even = 0
    print(" iniciado contador par (even) en:"..tostring(self.state.counter.even))
    self.state.counter.odd = 1
    print(" iniciado contador impar (odd) en:"..tostring(self.state.counter.odd))
    
    self.state.rotate = {}
    self.state.rotate.odd = self.dalclick.rotate_odd
    print(" asignada rotación por defecto para cámara de páginas impares: "..self.state.rotate.odd)
    self.state.rotate.even = self.dalclick.rotate_even
    print(" asignada rotación por defecto para cámara de páginas pares: "..self.state.rotate.even)
    
    if type(options.zoom) == 'number' then
        self.state.zoom_pos = options.zoom
        print(" asignado valor de zoom previo: "..tostring(options.zoom))
    end
    
    return true
end

function project:save_state()
    local content = util.serialize(self.state)
    --if dcutls.localfs:create_file(self.dalclick.dc_config_path.."/.dc_state",content) then
    if dcutls.localfs:create_file(self.dalclick.root_project_path.."/"..self.settings.regnum.."/.dc_state",content) then
        return true
    else
        return false
    end
end

function project:load_state()
    local content = dcutls.localfs:read_file(self.dalclick.root_project_path.."/"..self.settings.regnum.."/.dc_state")
    if content then
        self.state = util.unserialize(content)
        return true
    else
        return false
    end
end

function project:get_thumb_path(idname, filename)
        -- local proc_path = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.proc_name.."/"..idname.."/"
    -- self.settings.path_proc[idname]
    local preview_folder = self.settings.path_proc[idname].."/"..self.dalclick.thumbfolder_name
    if not dcutls.localfs:file_exists( preview_folder ) then
        if dcutls.localfs:create_folder( preview_folder ) then
        else
            return nil
        end
    end

    local thumb_path = preview_folder.."/"..filename
    local big_path = self.settings.path_proc[idname].."/"..filename

    if dcutls.localfs:file_exists( big_path ) then
        if dcutls.localfs:file_exists( thumb_path ) then
            return thumb_path
        else
            print(" creando vista previa para... "..thumb_path)
            os.execute("econvert -i "..big_path.." --thumbnail ".."0.125".." -o "..thumb_path.." > /dev/null 2>&1")
            if dcutls.localfs:file_exists( thumb_path ) then
                return thumb_path
            else
                return self.dalclick.empty_thumb_path_error
            end
        end
    else
        return self.dalclick.empty_thumb_path
    end
end


function project:make_preview(mode)
  
    local previews = {}
    local filenames = {}
    
    if mode == 'actual' then
        for idname, pos in pairs( self.state.counter ) do
            local filename_we = string.format("%04d", pos)..".jpg"
            previews[idname] = self:get_thumb_path(idname, filename_we)
            filenames[idname] = filename_we
        end
    else -- if mode == 'last' or mode == nil
        for idname, saved_file in pairs( self.state.saved_files ) do
            previews[idname] = self:get_thumb_path(idname, saved_file.basename)
            filenames[idname] = saved_file.basename
        end
    end
    if next(previews) == nil then
        return false -- empty table 
    else
        return true, previews, filenames
    end
end

function project:alter_counter_and_make_preview(action, max)

    local previews = {}
    local filenames = {}
        
    if action == "next" then
        if self:counter_next(max) then
            self:save_state()
        else
            print( " Se llego al final de la lista")
        end
    elseif action == "prev" then
        if self:counter_prev() then
            self:save_state()
        else
            print( " Se llego al principio de la lista")
        end
    else
        return false
    end
    
    for idname, pos in pairs( self.state.counter ) do
        local filename_we = string.format("%04d", pos)..".jpg"
        previews[idname] = self:get_thumb_path(idname, filename_we)
        filenames[idname] = filename_we
    end
    
    return true, previews, filenames
end

function project:guest_counter_and_make_preview(action, max, local_counter)

    local previews = {}
    local filenames = {}

    local actualize = true
    local new_counter = {}
    if action == "next" then
        for idname,count in pairs(local_counter) do
            count = count + 2
            if type(max) == 'number' and count > max then
                print(" el contador llegó al valor maximo")
                actualize = false
                break
            else
                new_counter[idname] = count
            end
        end
    elseif action == "prev" then
        for idname,count in pairs(local_counter) do
            count = count - 2
            if count < 0 then
                print(" el contador llegó al valor de inicio")
                actualize = false
                break
            else
                new_counter[idname] = count
            end
        end
    elseif action == "idle" then
        new_counter = local_counter
    else
        return false
    end

    if actualize then
        local_counter = new_counter    
    end
    
    for idname, count in pairs( local_counter ) do
        local filename_we = string.format("%04d", count)..".jpg"
        previews[idname] = self:get_thumb_path(idname, filename_we)
        filenames[idname] = filename_we
    end
    
    return true, previews, filenames, local_counter
end

function project:send_post_proc_actions()

    local dc_pp = self.dalclick.dalclick_pwdir.."/".."dc_pp"
    if dcutls.localfs:file_exists( dc_pp ) then		

        local project_path = self.dalclick.root_project_path.."/"..self.settings.regnum 

        local dcpp_command = 
            dc_pp
            .." 'project="..project_path.."'"
            .." 'even="..   project_path.."/"..self.dalclick.proc_name.."/"..self.dalclick.even_name.."'"
            .." 'odd="..    project_path.."/"..self.dalclick.proc_name.."/"..self.dalclick.odd_name.."'"
            .." 'all="..    project_path.."/"..self.dalclick.proc_name.."/"..self.dalclick.all_name.."'"
            .." 'done="..   project_path.."/"..self.dalclick.doc_name .."'"
            .." 'output_name=".. self.dalclick.doc_filename.."'"
            .." 'title="..self.settings.title.."'"

         -- print( ppcommand )
         local exit_status = os.execute(dcpp_command)

         print()
         print(" script exit status: "..tostring(exit_status))
         return true
     else
        print(" ERROR: La ruta al script de post-procesamiento no esta correctamente configurada:")
        print(dc_pp)
        return false
     end
end

function project:show_capts(previews, filenames, counter_max, mode)

    if type(counter_max) ~= 'table' then
        if mode == "with_guest_counter" then
            print()
            print(" Todavía no hay capturas en este proyecto")
            print()
            sys.sleep(2000)
            return false
        else
            counter_max = {}
        end
    end
    
    local max = counter_max.odd
    local local_counter = self.state.counter
    
    if type(filenames) ~= 'table' or type(previews) ~= 'table' then
        if local_counter.odd > counter_max.odd then
            local status
            status, previews, filenames, local_counter = self:guest_counter_and_make_preview('prev', max, local_counter)
        else
            local status
            status, previews, filenames, local_counter = self:guest_counter_and_make_preview('idle', max, local_counter)
        end
    end
        
    if type(previews) ~= 'table' then
        return false
    end
    if not previews.odd or not previews.even then
        return false
    end

    require("imlua")
    require("cdlua")
    require("cdluaim")
    require("iuplua")
    require("iupluacd")
    require("iupluaimglib")

    local left = {}
    local right = {}


    
    local function shift_images(stat, action, previews, filenames)
       if stat then
           left.image = im.FileImageLoad( previews.even ); left.cnv:action()
           right.image = im.FileImageLoad( previews.odd ); right.cnv:action()
           left.label.title = filenames.even
           right.label.title = filenames.odd
           -- gbtn_go.tip = "Go to "..filenames.even.." | "..filenames.odd
       end
    end
           
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

    -------
    
    left.label = iup.label{
        title = filenames.even --, expand = "HORIZONTAL", padding = "10x5"
    }
    
    right.label = iup.label{
        title = filenames.odd --, expand = "HORIZONTAL", padding = "10x5"
    }
    
    -- 'with_counter' mode buttons
    local btn_previous = iup.button{
        image = "IUP_ArrowLeft", 
        flat = "Yes", 
        action = function() local stat, previews, filenames = self:alter_counter_and_make_preview('prev', max); shift_images(stat, 'prev', previews, filenames) end, 
        canfocus="No", 
        tip = "Previous",
        padding = '5x5'
    }
        
    local btn_next = iup.button{
        image = "IUP_ArrowRight", 
        flat = "Yes", 
        action = function() local stat, previews, filenames = self:alter_counter_and_make_preview('next', max); shift_images(stat, 'next', previews, filenames) end,
        canfocus="No", 
        tip = "Next",
        padding = '5x5'
    }   

    -- with 'guest' counter mode (contador "interno" solo actualiza state.counter al hacer click en return)

    local gbtn_previous = iup.button {
        image = "IUP_ArrowLeft", 
        flat = "Yes", 
        action = function() local stat, previews, filenames, new_counter = self:guest_counter_and_make_preview('prev', max, local_counter); local_counter = new_counter; shift_images(stat, 'prev', previews, filenames) end,
        canfocus="No", 
        tip = "Previous",
        padding = '5x5'
    }
        
    local gbtn_next = iup.button{
        image = "IUP_ArrowRight", 
        flat = "Yes", 
        action = function() local stat, previews, filenames, new_counter = self:guest_counter_and_make_preview('next', max, local_counter); local_counter = new_counter; shift_images(stat, 'next', previews, filenames) end,  
        canfocus="No", 
        tip = "Next",
        padding = '5x5'
    }
    
    local gbtn_go = iup.button{
        title = "Go",
        flat = "No", 
        padding = "15x2",
        action = function()  end,  
        canfocus="No", 
        tip = "",
    }

    local gbtn_cancel = iup.button{
        title = "Cancel",
        flat = "No", 
        padding = "15x2",
        canfocus="No", 
        tip = "Cancel",
    }
    

    -------

    local viewers = iup.hbox{ 
        left.cnv,
        right.cnv 
    }

    local labelbar = iup.hbox{ 
        left.label, 
        iup.fill {
            expand="HORIZONTAL"
        },
        right.label,
        -- margin = "10x10",
        -- gap = 2,
    }

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
        gbtn_go,
        gbtn_cancel,
    }
    
    local bottombar_guest = iup.hbox{
        gbtn_previous, 
        iup.fill {
            expand="HORIZONTAL"
        },
        gcenter_buttons,
        iup.fill {
            expand="HORIZONTAL"
        },
        gbtn_next,
        margin = "10x10",
        gap = 2,
    }

    -- -- -- --
    
    local dlg    
    if mode == "with_counter" then
        dlg = iup.dialog{
            iup.vbox{
                viewers,
                labelbar,
                bottombar
            },
            title="DALclick",
            margin="5x5",
            gap=10
        }
    elseif mode == "with_guest_counter" then
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
        right.image:Destroy()
        right.cnv.canvas:Kill()
        left.image:Destroy()
        left.cnv.canvas:Kill()
        iup.ExitLoop() -- should be removed if used inside a bigger application
        dlg:destroy()
    end
    
    local function set_counter()
        self.state.counter = local_counter
        self:save_state()
        print(" Se actualizó el contador a: "..tostring(self.state.counter.even).."|"..tostring(self.state.counter.odd))
    end
    
    function gbtn_go:action() 
        set_counter()
        destroy_dialog()
        return iup.IGNORE -- because we destroy the dialog
    end

    function gbtn_cancel:action()
        destroy_dialog()
        return iup.IGNORE -- because we destroy the dialog
    end
    
    function dlg:close_cb() -- si se cierra desde la ventana
        destroy_dialog()
        return iup.IGNORE -- because we destroy the dialog
    end

    dlg:show()
    iup.MainLoop()
    --iup.Close()
end

return project
