require "pins"
require "conf"

function setpindir()
    pio.pin.setdir(pio.INPUT, pio.P0_6)
    pio.pin.setdir(pio.OUTPUT, pio.P0_7)
end

function setpinval()
    pio.pin.sethigh(pio.P0_7)
    --pio.pin.setlow(pio.P0_6)
end

function getpinval()
    local v = 0
    v = pio.pin.getval(pio.P0_6)
    return v
end

--[[
sys.taskInit(
    function()
        sys.wait(2000) 
        local c, cnt = 0, 0
        setpindir()
        setpinval()
        while true do
            if cnt == 5 then
                --conf.Restore()
                break
            end

            c = getpinval()
            if c == 0 then sys.publish("IOTEST", "Normal Start") break end
            
            sys.wait(1000)
            cnt = cnt + 1
        end
    end
)
--]]