require "bit"
require "sys"
require "custom.common.wclient"
require "custom.common.recognizelib"
require "lib.loginlib"

order_delivery = {fields = "delivery_id",
				encoding = "gbk",
				domain = "http://www.sinopecsales.com",
				send_sms_code_limit = 2,
				wait_smsras_code_limit = 3,
				download_number_code_limit = 3}
order_delivery.deal_code = {success = "000", failure = "100", unkown = "900"}
order_delivery.card_use_status = {waiting = 20, useing = 30, used = 0, unuse = 90, exp_card = 40, unkown = 99}
order_delivery.gasoline_card_archive_status = {normal = 0, --正常
											sub            = 1, --副卡,
											lose           = 2, --挂失
											damage         = 3, --损坏
											discard        = 4, --废弃
											card_exception = 5, --卡异常
											expire         = 6, --卡过期
											not_exists     = 9  --卡号不存在
											}
order_delivery.http = wclient()
order_delivery.recognize = recognize()
order_delivery.grs_dbg = xdbg("grs_db")
order_delivery.sms_dbg = xdbg("sms_db")


order_delivery.main = function(args)
	print("------------------上游发货------------------")
	print("1. 检查参数")
	order_delivery.params = xtable.parse(args[2], 1)
	if(xobject.empty(order_delivery.params, order_delivery.fields)) then
		error(string.format("缺少参数.需传入:%s,已传入:%s", order_delivery.fields, args[2]))
		return sys.error.param_miss
	end
	order_delivery.params.robot_code = flowlib.get_local_ip()
	order_delivery.params.__send_sms_code_times = 0

	print("2. 开始发货")
	local recharge_result, up_order_info, query_result, up_order_query_info = order_delivery.delivery_flow()
	if(recharge_result.code == sys.error.order.no_need_delivery.code) then
		error("订单无需发货,流程结束")
		return recharge_result
	end

	print("3. 保存发货结果")
	local result, next_step_data = order_delivery.delivery_save(recharge_result, up_order_info, query_result, up_order_query_info)
	if(result.code ~= sys.error.success.code) then
		error("保存发货结果失败")
		return result
	end

	print("4. 处理后续流程")
	order_delivery.next_step(next_step_data)

	return sys.error.success
end

order_delivery.delivery_flow = function()
	print("获取发货数据")
	local result = order_delivery.get_delivery_data()
	if(result.code ~= sys.error.success.code) then
		return result
	end

	print("获取网站登录Cookie")
	result = order_delivery.get_web_login_data()
	if(result.code ~= sys.error.success.code) then
		error("获取网站登录Cookie失败.无法进行后续发货流程")
		return result
	end

	print("检查是否需要验卡")
	if(tostring(order_delivery.delivery_data.need_check_card) == "0") then
		result = order_delivery.verify_card({card_no = order_delivery.delivery_data.card_no})
		if(result.code ~= sys.error.delivery.recharge_card_normal.code) then
			return result
		end
	end

	::send_sms_code::
	print("获取短信验证码")
	local sms_code, number_code, user_card_staus, user_card_info = nil
	order_delivery.params.__send_sms_code_times = order_delivery.params.__send_sms_code_times + 1
	order_delivery.params.__download_number_code_times = 0
	result, user_card_status, sms_code = order_delivery.get_sms_code({recharge_account_id = order_delivery.delivery_data.recharge_account_id,
													validcode_mobile = order_delivery.delivery_data.validcode_mobile,
													up_shelf_id = order_delivery.delivery_data.up_shelf_id})
	if(result.code == sys.error.delivery.user_card_cannot_recharge.code) then
		print("将加油卡信息加入至保存加油卡信息MQ中")
		result = order_delivery.join_to_card_info_save_mq(user_card_status, user_card_info)
		return result
	elseif(result.code ~= sys.error.success.code) then
		return result
	end

	print("发送中石化查询加油卡信息请求")
	result, user_card_status, user_card_info = order_delivery.request_query_card_info({recharge_account_id = order_delivery.delivery_data.recharge_account_id,
																					validcode_mobile = order_delivery.delivery_data.validcode_mobile,
																					sms_code = sms_code})
	if(result.code == sys.error.delivery.sms_code_error.code) then
		if(order_delivery.params.__send_sms_code_times < order_delivery.send_sms_code_limit) then
			goto send_sms_code
		else
			return result
		end
	elseif(result.code == sys.error.success.code) then
		print("将加油卡信息加入至保存加油卡信息MQ中")
		result = order_delivery.join_to_card_info_save_mq(user_card_status, user_card_info)
	else
		return result
	end

	::get_number_code::
	print("获取数字验证码")
	order_delivery.params.__download_number_code_times = order_delivery.params.__download_number_code_times + 1
	result, number_code = order_delivery.get_number_code()
	if(result.code ~= sys.error.success.code) then
		if(order_delivery.params.__download_number_code_times < order_delivery.download_number_code_limit) then
			goto get_number_code
		else
			return result
		end
	end

	print("发送中石化充值请求")
	local recharge_result, up_order_info = order_delivery.request_recharge({recharge_account_id = order_delivery.delivery_data.recharge_account_id,
															card_pwd = order_delivery.delivery_data.card_pwd,
															validcode_mobile = order_delivery.delivery_data.validcode_mobile,
															number_code = number_code,
															sms_code = sms_code})
	if(recharge_result.code == sys.error.delivery.sms_code_error.code) then
		if(order_delivery.params.__send_sms_code_times < order_delivery.send_sms_code_limit) then
			goto send_sms_code
		else
			return recharge_result
		end
	elseif(recharge_result.code == sys.error.delivery.number_code_error.code) then
		if(order_delivery.params.__download_number_code_times < order_delivery.download_number_code_limit) then
			goto get_number_code
		else
			return recharge_result
		end
	elseif(recharge_result.code ~= sys.error.success.code) then
		return recharge_result
	end

	print("发送中石化订单查询请求")
	local query_result, up_order_query_info = order_delivery.request_order_query({order_id = up_order_info.order_id})
	return recharge_result, up_order_info, query_result, up_order_query_info
