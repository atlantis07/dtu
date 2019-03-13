require "utils"
require "pm"
require "nvm"
require "dltdata"

module(..., package.seeall)

local UART_ID = 2
--串口读到的数据缓冲区
local rdbuf = ""
local COM_flag, COM_HEAD = 0, 0x68

local device_addr = 0--设备地址
local com_class   = 0--数据类型
local com_length  = 0--数据长度
local com_check   = 0--数据校验 

local derice_addr_table = {}--设备地址列表
local derice_number = 0

local procflag = 0
local addflag = 0

local cf = "dltdata"
local cnt = 0

local retbuf = {}

local run_flag = 0

_G["get_DLT_addr"] = {0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA}  --获取电表地址
_G["DTL_addr1"] = {0x00, 0x00, 0x00, 0x19, 0x01, 0x01}
--68 01 01 19 00 00 00 68 93 06 34 34 4C 33 33 33 D1 16 
_G["get_DLT_data"] = {0x00, 0x01, 0x00, 0x00}--指令类型为0x11     --正向有功总电量
-- FE FE FE FE 68 01 01 19 00 00 00 68 91 08 33 33 34 33 33 33 33 33 1D 16

_G["get_DLT_Voltage_A"] = {0x02, 0x01, 0x01, 0x00}--A相电压
-- FE FE FE FE 68 01 01 19 00 00 00 68 91 06 33 34 34 35 77 55 1E 16 
_G["get_DLT_Voltage_B"] = {0x02, 0x01, 0x02, 0x00}--B相电压
_G["get_DLT_Voltage_C"] = {0x02, 0x01, 0x03, 0x00}--C相电压
_G["get_DLT_Voltage_F"] = {0x02, 0x01, 0xFF, 0x00}--电压数据块

_G["get_DLT_Current_A"] = {0x02, 0x02, 0x01, 0x00}--A相电流
_G["get_DLT_Current_B"] = {0x02, 0x02, 0x02, 0x00}--B相电流
_G["get_DLT_Current_C"] = {0x02, 0x02, 0x03, 0x00}--C相电流

_G["get_DLT_Power_T"] = {0X02, 0X03, 0X00, 0X00}--瞬时总有功功率
_G["get_DLT_Power_A"] = {0X02, 0X03, 0X01, 0X00}--瞬时A相有功功率
_G["get_DLT_Power_B"] = {0X02, 0X03, 0X02, 0X00}--瞬时B相有功功率
_G["get_DLT_Power_C"] = {0X02, 0X03, 0X03, 0X00}--瞬时C相有功功率
_G["get_DLT_Power_F"] = {0X02, 0X03, 0XFF, 0X00}--瞬时有功功率数据块

function parse(data, par)
    if not data then log.info("dlt", "not data") return end    
    log.info("test", "revice data:"..data:toHex())
    local tail = string.find(data,string.char(0x16))
    if not tail then return false,data end    
    local cmdtyp = string.find(data,string.char(0x68))
    if not cmdtyp or (cmdtyp >= tail) then return false,data end

    local body,result = string.sub(data, cmdtyp+1, tail-1)

    log.info("testUart.parse",data:toHex(),cmdtyp,body:toHex())

    if string.byte(data, cmdtyp) == COM_HEAD then

        device_addr = string.sub(body, 1, 6)

        if string.byte(body, 7) ~= COM_HEAD then return true, cmdtyp end

        --数据校验
        com_check = COM_HEAD
        for var = 1, string.len(body) - 1, 1 do
            com_check = com_check + string.byte(body, var)
        end
         com_check = com_check % 256
        if com_check ~= string.byte(body, string.len(body)) then return true, cmdty end

        --获取数据类型、数据长度
        com_class = string.byte(body, 8)
        com_length = string.byte(body, 9)

        --储存设备地址
        -- derice_number = derice_number + 1
        -- derice_addr_table[derice_number] = string.reverse(device_addr)
        -- write(derice_addr_table[derice_number])
        --数据信息输出
        log.info("testUart.write","Device_addr:"..string.reverse(device_addr):toHex().." DATA_class:"..string.char(com_class):toHex().." DATA_length:"..string.char(com_length):toHex())
        --获取接收到的数据
        local data_addr = string.sub(body, 10, 10 + com_length - 1)

        --数据类型、数据长度的判断
        if com_class == 0x93 then
            data_addr = string.reverse(data_addr)

            local less_data = ""
            for var = 1, string.len(data_addr), 1 do
                less_data = less_data..string.char(string.byte(data_addr, var) - 0x33)
            end
            --储存设备地址
            derice_number = derice_number + 1
            derice_addr_table[derice_number] = less_data

            DLT_Data_break(string.reverse(device_addr):toHex(), 0x00, less_data:toHex(), par)

        elseif com_class == 0x91 then
            com_class_addr = string.reverse(string.sub(data_addr, 1,4))
            local less_data = {}
            for var = 1, string.len(com_class_addr), 1 do
                less_data[var] = string.byte(com_class_addr, var) - 0x33
            end
            --获得相关数据值
            com_data_value = string.reverse(string.sub(data_addr, 5,com_length))
            local data_value = ""
            for var = 1,string.len(com_data_value), 1 do
               data_value = data_value..string.char(string.byte(com_data_value, var) - 0x33)
            end

            DLT_Data_break(string.reverse(device_addr):toHex(), table.concat(less_data), data_value:toHex(), par)  
        end

    end

    return true,string.sub(data,tail+1,-1)
