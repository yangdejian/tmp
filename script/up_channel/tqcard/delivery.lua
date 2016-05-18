require "sys"
require "custom.common.xhttp"

tqcard_delivery = {fields = "delivery_id",
					encoding = "utf-8",
					pre_code = "TQCARD_D_",
					result_source = 2,
					local_ip = flowlib.get_local_ip()}
tqcard_delivery.grs_dbg = xdbg("grs_db")
tqcard_delivery.http = xhttp()

tqcard_delivery.main = function(args)
	print("------------------上游发货(同求网)------------------")
	print("1. 检查参数")
	local params = xtable.parse(args[2], 1)
	if(xobject.empty(params, tqcard_delivery.fields)) then
		error(string.format("缺少参数.需传入:%s,已传入:%s", tqcard_delivery.fields, args[2]))
		return sys.error.param_miss
	end
	params.robot_code = tqcard_delivery.local_ip

	print("2. 获取发货数据")
	local result, delivery_data = tqcard_delivery.get_delivery_data(params)
	tqcard_delivery.lifetime_save(params, "【发货获取】"..tostring(result.code))
	if(result.code ~= sys.error.success.code) then
		return result
	end
	params = xtable.merge(params, delivery_data)

	print("3. 提交上游发货请求")
	result = tqcard_delivery.request_up_delivery(params)
	tqcard_delivery.lifetime_save(params, "【发货结果】"..tostring(result.code))

	print("4. 保存发货结果")
	result, params.next_step_data = tqcard_delivery.delivery_save(result, params)
	tqcard_delivery.lifetime_save(params, string.format("【发货保存】%s【%s】", result.code, tostring(params.next_step_data and params.next_step_data.next_step)))
	if(result.code ~= sys.error.success.code) then
		return result
	end

	print("5. 处理后续流程")
	tqcard_delivery.next_step(params)

	return sys.error.success
end

tqcard_delivery.get_delivery_data = function(params)
	local dbg_result = tqcard_delivery.grs_dbg:execute("order.delivery.get", params)
	if(dbg_result.result.code ~= sys.error.success.code) then
		return dbg_result.result
	end
	local delivery_data = dbg_result.data

	local dbg_result = tqcard_delivery.grs_dbg:execute("order.delivery.get_delivery_config", delivery_data)
	if(dbg_result.result.code ~= sys.error.success.code) then
		return dbg_result.result
	end
	delivery_data = xtable.merge(delivery_data, dbg_result.data)

	return sys.error.success, delivery_data
end

tqcard_delivery.request_up_delivery = function(params)
	print("3.1 构建请求url")
	local url = tqcard_delivery.builder_url(params)

	print("3.2 提交请求")
	local content = tqcard_delivery.http:get(url, tqcard_delivery.encoding)
	print("url:"..url)
	print("content:"..tostring(content))

	print("3.3 解析返回结果")
	if(xstring.empty(content)) then
		error("发货请求返回空.url:"..url)
		return sys.error.response_empty
	end
	local data = xtable.parse(content, 1)
	if(tostring(data.result) ~= "ok") then
		error("提交订单失败:"..tostring(data.msg))
		return {code = sys.error.failure.code, msg = tostring(data.msg)}
	end
	params.up_order_no = string.gsub(data.msg, "订单ID：", "")

	return sys.error.success
end

tqcard_delivery.delivery_save = function(recharge_result, params)
	local input = {delivery_id = params.delivery_id,
				channel_no = params.up_channel_no,
				success_standard = 0,
				up_order_no = params.up_order_no or "",
				result_source = tqcard_delivery.result_source,
				result_msg = recharge_result.msg,
				query_timespan = params.query_timespan,
				robot_code = tqcard_delivery.local_ip}
	input.up_error_code = tqcard_delivery.get_up_error_code(recharge_result.code)
	local dbg_result = tqcard_delivery.grs_dbg:execute("order.delivery.save", input)
	return dbg_result.result, dbg_result.data
end

tqcard_delivery.get_up_error_code = function(code)
	return tqcard_delivery.pre_code..string.upper(code)
end

--{order_no, delivery_id, content}
tqcard_delivery.lifetime_save = function(params, msg)
	local params = {order_no = params.order_no,
					delivery_id = params.delivery_id,
					ip = tqcard_delivery.local_ip,
					content = msg}
	local dbg_result = tqcard_delivery.grs_dbg:execute("order.lifetime.save", params)
	if(dbg_result.result.code ~= sys.error.success.code) then
		error("生命周期保存失败:"..xtable.tojson(dbg_result.result))
	end
	return dbg_result.result
end

tqcard_delivery.builder_url = function(params)
	return string.format("%s?productid=%s&productnum=%s&bizid=%s&useract=%s&userid=%s&key=%s",
						params.recharge_url,
						params.up_product_no,
						params.product_num,
						params.delivery_id,
						params.recharge_account_id,
						params.account_name,
						tqcard_delivery.builder_sign(params))
end

tqcard_delivery.builder_sign = function(params)
	local raw = params.account_name..params.up_product_no..params.product_num..params.recharge_account_id..sys.decrypt_pwd(params.up_channel_no, params.token_key)
	print("签名原串:"..raw)
	return string.lower(xutility.md5.encrypt(raw))
end

tqcard_delivery.next_step = function(params)
	if(xstring.empty(params.next_step_data.next_step)) then
		return true
	end
	local queues = xmq(params.next_step_data.next_step)
	queues:send({delivery_id = params.delivery_id, order_no = params.next_step_data.order_no, query_id = params.next_step_data.query_id})
	return true
end

return tqcard_delivery
