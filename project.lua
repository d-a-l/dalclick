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
    self.settings.title = nil
    self.settings.out_img_format = 'dng'
    self.settings.ref_cam = "even"
    self.settings.rotate = true
    self.settings.mode = 'secure'
    self.settings.thumbfolder_name = self.dalclick.thumbfolder_name
    --
    self.state.counter = nil -- *siguiente* captura a la ultima realizada
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

function project:is_broken()
    local settings_path
    if dcutls.localfs:file_exists(self.dalclick.dc_config_path.."/running_project") then
        settings_path = dcutls.localfs:read_file(self.dalclick.dc_config_path.."/running_project")
        -- local settings_path = util.unserialize(content)
        if dcutls.localfs:file_exists(settings_path) then
            return settings_path
        else
            -- archivo running_project corrupto, no existe el proyecto
            print(" El proyecto referenciado en "..self.dalclick.dc_config_path.."/running_project".." no existe.")
            print(" Eliminando "..self.dalclick.dc_config_path.."/running_project")
            dcutls.localfs:delete_file(self.dalclick.dc_config_path.."/running_project")
            return false
        end
    else
        return false
    end
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
        print(" '"..self.settings.regnum.."' guardado")
        return true    
    else
        print("no se pudo guardar la configuracion del proyecto actual en:  "..self.dalclick.root_project_path.."/"..self.settings.regnum.."/")
        return false
    end
end

function project:open()
    -- 
    require( "iuplua" )
    local regnum_dir, status, load_dir_error, a

    -- Creates a file dialog and sets its type, title, filter and filter info
    local od = iup.filedlg{ dialogtype = "DIR", 
                            title = "Seleccionar carpeta de proyecto", 
                            directory = self.dalclick.root_project_path
                            }

    -- Shows file dialog in the center of the screen
    od:popup (iup.ANYWHERE, iup.ANYWHERE)

    -- Gets file dialog status
    status = od.status

    -- Check status
    load_dir_error = true
    if status == "0" then 
      if type(od.value) ~= 'string' then
          -- nota: solo con Alarm se pudo corregir el problema de que no se podia cerrar filedlg
          iup.Alarm("Cargando proyecto", "Error: Hubo un problema al intentar cargar '"..tostring(od.value).."'" ,"Continuar")
      else
          if od.value == self.settings.regnum then
              iup.Alarm("Cargando proyecto", "El proyecto seleccionado es el proyecto abierto actualmente" ,"Continuar")
          else
              a = iup.Alarm("Cargando proyecto", "Carpeta seleccionada:\n"..od.value ,"OK", "Cancelar")
              if a == 1 then 
                  load_dir_error = false
                  regnum_dir = od.value
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
        return false
    end

    -- All ok, load project
    
    if dcutls.localfs:file_exists(regnum_dir.."/.dc_settings") then
        if self:load(regnum_dir.."/.dc_settings") then
            print(" [Abrir proyecto] Proyecto cargado con éxito desde '"..regnum_dir.."'." )
            -- guardar referencia al proyecto cargado como "running project"
            if self:update_running_project(regnum_dir.."/.dc_settings") then
                return true -- success!!
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


function project:create( regnum, title )

    self.settings.regnum = regnum
    self.settings.title = title
    
    print(" Se está creando un nuevo proyecto:\n")
    print(" === "..self.settings.regnum.." ===")
    if self.settings.title ~= "" then print(" título: '"..self.settings.title.."'") end
    print()

    if self.settings.regnum then
        local settings_path = self.dalclick.root_project_path.."/"..self.settings.regnum.."/.dc_settings"

        self.settings.path_raw.odd = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.raw_name.."/"..self.dalclick.odd_name
        self.settings.path_raw.even = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.raw_name.."/"..self.dalclick.even_name
        self.settings.path_raw.all = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.raw_name.."/"..self.dalclick.all_name

        self.settings.path_proc.odd = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.proc_name.."/"..self.dalclick.odd_name
        self.settings.path_proc.even = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.proc_name.."/"..self.dalclick.even_name
        self.settings.path_proc.all = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.proc_name.."/"..self.dalclick.all_name

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
        -- create running_project 
        if self:update_running_project(settings_path) then
            return true -- success!!
        else
            print(" [Crear proyecto] Error: no se pudo actualizar la configuración interna de DALclick" )
            return false
        end
            
        -- if not dcutls.localfs:create_file(self.dalclick.dc_config_path.."/running_project",settings_path) then
        --    return false
        -- end
        return true
    else
        print("create_project_tree: no se ha recibido un número de registro válido!\n")
        return false
    end
end

function project:save_current_and_create_new_project(defaults)
    -- guarda el proyecto en curso y crea uno nuevo
    if not self:write() then
        print(" error: no se pudo guardar el proyecto actual.")
        return false
    end
    
    local regnum, title = self:get_project_newname()
    if regnum == nil then
        return nil
    end
    
    print(); print(" Creando proyecto nuevo..."); print()
    
    if not self:init(defaults) then
        print("No se pudo inicializar un proyecto")
        return false
    end
    if self:create(regnum, title) then
        -- if not self:update_running_project() then
        --    print(" error: no se pudo actualizar la configuración interna de DALclick")
        --    return false
        -- end
        return true
    else      
        print(" Error: No se pudo crear un nuevo proyecto.")
        return false

    end
end

function project:print_self_p()
    print("self.settings: "..tostring(self.settings))
    print("self.settings: "..util.serialize(self.settings))
end

