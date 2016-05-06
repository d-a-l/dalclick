--[[

    remote shoot alternative

--]]

local rsalt = {}

function rsalt:direct_raw_shoot_all(dalclick_globals, project_config, project_vars, cams)
    -- las camaras deben estar en rec mode y prefocus (shot half) previo

    local shoot_fail = false
    local break_main_loop = false
    local saved_files = {
        path = {},
        basepath = {},
        basename = {},
        idname = {},
    }
    local rs_opts = {}
    local ext
    for i,lcon in ipairs(cams) do
        lcon.count = project_vars.counter_state[lcon.idname]
        local local_path = dalclick_globals.root_project_path.."/"..project_config.regnum.."/"..dalclick_globals.raw_name.."/"..lcon.idname.."/"
        local file_name = string.format("%04d", lcon.count)
        -- local status,err = rsalt:direct_raw_shoot(lcon, local_path, file_name, project_config.format)
        rs_opts[1] = local_path..file_name
        rs_opts.cont = 1

        if project_config.out_img_format == "dng" then
            rs_opts.dng = true; ext = 'dng'
        elseif project_config.out_img_format == "raw" then
            rs_opts.raw = true; ext = 'raw'
        else
            print("err: no existe out_img_format")
            return false
        end
        local status,err = rsalt:direct_shoot(lcon, rs_opts)
        --
        if status then
            saved_files.path[i] = local_path..file_name.."."..ext
            saved_files.basepath[i] = local_path
            saved_files.basename[i] = file_name
            saved_files.idname[i] = lcon.idname
        else
            if err == "not in rec mode" then
                shoot_fail = true
                print(" ["..i.."] warning: set all cams to 'rec' mode to shoot")
            else
                shoot_fail = true
                break_main_loop = true
                printf(" ["..i.."] err: \n"..tostring(err))
            end
            break
        end
        sys.sleep(100)
    end

    if shoot_fail then
        -- for practical purposes remove all captures downloaded of this loop
        for i,file in ipairs(saved_files) do
            -- remove(file)
        end
        if break_main_loop then
            return true, true
        else
            return true, false -- capture is not performed but main_loop can continue
        end
    else
        -- TODO confirm saved files
        return false, false, saved_files
    end
end



function rsalt:direct_raw_shoot(lcon, dst_dir, dst)
    con = lcon
    -- from cli.lua names={'remoteshoot','rs'},
    local opts = { 
        fformat=2, --raw
        lstart=0, --s
        lcount=0, --c
        cont=1,
    }
    local opts_s = serialize(opts)

    print('rs_init')
    local status,rstatus,rerr = lcon:execwait('return rs_init('..opts_s..')',{libs={'rs_shoot_diy_init'}})
    if not status then
        return false,rstatus
    end
    if not rstatus then
        return false,rerr
    end

    print('rs_shoot')
    local status,err = lcon:exec('rs_shoot('..opts_s..')',{libs={'rs_shoot_diy'}})
    -- rs_shoot should not initialize remotecap if there's an error, so no need to uninit
    if not status then
        return false,err
    end

    local rcopts={}
    rcopts.raw=rsalt.rc_handler_file(dst_dir,dst)

    print("get data")
    status,err = lcon:capture_get_data(rcopts)
    if not status then
        warnf('capture_get_data error %s\n',tostring(err))
    end

    --
    if opts.cont and not status then
        print('sending stop message\n')
        lcon:write_msg('stop')
    end
    --

    local t0=ustime.new()
    -- wait for shot script to end or timeout
    local wstatus,werr = lcon:wait_status{
        run=false,
        timeout=30000,
    }
    if not wstatus then
        warnf('error waiting for shot script %s\n',tostring(werr))
    elseif wstatus.timeout then
        warnf('timed out waiting for shot script\n')
    end
    printf("wait time %.4f\n",ustime.diff(t0)/1000000)

    local ustatus,uerr = lcon:exec('init_usb_capture(0)') -- try to uninit
    -- if uninit failed, combine with previous status
    if not ustatus then
        uerr = 'uninit '..tostring(uerr)
        status = false
        if err then
            err = err .. ' ' .. uerr
        else 
            err = uerr
        end
        return status, err
    end
    return true
