require "sys"

--[[
	1.检查订单支付表数据是否存在、状态是否为等待、正在支付
	2.将等待支付状态改为正在支付 等待状态的将超时时长设为当前时间加五分钟
	3.支付
	4.支付失败
		4.1检查支付超时时长
			4.1.1超过支付超时时长 处理订单状态退款发货等状态改为无需 检查是否需要发通知 发送通知(特别是余额不足通知) 发送统计
			4.1.2没超过 不做处理等待后补流程
	5.支付成功 改变订单状态 发送发货 发送统计
]]
order_pay = {fields = "order_no"}
order_pay.pay_status = {wait = "20",ondo = "30",success = "0",fail = "90"}
order_pay.recharge_status = {wait = "20",ondo = "30",success = "0",fail = "90"}
order_pay.order_status = {onpay = "10",ondelivery = "20"}
order_pay.pay_result = {succ = 0,fail = 1}
order_pay.out_time = 5
order_pay.dbg = xdbg()
order_pay.local_ip = flowlib.get_local_ip()

order_pay.main = function(args)
	print("-----------------下游订单支付------------------")
	print("1. 检查必须参数")
	local params = xtable.parse(args[2], 1)
	if(xobject.empty(params, order_pay.fields)) then
		print(string.format("缺少必须参数, 需传入:%s, 已传入:%s", order_pay.fields, args[2]))
		return sys.error.param_miss
	end

	print("2. 进入主流程")
	local result,pay_next_steps,payment_info = order_pay.main_flow(params)

	--print("3. 发送统计消息")
	--order_pay.send_flow_monitor(result, xobject.clone(payment_info, "name,down_channel_no,count,amount"))

	print("4. 记录支付生命周期")
	order_pay.add_order_lifetime({content = '【支付结果】'..result.code..'【'..tostring(pay_next_steps)..'】'},params)

	print("------下游订单支付完成-------")
	return
end

order_pay.main_flow = function(params)
	print("2.1.检查订单支付状态")
	local result, payment_info = order_pay.check_order_pay_status(params)
	if(result.code ~= sys.error.success.code) then
		return result,'',{}
	end

	print("2.2.支付扣款")
	local pay_result,next_step_codes = order_pay.payment(payment_info)
	if((pay_result.code ~= sys.error.success.code and pay_result.code ~= sys.error.balance_low.code) or xstring.empty(next_step_codes)) then
		return pay_result,next_step_codes, payment_info
	end

	print("2.3.发送至后续流程")
	order_pay.next_step(next_step_codes,params)

	return pay_result,next_step_codes,payment_info
end

--=============================生命周期函数============================
order_pay.add_order_lifetime = function(data,params)
	local dbg_result = order_pay.dbg:execute("order.lifetime.save", {order_no = params.order_no,
																	delivery_id = 0,
																	ip = order_pay.local_ip,
																	content = data.content})
	if(dbg_result.result.code ~= sys.error.success.code) then
		print("ERR 添加生命周期失败："..xtable.tojson(dbg_result))
	end
	return dbg_result
end

--===============================流程函数===============================
order_pay.check_order_pay_status = function(params)
	local dbg_result = order_pay.dbg:execute("order.pay.get", {order_no = params.order_no,
															robot_code = order_pay.local_ip,
															out_time = order_pay.out_time,
															pay_status = order_pay.pay_status.ondo})
	local content = {content = '【支付获取】'..dbg_result.result.code}
	if(dbg_result.result.code ~= sys.error.success.code) then
		print("ERR 订单支付状态不允许支付")
		content = {content = '【支付获取】'..dbg_result.result.code.."ERR 订单支付状态不允许支付"}
	end

	order_pay.add_order_lifetime(content,params)
	return dbg_result.result, dbg_result.data
end

order_pay.payment = function(payment_info)
	local dbg_result = order_pay.dbg:execute("order.pay.obey", payment_info)
	local pay_result = order_pay.pay_result.succ
	if(dbg_result.result.code == sys.error.balance_low.code) then
		pay_result = order_pay.pay_result.fail
	elseif(dbg_result.result.code ~= sys.error.success.code) then
		print("ERR 订单支付发生错误")
		return dbg_result.result
	end
    local return_result = dbg_result.result

	dbg_result = order_pay.dbg:execute("order.pay.save", {payment_id = payment_info.payment_id,
														pay_result = pay_result,
														pay_msg = dbg_result.result.msg,})
	if(dbg_result.result.code ~= sys.error.success.code) then
		return dbg_result.result
	end

	return return_result,dbg_result.data.next_step_codes
end

order_pay.next_step = function(next_step_codes,params)
	local queues = xmq(next_step_codes)
	local send_result = queues:send({order_no = params.order_no})
	print("支付mq发送结果："..tostring(send_result))  
end

--===============================监控函数===================================
order_pay.send_flow_monitor = function(result, data)
	data = data or {}
	data.name = "down_pay"
	data.count = 1
	data.amount = data.payment_amount
	sys.monitor.save(result, data)
end

order_pay.send_system_monitor = function(msg)
	sys.monitor.system_monitor({title = "流程脚本执行异常", desc = msg})
end

return order_pay
