require "sys"
require "custom.common.xhttp"
require "custom.common.xxml"

quxun_delivery = {fields = "delivery_id",
				encoding = "UTF-8",
				pre_code = "QUXUN_D_",
				up_product_type = "sinopec",
				result_source = 2,
				local_ip = flowlib.get_local_ip()}
quxun_delivery.grs_dbg = xdbg("grs_db")
quxun_delivery.http = xhttp()
quxun_delivery.up_delivery_status = {wait = "0", success = "1", rechargeing = "2"}

quxun_delivery.main = function(args)
	print("------------------上游发货(趣讯)------------------")
	print("1. 检查参数")
	local params = xtable.parse(args[2], 1)
	if(xobject.empty(params, quxun_delivery.fields)) then
		error(string.format("缺少参数.需传入:%s,已传入:%s", quxun_delivery.fields, args[2]))
		return sys.error.param_miss
	end
	params.robot_code = quxun_delivery.local_ip

	print("2. 获取发货数据")
	local result, delivery_data = quxun_delivery.get_delivery_data(params)
	quxun_delivery.lifetime_save(params, "【发货获取】"..tostring(result.code))
	if(result.code ~= sys.error.success.code) then
		return result
	end
	params = xtable.merge(params, delivery_data)

	print("3. 提交上游发货请求")
	result = quxun_delivery.request_up_delivery(params)
	quxun_delivery.lifetime_save(params, "【发货结果】"..tostring(result.code))

	print("4. 保存发货结果")
	result, params.next_step_data = quxun_delivery.delivery_save(result, params)
	quxun_delivery.lifetime_save(params, string.format("【发货保存】%s【%s】", result.code, tostring(params.next_step_data and params.next_step_data.next_step)))
	if(result.code ~= sys.error.success.code) then
		return result
	end

	print("5. 处理后续流程")
	quxun_delivery.next_step(params)

	return sys.error.success
end

quxun_delivery.get_delivery_data = function(params)
	local dbg_result = quxun_delivery.grs_dbg:execute("order.delivery.get", params)
	if(dbg_result.result.code ~= sys.error.success.code) then
		return dbg_result.result
	end
	local delivery_data = dbg_result.data

	local dbg_result = quxun_delivery.grs_dbg:execute("order.delivery.get_delivery_config", delivery_data)
	if(dbg_result.result.code ~= sys.error.success.code) then
		return dbg_result.result
	end
	delivery_data = xtable.merge(delivery_data, dbg_result.data)

	return sys.error.success, delivery_data
end

quxun_delivery.request_up_delivery = function(params)
	print("3.1 构建请求数据")
	local post_data = quxun_delivery.builder_post_data(params)

	print("3.2 提交请求")
	local content = quxun_delivery.http:post(params.recharge_url, post_data, quxun_delivery.encode)
	print("url:"..params.recharge_url)
	print("post_data:"..post_data)
	print("content:"..tostring(content))

	print("3.3 解析返回结果")
	if(xstring.empty(content)) then
		error("发货请求返回空.post_data:"..post_data)
		return sys.error.response_empty
	end
	local data = quxun_delivery.analysis(content)
	if(tostring(data.resultno) ~= quxun_delivery.up_delivery_status.wait
		and tostring(data.resultno) ~= quxun_delivery.up_delivery_status.success
		and tostring(data.resultno) ~= quxun_delivery.up_delivery_status.rechargeing) then
		error("提交订单失败")
		return {code = sys.error.failure.code, msg = "提交订单返回失败,状态码:"..tostring(data.resultno)}
	end
	params.up_order_no = data.up_order_no

	return sys.error.success
end

quxun_delivery.delivery_save = function(recharge_result, params)
	local input = {delivery_id = params.delivery_id,
				channel_no = params.up_channel_no,
				success_standard = 0,
				up_order_no = params.up_order_no or "",
				result_source = quxun_delivery.result_source,
				result_msg = recharge_result.msg,
				query_timespan = params.query_timespan,
				robot_code = quxun_delivery.local_ip}
	input.up_error_code = quxun_delivery.get_up_error_code(recharge_result.code)

	local dbg_result = quxun_delivery.grs_dbg:execute("order.delivery.save", input)
	return dbg_result.result, dbg_result.data
end

quxun_delivery.analysis = function(content)
	local xml = xxml()
	xml:load(content)
	local data = {}
	data.up_order_no = xml:get("//order/orderid","innerText")
	data.ordercash = xml:get("//order/ordercash","innerText")
	data.resultno = xml:get("//order/resultno","innerText")

	return data
end

quxun_delivery.get_up_error_code = function(code)
	return quxun_delivery.pre_code..string.upper(code)
end

--{order_no, delivery_id, content}
quxun_delivery.lifetime_save = function(params, msg)
	local params = {order_no = params.order_no,
					delivery_id = params.delivery_id,
					ip = quxun_delivery.local_ip,
					content = msg}
	local dbg_result = quxun_delivery.grs_dbg:execute("order.lifetime.save", params)
	if(dbg_result.result.code ~= sys.error.success.code) then
		error("生命周期保存失败:"..xtable.tojson(dbg_result.result))
	end
	return dbg_result.result
end

quxun_delivery.builder_post_data = function(params)
	local order_time = tostring(xdate:now("yyyyMMddhhmmss"))
	return string.format("product=%s&userid=%s&price=%s&num=%s&account_number=%s&spordertime=%s&sporderid=%s&sign=%s&back_url=%s",
						quxun_delivery.up_product_type,
						params.account_name,
						params.total_face,
						1,
						params.recharge_account_id,
						order_time,
						params.delivery_id,
						quxun_delivery.builder_sign(params, order_time),
						params.notify_url)
end

quxun_delivery.builder_sign = function(params, order_time)
	local raw = string.format("product=%s&userid=%s&price=%s&num=%s&account_number=%s&spordertime=%s&sporderid=%s&key=%s",
							quxun_delivery.up_product_type,
							params.account_name,
							params.total_face,
							1,
							params.recharge_account_id,
							order_time,
							params.delivery_id,
							sys.decrypt_pwd(params.up_channel_no, params.token_key))
	print("签名原串:"..raw)
	return string.upper(xutility.md5.encrypt(raw))
end

quxun_delivery.next_step = function(params)
	if(xstring.empty(params.next_step_data.next_step)) then
		return true
	end
	local queues = xmq(params.next_step_data.next_step)
	queues:send({delivery_id = params.delivery_id, order_no = params.next_step_data.order_no, query_id = params.next_step_data.query_id})
	return true
end

return quxun_delivery
