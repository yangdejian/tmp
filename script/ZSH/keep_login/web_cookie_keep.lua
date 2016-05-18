require "sys"
require 'custom.common.wclient'


--作者 阳德健
--流程作用 刷新官网某个请求以维持登录cookie
cookie_keep = {fields = "up_channel_no,up_shelf_id,login_id,login_name,login_pwd,cookies"}
cookie_keep.con_object = xdbg()
cookie_keep.loginlib = require("lib.loginlib")
cookie_keep.http = wclient()
cookie_keep.CONFIG = {
	timeout = 6000,
	login_on_flow = 'zsh_website_login_on'
}


cookie_keep.main = function(args)
	print("----------------[开始]网站cookie的维持---------------")
	print("1. 检查必须参数")
	local input = xtable.parse(args[2], 1)
	if(xobject.empty(input, cookie_keep.fields)) then
		error(string.format("缺少必须参数,已传入:%s",args[2]))
		return sys.error.param_miss
	end

	print("2. 刷新页面")
	local result = cookie_keep.refresh_one_page(input.cookies)	
	if(result.code == sys.error.login.cookies_timeout.code) then
		cookie_keep.notify_login_flow(input)
	end	

	print("3. 保存刷新结果")
	local dbg_ret = cookie_keep.con_object:execute("web.account.update_account",{
		description = result.code, login_id = input.login_id})
	return dbg_ret.result
end

--- 通知登录流程重新登录
cookie_keep.notify_login_flow = function(params)	
	local queues = xmq(cookie_keep.CONFIG.login_on_flow)
	local res = queues:send(params)
	print(string.format('发送结果:%s',tostring(res)))
end

--- 刷新页面维持cookie
cookie_keep.refresh_one_page = function(cookies)
	
	cookie_keep.loginlib.clear_web_cookies(cookie_keep.http)
	cookie_keep.loginlib.set_web_cookies(cookie_keep.http, cookies)
	
	local count = 0
	::START::
	count = count + 1
	local content = cookie_keep.http:query(cookie_keep.params_refresh_page, {}, cookie_keep.CONFIG.timeout)	
	if(xstring.empty(content)) then
		if(count < 3) then
			goto START
		end		
		return sys.error.login.refresh_response_empty
	end

	print('分析结果')
	local a,_ = string.find(content,'请登录')
	if(a) then	
		return sys.error.login.cookies_timeout
	end

	if(xstring.start_with(content,'{') and xstring.end_with(content,'}')) then	
		return sys.error.success
	end
	error('请求返回非json:'..content)
	return sys.error.login.refresh_response_html
end

cookie_keep.params_refresh_page = {
	method = "post",
	encoding = "gbk",
	content = "text",
	gzip = true,
	data = 'czkNo=2510440002369517',
	url = 'http://www.sinopecsales.com/gas/webjsp/memberOilCardAction_searchCzkStatus.json',
	header = [[Accept:application/json, text/javascript, */*; q=0.01
Content-Type:application/x-www-form-urlencoded; charset=UTF-8
X-Requested-With:XMLHttpRequest
Referer:http://www.sinopecsales.com/gas/
Accept-Language:zh-cn
Accept-Encoding:gzip, deflate
User-Agent:Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)
Host:www.sinopecsales.com
Connection:Keep-Alive
Cache-Control:no-cache
Content-Length:22]]
}

return cookie_keep
