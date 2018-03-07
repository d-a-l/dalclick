	--layout=, -l=<0|1|1.5|2>		-- default: 0
local t = {}

--     family = 'frame-hbox' family = { wrapper = 'frame', container = 'hbox' },
--                    'frame-vbox' family = { wrapper = 'frame', container = 'vbox' },
--                    'hbox-label_left' family = { wrapper = '', container = 'hbox', label = 'label' },

table.insert(t, {
    id = 'layout',
    label = 'Layout',
    sc_param = '--layout',
    gui_type = 'sc_radio',
    family = {
      parent = { iup_obj = 'vbox' },
      grandparent = { iup_obj = 'frame', title = 'Layout options:' }
    },
    radio_options = {
        { sc_val = '0',   title = 'Auto detect', default = true },
        { sc_val = '1',   title = 'One page layout' },
        { sc_val = '1.5', title = 'One page layout but cutting is needed'},
        { sc_val = '2',   title = 'Two page layout'},
    },
    value_type = 'string',
    explicit = false
})

table.insert(t, {
    id = 'kopista_detection',
    label = 'Crop',
    -- sc_param = '--layout',
    gui_type = 'sc_radio',
    family = {
      parent = { iup_obj = 'vbox' },
      grandparent = { iup_obj = 'frame', title = 'Select crop area:' }
    },
    radio_options = {
        { sc_val = 'content',   title = 'Content box', default = true },
        { sc_val = 'page',   title = 'Page border' },
    },
    value_type = 'string',
    explicit = false
})


--[[ table.insert(t, {
    id = 'layout-direction',
    label = 'Layout direction',
    sc_param = '--layout-direction',
    gui_type = 'sc_radio',
    family = {
      brother = { iup_obj = 'label', title = 'Layout direction'},
      parent = { iup_obj = 'hbox' }
    },
    radio_options = {
        { sc_val = 'lr', title = 'Left to right', default = true },
        { sc_val = 'rl', title = 'Right to left' }
    },
    value_type = 'string',
    explicit = false
}) ]]
--[[ table.insert(t, {
    id = 'orientation',
    label = 'Orientation',
    sc_param = '--orientation',
    gui_type = 'sc_radio',
    family = {
      parent = { iup_obj = 'hbox' },
      grandparent = { iup_obj = 'frame', title = 'Orientation' }
    },
    radio_options = {
        { sc_val = 'left',       title = 'Left' },
        { sc_val = 'right',      title = 'Right' },
        { sc_val = 'upsidedown', title = 'Upside down'},
        { sc_val = 'none',       title = 'None', default = true}
    },
    value_type = 'string',
    explicit = false
}) ]]
--[[ table.insert(t, {
    id = 'rotate',
    label = 'Rotate',
    sc_param = '--rotate',
    gui_type = 'sc_spin',
    gui_title = 'Rotate:',
    range = {
        min =  0.0 ,
        max = 360.0 ,
    },
    value_type = 'float',
    explicit = false
}) ]]
--[[ table.insert(t, {
    id = 'deskew',
    label = 'Deskew',
    sc_param = '--deskew',
    gui_type = 'sc_radio',
    radio_options = {
        { sc_val = 'auto',   title = 'Auto', default = true},
        { sc_val = 'manual', title = 'Manual' },
    },
    value_type = 'string',
    explicit = false
}) ]]
--[[ table.insert(t, {
    id = 'deskew-deviation',
    label = 'Deskew deviation',
    sc_param = '--deskew-deviation',
    sc_comment = 'pages with bigger skew deviation will be painted in red',
    gui_type = 'spin-float',
    gui_title = 'Deskew deviation',
    range = {
        min = 0.0,
        max = 1000, -- infinito
    },
    default = 5.0,
    value_type = 'float',
    explicit = false
}) ]]
--[[ table.insert(t, {
    id = 'disable-content-detection',
    label = 'Disable content detection',
    sc_param = '--disable-content-detection',
    gui_type = 'sc_checkbox' ,
    family = {
      parent = { iup_obj = 'hbox' },
    },
    value_type = 'boolean',
    explicit = false -- default enable implicit, true -> disable
}) ]]
--[[ table.insert(t, {
    id = 'enable-page-detection',
    label = 'Enable page detection',
    sc_param = '--enable-page-detection',
    gui_type = 'sc_checkbox',
    value_type = 'boolean',
    explicit = false -- default disable implicit, true -> enable
}) ]]
table.insert(t, {
    id = 'enable-fine-tuning',
    label = 'Enable fine tuning',
    sc_param = '--enable-fine-tuning',
    sc_comment = 'If page detection enabled it moves edges while corners are in black.',
    gui_type = 'sc_checkbox',
    value_type = 'boolean',
    explicit = false -- default disable implicit, true -> enable
})
--[[ table.insert(t, {
    id = 'force-disable-page-detection',
    label = 'Force disable page detection',
    sc_param = '--force-disable-page-detection',
    sc_comment = 'Switch page detection from page project off if enabled and set content detection to manual mode.',
    gui_type = 'sc_checkbox',
    value_type = 'boolean',
    explicit = false -- default enable implicit, true -> disable
}) ]]


