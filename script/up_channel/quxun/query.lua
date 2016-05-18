require "sys"
require "custom.common.xhttp"
require "custom.common.xxml"

quxun_query = {fields = "query_id,order_no",
				encoding = "utf-8",
				pre_code = "QUXUN_Q_",
				result_source = 3,
				next_query_wait_minutes = 5,
				local_ip = flowlib.get_local_ip()}
quxun_query.grs_dbg = xdbg("grs_db")
quxun_query.http = xhttp()

quxun_query.main = function(args)
	print("------------------上游查询(趣讯)------------------")
	print("1. 检查参数")
	local params = xtable.parse(args[2], 1)
	if(xobject.empty(params, quxun_query.fields)) then
		error(string.format("缺少参数.需传入:%s,已传入:%s", quxun_query.fields, args[2]))
		return sys.error.param_miss
	end
	params.robot_code = quxun_query.local_ip

	print("2. 获取发货数据")
	local result, delivery_data = quxun_query.get_delivery_data(params)
	quxun_query.lifetime_save(params, "【查询获取】"..tostring(result.code))
	if(result.code ~= sys.error.success.code) then
		return result
	end
	params = xtable.merge(params, delivery_data)

	print("3. 提交上游查询请求")
	result = quxun_query.request_up_query(params)
	if(result.code == sys.error.success.code) then
		quxun_query.lifetime_save(params, string.format("【查询结果】%s", result.code))
	else
		quxun_query.lifetime_save(params, string.format("【查询结果】%s|%s", result.code, result.msg))
	end

	print("4. 保存查询结果")
	result, params.next_step_data = quxun_query.save_query_result(result, params)
	quxun_query.lifetime_save(params, string.format("【查询保存】%s【%s】", result.code, tostring(params.next_step_data and params.next_step_data.next_step)))
	if(result.code ~= sys.error.success.code) then
		error("保存查询结果失败:"..xtable.tojson(result))
		return result
	end

	print("5. 处理后续流程")
	quxun_query.next_step(params)

	return sys.error.success
end

quxun_query.get_delivery_data = function(params)
	local dbg_result = quxun_query.grs_dbg:execute("order.delivery_query.get",{query_id = params.query_id,
																				wait_time = quxun_query.next_query_wait_minutes,
																				robot_code = quxun_query.local_ip})
	if(dbg_result.result.code ~= sys.error.success.code) then
		return dbg_result.result
	end
	local data = dbg_result.data

	dbg_result = quxun_query.grs_dbg:execute("order.delivery_query.get_query_config", data)
	if(dbg_result.result.code ~= sys.error.success.code) then
		return dbg_result.result
	end
	data = xtable.merge(data, dbg_result.data)

	return sys.error.success, data
end

quxun_query.request_up_query = function(params)
	print("3.1 构建请求url")
	local post_data = quxun_query.builder_post_data(params)

	print("3.2 提交请求")
	local content = quxun_query.http:post(params.query_url, post_data, quxun_query.encoding)
	print("url:"..params.query_url)
	print("post_data:"..post_data)
	print("content:"..tostring(content))

	print("3.3 解析返回结果")
	if(xstring.empty(content)) then
		error("查询请求返回空.url:"..url)
		return sys.error.response_empty
	end

	local data = quxun_query.analysis(content)
	params.up_order_no = data.up_order_no
	params.up_result_status = data.resultno

	return sys.error.success
end

quxun_query.save_query_result = function(recharge_result ,params)
	local input = {delivery_id = params.delivery_id,
				channel_no = params.up_channel_no,
				success_standard = 0,
				result_source = quxun_query.result_source,
				result_msg = recharge_result.msg,
				up_order_no = params.up_order_no or "",
				query_timespan = params.query_timespan or 0,
				robot_code = quxun_query.local_ip}

	if(recharge_result.code ~= sys.error.success.code) then
		input.up_error_code = quxun_query.get_up_error_code(recharge_result.code)
	else
		input.up_error_code = quxun_query.get_up_error_code("RESULT"..tostring(params.up_result_status))
	end

	local dbg_result = quxun_query.grs_dbg:execute("order.delivery.save", input)
	return dbg_result.result, dbg_result.data
end

quxun_query.analysis = function(content)
	local xml = xxml()
	xml:load(content)
	local data = {}
	data.up_order_no = xml:get("//order/orderid","innerText")
	data.ordercash = xml:get("//order/ordercash","innerText")
	data.resultno = xml:get("//order/resultno","innerText")

	return data
end

--{order_no, delivery_id, content}
quxun_query.lifetime_save = function(params, msg)
	local input = {order_no = params.order_no,
					delivery_id = params.delivery_id or 0,
					ip = quxun_query.local_ip,
					content = msg}
	local dbg_result = quxun_query.grs_dbg:execute("order.lifetime.save", input)
	if(dbg_result.result.code ~= sys.error.success.code) then
		error("生命周期保存失败:"..xtable.tojson(dbg_result.result))
	end
	return dbg_result.result
end

quxun_query.builder_post_data = function(params)
	return string.format("userid=%s&sporderid=%s&sign=%s",
						params.account_name,
						params.delivery_id,
						quxun_query.builder_sign(params))
end

quxun_query.builder_sign = function(params)
	local raw = string.format("userid=%s&sporderid=%s&key=%s",
							params.account_name,
							params.delivery_id,
							sys.decrypt_pwd(params.up_channel_no, params.token_key))
	print("签名原串:"..raw)
	return string.upper(xutility.md5.encrypt(raw))
end

quxun_query.get_up_error_code = function(code)
	return quxun_query.pre_code..string.upper(code)
end

quxun_query.next_step = function(params)
	if(xstring.empty(params.next_step_data.next_step)) then
		return true
	end
	local queues = xmq(params.next_step_data.next_step)
	queues:send({delivery_id = params.delivery_id, order_no = params.next_step_data.order_no, query_id = params.next_step_data.query_id})
	return true
end

return quxun_query
