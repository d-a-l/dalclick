-- IupGetParam Example in IupLua 
-- Shows a dialog with many possible fields. 

local prefiltros = {}

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

    single.image = im.FileImageLoad( "/opt/src/dalclick-dev/img/test.jpg" )
    single.cnv = iup.canvas{rastersize = single.image:Width().."x"..single.image:Height(), border = "YES"}

    function single.cnv:map_cb()       -- the CD canvas can only be created when the IUP canvas is mapped
        self.canvas = cd.CreateCanvas(cd.IUP, self)
    end
    function single.cnv:action()          -- called everytime the IUP canvas needs to be repainted
        self.canvas:Activate()
        self.canvas:Clear()
        single.image:cdCanvasPutImageRect(self.canvas, 0, 0, 0, 0, 0, 0, 0, 0) -- use default values
    end

    single.label = iup.label{
        title = "Filtros" --, expand = "HORIZONTAL", padding = "10x5"
    }

    gbtn.gbtn_contraste = iup.button{
        title = "Contraste",
        flat = "No",
        padding = "15x2",
        action = function()  end,
        canfocus="No",
        tip = "Ajustar contraste de la imagen",
    }

    gbtn.gbtn_gamma = iup.button{
        title = "Gamma",
        flat = "No",
        padding = "15x2",
        canfocus="No",
        tip = "Ajustar gamma de la imagen",
    }


    local viewers = iup.hbox{
       single.cnv
    }

    local labelbar = iup.hbox{
       single.label
    }

    local bottombar = iup.hbox{
        gbtn.gbtn_contraste,
        gbtn.gbtn_gamma,
	    iup.fill {
	        expand="HORIZONTAL"
	    },
	    margin = "10x10",
	    gap = 2,
    }

    local dlg = iup.dialog{
        iup.vbox{
            viewers,
            labelbar,
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

    local function param_action(dialog, param_index)
      if (param_index == iup.GETPARAM_OK) then
        print("OK")
      elseif (param_index == iup.GETPARAM_INIT) then
        print("Map")
      elseif (param_index == iup.GETPARAM_CANCEL) then
        print("Cancel")
      elseif (param_index == iup.GETPARAM_HELP) then
        print("Preview")
        -- aca accion!!
      -- else
        -- local param = iup.GetParamParam(dialog, param_index)
        -- print("PARAM"..param_index.." = "..param.value)
      end
      return 1
    end

    function gbtn.gbtn_contraste:action()

        local contraste = 0
          
        local ret, contraste = 
              iup.GetParam("Title", param_action,
                          "Bt %u[OK,Cancel,Preview]\n"..
                          "Contraste: %i[0,100]\n",
                          contraste)
        if (not ret) then
          return
        end
    end

    function gbtn.gbtn_gamma:action()

        local gamma = 0
          
        local ret, gamma = 
              iup.GetParam("Title", param_action,
                          "Bt %u[OK,Cancel,Preview]\n"..
                          "Gamma: %i[0,100]\n",
                          gamma)
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
