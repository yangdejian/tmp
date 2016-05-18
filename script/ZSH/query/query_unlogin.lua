
-------------------------------------------------------------------------
--- 不带账号查询
--- 适用于不带账号充值的订单,通过查询订单和充值卡来判断订单如何处理
-------------------------------------------------------------------------


require 'sys'

query_unlogin = {}
query_unlogin.comm = require('ZSH.query.comm')
query_unlogin.loginlib = require('lib.loginlib')
query_unlogin.CONFIG = {timeout = 6000}
query_unlogin.ZSH_ordersuccess = {no_paid='0',pay_succeed='1',pay_failed='2'} 
query_unlogin.ZSH_success = {no_start='0',under_way='1',success='2',failure='3',order_not_exists='4'}
query_unlogin.order_result = {success='ORDSUCC1_SUCC2',failure='ORDUSCC2',nodata='NODATA',unkown='UNKOWN'}
query_unlogin.card_use_status = {used='0',unuse='90',error='40',unkown='99'}
query_unlogin.card_use_msg = {['0']='USED',['90']='UNUSE',['40']='ERR',['99']='UNKOWN'}
query_unlogin.query_way = {by_ORDNO = 'Q_O', by_CHK_CARD = 'Q_CHK_CARD'}
query_unlogin.prefix = 'Q2'

--- return errcode,{up_error_code,success_standard,card_use_status[,up_order_no]}
query_unlogin.start_query = function(http,params)
	print('a. 检查字段')
	local require_fileds = 'up_shelf_id,card_no'
	if(xobject.empty(params,require_fileds)) then
		error('缺少必须参数:%s'..xtable.tojson(params))
		return sys.error.param_miss
	end
	
	print('b. 初始化http对象(获取并设置cookie)')
	local result, cookies = query_unlogin.loginlib.get_random_cookies(params.up_channel_no,params.up_shelf_id)
	if(result.code ~= sys.error.success.code) then
		error(string.format('获取随机cookie失败,code:%s,params:%s',result.code,xtable.tojson(params)))
		return sys.error.delivery.query.get_cookies_failed
	end
	query_unlogin.loginlib.clear_web_cookies(http)
	query_unlogin.loginlib.set_web_cookies(http, cookies)

	print('c. 根据参数情况进行查询')
	if(not xstring.empty(params.up_order_no)) then
		return query_unlogin.get_query_result_by_upOrderNo(http,params)
	else
		return query_unlogin.get_query_result_only_checkcard(http,params)
	end
end

query_unlogin.get_query_result_by_upOrderNo = function (http,params)
	print('通过上游订单号直接查询(无需登录的接口)')
	local query_way = query_unlogin.query_way.by_ORDNO
	local post_data = string.format("orderId=%s", params.up_order_no)
	local request_input = query_unlogin.comm.get_order_info_query_header(post_data)

	local content = http:query(request_input, {}, query_unlogin.CONFIG.timeout)
	local result = query_unlogin.check_response_content(content)
	if(result.code ~= sys.error.success.code) then
		return query_unlogin.build_query_fail_data(result,http,params)
	end

	local order_info = xtable.parse(content)
	return query_unlogin.build_query_ok_data(query_way,order_info,http,params)
end

query_unlogin.build_query_ok_data = function(query_way,order_info,http,params)
	print('查询成功,构建返回数据')
	local is_need,card_use_status = query_unlogin.is_need_check_card(order_info,params)
	if(is_need) then
		card_use_status = query_unlogin.check_card(http,params.card_no)
	end
	local deal_code = string.format('%s_ORDSUCC%sSUCC%s_CARD:%s',
		query_unlogin.prefix,tostring(order_info.ordersuccess or 'NULL'),tostring(order_info.success or 'NULL'),
		query_unlogin.card_use_msg[card_use_status])
	local return_data = {
		up_error_code = deal_code,
		success_standard = tonumber(order_info.orderMoney or 0)/100,
		card_use_status = card_use_status,
		up_order_no = order_info.sessionOrderId
	}
	return sys.error.success,return_data
end

