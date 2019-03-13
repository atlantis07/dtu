--- 模块功能：串口功能测试(TASK版)
-- @author openLuat
-- @module uart.testUartTask
-- @license MIT
-- @copyright openLuat
-- @release 2018.10.20
require "utils"
require "pm"
require "pins"
require "conf"
require "misc"
require "dlt"

module(..., package.seeall)

local stopflag = 0
local writeBuff = {{}, {}}

local JSON_FORMAT_ERR = "JSON_FORMAT_ERR"
local UARTID_NOT_EXIST = "UARTID_NOT_EXIST"
local UARTID_VAL = "UARTID_VAL 8/9"
local BAUDRATE_NOT_EXIST = "BAUDRATE_NOT_EXIST"
local BAUDRATE_VAL = "BAUDRATE_VAL 1200 ~ 921600"
local DATBITS_NOT_EXIST = "DATBITS_NOT_EXIST"
local DATBITS_VAL = "DATBITS_VAL 7/8"
local PARITY_NOT_EXIST = "PARITY_NOT_EXIST"
local PARITY_VAL = "PARITY_VAL 0/1/2"
local STOPBITS_NOT_EXIST = "STOPBITS_NOT_EXIST"
local STOPBITS_VAL = "STOPBITS 0/2"
local UART_STOP_OK = "STOP OK"
local UART_STOP_FAIL = "STOP FAIL"

local function UartPreInit(uid, data)
    local ret = ""
    local tjsondata,result,errinfo = json.decode(data)
    if result and type(tjsondata)=="table" then
        if tjsondata["cmd"] == "config" then
            if tjsondata["id"] == "8" or tjsondata["id"] == "9" then
                ret = testUart.UartConfig(data)
            else
                ret = testSocket.ChannelConfig(data)
                --log.info("mqttInMsg config", "channel 1 ~ 7")
            end
        elseif tjsondata["cmd"] == "send" then
            ret = ""
            testSocket.SendMultiChannel(data)
        elseif tjsondata["cmd"] == "http" then
            ret = testHttp.proc(data)
        elseif tjsondata["cmd"] == "gettime" then
            ret = testClock.getTime()
        elseif tjsondata["cmd"] == "getlocation" then
            ret = testLbsLoc.reqLbsLoc()
        elseif tjsondata["cmd"] == "p" then
            socket.printStatus()
        elseif tjsondata["cmd"] == "getconf" then
            ret = conf.GetAllConf(tjsondata["id"])
        elseif tjsondata["cmd"] == "getimei" then
            ret = misc.getImei()
        elseif tjsondata["cmd"] == "+++" then
            conf.Restore()
        end
    else
        ret = "json parse err"
        log.info("mqttInMsg json parse err", errinfo)
    end

    if ret ~= "" then
        uart.write(uid, ret)
    end
end

local function taskRead(uartID)
    local cacheData = ""
    while true do
        if stopflag == uartID then
            uart.close(uartID)
            pm.sleep("mcuart")
            sys.publish("UART_STOP","uart stop")
            break  
        end

        local s = uart.read(uartID,"*l")
        --电表参数处理
        if dlt.GetProcFlag() == 1 then
            if s ~= "" then
                dlt.adddlt(s)
            end
        end

        --log.info("uart", uartID, s)

        if conf.GetPassThrough(uartID) == 0 then --非透传模式
            if s == "" then
                sys.wait(1000)
            else
                --log.info("testUart", "No Passthrough Mode")
                --log.info("testUart", s)
                UartPreInit(uartID,s)
                s = ""
            end
        else 
                if s == "" then
                    uart.on(uartID,"receive",function() sys.publish("UART_RECEIVE") end)
                    if not sys.waitUntil("UART_RECEIVE",1000) then
                        if cacheData:sub(1,1024) ~= "" then
                            log.info("UART "..uartID.." PUBLISH")
                            sys.publish("UART_RECV_DATA", uartID, cacheData:sub(1,1024))
                            cacheData = cacheData:sub(1025,-1)
                        end
                        --cacheData = cacheData:sub(1025,-1)
                    end
                    uart.on(uartID,"receive")
                else
                    log.info("uart read", s)
                    cacheData = cacheData..s
                    if cacheData:len()>=1024 then
                        log.info("UART "..uartID.." PUBLISH")
                        sys.publish("UART_RECV_DATA", uartID, cacheData:sub(1,1024))
                        cacheData = cacheData:sub(1025,-1)
                    end
                end
        end
    end
    stopflag = 0
end


