require "sys"
auto_mq_receiver = {}
auto_mq_receiver.config = require "config.default"
auto_mq_receiver.scripts = {}

auto_mq_receiver.main = function(config_name)
	local flow_script = auto_mq_receiver.scripts[config_name]
	local script_name = string.format("exception.%s", config_name)
	if(flow_script == nil) then
		status, flow_script = pcall(require, script_name)
		if(not(status)) then
			_msg = string.format("ERR 引用脚本失败,脚本名称:%s,异常原因:%s", script_name, flow_script)
			print(_msg)
			auto_mq_receiver.send_monitor_msg(_msg)
			return
		end
		auto_mq_receiver.scripts[config_name] = flow_script
	end

	local dtStart = os.time()
	while(not flowlib.is_stopped() and not flowlib.is_paused()) do
		flowlib.changeStatus(2)
		--判断运行时间
		if(os.time() - dtStart >= auto_mq_receiver.config.scan.restarttime) then
			print("重启自动脚本........")
			return
		end
		--如果系统暂停则睡眠
		if(flowlib.is_paused()) then
			if(math.random(0,100) <= 10) then
				print("系统暂停......")
			end
			flowlib.sleep_sync(auto_mq_receiver.config.scan.sleeptime)
		else
			flowlib.changeStatus(1)
			_status, _msg = pcall(flow_script.main)
			collectgarbage("collect")
			if(not(_status)) then
				auto_mq_receiver.send_monitor_msg(string.format("ERR 流程执行异常.执行脚本%s, 方法:%s, 错误:%s", script_name, "main", tostring(_msg)))
			end
		end
		flowlib.changeStatus(2)
		flowlib.sleep_sync(2000)
	end
end

auto_mq_receiver.send_monitor_msg = function(msg)
	error(msg)
end

return auto_mq_receiver
