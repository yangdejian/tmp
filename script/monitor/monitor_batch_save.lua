require "sys"

monitor_batch_save = {}
monitor_batch_save.dbg = xdbg()

monitor_batch_save.main = function(args)
	print("-------------监控数据批量保存-------------")
	print("1. 获取参数")
	local params = xtable.parse(args[2])
	if(not(xtable.isarray(params))) then
		print("ERR 输入参数不是lua数组")
		return false
	end

	print("数据条数:"..tostring(#params))

	for i,v in pairs(params) do
		print("name:::"..tostring(v.name))
	end


	print("2. 操作数据层保存数据")
	local dbg_result = monitor_batch_save.dbg:execute("monitor.monitor.batch_save", params)
	if(dbg_result.result.code ~= sys.error.success.code) then
		print(string.format("保存监控数据失败,脚本名称:%s,错误码:%s", "monitor_batch_save", dbg_result.result.code))
	end

	print("------执行完成------")
end

return monitor_batch_save
