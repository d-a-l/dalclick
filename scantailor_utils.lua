local dcutls = require('dcutls')
require "lfs"
require "imlua"
local SLAXML = require('libs.xmlutils.slaxdom')

local sc_utils = {}

function split_string_to_table(inputstr, sep)
   if sep == nil then
      sep = "%s"
   end
   local t={} ; i=1
   for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      t[i] = str
      i = i + 1
   end
   return t
end

local function get_relative_path(file_path, relative_from_this_dir)
   if not file_path or not relative_from_this_dir then return false end

   p1 = split_string_to_table(file_path, '/')
   p2 = split_string_to_table(relative_from_this_dir, '/')

   while true do
      if p1[1] == p2[1] then
         table.remove(p1, 1)
         table.remove(p2, 1)
      else
         break
      end
   end

   local relative_path_1 = ""
   for k,v in pairs(p2) do
     relative_path_1 = relative_path_1.."../"
   end
   if relative_path_1 == "" then
      relative_path_1 = "./"
   end
   local relative_path_2 = ""
   local sep = ""
   for k,v in pairs(p1) do
     relative_path_2 = relative_path_2..sep..v
     sep = "/"
   end
   return relative_path_1 .. relative_path_2
end

local function create_symlinks(opts)
   --[[
      opts { source_paths = { "/path/to/jpegs/dir1", "/path/to/jpegs/dir2", etc }
             all_path = "/path/to/all/dir",
             mode = "R"|"A" -- relativo o absoluto
             match = "regexp" -- ej
             extension = { 'jpg','tif', 'TIFF' ... etc } -- optional, default : {'jpg','JPG'}
          }
   --]]
   local file_list = {}
   for _,path in pairs(source_paths) do
      local list = scandir({dir=path, extension={'jpg', 'JPG'}, match="^(%d%d%d%d)" })
      for k,v in ipairs(list) do table.insert(file_list, v) end
   end

   local path_list = {}
   if mode == 'R' then
      for _,file_obj in pairs(file_list) do
         table.insert(path_list, get_relative_path( file_obj.abs_path, all_path ))
      end
   else
      for _,file_obj in pairs(file_list) do
         table.insert(path_list, file_obj.abs_path)
      end
   end
   for _,file_path in pairs(path_list) do
      if not os.execute('ln -s "'..file_path..'" "'..all_path..'"') then
         return false, "Error: create_symlink: en '"..file_path.."'"
      end
   end
   return true
end

local function scandir(opts)
   local opts = opts or {}
   if not opts.dir then return false, "Error: scandir: dir no recibido" end
   if not opts.extension then opts.extension = {".*"} end
   if not opts.match then opts.match = "^(.+)" end
   if not dcutls.localfs:is_dir( opts.dir ) then return false, "Error: scandir: '"..opts.dir.."' no es un directorio" end

   local file_list = {}

   for file in lfs.dir(opts.dir) do
      if lfs.attributes( opts.dir.."/"..file, "mode") == "file" then
         for _,extension in pairs( opts.extension ) do
            if file:match(opts.match.."%."..extension.."$") then
               local file_obj = { name = file, abs_path = opts.dir..'/'..file }
               table.insert( file_list, file_obj )
            end
         end
      end
   end

   local sort_func = function( a,b ) return a.name < b.name end
   table.sort( file_list, sort_func )
   return true, "", file_list
end

local function get_img_size(path)
   if not path then return false, "Error: get_img_size: path no recibido" end
   if not dcutls.localfs:file_exists(path) then return false, "Error: get_img_size: '"..path .."' no existe" end

   local ifile, error = im.FileOpen(path)
   -- local format, compression, image_count = ifile:GetInfo()
   -- local format_desc = im.FormatInfo(format)
   -- print('format:', format, 'comp:', compression, 'image_count:', image_count)
   local error, width, height, color_mode, data_type = ifile:ReadImageInfo()
   ifile:Close()

   return true, "", { width=width, height=height }
end

