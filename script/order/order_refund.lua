require "sys"

order_refund = {}
order_refund_config ={ fields = "order_no"}
order_refund.xdbg =  xdbg()
order_refund.ip = flowlib.get_local_ip()
order_refund.main = function(args)

	print("----------------下游订单退款流程开始---------------")
	print("1.检查必传参数")
	params =xtable.parse(args[2], 1)
	if(xobject.empty(params, order_refund_config.fields)) then
		print("ERR输入参数有误")
		return sys.error.param_error
	end
	print("2.订单退款主流程")
	local result,order,sys_result =order_refund.main_flow(params)

    --print("3.下游订单退款流程统计")
    --order_refund.send_monitor(order,result,sys_result)

	print("4.下游退款完成的生命周期")
	order_refund.add_order_lifetime(order)

	print("-----下游订单退款流程完成-----")
end

order_refund.main_flow = function(params)
	local input_params=params
	print("2.1. 获取订单退款数据(取一笔)")
	local dbg_result = order_refund.get_refund_info(input_params)
	if(not(xstring.equals(dbg_result.result.code, "success"))) then
		print("没有需要退款的数据orderno:"..params.order_no)
		input_params.content="【退款失败】"..dbg_result.result.code
		return dbg_result.result,input_params
    end

	print("2.2. 请求退款")
	input_params = xtable.merge(input_params,dbg_result.data)
	local refund_result = order_refund.refund_request(input_params)
	if(not(xstring.equals(refund_result.result.code, "success"))) then
		print("退款异常，结果："..xtable.tojson(refund_result))
		input_params.content = '【退款失败】'..refund_result.result.code
		return refund_result.result,input_params
    end

	print("2.3. 保存退款结果")
	local save_result =order_refund.refund_save(input_params)
	if(not(xstring.equals(save_result.result.code, "success"))) then
		print("保存退款失败，结果："..xtable.tojson(save_result))
		input_params.content = '【退款成功】'..refund_result.result.code.."【保存失败】"..save_result.result.code
		return refund_result.result,input_params,save_result.result
    end

    input_params.content = '【退款成功】'..refund_result.result.code
	return refund_result.result,input_params
end

--===================================生命周期函数===========================================
order_refund.add_order_lifetime = function(data)
	local dbg_result= order_refund.xdbg:execute("order.lifetime.save", {order_no = data.order_no,
																		delivery_id = 0,
																		ip = order_refund.ip,
																		content = data.content })
	if(dbg_result.result.code ~= sys.error.success.code) then
		print("ERR 添加生命周期失败："..xtable.tojson(dbg_result))
	end
end

--========================================流程函数================================================
order_refund.get_refund_info = function (params )
	local dbg_result = order_refund.xdbg:execute("order.refund.get_info", {order_no = params.order_no,refund_robot_code = order_refund.ip})
	order_refund.add_order_lifetime(xtable.merge(params,{content='【退款获取】'..dbg_result.result.code}))
	return dbg_result
end

order_refund.refund_request = function (data )
	local dbg_result = order_refund.xdbg:execute("order.refund.refund_request", data)
	return dbg_result
end

order_refund.refund_save = function (data)
	local save_input = { refund_id = data.refund_id,refund_msg = 'success',refund_result = 0}
	local dbg_result =order_refund.xdbg:execute("order.refund.result_save", save_input)
	return dbg_result
end

--========================================监控函数================================================
--发送监控统计
order_refund.send_monitor =function(params,result,sys_result)
	params.count = 1
	local input = xobject.clone(params,"down_channel_no>channel_no,name,count,refund_amount>amount")
    order_refund.normal_monitor(input,result)

	if(sys_result and (sys_result.code ~= sys.error.success.code)) then
		print("系统错误保存,参数："..xtable.tojson(input))
		order_refund.sys_monitor(input,sys_result)
	end
end

--一般监控
order_refund.normal_monitor=function (input,result)
	input.name = 'down_refund'
	input.desc = input.result_msg or result.msg
	sys.monitor.save(result,input)
end

--系统监控
order_refund.sys_monitor=function (input ,sys_result)
	input.title="退款成功，保存失败"
	input.desc = sys_result.msg
	sys.monitor.system_monitor(input)
end

return order_refund
