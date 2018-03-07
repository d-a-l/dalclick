require "lfs"

fs = {}

local function split_to_numbers(str)
   local t={}
   for n in string.gmatch(str, "([^ ]+)") do
      table.insert(t, tonumber(n))
   end
   return t
end

local function get_user_and_groups(user)
   user = user or '$USER'
   local h = io.popen('id -u "'..user..'" | xargs echo -n')
   local u = h:read("*a")
   h:close()
   h = io.popen('id -G "'..user..'" | xargs echo -n')
   local g = h:read("*a")
   h:close()
   groups = split_to_numbers( g )
   return tonumber(u), groups
end

local function check_permissions(userid, groupids, attr)
   -- root can permission for all
   if userid == 0 then return true end
   -- owner user w permission in owner
   if attr['uid'] == userid then
      if string.match( attr['permissions'], "^.(w).......$" ) == 'w' then
         return true
      else
         return false -- if user is owner, user permissions overwrite groups and others
      end
   else
      -- any user's groups 'w' permission in group
      for k,groupid in ipairs(groupids) do
         if attr['gid'] == groupid then
            if string.match( attr['permissions'], "^....(w)....$" ) == 'w' then
               return true
            else
               return false -- no importa que others tenga permiso 'w'
            end
         end
      end
      if string.match( attr['permissions'], "^.......(w).$" ) == 'w' then
         return true
      else
         return false
      end
   end
   print('ERROR LOGICO SI SE LLEGO AQUI!')
end
-- ========================================================================= --

function fs:path_exists(path)
   if type(path) ~= 'string' then return nil end
   local f = io.open(path, "r")
   if f ~= nil then
      io.close(f)
      return true
   else
      return false
   end
end

function fs:is_dir(path)
   local attr,m,c = lfs.attributes( path )
   if attr == nil then return nil end
   if type(attr) == 'table' then
      if attr['mode'] == 'directory' then
         return true
      else
         return false
      end
   else
      return nil
   end
end

function fs:is_writable_dir(path, user) -- funciona con symlinks
   local userid, groupids
   if not user then
      userid, groupids = get_user_and_groups()
   else
      userid, groupids = get_user_and_groups(user)
   end
   local attr,m,c = lfs.attributes( path )
   if attr == nil then return nil end -- path no existe
   if attr['mode'] == 'directory' then
      return check_permissions(userid, groupids, attr)
   else
      return nil -- path existe pero no es directorio
   end
end

function fs:is_writable_file(path, user) -- funciona con symlinks
   local userid, groupids
   if not user then
      userid, groupids = get_user_and_groups()
   else
      userid, groupids = get_user_and_groups(user)
   end
   local attr,m,c = lfs.attributes( path )
   if attr == nil then return nil end
   if attr['mode'] == 'file' then
      return check_permissions(userid, groupids, attr)
   else
      return nil
   end
end

function fs:delete_file( path ) -- TODO testear!
   if type(path) ~= 'string' then return nil end
   if self:path_exists(path) then
      if os.remove(path) then
         return true
      else
         return false
      end
   else
      return nil
   end
end

function fs:create_file( path, content )  -- TODO testear!
   if type( path ) ~= 'string' then return false end
   content = content or ""
   if self:path_exists( path ) then
      if self:is_dir( path ) then
         return false
      else
         return nil
      end
   else
      local f = io.open(path, "w")
      if f ~= nil then
         f:write(content)
         f:close(f)
         return true
      else
         return false
      end
   end
end

function fs:create_dir( path ) -- TODO testear!
   if type( path ) ~= 'string' then return false end
   if self:path_exists( path ) then
      if self:is_dir( path ) then
         return nil
      else
         return false
      end
   else
      if lfs.mkdir( path ) then
         return true
      else
         return false
      end
   end
end

function fs:read_file( path ) -- TODO testear!
   if type( path ) ~= 'string' then return nil end
   local content
   local f = io.open(path, "r")
   if f ~= nil then
      content = f:read("*a")
      f:close()
      return true, content
   else
      return false
   end
end

function fs:read_file_as_table(path) -- TODO testear!
   local content = {}
   local f = io.open(path, "r")
   if f ~= nil then
      for line in f:lines() do
         table.insert(content, line);
      end
      f:close()
      return true, content
   else
      return false
   end
end

return fs
