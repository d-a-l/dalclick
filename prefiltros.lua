-- IupGetParam Example in IupLua
-- Shows a dialog with many possible fields.

local prefiltros = {}
-- 840x480
function prefiltros:refresh_econvert_preview(original_img_path, preview_img_path)
   if dcutls.localfs:file_exists(preview_img_path) then
      os.execute("rm "..preview_img_path)
   end
   local result = os.execute("cp "..original_img_path.." "..preview_img_path)
   return result
end

function prefiltros:econvert_create_preview( w, h, input, output)
   if dcutls.localfs:file_exists(input) then
      local image = im.FileImageLoad( input )
      local scale
      local w_margin, h_margin
      w_image = image:Width(); h_image = image:Height()
      image:Destroy()

      if h_image > w_image then
         scale = h / h_image
         if w_image * scale > w then
            scale = w / w_image
            h_margin = math.floor( (h - (h_image * scale)) / 2 )
            w_margin = 0
         else
            w_margin = math.floor( (w - (w_image * scale)) / 2 )
            h_margin = 0
         end
      else
         scale = w / w_image
         if h_image * scale > h then
            scale = h / h_image
            w_margin = math.floor( (w - (w_image * scale)) / 2 )
            h_margin = 0
         else
            h_margin = math.floor( (h - (h_image * scale)) / 2 )
            w_margin = 0
         end
      end
      print( w_margin, h_margin)
      scale = tostring(scale)
      econvert_val = scale:gsub(',','.')
      local command = "econvert -i ".. input .. " --scale "..econvert_val.." -o "..output
      print(command)
      local result = os.execute(command)
      -- if result then print("OK") end
      return result, w_margin, h_margin
   else
      return false
   end
end

function prefiltros:econvert_apply_contrast(val, input, output)
   if dcutls.localfs:file_exists(input) then
      local econvert_val = tostring( val / 100 )
      econvert_val = econvert_val:gsub(',','.')
      local command = "econvert -i ".. input .. " --contrast "..econvert_val.." -o "..output
      print(command)
      local result = os.execute(command)
      if result then print("OK") end
      return result
   end
end

function prefiltros:econvert_apply_gamma(val, input, output)

   if dcutls.localfs:file_exists(input) then
      local econvert_val = tostring( val / 100 )
      econvert_val = econvert_val:gsub(',','.')
      local command = "econvert -i ".. input .. " --gamma "..econvert_val.." -o "..output
      print(command)
      local result = os.execute(command)
      if result then print("OK") end
      return result
   end
end

