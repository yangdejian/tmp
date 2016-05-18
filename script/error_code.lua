error_code = {}

error_code.success = {code = "success", msg = "操作成功"}
error_code.failure = {code = "failure", msg = "操作失败"}
error_code.unkown = {code = "unkown", msg = "未知"}
error_code.param_miss = {code = "param_miss", msg = "缺少必须的参数"}
error_code.param_error = {code = "param_error", msg = "参数错误"}
error_code.not_exists={code="not_exists",msg="数据不存在"}
error_code.data_miss = {code = "data_miss", msg = "数据不存在或已被删除"}
error_code.data_exists = {code = "data_exists", msg = "数据已存在"}
error_code.data_not_exists = {code = "data_not_exists", msg = "数据不存在"}
error_code.system_busy = {code = "system_busy", msg = "系统繁忙,稍后再试"}
error_code.data_repeat = {code = "data_repeat", msg = "数据重复"}
error_code.data_time_out = {code = "data_time_out", msg = "数据已过期"}
error_code.balance_low = {code = "balance_low",msg = "账户余额不足"}
error_code.amount_error = {code = "amount_error", msg = "金额错误"}
error_code.not_allow = {code = "not_allow", msg = "不允许执行此操作"}
error_code.num_error = {code = "num_error", msg = "数量错误"}
error_code.has_refunded = {code = "has_refunded", msg = "已存在退款"}
error_code.valid_code_error = {code = "valid_code_error", msg = "验证码错误"}
error_code.card_status_error = {code = "card_status_error", msg = "卡状态错误"}
error_code.response_empty = {code = "response_empty", msg = "请求返回空"}
error_code.response_html = {code = "response_html", msg = "请求返回HTML内容"}
error_code.response_fmt_error = {code = "response_fmt_error", msg = "请求返回格式错误"}
error_code.xml_load_failure = {code = "xml_load_failure", msg = "XML内容加载失败"}
error_code.build_sign_failure = {code = "build_sign_failure", msg = "生成签名失败"}
error_code.sign_error = {code = "sign_error", msg = "签名错误"}

error_code.command = {}
error_code.command.require_error = {code = "command.require_error", msg = "执行指令时,引用数据层脚本错误"}
error_code.command.execute_error = {code = "command.execute_error", msg = "执行指令时,数据层方法错误"}

error_code.delivery = {}
error_code.delivery.payment_status_error = {code = "delivery.payment_status_error", msg = "支付状态错误"}
error_code.delivery.refund_status_error = {code = "delivery.refund_status_error", msg = "退款状态错误"}
error_code.delivery.verify_card_error = {code = "delivery.verify_card_error", msg = "验卡失败"}
error_code.delivery.recharge_card_normal = {code = "delivery.card_normal", msg = "充值卡正常"}
error_code.delivery.recharge_card_has_been_used = {code = "delivery.recharge_card_has_been_used", msg = "充值卡已被使用"}
error_code.delivery.recharge_card_status_exp = {code = "delivery.recharge_card_status_exp", msg = "充值卡状态异常"}
error_code.delivery.verify_card_result_unkown = {code = "delivery.verify_card_result_unkown", msg = "验卡结果已返回,代码未正常处理.需检查验卡页面是否升级"}
error_code.delivery.sms_code_error = {code = "delivery.sms_code_error", msg = "短信验证码错误"}
error_code.delivery.number_code_error = {code = "delivery.number_code_error", msg = "数字验证码错误"}
error_code.delivery.query_result_unkown = {code = "delivery.query_result_unkown", msg = "发货成功,查询结果未知"}
error_code.delivery.rechargeing = {code = "delivery.rechargeing", msg = "发货成功,正在充值"}
error_code.delivery.recharge_success = {code = "delivery.recharge_success", msg = "发货成功,充值成功"}
error_code.delivery.get_card_info_failure = {code = "delivery.get_card_info_failure", msg = "获取加油卡信息失败"}
error_code.delivery.recharge_account_id_not_exists = {code = "delivery.recharge_account_id_not_exists", msg = "加油卡卡号不存在"}
error_code.delivery.user_card_cannot_recharge = {code = "delivery.user_card_cannot_recharge", msg = "加油卡不可以充值"}
error_code.delivery.login_failure = {code = "delivery.login_failure", msg = "发货登录失败"}

error_code.delivery.recharge = {}
error_code.delivery.recharge.submit = {}
error_code.delivery.recharge.submit.failure = {code = "delivery.recharge.submit.failure", msg = "充值提交失败"}
error_code.delivery.recharge.submit.unkown = {code = "delivery.recharge.submit.unkown", msg = "充值提交结果未知"}
error_code.delivery.recharge.submit.sms_code_error = {code = "delivery.recharge.submit.sms_code_error", msg = "短信验证码错误"}
error_code.delivery.recharge.submit.number_code_error = {code = "delivery.recharge.submit.number_code_error", msg = "数字验证码错误"}
error_code.delivery.recharge.submit.card_pwd_error = {code = "delivery.recharge.submit.card_pwd_error", msg = "充值卡密码错误"}

error_code.delivery.recharge.query = {}
error_code.delivery.recharge.query.unkown = {code = "delivery.recharge.query.unkown", msg = "发货提交成功,查询结果未知"}

