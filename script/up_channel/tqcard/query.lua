require "sys"
require "custom.common.xhttp"

tqcard_query = {fields = "query_id,order_no",
				encoding = "utf-8",
				pre_code = "TQCARD_Q_",
				result_source = 3,
				next_query_wait_minutes = 5,
				local_ip = flowlib.get_local_ip()}
tqcard_query.grs_dbg = xdbg("grs_db")
tqcard_query.http = xhttp()
tqcard_query.up_order_status = {wait_pay = 1, pay_succ = 2, pay_failure = 3}
tqcard_query.up_delivery_status = {not_delivery = 0, deliverying = 1, success = 2, failure = 3, wait_delivery = 4}

tqcard_query.main = function(args)
	print("------------------上游查询(同求网)------------------")
	print("1. 检查参数")
	local params = xtable.parse(args[2], 1)
	if(xobject.empty(params, tqcard_query.fields)) then
		error(string.format("缺少参数.需传入:%s,已传入:%s", tqcard_query.fields, args[2]))
		return sys.error.param_miss
	end
	params.robot_code = tqcard_query.local_ip

	print("2. 获取发货数据")
	local result, delivery_data = tqcard_query.get_delivery_data(params)
	tqcard_query.lifetime_save(params, "【查询获取】"..tostring(result.code))
	if(result.code ~= sys.error.success.code) then
		return result
	end
	params = xtable.merge(params, delivery_data)

	print("3. 提交上游查询请求")
	result = tqcard_query.request_up_query(params)
	if(result.code == sys.error.success.code) then
		tqcard_query.lifetime_save(params, string.format("【查询结果】%s", result.code))
	else
		tqcard_query.lifetime_save(params, string.format("【查询结果】%s|%s", result.code, result.msg))
	end

	print("4. 保存查询结果")
	result, params.next_step_data = tqcard_query.save_query_result(result, params)
	tqcard_query.lifetime_save(params, string.format("【查询保存】%s【%s】", result.code, tostring(params.next_step_data and params.next_step_data.next_step)))
	if(result.code ~= sys.error.success.code) then
		error("保存查询结果失败:"..xtable.tojson(result))
		return result
	end

	print("5. 处理后续流程")
	tqcard_query.next_step(params)

	return sys.error.success
end

tqcard_query.get_delivery_data = function(params)
	local dbg_result = tqcard_query.grs_dbg:execute("order.delivery_query.get",{query_id = params.query_id,
																				wait_time = tqcard_query.next_query_wait_minutes,
																				robot_code = tqcard_query.local_ip})
	if(dbg_result.result.code ~= sys.error.success.code) then
		return dbg_result.result
	end
	local data = dbg_result.data

	dbg_result = tqcard_query.grs_dbg:execute("order.delivery_query.get_query_config", data)
	if(dbg_result.result.code ~= sys.error.success.code) then
		return dbg_result.result
	end
	data = xtable.merge(data, dbg_result.data)

	return sys.error.success, data
end

tqcard_query.request_up_query = function(params)
	print("3.1 构建请求url")
	local url = tqcard_query.builder_url(params)

	print("3.2 提交请求")
	local content = tqcard_query.http:get(url, tqcard_query.encoding)
	print("url:"..url)
	print("content:"..tostring(content))

	print("3.3 解析返回结果")
	if(xstring.empty(content)) then
		error("查询请求返回空.url:"..url)
		return sys.error.response_empty
	end

	local query_data = xtable.parse(content, 1)
	if(tostring(query_data.result) ~= "ok") then
		if(string.find(query_data.msg, "订单不存在") == nil) then
			return {code = sys.error.failure.code, msg = "上游返回:"..tostring(query_data.msg)}
		end
		return {code = sys.error.not_exists.code, msg = "上游返回:"..tostring(query_data.msg)}
	end
	if(xtable.empty(query_data.data)) then
		return {code = sys.error.unkown.code, msg = "上游返回结果中不包含data属性"}
	end

	print("3.4 检查查询结果中签名")
	local sign = xutility.md5.encrypt(tostring(query_data.data.userid)..sys.decrypt_pwd(params.up_channel_no, params.token_key))
	if(string.upper(sign) ~= string.upper(tostring(query_data.key))) then
		return sys.error.sign_error
	end

	params.up_order_no = query_data.data.id
	params.up_order_status = query_data.data.orderstatus
	params.up_delivery_status = query_data.data.dlystatus

	if(xstring.empty(query_data.data.errormsg)) then
		return sys.error.success
	end
	return {code = sys.error.success.code, msg = "上游返回:"..tostring(query_data.data.errormsg)}
end

tqcard_query.save_query_result = function(recharge_result ,params)
	local input = {delivery_id = params.delivery_id,
				channel_no = params.up_channel_no,
				success_standard = 0,
				result_source = tqcard_query.result_source,
				result_msg = recharge_result.msg,
				up_order_no = params.up_order_no or "",
				query_timespan = params.query_timespan or 0,
				robot_code = tqcard_query.local_ip}

	if(recharge_result.code ~= sys.error.success.code) then
		input.up_error_code = tqcard_query.get_up_error_code(recharge_result.code)
	elseif(params.up_order_status == tqcard_query.up_order_status.wait_pay
		or params.up_order_status == tqcard_query.up_order_status.pay_failure) then
		input.up_error_code = tqcard_query.get_up_error_code("PAY"..tostring(params.up_order_status))
	else
		input.up_error_code = tqcard_query.get_up_error_code("DELIVERY"..tostring(params.up_delivery_status))
	end

	local dbg_result = tqcard_query.grs_dbg:execute("order.delivery.save", input)
	return dbg_result.result, dbg_result.data
end

--{order_no, delivery_id, content}
tqcard_query.lifetime_save = function(params, msg)
	local input = {order_no = params.order_no,
					delivery_id = params.delivery_id or 0,
					ip = tqcard_query.local_ip,
					content = msg}
	local dbg_result = tqcard_query.grs_dbg:execute("order.lifetime.save", input)
	if(dbg_result.result.code ~= sys.error.success.code) then
		error("生命周期保存失败:"..xtable.tojson(dbg_result.result))
	end
	return dbg_result.result
end

tqcard_query.builder_url = function(params)
	return string.format("%s?bizid=%s&userid=%s&key=%s",
						params.query_url,
						params.delivery_id,
						params.account_name,
						tqcard_query.builder_sign(params))
end

tqcard_query.builder_sign = function(params)
	local raw = params.account_name
				..params.delivery_id
				..sys.decrypt_pwd(params.up_channel_no, params.token_key)
	print("签名原串:"..raw)
	return string.lower(xutility.md5.encrypt(raw, tqcard_query.encoding))
end

tqcard_query.get_up_error_code = function(code)
	return tqcard_query.pre_code..string.upper(code)
end

tqcard_query.next_step = function(params)
	if(xstring.empty(params.next_step_data.next_step)) then
		return true
	end
	local queues = xmq(params.next_step_data.next_step)
	queues:send({delivery_id = params.delivery_id, order_no = params.next_step_data.order_no, query_id = params.next_step_data.query_id})
	return true
end

return tqcard_query