end


order_delivery.get_web_login_data = function(up_shelf_id, login_name)
	local result, cookie = loginlib.get_cookies(order_delivery.delivery_data.up_shelf_id, order_delivery.delivery_data.third_login_name)
	if(result.code ~= sys.error.success.code) then
		return sys.error.login.get_cookie_failure
	end
	loginlib.clear_web_cookies(order_delivery.http)
	loginlib.set_web_cookies(order_delivery.http, cookie)
	return sys.error.success
end

order_delivery.get_delivery_data = function()
	local dbg_result = order_delivery.grs_dbg:execute("order.delivery.get", order_delivery.params)
	order_delivery.delivery_data = dbg_result.data
	return dbg_result.result
end

--{card_no}
order_delivery.verify_card = function(params)
	local input = {}
	input.encoding = order_delivery.encoding
	input.content = "json"
	input.method = "post"
	input.url = "http://www.sinopecsales.com/gas/webjsp/memberOilCardAction_searchCzkStatus.json"
	input.data = string.format("czkNo=%s", params.card_no)
	input.header= [[Accept:application/json, text/javascript, */*; q=0.01
Accept-Encoding:gzip, deflate
Accept-Language:zh-CN,zh;q=0.8
Connection:keep-alive
Content-Type:application/x-www-form-urlencoded; charset=UTF-8
Host:www.sinopecsales.com
Origin:http://www.sinopecsales.com
Referer:http://www.sinopecsales.com/gas/webjsp/myoil/myOilCard_v1.jsp
User-Agent:Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/48.0.2564.97 Safari/537.36
X-Requested-With:XMLHttpRequest]]
	local content = order_delivery.http:query(input, {}, 30000)
	if(xstring.empty(content)) then
		error(string.format("验卡请求返回空.url:%s,data:%s,header:%s", input.url, input.data, input.header))
		return {code = sys.error.delivery.verify_card_error.code, msg = "验卡请求返回空"}
	end
	if(order_delivery.is_html(content)) then
		error("验卡返回错误.内容:"..content)
		return {code = sys.error.delivery.verify_card_error.code, msg = "验卡请求返回需要登录"}
	end
	local result = xtable.parse(content, 1)
	if(result.czkUseStatus == nil) then
		error("验卡请求返回内容不包含卡状态.返回内容:"..content)
		return {code = sys.error.delivery.verify_card_error.code, msg = "验卡请求返回内容不包含卡状态"}
	elseif(result.czkUseStatus == "已使用") then
		error("卡已使用.发货编号:"..order_delivery.params.delivery_id)
		return sys.error.delivery.recharge_card_has_been_used
	elseif(result.czkUseStatus == "未使用") then
		print("卡未使用.可以正常发货")
		return sys.error.delivery.recharge_card_normal
	elseif(result.czkUseStatus == "error") then
		return sys.error.delivery.recharge_card_status_exp
	end
	error("验卡返回状态未知,response data:"..content)
	return sys.error.delivery.verify_card_result_unkown
end

order_delivery.send_sms_code = function(params)
	local input = {}
	input.encoding = order_delivery.encoding
	input.content = "json"
	input.method = "post"
	input.url = "http://www.sinopecsales.com/gas/html/netRechargeAction_getSmsYzm.json"
	input.data = string.format("cardNo=%s&phoneNo=%s", params.recharge_account_id, params.validcode_mobile)
	input.header = [[Accept:application/json, text/javascript, */*; q=0.01
Accept-Encoding:gzip, deflate
Accept-Language:zh-CN,zh;q=0.8
Connection:keep-alive
Content-Type:application/x-www-form-urlencoded; charset=UTF-8
Host:www.sinopecsales.com
Origin:http://www.sinopecsales.com
Referer:http://www.sinopecsales.com/gas/html/billQueryAction_goChangeCard.action
User-Agent:Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/48.0.2564.97 Safari/537.36
X-Requested-With:XMLHttpRequest]]
	local content = order_delivery.http:query(input, {}, 30000)
	if(xstring.empty(content)) then
		error(string.format("发送短信验证码请求返回空.url:%s,post_data:%s,header:%s", input.url, input.data, input.header))
		return {code = sys.error.failure.code, msg = "发送短信验证码返回空"}
	end
	if(order_delivery.is_html(content)) then
		error("发送短信验证码返回错误.内容:"..content)
		return {code = sys.error.failure.code, msg = "发送短信验证码返回需要登录"}
	end
	local data = xtable.parse(content, 1)
	local success_code = tostring(data.success)
	if(success_code == "0") then
		return sys.error.success
	elseif(success_code == "3") then
		error("加油卡不存在")
		return {code = sys.error.delivery.user_card_cannot_recharge.code, msg = "加油卡不存在"}, order_delivery.gasoline_card_archive_status.not_exists
	elseif(success_code == "4") then
		error("副卡不能进行充值")
		return {code = sys.error.delivery.user_card_cannot_recharge.code, msg = "副卡不能进行充值"}, order_delivery.gasoline_card_archive_status.sub
	elseif(success_code == "5") then
		error("加油卡已挂失,不能进行充值")
		return {code = sys.error.delivery.user_card_cannot_recharge.code, msg = "加油卡已挂失,不能进行充值"}, order_delivery.gasoline_card_archive_status.lose
	elseif(success_code == "6") then
		error("加油卡已过期,不能进行充值")
		return {code = sys.error.delivery.user_card_cannot_recharge.code, msg = "加油卡已过期,不能进行充?"}, order_delivery.gasoline_card_archive_status.expire
	elseif(success_code == "7") then
		error("加油卡已失效,不能进行充值")
		return {code = sys.error.delivery.user_card_cannot_recharge.code, msg = "加油卡已失效,不能进行充值"}, order_delivery.gasoline_card_archive_status.expire
	elseif(success_code == "9") then
		error("加油卡已损坏,不能进行充值")
		return {code = sys.error.delivery.user_card_cannot_recharge.code, msg = "加油卡已损坏,不能进行充?"}, order_delivery.gasoline_card_archive_status.damage
	elseif(success_code == "10") then
		error("加油卡已作废,不能进行充值")
		return {code = sys.error.delivery.user_card_cannot_recharge.code, msg = "加油卡已作废,不能进行充值"}, order_delivery.gasoline_card_archive_status.discard
	elseif(success_code == "11") then
		error("加油卡状态异常,不能进行充值")
		return {code = sys.error.delivery.user_card_cannot_recharge.code, msg = "加油卡状态异常,不能进行充值"}, order_delivery.gasoline_card_archive_status.card_exception
	end

	if(tostring(success_code) ~= "0") then
		local err_msg = order_delivery.get_card_error_info(tostring(data.success))
		error(string.format("发送短信验证码失败,返回内容:%s.错误消息:%s", content, err_msg))
		return {code = sys.error.failure.code, msg = err_msg}
	end
	return sys.error.success
