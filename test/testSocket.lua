--- testSocket
-- @module asyncSocket
-- @author AIRM2M
-- @license MIT
-- @copyright openLuat.com
-- @release 2018.10.27
require "socket"
module(..., package.seeall)

local ut1, ut2 = "", ""


local ID_NOT_EXIST = "ID NOT EXIST"
local ID_VAL = "CHANNEL ID VAL 1~7, UARTID 8/9"

local PROT_NOT_EXIST = "PROT NOT EXIST"
local PROT_VAL = "PROT VAL tcp/udp/mqtt"

local KEEPALIVE_VAL = "KEEPALIVE VAL 60~600"

local ADDRESS_NOT_EXIST = "ADDRESS NOT EXIST"

local PORT_NOT_EXIST = "PORT NOT EXIST"
local PORT_VAL = "PORT VAL 1000~65535"

local UID_NOT_EXIT = "UID NOT EXIST"
local UID_VAL = "UID 0/1/2"

local ALREADY_ON = "ALREADY ON"

local READ_CONF_ERR = "Read Config Error"

local UID1_BUSY = "UID1 BUSY "
local UID2_BUSY = "UID2 BUSY "

local chstopflag,chrstopflag = 0,0

local _uid1, _uid2 = 0,0

-- MQTT通道配置
local function MqttChannelTask(mqttconf)
    --log.info("MqttChannelTask", mqttconf["id"], mqttconf["id"], mqttconf["prot"], mqttconf["keepalive"],  mqttconf["address"],    mqttconf["port"], mqttconf["uid"],
           -- mqttconf["usr"], mqttconf["pwd"], mqttconf["cleansession"], mqttconf["sub"], mqttconf["pub"], mqttconf["qos"], mqttconf["retain"])
    local id = mqttconf["id"]
    local prot = mqttconf["prot"]
    local keepalive = mqttconf["keepalive"]
    local address = mqttconf["address"]
    local port = mqttconf["port"]
    local uid = mqttconf["uid"]
    local usr = mqttconf["usr"]
    local pwd = mqttconf["pwd"]
    local cleansession = mqttconf["cleansession"]
    local sub = mqttconf["sub"]
    local pub = mqttconf["pub"]
    local qos = mqttconf["qos"]
    local retain = mqttconf["retain"]
    
            
    while not socket.isReady() do sys.wait(1000) end
    --log.info("testSocket","mqtt task", id, prot, keepalive, address, port, uid, usr, pwd, cleansession, sub, pub, qos, retain)


    _G["asyncClient"..id] = mqtt.client(misc.getImei().."sub"..id, keepalive, usr, pwd, cleansession)

    while true do
        while not _G["asyncClient"..id]:connect(address, port, "tcp") do sys.wait(2000) end
        --while not _G["asyncClient"..id.."pub"]:connect(address, port, "tcp") do sys.wait(2000) end

        if _G["asyncClient"..id]:subscribe(sub, qos) then
            while true do
                local r, data = _G["asyncClient"..id]:receive(2000)
                if r then
                    log.info("这是收到了服务器下发的消息:", data.payload or "nil")
                    if uid == 1 or uid == 2 then
                        sys.publish("SOCKET_RECV_DATA", uid, data.payload)
                    else
                        sys.publish("SOCKET_RECV_DATA", uid, "recv,"..id..","..data.payload)
                    end
                elseif data == "timeout" then
                    --log.info("这是等待超时主动上报数据的显示!")
                    --sys.wait(1000)
                else
                    sys.wait(3000)
                    -- 网络链接被断开
                    break
                end

                --获取绑定隧道的数据
                if _G["ut"..id] ~= "" and _G["ut"..id] ~= nil then
                    _G["asyncClient"..id]:publish(pub, _G["ut"..id])
                    _G["ut"..id] = ""
                end

                if type(chstopflag) == "string" then
                    chstopflag = tonumber(chstopflag)
                end

                if chstopflag == id then
                    break
                end              
            end
        end

        _G["asyncClient"..id]:disconnect()
        if chstopflag == id then
            log.info("testSocket", "mqtt client disconnect")

            _G["asyncClient"..id] = nil  --client清空
            _G["ut"..id] = nil --client->server buf清空
            chstopflag = 0
            sys.publish("CH_STOP", id)
            break
        end
    end
end

