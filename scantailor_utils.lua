local sc_utils = {}

local function scandir()
   local l = {}
   return true, l
end

function sc_utils:create_protoproject(source_path, out_path)
   local result, list = scandir(source_path)
   if result == true then
   else
      local error_msg = list
      return false, error_msg
   end

end

return sc_utils