end

--{recharge_account_id,validcode_mobile}
order_delivery.get_sms_code = function(params)
	local result, user_card_status = order_delivery.send_sms_code(params)
	if(result.code ~= sys.error.success.code) then
		return result, user_card_status
	end
	--需等待短信发送至手机卡上
	local card_tail_no = string.sub(params.recharge_account_id, -4)
	result, content = order_delivery.get_smsras_sms(params.validcode_mobile, card_tail_no, 4000, 0)
	if(result.code == sys.error.sms.get_sms_content_failure.code) then
		print("验证码接收失败,累加失败次数")
		order_delivery.grs_dbg:execute("up_channel.phone_card.receive_sms_failure", params)
		return result
	end
	print("验证码接收成功,清空失败次数")
	order_delivery.grs_dbg:execute("up_channel.phone_card.receive_sms_success", params)
	local sms_data = order_delivery.analysis_recharge_sms(tostring(content))
	if(sms_data.code == nil) then
		error(string.format("短信内容解析失败.需检查短信内容解析函数是否需要升级.短信内容:%s", content))
		return sys.error.sms.content_analysis_failure
	elseif(tostring(sms_data.card_tail_no) ~= card_tail_no) then
		error(string.format("短信内容中加油卡尾号与用户加油卡号不匹配.短信中尾号:%s,用户加油卡号:%s", sms_data.card_tail_no, params.recharge_account_id))
		return sys.error.sms.content_card_no_match_failure
	end


	return sys.error.success, user_card_status, sms_data.code