function MqttChannelInit(id, prot, keepalive, address, port, uid, usr, pwd, cleansession, sub, pub, qos, retain)
    --uart绑定初始化
    if uid == 1 then
        _uid1 = id
    elseif uid == 2 then
        _uid2 = id
    end

    --log.info("testSocket","mqtt task init", id, prot, keepalive, address, port, uid, usr, pwd, cleansession, sub, pub, qos, retain)
    local mqttconf = {}
    mqttconf["id"] = id
    mqttconf["prot"] = prot
    mqttconf["keepalive"] = keepalive
    mqttconf["address"] = address
    mqttconf["port"] = port
    mqttconf["uid"] = uid
    mqttconf["usr"] = usr
    mqttconf["pwd"] = pwd
    mqttconf["cleansession"] = cleansession
    mqttconf["sub"] = sub
    mqttconf["pub"] = pub
    mqttconf["qos"] = qos
    mqttconf["retain"] = retain

    sys.taskInit(MqttChannelTask, mqttconf)
--    sys.taskInit(MqttChannelSend, mqttconf)    
end

--TCP/UDP 通道配置
local function ChannelTask(id,prot,ping,keepalive,address,port,uid)
    --log.info("testSocket", "taskid", "asyncClient"..id )
    while true do
        while not socket.isReady() do sys.wait(1000) end
        --_G["asyncClient"..id][id] = socket.tcp()
        if prot == "tcp" then
            _G["asyncClient"..id] = socket.tcp()
        elseif prot == "udp" then
            _G["asyncClient"..id] = socket.udp()
        end

        while not _G["asyncClient"..id]:connect(address, port) do sys.wait(2000) end

        while _G["asyncClient"..id]:asyncSelect(keepalive, ping) do end

        if type(chstopflag) == "string" then
            chstopflag = tonumber(chstopflag)
        end

        if chstopflag == id then
            log.info("testSocket", " close socket channel")
            _G["asyncClient"..id]:close()
            sys.wait(100)
            _G["asyncClient"..id] = nil
            chstopflag = 0
            sys.publish("CH_STOP", id)
            break
        end
        _G["asyncClient"..id]:close()
    end
end

local function ChannelRecv(id, uid)
    local cacheData = ""
    while not socket.isReady() do sys.wait(2000) end

    while true do
        --log.info("testSocket", "recv task")
        if type(chrstopflag) == "string" then
            chrstopflag = tonumber(chrstopflag)
        end

        if chrstopflag == id then
            log.info("testSocket", " close RECV")
            sys.wait(100)
            chrstopflag = 0
            sys.publish("CHR_STOP", id)
            break
        end
        
        if _G["asyncClient"..id] ~= nil then
            local cacheData = _G["asyncClient"..id]:asyncRecv()
            if cacheData == "" then
                --log.info("testScoket", "Recv Nil, sleep")
                sys.wait(1000)
            else
                log.info("testSocket", "SOCKET RECV DATA", cacheData)
                if uid == 1 or uid == 2 then
                    sys.publish("SOCKET_RECV_DATA", uid, cacheData)
                else
                    sys.publish("SOCKET_RECV_DATA", uid, "recv,"..id..","..cacheData)
                end
            end
        else
            sys.wait(500)
        end
        cacheData = ""
    end
end


function ChannelInit(id,prot,ping,keepalive,address,port,uid)
    --uart绑定初始化
    if uid == 1 then
        _uid1 = id
    elseif uid == 2 then
        _uid2 = id
    end

    _G["ch"..id] = sys.taskInit(ChannelTask, id,prot,ping,keepalive,address,port,uid)

    --接收
    --if uid ~= 0 then
    sys.taskInit(ChannelRecv, id, uid)
    --end
end


