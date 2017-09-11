local cabildo = {}



function cabildo:test(proyecto,d)

print("-- 1 --")
    --print(p.session.regnum)
    --print(defaults.left_cam_id_filename)
print("-- 2 --")
    print(proyecto.session.regnum)
    print(d.left_cam_id_filename)

end

function cabildo:gui(p, cams) -- projec, cams

    print("cams en gui: "..type(cams))
    p.session.preview_counter = p.state.counter
    local status, previews, filenames = p:make_preview()

    local vcanv = {}
    local noc_mode = p.session.noc_mode

    local gbtn = {}
    local button_prev_init_active = "YES"
    local button_next_init_active = "YES"
    
    if next(p.session.counter_max) == nil then
        -- no hay capturas
        return false
    end

    local ids, idref
    if noc_mode == 'odd-even' then
	    idref = 'odd'
        ids = {'even','odd'}
    else
	    idref = 'single'
        ids = {'single'}
    end  

    -- definir estado inicial
    if p.session.preview_counter[idref] > p.session.counter_max[idref] then
        p.session.preview_counter = p.session.counter_max
    end
    -- estado inicial botones prev/next
    if p.session.preview_counter[idref] == p.session.counter_max[idref] then
        button_next_init_active = "NO"
    end
    if p.session.preview_counter[idref] == p.session.counter_min[idref] then
        button_prev_init_active = "NO"
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
       obj.cnv = iup.canvas{rastersize = obj.image:Width().."x"..obj.image:Height(), border = "YES"}

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
        action = 
            function() 
                local counter_updated = p:preview_counter_prev( 0 )
                if counter_updated ~= false then
                    local status, previews, filenames = p:make_preview()
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
                   counter_updated = p:preview_counter_next( p.session.counter_max.odd )
                else
                   counter_updated = p:preview_counter_next( p.session.counter_max.single )
                end
                if counter_updated ~= false then
                    local status, previews, filenames = p:make_preview()
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
       for i, idname in ipairs(ids) do
          vcanv[idname].image = im.FileImageLoad( previews[idname] ); vcanv[idname].cnv:action()
          vcanv[idname].label.title = filenames[idname]
       -- gbtn_go.tip = "Go to "..filenames.even.." | "..filenames.odd
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

    -- print("DEBUG: odd "..tostring(p.session.preview_counter.odd)..".."..tostring(p.session.counter_max.odd))
    -- print("DEBUG: even "..tostring(p.session.preview_counter.even)..".."..tostring(p.session.counter_max.even))

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


    local function destroy_dialog() 
        -- print(" cerrando  ...")
       for i, obj in pairs(vcanv) do
           obj.image:Destroy()
		   obj.cnv.canvas:Kill()
       end
       iup.ExitLoop() -- should be removed if used inside a bigger application
       dlg:destroy()
    end
    
    local function set_counter()
        p.state.counter = p.session.preview_counter
        p:save_state()
        if noc_mode == 'odd-even' then
           print(" Se actualizó el contador a: "..tostring(p.state.counter.even).."|"..tostring(p.state.counter.odd))
        else
           print(" Se actualizó el contador a: "..tostring(p.state.counter.single))
        end
    end
    
    function gbtn.gbtn_go:action() 
        set_counter()
        destroy_dialog()
        return iup.IGNORE -- because we destroy the dialog
    end

    function gbtn.gbtn_from:action()
        local param = {}
        param.local_paths = {}
		for i, idname in pairs(ids) do
			local file_name_we = string.format("%04d", p.state.counter[idname])
			-- param.control_paths[idname].remote_path = -- del saved files anterior o nada
            param.local_paths[idname] = {}
			param.local_paths[idname].dest_dir = p.session.base_path.."/"..p.paths.raw[idname].."/"
			param.local_paths[idname].dest_tmp_dir = p.session.base_path.."/"..p.paths.raw[idname].."/"..p.dalclick.tempfolder_name.."/"
			param.local_paths[idname].dest_filemame = file_name_we..".".."jpg"
			param.local_paths[idname].basename_without_ext = file_name_we
		end 
        cabildo:gui_shoot(cams, param)
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

function cabildo:gui_shoot(cams,param)
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
    elseif shoot_result.status == 0 then
        -- move from temporal folder to permanent raw folder and update project state
        for idname, paths in pairs(shoot_result.successful) do
            local tmppath = paths.basepath..paths.basename
            local permpath = param.local_paths[idname].dest_dir..paths.basename
            
            if os.rename(tmppath, permpath) then
                print(" ["..idname.."] moviendo '"..tostring(paths.basename).."' desde carpeta temporal..OK")
            else
                print(" ERROR: no se pudo mover '"..tostring(tmppath).."' a '"..tostring(permpath).."'")
            end
        end
    end
    gaugeProgress.value = 1.0; pbdlg.title = "listo"
    iup.LoopStep()
    sys.sleep(100)
	-- distinguish canceled from finished by inspecting the flag
	print("canceled:", flags.cancelflag)
       --iup.ExitLoop() -- should be removed if used inside a bigger application
    pbdlg:destroy()
    return shoot_result
end

return cabildo
