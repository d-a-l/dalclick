-- dalclick project
-- local p = p:new{id = 'titulo_sin_espacios', dir = 'valid dir path' type = 'postproc_task'}

fs = require('app/utls/fs')

local p = {}

local p_types = {
   postproc_task = {
      id = postproc_task,
      tree = {
         defaults.doc_name,
      }
   },
   -- project = {
   --   id = project,
   --   tree = {}
   -- },
}

function p:init()
end

function p:create_tree()
   local base = self.dir .. '/' .. self.id
   for index, path in pairs( p_types[self..type].tree ) do
      if not fs:path_exists( base.."/"..path ) then
         if fs:create_folder_quiet( base.."/"..path ) == false then
            return false, "ERROR: can't create: "..base.."/"..path
         end
      end
   end
   return true
end

function p:check_tree()
   local base = self.dir .. '/' .. self.id
   for index, path in pairs( p_types[o.type].tree ) do
      if not fs:path_exists( base.."/"..path ) then
        return false, "ERROR: "..base.."/"..path
      end
   end
   return true
end

function p:load_config()
end

function p:save_config()
end

function p:check_config()
end

local new_em = {
   [1] = 'id no es string',
   [2] = 'id contiene caracteres invalidos',
   [3] = 'dir no es string',
   [4] = 'type no es string',
   [5] = 'type proporcionado no valido',
   [6] = 'dir no es writable o no existe',
   [7] = 'id ya existe pero no es writable',
}

function p:new(o)
   if type(o.id) ~= 'string' then return nil,new_em[1] end
   if not string.match(o.id, "^[%w-_]+$") then return nil,new_em[2] end -- a-z, A-Z, 0-9 mas '-' y '_'
   self.id = o.id
   if type(o.dir) ~= 'string' then return nil,new_em[3] end
   self.dir = o.dir
   if type(o.type) ~= 'string' then return nil,new_em[4] end
   if not p_types[o.type] then return nil,new_em[5] end
   self.type = o.type

   if not fs:is_writable_dir( self.dir ) == true then
      return nil,new_em[6]
   end

   local path = self.dir .. '/' .. self.id
   if fs:path_exists( path ) then
      if not fs:is_writable_dir( path ) then
         return nil,new_em[7]
      end
   else
      fs:create_dir(path)
      self.create_tree()
   end

   setmetatable(o, self)
   self.__index = self
   return o
end

return p

--[[
origins_paths = {} -- { 'path/to/even', 'path/to/odd' .. }
src_path = 'src' -- symlinks iniciales
proc_path = 'proc' -- aca adentro trtabaja postprocessing
done_path = 'done'
output_name = ''
pdf_layout = string

clean_prefilters=
clean_filters=
clean_ocr=
clean_pdf=
enable_post_actions = false
enable_pre_actions = false
enable_prefilters=
enable_filters=
enable_ocr
enable_pdf
prefilter_software = 'dalclick'
prefilter_options = { prefilter1 = {opt..opt}, prefilter2... }
filter_software = 'scantailor-enhanced'
filter_options = {scantailor_project_name, option..option..}
ocr_software = 'tesseract-ocr'
ocr_options = {}
pdf_software = 'pdfbeads'
pdf_options = {}

]]--
