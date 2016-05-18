require 'sys'
require 'custom.common.recognizelib'

-- 中石化的组包登录和cookie管理
loginlib = {}
loginlib.recognize = recognize()
loginlib.__config = {http_timeout = 30000, host = 'http://www.sinopecsales.com'}
loginlib.con_object = xdbg()
loginlib.login_result = {success='0',vcode_err2='2',vcode_err3='3',pwd_err='1',web_off='4'}

--- return errcode,msg(失败原因),cookies
--- 步骤：
--- 1、调用识别验证码
--- 2、识别
--- 3、请求登录
--- 4、返回结果
loginlib.login_on = function (http_request,login_name,pwd)
	print('登录账号:'..login_name)
	loginlib.clear_web_cookies(http_request)
	local ret,valid_code = loginlib.__read_valid_code(http_request)
	if(ret.code ~= sys.error.success.code) then
		return ret
	end

	local input = loginlib.get_login_request_header(login_name,pwd,valid_code)
	local content = http_request:query(input, {}, loginlib.__config.http_timeout)
	debug('登录返回结果:'..tostring(content))

	if(xstring.empty(content)) then
		return sys.error.login.response_empty
	end
	if(not xstring.start_with(content,'{') or not xstring.end_with(content,'}')) then
		error('请求返回非json:'..content)
		return sys.error.login.response_html
	end

	local response = xtable.parse(string.gsub(content,"\\/","/"))
	local status = tostring(response.success)
	if(status == loginlib.login_result.success) then
		local cookies = http_request:get_all_cookie(loginlib.__config.host..'/websso/')
		debug('截取到要用的cookies:'..tostring(cookies))
		loginlib.clear_web_cookies(http_request)
		return sys.error.success,cookies
	end
	
	if(status == loginlib.login_result.vcode_err2 or status == loginlib.login_result.vcode_err3) then
		return sys.error.login.valid_code_error
	elseif(status == loginlib.login_result.pwd_err) then
		return sys.error.login.password_error
	elseif(status == loginlib.login_result.web_off) then
		return sys.error.login.official_defend
	end

	error('官网返回未能处理的状态:'..status)
	return sys.error.login.unkown_result
end

--- return errcode
loginlib.check_is_logined = function(http)
	local input = loginlib.get_check_login_page_header()
	debug('header:'..xtable.tojson(input))
	local content = http:query(input, {}, 6000)
	debug('content:'..tostring(content))
	if(xstring.empty(content)) then
		error('请求返回空')
		return sys.error.login.response_empty
	end
	local a,_ = string.find(content,'请登录')
	if(type(a) == 'number') then
		error('cookie过期,需要重新登录')
		return sys.error.login.cookie_timeout
	end
	if(xstring.start_with(content,'{') and xstring.end_with(content,'}')) then
		print('账户验证为:已登录!')
		return sys.error.success
	end
	error(string.format('无法判断验证结果,content:%s',tostring(content)))
	return sys.error.login.response_html
end

--- return ret,cookies
loginlib.get_cookies = function(channel_no,up_shelf_id,login_name)
	local input = {channel_no=channel_no,up_shelf_id=up_shelf_id,login_name=login_name}
	local dbg_ret = loginlib.con_object:execute("web.account.get_account_cookies",input)
	if(dbg_ret.result.code ~= sys.error.success.code) then
		error(string.format('获取cookies失败:%s',xtable.tojson(input)))
		return dbg_ret.result
	end
	return dbg_ret.result,dbg_ret.data.cookies
end

--- return ret,cookies
loginlib.get_random_cookies = function(channel_no,up_shelf_id)
	local input = {channel_no=channel_no,up_shelf_id=up_shelf_id}
	local dbg_ret = loginlib.con_object:execute("web.account.get_random_cookies",input)
	if(dbg_ret.result.code ~= sys.error.success.code) then
		error(string.format('获取随机cookies失败:%s',xtable.tojson(input)))
		return dbg_ret.result
	end
	return dbg_ret.result,dbg_ret.data.cookies
end

---识别验证码
---return errcode,string[vcode]
loginlib.__read_valid_code = function (http_request)
	print('识别验证码')
	local status,msg = false,"未能识别验证码"
	local request_params = nil
	for i=1,10,1 do
		request_params = loginlib.get_vcode_recognize_params()
		status,msg=loginlib.recognize:net_recognize(http_request, request_params)
		if(status) then
			break
		end
	end
	if(not(status)) then
		error('识别失败,'..tostring(msg))
		return sys.error.login.valid_code_recognize_failure
	end
	local ret,calc_ret = loginlib.__calc_valid_code(request_params.result)
	if(ret.code ~= sys.error.success.code) then
		return ret
	end
	return ret,calc_ret
end