end

function rsalt:direct_shoot(lcon, args)

    con = lcon -- TODO remove this line!!

    if not args.u then
        args.u = 's'
    end
    -- args.tv=false
    -- args.sv=false
    -- args.av=false
    -- args.isomode=false
    -- args.nd=false
    -- args.jpg=false
    --- args.s=false
    --- args.c=false
    --- args.badpix=false

    local dst = args[1]
    local dst_dir
    if dst then
        if string.match(dst,'[\\/]+$') then
            -- explicit / treat it as a directory
            -- and check if it is
            dst_dir = string.sub(dst,1,-2)
            if lfs.attributes(dst_dir,'mode') ~= 'directory' then
                printf('mkdir %s\n',dst_dir)
                local status,err = fsutil.mkdir_m(dst_dir)
                if not status then
                    return false,err
                end
            end
            dst = nil
        elseif lfs.attributes(dst,'mode') == 'directory' then
            dst_dir = dst
            dst = nil
        end
    end

    local opts,err = rsalt:get_shoot_common_opts(args)
    if not opts then
        return false,err
    end

    util.extend_table(opts,{
        fformat=0,
        lstart=0,
        lcount=0,
    })
    -- fformat required for init
    if args.jpg then
        opts.fformat = opts.fformat + 1
    end
    if args.dng then
        opts.fformat = opts.fformat + 6
    else
        if args.raw then
            opts.fformat = opts.fformat + 2
        end
        if args.dnghdr then
            opts.fformat = opts.fformat + 4
        end
    end
    -- default to jpeg TODO won't be supported on cams without raw hook
    if opts.fformat == 0 then
        opts.fformat = 1
        args.jpg = true
    end

    if args.badpix and not args.dng then
        util.warnf('badpix without dng ignored\n')
    end

    if args.s or args.c then
        if args.dng or args.raw then
            if args.s then
                opts.lstart = tonumber(args.s)
            end
            if args.c then
                opts.lcount = tonumber(args.c)
            end
        else
            util.warnf('subimage without raw ignored\n')
        end
    end
    if args.cont then
        opts.cont = tonumber(args.cont)
    end
    local opts_s = serialize(opts)
    printf('rs_init - direct_shoot\n')
    local status,rstatus,rerr = lcon:execwait('return rs_init('..opts_s..')',{libs={'rs_shoot_diy_init'}})
    if not status then
        return false,rstatus
    end
    if not rstatus then
        return false,rerr
    end

    printf('rs_shoot - direct_shoot\n')
    -- TODO script errors will not get picked up here
    local status,err = lcon:exec('rs_shoot('..opts_s..')',{libs={'rs_shoot_diy'}})
    -- rs_shoot should not initialize remotecap if there's an error, so no need to uninit
    if not status then
        return false,err
    end

    local rcopts={}
    if args.jpg then
        rcopts.jpg=rsalt.rc_handler_file(dst_dir,dst)
    end
    if args.dng then
        if args.badpix == true then
            args.badpix = 0
        end
        local dng_info = {
            lstart=opts.lstart,
            lcount=opts.lcount,
            badpix=args.badpix,
        }
        rcopts.dng_hdr = rsalt.rc_handler_store(function(chunk) dng_info.hdr=chunk.data end)
        rcopts.raw = rsalt.rc_handler_raw_dng_file(dst_dir,dst,'dng',dng_info)
    else
        if args.raw then
            rcopts.raw=rsalt.rc_handler_file(dst_dir,dst)
        end
        if args.dnghdr then
            rcopts.dng_hdr=rsalt.rc_handler_file(dst_dir,dst)
        end
    end

    local nshots
    -- TOOO add options for repeated shots not in cont mode
    if opts.cont then
        shot_count = opts.cont
    else
        shot_count = 1
    end
    local status,err
    local shot = 1
    repeat 
        printf('get data %d\n',shot)
        status,err = lcon:capture_get_data(rcopts)
        if not status then
            warnf('capture_get_data error %s\n',tostring(err))
            break
        end
        shot = shot + 1
    until shot > shot_count or not status
    if opts.cont and not status then
        printf('sending stop message\n')
        lcon:write_msg('stop')
    end

    local t0=ustime.new()
    -- wait for shot script to end or timeout
    local wstatus,werr=lcon:wait_status{
        run=false,
        timeout=30000,
    }
    if not wstatus then
        warnf('error waiting for shot script %s\n',tostring(werr))
    elseif wstatus.timeout then
        warnf('timed out waiting for shot script\n')
    end
    printf("wait time %.4f\n",ustime.diff(t0)/1000000)

    local ustatus, uerr = lcon:exec('init_usb_capture(0)') -- try to uninit
    -- if uninit failed, combine with previous status
    if not ustatus then
        uerr = 'uninit '..tostring(uerr)
        status = false
        if err then
            err = err .. ' ' .. uerr
        else 
            err = uerr
        end
    end
    return status, err
