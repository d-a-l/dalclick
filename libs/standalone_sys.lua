local posix = require('posix')

-- standalone_sys: alternative 'sys' (fake) object to the chdkptp sys library

local standalone_sys={}

--[[
    sleep: a fake sys.sleep() function
    otras ocpiones 
     - https://luaposix.github.io/luaposix/modules/posix.time.html#clock_gettime
     - http://lua-users.org/wiki/SleepFunction
--]]
function standalone_sys.sleep(milisec)
    if type(milisec) ~= "number" then return true end
    local sec = math.floor(milisec/1000)
    posix.sleep(sec)
    return true
end

return standalone_sys


