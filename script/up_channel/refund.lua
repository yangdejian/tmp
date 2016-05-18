require "sys"

up_refund = {fields = "delivery_id"}
up_refund.dbg = xdbg()
up_refund.ip = flowlib.get_local_ip()

up_refund.main = function(args)
	print("----------------------上游订单退款--------------------------")
	print("1.检查参数")
	local params = xtable.parse(args[2], 1)
	if(xobject.empty(params, up_refund.fields)) then
		print(string.format("缺少必须参数, 需传入:%s, 已传入:%s", up_refund.fields, args[2]))
		return sys.error.param_miss
	end

	print("2.进入主流程")
	local result,refund_info= up_refund.main_flow(params)

	--print("3.发送统计消息")
	--up_refund.send_flow_monitor(result, refund_info)

	print("4.上游退款生命周期")
	up_refund.add_order_lifetime (refund_info)

	print("-----上游订单退款完成-----")
end

up_refund.main_flow = function(params)
	print("2.1. 获取上游退款信息")
	local input_params = params
	input_params.robot_code = up_refund.ip
	local result,refund_info = up_refund.get_refund_info(input_params)
	input_params = xtable.merge(refund_info,input_params)
	if(not(xstring.equals(result.code, "success"))) then
		input_params.content = "【上游退款失败】"..result.code
		return result,input_params
	end

	print("3.2. 上游退款保存")
	result = up_refund.save_refund(input_params)
	input_params.content = "【上游退款成功】"..result.code

	return result,input_params
end
--========================生命周期函数=========================
up_refund.add_order_lifetime = function(data)
	if(xstring.empty(data.order_no)) then
		print("ERR 添加生命周期失败：上游退款没有传订单号")
		return
	end
	local dbg_result = up_refund.dbg:execute("order.lifetime.save", {order_no = data.order_no,
																	delivery_id =not(xstring.empty(data.delivery_id)) and data.delivery_id or 0 ,
																	ip = up_refund.ip,
																	content = data.content})
	if(dbg_result.result.code ~= sys.error.success.code) then
		print("ERR 添加生命周期失败："..xtable.tojson(dbg_result))
	end

	return dbg_result
end

--=========================流程函数=============================
up_refund.get_refund_info = function(params)
	local dbg_result = up_refund.dbg:execute("up_channel.refund.get", params)
    params.content = "【上游退款获取】"..dbg_result.result.code
	if(dbg_result.result.code ~= sys.error.success.code) then
		print(string.format("ERR 获取退款订单信息失败：%s", dbg_result.result.msg))
        params.content = "【上游退款获取】"..dbg_result.result.code.."获取上游退款信息失败"
	end
	up_refund.add_order_lifetime(params)
	return dbg_result.result, dbg_result.data
end

up_refund.save_refund = function(input)
	local dbg_result = up_refund.dbg:execute("up_channel.refund.save", input)
	if(dbg_result.result.code ~= sys.error.success.code) then
		print(string.format("ERR 退款并保存结果失败：%s", dbg_result.result.msg))
	end
	return dbg_result.result
end

--==========================监控函数=============================
up_refund.send_flow_monitor = function(result, data)
	data = data or {}
	data.name = "up_refund"
	data.count = 1
	data.amount = data.refund_amount
	sys.monitor.save(result, data)
end

return up_refund