error_code.delivery.query = {}
error_code.delivery.query.list_response_empty = {code = "delivery.query.list_response_empty", msg = "查询订单列表请求返回空"}
error_code.delivery.query.list_response_html = {code = "delivery.query.list_response_html", msg = "查询订单列表返回html"}
error_code.delivery.query.card_response_empty = {code = "delivery.query.card_response_empty", msg = "验卡请求返回空"}
error_code.delivery.query.card_response_html = {code = "delivery.query.card_response_html", msg = "验卡请求返回html"}
error_code.delivery.query.get_cookies_failed = {code = "delivery.query.get_cookies_failed", msg = "获取cookie失败"}
error_code.delivery.query.single_response_empty = {code = "delivery.query.single_response_empty", msg = "直接查询订单请求返回空"}
error_code.delivery.query.single_response_html = {code = "delivery.query.single_response_html", msg = "直接查询订单返回html"}
error_code.delivery.query.order_not_exists = {code = "delivery.query.order_not_exists", msg = "查询返回订单不存在"}
error_code.delivery.query.order_success = {code = "delivery.query.order_success", msg = "查询返回充值成功"}



error_code.channel = {}
error_code.channel.not_exists = {code = "channel.not_exists", msg = "渠道不存在"}
error_code.channel.settle_type_error = {code = "channel.settle_type_error", msg = "渠道结算类型错误"}

error_code.up_channel = {}
error_code.up_channel.not_exists = {code = "up_channel.not_exists", msg = "渠道不存在"}
error_code.up_channel.settle_type_error = {code = "up_channel.settle_type_error", msg = "渠道结算类型错误"}

error_code.down_channel = {}
error_code.down_channel.order_notify_exists = {code = "down_channel.order_notify_exists", msg = "下游渠道订单通知数据已存在"}

error_code.order = {}
error_code.order.order_status_error = {code = "order.order_status_error", msg = "订单状态不正确"}
error_code.order.no_need_bind={code = "order.no_need_bind", msg = "订单无需绑定"}
error_code.order.no_need_delivery={code = "order.no_need_delivery", msg = "订单无需发货"}
error_code.order.not_fund_delivery_channel={code = "order.not_fund_delviery_channel", msg = "未找到发货渠道信息"}

error_code.order.bind_failed={code = "order.bind_failed", msg = "订单绑定失败"}
error_code.order.no_match_product={code = "order.no_match_product", msg = "订单未找到匹配的产品"}
error_code.order.no_match_error_code={code = "order.no_match_error_code", msg = "未找到匹配的错误码"}
error_code.order.delivery_save_error={code = "order.delivery_save_error", msg = "订单发货结果保存失败"}

error_code.order.no_need_notify ={code = "order.no_need_notify", msg = "订单无需通知"}
error_code.order.amount_error={code = "order.amount_error",msg = "订单金额有误"}
error_code.order.status_error={code="order_status_error",msg="订单状态有误"}
error_code.order.data_error={code="order_data_error",msg="订单数据有误"}
error_code.order.no_need_deal={code="order_no_need_deal",msg="订单无需处理"}

error_code.order.pay_delay_process={code="order.pay_delay_process",msg="延迟处理"}
error_code.order.not_allow_pay={code="order.not_allow_pay",msg="订单不允许支付"}
error_code.order.notify_not_save={code="order.notify_not_save",msg="订单通知记录未保存"}

error_code.sms = {}
error_code.sms.send_failure = {code = "sms.send_failure", msg = "短信发送失败"}
error_code.sms.content_card_no_match_failure = {code = "sms.content_card_no_match_failure", msg = "短信内容中充值卡号与发送卡号不匹配"}
error_code.sms.content_analysis_failure = {code = "sms.content_analysis_failure", msg = "短信内容解析失败"}
error_code.sms.get_sms_content_failure = {code = "sms.get_sms_content_failure", msg = "请求sms系统,获取短信内容失败"}

error_code.bind = {}
error_code.bind.no_useful_mobile = {code = "bind.no_useful_mobile", msg = "没有可用的手机号"}

error_code.login = {}
error_code.login.cookie_timeout = {code = "login.cookie_timeout", msg = "cookie已过期"}
error_code.login.get_cookie_failure = {code = "login.get_cookie_failure", msg = "获取登录cookie失败"}
error_code.login.valid_code_error = {code = "login.valid_code_error", msg = "登录验证码错误"}
error_code.login.valid_code_recognize_failure = {code = "login.valid_code_recognize_failure", msg = "登录验证码识别失败"}
error_code.login.valid_code_calc_failure = {code = "login.valid_code_calc_failure", msg = "验证码计算失败"}
error_code.login.password_error = {code = "login.password_error", msg = "登录密码错误"}
error_code.login.official_defend = {code="login.official_defend", msg = "官网维护,无法登录"}
error_code.login.repeat_login = {code="login.repeat_login", msg = "重复的登录"}
error_code.login.response_empty = {code="login.response_empty", msg = "请求返回空"}
error_code.login.response_html = {code="login.response_html", msg = "请求返回HTML"}
error_code.login.cookies_timeout = {code="login.cookies_timeout", msg = "cookie已过期"}
error_code.login.unkown_result = {code="login.unkown_result", msg = "登录结果未知"}
error_code.login.refresh_response_empty = {code="login.refresh_response_empty", msg = "登录维持请求返回空"}
error_code.login.refresh_response_html = {code="login.refresh_response_html", msg = "登录维持请求返回HTML"}


function eval(str)
	if(not(str)) then
		return nil
	end
    if type(str) == "string" then
        return loadstring("return " .. str)()
    elseif type(str) == "number" then
        return loadstring("return " .. tostring(str))()
    else
        print("is not a string")
    end
end


error_code.get = function(code)
	local result = eval("error_code."..tostring(code))
	if(result == nil) then
		print("找不到对应的错误码:"..tostring(code))
		result = error_code.system_busy
	end
	return result
end


return error_code
