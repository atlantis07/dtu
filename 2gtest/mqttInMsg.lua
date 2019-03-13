--- 模块功能：云端实时管理设备

module(...,package.seeall)

require "testUart"
require "testSocket"
require "testLbsLoc"
require "testClock"
require "testHttp"
require "dlt"

require "tabletostr"

require "socket"
require "misc"
--- MQTT客户端数据接收处理
-- @param mqttClient，MQTT客户端对象
-- @return 处理成功返回true，处理出错返回false
-- @usage mqttInMsg.proc(mqttClient)
--function proc(mqttClient)

function proc(result, data)
    local ret = ""
    --local result,data,ret
    while true do
        --result,data = mqttClient:receive(2000)
        --接收到数据
        if result then
            --log.info("mqttInMsg.proc",data.topic,string.toHex(data.payload))
            --log.info("mqttInMsg.proc",data.topic,data.payload)
            --TODO：根据需求自行处理data.payload
            local tjsondata,result,errinfo = json.decode(data.payload)
                if result and type(tjsondata)=="table" then
                    if tjsondata["cmd"] == "config" then
                        if tjsondata["id"] == "8" or tjsondata["id"] == "9" then
                            ret = testUart.UartConfig(data.payload)
                            break
                        else
                            ret = testSocket.ChannelConfig(data.payload)
                            break
                            --log.info("mqttInMsg config", "channel 1 ~ 7")
                        end
                    elseif tjsondata["cmd"] == "send" then
                        ret = testSocket.SendMultiChannel(data.payload)
                        break
                    elseif tjsondata["cmd"] == "http" then
                        ret = testHttp.proc(data.payload)
                        break
                    elseif tjsondata["cmd"] == "gettime" then
                        ret = testClock.getTime()
                        break
                    elseif tjsondata["cmd"] == "getlocation" then
                        ret = testLbsLoc.reqLbsLoc()
                        break
                    elseif tjsondata["cmd"] == "p" then
                        socket.printStatus()
                        break
                    elseif tjsondata["cmd"] == "getconf" then
                        --log.info("Get Imei", misc.getImei())
                        ret = conf.GetAllConf(tjsondata["id"])
                        break
                    elseif tjsondata["cmd"] == "getimei" then
                        ret = misc.getImei()
                        break
                    elseif tjsondata["cmd"] == "+++" then
                        conf.Restore()
                        break
                    elseif tjsondata["cmd"] == "getdlt" then
                        ret = "{}"

                        flag = dlt.DltRunFlag()
                        if flag == 1 then
                            break
                        end

                        dlt.DltSetRunFlag(1)

                        sys.publish("ADLT", data.payload)

                        sys.wait(1000)

                        res, dltdata = sys.waitUntil("DLT_RET", 10000)
                        --结果可能返回true,0",对结果进行json判断

                        local d,r,e = json.decode(dltdata)

                        if res == true and e == nil then
                            ret = dltdata
                        end

                        log.info("inmsg", "dltdata", dltdata, "ret", ret, "res", res, "dltdata type", type(dltdata))

                        dlt.DltSetRunFlag(0)
                        break
                    end
                else
                    ret = "json parse err"
                    --log.info("mqttInMsg json parse err", errinfo)
                    break
                end
            --如果mqttOutMsg中有等待发送的数据，则立即退出本循环
            --if mqttOutMsg.waitForSend() then return true end
        else
            break
        end
    end
    
    return ret
end
