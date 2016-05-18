monitorlib = {__data = {}, __last_time = 0}

--result:{
--错误码:code
--消息:msg
--}
--params:{
--监控类别名称:name数据层方法名称(必传) 例-down_request
--监控时间:time
--渠道编号:channel_no,down_channel_no,up_channel_no
--省份编号:province_no
--规格:product_standard,standard
--告警类型:warning_type(告警相关必传)
--总数量:total_count,count
--总金额:total_amount,amount
--失败数量:fail_count
--失败金额:fail_amount
--未知数量:unkown_count
--标题:title
--描述:desc(失败与未知时不传则为result.msg)
--}
monitorlib.save = function(result, params)
	pcall(monitorlib.__save, result, params)
end

monitorlib.system_monitor = function(params)
	params.name = "system"
	pcall(monitorlib.__save, nil, params)
end

monitorlib.__save = function(result,params)
	--检查参数
	if(not(sys.open_monitor)) then
		return
	end
	if(xstring.empty(params.name)) then
		print("ERR monitorlib.save缺少必须参数name")
		return
	end

	--构建参数
	local input = {}
	input.monitor_time = tonumber(params.time) or tonumber(xdate:now():format("yyyyMMddhhmmss"))
	input.channel_no = params.channel_no or params.down_channel_no or params.up_channel_no or "-"
	input.province_no = params.province_no or 0
	input.product_standard = params.product_standard or params.standard or 0
	input.warning_type = params.warning_type or 0
	input.total_count = params.total_count or params.count or 0
	input.total_amount = params.total_amount or params.amount or 0
	input.robot_code = flowlib.get_local_ip()
	if(result ~= nil) then
		if(result.code == sys.error.success.code) then
			--params.name = params.name.."_success"
			input.total_count = input.total_count == 0 and 1 or input.total_count
		elseif(result.code == sys.error.system_busy.code) then
			--params.name = params.name.."_unknown"
			input.unkown_count = params.unkown_count or input.total_count
			input.desc = params.desc or result.msg
		else
			--params.name = params.name.."_fail"
			input.fail_count = params.fail_count or input.total_count
			input.fail_amount = params.fail_amount or input.total_amount
			input.desc = params.desc or result.msg
		end
	end

	--将数据添加至数据集中
	table.insert(monitorlib.__data, xtable.merge(params, input))

	--检查是否需要发送至队列
	if(not(monitorlib.__can_send())) then
		return
	end

	--发送队列
	monitorlib.__send()
end

monitorlib.__can_send = function()
	return (#monitorlib.__data >= sys.monitor_store_number) or ((monitorlib.__last_time + sys.monitor_store_time) <= os.time())
end

monitorlib.__send = function()
	monitorlib.__last_time = os.time()
	local mq_adapter = xmq("monitor")
	local data = monitorlib.__get_send_data()
	print("发送至监控队列中的数据条数:"..tostring(#data))
	mq_adapter:send(xtable.tojson(data))
end

monitorlib.__get_send_data = function()
	local data = {}
	for i=1,sys.monitor_store_number,1 do
		data[i] = monitorlib.__data[1]
		table.remove(monitorlib.__data, 1)
	end
	return data
end

return monitorlib
