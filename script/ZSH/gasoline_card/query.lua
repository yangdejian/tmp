require "sys"
require "custom.common.wclient"

gasoline_card_query = {fields = "card_no", domain = "http://c.19ego.cn/oil_esales/CCBoilRechange_oilCard2ccb.do", encoding = "utf-8"}
gasoline_card_query.gasoline_card_archive_status = {normal         = 0, --正常
													sub            = 1, --副卡,
													lose           = 2, --挂失
													damage         = 3, --损坏
													discard        = 4, --废弃
													card_exception = 5, --卡异常
													expire         = 6, --卡过期
													not_exists     = 9  --卡号不存在
													}
gasoline_card_query.gasoline_card_type ={
	sub = '06',--副卡,
	lose = '05',
	not_exists = '03'
}													
gasoline_card_query.grs_dbg = xdbg("grs_db")
gasoline_card_query.http = wclient()

--[[main = function()
	gasoline_card_query.main({"", xtable.tojson({card_no = "1000115100001625079"})})

end]]


gasoline_card_query.main = function(args)
	print("------------------查询加油卡信息(高阳捷讯)2------------------")
	print("1. 检查参数")
	gasoline_card_query.params = xtable.parse(args[2], 1)
	if(xobject.empty(gasoline_card_query.params, gasoline_card_query.fields)) then
		error(string.format("缺少参数.需传入:%s,已传入:%s", gasoline_card_query.fields, args[2]))
		return sys.error.param_miss
	end

	print("2. 发送请求获取加油卡信息")
	gasoline_card_query.request_query_main_page()
	local result, card_holder,card_type = gasoline_card_query.request_card_query()
	if(result.code ~= sys.error.success.code) then
		return result
	end

	print("3. 将加油卡信息加入至保存加油卡信息MQ中")
	gasoline_card_query.join_to_card_info_save_mq(card_holder,card_type)
end

gasoline_card_query.request_query_main_page = function()
	local input = {}
	input.encoding = gasoline_card_query.encoding
	input.url =[[http://c.19ego.cn/oil_esales/CCBoilRechange_oilCard2ccb.do]]
				  
	gasoline_card_query.http:query(input, {}, 30000)
end

gasoline_card_query.request_card_query = function()
	local input = {}
	input.encoding = gasoline_card_query.encoding
	input.content = "json"
	input.method = "post"
	input.url = "http://c.19ego.cn/oil_esales/CCBoilRechange_queryCardNumber.do"
	input.data = string.format("cardNumber=%s", gasoline_card_query.params.card_no)
	input.header= [[Host: c.19ego.cn
Accept: text/plain, */*; q=0.01
X-Requested-With: XMLHttpRequest
Accept-Encoding: gzip, deflate
Accept-Language: zh-CN,zh;q=0.8,en-US;q=0.5,en;q=0.3
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
Origin: http://jiayou.19ego.cn:19000
User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 9_2_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Mobile/13D15 PSDType(0) AlipayDefined(nt:WIFI,ws:375|603|2.0) AliApp(AP/9.5.1.010816) AlipayClient/9.5.1.010816 Language/zh-Hans
APURLProtocol: APURLProtocol
Connection:keep-alive]]
	--gasoline_card_query.http:clear_all_cookie(gasoline_card_query.domain)
	--gasoline_card_query.http:set_cookies(gasoline_card_query.domain, "JSESSIONID=98FE770358E29F37355187EFB90DB7E4-n2.jvm33")
	local content = gasoline_card_query.http:query(input, {}, 30000)
	print("请求返回内容:"..tostring(content))
	if(xstring.empty(content)) then
		error("查询加油卡信息失败")
		return sys.error.failure
	end
	if(content == "quickAsk") then
		gasoline_card_query.join_to_card_info_query_mq(gasoline_card_query.params.card_no)
		return sys.error.unkown
	end
	local data = xstring.split(content, ",")
	if(#data == 2) then
		local card_holder = data[2]
		return sys.error.success, card_holder
	end
	if(#data == 3) then
		local card_holder = data[3]
		local card_type = data[2]
		return sys.error.success, card_holder,card_type
	end
	return sys.error.failure
	--[[
	local data = xstring.split(content, ",")
	if(#data ~= 2) then
		return sys.error.success
	end
	local card_holder = data[2]
	return sys.error.success, card_holder]]
end

gasoline_card_query.join_to_card_info_save_mq = function(card_holder,card_type)
	local status =""
	if(card_type == gasoline_card_query.gasoline_card_type.sub) then
		status = gasoline_card_query.gasoline_card_archive_status.sub
	elseif(card_type == gasoline_card_query.gasoline_card_type.lose)then
		status = gasoline_card_query.gasoline_card_archive_status.lose
	elseif(card_type == gasoline_card_query.gasoline_card_type.not_exists)then
		return
	elseif(card_holder == nil and card_type == nil) then
		return
	elseif(card_holder ~= nil and card_type == nil) then
			status = gasoline_card_query.gasoline_card_archive_status.normal
	else
		return
	end

	local send_data = {card_no = gasoline_card_query.params.card_no,
					card_holder = card_holder or "",
					carrier_no = "ZSH",
					status = status,
					is_complete = 1}
	local queues = xmq("gasoline_card_save")
	queues:send(send_data)
end

gasoline_card_query.join_to_card_info_query_mq=function (card_no)
	local queues= xmq("gasoline_card_query")
		local res1 = queues:send({card_no=card_no})
	
end

return gasoline_card_query