end

function rsalt.rc_handler_file(dir,filename_base,ext)
    return function(lcon,hdata)
        local filename,err = rsalt.rc_build_path(hdata,dir,filename_base,ext)
        if not filename then
            return false, err
        end
        printf('rc file %s %d\n',filename,hdata.id)
        
        local fh,err = io.open(filename,'wb')
        if not fh then
            return false, err
        end

        local chunk
        local n_chunks = 0
        -- note only jpeg has multiple chunks
        repeat
            printf('rc chunk get %s %d %d\n',filename,hdata.id,n_chunks)
            chunk,err=lcon:capture_get_chunk(hdata.id)    
            if not chunk then
                fh:close()
                return false,err
            end
            printf('rc chunk size:%d offset:%s last:%s\n',
                        chunk.size,
                        tostring(chunk.offset),
                        tostring(chunk.last))

            if chunk.offset then
                fh:seek('set',chunk.offset)
            end
            if chunk.size ~= 0 then
                chunk.data:fwrite(fh)
            else
                -- TODO zero size chunk could be valid but doesn't appear to show up in normal operation
                util.warnf('ignoring zero size chunk\n')
            end
            n_chunks = n_chunks + 1
        until chunk.last or n_chunks > hdata.max_chunks
        fh:close()
        if n_chunks > hdata.max_chunks then
            return false, 'exceeded max_chunks'
        end
        return true
    end
end

function rsalt:get_shoot_common_opts(args)
    print("---ARGS=\n"..serialize(args))
    if not util.in_table({'s','a','96'},args.u) then
        return false,"invalid units"
    end
    local opts={}
    if args.u == 's' then
        if args.av then
            opts.av=exp.f_to_av96(args.av)
        end
        if args.sv then
            opts.sv=exp.iso_to_sv96(args.sv)
        end2Dlatin
        if args.tv then
            local n,d = string.match(args.tv,'^([%d]+)/([%d.]+)$')
            if n then
                n = tonumber(n)
                d = tonumber(d)
                if not n or not d or n == 0 or d == 0 then
                    return false, 'invalid tv fraction'
                end
                opts.tv = exp.shutter_to_tv96(n/d)
            else
                n = tonumber(args.tv)
                if not n then
                    return false, 'invalid tv value'
                end
                opts.tv = exp.shutter_to_tv96(n)
            end
        end
    elseif args.u == 'a' then
        if args.av then
            opts.av = util.round(args.av*96)
        end
        if args.sv then
            opts.sv = util.round(args.sv*96)
        end
        if args.tv then
            opts.tv = util.round(args.tv*96)
        end
    else
        if args.av then
            opts.av=tonumber(args.av)
        end
        if args.sv then
            opts.sv=tonumber(args.sv)
        end
        if args.tv then
            opts.tv=tonumber(args.tv)
        end
    end
    if args.isomode then
        if opts.sv then
            return false,'set sv or isomode, not both!'
        end
        opts.isomode = tonumber(args.isomode)
    end
    if args.nd then
        local val = ({['in']=1,out=2})[args.nd]
        if not val then
            return false,'invalid ND state '..tostring(args.nd)
        end
        opts.nd = val
    end

    -- hack for CHDK override bug that ignores APEX 0
    -- only used for CHDK 1.1 (API 2.4 and earlier)
    -- if  opts.tv == 0 and not con:is_ver_compatible(2,5) then
    --     opts.tv = 1
    -- end
    return opts
end

