require "sys"

up_pay = {}
up_pay_config = {up_pay_provider = xdbg(), fields = "order_no,delivery_id"}
up_pay.local_ip = flowlib.get_local_ip()

up_pay.main = function(args)

	print("--------------------------------------上游订单支付----------------------------------")
	print("1. 检查必传参数")
	local params = xtable.parse(args[2], 1)
	if(xobject.empty(params, up_pay_config.fields)) then
		print(string.format("缺少必须参数, 需传入:%s, 已传入:%s", up_pay_config.fields, args[2]))
		return sys.error.param_miss
	end

	print("2.上游订单支付主流程")
	local result, data = up_pay.main_flow(params)

	--print("3.上游订单支付发送监控")
	--up_pay.send_monitor(data,result)

	print("4.添加上游订单支付生命周期")
	up_pay.add_order_lifetime(data)

	print("-----上游订单支付流程执行完成-----")

end

up_pay.main_flow = function(params)

	print("2.1. 获取上游支付信息")
	params.robot_code = up_pay.local_ip
	local dbg_result = up_pay.get_pay_info (params)
	if(dbg_result.result.code ~= sys.error.success.code) then
		print(string.format("ERR 上游支付信息获取失败：%s", dbg_result.result.msg))
		return dbg_result.result, dbg_result.data
	end
	local input = xtable.merge(params, dbg_result.data)

	print("2.2. 上游支付保存")
	dbg_result = up_pay.pay_save (input)
	input.content = '【上游支付结果】'..dbg_result.result.code
	if(dbg_result.result.code ~= sys.error.success.code) then
		print(string.format("ERR 上游支付结果保存失败：%s", dbg_result.result.msg))
		print(xtable.tojson(input))
	end

	return dbg_result.result, input
end

--===================================生命周期函数===========================================
up_pay.add_order_lifetime = function(data)
	local dbg_result = up_pay_config.up_pay_provider:execute("order.lifetime.save", {order_no = data.order_no,
																					delivery_id = data.delivery_id,
																					ip = up_pay.local_ip,
																					content = data.content})
	if(dbg_result.result.code ~= sys.error.success.code) then
		print("ERR 添加生命周期失败："..xtable.tojson(dbg_result))
	end
	return dbg_result
end

--=====================================流程函数===============================================
up_pay.get_pay_info =function (params)

	local dbg_result = up_pay_config.up_pay_provider:execute("up_channel.pay.get", params)
	params.content = '【上游支付获取】'..dbg_result.result.code
	up_pay.add_order_lifetime(params)
	return dbg_result

end

up_pay.pay_save =function (input)

	local dbg_result = up_pay_config.up_pay_provider:execute("up_channel.pay.save", input)
	return  dbg_result

end

--=====================================监控函数================================================
up_pay.send_monitor =function(data,result)

	data = data or {}
	data.name = "up_payment"
	data.count = 1
	sys.monitor.save(result, xobject.clone(data, "name,up_channel_no,count,pay_amount>amount"))

end

return up_pay
