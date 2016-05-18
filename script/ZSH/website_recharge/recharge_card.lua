require "sys"
require "custom.common.wclient"
require "lib.loginlib"

zsh_recharge_card = {encoding = "gbk"}
zsh_recharge_card.commonlib = require "zsh.website_recharge.commonlib"
zsh_recharge_card.encryptlib = require "zsh.website_recharge.encryptlib"
zsh_recharge_card.http = wclient()

--验卡
--{up_shelf_id,card_no,need_login}
zsh_recharge_card.check = function(recharge_http, params)
	local result, http = zsh_recharge_card.___get_http_client(recharge_http, params)
	if(result.code ~= sys.error.success.code) then
		return result
	end

	local input = {}
	input.encoding = zsh_recharge_card.encoding
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
	debug(string.format("url:%s, post_data:%s", input.url, input.data))
	local content = http:query(input, {}, 30000)
	if(xstring.empty(content)) then
		error(string.format("验卡请求返回空.url:%s,data:%s,header:%s", input.url, input.data, input.header))
		return {code = sys.error.delivery.verify_card_error.code, msg = "验卡请求返回空"}
	end

	if(zsh_gasoline_card.commonlib.is_html(content)) then
		error("验卡返回错误.内容:"..content)
		return {code = sys.error.delivery.verify_card_error.code, msg = "验卡请求返回需要登录"}
	end
	result = xtable.parse(content, 1)
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
	return {code = sys.error.delivery.verify_card_error.code, msg = "验卡请求返回内容解析失败:"..content}
end

zsh_recharge_card.___get_http_client = function(recharge_http, params)
	if(tostring(params.need_login) == "0") then
		return sys.error.success, recharge_http
	end

	local result, cookie = zsh_recharge_card.loginlib.get_random_cookies(params.up_channel_no, params.up_shelf_id)
	if(result.code ~= sys.error.success.code) then
		return result
	end

	if(zsh_recharge_card.http == nil) then
		return sys.error.system_busy
	end

	loginlib.clear_web_cookies(zsh_recharge_card.http)
	loginlib.set_web_cookies(zsh_recharge_card.http, cookie)
	return sys.error.success, zsh_recharge_card.http
end




return zsh_recharge_card
