require "sys"
require "custom.common.wclient"
require "lib.loginlib"

zsh_kami_recharge = {fields = "delivery_id,order_no,recharge_account_id",
					send_sms_code_limit = 2,
					download_number_code_limit = 2,
					local_ip = flowlib.get_local_ip(),
					recharge_mutex_lock_name = "zsh.website.recharge:%s"
					}
zsh_kami_recharge.commonlib = require "zsh.website_recharge.commonlib"
zsh_kami_recharge.sms_code = require "zsh.website_recharge.sms_code"
zsh_kami_recharge.image_code = require "zsh.website_recharge.image_code"
zsh_kami_recharge.gasoline_card = require "zsh.website_recharge.gasoline_card"
zsh_kami_recharge.recharge_card = require "zsh.website_recharge.recharge_card"
zsh_kami_recharge.recharge_order = require "zsh.website_recharge.recharge_order"
zsh_kami_recharge.grs_dbg = xdbg("grs_db")
zsh_kami_recharge.http = wclient()


zsh_kami_recharge.main = function(args)
	print("------------------中石化网页充值------------------")
	print("1. 检查参数")
	local params = xtable.parse(args[2], 1)
	if(xobject.empty(params, zsh_kami_recharge.fields)) then
		error(string.format("缺少参数.需传入:%s,已传入:%s", zsh_kami_recharge.fields, args[2]))
		return sys.error.param_miss
	end
	params.robot_code = zsh_kami_recharge.local_ip
	params.has_submit_recharge = false
	local result = nil
	if(zsh_kami_recharge.http == nil) then
		zsh_kami_recharge.lifetime_save(params, string.format("【ie browser】%s", sys.error.system_busy.code))
		error("创建浏览器失败,重置发货超时时长")
		zsh_kami_recharge.reset_delivery_timeout(params)
		return sys.error.system_busy
	end

	print("2. 获取中石化网页充值短信发送号码")
	result = zsh_kami_recharge.get_validcode_mobile(params)
	if(result.code ~= sys.error.success.code) then
		error("无可用的手机号,重置发货超时时长")
		zsh_kami_recharge.reset_delivery_timeout(params)
		return result
	end

	print("3. 获取发货数据")
	result, delivery_data = zsh_kami_recharge.get_delivery_data(params)
	zsh_kami_recharge.lifetime_save(params, "【发货获取】"..tostring(result.code))
	if(result.code ~= sys.error.success.code) then
		error(string.format("获取发货数据返回:%s,重置发货超时时长", result.code))
		zsh_kami_recharge.reset_delivery_timeout(params)
		zsh_kami_recharge.send_sms_code_success(params)
		return result
	end
	delivery_data.card_pwd = sys.decrypt_pwd(delivery_data.card_no, delivery_data.card_pwd)
	for i,v in pairs(delivery_data) do
		params[i] = v
	end

	print("4. 开始发货流程")
	local recharge_result, query_result = zsh_kami_recharge.delivery_flow(params)
	if(params.lock_obj ~= nil) then
		print("流程锁释放")
		zsh_kami_recharge.flow_unlock(params.lock_obj)
	end
	if(recharge_result.code == sys.error.delivery.sms_code_error.code
		or recharge_result.code == sys.error.sms.get_sms_content_failure.code
		or recharge_result.code == sys.error.sms.send_failure.code) then
		zsh_kami_recharge.send_sms_code_failure(params)
	else
		zsh_kami_recharge.send_sms_code_success(params)
	end

	print("5. 保存发货结果")
	result, params.next_step_data = zsh_kami_recharge.delivery_save(params, recharge_result, query_result)
	if(result.code ~= sys.error.success.code) then
		error("保存发货结果失败")
		return result
	end

	print("6. 处理后续流程")
	zsh_kami_recharge.next_step(params)

	return sys.error.success
end