-- 通道初始化
function ChannelConfig(param)
    local tjsondata,result,errinfo = json.decode(param)
    local id,prot,ping,keepalive,address,port,uid = tjsondata["id"],tjsondata["prot"],tjsondata["ping"],tjsondata["keepalive"],tjsondata["address"],tjsondata["port"],tjsondata["uid"]
    --mqtt
    local usr,pwd,cleansession,sub,pub,qos,retain = tjsondata["usr"], tjsondata["pwd"], tjsondata["cleansession"], tjsondata["sub"], tjsondata["pub"], tjsondata["qos"], tjsondata["retain"]

    local torigin = {}

    local status = tjsondata["status"]
    if result and type(tjsondata)=="table" then
        --首先获取channel id
        id = tonumber(id)
        if id == nil then 
            return ID_NOT_EXIST
        elseif(id < 1 or id > 7) then
            return ID_VAL
        end

        --查询该通道配置
        local oldconf = conf.GetConf(id)
        local confdata,confresult,conferrinfo = json.decode(oldconf)
        if not confresult then
            log.info("testSocket", conferrinfo)
            return READ_CONF_ERR
        end
        
        --判断是否重复开启
        if confdata["status"] == "on" and status ~= "stop" then
            return "CHANNEL "..id.." "..ALREADY_ON
        end


        --判断是否停止该通道
        if status == "stop" then
            --判断是否重复停止
            if confdata["status"] == "off" then
                return "CHANNEL "..id.." ".."STOP OK"
            end

            --如果已经启用
            --1 清除uart绑定
            if _uid1 == id then
                _uid1 = 0
            elseif _uid2 == id then
                _uid2 = 0
            end

            local oldprot = confdata["prot"]
           
            
            --2 tcp/udp停止recv task
            if oldprot == "tcp" or oldprot == "udp" then
                chrstopflag = id -- stop channel recv task
                if not sys.waitUntil("CHR_STOP", 3000) then
                    return "STOP Channel "..id.." FAIL" .. " wait for [CHR]"
                end
            end

            --3 tcp/udp停止通道select task,mqtt直接停止
            chstopflag = id -- stop channel select task

            if oldprot == "tcp" or oldprot == "udp" then
                coroutine.resume(_G["ch"..id])
            end

            if not sys.waitUntil("CH_STOP", 3000) then
                return "STOP Channel "..id.." FAIL" .. " wait for [CH]"
            end

            if confdata["uid"] == "1" then conf.SetPassThrough(1, 0)
            elseif confdata["uid"] == "2" then conf.SetPassThrough(2,0)
            end

            --4 设置配置文件
            local torigin = {
                id = tostring(id),
                status = "off",
            }
    
            local newconf = json.encode(torigin)                                                                                                            

            if not conf.SetConf(newconf, id) then
                log.info("testSocket", "Set Stop Conf Err", conf.GetConf(id))
                return "Set Conf Err"
            end

            --socket.printStatus()
            return "STOP Channel "..id.." OK"
        end

        --通用参数
        if address == nil then
            return ADDRESS_NOT_EXIST
        end

        port = tonumber(port)
        if port == nil then
            return PORT_NOT_EXIST
        elseif port < 1000 or port > 65535 then
            return PORT_VAL
        end

        uid = tonumber(uid)
        if uid == nil then
            return UID_NOT_EXIT
        elseif uid ~= 0 and uid ~= 1 and uid ~= 2 then
            return UID_VAL
        end

        if uid == 1 and _uid1 ~= 0 then
            return UID1_BUSY .. _uid1
        elseif uid == 2 and _uid2 ~= 0 then
            return UID2_BUSY .. _uid2
        end

        --ignore ping

        --ignore keepalive nil
        keepalive = tonumber(keepalive)
        if keepalive == nil then
        elseif keepalive < 60 or keepalive > 600 then
            return KEEPALIVE_VAL
        end

        if prot == nil then
            return PROT_NOT_EXIST
        elseif prot == "tcp"  or prot == "udp" then
            if prot == "udp" then
                return "UDP NOT SUPPORT"
            end
            --tcp/udp 参数
        elseif prot == "mqtt" then
            --mqtt参数
            --ignore usr
            --ignore pwd

            --cleansession MQTT是否保存会话标志位

            if sub == nil then
                return SUB_NOT_EXIST
            end

            if pub == nil then
                return SUB_NOT_EXIST
            end
            
            qos = tonumber(qos)
            if qos == nil then
                qos = 0
            elseif qos ~= 0 and qos ~= 1 and qos ~= 2 then
                return QOS_VAL
            end

            retain = tonumber(retain)
            if retain == nil then
                retain = 0
            elseif retain ~= 0 and retain ~= 1 then
                return RETAIN_VAL
            end

        else
            return PROT_VAL
        end

        --log.info("testSocket", id, prot, keepalive, address, port, uid, usr, pwd, cleansession, sub, pub, qos, retain)
        

        if prot == "tcp" or prot == "udp" then
            ChannelInit(id, prot, ping, keepalive, address, port, uid)
        elseif prot == "mqtt" then
            MqttChannelInit(id, prot, keepalive, address, port, uid, usr, pwd, cleansession, sub, pub, qos, retain)
        end
        
        conf.SetPassThrough(uid, 1)

        if prot == "tcp" or prot == "udp" then
            torigin = {
                id = tostring(id),
                prot = prot,
                ping =  ping,
                keepalive = tostring(keepalive),
                address = address,
                port = tostring(port),
                uid = tostring(uid),
                status = "on",
            }
        elseif prot == "mqtt" then
            torigin = {
                id = tostring(id),
                prot = prot,
                ping =  ping,
                keepalive = tostring(keepalive),
                address = address,
                port = tostring(port),
                uid = tostring(uid),
                usr = usr, 
                pwd = pwd, 
                cleansession = tostring(cleansession), 
                sub = sub, 
                pub = pub, 
                qos = tostring(qos), 
                retain = tostring(retain),
                status = "on",
            }
        end

        local newconf = json.encode(torigin)                                                                                                            
  
        if not conf.SetConf(newconf, id) then
            log.info("testSocket", "Set Init Conf Err")
            return "Set Conf Err"
        end

        return "Channel "..id.." init OK"
    else
        return JSON_FORMAT_ERR
    end
