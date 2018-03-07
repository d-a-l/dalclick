
local build_iup_elems = require( "build_iup_elems" )

local build = {}

function build:layout(list_elems, list_groups, special_frame)
   -- create n layouts for n groups and 'more options' layout for iup_free_elems
   -- order:
   -- 1. special frame ()
   -- 2. explicit groups from list,
   -- 3. implicit groups from elem, 3. free elems

   if type(list_elems) ~= 'table' then return false end
   local list_groups = list_groups or {}
   local lg_order = {}
   local iup_free_elems = {}; local iup_grouped_elems = {}

   -- compute groups
   local function get_list_groups_by_id(id)
      for n,l in pairs(list_groups) do
         if l.id == id then return l end
      end
      return false
   end

   for n,l in pairs(list_groups) do
      if l.id then
         iup_grouped_elems[l.id] = {}
         table.insert( lg_order, l.id)
      end
   end

   -- compute elements
   local control_items_register = {}
   local created_items_register = {}
   for n,e in pairs(list_elems) do
      local iup_elem; local controls

      if e.gui_type == 'sc_radio' then
         iup_elem, controls = build_iup_elems:sc_radio(e)
      elseif e.gui_type == 'sc_checkbox' then
         iup_elem, controls = build_iup_elems:sc_checkbox(e)
      elseif e.gui_type == 'sc_spin' then
         iup_elem = build_iup_elems:sc_spin(e)
      end

      if type(controls) == 'table' and e.id then
         control_items_register[e.id] = controls
      end

      if iup_elem then
         if e.id then created_items_register[e.id] = iup_elem end
         if e.group_id then
            if not iup_grouped_elems[e.group_id] then
               -- 'implicit' groups mentiones in elems
               iup_grouped_elems[e.group_id] = {}
               table.insert( lg_order, e.group_id )
            end
            -- print("insertando un" .. e.gui_type .." en ".. e.group_id)
            table.insert( iup_grouped_elems[e.group_id], iup_elem)
         else
            table.insert( iup_free_elems, iup_elem)
         end
      end
   end

   -- compose layout
   frames = {}
   if special_frame then
      table.insert( frames, special_frame )
   end
   for n,id in pairs( lg_order ) do
      -- print("armando "..id)
      local title, header
      local g = get_list_groups_by_id(id)
      if g then
         title = g.title or id
         if g.header then
            if g.header.gui_type == 'label' then
               header = iup.label{ title = g.header.label_title }
            end
         end
      end
      local iup_elems = {}
      if header then table.insert( iup_elems, header ) end
      table.insert( iup_elems, iup.vbox( iup_grouped_elems[id] ))
      local iup_frame = iup.frame(iup_elems)
      if id then created_items_register['group_'..id] = iup_frame end
      iup_frame.title = id

      table.insert( frames, iup_frame )
   end

   table.insert( frames, iup.frame{ iup.vbox(iup_free_elems), title='More Options' } )

   local layout = iup.vbox(frames)


   print("\nCreated items:")
   for k, i in pairs(created_items_register) do print(k, i) end
   print("\nControl items:")
   for k, i in pairs(control_items_register) do
      for n, c in pairs(i) do
         print(k, n, c)
      end
   end
   -- print("control_items_register['layout']"..tostring(control_items_register['layout']))
   -- print("control_items_register['layout']['on_extra_actions']"..tostring(control_items_register['layout']['on_extra_actions']))

   -- control_items_register['enable-fine-tuning']['on_extra_actions']('sarasa')

   control_items_register['layout']['on_extra_actions'] = function()
      -- iup.Message("layout", "llegamos!")
      created_items_register['group_margins'].active = "No"
   end

   return layout
end

function build:scantailor_special_frame()
   local special = {}

   local iup_checkbox_cb, iup_checkbox_cb_toogle = build_iup_elems:sc_checkbox{
      id='content_box', toogle_opts={ title='Crop to content-box' }, }
   local iup_checkbox_pb, iup_checkbox_pb_toogle = build_iup_elems:sc_checkbox{
      id='page_border', toogle_opts={ title='Crop to page-border' }, }

   local iup_options_cb = {}
   table.insert( iup_options_cb, (build_iup_elems:sc_radio{
          id = 'content-detection',
          label = 'Content detection',
          gui_type = 'sc_radio',
          family = {
            parent = { iup_obj = 'vbox' },
            grandparent = { iup_obj = 'frame', title = 'Mode:' }
          },
          radio_options = {
              { sc_val = 'cautious',   title = 'Cautious' },
              { sc_val = 'normal',     title = 'Normal', default = true },
              { sc_val = 'aggressive', title = 'Aggressive' },
          },
          value_type = 'string',
          explicit = false
   }))
   table.insert( iup_options_cb, (build_iup_elems:sc_getparam{
       id = 'margins',
       label = 'Manual margins',
       button_options = { title = 'Set margins' }
   }))
   --[[ table.insert( iup_options_cb, sc_iup_radio{
          id = 'content-detection',
          label = 'Content detection',
          gui_type = 'sc_radio',
          family = {
            parent = { iup_obj = 'vbox' },
            grandparent = { iup_obj = 'frame', title = 'Mode:' }
          },
          radio_options = {
              { sc_val = 'cautious',   title = 'Cautious' },
              { sc_val = 'normal',     title = 'Normal', default = true },
              { sc_val = 'aggressive', title = 'Aggressive' },
          },
          value_type = 'string',
          explicit = false
   })
   table.insert(t, {
       id = 'enable-auto-margins',
       label = 'Enable auto margins',
       sc_param = '--enable-auto-margins',
       sc_comment = 'Sets the margins to original ones (based on detected page or image size).',
       gui_type = 'checkbox',
       value_type = 'boolean',
       explicit = false -- default disable implicit, true -> enable
   })
   table.insert(t, {
       id = 'disable-content-text-mask',
       label = 'Disable content text mask',
       sc_param = '--disable-content-text-mask',
       sc_comment = 'Disable using text mask to estimate a content box.',
       gui_type = 'checkbox',
       value_type = 'boolean',
       explicit = false -- default enable implicit, true -> disable
   }) ]]
   -- iup_options_cb.active = "No"
   local cb_frame = iup.frame{ iup.vbox( iup_options_cb ) }

   cb_frame.sunken = "Yes"
   cb_frame.active = "No"

   local iup_vbox_cb = iup.vbox {
      iup_checkbox_cb,
      -- iup.label{ separator="HORIZONTAL" },
      cb_frame,
      size="150x"
   }
   local iup_vbox_pb = iup.vbox {
      iup_checkbox_pb,
      -- iup.label{ separator="HORIZONTAL" },
      size="150x"
      -- iup_options_pb
   }
   local iup_box = iup.hbox {
      iup_vbox_cb,
      -- iup.label{ separator="VERTICAL" },
      iup_vbox_pb
      -- iup_options_pb
   }
   local iup_frame = iup.frame{ iup_box, title="Crop area"}

   function iup_checkbox_cb_toogle:action()
      if self.value == "ON" then
         cb_frame.active = "Yes"
         iup_checkbox_pb_toogle.value = "OFF"
         iup_checkbox_pb_toogle:action()
         -- iup_checkbox_pb_toogle.value = "No"
      else
         cb_frame .active = "No"
      end
   end
   function iup_checkbox_pb_toogle:action()
      if self.value == "ON" then
         --iup_options_pb.active = "Yes"
         iup_checkbox_cb_toogle.value = "OFF"
         iup_checkbox_cb_toogle:action()
         -- iup_options_cb.active = "No"
      else
         -- iup_options_pb.active = "No"
      end
   end
   return iup_frame
end

return build