function rsalt.rc_build_path(hdata,dir,filename,ext)
    if not filename then
        filename = string.format('IMG_%04d',hdata.imgnum)
    end

    if ext then
        filename = filename..'.'..ext
    else
        filename = filename..'.'..hdata.ext
    end

    if dir then
        filename = fsutil.joinpath(dir,filename)
    end
    return filename
end

function rsalt.rc_handler_store(store)
    return function(lcon,hdata) 
        local store_fn
        if not store then
            store_fn = hdata.store_return
        elseif type(store) == 'function' then
            store_fn = store
        elseif type(store) == 'table' then
            store_fn = function(val)
                table.insert(store,val)
            end
        else
            return false,'invalid store target'
        end
        local chunk
        local n_chunks = 0
        repeat
            local err
            printf('rc chunk get %d %d\n',hdata.id,n_chunks)
            chunk,err=lcon:capture_get_chunk(hdata.id)    
            if not chunk then
                return false,err
            end
            printf('rc chunk size:%d offset:%s last:%s\n',
                        chunk.size,
                        tostring(chunk.offset),
                        tostring(chunk.last))

            chunk.imgnum = hdata.imgnum -- for convenience, store image number in chunk
            local status,err = store_fn(chunk)
            if status==false then -- allow nil so simple functions don't need to return a value
                return false,err
            end
            n_chunks = n_chunks + 1
        until chunk.last or n_chunks > hdata.max_chunks
        if n_chunks > hdata.max_chunks then
            return false, 'exceeded max_chunks'
        end
        return true
    end
end

function rsalt.rc_handler_file(dir,filename_base,ext)
    return function(lcon,hdata)
        local filename,err = rsalt.rc_build_path(hdata,dir,filename_base,ext)
        if not filename then
            return false, err
        end
        printf('rc file %s %d\n',filename,hdata.id)
        
        local fh,err = io.open(filename,'wb')
        if not fh then
            return false, err
        end

        local chunk
        local n_chunks = 0
        -- note only jpeg has multiple chunks
        repeat
            printf('rc chunk get %s %d %d\n',filename,hdata.id,n_chunks)
            chunk,err=lcon:capture_get_chunk(hdata.id)    
            if not chunk then
                fh:close()
                return false,err
            end
            printf('rc chunk size:%d offset:%s last:%s\n',
                        chunk.size,
                        tostring(chunk.offset),
                        tostring(chunk.last))

            if chunk.offset then
                fh:seek('set',chunk.offset)
            end
            if chunk.size ~= 0 then
                chunk.data:fwrite(fh)
            else
                -- TODO zero size chunk could be valid but doesn't appear to show up in normal operation
                util.warnf('ignoring zero size chunk\n')
            end
            n_chunks = n_chunks + 1
        until chunk.last or n_chunks > hdata.max_chunks
        fh:close()
        if n_chunks > hdata.max_chunks then
            return false, 'exceeded max_chunks'
        end
        return true
    end
end

function rsalt.rc_handler_raw_dng_file(dir,filename_base,ext,dng_info)
    return function(lcon,hdata)
        local filename,err = rsalt.rc_build_path(hdata,dir,filename_base,'dng')
        if not filename then
            return false, err
        end
        if not dng_info then
            return false, 'missing dng_info'
        end
        if not dng_info.hdr then
            return false, 'missing dng_hdr'
        end

        printf('rc file %s %d\n',filename,hdata.id)
        
        local fh,err=io.open(filename,'wb')
        if not fh then
            return false, err
        end

        printf('rc chunk get %s %d\n',filename,hdata.id)
        local raw,err=lcon:capture_get_chunk(hdata.id)    
        if not raw then
            return false, err
        end
        printf('rc chunk size:%d offset:%s last:%s\n',
                        raw.size,
                        tostring(raw.offset),
                        tostring(raw.last))
        dng_info.hdr:fwrite(fh)
        --fh:write(string.rep('\0',128*96*3)) -- TODO fake thumb
        local status, err = rsalt.rc_process_dng(dng_info,raw)
        if status then
            dng_info.thumb:fwrite(fh)
            raw.data:fwrite(fh)
        end
        fh:close()
        return status,err
    end
end

