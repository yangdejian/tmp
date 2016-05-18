require "sys"
require "custom.common.xhttp"
require "custom.common.qparam"
require 'xsign'

--作者 李亚
-- 流程作用 下游通知流程

order_notify_config ={fields ='order_no', charset='utf-8',notify_count = 3,pkg = require("config.package")}
order_notify = {request = {}, nexts = {}, save = {}, info = {},monitor = {} }
order_notify.xdbg=xdbg()
order_notify.ip = flowlib.get_local_ip()

order_notify.main = function(args)
	print("---------------------下游订单通知流程开始--------------------")
	print("1. 下游通知检查必传参数】")
	local params = xtable.parse(args[2], 1)
	if(xobject.empty(params, order_notify_config.fields)) then
		print("ERR输入参数有误")
		return sys.error.param_error
	end

	print("2. 通知主流程")
	local result,order,save_result =order_notify.main_flow(params)

    print("3. 下游订单通知流程统计")
    --order_notify.send_monitor(order,result,save_result)

	print("4. 通知完成的生命周期")
	order_notify.create_lifetime(order)

	print("5. 下游订单通知流程完成")
end

order_notify.main_flow = function(params)    
	print("1.1 获取要通知的数据.订单号："..params.order_no)
	input_params =params
	local res=order_notify.info.get_notify_info(params)
	if(not(xstring.equals(res.result.code, "success"))) then
		input_params.content = "【通知失败】"..res.result.msg
		return res.result,input_params
	end

	print("1.2 通知下游")
	input_params = xtable.merge(input_params,res.data)
	local result,notify_result = order_notify.request.notify(res.data,params.times)
	input_params.desc=notify_result.msg
	if(not(xstring.equals(result.code, "success"))) then
		input_params.content = "【通知失败】"..notify_result.msg
		return notify_result,input_params
	end 

	print("1.3 通知保存")
	local save_result =  order_notify.save.notify_save(notify_result,res.data )
	 if(xstring.equals(save_result.result.code, "success")) then
	  	print("1.4 通知保存的下一步"..save_result.data.next_step_code)
	    order_notify.nexts.notify_next_step(save_result.data.next_step_code,res.data)
		next_step="【"..save_result.data.next_step_code.."】"
	end
    input_params.content = "【通知结束】"..notify_result.code..tostring(next_step).."【通知保存结果】"..save_result.result.code
	
	return  result,input_params,save_result.result

end

---==========================================获取通知===================================
--返回要通知的数据
order_notify.info.get_notify_info = function (params)
	local res=order_notify.xdbg:execute("order.notify.info_query",{order_no = params.order_no,notify_robot_code = flowlib.get_local_ip()})
	order_notify.create_lifetime(xtable.merge({content = "【查询通知】"..res.result.code},params))
	return res

end

--==========================================通知===================================
--通知 通知有次数且失败则直接return 否则走下一步保存
order_notify.request.notify=function (data ,current_times)	
	local result = order_notify.request.notify_up_data(data)
	print("发送通知结果："..tostring(result.msg))
	local times= current_times or 1
	if(not(xstring.equals(result.code, "success")) and times < order_notify_config.notify_count) then
		print("通知失败，次数还有，重新发送,当前次数："..times)
		order_notify.request.notify_send(times,data.order_no)
		return sys.error.failure,result
	end
	return sys.error.success,result
end
--通知发送
order_notify.request.notify_send = function(times,order_no)
	local notify_queues = xmq("order_notify")
		local result = notify_queues:send({times = times  + 1,order_no = order_no})
		print(result and  "加入通知队列成功" or "加入通知队列失败")
end
--根据返回数据,构建通知发送
order_notify.request.notify_up_data = function(data)
	local http=xhttp()
	local path = data.notify_url..order_notify.request.set_input_params(data,notify)
	print("通知url:"..path)
	--发送通知
	local send_result=http:get(path,order_notify_config.charset)
	if(string.find(string.lower(send_result),"success")~=nil) then
		return sys.error.success
    end
	send_result = not(xstring.empty(send_result)) and string.sub(send_result,1,32) or'下游返回空'
	return {code = sys.error.failure.code,msg =send_result }