zsh_kami_recharge.delivery_flow = function(params)
	local start, result = 4.0
	if(tostring(params.need_login) == "0") then
		start = start + 0.1
		print(string.format("%s. 流程锁开始", start))
		params.lock_obj = zsh_kami_recharge.flow_lock(string.format(zsh_kami_recharge.recharge_mutex_lock_name, params.third_login_name))

		start = start + 0.1
		print(string.format("%s. 获取登录cookie", start))
		result = zsh_kami_recharge.get_web_login_data(params)
		if(result.code ~= sys.error.success.code) then
			zsh_kami_recharge.lifetime_save(params, "【发货登录】"..tostring(result.code))
			return sys.error.delivery.login_failure
		end

		start = start + 0.1
		print(string.format("%s. 检查是否登录成功", start))
		result = loginlib.check_is_logined(zsh_kami_recharge.http)
		if(result.code ~= sys.error.success.code) then
			zsh_kami_recharge.lifetime_save(params, "【登录失败】"..tostring(result.code))
			return sys.error.delivery.login_failure
		end
	end

	if(tostring(params.need_check_card) == "0") then
		start = start + 0.1
		print(string.format("%s. 检查充值卡使用状态", start))
		result = zsh_kami_recharge.recharge_card.check(zsh_kami_recharge.http, params)
		if(result.code ~= sys.error.delivery.recharge_card_normal.code) then
			zsh_kami_recharge.lifetime_save(params, "【发货验卡】"..tostring(result.code))
			return result
		end
	end

	start = start + 0.1
	print(string.format("%s. 开始页面流程", start))
	local recharge_result, query_result = zsh_kami_recharge.page_flow(params)
	if(recharge_result.code ~= sys.error.success.code) then
		zsh_kami_recharge.lifetime_save(params, "【发货结果】"..tostring(recharge_result.code))
	end

	return recharge_result, query_result
end

zsh_kami_recharge.page_flow = function(params)
	::send_sms_code::
	print("发送短信验证码")
	params.__current_send_sms_code_num = (params.__current_send_sms_code_num or 0) + 1
	params.__current_download_img_code_num = 0
	local result = nil
	result, params.gasoline_card_status = zsh_kami_recharge.sms_code.send(zsh_kami_recharge.http, params)
	if(result.code ~= sys.error.success.code) then
		return result
	end

	print("接收短信验证码")
	result, params.sms_code = zsh_kami_recharge.sms_code.receive(zsh_kami_recharge.sms_dbg, params)
	if(result.code ~= sys.error.success.code) then
		return result
	end

	print("查询加油卡信息")
	result, user_card_info = zsh_kami_recharge.gasoline_card.query(zsh_kami_recharge.http, params)
	if(result.code == sys.error.delivery.sms_code_error.code
		and params.__current_send_sms_code_num <= zsh_kami_recharge.send_sms_code_limit) then
		goto send_sms_code
	elseif(result.code ~= sys.error.success.code) then
		return result
	end

	print("将加油卡信息加入至MQ")
	zsh_kami_recharge.join_to_card_info_save_mq(params, user_card_info)

	::download_image_code::
	print("下载并识别图片验证码")
	params.__current_download_img_code_num = params.__current_download_img_code_num + 1
	result, params.img_code = zsh_kami_recharge.image_code.download(zsh_kami_recharge.http)
	if(result.code ~= sys.error.success.code) then
		return result
	end

	print("提交充值")
	result, params.zsh_order_info = zsh_kami_recharge.recharge_order.submit(zsh_kami_recharge.http, params)
	zsh_kami_recharge.flow_unlock(lock_obj)
	if(result.code ~= sys.error.success.code) then
		return result
	end

	print("查询充值结果")
	local query_result = zsh_kami_recharge.recharge_order.query(zsh_kami_recharge.http, params)
	return result, query_result
end

zsh_kami_recharge.get_validcode_mobile = function(params)
	local dbg_result = zsh_kami_recharge.grs_dbg:execute("recharge.mobile.get", params)
	if(dbg_result.result.code ~= sys.error.success.code) then
		zsh_kami_recharge.lifetime_save(params, string.format("【取手机号】%s", dbg_result.result.code))
		return dbg_result.result
	end
	params.validcode_mobile = dbg_result.data.validcode_mobile
	params.recharge_mobile_id = dbg_result.data.recharge_mobile_id
	params.mobile_use_id = dbg_result.data.mobile_use_id
	return sys.error.success