end

function DLT_Data_break(device_addr, data_class, data, par)
    if par == "addr" then
        local torigin = {
            id = tostring(cnt),
            device_addr = tostring(device_addr),
            data_class = tostring(data_class),
            com_data = tostring(com_data)
        }
        local new = json.encode(torigin)
        derice_addr_table[cnt] = new
        cnt = cnt + 1
    end

    retbuf[cnt] = {
        device_addr = tostring(device_addr), 
        com_class = tostring(data_class),
        com_data = tostring(data)
        }
    --retbuf = retbuf .. " {device_addr: "..device_addr.." com_class: "..data_class.." com_data: "..data.."}"
    log.info("DLT_info", "device_addr: "..device_addr.." com_class: "..data_class.." com_data: "..data)
end

local function DLT_com_handle(par)
   if(COM_flag == 1) then
        --COM_flag = 0;
        local result,unproc
        unproc = rdbuf
        --根据帧结构循环解析未处理过的数据
        while true do
            result,unproc = parse(unproc, par)
            if not unproc or unproc == "" or not result then
                break
            end
        end

        rdbuf = unproc or ""
    end
    local js = json.encode(retbuf)

    local subjs = string.sub(js, 2,-2)
    --log.info("js", subjs)

    sys.publish("DLT_RET", subjs)
    retbuf = {}
    --cnt = 0
    COM_flag = 0;
end

function adddlt(data)
    if not data or string.len(data) == 0 then return end

    rdbuf = rdbuf..data
    COM_flag = 1;
end

function DLT_485_Send_com(device_addr, command_class, command_len, command)

    local send_data = ""
    local check_nums = 0x68
    send_data = send_data..string.char(0x68)

    for var = 0, 5 do
        check_nums = check_nums + device_addr[6 - var]
        send_data = send_data..string.char(device_addr[6 - var])
    end

    check_nums = check_nums + 0x68
    send_data = send_data..string.char(0x68)

    check_nums = check_nums + command_class
    send_data = send_data..string.char(command_class)

    check_nums = check_nums + command_len
     send_data = send_data..string.char(command_len)

     -- command = string.reverse(command)
    for var = 0, command_len - 1 do
        check_nums = check_nums + command[command_len - var] + 0x33
        send_data = send_data..string.char(command[command_len - var] + 0x33)
    end
    check_nums = check_nums % 256
    send_data = send_data..string.char(check_nums)

    send_data = send_data..string.char(0x16)

    --uart.write(UART_ID, send_data)
    sys.publish("SOCKET_RECV_DATA", 2, send_data)
    log.info("UART_ID", send_data:toHex())

end


function procdata()

    while true do
        local result, param = sys.waitUntil("ADLT", nil)
        local tjsondata,result,errinfo = json.decode(param)
        local par = tjsondata["type"]

        if result and type(tjsondata)=="table" then
            if _G["get_DLT_"..par] ~= nil and type(_G["get_DLT_"..par]) == "table" then
                local addr = {0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA}
                local cmd = _G["get_DLT_"..par]
                procflag = 1
                --确认uart开启电表数据处理模式

                sys.wait(500)

                if par == "addr" then
                    cnt = 0
                    --nvm.set(cf, {})
                    --nvm.flush()

                    DLT_485_Send_com(addr, 0x13, 0, 0)
                else
                    for i=0,cnt-1,1 do
                        local tjsondata,result,errinfo = json.decode(derice_addr_table[i])
                        if result and type(tjsondata)=="table" then
                            local strdevaddr = tjsondata["device_addr"]
                            local numdevaddr = {}
                            for i=1,6,1 do
                                numdevaddr[i] = tonumber(string.sub(strdevaddr, 2*i-1, 2*i), 16)
                            end

                            DLT_485_Send_com({numdevaddr[1], numdevaddr[2], numdevaddr[3], numdevaddr[4], numdevaddr[5], numdevaddr[6]}, 0x11, 0x4, cmd)
                        end
                    end
                end

                --等待接收数据完成
                sys.wait(2000)
                procflag = 0

                DLT_com_handle(par)

                if par == "addr" then
                    --nvm.set(cf, {})
                    nvm.set(cf, derice_addr_table)
                    nvm.flush()
                end

            end
        end
    end

end


function GetProcFlag()
    return procflag
end

function dltInit()
    nvm.init("dltdata.lua")
end

function DltRunFlag()
    return run_flag
end

function DltSetRunFlag(v)
    run_flag = v
end

--dltInit()

sys.taskInit(procdata)