end
--设置发送的数据格式?后面的拼接
order_notify.request.set_input_params = function(data,notify)	
	local tbParams={}
	tbParams.orderNo = data.order_no
	tbParams.orderStatus = data.recharge_status 
	tbParams.coopId = data.down_channel_no 
	tbParams.coopOrderNo = data.down_order_no
	tbParams.rechargeAccount = data.recharge_account 
	tbParams.submitAmount = data.total_standard
	tbParams.successAmount = data.succ_standard   
	tbParams.paymentDiscount = data.payment_discount 

	print("所传参数"..xtable.tojson(data))

	tbParams.sign = xsign.make(tbParams,order_notify_config.charset,sys.decrypt_pwd(data.down_channel_no,data.token))
	return "?"..'orderNo='..data.order_no..'&orderStatus='..data.recharge_status..'&coopId='..data.down_channel_no..
	'&coopOrderNo='..data.down_order_no..'&rechargeAccount='..data.recharge_account..'&submitAmount='..data.total_standard..'&successAmount='..
	data.succ_standard ..'&paymentDiscount='..data.payment_discount..'&sign='..tbParams.sign

end

---============================================通知保存==========================================
--通知保存 通知结果成功则返回保存结果
order_notify.save.notify_save=function (result,data )
	local notify_result= xstring.equals(result.code, "success") and order_notify_config.pkg.delivery.notify_result.success or order_notify_config.pkg.delivery.notify_result.failure
	return  order_notify.save.notify_result_save(notify_result,result.msg,data)
end

--通知结果保存
order_notify.save.notify_result_save = function(status,content,data)
	local save_result = order_notify.xdbg:execute("order.notify.result_save",{notify_result= status,notify_msg = content,notify_id = data.notify_id})
	if(not(xstring.equals(save_result.result.code, "success"))) then
		print("通知成功修改结果时返回错误:"..xtable.tojson(save_result))
	end

	return save_result
end

--返回的下一步处理
order_notify.nexts.notify_next_step=function (next_step_code,data)
	if(not(xstring.empty(next_step_code))) then			
			local queues = xmq(next_step_code)
			local send_result =queues:send({order_no= data.order_no})
			print(send_result and  "加入队列成功" or "加入对列失败")
	end
end


--========================================?¨¤??================================================
order_notify.send_monitor =function(params,result,sys_result)
	params.count = 1
	params.name = 'down_notify'
	local input = xobject.clone(params,"down_channel_no>channel_no,name,province_no,count,fail_count,unkown_count")
	
    print("统计保存")
    order_notify.monitor.normal_monitor(input,result)

	if(sys_result and (sys_result.code ~= sys.error.success.code)) then
			print("系统错误保存,参数："..xtable.tojson(input))
		order_notify.monitor.sys_monitor(input,sys_result)
	end

end

--一般监控
order_notify.monitor.normal_monitor=function (input,result)
	input.name = 'down_notify'
	input.desc = result.msg
	sys.monitor.save(result,input)
end

--系统监控
order_notify.monitor.sys_monitor = function (input ,sys_result)
	input.title="通知成功，保存失败"
	input.desc = sys_result.msg
	print("系统统计保存内容："..xtable.tojson(input))
	sys.monitor.system_monitor(input)
end

order_notify.create_lifetime = function (data)
	local result = order_notify.xdbg:execute("order.lifetime.save",{ 
		order_no = data.order_no,
		ip = order_notify.ip,
		content = data.content,
		delivery_id = 0
		})
	if(not(xstring.equals(result.result.code,"success"))) then
		print("添加订单通知的生命周期失败"..result.result.code.."order_no"..data.order_no)
	end

end

return order_notify