end

zsh_kami_recharge.send_sms_code_success = function(params)
	print("短信发送成功,归还号码")
	params.is_success = 0
	local dbg_result = zsh_kami_recharge.grs_dbg:execute("recharge.mobile.back", params)
	zsh_kami_recharge.lifetime_save(params, string.format("【还手机号】%s【%s】", dbg_result.result.code, params.validcode_mobile))
	if(dbg_result.result.code ~= sys.error.success.code) then
		error("归还手机号失败:"..dbg_result.result.code)
	end
	return dbg_result.result
end

zsh_kami_recharge.send_sms_code_failure = function(params)
	print("短信发送失败,归还号码")
	params.is_success = 1
	local dbg_result = zsh_kami_recharge.grs_dbg:execute("recharge.mobile.back", params)
	zsh_kami_recharge.lifetime_save(params, string.format("【还手机号】%s【%s】", dbg_result.result.code, params.validcode_mobile))
	if(dbg_result.result.code ~= sys.error.success.code) then
		error("归还手机号失败:"..dbg_result.result.code)
	end
	return dbg_result.result
end

zsh_kami_recharge.reset_delivery_timeout = function(params)
	local dbg_result = zsh_kami_recharge.grs_dbg:execute("order.delivery.reset_delivery_timeout", params)
	zsh_kami_recharge.lifetime_save(params, string.format("【重置超时】%s", dbg_result.result.code))
	return dbg_result.result
end

zsh_kami_recharge.get_delivery_data = function(params)
	local dbg_result = zsh_kami_recharge.grs_dbg:execute("order.delivery.kami_get", params)
	return dbg_result.result, dbg_result.data
end

zsh_kami_recharge.get_web_login_data = function(params)
	local result, cookie = loginlib.get_cookies(params.up_channel_no, params.up_shelf_id, params.third_login_name)
	if(result.code ~= sys.error.success.code) then
		return sys.error.login.get_cookie_failure
	end
	loginlib.clear_web_cookies(zsh_kami_recharge.http)
	loginlib.set_web_cookies(zsh_kami_recharge.http, cookie)
	return sys.error.success
end