local function xml_get_attr_value_from_element( attr_name, el)
   if type(el) ~= 'table' then
      return false, "Error: xml_get_attr_value_from_element: el elemento no es una tabla"
   end
   if not attr_name or type(attr_name) ~= 'string' then
      return false, "Error: xml_get_attr_value_from_element: attr_name nulo o invalido"
   end
   if el.attr then
      for _, el_attr in ipairs(el.attr) do
         if el_attr.type == 'attribute' and el_attr.name == attr_name then
            return true, 'Encontrado!', el_attr.value
         end
      end
      return nil, "Warning: atributo: '" .. attr_name .. "' no encontrado en el elemento"
   end
   return nil, "Warning: el elemento no tenia atributos"
end

local function xml_select_elements_by_name(el, obj_name, R_param, r)
   r = r or 1; r = r + 1
   local founds_list = {}
   if el.type == 'element' and el.name == obj_name then
      -- print(r, "encontrado!", el)
      table.insert( founds_list, el)
      if not R_param then
         return founds_list
      end
   end
   for key, val in pairs( el ) do
      -- print(r, key, val)
      if ( key == 'kids' or type(key) == 'number' )  and type(val) == 'table' then
         -- print(r, 'recursion! ->', val)
         local more_founds = xml_select_elements_by_name(val, obj_name, R_param, r)
         if next(more_founds) and not R_param then
            return more_founds
         end
         for k,v in ipairs(more_founds) do table.insert(founds_list, v) end
      end
   end
   return founds_list
end

function sc_utils:check_version(scantailor_project_path)
   if not scantailor_project_path then
      return false, "Error: check_version: scantailor_project_path no recibido"
   end
   local content = dcutls.localfs:read_file(scantailor_project_path)
   if not content then
      return false, "Error: check_version: '" .. scantailor_project_path .. "' "
                 .. "no existe o no puede abrirse"
   end
   local doc = SLAXML:dom(content)
   if type(doc) ~= 'table' then return false, "Error, el doc obtenido no es una tabla" end
   local obj_name = 'project'
   local attr_name = 'version'
   local found_list = xml_select_elements_by_name(doc, obj_name, 'R')
   if type(found_list) == 'table' and next(found_list) then
      for k,el in ipairs (found_list) do
         local result, msg, value = xml_get_attr_value_from_element(attr_name, el)
         if result == true then return true, msg, value end
         if result == false then return false, msg end
      end
      return nil, msg
   else
      return nil, "Warning: xml_select_elements_by_name: no encontro el element ".. tostring(obj_name).."'"
   end
end

function sc_utils:create_protoproject_and_save(opts)
   --[[
      opts { source_path = "/path/to/jpegs/files/dir",
             out_path = "/path/to/scantailor/out/dir",
             projectfile_path = "/path/to/scantailor/file.scantailor"
             extension = { 'jpg','tif', 'TIFF' ... etc } -- optional, default : {'jpg','JPG'}
          }
   --]]
   local opts = opts or {}
   if not opts.projectfile_path then
	   return false, "Error: create_protoproject_and_save: projectfile_path no recibido"
   end
   if dcutls.localfs:file_exists(opts.projectfile_path) then
	   return false, "Error: create_protoproject_and_save: "..opts.projectfile_path.." ya existe"
   end
   local result, msg, out = self:create_protoproject(opts)
   if not result then
      return result, msg
   else
      if dcutls.localfs:create_file(opts.projectfile_path,out) then
   	   return true, "OK: create_protoproject_and_save: proyecto scantailor creado en "..opts.projectfile_path
      else
         return false, "ERROR: create_protoproject_and_save: No se pudo crear el proyecto en "..opts.projectfile_path
      end
   end
end

