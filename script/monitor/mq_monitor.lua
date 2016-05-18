require "sys"
require "custom.common.utils"

mq_monitor = {}
mq_monitor.dbg = xdbg()
mq_monitor.config_path = "../ini/mq.ini"
mq_monitor.start_index = utils.getIniStr("monitor", "start", "", mq_monitor.config_path)

mq_monitor.main = function(args)
	print("-------MQ队列数量监控------")
	print("1. 获取主流程队列列表")
	mq_monitor.data = {}
	mq_monitor.index = mq_monitor.start_index
	local result = mq_monitor.get_all_queue_list()
	if(not(result)) then
		return true
	end

	if(xtable.empty(mq_monitor.data)) then
		print("无队列数据")
		return true
	end

	print("2. 保存数据")
	mq_monitor.dbg:execute("monitor.monitor.message_queue", mq_monitor.data)

	return true
end

mq_monitor.get_setting = function(index)
	local node_name = "service"..index
	local data = {}
	data.server_name = utils.getIniStr(node_name, "name", "", mq_monitor.config_path)
	local conn_url = utils.getIniStr(node_name, "url", "", mq_monitor.config_path)
	data.robot_code = xstring.split(conn_url, "?")[1]
	return data
end

mq_monitor.get_all_queue_list = function()
	while(true) do
		local data = mq_monitor.get_setting(mq_monitor.index)
		if(xstring.empty(data.server_name) or xstring.empty(data.robot_code)) then
			return true
		end
		if(not(mq_monitor.get_queue_list(data.server_name, data.robot_code))) then
			return false
		end
		mq_monitor.index = mq_monitor.index + 1
	end
	return true
end

mq_monitor.get_queue_list = function(server_name, robot_code)
	local adapter = mq.MQAdapter(server_name)
	local vec = base.StringVector()
	local status = adapter:All(vec)
	if(not(status))then
		print("ERR 获取队列名称列表失败")
		return false
	end
	local monitor_time = tonumber(xdate:now():format("yyyyMMddhhmmss"))
	for i=0,vec:size()-1,1 do
		local name = vec:get(i)
		local count = adapter:Count(name)
		--if(count > 0) then
			table.insert(mq_monitor.data, {robot_code = robot_code,
										monitor_time = monitor_time,
										title = name,
										total_count = count})
		--end
	end
	return true
end


return mq_monitor
