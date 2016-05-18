
utouu_comm = {}

utouu_comm.update_status = {not_start='10',wait='20',doing='30',success='0',failure='90'}
utouu_comm.read_status = {not_start='10',wait='20',doing='30',success='0',failure='90'}
utouu_comm.host = 'http://www.utcard.cn'

utouu_comm.file_exists = function(path)
	local file = io.open(path, "rb")
	if file then file:close() end
	return file ~= nil
end

utouu_comm.get_bonus_date = function(http,id)
	print('获取分红日期')
	local request_input = utouu_comm.header.bonus_distrb_date(id)
	local ret,obj = utouu_comm.http_request(http,request_input)
	if(not ret) then
		return false,tostring(obj)
	end
	print('分红日期：'..tostring(obj.bonusDistritionsDay))
	return true,obj.bonusDistritionsDay
end

utouu_comm.get_avg_bonus = function(http,code)
	print('获取每票分红')
	local request_input = utouu_comm.header.ucard_simple_info(code)
	local ret,obj = utouu_comm.http_request(http,request_input)
	if(not ret) then
		return false,tostring(obj)
	end
	if(not obj.success) then
		return false,xtable.tojson(obj)
	end
	local gov = obj.data.rows[1]
	if(xtable.empty(gov)) then
		return false,'没有查到府信息:'..xtable.tojson(obj)
	end
	print('每票分红：'..tostring(gov.stock_avg_bonus))
	return true,tonumber(gov.stock_avg_bonus)
end

utouu_comm.http_request = function(http,request_input)
	debug('input:'..xtable.tojson(request_input))
	local content = http:query(request_input, {}, 3000)
	print('content:'..tostring(content))
	if(xstring.empty(content)) then
		return false,'请求返回空'
	end
	if(not xstring.start_with(content,'{')) then
		return false,'返回的格式非json'
	end

	local obj = xtable.parse(content)
	return true,obj
end

utouu_comm.header = {}
utouu_comm.header.bonus_distrb_date = function(id)
    return {
		method = "get",
		encoding = "UTF-8",
		content = "text",
		gzip = true,
		data = '_='..tostring(id)..os.date('%Y%m%d%H%M%S'),
		url = 'http://www.utcard.cn/utcard/get-bouns-distritions-day/'..tostring(id),
		header = [[Accept:application/json, text/javascript, */*; q=0.01
Accept-Encoding:gzip, deflate, sdch
Accept-Language:zh-CN,zh;q=0.8
Cache-Control:max-age=0
Connection:keep-alive
Host:www.utcard.cn
Referer:http://www.utcard.cn/utcard/133906
User-Agent:Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.101 Safari/537.36
X-Requested-With:XMLHttpRequest]]
	}
end

utouu_comm.header.ucard_simple_info = function(code)
    return {
		method = "post",
		encoding = "UTF-8",
		content = "text",
		gzip = true,
		data = 'ipo_time=0&sort=stock_trade_price&order=DESC&page=1&limit=20&stock='..code,
		url = 'http://www.utcard.cn/utcard/listpage',
		header = [[Accept:application/json, text/javascript, */*; q=0.01
Accept-Encoding:gzip, deflate
Accept-Language:zh-CN,zh;q=0.8
Connection:keep-alive
Content-Length:73
Content-Type:application/x-www-form-urlencoded; charset=UTF-8
Host:www.utcard.cn
Origin:http://www.utcard.cn
Referer:http://www.utcard.cn/trade-center
User-Agent:Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.101 Safari/537.36
X-Requested-With:XMLHttpRequest]]
	}
end


return utouu_comm




--[[utouu_comm.get_web_cookies = function(http)
	local input = utouu_comm.header.trade_center
	local content = http:query(input, {}, 300)
	--debug('get_web_cookies-content:'..tostring(content))

	if(xstring.empty(content)) then
		return false,"请求返回空"
	end

	local cookies = http:get_all_cookie(utouu_comm.host)
	debug('截取到要用的cookies:'..tostring(cookies))

	return true,cookies
end

utouu_comm.clear_web_cookies = function(http)
	local domain = utouu_comm.host
	http:set_cookie(domain, 'SERVERID=0; Expires=Tue, 15-Mar-2011 08:53:21 GMT; Path=/')
	http:set_cookie(domain, 'CNZZDATA1257117916=0; Expires=Tue, 15-Mar-2011 08:53:21 GMT; Path=/')
	http:set_httponly_cookie(domain, 'JSESSIONID=0; Expires=Tue, 15-Mar-2011 08:53:21 GMT; Path=/')
end

utouu_comm.set_web_cookies = function(http, cookies)
	local domain = utouu_comm.host
	local arr = xstring.split(cookies,';')
	for i,v in pairs(arr) do
		if(xstring.start_with(v,'SERVERID')) then
			http:set_cookies(domain, string.format("%s;Path=/", v))
		end
		if(xstring.start_with(v,'CNZZDATA')) then
			http:set_cookies(domain, string.format("%s;Path=/", v))
		end
		if(xstring.start_with(v,'JSESSIONID')) then
			http:set_httponly_cookie(domain, string.format("%s;Path=/", v))
		end
	end
end
]]