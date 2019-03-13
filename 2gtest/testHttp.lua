--- 模块功能：HTTP功能测试.
-- @author openLuat
-- @module http.testHttp
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.23

module(...,package.seeall)

require"http"
require"sys"

local METHOD_NOT_EXIST = "METHNOD NOT EXIST"
local METHOD_VAL = "METHOD GET/POST"
local URL_NOT_EXIST = "URL NOT EXIST"
local TIMEOUT_VAL = "TIMEOUT >0 secs"

local content = ""

local function cbFnc(result,prompt,head,body)
    --[[
    if result and head then
        for k,v in pairs(head) do
            log.info("testHttp.cbFnc",k..": "..v)
        end
    end
    --]]
    if result and body then
        content = body
        --log.info("testHttp", "body", body)
        sys.publish("HTTP_RECV" ,body)
        --log.info("testHttp.cbFnc","bodyLen="..body:len())
    end
end

local function cbFncFile(result,prompt,head,filePath)
    log.info("testHttp.cbFncFile",result,prompt,filePath)
    if result and head then
        for k,v in pairs(head) do
            log.info("testHttp.cbFncFile",k..": "..v)
        end
    end
    if result and filePath then
        local size = io.fileSize(filePath)
        log.info("testHttp.cbFncFile","fileSize="..size)
        
        --输出文件内容，如果文件太大，一次性读出文件内容可能会造成内存不足，分次读出可以避免此问题
        if size<=4096 then
            log.info("testHttp.cbFncFile",io.readFile(filePath))
        else
			
        end
    end
    --文件使用完之后，如果以后不再用到，需要自行删除
    if filePath then os.remove(filePath) end
end

function proc(param)
    local tjsondata,result,errinfo = json.decode(param)
    local id,method,url,timeout,head,body = tjsondata["id"], tjsondata["method"],tjsondata["url"], tjsondata["timeout"], tjsondata["head"], tjsondata["body"]
    local c= ""

    while not socket.isReady() do sys.waitUntil("IP_READY_IND") end
    
    if result and type(tjsondata)=="table" then

        if method == nil then
            return METHOD_NOT_EXIST
        elseif method ~= "GET" and method ~= "POST" then
            return METHOD_VAL
        end

        if url == nil then
            return URL_NOT_EXIST
        end

           --head

        --body


        timeout = tonumber(timeout)
        if timeout == nil then
            timeout = 30
        elseif timeout <= 0 then
            return TIMEOUT_VAL
        end

        log.info("testHttp", id, method, url, timeout,head, body)

        http.request(method, url, nil, head, body, timeout * 1000, cbFnc)
        if method == "GET" then
            if not sys.waitUntil("HTTP_RECV", timeout * 1000) then
                return ""
            else
                c = content
                content = ""
                return c
            end
        else
            return "POST"
        end
    else
        return HTTP_FORMAT_ERR
    end
    
end


--http.request("GET","www.lua.org",nil,nil,nil,nil,cbFnc)
--http.request("GET","https://www.baidu.com",{caCert="ca.crt"},nil,nil,nil,cbFnc)
--http.request("GET","www.lua.org",nil,nil,nil,30000,cbFncFile,"download.bin")
--http.request("GET","http://www.lua.org",nil,nil,nil,30000,cbFnc)
--http.request("GET","www.lua.org/about.html",nil,nil,nil,30000,cbFnc)
--http.request("GET","www.lua.org:80/about.html",nil,nil,nil,30000,cbFnc)
--http.request("POST","www.iciba.com",nil,nil,"Luat",30000,cbFnc)
--http.request("POST","36.7.87.100:6500",nil,{head1="value1"},{[1]="begin\r\n",[2]={file="/lua/http.lua"},[3]="end\r\n"},30000,cbFnc)
--http.request("POST","http://lq946.ngrok.xiaomiqiu.cn/",nil,nil,{[1]="begin\r\n",[2]={file_base64="/lua/http.lua"},[3]="end\r\n"},30000,cbFnc)

--如下示例代码是利用文件流模式，上传录音文件的demo，使用的URL是随意编造的
--[[
http.request("POST","www.test.com/postTest?imei=1&iccid=2",nil,
         {['Content-Type']="application/octet-stream",['Connection']="keep-alive"},
         {[1]={['file']="/RecDir/rec001"}},
         30000,cbFnc)
]]


--如下示例代码是利用x-www-form-urlencoded模式，上传3个参数，通知openluat的sms平台发送短信
--[[
function urlencodeTab(params)
    local msg = {}
    for k, v in pairs(params) do
        table.insert(msg, string.urlEncode(k) .. '=' .. string.urlEncode(v))
        table.insert(msg, '&')
    end
    table.remove(msg)
    return table.concat(msg)
end

http.request("POST","http://api.openluat.com/sms/send",nil,
         {
             ["Authorization]"="Basic jffdsfdsfdsfdsfjakljfdoiuweonlkdsjdsjapodaskdsf",
             ["Content-Type"]="application/x-www-form-urlencoded",
         },
         urlencodeTab({content="您的煤气检测处于报警状态，请及时通风处理！", phone="13512345678", sign="短信发送方"}),
         30000,cbFnc)
]]
         
         


--如下示例代码是利用multipart/form-data模式，上传2参数和1个照片文件
--[[
local function postMultipartFormData(url,cert,params,timeout,cbFnc,rcvFileName)
    local boundary,body,k,v,kk,vv = "--------------------------"..os.time()..rtos.tick(),{}
    
    for k,v in pairs(params) do
        if k=="texts" then
            local bodyText = ""
            for kk,vv in pairs(v) do
                bodyText = bodyText.."--"..boundary.."\r\nContent-Disposition: form-data; name=\""..kk.."\"\r\n\r\n"..vv.."\r\n"
            end
            body[#body+1] = bodyText
        elseif k=="files" then
            local contentType =
            {
                jpg = "image/jpeg",
                jpeg = "image/jpeg",
                png = "image/png",                
            }
            for kk,vv in pairs(v) do
                print(kk,vv)
                body[#body+1] = "--"..boundary.."\r\nContent-Disposition: form-data; name=\""..kk.."\"; filename=\""..kk.."\"\r\nContent-Type: "..contentType[vv:match("%.(%w+)$")].."\r\n\r\n"
                body[#body+1] = {file = vv}
                body[#body+1] = "\r\n"
            end
        end
    end    
    body[#body+1] = "--"..boundary.."--\r\n"
        
    http.request(
        "POST",
        url,
        cert,
        {
            ["Content-Type"] = "multipart/form-data; boundary="..boundary,
            ["Connection"] = "keep-alive"
        },
        body,
        timeout,
        cbFnc,
        rcvFileName
        )    
end

postMultipartFormData(
    "1.202.80.121:4567/api/uploadimage",
    nil,
    {
        texts = 
        {
            ["imei"] = "862991234567890",
            ["time"] = "20180802180345"
        },
        
        files =
        {
            ["logo_color.jpg"] = "/ldata/logo_color.jpg"
        }
    },
    60000,
    cbFnc
)
]]
