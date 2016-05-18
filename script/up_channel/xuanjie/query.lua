require 'sys'
require "xqstring"
require "custom.common.xhttp"

xuanjie_query = {}
xuanjie_query = {fields="query_id,order_no",encode="UTF-8",pre_code='XUANJIE_Q_'}
xuanjie_query.CONFIG = {ip=flowlib.get_local_ip(),next_query_wait_minutes=5,result_source=3}
xuanjie_query.response_fmt = {json=1,xml=2,split=3} -- 请求结果返回格式:3:为字符串拼接（由“|”分隔）

xuanjie_query.dbg 	= xdbg()
xuanjie_query.http = xhttp()

xuanjie_query.main = function(args)
	print("----------------【济南炫捷】发货查询 ----------------")
	print("【检查必须参数】")
	local input = xtable.parse(args[2], 1)
	if(xobject.empty(input, xuanjie_query.fields)) then
		error("缺少必须参数:"..xuanjie_query.fields)
		return sys.error.param_miss
	end

	print("【上游发货主流程】")
	local result,data,content = xuanjie_query.main_flow(input)

	print("【发货完成的生命周期】")
	xuanjie_query.create_order_life(xtable.merge(input,data),content)

	print("流程结束:"..result.code)
end

xuanjie_query.main_flow = function(params)
	print("1、获取发货数据")
	local result,query_params = xuanjie_query.get_query_data(params) 
	if(result.code ~= sys.error.success.code) then
		return result,{},'【查询获取】失败:'..result.code
	end

	print("2、开始查询")
	local query_result = xuanjie_query.get_query_result(query_params)

	print("3、保存查询结果到数据库")
	local result,dbg_data = xuanjie_query.save_query_result(query_result,query_params)
	if(result.code ~= sys.error.success.code) then
		return result,query_params,'【查询保存】失败:'..result.code
	end

	print("4、发送至后续流程") 
	if(not xstring.empty(dbg_data.next_step_codes)) then
		xuanjie_query.notify_next_flow(dbg_data.next_step_codes,query_params)
	end

	return result,query_params,string.format('【查询保存】成功(%s),NEXT:%s',
		query_result.result_msg,tostring(dbg_data.next_step_codes))
end

--- return errcode,data
xuanjie_query.get_query_data = function(params)
	local return_data = {}

	print('获取发货等信息')
	local input = {query_id = params.query_id,
		wait_time = xuanjie_query.CONFIG.next_query_wait_minutes,
		robot_code = xuanjie_query.CONFIG.ip
	}
	local dbg_ret = xuanjie_query.dbg:execute("order.delivery_query.get",input)
	if(dbg_ret.result.code ~= sys.error.success.code) then
		error('DBG-ERR:获取发货信息失败,input:'..xtable.tojson(input))
		return dbg_ret.result
	end
	return_data = xtable.merge(return_data,dbg_ret.data)

	print('获取查询地址等信息')
	local db_ret = xuanjie_query.dbg:execute("order.delivery_query.get_query_config",dbg_ret.data)
	if(db_ret.result.code ~= sys.error.success.code) then
		error('DBG-ERR:获取查询地址信息失败,params:'..xtable.tojson(dbg_ret.data))
		return db_ret.result
	end
	return_data = xtable.merge(return_data,db_ret.data)

	xuanjie_query.create_order_life(return_data,string.format('【查询获取】qid:%s,ret:%s',params.query_id,dbg_ret.result.code))
	return dbg_ret.result,return_data
end

xuanjie_query.get_query_result = function(params)
	local response = {}
	local q = xqstring:new()
	local real_key = sys.decrypt_pwd(params.up_channel_no,params.token_key)

	print('2.1 构造签名和post_data')
	q:add("orderno",params.delivery_id)
	q:add("username",params.account_name)
	q:add("rtntype",xuanjie_query.response_fmt.json)
	q:add("key",real_key)

	local raw = q:make({kvc="=",sc="&",req=true,ckey=true,encoding=xuanjie_query.encode})
	debug('raw:'..raw)
	local sign = string.lower(xutility.md5.encrypt(raw,xuanjie_query.encode))
	debug('sign:'..sign)

	q:remove("key")
	q:add("sign",sign)
	local post_data = q:make({kvc="=",sc="&",req=true,ckey=true,encoding=xuanjie_query.encode})
	print('post_data:'..post_data)

	print('2.1 请求查询接口')
	local url = params.query_url..'?'..post_data
	print('url:'..url)
	local content = xuanjie_query.http:get(url,xuanjie_query.encode)
	print("content:"..content)

	print('2.2 分析查询结果')
	if(xstring.empty(content)) then
		response.up_error_code = xuanjie_query.get_up_error_code(sys.error.response_empty.code)
		error('查询接口返回空')
		return response
	end
	if(not xstring.start_with(content,'{') or not xstring.end_with(content,'}')) then
		response.up_error_code = xuanjie_query.get_up_error_code(sys.error.response_fmt_error.code)
		error('下单接口响应格式错误(返回非Json数据)')
		return response
	end

	local data = xtable.parse(content)
	local up_error_code = string.format('%s_%s',tostring(data.nrtn),tostring(data.flag))
	
	response.up_error_code = xuanjie_query.get_up_error_code(up_error_code)
	print('response:'..xtable.tojson(response))
	return response
end

--- query_result:{up_error_code,card_use_status,success_standard,up_order_no,order_msg,card_msg}
xuanjie_query.save_query_result = function(query_result,query_params)
	print('保存查询结果')
	local input = {
		up_error_code = query_result.up_error_code,
		success_standard = xstring.empty(query_result.success_standard) and 0 or query_result.success_standard,
		delivery_id = query_params.delivery_id,
		up_order_no = xstring.empty(query_result.up_order_no) and 0 or query_result.up_order_no,
		up_channel_no = query_params.up_channel_no,
		result_source = xuanjie_query.CONFIG.result_source,
		result_msg = query_result.result_msg
	}
	local dbg_ret = xuanjie_query.dbg:execute("order.delivery_query.save", input)
	if(dbg_ret.result.code ~= sys.error.success.code) then
		error('查询保存失败,code:'..dbg_ret.result.code)
		error('input:'..xtable.tojson(input))
		return dbg_ret.result
	end
	return dbg_ret.result, dbg_ret.data
end

xuanjie_query.create_order_life = function (params, content)
	print('创建生命周期')
	local input = {order_no = params.order_no,
		delivery_id = xstring.empty(params.delivery_id) and 0 or params.delivery_id,
		ip = xuanjie_query.CONFIG.ip,
		content = content}
	local dbg_result = xuanjie_query.dbg:execute("order.lifetime.save", input)
	if(dbg_result.result.code ~= sys.error.success.code) then
		error('DBG_ERR生命周期保存失败')
		error("input:"..xtable.tojson(input))
	end
end

xuanjie_query.notify_next_flow = function(next_step_codes, query_info)
	if(xstring.empty(next_step_codes)) then
		error('没有下一步!')
		return true
	end
	local queues = xmq(next_step_codes)
	local ret = queues:send(query_info)
	print(ret and '加入队列成功' or '加入队列失败')
end

xuanjie_query.get_up_error_code = function(code)
	return xuanjie_query.pre_code..code
end

return xuanjie_query