function prefiltros:gui(data)

    require("imlua")
    require("cdlua")
    require("cdluaim")
    require("iuplua")
    require("iupluacontrols" )
    require("iupluacd")
    require("iupluaimglib")

    local single = {}
    local gbtn = {}

    local canvas_width =  800
    local canvas_height = 500

    -- default init vales
    local contrast = 0
    local gamma = 100
    local brightness = 0
    local crop_top = 0; local crop_bottom = 0
    local crop_left = 0; local crop_right = 0
    local hipass = 0
    local saturation = 0

    local input_img_path = "img/test.jpg"
    local tmp_orig_path = "/tmp/dalclick_prefilter_preview_orig.jpg"
    local tmp_test_path = "/tmp/dalclick_prefilter_preview_test.jpg"

    local result, w_margin, h_margin = self:econvert_create_preview( canvas_width, canvas_height, input_img_path, tmp_orig_path)
    if( not dcutls.localfs:file_exists(tmp_orig_path) or not result ) then
      return false, "No se pudo crear el archivo temporal '"..tmp_orig_path.."' para realizar la vista previa"
    end

    local result = self:refresh_econvert_preview(tmp_orig_path, tmp_test_path)
    if( not dcutls.localfs:file_exists(tmp_test_path) or not result ) then
       return false, "No se pudo crear el archivo temporal '"..tmp_test_path.."' para realizar la vista previa"
    end

    single.image = im.FileImageLoad( tmp_orig_path )
    -- single.cnv = iup.canvas{rastersize = single.image:Width().."x"..single.image:Height(), border = "YES"}
    single.cnv = iup.canvas{rastersize = canvas_width.."x"..canvas_height, border = "YES"}
    function single.cnv:map_cb()       -- the CD canvas can only be created when the IUP canvas is mapped
        self.canvas = cd.CreateCanvas(cd.IUP, self)
    end

    function single.cnv:action()          -- called everytime the IUP canvas needs to be repainted
      self.canvas:Activate()
      self.canvas:Clear()
      single.image:cdCanvasPutImageRect(self.canvas, w_margin, h_margin, 0, 0, 0, 0, 0, 0) -- use default values
    end

    local function reload_image_and_refresh_canvas( new_img_path )
       single.image = im.FileImageLoad( new_img_path )
       single.cnv.canvas:Activate()
       single.cnv.canvas:Clear()
       single.image:cdCanvasPutImageRect(single.cnv.canvas, w_margin, h_margin, 0, 0, 0, 0, 0, 0)
    end

    local function refresh_label( name )
       if name == "CONTRAST" then
          local value = tostring(contrast)
          if value == '0' then value = "-" end
          single.label_contrast.title = "<b>Contraste</b>: " .. value
       elseif name == "GAMMA" then
          local value = tostring(gamma)
          if value == '100' then value = "-" end
          single.label_gamma.title = "<b>Gamma</b>: " .. value
       elseif name == "BRIGHTNESS" then
          local value = tostring(brightness)
          if value == '0' then value = "-" end
          single.label_brightness.title = "<b>Brillo</b>: " .. value
       elseif name == "CROP" then
          local top = tostring(crop_top)
          local right = tostring(crop_right)
          local bottom = tostring(crop_bottom)
          local left = tostring(crop_left)
          single.label_crop.title = "<b>Recorte</b>: "
                                 .. top .. " " .. right .. " "
                                 .. bottom .. " " .. left
       elseif name == "HIPASS" then
          local value = tostring(hipass)
          if value == '0' then value = "-" end
          single.label_hipass.title = "<b>High Pass</b>: " .. value
       elseif name == "SATURATION" then
          local value = tostring(saturation)
          if value == '0' then value = "-" end
          single.label_saturation.title = "<b>Saturación</b>: " .. value
       end
    end

    single.label_contrast = iup.label{
        title = "", expand = "HORIZONTAL", markup = "YES" --, padding = "10x5"
    }
    single.label_gamma = iup.label{
        title = "", expand = "HORIZONTAL", markup = "YES" --, padding = "10x5"
    }
    single.label_brightness = iup.label{
        title = "", expand = "HORIZONTAL", markup = "YES" --, padding = "10x5"
    }
    single.label_crop = iup.label{
        title = "", expand = "HORIZONTAL", markup = "YES" --, padding = "10x5"
    }
    single.label_hipass = iup.label{
        title = "", expand = "HORIZONTAL", markup = "YES" --, padding = "10x5"
    }
    single.label_saturation = iup.label{
        title = "", expand = "HORIZONTAL", markup = "YES" --, padding = "10x5"
    }

    refresh_label( 'BRIGHTNESS' ); refresh_label( 'CROP' )
    refresh_label( 'CONTRAST' ); refresh_label( 'GAMMA' )
    refresh_label( 'HIPASS' ); refresh_label( 'SATURATION' )

    gbtn.gbtn_ok = iup.button{
        title = "Aplicar", flat = "No", padding = "15x2", canfocus="No", tip = "Aplicar",
    }
    gbtn.gbtn_cancel = iup.button{
        title = "Cancelar", flat = "No", padding = "15x2", canfocus="No", tip = "Cancelar",
    }
    gbtn.gbtn_preview = iup.button{
        title = "Vista previa combinada", flat = "No", padding = "15x2", canfocus="No", tip = "Vista previa combinada de todos lo filtros",
    }
    gbtn.gbtn_contrast = iup.button{
        title = "+",
        flat = "No",
        padding = "15x2",
        canfocus="No",
        tip = "Modificar contraste",
    }

    gbtn.gbtn_gamma = iup.button{
        title = "+",
        flat = "No",
        padding = "15x2",
        canfocus="No",
        tip = "Modificar gamma",
    }

    gbtn.gbtn_brightness = iup.button{
        title = "+",
        flat = "No",
        padding = "15x2",
        canfocus="No",
        tip = "Modificar brillo",
    }

    gbtn.gbtn_crop = iup.button{
        title = "+",
        flat = "No",
        padding = "15x2",
        canfocus="No",
        tip = "Modificar recorte",
    }

    gbtn.gbtn_hipass = iup.button{
        title = "+",
        flat = "No",
        padding = "15x2",
        canfocus="No",
        tip = "Modificar filtro high pass",
    }

    gbtn.gbtn_saturation = iup.button{
        title = "+",
        flat = "No",
        padding = "15x2",
        canfocus="No",
        tip = "Modificar saturación",
    }

    local viewers = iup.hbox{
       single.cnv
    }

    local labelbar_left = iup.vbox{
       iup.label{separator="HORIZONTAL"},
       iup.hbox{
          single.label_contrast,
          gbtn.gbtn_contrast,
          alignment="ACENTER" },
       iup.label{separator="HORIZONTAL"},
       iup.hbox{
          single.label_gamma,
          gbtn.gbtn_gamma,
          alignment="ACENTER" },
       iup.label{separator="HORIZONTAL"},
       margin="2x2", gap=2
    }

    local labelbar_center = iup.vbox{
       iup.label{separator="HORIZONTAL"},
       iup.hbox{
          single.label_hipass,
          gbtn.gbtn_hipass,
          alignment="ACENTER" },
       iup.label{separator="HORIZONTAL"},
       iup.hbox{
          single.label_saturation,
          gbtn.gbtn_saturation,
          alignment="ACENTER" },
       iup.label{separator="HORIZONTAL"},
       margin="2x2", gap=2
    }

    local labelbar_right = iup.vbox{
       iup.label{separator="HORIZONTAL"},
       iup.hbox{
          single.label_brightness,
          gbtn.gbtn_brightness,
          alignment="ACENTER" },
       iup.label{separator="HORIZONTAL"},
       iup.hbox{
          single.label_crop,
          gbtn.gbtn_crop,
          alignment="ACENTER" },
       iup.label{separator="HORIZONTAL"},
       margin="2x2", gap=2
    }

    local bottombar = iup.hbox{
	    iup.fill {
	        expand="HORIZONTAL"
	    },
       gbtn.gbtn_preview , gbtn.gbtn_cancel, gbtn.gbtn_ok,
	    margin = "10x10",
	    gap = 2,
    }

    local dlg = iup.dialog{
        iup.vbox{
            viewers,
            iup.hbox{ labelbar_left, labelbar_center, labelbar_right },
            bottombar
        },
        title="Prefiltros",
        margin="5x5",
        gap=10
    }

    local function destroy_dialog()
        -- print(" cerrando  ...")
        single.image:Destroy()
        single.cnv.canvas:Kill()
        iup.ExitLoop() -- should be removed if used inside a bigger application
        dlg:destroy()
    end

    function dlg:close_cb() -- si se cierra desde la ventana
        destroy_dialog()
        return iup.IGNORE -- because we destroy the dialog
    end

    local dlg_cb = {}

    local function param_action(dialog, param_index)
      if (param_index == iup.GETPARAM_OK) then
        return "OK"
      elseif (param_index == iup.GETPARAM_INIT) then
        return "Map"
      elseif (param_index == iup.GETPARAM_CANCEL) then
        return "Cancel"
      elseif (param_index == iup.GETPARAM_HELP) then
        return "Preview"
        -- aca accion!!
      -- else
      else
        return false
        -- local param = iup.GetParamParam(dialog, param_index)
        -- print("PARAM"..param_index.." = "..param.value)
        -- local param = iup.GetParamParam(dialog, param_index)

      end
      -- print("contraste: "..contraste)
      -- print("gamma: "..gamma)
      -- print(dialog.Title)
      -- print(dialog.id)
    end

    local function param_action_contrast(dialog, param_index)
       local contrast_index = 0
       local result = param_action(dialog, param_index)
       if (result == "Preview") then
          local param = iup.GetParamParam(dialog, contrast_index)
          print("Preview contraste: "..param.value.." ...")
          -- local procesando = iup.Message ("Preview", "Procesando...")
          if self:refresh_econvert_preview(tmp_orig_path, tmp_test_path) then
             if self:econvert_apply_contrast(param.value, tmp_test_path, tmp_test_path) then
                reload_image_and_refresh_canvas(tmp_test_path)
                refresh_label('CONTRAST')
             else
                print("error! No se pudo aplicar el filtro contraste.")
             end
          else
             print("error! No se pudo actualizar la imagen para vista previa en '"..tmp_test_path.."'")
          end
       elseif (result == "OK") then
          local param = iup.GetParamParam(dialog, contrast_index)
          contrast = param.value
          print("contraste seleccionado: "..contrast)
          if self:refresh_econvert_preview(tmp_orig_path, tmp_test_path) then
             reload_image_and_refresh_canvas(tmp_test_path)
             refresh_label('CONTRAST')
          else
             print("error! No se pudo actualizar la imagen para vista previa en '"..tmp_test_path.."'")
          end
       elseif (result == "Cancel") then
          print("Eligió cancelar, contraste actual: "..contrast)
          if self:refresh_econvert_preview(tmp_orig_path, tmp_test_path) then
             reload_image_and_refresh_canvas(tmp_test_path)
             refresh_label('CONTRAST')
          else
             print("error! No se pudo actualizar la imagen para vista previa en '"..tmp_test_path.."'")
          end
       end
       return 1
    end

    local function param_action_gamma(dialog, param_index)
       local gamma_index = 0
       local result = param_action(dialog, param_index)
       if (result == "Preview") then
          local param = iup.GetParamParam(dialog, gamma_index)
          print("Preview gamma: "..param.value.." ...")
          if self:refresh_econvert_preview(tmp_orig_path, tmp_test_path) then
             if self:econvert_apply_gamma(param.value, tmp_test_path, tmp_test_path) then
                reload_image_and_refresh_canvas(tmp_test_path)
                refresh_label('GAMMA')
             else
                print("error! No se pudo aplicar el filtro gamma.")
             end
          else
             print("error! No se pudo actualizar la imagen para vista previa en '"..tmp_test_path.."'")
          end
       elseif (result == "OK") then
          local param = iup.GetParamParam(dialog, gamma_index)
          gamma = param.value
          print("gamma seleccionada: "..gamma)
          if self:refresh_econvert_preview(tmp_orig_path, tmp_test_path) then
             reload_image_and_refresh_canvas(tmp_test_path)
             refresh_label('GAMMA')
          else
             print("error! No se pudo actualizar la imagen para vista previa en '"..tmp_test_path.."'")
          end
       elseif (result == "Cancel") then
          print("Eligió cancelar, gamma actual: "..gamma)
          if self:refresh_econvert_preview(tmp_orig_path, tmp_test_path) then
             reload_image_and_refresh_canvas(tmp_test_path)
             refresh_label('GAMMA')
          else
             print("error! No se pudo actualizar la imagen para vista previa en '"..tmp_test_path.."'")
          end
       end
       return 1
    end



    function gbtn.gbtn_contrast:action()
        local v = contrast
        local ret, v =
              iup.GetParam("Contraste", param_action_contrast,
                          "Bt %u[OK,Cancel,Preview]\n"..
                          "Contraste: %i[0,100]\n",
                          v)
        if (not ret) then
          return
        end
    end

    function gbtn.gbtn_gamma:action()

        local v = gamma
        local ret, v =
              iup.GetParam("Gamma", param_action_gamma,
                          "Bt %u[OK,Cancel,Preview]\n"..
                          "Gamma: %i[0,200]\n",
                          v)
        if (not ret) then
          return
        end
    end


    dlg:show()
    if (iup.MainLoopLevel()==0) then
      iup.MainLoop()
    end
end

return prefiltros
