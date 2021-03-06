--- 模块功能：MQTT客户端数据发送处理
-- @author openLuat
-- @module mqtt.mqttOutMsg
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28


module(...,package.seeall)
require "misc"

--数据发送的消息队列
local msgQueue = {}
--[[
local function insertMsg(topic,payload,qos,user)
    table.insert(msgQueue,{t=topic,p=payload,q=qos,user=user})
end

local function pubQos0TestCb(result)
    log.info("mqttOutMsg.pubQos0TestCb",result)
    if result then sys.timerStart(pubQos0Test,10000) end
end

function pubQos0Test()
    insertMsg("/qos0topic","qos0data",0,{cb=pubQos0TestCb})
end

local function pubQos1TestCb(result)
    log.info("mqttOutMsg.pubQos1TestCb",result)
    if result then sys.timerStart(pubQos1Test,20000) end
end

function pubQos1Test()
    insertMsg("/中文qos1topic","中文qos1data",1,{cb=pubQos1TestCb})
end

--- 初始化“MQTT客户端数据发送”
-- @return 无
-- @usage mqttOutMsg.init()
function init()
    pubQos0Test()
    pubQos1Test()
end

--- 去初始化“MQTT客户端数据发送”
-- @return 无
-- @usage mqttOutMsg.unInit()
function unInit()
    sys.timerStop(pubQos0Test)
    sys.timerStop(pubQos1Test)
    while #msgQueue>0 do
        local outMsg = table.remove(msgQueue,1)
        if outMsg.user and outMsg.user.cb then outMsg.user.cb(false,outMsg.user.para) end
    end
end

--- MQTT客户端是否有数据等待发送
-- @return 有数据等待发送返回true，否则返回false
-- @usage mqttOutMsg.waitForSend()
function waitForSend()
    return #msgQueue > 0
end

--- MQTT客户端数据发送处理
-- @param mqttClient，MQTT客户端对象
-- @return 处理成功返回true，处理出错返回false
-- @usage mqttOutMsg.proc(mqttClient)
--]]


function proc(mqttClient, InMsg)
    --[[while #msgQueue>0 do
        local outMsg = table.remove(msgQueue,1)
        local result = mqttClient:publish(outMsg.t,outMsg.p,outMsg.q)
        if outMsg.user and outMsg.user.cb then outMsg.user.cb(result,outMsg.user.para) end
        if not result then return end
    end--]]
    if type(InMsg) == "number" then InMsg = tostring(InMsg) end
    local result = mqttClient:publish("/dev/pub/"..misc.getImei(), InMsg, 0)
    if not result then return end
    return result
end