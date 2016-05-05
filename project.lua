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
	--
	self.state.counter = nil -- *siguiente* captura a la ultima realizada
    self.state.zoom_pos = nil
    self.state.saved_files = nil -- last capture paths
    -- self.state.focus = nil -- ojo puede no ser igual para las dos cams
    -- self.state.resolution = nil
	return true
end

function project:is_broken()
	local settings_path
	if dcutls.localfs:file_exists(self.dalclick.dc_config_path.."/runnig_project") then
		settings_path = dcutls.localfs:read_file(self.dalclick.dc_config_path.."/runnig_project")
		-- local settings_path = util.unserialize(content)
		if dcutls.localfs:file_exists(settings_path) then
			return settings_path
		else
			-- archivo running_project corrupto, no existe el proyecto
			print(" El proyecto referenciado en "..self.dalclick.dc_config_path.."/runnig_project".." no existe.")
			print(" Eliminando "..self.dalclick.dc_config_path.."/runnig_project")
			dcutls.localfs:delete_file(self.dalclick.dc_config_path.."/runnig_project")
			return false
		end
	else
		return false
	end
end

function project:clear()
	-- clear existing project
	if dcutls.localfs:delete_file(self.dalclick.dc_config_path.."/runnig_project") then
        return true	
	else
		print("no se pudo eliminar: "..self.dalclick.dc_config_path.."/runnig_project")
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
	-- IupFileDlg Example in IupLua 
	-- Shows a typical file-saving dialog. 
	local regnum_dir
	require( "iuplua" )

	-- Creates a file dialog and sets its type, title, filter and filter info
	filedlg = iup.filedlg{dialogtype = "DIR", title = "Seleccionar carpeta de proyecto", 
		                  directory=self.dalclick.root_project_path}

	-- Shows file dialog in the center of the screen
	filedlg:popup (iup.ANYWHERE, iup.ANYWHERE)

	-- Gets file dialog status
	status = filedlg.status

	if status == "0" then 
	  print (" Carpeta seleccionada: ", filedlg.value)
	  regnum_dir = filedlg.value
	elseif status == "-1" then 
	  print(" Operación cancelada")
	  return false
	else
	  print(" error")
	  return false
	end


	if self:load(regnum_dir.."/.dc_settings") then
		return true
	else
		print(" error: no se pudieron cargar preferencias desde: "..regnum_dir.."/.dc_settings")
		return false
	end
end

function project:create()

    guisys.init()

	local regnum = "" -- default
	local title = "" -- default
	local format = "Iniciar Proyecto\nNúmero de registro: %100.30%s\nTítulo:%300.30%s\n"
	repeat
		self.settings.regnum, self.settings.title = iup.Scanf(format, regnum, title)
	   if self.settings.regnum == "" then 
			iup.Message("Iniciar Proyecto", "El campo 'Número de registro' es obligatorio para iniciar un proyecto")
		else
			if string.match(self.settings.regnum, "^[%w-_]+$") then
				break
			else
				iup.Message("Iniciar Proyecto", "El campo 'Número de registro' solo permite caracteres alfanuméricos y guiones, no admite espacios, acentos u otros signos")
			end
		end
	until false

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
	    if self.mkdir_tree(self.dalclick, self.settings) then
			-- create settings file
			if dcutls.localfs:create_file(settings_path, content) then
				-- create runnig_project 
				if dcutls.localfs:create_file(self.dalclick.dc_config_path.."/runnig_project",settings_path) then
		        	return true -- status and counter
				end
			end
		end
		return false
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
    -- path = {}, basepath = {}, basename = {},	idname = {},
	local previews = {}
	local rotate = {}
	rotate.odd = "90"
	rotate.even = "-90"
	rotate.all = "-90" --TODO usar valores de config

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
	local sarasa = {
		image = {},
		cnv = {},
	}
	local cosas = {}
	local i = 1
	for idname, preview_path in pairs( previews ) do
		local image = im.FileImageLoad( preview_path ) -- directly load the image at index 0. it will open and close the file
		local cnv = iup.canvas{rastersize = image:Width().."x"..image:Height(), border = "YES"}
		cnv.image = image -- store the new image in the IUP canvas as an attribute
		--
		function cnv:map_cb()       -- the CD canvas can only be created when the IUP canvas is mapped
		  self.canvas = cd.CreateCanvas(cd.IUP, self)
		end

		function cnv:action()          -- called everytime the IUP canvas needs to be repainted
		  self.canvas:Activate()
		  self.canvas:Clear()
		  self.image:cdCanvasPutImageRect(self.canvas, 0, 0, 0, 0, 0, 0, 0, 0) -- use default values
		end
		cosas[i] = { cnv = cnv, image = image }
		i = i + 1
	end

--[[
	local function fl4()
		image = im.FileImageLoad("/opt/src/samples_imlua5/lena.jpg")
		cnv.image = image
		iup.Update(cnv)
	end

	local function fl3()
		image = im.FileImageLoad("/opt/src/samples_imlua5/flower3.jpg")
		cnv.image = image
		iup.Update(cnv)
	end

	local function fl2()
		image = im.FileImageLoad("/opt/src/samples_imlua5/flower2.jpg")
		cnv.image = image
		iup.Update(cnv)
	end
]]

--[[
	local buts = iup.hbox{
	  iup.button{title="First", image="IUP_MediaGotoBegin", action=function(self) fl3() end}, 
	  iup.button{title="Previous", image="IUP_MediaRewind", action=function(self) fl2() end}, 
	  iup.button{title="Pause", image="IUP_MediaPause", action=function(self) fl4() end}, 
	  iup.button{title="Next", image="IUP_MediaForward", action=function(self) end}, 
	  iup.button{title="Last", image="IUP_MediaGoToEnd", action=function(self) end}, 
	  }
]]
	local imgs = iup.hbox{ cosas[2].cnv, cosas[1].cnv }

	-- dlg = iup.dialog{cnv}
	-- local dlg = iup.dialog{iup.vbox{imgs, buts},title="DALclick", margin="5x5", gap=10}
	local dlg = iup.dialog{iup.vbox{imgs},title="DALclick", margin="5x5", gap=10}


	function dlg:close_cb()
		for i, cosa in ipairs( cosas ) do
			cosa.image:Destroy()
			cosa.cnv.canvas:Kill()
		end
		self:destroy()
		return iup.IGNORE -- because we destroy the dialog
	end

	dlg:show()
	iup.MainLoop()
end

return project
