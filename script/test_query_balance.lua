
require 'sys'
require "custom.common.xhttp"
--require 'sqlite3'
require "CLRPackage"

import('SecurityCore')


function main()

	print("Hello!")


	--xj()
	--hc()
	--lufu()
	jingfeng_online()
end


function xj()

	local encode = 'UTF-8'
	local http = xhttp()
	local raw = 'username=18980509543&rtntype=1&key=bf9a51ce5479afeef7f6fa1de444363e'
	local sign = string.lower(xutility.md5.encrypt(raw,encode))
	print(sign)

	local post_data = 'username=18980509543&rtntype=1&sign='..sign
	--:http://xxx.xxx.xxx.xxx:xxx/xuanjie/querybalance
	local url = 'http://120.55.75.52:11158/xuanjie/querybalance'
	local content = http:get(url..'?'..post_data,encode)
	print('content:'..content)

end

function hc()

	local encode = 'UTF-8'
	local http = xhttp()
	local raw = 'userid=10001576&key=ygryuihfde68716'
	local sign = xutility.md5.encrypt(raw,encode)
	print(sign)

	local post_data = 'userid=10001576&sign='..sign
	local url = 'http://180.96.21.204:8082/searchbalance.do'
	local content = http:get(url..'?'..post_data,encode)
	print('content:'..content)

end

function jingfeng_online()

	local http = xhttp()
	local raw = 'SCQX201604081801'
	local key = '30D491D537BA7F47B390706B0D5EC063'
	local ret,sign = pcall(Security.Jinfeng_Hmac,raw,key)
	print(ret)
	if(not ret) then
		print('err:'..sign)
		return
	end

	local url = 'http://202.85.213.155:8080/youpintongAgentBalanceInterfaceServlet?'
		..'P1_agentcode=SCQX201604081801&hmac='..sign

	local content = http:get(url,'UTF-8')
	print('content:'..content)

end

function jingfeng_test()

	local http = xhttp()
	local raw = 'JFCS201601191438'
	local key = 'FC096367A92740622726F0FD225DC7DF'
	local ret,sign = pcall(Security.Jinfeng_Hmac,raw,key)
	print(ret)
	if(not ret) then
		print('err:'..sign)
		return
	end

	local url = 'http://218.241.136.86:8084/youpintongAgentBalanceInterfaceServlet?'
		..'P1_agentcode=JFCS201601191438&hmac='..sign

	local content = http:get(url,'UTF-8')
	print('content:'..content)

end

function lufu()

	local http = xhttp()

	local raw = 'APIID=16041958023164&APIKEY=A87548EB212E65309FF6B41CA34D39CD'
	local sign = xutility.md5.encrypt(raw,'UTF-8')
	local url = 'http://120.27.39.93/Api/GetUserMoney.aspx?APIID=16041958023164&Sign='..sign
	local content = http:get(url,'UTF-8')
	print(content)
--http://localhost:/Api/GetUserMoney.aspx
end