query_unlogin.build_query_fail_data = function(query_ret,http,params)
	print('查询失败,根据验卡构建错误码')
	local deal_code = nil 
	local card_use_status = query_unlogin.check_card(http,params.card_no)
	if(query_ret.code == sys.error.delivery.query.single_response_empty.code) then
		deal_code = string.format('%s_RESPONSE_EMPTY_CARD:%s',
			query_unlogin.prefix,query_unlogin.card_use_msg[card_use_status])
	end
	if(query_ret.code == sys.error.delivery.query.single_response_html.code) then
		deal_code = string.format('%s_RESPONSE_HTML_CARD:%s',
			query_unlogin.prefix,query_unlogin.card_use_msg[card_use_status])
	end
	if(xstring.empty(deal_code)) then
		deal_code = string.format('%s_QUERY_OTHER_ERR_CARD:%s',
			query_unlogin.prefix,query_unlogin.card_use_msg[card_use_status])
	end
	local return_data = {
		up_error_code = deal_code,
		success_standard = 0,
		card_use_status = card_use_status
	}
	return query_ret,return_data
end

query_unlogin.get_query_result_only_checkcard = function (http,params)
	print('没有上游订单号(也不带账号),只能直接验卡')
	local query_way = query_unlogin.query_way.by_CHK_CARD
	local card_use_status = query_unlogin.check_card(http,params.card_no)
	local deal_code = string.format('%s_ONLY_CARD:%s',query_unlogin.prefix,query_unlogin.card_use_msg[card_use_status])
	print('DEAL_CODE:'..deal_code)
	local return_data = {
		up_error_code = deal_code,
		success_standard = 0,
		card_use_status = card_use_status
	}
	return sys.error.success,return_data
end

query_unlogin.check_card = function (http, card_no)
	print('查询验卡接口')
	local request_input = query_unlogin.comm.get_card_query_header('czkNo='..card_no)
	local content = http:query(request_input, {}, query_unlogin.CONFIG.timeout)
	debug('请求返回:'..tostring(content))
	if(xstring.empty(content) or query_unlogin.comm.is_html(content)) then
		error('验卡失败,返回:'..tostring(content))
		return query_unlogin.card_use_status.unkown
	end

	local obj = xtable.parse(content)
	print('分析验卡请求结果')
	if(obj.czkUseStatus == "已使用") then
		return query_unlogin.card_use_status.used
	end
	if(obj.czkUseStatus == "未使用") then
		return query_unlogin.card_use_status.unuse
	end
	if(obj.czkUseStatus == "error") then
		return query_unlogin.card_use_status.error
	end
	print("出现新的卡状态,czkUseStatus:"..tostring(obj.czkUseStatus))
	return query_unlogin.card_use_status.unkown
end

query_unlogin.is_need_check_card = function (order_info,params)
	if(query_unlogin.is_sure_order_success(order_info,params)) then
		return false,query_unlogin.card_use_status.used
	end
	return true
end

--- 订单是否允许被处理为成功
-- 成功订单{"ordersuccess":1,"sessionOrderId":"2116030417077614","orderMoney":10000,"success":2,"prefAmount":0}
-- 失败订单{"ordersuccess":2,"sessionOrderId":"2316031815081033"}
-- 订单号错误{"sessionOrderId":"2116030416547111","success":4}
-- 乱发的错误号码(订单号位数不足){"error":0,"sessionOrderId":""}
query_unlogin.is_sure_order_success = function(order_info,params)
	if(tostring(order_info.sessionOrderId) == params.up_order_no 
		and tostring(order_info.ordersuccess) == query_unlogin.ZSH_ordersuccess.pay_succeed 
		and tostring(order_info.success) == query_unlogin.ZSH_success.success) then
		return true
	end
	return false
end

--- 订单是否允许被处理为失败
query_unlogin.is_sure_order_failure = function(order_info,params)
	if(tostring(order_info.sessionOrderId) == query_params.up_order_no 
		and tostring(order_info.ordersuccess) == query_unlogin.ZSH_ordersuccess.pay_failed) then
		return true
	end
	return false
end

query_unlogin.check_response_content = function (content)
	print('检查请求返回内容')
	if(xstring.empty(content)) then
		error("查询失败,请求返回空")
		return sys.error.delivery.query.single_response_empty 
	end 
	if(query_unlogin.comm.is_html(content)) then
		error("查询失败,返回html:"..tostring(content))
		return sys.error.delivery.query.single_response_html 
	end
	return sys.error.success
end

return query_unlogin

