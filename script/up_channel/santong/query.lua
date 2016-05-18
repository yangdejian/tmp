require "sys"
require "custom.common.xhttp"

santong_query = {fields = "query_id,order_no",
				encoding = "utf-8",
				pre_code = "SANTONG_Q_",
				result_source = 3,
				next_query_wait_minutes = 5,
				up_succ_code = "00000",
				local_ip = flowlib.get_local_ip()}
santong_query.grs_dbg = xdbg("grs_db")
santong_query.http = xhttp()

santong_query.main = function(args)
	print("------------------上游查询(三通)------------------")
	print("1. 检查参数")
	local params = xtable.parse(args[2], 1)
	if(xobject.empty(params, santong_query.fields)) then
		error(string.format("缺少参数.需传入:%s,已传入:%s", santong_query.fields, args[2]))
		return sys.error.param_miss
	end
	params.robot_code = santong_query.local_ip

	print("2. 获取发货数据")
	local result, delivery_data = santong_query.get_delivery_data(params)
	santong_query.lifetime_save(params, "【查询获取】"..tostring(result.code))
	if(result.code ~= sys.error.success.code) then
		return result
	end
	params = xtable.merge(params, delivery_data)

	print("3. 提交上游查询请求")
	result = santong_query.request_up_query(params)
	if(result.code == sys.error.success.code) then
		santong_query.lifetime_save(params, string.format("【查询结果】%s", result.code))
	else
		santong_query.lifetime_save(params, string.format("【查询结果】%s|%s", result.code, result.msg))
	end

	print("4. 保存查询结果")
	result, params.next_step_data = santong_query.save_query_result(result, params)
	santong_query.lifetime_save(params, string.format("【查询保存】%s【%s】", result.code, tostring(params.next_step_data and params.next_step_data.next_step)))
	if(result.code ~= sys.error.success.code) then
		error("保存查询结果失败:"..xtable.tojson(result))
		return result
	end

	print("5. 处理后续流程")
	santong_query.next_step(params)

	return sys.error.success
end

santong_query.get_delivery_data = function(params)
	local dbg_result = santong_query.grs_dbg:execute("order.delivery_query.get",{query_id = params.query_id,
																				wait_time = santong_query.next_query_wait_minutes,
																				robot_code = santong_query.local_ip})
	if(dbg_result.result.code ~= sys.error.success.code) then
		return dbg_result.result
	end
	local data = dbg_result.data

	dbg_result = santong_query.grs_dbg:execute("order.delivery_query.get_query_config", data)
	if(dbg_result.result.code ~= sys.error.success.code) then
		return dbg_result.result
	end
	data = xtable.merge(data, dbg_result.data)

	return sys.error.success, data
end

santong_query.request_up_query = function(params)
	print("3.1 构建请求url")
	local url = santong_query.builder_url(params)

	print("3.2 提交请求")
	local content = santong_query.http:get(url, santong_query.encoding)
	print("url:"..url)
	print("content:"..tostring(content))

	print("3.3 解析返回结果")
	if(xstring.empty(content)) then
		error("查询请求返回空.url:"..url)
		return sys.error.response_empty
	end
	local data = xtable.parse(content, 1)
	if(tostring(data.errorCode) ~= santong_query.up_succ_code) then
		return {code = data.errorCode, msg = data.errorDesc}
	end
	params.up_order_no = data.hfOrderNo
	params.up_order_status = data.orderStatus

	return sys.error.success
end

santong_query.save_query_result = function(recharge_result ,params)
	local input = {delivery_id = params.delivery_id,
				channel_no = params.up_channel_no,
				success_standard = 0,
				result_source = santong_query.result_source,
				result_msg = recharge_result.msg,
				up_order_no = params.up_order_no or "",
				query_timespan = params.query_timespan or 0,
				robot_code = santong_query.local_ip}
	if(recharge_result.code == sys.error.success.code) then
		input.up_error_code = santong_query.get_up_error_code(tostring(params.up_order_status))
	elseif(recharge_result.code == sys.error.response_empty.code) then
		input.up_error_code = santong_query.get_up_error_code(sys.error.response_empty.code)
	else
		input.up_error_code = santong_query.get_up_error_code(recharge_result.code)
	end

	local dbg_result = santong_query.grs_dbg:execute("order.delivery.save", input)
	return dbg_result.result, dbg_result.data
end

--{order_no, delivery_id, content}
santong_query.lifetime_save = function(params, msg)
	local input = {order_no = params.order_no,
					delivery_id = params.delivery_id or 0,
					ip = santong_query.local_ip,
					content = msg}
	local dbg_result = santong_query.grs_dbg:execute("order.lifetime.save", input)
	if(dbg_result.result.code ~= sys.error.success.code) then
		error("生命周期保存失败:"..xtable.tojson(dbg_result.result))
	end
	return dbg_result.result
end

santong_query.builder_url = function(params)
	return string.format("%s?coopId=%s&merchantOrderNo=%s&sign=%s",
						params.query_url,
						params.account_name,
						params.delivery_id,
						santong_query.builder_sign(params))
end

santong_query.builder_sign = function(params)
	--coopId+merchantOrderNo+secretKey
	local raw = params.account_name
				..params.delivery_id
				..sys.decrypt_pwd(params.up_channel_no, params.token_key)
	print("签名原串:"..raw)
	return string.lower(xutility.md5.encrypt(raw))
end

santong_query.get_up_error_code = function(code)
	return santong_query.pre_code..string.upper(code)
end

santong_query.next_step = function(params)
	if(xstring.empty(params.next_step_data.next_step)) then
		return true
	end
	local queues = xmq(params.next_step_data.next_step)
	queues:send({delivery_id = params.delivery_id, order_no = params.next_step_data.order_no, query_id = params.next_step_data.query_id})
	return true
end

return santong_query
