
query_comm = {}

query_comm.is_html = function(content)
	local s,e = string.find(content, "<html>")
	if(s ~= nil) then
		return true
	end
	return false
end
--获取卡密充值订单列表查询请求头
query_comm.get_kami_order_list_query_header = function(post_data)
	local params_order_query = {
		method = "post",
		encoding = "gbk",
		content = "text",
		gzip = true,
		data = post_data,
		url = 'http://www.sinopecsales.com/gas/webjsp/netRechargeAction_queryCardOrderOfCzk.json',
		header = [[Accept: application/json, text/javascript, */*; q=0.01
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
X-Requested-With: XMLHttpRequest
Referer: http://www.sinopecsales.com/gas/
Accept-Language: zh-cn
Accept-Encoding: gzip, deflate
User-Agent: Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)
Host: www.sinopecsales.com
Connection: Keep-Alive
Cache-Control: no-cache]]
	}
	return params_order_query
end

--获取网银充值订单列表查询请求头
query_comm.get_bank_order_list_query_header = function(post_data)
	local params = {
		method = "post",
		encoding = "gbk",
		content = "text",
		gzip = true,
		data = post_data,
		url = 'http://www.sinopecsales.com/gas/webjsp/netRechargeAction_queryCardOrderOfUnion.json',
		header = [[Accept:application/json, text/javascript, */*; q=0.01
Accept-Encoding:gzip, deflate
Accept-Language:zh-CN,zh;q=0.8
Connection:keep-alive
Content-Type:application/x-www-form-urlencoded; charset=UTF-8
Host:www.sinopecsales.com
Origin:http://www.sinopecsales.com
Referer:http://www.sinopecsales.com/gas/webjsp/charge/unionCardOrderList.jsp
User-Agent:Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/48.0.2564.97 Safari/537.36
X-Requested-With:XMLHttpRequest
Cache-Control: no-cache]]
	}
	return params
end

query_comm.get_card_query_header = function(post_data)
	local params_card_query = {
		method = "post",
		encoding = "gbk",
		content = "text",
		gzip = true,
		data = post_data,
		url = 'http://www.sinopecsales.com/gas/webjsp/memberOilCardAction_searchCzkStatus.json',
		header = [[Accept: application/json, text/javascript, */*; q=0.01
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
X-Requested-With: XMLHttpRequest
Referer: http://www.sinopecsales.com/gas/
Accept-Language: zh-cn
Accept-Encoding: gzip, deflate
User-Agent: Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)
Host: www.sinopecsales.com
Connection: Keep-Alive
Cache-Control: no-cache]]
	}
	return params_card_query
end

query_comm.get_order_info_query_header = function(post_data)
	local order_info_query_header = {
		method = "post",
		encoding = 'gbk',
		content = "json",
		data = post_data,
		url = "http://www.sinopecsales.com/gas/html/netRechargeAction_selectCardOrder.json",
		header = [[Accept:application/json, text/javascript, */*; q=0.01
Accept-Encoding:gzip, deflate
Accept-Language:zh-CN,zh;q=0.8
Connection:keep-alive
Content-Type:application/x-www-form-urlencoded; charset=UTF-8
Host:www.sinopecsales.com
Origin:http://www.sinopecsales.com
Referer:http://www.sinopecsales.com/gas/html/billQueryAction_goChangeCard.action
User-Agent:Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/48.0.2564.97 Safari/537.36
X-Requested-With:XMLHttpRequest]]
	}
	return order_info_query_header
end


return query_comm
