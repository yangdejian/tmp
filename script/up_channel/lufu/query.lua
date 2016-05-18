require 'sys'
require "xqstring"
require "custom.common.xhttp"

lufu_query = {}
lufu_query = {fields="query_id,order_no",encode="UTF-8",pre_code='LUFU_Q_'}
lufu_query.CONFIG = {ip=flowlib.get_local_ip(),next_query_wait_minutes=5,result_source=3}

lufu_query.dbg 	= xdbg()
lufu_query.http = xhttp()

lufu_query.main = function(args)
	print("----------------【璐付缴费100】发货查询 ----------------")
	print("【检查必须参数】")
	local input = xtable.parse(args[2], 1)
	if(xobject.empty(input, lufu_query.fields)) then
		error("缺少必须参数:"..lufu_query.fields)
		return sys.error.param_miss
	end

	print("【上游发货主流程】")
	local result,data,content = lufu_query.main_flow(input)

	print("【发货完成的生命周期】")
	lufu_query.create_order_life(xtable.merge(input,data),content)

	print("流程结束:"..result.code)
end

lufu_query.main_flow = function(params)
	print("1、获取发货数据")
	local result,query_params = lufu_query.get_query_data(params) 
	if(result.code ~= sys.error.success.code) then
		return result,{},'【查询获取】失败:'..result.code
	end

	print("2、开始查询")
	local query_result = lufu_query.get_query_result(query_params)

	print("3、保存查询结果到数据库")
	local result,dbg_data = lufu_query.save_query_result(query_result,query_params)
	if(result.code ~= sys.error.success.code) then
		return result,query_params,'【查询保存】失败:'..result.code
	end

	print("4、发送至后续流程") 
	if(not xstring.empty(dbg_data.next_step_codes)) then
		lufu_query.notify_next_flow(dbg_data.next_step_codes,query_params)
	end

	return result,query_params,string.format('【查询保存】成功(%s),NEXT:%s',
		query_result.result_msg,tostring(dbg_data.next_step_codes))
end

--- return errcode,data
lufu_query.get_query_data = function(params)
	local return_data = {}

	print('获取发货等信息')
	local input = {query_id = params.query_id,
		wait_time = lufu_query.CONFIG.next_query_wait_minutes,
		robot_code = lufu_query.CONFIG.ip
	}
	local dbg_ret = lufu_query.dbg:execute("order.delivery_query.get",input)
	if(dbg_ret.result.code ~= sys.error.success.code) then
		error('DBG-ERR:获取发货信息失败,input:'..xtable.tojson(input))
		return dbg_ret.result
	end
	return_data = xtable.merge(return_data,dbg_ret.data)

	print('获取查询地址等信息')
	local db_ret = lufu_query.dbg:execute("order.delivery_query.get_query_config",dbg_ret.data)
	if(db_ret.result.code ~= sys.error.success.code) then
		error('DBG-ERR:获取查询地址信息失败,params:'..xtable.tojson(dbg_ret.data))
		return db_ret.result
	end
	return_data = xtable.merge(return_data,db_ret.data)

	lufu_query.create_order_life(return_data,string.format('【查询获取】qid:%s,ret:%s',params.query_id,dbg_ret.result.code))
	return dbg_ret.result,return_data
end

lufu_query.get_query_result = function(params)
	local response = {}
	local q = xqstring:new()
	local real_key = sys.decrypt_pwd(params.up_channel_no,params.token_key)

	print('2.1 构造签名和post_data')
	q:add("APIID",params.account_name)
	q:add("OrderID",params.delivery_id)
	q:add("APIKEY",real_key)

	local raw = q:make({kvc="=",sc="&",req=true,ckey=true,encoding=lufu_query.encode})
	debug('raw:'..raw)
	local sign = xutility.md5.encrypt(raw,lufu_query.encode)
	debug('sign:'..sign)

	q:remove("APIKEY")
	q:add("Sign",sign)
	local post_data = q:make({kvc="=",sc="&",req=true,ckey=true,encoding=lufu_query.encode})
	print('post_data:'..post_data)

	print('2.1 请求查询接口')
	local url = params.query_url..'?'..post_data
	print('url:'..url)
	local content = lufu_query.http:get(url,lufu_query.encode)
	print("content:"..content)

	print('2.2 分析查询结果')
	if(xstring.empty(content)) then
		response.up_error_code = lufu_query.get_up_error_code(sys.error.response_empty.code)
		error('查询接口返回空')
		return response
	end
	if(not xstring.start_with(content,'{') or not xstring.end_with(content,'}')) then
		response.up_error_code = lufu_delivery.get_up_error_code(sys.error.response_fmt_error.code)
		error('下单接口响应格式错误(返回非Json数据)')
		return response
	end

	local data = xtable.parse(content)
	response.up_error_code = lufu_query.get_up_error_code(data.Code)
	response.up_order_no = tostring(data.OrderID)
	response.result_msg = data.Code..'|'..data.Msg
	print('response:'..xtable.tojson(response))
	return response
end

--- query_result:{up_error_code,card_use_status,success_standard,up_order_no,order_msg,card_msg}
lufu_query.save_query_result = function(query_result,query_params)
	print('保存查询结果')
	local input = {
		up_error_code = query_result.up_error_code,
		success_standard = xstring.empty(query_result.success_standard) and 0 or query_result.success_standard,
		delivery_id = query_params.delivery_id,
		up_order_no = xstring.empty(query_result.up_order_no) and 0 or query_result.up_order_no,
		up_channel_no = query_params.up_channel_no,
		result_source = lufu_query.CONFIG.result_source,
		result_msg = query_result.result_msg
	}
	local dbg_ret = lufu_query.dbg:execute("order.delivery_query.save", input)
	if(dbg_ret.result.code ~= sys.error.success.code) then
		error('查询保存失败,code:'..dbg_ret.result.code)
		error('input:'..xtable.tojson(input))
		return dbg_ret.result
	end
	return dbg_ret.result, dbg_ret.data
end

lufu_query.create_order_life = function (params, content)
	print('创建生命周期')
	local input = {order_no = params.order_no,
		delivery_id = xstring.empty(params.delivery_id) and 0 or params.delivery_id,
		ip = lufu_query.CONFIG.ip,
		content = content}
	local dbg_result = lufu_query.dbg:execute("order.lifetime.save", input)
	if(dbg_result.result.code ~= sys.error.success.code) then
		error('DBG_ERR生命周期保存失败')
		error("input:"..xtable.tojson(input))
	end
end

lufu_query.notify_next_flow = function(next_step_codes, query_info)
	if(xstring.empty(next_step_codes)) then
		error('没有下一步!')
		return true
	end
	local queues = xmq(next_step_codes)
	local ret = queues:send(query_info)
	print(ret and '加入队列成功' or '加入队列失败')
end

lufu_query.get_up_error_code = function(code)
	return lufu_query.pre_code..code
end

return lufu_query