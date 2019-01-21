module(...,package.seeall)

require"config"
require"nvm"
require "testUart"
require "testSocket"


local conf = {}
local cf = "config"
local u1p, u2p = 0, 0


function ConfInit()
    conf[0] = "123"
    conf[1] = "{\"id\":\"1\", \"prot\":\"nil\", \"ping\":\"nil\",\"keepalive\":\"60\",\"address\":\"nil\",\"port\":\"0\", \"uid\":\"0\", \"status\":\"off\"}"
    conf[2] = "{\"id\":\"2\", \"prot\":\"nil\", \"ping\":\"nil\",\"keepalive\":\"60\",\"address\":\"nil\",\"port\":\"0\", \"uid\":\"0\", \"status\":\"off\"}"
    conf[3] = "{\"id\":\"3\", \"prot\":\"nil\", \"ping\":\"nil\",\"keepalive\":\"60\",\"address\":\"nil\",\"port\":\"0\", \"uid\":\"0\", \"status\":\"off\"}"
    conf[4] = "{\"id\":\"4\", \"prot\":\"nil\", \"ping\":\"nil\",\"keepalive\":\"60\",\"address\":\"nil\",\"port\":\"0\", \"uid\":\"0\", \"status\":\"off\"}"
    conf[5] = "{\"id\":\"5\", \"prot\":\"nil\", \"ping\":\"nil\",\"keepalive\":\"60\",\"address\":\"nil\",\"port\":\"0\", \"uid\":\"0\", \"status\":\"off\"}"
    conf[6] = "{\"id\":\"6\", \"prot\":\"nil\", \"ping\":\"nil\",\"keepalive\":\"60\",\"address\":\"nil\",\"port\":\"0\", \"uid\":\"0\", \"status\":\"off\"}"
    conf[7] = "{\"id\":\"7\", \"prot\":\"nil\", \"ping\":\"nil\",\"keepalive\":\"60\",\"address\":\"nil\",\"port\":\"0\", \"uid\":\"0\", \"status\":\"off\"}"

    conf[8] = "{\"id\":\"8\", \"baudrate\":\"0\",  \"datbits\":\"0\",   \"parity\":\"0\",  \"stopbits\":\"0\",  \"status\":\"off\"}"
    conf[9] = "{\"id\":\"9\", \"baudrate\":\"0\",  \"datbits\":\"0\",   \"parity\":\"0\",  \"stopbits\":\"0\",  \"status\":\"off\"}"
end


function NvmInit()
    --log.info("Conf","NvmInit")
    nvm.init("config.lua")
    local c = nvm.get(cf)
    if c == nil then
        log.info("Conf", "Conf Init")
        ConfInit()
        NvmSetConf()
    else
        log.info("Conf", "Read Old Conf")
        conf = c
    end
end

function NvmSetConf()
    nvm.set(cf, conf)
    nvm.flush()
end

function SetConf(newconf, i)
    if type(i) ~= "number" then 
        log.info("conf", "i is not number")
        return false 
    elseif i < 0 or i > 9 then
        log.info("conf", "i < 0 or i > 9")
        return false
    end
    
    conf[i] = newconf
    NvmSetConf()
    return true
end

function NvmGetConf(id)
    local t = {}
    t = nvm.get(cf)
    if t == nil then
        log.info("Conf", "Conf Table is nil")
        return false
    end
    return t[id]
end

function GetConf(id)
    return NvmGetConf(id)
end

function GetAllConf()
    local t = nvm.get(cf)
    local ret = ""
    for i=1,9,1 do
        ret = ret .. t[i] .. " "
    end
    return  ret
end

function RunAll()
    local t = nvm.get(cf)

    for i=1,9,1 do
        local tjsondata,result,errinfo = json.decode(t[i])
        if result and type(tjsondata)=="table" then                    
            if tjsondata["status"] == "on" then
                if i <= 7 then
                    local id,prot,ping,keepalive,address,port,uid = tjsondata["id"], tjsondata["prot"],tjsondata["[ping"], tjsondata["keepalive"],tjsondata["address"],tjsondata["port"],tjsondata["uid"]
                    local usr,pwd,cleansession,sub,pub,qos,retain = tjsondata["usr"],tjsondata["pwd"],tjsondata["cleansession"],tjsondata["sub"],tjsondata["pub"],tjsondata["qos"],tjsondata["retain"]
                    id = tonumber(id)
                    keepalive = tonumber(keepalive)
                    port = tonumber(port)
                    uid = tonumber(uid)
                    cleansession = tonumber(cleansession)
                    qos = tonumber(qos)
                    retain = tonumber(retain)

                    if tjsondata["prot"] == "tcp" or tjsondata["prot"] == "udp" then
                        log.info("RunALL",id,prot,ping,keepalive,address,port,uid)
                        testSocket.ChannelInit(id,prot,ping,keepalive,address,port,uid)
                    elseif prot == "mqtt" then
                        testSocket.MqttChannelInit(id, prot, keepalive, address, port, uid, usr, pwd, cleansession, sub, pub, qos, retain)
                    end
                else
                    local id, baudrate, datbits, parity,stopbits = tjsondata["id"], tjsondata["baudrate"], tjsondata["datbits"], tjsondata["parity"], tjsondata["stopbits"]
                    local uartid  = tonumber(id) - 7
                    baudrate = tonumber(baudrate)
                    datbits = tonumber(datbits)
                    parity = tonumber(parity) 
                    stopbits = tonumber(stopbits)
                    log.info("Conf", "uart", uartid, baudrate, datbits, parity, stopbits)
                    testUart.UartInit(uartid, baudrate, datbits, parity, stopbits)
                end
            end
        end
    end
end

function StopAll()
    local t = nvm.get(cf)

    for i=1,9,1 do
        local tjsondata,result,errinfo = json.decode(t[i])
        if result and type(tjsondata)=="table" then                    
            if tjsondata["status"] == "on" then
                local s = "{\"cmd\":\"config\",\"id\":\""..i.."\",\"status\":\"stop\"}"
                log.info("Stop All", s)
                if i <= 7 then
                    ret = testSocket.ChannelConfig(s)
                else
                    ret = testUart.UartConfig(s)
                end
                log.info("Stop All", ret)
            end
        end
    end
end

function Restore()
    StopAll()
end

function SyncPassthrough()
    for i=1,7,1 do
        local tjsondata,result,errinfo = json.decode(conf[i])
        if result and type(tjsondata)=="table" then                    
            if tjsondata["status"] == "on" then
                local id = tjsondata["uid"]
                id = tonumber(id)
                if id == 1 then u1p = 1 end
                if id == 2 then u2p = 1 end  
            end
        end
    end
end

function SetPassThrough(uid, val)
    if uid == 1 then
        u1p = val
    elseif uid == 2 then
        u2p = val
    end
end

function GetPassThrough(uid)
    if uid == 1 then
        return u1p
    elseif uid == 2 then
        return u2p
    else
        return 0
    end
end