function sc_utils:create_protoproject(opts)
--[[
   opts { source_path = "/path/to/jpegs/files/dir",
          out_path = "/path/to/scantailor/out/dir",
          extension = { 'jpg','tif', 'TIFF' ... etc } -- optional, default : {'jpg','JPG'}
       }
--]]
   local opts = opts or {}
   if not opts.source_path or not opts.out_path then
	   return false, "Error: create_protoproject: source_path o out_path no recibido"
   end
   opts.extension = opts.extension or {'jpg','JPG'}
   if not dcutls.localfs:is_dir( opts.out_path ) then
        return false, "Error: create_protoproject: '" .. opts.out_path .. "' no existe"
   end

   local result, msg, list = scandir({ dir = opts.source_path, ext = opts.extension })
   if not result then return false, msg end

   local project =
      { type = "element",
        name = 'project',
        attr =
          {
              { type = 'attribute', name = 'layoutDirection', value = "LTR" },
              { type = 'attribute', name = 'outputDirectory', value = opts.out_path },
              { type = 'attribute', name = 'version', value = "3" }
          }
      }

   local directories =
      { type = "element",
        name = 'directories',
        kids =
          {
              { type = 'element',
                name = 'directory',
                attr =
                  {
                      { type = 'attribute', name = 'id', value = "1" },
                      { type = 'attribute', name = 'path', value = opt.source_path }
                  }
              }
          }
      }

   local file_kids = {}
   local image_kids = {}
   local page_kids = {}

   local n = 2
   for _,file in pairs(list) do

      local f = { type = "element",
                  name = 'file',
                  attr = {
		     { type = 'attribute', name = 'name', value = file.name },
		     { type = 'attribute', name = 'id', value = tostring(n) },
		     { type = 'attribute', name = 'dirId', value = "1" }
                  }
                }
      table.insert( file_kids, f )

      local result, msg, size = get_img_size( file.abs_path )
      if not result then return false end

      local i = { type = 'element',
		  name = "image",
                  attr = {
                     { type = 'attribute', name = 'fileId', value = tostring(n) },
                     { type = 'attribute', name = 'id', value = tostring(n + 1) },
                     { type = 'attribute', name = 'fileImage', value = '0' },
                     { type = 'attribute', name = 'subPages', value = '1' },
		  },
                  kids = {
                     {  type = 'element',
                        name = 'size',
                        attr = {
                           { type = 'attrubute', name = 'width', value = tostring(size.width) },
                           { type = 'attrubute', name = 'height', value = tostring(size.height) }
                        }
                     },
                     {  type = 'element',
                        name = 'dpi',
                        attr = {
                           { type = 'attrubute', name = 'vertical', value = '400' },
                           { type = 'attrubute', name = 'horizontal', value = '400' }
                        }
                     },
                     {  type = 'element',
                        name = 'grayscale',
                        attr = {
                           { type = 'attrubute', name = 'value', value = '0' },
                        }
                     }
                  }
              }
      table.insert( image_kids, i )

      local p = { type = "element",
                  name = 'page',
                  attr = {
                     { type = 'attribute', name = 'id', value = tostring( n + 2 ) },
                     { type = 'attribute', name = 'imageId', value = tostring( n + 1 ) },
                     { type = 'attribute', name = 'subPage', value = "single" }
                  }
                }
      table.insert( page_kids, p )

      n = n + 3
   end

   files = { type = 'element', name = 'files', kids = file_kids }
   images = { type = 'element', name = 'images', kids = image_kids }
   pages = { type = 'element', name = 'pages', kids = page_kids }
   project.kids = { directories, files, images, pages }

   return true, '', SLAXML:xml(project, { indent = 2 })

end


-- local result, msg, version = sc_utils:check_version('/opt/src/testproj-basico.ScanTailor')
-- print('result:', result)
-- print('msg:', msg)
-- if result then print('version:', version, type(version)) end

--[[
local scantailor_project_path = '/opt/src/testproj-basico.ScanTailor'
local content = dcutls.localfs:read_file(scantailor_project_path)
if not content then
   return false, "Error: check_version: '" .. scantailor_project_path .. "' "
              .. "no existe o no puede abrirse"
end
local doc = SLAXML:dom(content)
if type(doc) ~= 'table' then return false, "Error, el doc obtenido no es una tabla" end
local obj_name = 'file'
local found_list = xml_select_elements_by_name(doc, obj_name, 'R')
if type(found_list) == 'table' then
   print("---- resultado de busqueda: -----")
   for key, obj in pairs(found_list) do
      print(key, obj, obj.name, obj.type )
   end
else
   print("found_list no es una tabla!")
end
--]]

-- Crear proyeco vacio
-- local result, msg, string = sc_utils:create_protoproject( "/mnt/diy_20/bib/cronicas-judeoarg/pre/all", "/home/pampa")
-- print(result, msg)
-- print(string)

--[[ for i,fo in pairs(list) do
   local res, msg, size = get_img_size(fo.abs_path)
   print("i:"..i..", ".."list.name: '"..fo.name.."', ".."list.abs_path: '"..fo.abs_path.."'", size.width, size.height)
end
--]]


-- p1 = split_string_to_table(path1)
-- p2 = split_string_to_table(path2)

return sc_utils