function rsalt.rc_process_dng(dng_info,raw)
    local hdr,err=dng.bind_header(dng_info.hdr)
    if not hdr then
        return false, err
    end
    -- TODO makes assumptions about header layout
    local ifd=hdr:get_ifd{0,0} -- assume main image is first subifd of first ifd
    if not ifd then 
        return false, 'ifd 0.0 not found'
    end
    local ifd0=hdr:get_ifd{0} -- assume thumb is first ifd
    if not ifd0 then 
        return false, 'ifd 0 not found'
    end

    raw.data:reverse_bytes()

    local bpp = ifd.byname.BitsPerSample:getel()
    local width = ifd.byname.ImageWidth:getel()
    local height = ifd.byname.ImageLength:getel()

    printf('dng %dx%dx%d\n',width,height,bpp)
    
    -- values are assumed to be valid
    -- sub-image, pad
    if dng_info.lstart ~= 0 or dng_info.lcount ~= 0 then
        -- TODO assume a single strip with full data
        local fullraw = lbuf.new(ifd.byname.StripByteCounts:getel())
        local offset = (width * dng_info.lstart * bpp)/8;
        --local blacklevel = ifd.byname.BlackLevel:getel()
        -- filling with blacklevel would be nicer but max doesn't care about byte order
        fullraw:fill(string.char(0xff),0,offset) -- fill up to data
        -- copy 
        fullraw:fill(raw.data,offset,1)
        fullraw:fill(string.char(0xff),offset+raw.data:len()) -- fill remainder
        -- replace original data
        raw.data=fullraw
    end


    local twidth = ifd0.byname.ImageWidth:getel()
    local theight = ifd0.byname.ImageLength:getel()

    local status, err = pcall(hdr.set_data,hdr,raw.data)
    if not status then
        printf('not creating thumb: %s\n',tostring(err))
        dng_info.thumb = lbuf.new(twidth*theight*3)
        return true -- thumb failure isn't fatal
    end
    if dng_info.badpix then
        printf('patching badpixels: ')
        local bcount=hdr.img:patch_pixels(dng_info.badpix) -- TODO should use values from opcodes
        printf('%d\n',bcount)
    end

    printf('creating thumb: %dx%d\n',twidth,theight)
    -- TODO assumes header is set up for RGB uncompressed
    -- TODO could make a better / larger thumb than default and adjust entries
    dng_info.thumb = hdr.img:make_rgb_thumb(twidth,theight)
    return true
end

local function init()
    chdku.rlibs:register({
        name='rs_shoot_diy',
        depend={'rlib_shoot_common'},
        code=[[
function rs_shoot_single()
    press('shoot_full_only')
    sleep(100)
    release('shoot_full')
end
function rs_shoot_cont(opts)
    local last = get_exp_count() + opts.cont
    press('shoot_half')
    repeat
        m=read_usb_msg(10)
    until get_shooting() or m == 'stop'
    if m == 'stop' then
        release('shoot_half')
        return
    end
    sleep(20)
    press('shoot_full')
    repeat
        m=read_usb_msg(10)
    until get_exp_count() >= last or m == 'stop'
    release('shoot_full')
end
function rs_shoot(opts)
    rlib_shoot_init_exp(opts)
    if opts.cont then
        rs_shoot_cont(opts)
    else
        rs_shoot_single()
    end
end
]]})
    chdku.rlibs:register({
        name='rs_shoot_diy_init',
        code=[[
function rs_init(opts)
    local rec,vid = get_mode()
    if not rec then
        return false,'not in rec mode'
    end
    if type(init_usb_capture) ~= 'function' then
        return false, 'usb capture not supported'
    end
    if bitand(get_usb_capture_support(),opts.fformat) ~= opts.fformat then
        return false, 'unsupported format'
    end
    if not init_usb_capture(opts.fformat,opts.lstart,opts.lcount) then
        return false, 'init failed'
    end
    if opts.cap_timeout then
        set_usb_capture_timeout(opts.cap_timeout)
    end
    if opts.cont then
        if get_prop(require'propcase'.DRIVE_MODE) ~= 1 then
            return false, 'not in continuous mode'
        end
        if opts.cont <= 0 then
            return false, 'invalid shot count'
        end
    end
    return true
end
]]})
end

init()

return rsalt
