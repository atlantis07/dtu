require "net"

sys.taskInit(function()
    while true do
        local  state = net.getState()
        if(state == "REGISTERED")
        then
            sys.publish("STATUS", state)
            sys.wait(5000)
        end
        sys.wait(5000)
    end
end)