--[[ table.insert(t, {
    id = 'content-deviation',
    label = 'Content deviation',
    sc_param = '--content-deviation',
    sc_comment = 'Pages with bigger content deviation will be painted in red.',
    gui_type = 'spin-float',
    gui_title = 'Deskew deviation',
    range = {
        min = 0.0,
        max = 1000.0, -- infinito
    },
    default = 1.0,
    value_type = 'float',
    explicit = false
}) ]]
--[[ table.insert(t, {
    id = 'content-box',
    label = 'Content box',
    sc_param = '--content-box',
    sc_comment = 'If set the content detection is set to manual mode. Example: "--content-box=100x100:1500x2500".',
    gui_type = 'content-box-custom',
    gui_title = 'Content box:',
    value_type = 'string',     -- value result is string, example: '100x100:1500x2500'
    explicit = false
}) ]]

table.insert(t, {
    id = 'margins',
    label = 'Margins',
    sc_param = '--margins',
    sc_comment = 'Sets left, top, right and bottom margins to same number.',
    gui_type = 'custom_string',
    family = {
      brother = { iup_obj = 'label', title = 'Margins:' },
      parent = { iup_obj = 'vbox' }
    },
    gui_title = 'Margins:',
    value_type = 'int',
    explicit = false
})

--[[
table.insert(t, {
    id = 'margins',
    label = 'Margins',
    sc_param = '--margins',
    sc_comment = 'Sets left, top, right and bottom margins to same number.',
    gui_type = 'sc_spin',
    family = {
      brother = { iup_obj = 'label', title = 'Margins:' },
      parent = { iup_obj = 'vbox' }
    },
    gui_title = 'Margins:',
    value_type = 'int',
    explicit = false
})
table.insert(t, {
    id = 'margins-left',
    label = 'Margin left',
    sc_param = '--margins-left',
    gui_type = 'sc_spin',
    family = {
      brother = { iup_obj = 'label', title = 'Margin left:' },
      parent = { iup_obj = 'vbox' }
    },
    group_id = 'margins',
    value_type = 'int',
    explicit = false
})
table.insert(t, {
    id = 'margins-right',
    label = 'Margin right',
    sc_param = '--margins-right',
    gui_type = 'sc_spin',
    family = {
      brother = { iup_obj = 'label', title = 'Margin right:' },
      parent = { iup_obj = 'vbox' }
    },
    group_id = 'margins',
    value_type = 'int',
    explicit = false
})
table.insert(t, {
    id = 'margins-top',
    label = 'Margin top',
    sc_param = '--margins-top',
    gui_type = 'sc_spin',
    family = {
      brother = { iup_obj = 'label', title = 'Margin top:' },
      parent = { iup_obj = 'vbox' }
    },
    group_id = 'margins',
    value_type = 'int',
    explicit = false
})
table.insert(t, {
    id = 'margins-bottom',
    label = 'Margin bottom',
    sc_param = '--margins-bottom',
    gui_type = 'sc_spin',
    family = {
      brother = { iup_obj = 'label', title = 'Margin bottom:' },
      parent = { iup_obj = 'vbox' }
    },
    group_id = 'margins',
    value_type = 'int',
    explicit = false
})

table.insert(t, {
    id = 'default-margins',
    label = 'Default margins',
    sc_param = '--default-margins',
    sc_comment = 'Sets left, top, right and bottom margins, for new pages, to same number.',
    gui_type = 'sc_spin',
    family = {
      brother = { iup_obj = 'label', title = 'Default margins:' },
      parent = { iup_obj = 'vbox' }
    },
    gui_title = 'Default margins:',
    value_type = 'int',
    explicit = false
})
table.insert(t, {
    id = 'default-margins-left',
    label = 'Default margin left',
    sc_param = '--default-margins-left',
    gui_type = 'sc_spin',
    family = {
      brother = { iup_obj = 'label', title = 'Default margin left:' },
      parent = { iup_obj = 'hbox' }
    },
    group_id = 'default-margins',
    value_type = 'int',
    explicit = false
})
table.insert(t, {
    id = 'default-margins-right',
    label = 'Default margin right',
    sc_param = '--default-margins-right',
    gui_type = 'sc_spin',
    group_id = 'default-margins',
    value_type = 'int',
    explicit = false
})
table.insert(t, {
    id = 'default-margins-top',
    label = 'Default margin top',
    sc_param = '--default-margins-top',
    gui_type = 'sc_spin',
    group_id = 'default-margins',
    value_type = 'int',
    explicit = false
})
table.insert(t, {
    id = 'default-margins-bottom',
    label = 'Default margin bottom',
    sc_param = '--default-margins-bottom',
    gui_type = 'sc_spin',
    group_id = 'default-margins',
    value_type = 'int',
    explicit = false
}) ]]