--- return errcode,number
loginlib.__calc_valid_code = function(vcode)
	print('计算验证码:'..tostring(vcode))
	local a = tonumber(string.sub(vcode, 1, 1))
	local b = tonumber(string.sub(vcode, 3, 3))
	local opt = string.sub(vcode, 2, 2)
	if(a == nil or b == nil) then
		error(string.format("验证码转换数字失败,%s无法计算",vcode))
		return sys.error.login.valid_code_calc_failure
	end
	local ret = 0
	if(opt == '+') then
		ret = a + b
	elseif(opt == '-') then
		ret = a - b
	elseif(opt == 'x') then
		ret = a * b
	elseif(opt == '/') then
		ret = a / b
	else
		error(string.format("无法识别的运算符:%s %s %s",a,opt,b))
		return sys.error.login.valid_code_calc_failure
	end
	return sys.error.success, ret
end

-- 登录之前，需要先获取JSSessionID来区分不同的登录用户
loginlib.clear_web_cookies = function(http)
	local domain = loginlib.__config.host
	--清除memberAccount
	http:set_cookie(domain, 'memberAccount=ydj_test; Expires=Tue, 15-Mar-2011 08:53:21 GMT; Path=/websso')
	http:set_cookie(domain, 'memberAccount=ydj_test; Expires=Tue, 15-Mar-2011 08:53:21 GMT; Path=/')
	--清除JSessionID
	http:set_httponly_cookie(domain, 'JSESSIONID=000000; Expires=Tue, 15-Mar-2011 08:53:21 GMT; Path=/websso')
	--清除ticket(这个很特殊,是全域名)
	http:set_httponly_cookie("http://sinopecsales.com", "ticket=ydj_tck; Expires=Tue, 15-Mar-2011 08:53:21 GMT; Path=/")
end

loginlib.set_web_cookies = function(http, cookies)
	local domain = loginlib.__config.host
	local arr = xstring.split(cookies,';')
	for i,v in pairs(arr) do
		--设置Set-Cookie:memberAccount=xiaoliya; Expires=Tue, 15-Mar-2016 01:56:43 GMT; Path=/websso
		if(xstring.start_with(v,'memberAccount')) then
			local str = string.format("%s;Path=/websso", v)
			http:set_cookies(domain, str)
		end
		--Set-Cookie:JSESSIONID=35C1347484A194425547A92326F8BDD2; Path=/websso; HttpOnly
		if(xstring.start_with(v,'JSESSIONID')) then
			http:set_httponly_cookie(domain, string.format("%s;Path=/websso", v))
			http:set_httponly_cookie(domain, string.format("%s;Path=/gas", v))
		end
		--Set-Cookie:ticket="SSO-550_M9YT8DKE9IFE6K6ZKLVTZD7ZY_NTYYXCIA8LGMPL5I6YYNFYH2GSSRK8UZEU8G,687474703A2F2F31302E352E3138302E35353A383038302F77656273736F"; Version=1; Domain=.sinopecsales.com; Path=/
		if(xstring.start_with(v,'ticket')) then
			http:set_cookies(domain, string.format("%s;Path=/", v))
		end
	end
end

loginlib.get_vcode_recognize_params = function()
	local params_vcode_recognize = {
		net = "zhongshihua.net",
		value = 0.5,
		len = 5,
		id = "",
		result = "",
		timeout = 5000,
		url = "http://www.sinopecsales.com/websso/YanZhengMaServlet?"..math.random(),
		header = [[Referer: http://www.sinopecsales.com/websso/loginAction_form.action
Accept: image/png, image/svg+xml, image/*;q=0.8, */*;q=0.5
Accept-Language: zh-CN
User-Agent: Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)
Accept-Encoding: gzip, deflate
Host: www.sinopecsales.com
Connection: Keep-Alive
Cache-Control: no-cache]]
	}
	return params_vcode_recognize
end

loginlib.get_login_request_header = function(login_name,pwd,valid_code)
	local post_data = string.format("memberAccount=%s&memberUmm=%s&rememberMe=on&check=%s&tsp=%s",
		login_name,pwd,valid_code,math.random())
	local params_login_request = {
		action = "download",
		method = "post",
		data = post_data,
		url = 'http://www.sinopecsales.com/websso/loginAction_login.json',
		encoding = "gbk",
		content = "text",
		gzip = true,
		header = [[Accept:application/json, text/javascript, */*; q=0.01
Accept-Encoding:gzip,deflate,sdch
Accept-Language:zh-CN,zh;q=0.8
Connection:keep-alive
Content-Type:application/x-www-form-urlencoded; charset=UTF-8
Host:www.sinopecsales.com
Origin:http://www.sinopecsales.com
Referer:http://www.sinopecsales.com/websso/loginAction_form.action
User-Agent:Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/31.0.1650.63 Safari/537.36
X-Requested-With:XMLHttpRequest]]
	}
	return params_login_request
end

loginlib.get_check_login_page_header = function()
	local params_refresh_page = {
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
	return params_refresh_page
end





return loginlib