end

order_delivery.get_number_code = function()
	local input = {}
	input.url = "http://www.sinopecsales.com/gas/YanZhengMaServlet?"..os.time()
	input.net = "zhongshihua.net"
	input.value = 0.5
	input.len = 5
	input.result = ""
	local result, msg = order_delivery.recognize:net_recognize(order_delivery.http, input)
	print("数字验证码识别结果:"..tostring(input.result))
	if(not(result)) then
		error(msg)
		return sys.error.failure
	end
	--识别后需判断第一个和第三个是否是字符，第二个是号是运算符+或x,第四个是=号，第5个是w
	local a = tonumber(string.sub(input.result, 1, 1))
	local b = tonumber(string.sub(input.result, 3, 3))
	local d = string.sub(input.result, 2, 2)
	if(a == nil or b == nil) then
		error("数字验证码识别错误,需重新获取数字验证码")
		return sys.error.failure
	end
	if(d == "+") then
		return sys.error.success, a + b
	end
	return sys.error.success, a * b
end

order_delivery.request_query_card_info = function(params)
	local input = {}
	input.encoding = order_delivery.encoding
	input.content = "json"
	input.method = "post"
	input.url = "http://www.sinopecsales.com/gas/html/netRechargeAction_queryCardInfo.json"
	input.data = string.format([=[cardNo=%s&smsYzm=%s&chargePhoneNo=%s]=],
								params.recharge_account_id,
								params.sms_code,
								params.validcode_mobile)
	input.header= [[Accept:application/json, text/javascript, */*; q=0.01
Accept-Encoding:gzip, deflate
Accept-Language:zh-CN,zh;q=0.8
Connection:keep-alive
Content-Type:application/x-www-form-urlencoded; charset=UTF-8
Host:www.sinopecsales.com
Origin:http://www.sinopecsales.com
Referer:http://www.sinopecsales.com/gas/html/billQueryAction_goChangeCard.action
User-Agent:Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/48.0.2564.97 Safari/537.36
X-Requested-With:XMLHttpRequest]]
	local content = order_delivery.http:query(input, {}, 30000)
	print("查询加油卡信息请求返回内容:"..tostring(content))
	if(xstring.empty(content)) then
		error(string.format("查询加油卡信息请求返回空.url:%s,post_data:%s,header:%s", input.url, input.data, input.header))
		return sys.error.delivery.get_card_info_failure
	end
	if(order_delivery.is_html(content)) then
		error("查询加油卡信息返回错误.内容:"..content)
		return sys.error.delivery.get_card_info_failure
	end
	local data = xtable.parse(content, 1)
	if(tostring(data.smsyzmresult) == "3" or tostring(data.smsyzmresult) == "4") then
		error("短信验证码错误,需重新获取")
		return sys.error.delivery.sms_code_error
	end
	if(data.cardInfo ~= nil) then
		if(tostring(data.cardInfo) == "error") then
			error("加油卡不存在")
			return {code = sys.error.delivery.user_card_cannot_recharge.code, msg = "加油卡不存在"}, order_delivery.gasoline_card_archive_status.not_exists
		elseif(tostring(data.cardInfo.priCard) == "0") then
			error("不能给副卡进行充值")
			return {code = sys.error.delivery.user_card_cannot_recharge.code, msg = "不能给副卡进行充值"}, order_delivery.gasoline_card_archive_status.sub
		elseif(tostring(data.cardInfo.cardStatus) == "04") then
			print("加油卡正常,可以进行充值")
		elseif(tostring(data.cardInfo.cardStatus) == "07") then
			error("加油卡已挂失，不能进行充值")
			return {code = sys.error.delivery.user_card_cannot_recharge.code, msg = "加油卡已挂失，不能进行充值"}, order_delivery.gasoline_card_archive_status.lose
		elseif(tostring(data.cardInfo.cardStatus) == "09") then
			error("加油卡已损坏，不能进行充值")
			return {code = sys.error.delivery.user_card_cannot_recharge.code, msg = "加油卡已损坏，不能进行充值"}, order_delivery.gasoline_card_archive_status.damage
		elseif(tostring(data.cardInfo.cardStatus) == "10") then
			error("加油卡已作废，不能进行充值")
			return {code = sys.error.delivery.user_card_cannot_recharge.code, msg = "加油卡已作废，不能进行充值"}, order_delivery.gasoline_card_archive_status.discard
		elseif(data.cardInfo.cardStatus ~= nil and tostring(data.cardInfo.cardStatus) ~= "" and tostring(data.cardInfo.cardStatus) ~= "null") then
			error("加油卡状态异常，不能进行充值")
			return {code = sys.error.delivery.user_card_cannot_recharge.code, msg = "加油卡状态异常，不能进行充值"}, order_delivery.gasoline_card_archive_status.card_exception
		elseif(tostring(data.cardInfo.validDate) == "1") then
			error("加油卡已超过有效期，不能进行充值")
			return {code = sys.error.delivery.user_card_cannot_recharge.code, msg = "加油卡已超过有效期，不能进行充值"}, order_delivery.gasoline_card_archive_status.expire
		end
	end
	--解析卡信息
	local user_card_info = order_delivery.analysis_user_card_info(data.cardInfo)
	return sys.error.success, order_delivery.gasoline_card_archive_status.normal, user_card_info
end

--{recharge_account_id,card_pwd,validcode_mobile,number_code,sms_code}
order_delivery.request_recharge = function(params)
	local input = {}
	input.encoding = order_delivery.encoding
	input.content = "json"
	input.method = "post"
	input.url = "http://www.sinopecsales.com/gas/html/netRechargeAction_czkCharge.json"
	input.data = string.format([=[rechargeCardNo=%s&rechargeCzkCardPwd=["%s"]&rechargeCardPhone=%s&yzm=%s&addCyCardNoTiXing=false&smsYzm=%s]=],
								params.recharge_account_id,
								order_delivery.card_pwd_encrypt(params.card_pwd),
								params.validcode_mobile,
								params.number_code,
								params.sms_code)
	input.header= [[Accept:application/json, text/javascript, */*; q=0.01
Accept-Encoding:gzip, deflate
Accept-Language:zh-CN,zh;q=0.8
Connection:keep-alive
Content-Type:application/x-www-form-urlencoded; charset=UTF-8
Host:www.sinopecsales.com
Origin:http://www.sinopecsales.com
Referer:http://www.sinopecsales.com/gas/html/billQueryAction_goChangeCard.action
User-Agent:Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/48.0.2564.97 Safari/537.36
X-Requested-With:XMLHttpRequest]]
	local content = order_delivery.http:query(input, {}, 30000)
	print("充值请求返回内容:"..tostring(content))
	if(xstring.empty(content)) then
		error(string.format("充值请求返回空.url:%s,post_data:%s,header:%s", input.url, input.data, input.header))
		return sys.error.unkown
	end
	if(order_delivery.is_html(content)) then
		error("充值返回错误.内容:"..content)
		return sys.error.failure
	end
	local data = xtable.parse(content, 1)
	if(data.error ~= nil and string.find(data.error, "短信验证码不正确") ~= nil) then
		print("短信验证码不正确,需重新获取")
		return sys.error.delivery.sms_code_error
	elseif(data.yzmresult == "1") then
		error("需重新获取数字验证码")
		return sys.error.delivery.number_code_error
	elseif(data.yzmresult == "2") then
		error("数字验证码计算错误,需重新获取")
		return sys.error.delivery.number_code_error
	elseif(data.list == nil or data.list[1] == nil or data.list[1][1] == nil) then
		error(string.format("充值请求返回内容不包含订单号.url:%s,post_data:%s,header:%s,response_data:%s", input.url, input.data, input.header, content))
		return sys.error.unkown
	end
	return sys.error.success, {order_id = data.list[1][1]}
