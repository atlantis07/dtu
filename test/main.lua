PROJECT = "airDTU"
VERSION = "1.0.0"
PRODUCT_KEY = "UFieXrh1FV6KelkZ5JBPb5XqBaHCE5k1"

--加载日志功能模块，并且设置日志输出等级
--如果关闭调用log模块接口输出的日志，等级设置为log.LOG_SILENT即可
require "log"
LOG_LEVEL = log.LOGLEVEL_TRACE

require "sys"

require "net"
--每1分钟查询一次GSM信号强度
--每1分钟查询一次基站信息
net.startQueryAll(60000, 60000)

--加载硬件看门狗功能模块
--根据自己的硬件配置决定：1、是否加载此功能模块；2、配置Luat模块复位单片机引脚和互相喂狗引脚
--合宙官方出售的Air201开发板上有硬件看门狗，所以使用官方Air201开发板时，必须加载此功能模块
require "wdt"
wdt.setup(pio.P0_30, pio.P0_31)


--加载网络指示灯功能模块
--根据自己的项目需求和硬件配置决定：1、是否加载此功能模块；2、配置指示灯引脚
--合宙官方出售的Air800和Air801开发板上的指示灯引脚为pio.P0_28，其他开发板上的指示灯引脚为pio.P1_1
--require "netLed"
--netLed.setup(true,pio.P1_1)

--加载错误日志管理功能模块【强烈建议打开此功能】
--如下2行代码，只是简单的演示如何使用errDump功能，详情参考errDump的api
require "errDump"
errDump.request("tcp://112.74.179.152:8001", 600*1000)

--require "getlocation"

--conf init
require "conf"

require "testClock"

--uart init
require "testUart"

require "testHttp"

require "mqttInMsg"
require "mqttOutMsg"
require "mqttTask"

require "update"

require "testIO"

require "mqttTask"

sys.taskInit(
    function()
        conf.NvmInit()--获取重启之前的配置

        if not sys.waitUntil("IOTEST", 10000) then
            log.info("Hardware Restore")
            conf.ConfInit()             --初始化默认配置
            conf.NvmSetConf()           --保存配置
        else
            log.info("main", "Update Request")

            update.request()

            --等待更新版本完成，或者60秒之后之后获取配置参数
            sys.waitUntil("UPDATE_FINISH", 60000)

            log.info("main", "Conf Request")
            
            local m, r= "", ""
            while true do
                local i = 0
                m = misc.getImei()
                if m ~= "" then 
                    r = {
                        id = "0",
                        method = "GET",
                        url = "http://ipv4.skyv6.com/api/dtu.php?imei="..m,
                    }
                    r = json.encode(r) 
                    break               
                end
                if i > 30 then break end
                i = i + 1
                sys.wait(1000)
            end
            
            if r ~= "" then
                local newconf = testHttp.proc(r)
                local torigin = {}
                --log.info("main conf:", conf)

                --解析配置文件
                local tjsondata,result,errinfo = json.decode(newconf)
                if result and type(tjsondata)=="table" then
                    local old,new = "", ""
                    
                    --旧版本号
                    old = conf.GetConf(0)
                    old = tonumber(old)
                    if old == nil or old == 0 then
                        old = 0
                    end

                    --新版本号
                    new = tjsondata["version"]
                    if new ~= nil and new ~= "" then
                        new = tonumber(new)
                    end

                    --比较版本号
                    if new > old then
                        for i=1,7,1 do
                            if tjsondata["id"..i] ~= nil then
                                local ch = tjsondata["id"..i]
                                if ch["prot"] == "tcp" or ch["prot"] == "udp" then
                                    torigin = {
                                        id = ch["id"],
                                        prot = ch["prot"],
                                        ping =  ch["ping"],
                                        keepalive = ch["keepalive"],
                                        address = ch["address"],
                                        port = ch["port"],
                                        uid = ch["uid"],
                                        status = "on",
                                    }
                                elseif ch["prot"] == "mqtt" then
                                    torigin = {
                                        id = ch["id"],
                                        prot = ch["prot"],
                                        ping =  ch["ping"],
                                        keepalive = ch["keepalive"],
                                        address = ch["address"],
                                        port = ch["port"],
                                        uid = ch["uid"],
                                        usr = ch["usr"], 
                                        pwd = ch["pwd"], 
                                        cleansession = ch["cleansession"], 
                                        sub = ch["sub"], 
                                        pub = ch["pub"], 
                                        qos = ch["qos"], 
                                        retain = ch["retain"],
                                        status = "on",
                                    }                    
                                end
                                local nc = json.encode(torigin)
                                local ret = conf.SetConf(nc, i)
                                log.info("main conf", ret)   
                            end
                        end

                        for i=8,9,1 do
                            if tjsondata["id"..i] ~= nil then
                                local ch = tjsondata["id"..i]
                                    torigin = {
                                        id = ch["id"],
                                        baudrate = ch["baudrate"],
                                        datbits =  ch["datbits"],
                                        parity = ch["parity"],
                                        stopbits = ch["stopbits"],
                                        status = "on",
                                    }
                                local nc = json.encode(torigin)
                                local ret = conf.SetConf(nc, i)
                                log.info("main conf", ret)
                            end
                        end
                    end
                end
            end
        end
        conf.RunAll() --启动配置项
        conf.SyncPassthrough()--同步透传标志

        log.info("main", "start remote control")
        sys.publish("PREINIT", "Finish")
    end
)




--testUart.UartConfig("{\"cmd\":\"config\",\"id\":\"9\", \"baudrate\":\"115200\", \"datbits\":\"8\",\"parity\":\"2\", \"stopbits\":\"0\"}")

--sys.taskInit(mqttTask.MqttTask)


--启动系统框架
sys.init(0, 0)

sys.run()