end

--[[
sys.timerLoopStart(function()
    log.info("打印占用的内存:", _G.collectgarbage("count"))-- 打印占用的RAM
    log.info("打印可用的空间", rtos.get_fs_free_size())-- 打印剩余FALSH，单位Byte
end, 1000)
--]]

--UART接收数据处理
local function data_proc(uid, data)
    log.info("testSocket", "Socket Process data", uid, type(uid), data, type(data))
    
    local cnt = 0
    while not socket.isReady() 
    do 
        if cnt >= 5 then return end
        sys.wait(1000) 
        cnt = cnt + 1
    end 

    if uid == 1 then
        if _G["asyncClient".._uid1] ~= nil then
            local oldconf = conf.GetConf(_uid1)
            local confdata,confresult,conferrinfo = json.decode(oldconf)
            if not confresult then
                log.info("testSocket", conferrinfo)
                return READ_CONF_ERR
            end

            if confdata["prot"] == "tcp" then
                _G["asyncClient".._uid1]:asyncSend(data)
            elseif confdata["prot"] == "mqtt" then
                local pub = confdata["pub"]
                if pub ~= nil and pub ~= "" then
                    if _G["ut".._uid1] == nil then
                        _G["ut".._uid1] =  data
                    else
                        _G["ut".._uid1] = _G["ut".._uid1] .. data
                    end
                end
            end
        end
    elseif uid == 2 then
        if _G["asyncClient".._uid2] ~= nil then
            local oldconf = conf.GetConf(_uid2)
            local confdata,confresult,conferrinfo = json.decode(oldconf)
            if not confresult then
                log.info("testSocket", conferrinfo)
                return READ_CONF_ERR
            end

            if confdata["prot"] == "tcp" then
                _G["asyncClient".._uid2]:asyncSend(data)
            elseif confdata["prot"] == "mqtt" then
                local pub = confdata["pub"]
                if pub ~= nil and pub ~= "" then
                    if _G["ut".._uid2] == nil then
                        _G["ut".._uid2] =  data
                    else
                        _G["ut".._uid2] = _G["ut".._uid2] .. data
                    end
                end
            end
        end
    else
        --没有通道绑定当前UART
    end
end

--多通道发送
function SendMultiChannel(payload)
    local tjsondata,result,errinfo = json.decode(payload)
    local id, data = tjsondata["id"], tjsondata["data"]
    if result and type(tjsondata)=="table" then
        id = tonumber(id)
        if id == nil then 
            return ID_NOT_EXIST
        elseif(id < 1 or id > 7) then
            return ID_VAL
        end

        if data == nil or data == "" then
            return "DATA IS NIL"
        end
    else
        return "Multi Send ForMat Err"
    end


    local oldconf = conf.GetConf(id)
    local confdata,confresult,conferrinfo = json.decode(oldconf)
    if confresult and type(confdata)=="table" then
        if confdata["status"] == "on" then
            if confdata["prot"] == "tcp" or confdata["prot"] == "udp" then
                log.info("testSocket", "MultiSend", id, "data", data)
                _G["asyncClient"..id]:asyncSend(data)
            elseif confdata["prot"] == "mqtt" then
                local pub = confdata["pub"]
                if pub ~= nil and pub ~= "" then
                    log.info("testSocket", "MultiSend", id, "data", data)
                    if _G["ut"..id] == nil then
                        _G["ut"..id] = data
                    else
                        _G["ut"..id] = _G["ut"..id] .. data
                    end
                end
            else
                return "Channel Not Run"
            end
        end
    else
        return "Read Conf Err"
    end


    return "Send OK"
end


sys.subscribe("UART_RECV_DATA", data_proc)  