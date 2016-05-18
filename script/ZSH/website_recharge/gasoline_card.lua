require "sys"

zsh_gasoline_card = {encoding = "gbk"}
zsh_gasoline_card.commonlib = require "zsh.website_recharge.commonlib"
zsh_gasoline_card.decodelib = require "zsh.website_recharge.decodelib"

--查询加油卡信息(归属人信息等)
--{recharge_account_id,sms_code,validcode_mobile}
zsh_gasoline_card.query = function(http, params)
	local input = {}
	input.encoding = zsh_gasoline_card.encoding
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
	debug(string.format("url:%s, post_data:%s", input.url, input.data))
	local content = http:query(input, {}, 30000)
	print("查询加油卡信息请求返回内容:"..tostring(content))
	if(xstring.empty(content)) then
		error(string.format("查询加油卡信息请求返回空.url:%s,post_data:%s,header:%s", input.url, input.data, input.header))
		return sys.error.delivery.get_card_info_failure
	end
	if(zsh_gasoline_card.commonlib.is_html(content)) then
		error("查询加油卡信息返回错误.内容:"..content)
		return sys.error.delivery.get_card_info_failure
	end
	local data = xtable.parse(string.gsub(content, "\\", ""), 1)
	if(tostring(data.smsyzmresult) == "3" or tostring(data.smsyzmresult) == "4") then
		error("短信验证码错误,需重新获取")
		return sys.error.delivery.sms_code_error
	end
	local gasoline_card_status, msg = zsh_gasoline_card.__analysis_query_result(data.cardInfo)
	if(gasoline_card_status ~= zsh_gasoline_card.commonlib.gasoline_card_status.normal) then
		return {code = sys.error.delivery.user_card_cannot_recharge.code, msg = msg}, {status = gasoline_card_status}
	end
	return sys.error.success, zsh_gasoline_card.__analysis_card_info(data.cardInfo)
end

zsh_gasoline_card.__analysis_query_result = function(card_info)
	local status, msg = nil
	local pri_card = tostring(card_info.priCard)
	local card_status = tostring(card_info.cardStatus)
	local card_validate = tostring(card_info.validDate)
	if(card_info == nil or tostring(card_info) == "error") then
		msg = "加油卡不存在"
		status = zsh_gasoline_card.commonlib.gasoline_card_status.not_exists
	elseif(pri_card == "0") then
		msg = "副卡无法充值"
		status = zsh_gasoline_card.commonlib.gasoline_card_status.sub
	elseif(card_validate == "1") then
		msg = "加油卡已超过有效期，不能进行充值"
		status = zsh_gasoline_card.commonlib.gasoline_card_status.expire
	elseif(card_status == "04") then
		msg = "加油卡正常,可以进行充值"
		status = zsh_gasoline_card.commonlib.gasoline_card_status.normal
	elseif(card_status == "07") then
		msg = "加油卡已挂失，不能进行充值"
		status = zsh_gasoline_card.commonlib.gasoline_card_status.lose
	elseif(card_status == "09") then
		msg = "加油卡已损坏，不能进行充值"
		status = zsh_gasoline_card.commonlib.gasoline_card_status.damage
	elseif(card_status == "10") then
		msg = "加油卡已作废，不能进行充值"
		status = sh_gasoline_card.commonlib.gasoline_card_status.discard
	elseif(card_status ~= nil and card_status ~= "") then
		msg = "加油卡状态异常，不能进行充值"
		status = zsh_gasoline_card.commonlib.gasoline_card_status.card_exception
	else
		msg = "加油卡状态解析失败"
		status = zsh_gasoline_card.commonlib.gasoline_card_status.card_exception
	end
	return status, msg
end

zsh_gasoline_card.__analysis_card_info = function(data)
	local card_info = data
	card_info.status = zsh_gasoline_card.commonlib.gasoline_card_status.normal
	card_info.card_no = data.cardNo
	card_info.card_holder = zsh_gasoline_card.decodelib.card_holder_decode(data.cardHolder)
	return card_info
end











return zsh_gasoline_card
