local cabildo = {}



function cabildo:test(d)

print("-- 1 --")
    --print(current_project.session.regnum)
    --print(defaults.left_cam_id_filename)
print("-- 2 --")
    print(proyecto.session.regnum)
    print(d.left_cam_id_filename)

end

function cabildo:gui(cams) -- projec, cams

    local noc_mode = current_project.session.noc_mode
    local ids, idref
    if noc_mode == 'odd-even' then
	    idref = 'odd'
       ids = {'even','odd'}
    else
	    idref = 'single'
       ids = {'single'}
    end
    local previews, filenames = self:make_preview(ids)
    local vcanv = {}
    local gbtn = {}
    local current_cnv_size = {}
    local prev_cnv_size = {}
    local button_prev_init_active = "YES"
    local button_next_init_active = "YES"
    local button_shoot_init_active= "YES"

    local max_min_status = current_project:get_counter_max_min()
    if max_min_status == true then
       -- definir estado inicial
       if current_project.state.counter[idref] > current_project.session.counter_max[idref] then
           current_project.state.counter = current_project.session.counter_max
       end
       -- estado inicial botones prev/next
       if current_project.state.counter[idref] == current_project.session.counter_max[idref] then
           button_next_init_active = "NO"
       end
       if current_project.state.counter[idref] < current_project.session.counter_max[idref] then
           button_shoot_init_active= "NO"
       end
       if current_project.state.counter[idref] == current_project.session.counter_min[idref] then
           button_prev_init_active = "NO"
       end
    elseif max_min_status == nil then
           button_prev_init_active = "NO"
           button_next_init_active = "NO"
    else 
      -- error
        print("error: max_min_status == '"..tostring(max_min_status).."'")
        return false
    end

    require("imlua")
    require("cdlua")
    require("cdluaim")
    require("iuplua")
    require("iupluacd")
    require("iupluaimglib")

    -- crear tablas segun la cantidad de previews
    for i, idname in ipairs(ids) do
       vcanv[idname] = {}
    end

    for idname, obj in pairs(vcanv) do
       obj.image = im.FileImageLoad( previews[idname] )
       current_cnv_size[idname] = obj.image:Width().."x"..obj.image:Height()
       obj.cnv = iup.canvas{rastersize = current_cnv_size[idname], border = "YES"}

       obj.label = iup.label{
           title = filenames[idname] --, expand = "HORIZONTAL", padding = "10x5"
       }

       function obj.cnv:map_cb()       -- the CD canvas can only be created when the IUP canvas is mapped
           self.canvas = cd.CreateCanvas(cd.IUP, self)
       end
       function obj.cnv:action()          -- called everytime the IUP canvas needs to be repainted
         self.canvas:Activate()
         self.canvas:Clear()
         obj.image:cdCanvasPutImageRect(self.canvas, 0, 0, 0, 0, 0, 0, 0, 0) -- use default values
       end
    end
    -- left.cnv:action(); right.cnv:action()
    -------
       
    gbtn.gbtn_prev = iup.button {
        image = "IUP_ArrowLeft", 
        flat = "Yes", 
        action = function() end,
        canfocus="No", 
        tip = "Previous",
        padding = '5x5',
        active = button_prev_init_active
    }
        
    gbtn.gbtn_next = iup.button{
        image = "IUP_ArrowRight", 
        flat = "Yes", 
        action = function() end,  
        canfocus="No", 
        tip = "Next",
        padding = '5x5',
        active = button_next_init_active
    }
    
    -- gbtn.gbtn_go = iup.button{
    --     title = "Ir",
    --     flat = "No", 
    --     padding = "15x2",
    --     action = function()  end,  
    --     canfocus="No", 
    --     tip = "",
    -- }

    -- gbtn.gbtn_cancel = iup.button{
    --     title = "Cancelar",
    --     flat = "No", 
    --     padding = "15x2",
    --     canfocus="No", 
    --     tip = "Cancelar",
    --}
    
    gbtn.gbtn_shoot = iup.button {
        image = "IUP_MediaRecord",
        flat = "No", 
        padding = "15x2",
        canfocus="No",
        padding = '5x5',
        tip = "Capturar",
        active = button_shoot_init_active
    }
    
    gbtn.gbtn_shoot_overw = iup.button {
        image = "IUP_NavigateRefresh",
        flat = "No", 
        padding = "15x2",
        canfocus="No", 
        padding = '5x5',
        tip = "Capturar sobreescribiendo",
    }
    
    -- print("DEBUG: odd "..tostring(p.state.counter.odd)..".."..tostring(p.session.counter_max.odd))
    -- print("DEBUG: even "..tostring(p.state.counter.even)..".."..tostring(p.session.counter_max.even))

    -------
    local viewers, labelbar
    if noc_mode == 'odd-even' then
       viewers = iup.hbox{ 
           vcanv.even.cnv,
           vcanv.odd.cnv 
       }

       labelbar = iup.hbox{ 
           vcanv.even.label, 
           iup.fill {
               expand="HORIZONTAL"
           },
           vcanv.odd.label,
           -- margin = "10x10",
           -- gap = 2,
       }
    else
       viewers = iup.hbox{ 
           vcanv.single.cnv
       }

       labelbar = iup.hbox{ 
           vcanv.single.label
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
        -- gbtn.gbtn_go,
        -- gbtn.gbtn_cancel,
        -- iup.label{separator="VERTICAL"},
        gbtn.gbtn_shoot,
        gbtn.gbtn_shoot_overw,
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

    local function set_counter()
        -- como no usamos mas preview_counter es ineecesario
    end

    local function go_prev(ids)
       local counter_updated, counter_status = current_project:counter_prev( 0 )
       if counter_updated then
           local previews, filenames = cabildo:make_preview(ids)
           gbtn:gbtn_action_callback(counter_status, previews, filenames) 
       end
    end

    local function go_next(ids, idref) -- zzzz
       local counter_updated, counter_status = current_project:counter_next( current_project.session.counter_max[idref] )

       if counter_updated then
           local previews, filenames = cabildo:make_preview(ids)
           gbtn:gbtn_action_callback(counter_status, previews, filenames) 
       end
    end

    local function shoot(shootmode)

      -- cuando existe img en raw pero no en pre preguntar si generarla on the fly mientras se navega con prev/next
      if shootmode == nil then print("error: 'shootmode == nil'"); return false; end
      if type(cams) == 'table' and next(cams) then
         --continue
         print("·cams ="..tostring(cams))
      else 
         return false 
      end

      local ok_to_shoot = false
      local back_counter_if_fail = false
      if shootmode == 'normal' then
         if current_project.session.counter_max then
            if current_project.state.counter[idref] == current_project.session.counter_max[idref] then
               if current_project:counter_next() then
                  ok_to_shoot = true
                  back_counter_if_fail = true
               end
            end
         else
            -- primera captura, no avanzar el contador
            ok_to_shoot = true
            back_counter_if_fail = false
         end
      elseif shootmode == 'overwrite' then
         ok_to_shoot = true
         back_counter_if_fail = false
      end

      if ok_to_shoot then
         local param = {}
         build_param_fail = false
         param.device = {}
         param.rotate_angle = {}
         param.prefilter = current_project.settings.prefilters
         if current_project.settings.mode == 'secure' then param.delay = 8
         if current_project.settings.mode == 'normal' then param.delay = 4
         if current_project.settings.mode == 'fast' then param.delay = 2
         for i, idname in pairs(ids) do
            local file_name_we = string.format("%04d", current_project.state.counter[idname])
            -- param.control_paths[idname].remote_path = -- del saved files anterior o nada
            param.device[idname] = {}
            param.device[idname].dest_dir = current_project.session.base_path.."/"..current_project.paths.raw[idname].."/"
            param.device[idname].dest_preproc_dir = current_project.session.base_path.."/"..current_project.paths.pre[idname].."/"
            param.device[idname].dest_tmp_dir = current_project.session.base_path.."/"..current_project.paths.raw[idname].."/"..current_project.dalclick.tempfolder_name.."/"
            if not dcutls.localfs:file_exists( param.device[idname].dest_tmp_dir ) then
               if not dcutls.localfs:create_folder( param.device[idname].dest_tmp_dir ) then
                  build_param_fail = true
               end
            end
            param.device[idname].dest_filemame = file_name_we..".".."jpg"
            param.device[idname].basename_without_ext = file_name_we
            param.device[idname].thumbpath_dir = current_project.session.base_path.."/"..current_project.paths.pre[idname].."/"..current_project.dalclick.thumbfolder_name.."/"
            if not dcutls.localfs:file_exists( param.device[idname].thumbpath_dir ) then
               if not dcutls.localfs:create_folder( param.device[idname].thumbpath_dir ) then
                  build_param_fail = true
               end
            end
            param.device[idname].rotate_angle = current_project.state.rotate[idname]

            param.rotate = current_project.settings.rotate
            -- param.thumbnail_scale = ( current_project.settings.rotate and "0.125" or "0.167")
         end
         if (not build_param_fail) and cabildo:gui_shoot_download_and_preproc(cams, param) then
            current_project.session.counter_max = current_project.state.counter
            local previews, filenames = cabildo:make_preview(ids)
            gbtn:gbtn_action_callback('last', previews, filenames) 
         else
            -- no hubo exito
            if back_counter_if_fail == true then
               current_project:counter_prev()
            end
         end
      end
    end

    -- -- -- --
    
    local dlg    

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

    function dlg:k_any(c)
       if (c == iup.K_CR) then
          shoot('normal')
       elseif (c == iup.K_plus) then
	      shoot('overwrite')
       elseif (c == iup.K_RIGHT) then
	      go_next(ids, idref)
       elseif (c == iup.K_LEFT) then
          go_prev(ids)
       end
    end
-- Keyboard Codes https://webserver2.tecgraf.puc-rio.br/iup/en/attrib/key.html
-- Defining Hot Keys http://webserver2.tecgraf.puc-rio.br/iup/en/tutorial/tutorial3.html#Hot_Keys

    local function update_dlg_size()
       --iup.RefreshChildren(dlg)
       local update = false
       for i, idname in ipairs(ids) do
          if current_cnv_size[idname] ~= prev_cnv_size[idname] then
             update = true; -- print("update size! "..prev_cnv_size[idname].." -> "..current_cnv_size[idname])
          end
       end
       if update then
          iup.SetAttribute(dlg, "SIZE", NULL) --  if the new size is NULL the dialog will be resized to the Natural size that include all the elements.
          iup.Refresh(dlg)
       end
    end

    local function destroy_dialog() 
        -- print(" cerrando  ...")
       for i, obj in pairs(vcanv) do
           obj.image:Destroy()
           obj.cnv.canvas:Kill()
       end
       iup.ExitLoop() -- should be removed if used inside a bigger application
       dlg:destroy()
    end
    

    -- function gbtn.gbtn_go:action() 
    --    set_counter()
    --    destroy_dialog()
    --    return iup.IGNORE -- because we destroy the dialog
    -- end

    function gbtn.gbtn_shoot:action()
       shoot('normal')
    end

    function gbtn.gbtn_shoot_overw:action()
       shoot('overwrite')
    end

    function gbtn.gbtn_next:action()
       go_next(ids, idref)
    end

    function gbtn.gbtn_prev:action()
        go_prev(ids)
    end


    -- function gbtn.gbtn_cancel:action()
    --    destroy_dialog()
    --    return iup.IGNORE -- because we destroy the dialog
    -- end

    function gbtn:gbtn_action_callback(counter_status, previews, filenames)
       for i, idname in ipairs(ids) do
          vcanv[idname].image = im.FileImageLoad( previews[idname] )
          prev_cnv_size[idname] = current_cnv_size[idname]
          current_cnv_size[idname] = vcanv[idname].image:Width().."x"..vcanv[idname].image:Height()
          vcanv[idname].cnv.rastersize = current_cnv_size[idname]
          vcanv[idname].cnv:action()
          vcanv[idname].label.title = filenames[idname]
       -- gbtn_go.tip = "Go to "..filenames.even.." | "..filenames.odd
       end
       
       if counter_status == "last" then
           gbtn.gbtn_next.active = "NO"
           gbtn.gbtn_prev.active = "YES"
           gbtn.gbtn_shoot.active = "YES"
       elseif counter_status == "first" then
           gbtn.gbtn_prev.active = "NO"
           gbtn.gbtn_next.active = "YES"
           gbtn.gbtn_shoot.active = "NO"
       else -- 'within_range'
           gbtn.gbtn_next.active = "YES"
           gbtn.gbtn_prev.active = "YES"
           gbtn.gbtn_shoot.active = "NO"
       end
       update_dlg_size()
    end
    function dlg:close_cb() -- si se cierra desde la ventana
        destroy_dialog()
        return iup.IGNORE -- because we destroy the dialog
    end

    --

    dlg:show()
    iup.MainLoop()
    --iup.Close()
end


function cabildo:make_preview(ids)

    -- param = { [idname] => num, ..}
    local previews = {}
    local filenames = {}
    for n, idname in pairs(ids) do
       local filename_we
       filename_we = string.format("%04d", current_project.state.counter[idname])..".jpg"
       previews[idname] = current_project:get_thumb_path(idname, filename_we)
       filenames[idname] = filename_we
    end
    return previews, filenames
end

function cabildo:gui_shoot_download_and_preproc(cams,param)
	--require "iuplua"

   local dc_multicam = require('dc_multicam')

	local flags = {}
	local gaugeProgress

	local function StartProgressBar()
		cancelbutton = iup.button {
		    title = "Cancel",
		    action=function()
		        flags.cancelflag = true
		        --return iup.CLOSE
		    end
		}
		gaugeProgress = iup.progressbar{ expand="HORIZONTAL" }
		dlgProgress = iup.dialog{
		    title = "Capturando imagen",
		    dialogframe = "YES", border = "YES",
		    iup.vbox {
		        gaugeProgress,
		        cancelbutton,
			}
		}
		dlgProgress.size = "QUARTERxEIGHTH"
		dlgProgress.menubox = "NO"  --  Remove Windows close button and menu.
		dlgProgress.close_cb = cancelbutton.action
		dlgProgress:showxy(iup.CENTER, iup.CENTER)  --  Put up Progress Display
		return dlgProgress
	end


	pbdlg = StartProgressBar()
	gaugeProgress.value = 0.0

   shoot_result = dc_multicam:shoot_and_download_all(gaugeProgress, flags, cams, param, pbdlg)
   print('status: '..tostring(shoot_result.status))

   gaugeProgress.value = 0.9; pbdlg.title = "moviendo archivos"
   iup.LoopStep()

   local shoot_fail = false
   local command_fail = false
   if shoot_result.status == 7 then
      -- remove captures from temporal folder if any
      if type(result.successful) == 'table' and next(result.successful) then
        for idname, paths in pairs(result.successful) do
           if type(paths) == 'table' then
              local tmppath = paths.basepath..paths.basename
              if dcutls.localfs:delete_file(tmppath) then
                 print(" eliminando descarga carpeta temporal..OK")
              else
                 print(" ATENCION: no se pudo eliminar '"..tostring(tmppath).."'")
              end
           end
        end
     end
     shoot_fail = true
   elseif shoot_result.status == 0 then

      for idname, paths in pairs(shoot_result.successful) do
         -- move from temporal folder to permanent raw folder and update project state
         command_fail = false
         pbdlg.title = "moviendo archivos ["..paths.basename.."]"
         iup.LoopStep()
         local tmppath = paths.basepath..paths.basename
         local permpath = param.device[idname].dest_dir..paths.basename
         
         if os.rename(tmppath, permpath) then
             print(" ["..idname.."] moviendo '"..tostring(paths.basename).."' desde carpeta temporal..OK")
         else
             print(" ERROR: no se pudo mover '"..tostring(tmppath).."' a '"..tostring(permpath).."'")
             command_fail = true
         end
         if not command_fail then
            -- generate thmbnail and rotate
            local portrait = false
            if param.rotate then
               if tonumber(param.device[idname].rotate_angle) == 180 or tonumber(param.device[idname].rotate_angle) == 0 then
                  portrait = false
               else
                  portrait = true
               end
            else
                  portrait = false
            end
            pbdlg.title = "generando thumbnails ["..paths.basename.."]"
            iup.LoopStep()
            command_fail = false
            local prefilters_param = ""
            for prefilter, value in pairs( param.prefilters ) do
                prefilters_param = prefilters_param .. " --" .. prefilter .. " " .. value[idname]
            end
            local command = 
               "econvert -i "..param.device[idname].dest_dir..param.device[idname].dest_filemame
             ..( param.rotate and " --rotate "..param.device[idname].rotate_angle or "")
             .." -o "..param.device[idname].dest_preproc_dir..param.device[idname].dest_filemame
             .." --thumbnail "..( portrait and "0.125" or "0.167")
             .." -o "..param.device[idname].thumbpath_dir.."/"..param.device[idname].dest_filemame
             .." > /dev/null 2>&1"
            printf(" ["..idname.."] "..(param.prefilters and "prefiltro / " or "")..(param.rotate and "rotado / " or "").."vista previa ("..param.device[idname].dest_filemame..")...") 
            if not os.execute(command) then
               print("ERROR")
               print("    falló: '"..command.."'")
               command_fail = true
            else
               print("OK")
            end
         end
      end
   else
      shoot_fail = true
   end
   gaugeProgress.value = 1.0; pbdlg.title = "listo"
   iup.LoopStep()
   sys.sleep(100)
   -- distinguish canceled from finished by inspecting the flag
   print("canceled:", flags.cancelflag)
    --iup.ExitLoop() -- should be removed if used insgaugeProgress.value = 1.0; pbdlg.title = "listo"ide a bigger application
   pbdlg:destroy()
   if command_fail or shoot_fail then
      return false
   else
      return true
   end
end

return cabildo