function project:load(settings_path)

    if dcutls.localfs:file_exists(settings_path) then
        local content = dcutls.localfs:read_file(settings_path)
        if content then
            -- print("restore: "..content)
            self.settings = util.unserialize(content)
            print("\n Datos del proyecto cargado:\n")
            print(" = ID:     "..self.settings.regnum)
            if self.settings.title ~= "" then print(" = Título: '"..self.settings.title.."'") end
            print()
            if settings_path ~= self.dalclick.root_project_path.."/"..self.settings.regnum.."/.dc_settings" then
                print()
                print(" Atencion! el archivo de configuracion del proyecto podría estar corrupto")
                print("  "..settings_path)
                print("  "..self.dalclick.root_project_path.."/"..self.settings.regnum.."/.dc_settings")
                print()
            end
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
                print()
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
            else
                self.state = {} -- asegurarse que no queda cargado un estado de un proyecto anterior
                print(" ATENCION: no se ha podido cargar un estado del contador.")
                print(" El contador se reiniciará desde 0 cuando se inicialicen")
                print(" las cámaras, por favor verifique que no existan capturas")
                print(" previas, ya que serán sobreescritas.")
                print()
                print(" las capturas para este proyecto se guardan en:\n")
                print("  "..self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.raw_name)
                print()
                print(" Si existen capturas y no desea sobreescribirlas, puede ")
                print(" actualizar el estado del contador editando manualmente el")
                print(" siguiente archivo (luego de inicializar las camaras):\n")
                print("  "..self.dalclick.root_project_path.."/"..self.settings.regnum.."/.dc_state")
                print()
            end
            return true
        else
            return false
        end
    else
        print(" No existe un proyecto DALclick en la carpeta ingresada: "..settings_path)
        return false
    end
end

function project.mkdir_tree(g,s)

    if not dcutls.localfs:file_exists(g.root_project_path.."/"..s.regnum) then
        print(" Creando árbol de directorios del proyecto...\n")
        dcutls.localfs:create_folder( g.root_project_path.."/"..s.regnum)
        dcutls.localfs:create_folder( g.root_project_path.."/"..s.regnum.."/"..g.raw_name)
        dcutls.localfs:create_folder( g.root_project_path.."/"..s.regnum.."/"..g.proc_name)
        dcutls.localfs:create_folder( g.root_project_path.."/"..s.regnum.."/"..g.doc_name)
        dcutls.localfs:create_folder( s.path_raw.odd )
        dcutls.localfs:create_folder( s.path_raw.even )
        dcutls.localfs:create_folder( s.path_raw.all )
        dcutls.localfs:create_folder( s.path_proc.odd )
        dcutls.localfs:create_folder( s.path_proc.even )
        dcutls.localfs:create_folder( s.path_proc.all )
        return true
    else
        print("warn: '"..g.root_project_path.."/"..s.regnum.."' ya existe\n")
        return false
    end
end

function project:counter_next()
    local next_counter = {}
    for idname,count in pairs(self.state.counter) do
        count = count + 2 -- TODO we need count cameras!!!
        next_counter[idname] = count
    end
    self.state.counter = next_counter
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

function project:make_preview()
    -- TODO Quick and Dirty!!!
    -- path = {}, basepath = {}, basename = {},    idname = {},
    local previews = {}

    for idname, saved_file in pairs( self.state.saved_files ) do

        local proc_path = self.dalclick.root_project_path.."/"..self.settings.regnum.."/"..self.dalclick.proc_name.."/"..idname.."/"

        if not dcutls.localfs:file_exists( proc_path..".previews" ) then
            if dcutls.localfs:create_folder( proc_path..".previews" ) then
                print(" ["..idname.."] creado... "..proc_path..".previews")
            else
                return false
            end
        end

        local thumb_path = proc_path..".previews/"..saved_file.basename
        local big_path = proc_path..saved_file.basename
        print(" ["..idname.."] creando vista previa... "..thumb_path)

        if dcutls.localfs:file_exists( big_path ) then
            os.execute("econvert -i "..big_path.." --thumbnail ".."0.125".." -o "..thumb_path.." > /dev/null 2>&1")
            if not dcutls.localfs:file_exists( thumb_path ) then
                thumb_path = self.dalclick.empty_thumb_path_error
            end
        else
            thumb_path = self.dalclick.empty_thumb_path
        end
        previews[idname] = thumb_path
    end
    if next(previews) == nil then
        return false -- empty table 
    else
        return true, previews
    end
end

function project:show_capts(previews)
    -- TODO Quick and Dirty!!!
    if type(previews) ~= 'table' then
        return false
    end
    if not previews.odd or not previews.even then
        return false
    end

    require"imlua"
    require"cdlua"
    require"cdluaim"
    require"iuplua"
    require"iupluacd"

    local left = {}
    local right = {}
       
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

    local viewers = iup.hbox{ 
        left.cnv,
        right.cnv 
    }

    -- dlg = iup.dialog{cnv}
    -- local dlg = iup.dialog{iup.vbox{imgs, buts},title="DALclick", margin="5x5", gap=10}
    local dlg = iup.dialog{
        iup.vbox{
            viewers
        },
        title="DALclick",
        margin="5x5",
        gap=10
    }


    function dlg:close_cb()
        right.image:Destroy()
        right.cnv.canvas:Kill()
        left.image:Destroy()
        left.cnv.canvas:Kill()

        self:destroy()
        return iup.IGNORE -- because we destroy the dialog
    end

    dlg:show()
    iup.MainLoop()
end

return project
