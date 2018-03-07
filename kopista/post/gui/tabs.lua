require( "iuplua" )
require( "iupluacontrols" )
local sc_op = require( "scantailor-enhanced" )
local build = require( "build_layout" )

-- image

img1 = iup.image{
       {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
       {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
       {1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1},
       {1,1,1,1,1,1,2,2,1,1,1,1,1,1,1,1},
       {1,1,1,1,1,2,1,2,1,1,1,1,1,1,1,1},
       {1,1,1,1,2,1,1,2,1,1,1,1,1,1,1,1},
       {1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1},
       {1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1},
       {1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1},
       {1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1},
       {1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1},
       {1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1},
       {1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1},
       {1,1,1,2,2,2,2,2,2,2,2,2,1,1,1,1},
       {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
       {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1};
       colors = {"255 255 255", "0 192 0"}
}

-- Button

enable_gender_opts = iup.button{title="TEST COSAS"}

-- --
newframe = iup.frame{title="New Gender"}
-- --
local toggle_sel = iup.toggle{ title='activar opciones'} --, minsize="140x"

local toggle1 = iup.toggle{ title='manzana' }
local toggle2 = iup.toggle{ title='durazno' }
-- local label1 = iup.label{title = 'Descripcion aca:', minsize="140x"}

-- local box = iup.hbox{label1, toggle1, toggle2, gap='15', margin="15x5",
local box = iup.hbox{toggle1, toggle2, gap='15', margin="15x5",
alignment="ACENTER",  } -- homogeneous="YES"
-- local framex = iup.frame{
   -- iup.radio{ radio1 },
   -- title = 'otro radio',
-- }

local radio2 = iup.radio{ box }
-- local frame2 = iup.frame{ radio2 } --title="opciones a activar"
local box2 = iup.hbox{toggle_sel, radio2}
------
--[[
free_elems = {}
groups = {}
groups_order = {}
for n,e in pairs(sc_op) do
   local iup_elem

   if e.gui_type == 'radio' then
      iup_elem = c:iup_radio(e)
   elseif e.gui_type == 'sc_radio' then
      iup_elem = c:sc_iup_radio(e)
   elseif e.gui_type == 'checkbox' then
      iup_elem = c:iup_checkbox(e)
   end
   if iup_elem then
      if e.group then
         if not groups[e.group] then
            groups[e.group] = {}
            table.insert( groups_order, e.group )
         end
         table.insert( groups[e.group], iup_elem)
      else
         table.insert( free_elems, iup_elem)
      end
   end
end
-- table.insert( free_elems, iup.label{title="Titulo del coso", expand="HORIZONTAL"})
-- table.insert( free_elems, iup.button{title="Test Button"})

sc_box = {}
for n,group_name in pairs( groups_order ) do
   local iup_frame = iup.frame{
      iup.vbox( groups[group_name] ),
      title = group_name
   }
   table.insert( sc_box, iup_frame )
end

table.insert( sc_box, iup.frame{ iup.vbox(free_elems), title='Opciones' } )
]]
sc_special_frame = build:scantailor_special_frame()
sc_opt_layout = build:layout(sc_op, list_groups, sc_special_frame)

seleccionar_proyecto = iup.toggle{ title="Usar parametros de proyecto" }
seleccionar_opciones = iup.toggle{ title="Configurar parametros" }
sc_layout = iup.vbox{
   iup.vbox{ seleccionar_proyecto },
   iup.frame{ title="Cargar proyecto" },
   iup.vbox{ seleccionar_opciones },
   sc_opt_layout
}

activar_opciones = iup.toggle{ title="Activar" }
tab_sc = iup.vbox {
   iup.vbox{ activar_opciones },
   sc_layout
}

function activar_opciones:action()
   if self.value == "ON" then
      sc_layout.active = "Yes"
   else
      sc_layout.active = "No"
   end
end

tab_sc['tabtitle'] = "Scantailor"

tabs_e = {}
table.insert( tabs_e, iup.vbox{
   iup.label{ title="Init aldo" }, iup.toggle{title = "", image = img1},  tabtitle="Pre filters" } )
table.insert( tabs_e, tab_sc )
table.insert( tabs_e, iup.vbox{
   iup.label{title="Titulo Segundo Tab"},
   iup.button{title="Botonazo B"},
   box2,
   tabtitle = "Tesseract" })

-- Creates tabs
tabs = iup.tabs(tabs_e)

-- functions

function toggle_sel:action()
   -- iup.Message('Alert', tostring(self.value))
   if self.value == "ON" then
      radio2.active = "Yes"
      -- iup.Message('Alert', 'encender!')
   else
      radio2.active = "No"
      -- iup.Message('Alert', 'apagar!')
   end
end

function enable_gender_opts:action ()
   -- frame.active = "Yes"

   -- iup.Append(boxes[1],newframe)
   -- iup.Map(newframe);
   -- iup.Refresh(dlg);

   iup.Message('Alert', tostring(exclusive.value) )

end

left_bar = iup.vbox{ iup.label{title="the left bar"} }

iup_split = iup.split{left_bar, iup.scrollbox{tabs; margin="10x10"}, value="150"}

-- Creates dialog
dlg = iup.dialog {
   iup_split,
   title="Test IupTabs",
   font="Roboto Regular, Normal 11",
    size="500x300"
}

-- Shows dialog in the center of the screen
dlg:showxy(iup.CENTER, iup.CENTER)

if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
end
