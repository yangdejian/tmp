require "sys"
require "xqstring"
require "custom.common.xhttp"
require "CLRPackage"

import('SecurityCore')

--处理订单发货
jfyp_delivery = {fields="delivery_id",encode="UTF-8",pre_code='JFYP_D_'}
jfyp_delivery.config = {result_source=2,robot_code=flowlib.get_local_ip()}
jfyp_delivery.up_result_code = {success = '000000'}

jfyp_delivery.dbg = xdbg()
jfyp_delivery.http = xhttp()


jfyp_delivery.main = function(args)
	print("-------------- 【劲峰优品】上游发货 ------------")

	print("【检查输入参数】")
	local params=xtable.parse(args[2], 1)
	if(xobject.empty(params, jfyp_delivery.fields)) then
		print("ERR输入参数有误")
		return sys.error.param_miss
	end
	local input = xtable.merge(params,jfyp_delivery.config)

	print("【上游发货主流程】")
	local result,data,content = jfyp_delivery.main_flow(input)

	print("【发货完成的生命周期】")
	jfyp_delivery.create_lifetime(xtable.merge(input,data),content)

	print("流程结束:"..result.code)
end

jfyp_delivery.main_flow = function(params)

	print("1. 获取发货订单数据")
	local result,delivery_info = jfyp_delivery.get_delivery_info(params)
	if(result.code ~= "success") then
		return result,{},"【发货结束】发货获取失败:"..result.code
	end
	delivery_info.delivery_id = params.delivery_id

	print("2. 处理上游发货")
	local response_data = jfyp_delivery.request_order(delivery_info)

	print("3. 保存发货结果")
	local result,data = jfyp_delivery.save_result(delivery_info,response_data)
	if(result.code ~= "success") then
		return result,delivery_info,string.format('【发货结束】%s',result.code)
	end

	print("4. 处理后续流程")
	if(not xstring.empty(data.next_step)) then
		jfyp_delivery.next_step(data.next_step,xtable.merge(delivery_info,data))
	end

	return sys.error.success,delivery_info,'【发货结束】success,NEXT:'..tostring(data.next_step)
end


--===================================获取发货订单=============================================
jfyp_delivery.get_delivery_info = function(params)
	local return_data = {}

	print('获取发货数据')
	local db_ret = jfyp_delivery.dbg:execute("order.delivery.get",params)
	if(db_ret.result.code ~= sys.error.success.code) then
		error('DBG-ERR:获取发货数据失败,params:'..xtable.tojson(params))
		return db_ret.result
	end
	return_data = xtable.merge(return_data,db_ret.data)

	print('获取发货配置信息')
	local db_ret = jfyp_delivery.dbg:execute("order.delivery.get_delivery_config",db_ret.data)
	if(db_ret.result.code ~= sys.error.success.code) then
		error('DBG-ERR:获取发货配置信息失败,input:'..xtable.tojson(db_ret.data))
		return db_ret.result
	end
	return_data = xtable.merge(return_data,db_ret.data)

	jfyp_delivery.create_lifetime(return_data,"【发货获取】成功")
	return sys.error.success,return_data
end

--===================================发货请求=============================================
--发货请求
jfyp_delivery.request_order = function(params)
	local response = {}
	local q = xqstring:new()

	print('2.1 构造签名和post_data')
	q:add("P0_biztype",'mobiletopup')
	q:add("P1_agentcode",params.account_name)
	q:add("P2_mobile",params.recharge_account_id)
	q:add("P3_parvalue",params.total_standard)
	q:add("P4_productcode",params.carrier_no)
	q:add("P5_requestid",params.delivery_id)
	q:add("P6_callbackurl",params.notify_url)
	q:add("P7_extendinfo",'')

	local raw = q:make({kvc="",sc="",req=true,ckey=false,encoding=jfyp_delivery.encode})
	debug('raw:'..raw)
	local real_key = sys.decrypt_pwd(params.up_channel_no,params.token_key)
	local ret,sign = pcall(Security.Jinfeng_Hmac,raw,real_key)
	if(not ret) then
		error('调用Security.Jinfeng_Hmac进行签名失败,sign:'..tostring(sign))
		return sys.error.build_sign_failure
	end
	q:add("hmac",sign)
	local post_data = q:make({kvc="=",sc="&",req=true,ckey=true,encoding=jfyp_delivery.encode})
	print('post_data:'..post_data)

	print('2.2 请求下单接口')
	local url = params.recharge_url..'?'..post_data
	debug('url:'..url)
	local content = jfyp_delivery.http:get(url,jfyp_delivery.encode)
	print("content:"..content)

	print('2.3 分析下单结果')
	if(xstring.empty(content)) then
		response.up_error_code = jfyp_delivery.get_up_error_code(sys.error.response_empty.code)
		response.result_msg = '下单接口返回空'
		error(response.result_msg)
		return response
	end
	local s,e = string.find(content, "<html>")
	if(s ~= nil) then
		response.up_error_code = jfyp_delivery.get_up_error_code(sys.error.response_html.code)
		response.result_msg = '下单接口返回HTML'
		error(response.result_msg)
		return response
	end

	response.up_error_code = jfyp_delivery.get_up_error_code(content)
	print('response:'..xtable.tojson(response))
	return response
end

--===================================保存发货结果=============================================
--input:{delivery_id,channel_no,success_standard,result_source,result_msg,
--		query_timespan,up_error_code,robot_code}
jfyp_delivery.save_result = function(delivery_info,response_data)
	print('保存发货结果')
	local input = {
		delivery_id = delivery_info.delivery_id,
		channel_no = delivery_info.channel_no,
		success_standard = xstring.empty(response_data.success_standard) and 0 or response_data.success_standard,
		result_source = jfyp_delivery.config.result_source,
		result_msg = response_data.result_msg,
		query_timespan = delivery_info.query_timespan,
		up_error_code = response_data.up_error_code,
		robot_code = jfyp_delivery.config.robot_code,
		up_order_no = xstring.empty(response_data.up_order_no) and 0 or response_data.up_order_no
	}
	local db_ret = jfyp_delivery.dbg:execute("order.delivery.save",input)
	if(db_ret.result.code ~= sys.error.success.code) then
		error('发货保存失败:'..db_ret.result.code)
		error('保存参数:'..xtable.tojson(input))
		return db_ret.result
	end
	return db_ret.result,db_ret.data
end

jfyp_delivery.get_up_error_code = function(code)
	return jfyp_delivery.pre_code..code
end

--发货后的下一步处理
jfyp_delivery.next_step = function (next_step,data)
	if(xstring.empty(next_step)) then
		return
	end
	local queues = xmq(next_step)
	local result = queues:send(data)
    print(result and "加入队列成功" or "加入队列失败")
end

--- 创建订单的生命周期
jfyp_delivery.create_lifetime = function (data,content)
	if(xstring.empty(data.order_no)) then
		error("创建发货的生命周期时没有订单号")
		return
	end
	local result = jfyp_delivery.dbg:execute("order.lifetime.save",{order_no = data.order_no,
		ip = jfyp_delivery.config.robot_code,
		content = content,
		delivery_id = xstring.empty(data.delivery_id) and 0 or data.delivery_id})
	if(result.result.code ~= "success") then
		error("添加订单发货的生命周期失败:"..result.result.code)
	end
end

return jfyp_delivery
