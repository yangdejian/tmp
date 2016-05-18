require 'sys'
require "xqstring"
require "custom.common.xhttp"
require "CLRPackage"

import('SecurityCore')

jfyp_query = {}
jfyp_query = {fields="query_id,order_no",encode="UTF-8",pre_code='JFYP_Q_'}
jfyp_query.CONFIG = {ip=flowlib.get_local_ip(),next_query_wait_minutes=5,result_source=3}
jfyp_query.up_result_code = {success = '000000'}

jfyp_query.dbg 	= xdbg()
jfyp_query.http = xhttp()

jfyp_query.main = function(args)
	print("----------------【劲峰优品】发货查询 ----------------")
	print("【检查必须参数】")
	local input = xtable.parse(args[2], 1)
	if(xobject.empty(input, jfyp_query.fields)) then
		error("缺少必须参数:"..jfyp_query.fields)
		return sys.error.param_miss
	end

	print("【上游发货主流程】")
	local result,data,content = jfyp_query.main_flow(input)

	print("【发货完成的生命周期】")
	jfyp_query.create_order_life(xtable.merge(input,data),content)

	print("流程结束:"..result.code)
end

jfyp_query.main_flow = function(params)
	print("1、获取发货数据")
	local result,query_params = jfyp_query.get_query_data(params) 
	if(result.code ~= sys.error.success.code) then
		return result,{},'【查询获取】失败:'..result.code
	end

	print("2、开始查询")
	local query_result = jfyp_query.get_query_result(query_params)

	print("3、保存查询结果到数据库")
	local result,dbg_data = jfyp_query.save_query_result(query_result,query_params)
	if(result.code ~= sys.error.success.code) then
		return result,query_params,'【查询保存】失败:'..result.code
	end

	print("4、发送至后续流程") 
	if(not xstring.empty(dbg_data.next_step_codes)) then
		jfyp_query.notify_next_flow(dbg_data.next_step_codes,query_params)
	end

	return result,query_params,'【查询保存】成功,NEXT:'..tostring(dbg_data.next_step_codes)
end

--- return errcode,data
jfyp_query.get_query_data = function(params)
	local return_data = {}

	print('获取发货等信息')
	local input = {query_id = params.query_id,
		wait_time = jfyp_query.CONFIG.next_query_wait_minutes,
		robot_code = jfyp_query.CONFIG.ip
	}
	local dbg_ret = jfyp_query.dbg:execute("order.delivery_query.get",input)
	if(dbg_ret.result.code ~= sys.error.success.code) then
		error('DBG-ERR:获取发货信息失败,input:'..xtable.tojson(input))
		return dbg_ret.result
	end
	return_data = xtable.merge(return_data,dbg_ret.data)

	print('获取查询地址等信息')
	local db_ret = jfyp_query.dbg:execute("order.delivery_query.get_query_config",dbg_ret.data)
	if(db_ret.result.code ~= sys.error.success.code) then
		error('DBG-ERR:获取查询地址信息失败,params:'..xtable.tojson(dbg_ret.data))
		return db_ret.result
	end
	return_data = xtable.merge(return_data,db_ret.data)

	jfyp_query.create_order_life(return_data,string.format('【查询获取】qid:%s,ret:%s',params.query_id,dbg_ret.result.code))
	return dbg_ret.result,return_data
end

jfyp_query.get_query_result = function(params)
	local response = {}
	local q = xqstring:new()

	print('2.1 构造签名和post_data')
	q:add("P1_agentcode",params.account_name)
	q:add("P5_requestid",params.delivery_id)

	local raw = q:make({kvc="",sc="",req=true,ckey=false,encoding=jfyp_query.encode})
	debug('raw:'..raw)
	local real_key = sys.decrypt_pwd(params.up_channel_no,params.token_key)
	local ret,sign = pcall(Security.Jinfeng_Hmac,raw,real_key)
	if(not ret) then
		error('调用Security.Jinfeng_Hmac进行签名失败,sign:'..tostring(sign))
		return sys.error.build_sign_failure
	end
	q:add("hmac",sign)
	local post_data = q:make({kvc="=",sc="&",req=true,ckey=true,encoding=jfyp_query.encode})

	print('2.1 请求查询接口')
	local url = params.query_url..'?'..post_data
	debug('url:'..url)
	local content = jfyp_query.http:get(url,jfyp_query.encode)
	print("content:"..content)

	print('2.2 分析查询结果')
	if(xstring.empty(content)) then
		response.up_error_code = jfyp_query.get_up_error_code(sys.error.response_empty.code)
		error('查询接口返回空')
		return response
	end

	local args = xstring.split(content,'|')
	local resultno = args[1]
	local up_order_no = nil

	if(xstring.equals(args[1],jfyp_query.up_result_code.success)) then
		resultno = args[1]..'_'..args[6]
		up_order_no = args[2]
	end

	response.up_error_code = jfyp_query.get_up_error_code(resultno)
	response.up_order_no = up_order_no
	print('response:'..xtable.tojson(response))
	return response
end

--- query_result:{up_error_code,card_use_status,success_standard,up_order_no,order_msg,card_msg}
jfyp_query.save_query_result = function(query_result,query_params)
	print('保存查询结果')
	local input = {
		up_error_code = query_result.up_error_code,
		success_standard = xstring.empty(query_result.success_standard) and 0 or query_result.success_standard,
		delivery_id = query_params.delivery_id,
		up_order_no = xstring.empty(query_result.up_order_no) and 0 or query_result.up_order_no,
		up_channel_no = query_params.up_channel_no,
		result_source = jfyp_query.CONFIG.result_source,
		result_msg = jfyp_query.result_msg
	}
	local dbg_ret = jfyp_query.dbg:execute("order.delivery_query.save", input)
	if(dbg_ret.result.code ~= sys.error.success.code) then
		error('查询保存失败,code:'..dbg_ret.result.code)
		error('input:'..xtable.tojson(input))
		return dbg_ret.result
	end
	return dbg_ret.result, dbg_ret.data
end

jfyp_query.create_order_life = function (params, content)
	print('创建生命周期')
	local input = {
		order_no = params.order_no,
		delivery_id = xstring.empty(params.delivery_id) and 0 or params.delivery_id,
		ip = jfyp_query.CONFIG.ip,
		content = content
	}
	local dbg_result = jfyp_query.dbg:execute("order.lifetime.save", input)
	if(dbg_result.result.code ~= sys.error.success.code) then
		error('DBG_ERR生命周期保存失败')
		error("input:"..xtable.tojson(input))
	end
end

jfyp_query.notify_next_flow = function(next_step_codes, query_info)
	if(xstring.empty(next_step_codes)) then
		error('没有下一步!')
		return true
	end
	local queues = xmq(next_step_codes)
	local ret = queues:send(query_info)
	print(ret and '加入队列成功' or '加入队列失败')
end

jfyp_query.get_up_error_code = function(code)
	return jfyp_query.pre_code..code
end

return jfyp_query