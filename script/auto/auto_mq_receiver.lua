require "sys"

auto_mq_receiver = {}
auto_mq_receiver.configs = {}
auto_mq_receiver.scripts = {}

auto_mq_receiver.main = function(config_name)
	local config = auto_mq_receiver.configs[config_name]
	if(config == nil) then
		config = auto_mq_receiver.load_config(config_name)
		if(not(config)) then
			return
		end
		auto_mq_receiver.configs[config_name] = config
	end

	local g_mq_receiver = xmq(config_name)
	if(not g_mq_receiver) then
		return
	end

	local flow_script = auto_mq_receiver.scripts[config_name]
	local script_name = xstring.rtrim(xstring.ltrim(config.mq.script_path, "../script"), ".lua")
	if(flow_script == nil) then
		_status, flow_script = pcall(require, script_name)
		if(not(_status)) then
			_msg = string.format("引用脚本失败,脚本名称:%s,异常原因:%s", script_name, flow_script)
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
		if(os.time() - dtStart >= config.scan.restarttime) then
			print("重启自动脚本........")
			return
		end
		--如果系统暂停则睡眠
		if(flowlib.is_paused()) then
			if(math.random(0,100) <= 10) then
				print("系统暂停......")
			end
			flowlib.sleep_sync(config.scan.sleeptime)
		else
			flowlib.changeStatus(1)
			local data = g_mq_receiver:rev()
			--print("收到数据:" .. xtable.tojson(data))
			if(xtable.empty(data))then
				flowlib.changeStatus(2)
				flowlib.sleep_sync(config.scan.idletime)
			else
				local input = {}
				input[1] = config.mq.script_path
				for i,v in pairs(data) do
					--flowlib.start_flow(config.mq.script_path, v)
					print("输入参数:"..tostring(v))
					input[2] = v
					_status, _msg = pcall(flow_script.main, input)
					collectgarbage("collect")
					if(not(_status)) then
						auto_mq_receiver.send_monitor_msg(string.format("流程执行异常.执行脚本%s, 方法:%s, 错误:%s", script_name, "main", tostring(_msg)))
					end
				end
			end
			flowlib.changeStatus(2)
			flowlib.sleep_sync(10)
		end
	end
end

auto_mq_receiver.send_monitor_msg = function(msg)
	error(msg)
end

auto_mq_receiver.load_config = function(config_name)
	local config_path= string.format("config.%s", config_name)
	local status, config = pcall(require,config_path)
	if(not status) then
		_msg = string.format("加载配置文件失败:%s", config_path)
		auto_mq_receiver.send_monitor_msg(_msg)
		return nil
	end

	if(not(config.mq)) then
		_msg = string.format("未找到mq配置节点:%s", config_path)
		auto_mq_receiver.send_monitor_msg(_msg)
		return nil
	end

	if(not(config.scan)) then
		local __config=require("config.default")
		config.scan=__config.scan
	end

	return config
end

return auto_mq_receiver