function UartInit(id, baudrate, datbits, parity, stopbits)
    log.info("testUart", "UART_INIT")
    pm.wake("mcuart")
    --保持系统处于唤醒状态，不会休眠
    log.info("uart",  baudrate, datbits, parity, stopbits)
    local realbaud = uart.setup(id, baudrate, datbits, parity, stopbits, nil, 1)
    sys.taskInit(taskRead, id)
    --log.info("testUart realbaud", realbaud)
    return realbaud
end

function UartStop(id)
    stopflag = id

    if not sys.waitUntil("UART_STOP", 2000) then
        --log.info("testUart", "stop failed")
        return UART_STOP_FAIL
    else
        --log.info("testUart", "stop ok")
        return UART_STOP_OK
    end
end

function UartConfig(param)
    local respone = ""
    local ret = 0
    local realbaud = 0

    local tjsondata,result,errinfo = json.decode(param)
    local id,baudrate,datbits,parity,stopbits,status = tjsondata["id"], tjsondata["baudrate"], tjsondata["datbits"],tjsondata["parity"], tjsondata["stopbits"], tjsondata["status"]
    local uartid

    if result and type(tjsondata)=="table" then

        id = tonumber(id)
        uartid = id - 7

        if status == "stop" then
            ret = UartStop(uartid)
            local torigin = {
                id = tostring(id),
                --[[
                baudrate = tostring(0),
                databits =  tostring(0),
                parity = tostring(0),
                stopbits = tostring(0),
                --]]
                status = "off",
            }

            local newuartconf = json.encode(torigin)                                                                                                            
      
            if not conf.SetConf(newuartconf, id) then
                log.info("testUart", "set conf fail")
            end
            return ret
        end

        baudrate = tonumber(baudrate)
        if baudrate == nil then 
            return BAUDRATE_NOT_EXIST
        elseif(baudrate < 1200 or baudrate > 921600) then
            return BAUDRATE_VAL
        end

        
        datbits = tonumber(datbits)
        if datbits == nil then
            return DATBITS_NOT_EXIST
        elseif(datbits ~= 7 and datbits ~= 8) then
            return DATBITS_VAL
        end

        parity = tonumber(parity)
        if parity == nil then
            return PARITY_NOT_EXIST
        elseif(parity ~= 0 and parity ~= 1 and parity ~= 2) then
            return PARITY_VAL
        end
        
        stopbits = tonumber(stopbits)
        if stopbits == nil then
            return STOPBITS_NOT_EXIST
        elseif(stopbits ~= 0 and stopbits ~= 2) then
            return STOPBITS_VAL
        end

        --[[
        log.info("uart param", uartid, baudrate, datbits, parity, stopbits)
        log.info("uart default", uart.PAR_EVEN, uart.PAR_ODD,uart.PAR_NONE, uart.STOP_1,uart.STOP_2)
        --]]

        log.info("uart param", id, uartid, baudrate, datbits, parity, stopbits)

        local uartconf = conf.GetConf(id)
        --log.info("testUart old conf", uartconf)
        local confdata,confresult,conferrinfo = json.decode(uartconf)
        if not confresult then
            log.info("testUart", conferrinfo)
            return
        end
        
        if confdata["status"] == "on" then
            return "ALREADY ON"
        end

        realbaud = UartInit(uartid, baudrate, datbits, parity, stopbits)
        if type(realbaud) == "number" and realbaud > 0 then
            local torigin = {
                id = tjsondata["id"],
                baudrate = tostring(realbaud),
                datbits =  tjsondata["datbits"],
                parity = tjsondata["parity"],
                stopbits = tjsondata["stopbits"],
                status = "on",
            }

            local newuartconf = json.encode(torigin)                                                                                                            
      
            if not conf.SetConf(newuartconf, id) then
                log.info("testUart", "set conf fail")
                return UartStop(uartid)
            end

            --log.info("testUart new conf", conf.GetConf(id))

        end
    else
        return JSON_FORMAT_ERR
    end

    return realbaud
end


local function socketRecvData(uid, data)
    uid = tonumber(uid)
    if uid ~= 1 and uid ~= 2 then
        log.info("testSocket", "recv socket", uid, data)
        uart.write(2, data)
    else
        log.info("testUart", "write", uid, "data", data:toHex())
        uart.write(uid, data)
    end
end

local function  net_state()
    log.info("net", "register")
end

sys.subscribe("SOCKET_RECV_DATA",socketRecvData)

sys.subscribe("NET_STATUS_IND", net_state)