local c = {}
local build = {} -- interna! no devuelta

local left_margin = "140x"

function build:toggle(opts)
   local toogle_box = {}
   local iup_radiotoggle
   if opts.image then
      local iup_image = iup.image( opts.image )
      iup_radiotoggle = iup.toggle{ image=iup_image, sc_val=opts.sc_val }
      if opts.title then
         local iup_label = iup.label{ title=opts.title }
         toogle_box = iup.hbox{ iup_radiotoggle, iup.label }
      else
         toogle_box = iup_radiotoggle
      end
   else
      if opts.sc_val then
         iup_radiotoggle = iup.toggle{ title=opts.title, sc_val=opts.sc_val }
      else
         iup_radiotoggle = iup.toggle{ title=opts.title }
      end
      toogle_box = iup_radiotoggle
   end

   function iup_radiotoggle:on_extra_actions()
   end
   function iup_radiotoggle:off_extra_actions()
   end
   function iup_radiotoggle:action()
      if self.value == "ON" then
         self:on_extra_actions()
      else
         self:off_extra_actions()
      end
   end

   return toogle_box, iup_radiotoggle
end

function build:radio(t)
   if type(t.radio_options) ~= 'table' then return false end

   local controls = {}

   local iup_parent, iup_radio, iup_grandparent, default_object
   local iup_brothers = {};

   if t.family.brother.iup_obj == 'label' then
      local iup_label = iup.label{ title = t.family.brother.title, minsize=left_margin }
      table.insert( iup_brothers, iup_label )
   end

   for n,opts in pairs(t.radio_options) do
      local toogle_box, toggle_ref = self:toggle(opts)
      if toggle_ref.sc_val then
         controls[toggle_ref.sc_val] = toggle_ref
      else
         table.insert( controls, toggle_ref )
      end
      table.insert( iup_brothers, toogle_box)
      -- if opts.default then default_obj = #iup_brothers end
      if opts.default then default_object = toggle_ref end
   end

   if t.family.parent.iup_obj == 'hbox' then
      iup_parent = iup.hbox(iup_brothers)
   else
      iup_parent = iup.vbox(iup_brothers)
   end

   iup_radio = iup.radio{ iup_parent }
   if default_object then iup_radio.value = default_object end -- iup_brothers[default_obj] end

   if t.family.grandparent.iup_obj == 'frame' then
      iup_grandparent = iup.frame{ iup_radio }
      if t.family.grandparent.title then
         iup_grandparent.title = t.family.grandparent.title
      end
   end

   if iup_grandparent then
      iup_grandparent.id = t.id
      function iup_grandparent:get_value()
         return iup_radio.value -- self[1].value
      end
      return iup_grandparent, controls
   else
      iup_radio.id = t.id
      return iup_radio, controls
   end
end

function build:checkbox(t)

   local toogle_opts = t.toogle_opts or {}
   if not toogle_opts.title then toogle_opts.title = t.label end

   local checkbox, toogle_control = self:toggle(toogle_opts)

   local iup_parent
   if t.family.parent.iup_obj == 'hbox' then
      iup_parent = iup.hbox{ checkbox }
   elseif t.family.parent.iup_obj == 'vbox' then
      iup_parent = iup.vbox{ checkbox }
   end

   if iup_parent then
      iup_parent.id = t.id
      return iup_parent, toogle_control
   else
      checkbox.id = t.id
      return checkbox, toogle_control
   end
end

function build:getparam(t)
   local button_options = t.button_options or {}
   local param_options = t.param_options or {}
   local button_title

   if button_options.title then
      button_title = button_options.title
   else
      button_title = "Set '"..t.label.."' options"
   end
   local iup_button = iup.button{ title=button_title }

