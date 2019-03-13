require "ntp"
require "misc"
require "common"
require "log"
module(..., package.seeall)

function getTime()
    local tm = misc.getClock()
    --log.info("testNtp.printTime", string.format("%04d/%02d/%02d,%02d:%02d:%02d", tm.year, tm.month, tm.day, tm.hour, tm.min, tm.sec))
    return string.format("%04d/%02d/%02d,%02d:%02d:%02d", tm.year, tm.month, tm.day, tm.hour, tm.min, tm.sec)
end

ntp.timeSync(24)