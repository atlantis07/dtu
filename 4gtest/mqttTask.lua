--- 模块功能：MQTT客户端处理框架
-- @author openLuat
-- @module mqtt.mqttTask
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28

module(...,package.seeall)

require "misc"
require "mqtt"

require "mqttOutMsg"
require "mqttInMsg"

require "aLiYun"
require "aLiYunOta"

local ready = false

--- MQTT连接是否处于激活状态
-- @return 激活状态返回true，非激活状态返回false
-- @usage mqttTask.isReady()
function isReady()
    return ready
end


function getDeviceNameFnc()
    return "2gDTU"
end

function getDeviceSecretFnc()
    return "fpaQQkNktDLfoMdPwSO8lGsl1bH7tN9v"
end

function setDeviceSecretFnc()
end

local function rcvCbFnc(topic,qos,payload)
    log.info("testALiYun.rcvCbFnc",topic,qos,payload)
end

--启动MQTT客户端任务
sys.taskInit(
    function()
        local retryConnectCnt = 0

        sys.waitUntil("PREINIT")

        while true do
            if not socket.isReady() then
                retryConnectCnt = 0
                log.info("socket", "not ready")
                sys.waitUntil("IP_READY_IND",300000)
                log.info("socket", "ready")
            end 

            if socket.isReady() then
                local imei = misc.getImei()
                --创建一个MQTT客户端
                mqttClient = mqtt.client(imei,600,"user","password")
                --阻塞执行MQTT CONNECT动作，直至成功
                --如果使用ssl连接，打开mqttClient:connect("lbsmqtt.airm2m.com",1884,"tcp_ssl",{caCert="ca.crt"})，根据自己的需求配置
                --mqttClient:connect("lbsmqtt.airm2m.com",1884,"tcp_ssl",{caCert="ca.crt"})
                --if mqttClient:connect("lbsmqtt.airm2m.com",1884,"tcp") then
                if mqttClient:connect("112.74.179.152",1883,"tcp") then
                    retryConnectCnt = 0
                    ready = true
                    --订阅主题
                    --if mqttClient:subscribe({["/event0"]=0, ["/中文event1"]=1}) then
                    log.info("MQTT TASK", "SUB", misc.getImei())
                    if mqttClient:subscribe("/dev/sub/"..misc.getImei(),0) then
                        while true do
                            result,data = mqttClient:receive(100)
                            if result then
                                log.info("mqtt receive", data)
                                local InMsg = mqttInMsg.proc(result,data)
                                if InMsg ~= nil then
                                    if not mqttOutMsg.proc(mqttClient, InMsg) then log.error("mqttTask.mqttOutMsg proc error") break end
                                end
                            end
                        end
                    end
                    ready = false
                else
                    retryConnectCnt = retryConnectCnt+1
                end
                --断开MQTT连接
                mqttClient:disconnect()
                if retryConnectCnt>=5 then link.shut() retryConnectCnt=0 end
                sys.wait(5000)
            else
                --进入飞行模式，20秒之后，退出飞行模式
                --net.switchFly(true)
                sys.wait(20000)
                --net.switchFly(false)
            end
        end
    end
)