zsh_kami_recharge.delivery_save = function(input, recharge_result, query_result)
	local params = {}
	params.delivery_id = input.delivery_id
	params.channel_no = input.up_channel_no
	params.success_standard = 0
	params.result_source = 2
	params.result_msg = recharge_result.msg
	params.up_order_no = (input.zsh_order_info and input.zsh_order_info.order_id) or ""
	params.query_timespan = input.query_timespan
	params.up_error_code = zsh_commonlib.get_deal_code(sys.error.delivery.recharge.submit.unkown.code)
	params.card_use_status = zsh_kami_recharge.commonlib.recharge_card_status.unkown
	params.robot_code = zsh_kami_recharge.local_ip
	print("has_submit_recharge:"..tostring(input.has_submit_recharge))
	if(not(input.has_submit_recharge)) then
		if(recharge_result.code == sys.error.login.get_cookie_failure.code) then
			params.card_msg = "获取登录cookie失败"
			params.card_use_status = zsh_kami_recharge.commonlib.recharge_card_status.unuse
			params.up_error_code = zsh_commonlib.get_deal_code(sys.error.get_cookie_failure.code)

		elseif(recharge_result.code == sys.error.delivery.recharge_card_has_been_used.code) then
			params.card_msg = "充值卡已被使用"
			params.card_use_status = zsh_kami_recharge.commonlib.recharge_card_status.exp_card
			params.up_error_code = zsh_commonlib.get_deal_code(sys.error.recharge_card_has_been_used.code)

		elseif(recharge_result.code == sys.error.delivery.recharge_card_status_exp.code) then
			params.card_msg = "充值卡状态异常"
			params.card_use_status = zsh_kami_recharge.commonlib.recharge_card_status.exp_card
			params.up_error_code = zsh_commonlib.get_deal_code(sys.error.recharge_card_status_exp.code)

		elseif(recharge_result.code == sys.error.delivery.verify_card_error.code) then
			params.card_msg = "获取充值卡使用状态失败"
			params.card_use_status = zsh_kami_recharge.commonlib.recharge_card_status.unuse
			params.up_error_code = zsh_commonlib.get_deal_code(sys.error.verify_card_error.code)

		else
			params.card_msg = recharge_result.msg
			params.card_use_status = zsh_kami_recharge.commonlib.recharge_card_status.unuse
			params.up_error_code = zsh_commonlib.get_deal_code(recharge_result.code)

		end
	else
		if(recharge_result.code == sys.error.delivery.recharge.submit.card_pwd_error.code) then
			params.card_msg = recharge_result.msg
			params.up_error_code = zsh_commonlib.get_deal_code(recharge_result.code)
			params.card_use_status = zsh_kami_recharge.commonlib.recharge_card_status.exp_card
		elseif(recharge_result.code ~= sys.error.success.code) then
			params.card_msg = "提交充值请求失败"
			params.up_error_code = zsh_commonlib.get_deal_code(recharge_result.code)
			params.card_use_status = zsh_kami_recharge.commonlib.recharge_card_status.unkown

		elseif(query_result.code == sys.error.delivery.recharge_success.code) then
			params.card_msg = "充值成功,卡已使用"
			params.up_error_code = zsh_commonlib.get_deal_code(sys.error.delivery.recharge_success.code)
			params.card_use_status = zsh_kami_recharge.commonlib.recharge_card_status.used

		else
			params.card_msg = "提交充值成功,订单查询失败.充值卡使用结果未知"
			params.up_error_code = zsh_commonlib.get_deal_code(query_result.code)
			params.result_msg = query_result.msg

		end
	end

	debug("result_msg:"..params.result_msg)
	debug("card_msg:"..params.card_msg)
	debug("up_error_code:"..params.up_error_code)

	local dbg_result = zsh_kami_recharge.grs_dbg:execute("order.delivery.save", params)
	zsh_kami_recharge.lifetime_save(input, string.format("【发货保存】%s【%s】【%s】", dbg_result.result.code, tostring(dbg_result.data and dbg_result.data.next_step), tostring(params.card_msg)))
	return dbg_result.result, dbg_result.data

end

zsh_kami_recharge.next_step = function(params)
	if(xstring.empty(params.next_step_data.next_step)) then
		return true
	end
	local queues = xmq(params.next_step_data.next_step)
	queues:send({delivery_id = params.delivery_id, order_no = params.next_step_data.order_no, query_id = params.next_step_data.query_id})
	return true
end

zsh_kami_recharge.join_to_card_info_save_mq = function(params, user_card_info)
	local send_data = {card_no = params.recharge_account_id,
					card_holder = user_card_info.card_holder or "",
					carrier_no = "ZSH",
					status = user_card_info.status,
					is_complete = 0}
	local queues = xmq("gasoline_card_save")
	queues:send(send_data)
end

--{order_no, delivery_id, content}
zsh_kami_recharge.lifetime_save = function(params, msg)
	local params = {order_no = params.order_no,
					delivery_id = params.delivery_id,
					ip = zsh_kami_recharge.local_ip,
					content = msg}
	local dbg_result = zsh_kami_recharge.grs_dbg:execute("order.lifetime.save", params)
	if(dbg_result.result.code ~= sys.error.success.code) then
		error("生命周期保存失败:"..xtable.tojson(dbg_result.result))
	end
	return dbg_result.result
end

zsh_kami_recharge.flow_lock = function(lock_name)
	local mutex = base.GlobalMutex(lock_name)
	local wait = mutex:TryLock(10*1000)
	return mutex
end

zsh_kami_recharge.flow_unlock = function(mutex)
	if(mutex ~= nil) then
		mutex:Unlock()
	end
	return true
end

return zsh_kami_recharge
