
require 'sys'
require 'custom.common.wclient'
require 'utouu.comm'


function main()

	print(1)
	local http = wclient()
	test_query_page(http)
	
end

function test_get_cookies(http)
 	local ret,cookies = utouu_comm.get_web_cookies(http)
 	print('ret:'..tostring(ret))
 	print('cookies:'..tostring(cookies))
end

function test_query_page(http)
	
	local request_input = {
		method = "post",
		encoding = "UTF-8",
		content = "text",
		gzip = true,
		data = 'ipo_time=1&sort=stock_trade_price&order=DESC&page=100&limit=20',
		url = 'http://www.utcard.cn/utcard/listpage',
header = [[Host: www.utcard.cn
Connection: keep-alive
Accept: application/json, text/javascript, */*; q=0.01
Origin: http://www.utcard.cn
X-Requested-With: XMLHttpRequest
User-Agent: Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.101 Safari/537.36
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
Referer: http://www.utcard.cn/trade-center
Accept-Encoding: gzip, deflate
Accept-Language: zh-CN,zh;q=0.8]]

	}
	local content = http:query(request_input, {}, 3000)
	print('content:'..content)
	local obj = xtable.parse(content)
	print('obj:'..xtable.tojson(obj))
end

--[[
Cookie:JSESSIONID=F77CFAB966E8F6C9B3E2450DF601D5CC; SERVERID=241818301372624abb084e6e2b44ce66|1462602303|1462602303; CNZZDATA1257117916=1922946553-1462599383-%7C1462599383

]]