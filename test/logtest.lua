require"common"

local function test()
    log.info("logtest.test",common.utf8ToGb2312("输出info级别的日志"))
    log.debug("logtest.test",common.utf8ToGb2312("输出debug级别的日志"))
    log.trace("logtest.test",common.utf8ToGb2312("输出trace级别的日志"))
    log.warn("logtest.test",common.utf8ToGb2312("输出warn级别的日志"))
    log.error("logtest.test",common.utf8ToGb2312("输出error级别的日志"))
    log.fatal("logtest.test",common.utf8ToGb2312("输出fatal级别的日志"))
end
