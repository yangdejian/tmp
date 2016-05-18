require "sys"

monitor_save = {}
monitor_save.dbg = xdbg()

monitor_save.main = function(args)
	print("-------------监控数据保存-------------")
	print("1. 获取参数")
	local params = xtable.parse(args[2], 1)
	local queue_name = args[3]

	print("2. 操作数据层保存数据")
	local dbg_result = monitor_save.dbg:execute("monitor."..tostring(queue_name), params)
	if(dbg_result.result.code ~= sys.error.success.code) then
		print(string.format("保存监控数据失败,队列名称:%s,错误码:%s", queue_name, dbg_result.result.code))
	end

	print("------执行完成------")
end

return monitor_save
