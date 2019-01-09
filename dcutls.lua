
local dcutls = {
    localfs = {}
}

function dcutls.localfs:file_exists(path)

    local f = io.open(path, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

function dcutls.localfs:is_dir(path)
   local r = false
   if type(path) ~= 'string' then return nil end
   local result,idntknw,code = os.execute("cd '" .. path .. "'")
   if type(result) == 'boolean' then -- lua 5.2
      if result == true then r = true end
   elseif type(result) == 'number' then -- lua 5.1
      if result == 0 then r = true end
   end
   return r -- true/false
end

function dcutls.localfs:delete_file(path)

    if self:file_exists(path) then
        if os.remove(path) then
            return true
        else
            return false
        end
    else
        print(" DEBUG: no existe el archivo que se desea eliminar: "..path)
        return nil
    end
end

function dcutls.localfs:create_file(path,content)

    if path == "" then
        return false
    end
    local f = io.open(path, "w")
    if f ~= nil then
        f:write(content)
        f:close(f)
        return true
    else
        return false
    end
end

function dcutls.localfs:read_file(path)

    local content
    if path == "" then
        return false
    end
    local f = io.open(path, "r")
    if f~=nil then
        content = f:read("*a")
        f:close()
        return content
    else
        return false
    end
end

function dcutls.localfs:read_file_as_table(path)

    local content = {}
    if path == "" then
        return false
    end
    local f = io.open(path, "r")
    if f ~= nil then
        for line in f:lines() do
            table.insert(content, line);
        end
        f:close()
        return content
    else
        return false
    end
end

function dcutls.localfs:create_folder(path)

    if path == "" then
        return false
    end
    if not self:file_exists(path) then
        if lfs.mkdir(path) then
            print("  '"..path.."' creado con éxito")
            return true
        else
            print("  error: '"..path.."' no pudo ser creado")
            return false
        end
    else
        print("  advertencia: '"..path.."' ya existe")
        return true
    end
end

function dcutls.localfs:create_folder_quiet(path)

    if path == "" then
        return false
    end
    if not self:file_exists(path) then
        if lfs.mkdir(path) then
            return true
        else
            return false
        end
    else
        return nil
    end
end

function dcutls:init_queue(path)
end

function dcutls:get_user_home()
    local handle = io.popen("echo -n $HOME")
    local result = handle:read("*a")
    handle:close()
    return result
end

function dcutls.shoot_half_wait_full(lcon)
    local status, err = lcon:execwait([[
press('shoot_half')
local i=0
while get_shooting() do
    sleep(10)
    if i > 300 then
        release('shoot_half')
        break
    end
    i=i+1
end
play_sound(4)
press('shoot_full')
sleep(50)
release('shoot_full')
]])
    printf("shoot_half_full: status=%s, shootst=%s\n", tostring(status), tostring(err))
    return status, err
end

function dcutls.verify_empty(lcon)
-- verifica que este vacía la tarjeta TODO reescribir!!
    if lcon:is_connected() then
        t = lcon:listdir('A/DCIM',{match=l.folder_match}) -- solo lista directorios que empiezan con un numero
        if t then
            if next(t) then
                print("\nPor favor, vacía completamente la tarjeta de memoria antes de iniciar un nuevo proceso de digitalización\n")
            else
                printf("%s: OK tarjeta vacía \n", tostring(lcon.ptpdev.serial_number))
            end
        else
                print("nada que listar aqui")

        end
    else
        print("error: %s no esta conectada\n", tostring(lcon.ptpdev.serial_number))
    end

end

return dcutls