end

--{order_id}
order_delivery.request_order_query = function(params)
	local input = {}
	input.encoding = order_delivery.encoding
	input.content = "json"
	input.method = "post"
	input.url = "http://www.sinopecsales.com/gas/html/netRechargeAction_selectCardOrder.json"
	input.data = string.format("orderId=%s", params.order_id)
	input.header = [[Accept:application/json, text/javascript, */*; q=0.01
Accept-Encoding:gzip, deflate
Accept-Language:zh-CN,zh;q=0.8
Connection:keep-alive
Content-Type:application/x-www-form-urlencoded; charset=UTF-8
Host:www.sinopecsales.com
Origin:http://www.sinopecsales.com
Referer:http://www.sinopecsales.com/gas/html/billQueryAction_goChangeCard.action
User-Agent:Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/48.0.2564.97 Safari/537.36
X-Requested-With:XMLHttpRequest]]
	local content = order_delivery.http:query(input, {}, 30000)
	print("订单查询返回内容:"..content)
	if(xstring.empty(content)) then
		error(string.format("查询订单请求返回空.url:%s,post_data:%s,header:%s", input.url, input,data, input.header))
		return sys.error.delivery.query_result_unkown
	end
	if(order_delivery.is_html(content)) then
		error("订单查询返回错误.内容:"..content)
		return sys.error.delivery.query_result_unkown
	end
	local data = xtable.parse(content, 1)
	if(tostring(data.ordersuccess) == "1" and tostring(data.success) == "2" and tonumber(data.orderMoney) > 0) then
		print("充值成功")
		return sys.error.delivery.recharge_success
	end
	return sys.error.delivery.query_result_unkown, data
end

order_delivery.delivery_save = function(recharge_result, up_order_info, query_result, up_order_query_info)
	local params = {}
	params.delivery_id = order_delivery.params.delivery_id
	params.channel_no = order_delivery.delivery_data.up_channel_no
	params.success_standard = 0
	params.result_source = 2
	params.result_msg = recharge_result.msg
	params.up_order_no = (up_order_info == nil or up_order_info.order_id == nil) and "" or up_order_info.order_id
	params.query_timespan = order_delivery.delivery_data.query_timespan
	params.up_error_code = order_delivery.deal_code.unkown
	params.card_use_status = order_delivery.card_use_status.unkown
	params.robot_code = order_delivery.params.robot_code
	if(recharge_result.code == sys.error.login.get_cookie_failure.code) then
		params.card_msg = "获取登录cookie失败,卡未使用"
		params.card_use_status = order_delivery.card_use_status.unuse
		params.up_error_code = order_delivery.deal_code.failure

	elseif(recharge_result.code == sys.error.delivery.recharge_card_has_been_used.code
		or recharge_result.code == sys.error.delivery.recharge_card_status_exp.code) then
		params.card_msg = "验卡返回卡已被使用"
		params.card_use_status = order_delivery.card_use_status.exp_card
		params.up_error_code = order_delivery.deal_code.failure

	elseif(recharge_result.code == sys.error.unkown.code) then
		params.card_msg = "提交充值请求返回结果未知,卡使用结果未知"

	elseif(recharge_result.code == sys.error.delivery.verify_card_result_unkown.code) then
		params.card_msg = sys.error.delivery.verify_card_result_unkown.msg
		params.card_use_status = order_delivery.card_use_status.unuse
		params.up_error_code = order_delivery.deal_code.failure

	elseif(recharge_result.code == sys.error.delivery.verify_card_error.code) then
		params.card_msg = "验卡失败,卡使用状态未知"
		params.card_use_status = order_delivery.card_use_status.unuse
		params.up_error_code = order_delivery.deal_code.failure

	elseif(recharge_result.code ~= sys.error.success.code) then
		params.card_msg = "提交充值请求失败,卡未使用"
		params.up_error_code = order_delivery.deal_code.failure
		params.card_use_status = order_delivery.card_use_status.unuse

	elseif(query_result.code == sys.error.delivery.query_result_unkown.code) then
		params.card_msg = "提交充值请求成功,查询失败.卡状态未知"
		params.result_msg = query_result.msg

	else
		params.card_msg = "提交充值请求成功,卡已使用"
		params.up_error_code = order_delivery.deal_code.success
		params.up_order_no = up_order_info.order_id
		params.card_use_status = order_delivery.card_use_status.useing
	end
	local dbg_result = order_delivery.grs_dbg:execute("order.delivery.save", params)
	return dbg_result.result, dbg_result.data

end

order_delivery.next_step = function(data)
	if(xstring.empty(data.next_step)) then
		return
	end
	local queues = xmq(data.next_step)
	queues:send({delivery_id = order_delivery.params.delivery_id, order_no = data.order_no, query_id = data.query_id})
end

order_delivery.join_to_card_info_save_mq = function(card_status, card_info)
	local send_data = {card_no = order_delivery.delivery_data.recharge_account_id,
					card_holder = card_info.card_holder or "",
					carrier_no = "ZSH",
					status = card_status,
					is_complete = 0}
	local queues = xmq("gasoline_card_save")
	queues:send(send_data)
end

order_delivery.get_smsras_sms = function(mobile, card_tail_no, sleep_time, wait_times)
	flowlib.sleep_sync(sleep_time)
	local dbg_result = order_delivery.sms_dbg:execute_sp("sp_get_grs_sms", {mobile, card_tail_no, 60})
	if(tostring(dbg_result:get(0)) == "100") then
		return sys.error.success, dbg_result:get(1)
	elseif(tostring(dbg_result:get(0)) ~= "100" and wait_times <= order_delivery.wait_smsras_code_limit) then
		return order_delivery.get_smsras_sms(mobile, card_tail_no, 1000, wait_times + 1)
	else
		return sys.error.sms.get_sms_content_failure
	end
end

order_delivery.card_pwd_encrypt = function(card_pwd)
	local str = ""
	for i=1,#card_pwd,1 do
		local b = string.byte(string.sub(card_pwd, i, i))
		local s = string.format("%02x",bit.bxor(b,158))
		if(#s == 1) then
			str = str.."0"
		end
		str = str..s
	end
	return str
end


order_delivery.is_html = function(content)
	local s,e = string.find(content, "<html>")
	if(s ~= nil) then
		return true
	end
	return false
end

order_delivery.get_card_error_info = function(status)
	local msg = nil
	if(status == "1") then
		msg = "手机号码不正确"
	elseif(status == "2") then
		msg = "加油卡号码不正确"
	elseif(status == "3") then
		msg = "加油卡不存在"
	elseif(status == "4") then
		msg = "副卡不能进行充值"
	elseif(status == "5") then
		msg = "加油卡已挂失,不能进行充值"
	elseif(status == "6") then
		msg = "加油卡已超过有效期,不能进行充值"
	elseif(status == "7") then
		msg = "加油卡已失效,不能进行充值"
	elseif(status == "9") then
		msg = "加油卡已损坏,不能进行充值"
	elseif(status == "10") then
		msg = "加油卡已作废,不能进行充值"
	elseif(status == "11") then
		msg = "加油卡状态异常,不能进行充值"
	else
		msg = "未知状态,值:"..status
	end
	return msg
end

order_delivery.analysis_recharge_sms = function(content)
	local codes, data = {}, {}
	for item in string.gmatch(content, "[%d]+") do
		table.insert(codes, item)
	end
	data.card_tail_no = codes[1]
	data.code = codes[2]
	return data
end

order_delivery.analysis_user_card_info = function(data)
	local card_info = data
	card_info.card_no = data.cardNo
	card_info.card_holder = data.cardHolder


	--解析用户名字
	--解析用户名字
	--解析用户名字
	--解析用户名字


	return card_info
end




return order_delivery
