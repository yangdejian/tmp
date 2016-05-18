zsh_commonlib = {}


zsh_commonlib.recharge_card_status = {waiting = 20,
								useing = 30,
								used = 0,
								unuse = 90,
								exp_card = 40,
								unkown = 99
								}
zsh_commonlib.gasoline_card_status = {normal = 0, --正常
								sub            = 1, --副卡,
								lose           = 2, --挂失
								damage         = 3, --损坏
								discard        = 4, --废弃
								card_exception = 5, --卡异常
								expire         = 6, --卡过期
								not_exists     = 9  --卡号不存在
								}

zsh_commonlib.delivery_deal_code = {}
zsh_commonlib.delivery_deal_code["failure"] = "DFAILURE"
zsh_commonlib.delivery_deal_code["delivery.login_failure"] = "DRCHG_LOGIN_FAILURE"--登录失败
zsh_commonlib.delivery_deal_code["delivery.verify_card_error"] = "DRCHG_VERIFY_CARD_ERROR"--验卡异常
zsh_commonlib.delivery_deal_code["delivery.recharge_card_has_been_used"] = "DRCHG_CARD_HAS_BEEN_USED"--卡已被使用
zsh_commonlib.delivery_deal_code["delivery.recharge_card_status_exp"] = "DRCHG_CARD_STATUS_EXP"--卡状态异常
zsh_commonlib.delivery_deal_code["delivery.user_card_cannot_recharge"] = "DUSER_CARD_CANNOT_RECHARGE"--加油卡无法充值
zsh_commonlib.delivery_deal_code["sms.send_failure"] = "DSMS_SEND_FAILURE"--短信发送失败
zsh_commonlib.delivery_deal_code["sms.get_sms_content_failure"] = "DGET_SMS_CONTENT_FAILURE"--短信内容获取失败
zsh_commonlib.delivery_deal_code["delivery.get_card_info_failure"] = "DGET_CARD_INFO_FAILURE"--加油卡信息获取失败
zsh_commonlib.delivery_deal_code["delivery.sms_code_error"] = "DRCHG_SMS_CODE_ERROR"--短信验证码错误
zsh_commonlib.delivery_deal_code["delivery.number_code_error"] = "DRCHG_IMG_CODE_ERROR"--数字验证码错误
zsh_commonlib.delivery_deal_code["delivery.recharge.submit.unkown"] = "DRCHG_SUBMIT_UNKOWN"--充值提交结果未知
zsh_commonlib.delivery_deal_code["delivery.recharge.submit.failure"] = "DRCHG_SUBMIT_FAILURE"--充值提交失败
zsh_commonlib.delivery_deal_code["delivery.recharge.submit.sms_code_error"] = "DRCHG_SUBMIT_SMS_CODE_ERROR"--充值提交返回短信验证码错误
zsh_commonlib.delivery_deal_code["delivery.recharge.submit.number_code_error"] = "DRCHG_SUBMIT_IMG_CODE_ERROR"--充值提交返回数字验证码错误
zsh_commonlib.delivery_deal_code["delivery.recharge.submit.card_pwd_error"] = "DRCHG_SUBMIT_CARD_PWD_ERROR"--充值卡密码错误
zsh_commonlib.delivery_deal_code["delivery.recharge.query.unkown"] = "DRCHG_QUERY_UNKOWN"--充值查询结果未知
zsh_commonlib.delivery_deal_code["delivery.recharge_success"] = "DRCHG_SUCCESS"--充值成功
zsh_commonlib.delivery_deal_code["payStatus:!"] = "DPAYSTATUS:!"--查询订单失败
zsh_commonlib.delivery_deal_code["payStatus:0"] = "DPAYSTATUS:0"--查询订单失败
zsh_commonlib.delivery_deal_code["payStatus:1&rechargeStatus:!"] = "DPAYSTATUS:1&RECHARGESTATUS:!"--支付成功,充值状态未知
zsh_commonlib.delivery_deal_code["payStatus:1&rechargeStatus:0"] = "DPAYSTATUS:1$RECHARGESTATUS:0"--支付成功,未充值
zsh_commonlib.delivery_deal_code["payStatus:1&rechargeStatus:1"] = "DPAYSTATUS:1$RECHARGESTATUS:1"--支付成功,等待充值
zsh_commonlib.delivery_deal_code["payStatus:1&rechargeStatus:2"] = "DPAYSTATUS:1$RECHARGESTATUS:2"--支付成功,充值成功
zsh_commonlib.delivery_deal_code["payStatus:1&rechargeStatus:3"] = "DPAYSTATUS:1$RECHARGESTATUS:3"--支付成功,充值失败
zsh_commonlib.delivery_deal_code["payStatus:1&rechargeStatus:4"] = "DPAYSTATUS:1$RECHARGESTATUS:4"--支付成功,无此订单
zsh_commonlib.delivery_deal_code["payStatus:1&rechargeStatus:5"] = "DPAYSTATUS:1$RECHARGESTATUS:5"--支付成功,正在充值
zsh_commonlib.delivery_deal_code["payStatus:2"] = "DPAYSTATUS:2"--查询订单失败
zsh_commonlib.delivery_deal_code["manual_audit"] = "MANUAL_AUDIT"--人工审核

zsh_commonlib.get_deal_code = function(code)
	if(zsh_commonlib.delivery_deal_code[code] == nil) then
		error("未找到对应的处理码:"..code)
		return zsh_commonlib.delivery_deal_code["manual_audit"]
	end
	return zsh_commonlib.delivery_deal_code[code]
end

zsh_commonlib.is_html = function(content)
	local s,e = string.find(content, "<html>")
	if(s ~= nil) then
		return true
	end
	return false
end









return zsh_commonlib