-- -- -- --
--[[
   local function param_action(dialog, param_index)
     if (param_index == iup.GETPARAM_OK) then
       print("OK")
     elseif (param_index == iup.GETPARAM_INIT) then
       print("Map")
     elseif (param_index == iup.GETPARAM_CANCEL) then
       print("Cancel")
     elseif (param_index == iup.GETPARAM_HELP) then
       print("Help")
     elseif (param_index == 1) then
       return 0
     else
       local param = iup.GetParamParam(dialog, param_index)
       print("PARAM"..param_index.." = "..param.value)
     end
     return 1
   end

   -- set initial values
   local pstring = "string text"

   function iup_button:action()
      ret, pstring = iup.GetParam("Title", param_action, "String: %s", pstring)
      -- if (not ret) then exit() end
      iup.Message("IupGetParam", "String: "..pstring)
   end
]]
-- -- -- --
   function iup_button:action()
      iup.Message("IupGetParam", "Apretaste el boton boludo!")
   end
   return iup_button -- necesita devolver un control del boton?
end
--[[
local iup_param = iup.param{format = "Experimento: %r[-1.5,1.5,0.05]\n"}
local iup_parambox = iup.parambox{ iup_param }
local iup_frame = iup.frame{ iup_parambox, title = 'for test' }
]]

function build:spin(t)

   local iup_brothers = {}

   if t.family.brother.iup_obj == 'label' then
      local iup_label = iup.label{ title = t.family.brother.title, minsize="140x" }
      table.insert( iup_brothers, iup_label )
   end

   local iup_spintext = iup.text{ spin="YES" }
   table.insert( iup_brothers, iup_spintext )
   table.insert( iup_brothers, iup.fill{} )

   local iup_parent
   if t.family.parent.iup_obj == 'frame' then
      iup_parent = iup.frame( iup_brothers )
      iup_parent.title = parent.title
   else -- t.family.parent.iup_obj == 'hbox'
      iup_parent = iup.hbox( iup_brothers )
   end

   if iup_parent then
      iup_parent.id = t.id
      return iup_parent
   else
      -- iup_spinbox.id = t.id
      return iup_spintext -- necesita devolver un control?
   end
end

function build:scantailor_enable_option(t, build_funtion)
   -- create a checkbox to enable / disable he option
   if type(t) ~= 'table' then return false end

   local o = {};
   local c = {}
   local toogle_control = iup.toggle{ title=t.label, minsize=left_margin }
   local iup_vbox = iup.vbox{ toogle_control }
   table.insert( o, iup_vbox )
   table.insert( c, toogle_control )

   local iup_elem, controls = self[build_funtion](self, t)
   iup_elem.active = "No"

   if type(controls) == 'table' then
      for ind, control in pairs(controls) do
         -- print('ind: '..ind)
         if type(ind) == 'string' then
            -- print('asign '..ind..' to c')
            c[ind] = control
         else
            table.insert(c, control)
         end
      end
   end

   if type(t.disable_items) == 'table' then
      toogle_control.disable_items = t.disable_items
   end
   function toogle_control:on_extra_actions()
   end
   function toogle_control:off_extra_actions()
   end
   function toogle_control:action()
      if self.value == "ON" then
         iup_elem.active = "Yes"
         self:on_extra_actions()
      else
         iup_elem.active = "No"
         self:off_extra_actions()
      end
   end
   table.insert( o, iup_elem )
   return iup.hbox( o ), c
end

--============================= Public functions ============================ --

local function check_family(t)
   if not t.family             then t['family'] = {}                end
   if not t.family.parent      then t['family']['parent'] = {}      end
   if not t.family.brother     then t['family']['brother'] = {}     end
   if not t.family.grandparent then t['family']['grandparent'] = {} end
   return t
end

function c:sc_radio(t)
   local tt = check_family(t)
   if type(tt) ~= 'table' then return false end
   return build:scantailor_enable_option(tt, 'radio')
end

function c:sc_getparam(t)
   local t = check_family(t)
   if type(t) ~= 'table' then return false end
   return build:scantailor_enable_option(t, 'getparam')
end

function c:sc_checkbox(t)
   local t = check_family(t)
   if type(t) ~= 'table' then return false end
   return build:checkbox(t)
end

function c:sc_spin(t)
   local t = check_family(t)
   if type(t) ~= 'table' then return false end
   return build:scantailor_enable_option(t, 'spin')
end

return c