table.insert(t, {
    id = 'match-layout',
    label = 'Match layout',
    sc_param = '--match-layout',
    gui_type = 'sc_radio',
    radio_options = {
        { sc_val = 'true',  title = 'Yes', default = true },
        { sc_val = 'false', title = 'No' },
    },
    value_type = 'boolean',
    explicit = false
})

return t

	--output-project=, -o=<project_name>!!!

   --page-detection-box=<widthxheight>		-- in mm
		--page-detection-tolerance=<0.0..1.0>	-- default: 0.1


--[margins]
--white-margins				-- default: false


--[match layout]
	--match-layout-tolerance=<0.0...)	-- default: off
	--match-layout-default=<true|false>	-- default: true

	--alignment=<center|original|auto>	-- sets vertical to original and horizontal to center
		--alignment-vertical=<top|center|bottom|original>
		--alignment-horizontal=<left|center|right|original>
	--alignment-tolerance=<float>		-- sets tolerance for auto alignment

--[resolucion]
	--dpi=<number>				-- sets x and y dpi. default: 600
		--dpi-x=<number>
		--dpi-y=<number>
	--output-dpi=<number>			-- sets x and y output dpi. default: 600
		--output-dpi-x=<number>
		--output-dpi-y=<number>

	--default-output-dpi=<number>		-- default output dpi for pages created by split filter in gui

--[color mode]
	--color-mode=<black_and_white|color_grayscale|mixed>
						-- default: black_and_white
	--default-color-mode=<...>		-- sets default value for new images created by split filter
   --normalize-illumination		-- default: false

--[mixed color mode image detection]
	--picture-shape=<free|rectangular>
						-- default: free

--[avanzadas]
	--threshold=<n>				-- n<0 thinner, n>0 thicker; default: 0
	--despeckle=<off|cautious|normal|aggressive>
						-- default: normal
   --depth-perception=<1.0...3.0>		-- default: 2.0
   --tiff-compression=<lzw|deflate|packbits|jpeg|none>	-- default: lzw
	--tiff-force-rgb			-- all output tiffs will be rgb
	--tiff-force-grayscale			-- all output tiffs will be grayscale
	--tiff-force-keep-color-space		-- output tiffs will be in original color space



	--dewarping=<off|auto>			-- default: off
	--start-filter=<1...6>			-- default: 4
	--end-filter=<1...6>			-- default: 6

	--window-title=WindowTitle		-- default: project name
	--disable-check-output			-- don't check if page is valid when switching to step 6
