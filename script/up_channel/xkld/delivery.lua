require "sys"
require "xqstring"
require "custom.common.xhttp"

--处理订单发货
xkld_delivery = {fields="delivery_id",encode="UTF-8",pre_code='XKLD_D_'}
xkld_delivery.config = {result_source=2,robot_code=flowlib.get_local_ip()}
xkld_delivery.up_carrier_no = {ZSH=1,ZSY=2}

xkld_delivery.dbg = xdbg()
xkld_delivery.http = xhttp()


xkld_delivery.main = function(args)
	print("-------------- 【新科兰德】上游发货 ------------")

	print("【检查输入参数】")
	local params=xtable.parse(args[2], 1)
	if(xobject.empty(params, xkld_delivery.fields)) then
		print("ERR输入参数有误")
		return sys.error.param_miss
	end
	local input = xtable.merge(params,xkld_delivery.config)

	print("【上游发货主流程】")
	local result,data,content = xkld_delivery.main_flow(input)

	print("【发货完成的生命周期】")
	xkld_delivery.create_lifetime(xtable.merge(input,data),content)

	print("流程结束:"..result.code)
end

xkld_delivery.main_flow = function(params)

	print("1. 获取发货订单数据")
	local result,delivery_info = xkld_delivery.get_delivery_info(params)
	if(result.code ~= "success") then
		return result,{},"【发货结束】发货获取失败:"..result.code
	end
	delivery_info.delivery_id = params.delivery_id

	print("2. 处理上游发货")
	local response_data = xkld_delivery.request_order(delivery_info)

	print("3. 保存发货结果")
	local result,data = xkld_delivery.save_result(delivery_info,response_data)
	if(result.code ~= "success") then
		return result,delivery_info,string.format('【发货结束】%s',result.code)
	end

	print("4. 处理后续流程")
	if(not xstring.empty(data.next_step)) then
		xkld_delivery.next_step(data.next_step,delivery_info)
	end

	return sys.error.success,delivery_info,'【发货结束】success,NEXT:'..tostring(data.next_step)
end


--===================================获取发货订单=============================================
xkld_delivery.get_delivery_info = function(params)
	local return_data = {}

	print('获取发货数据')
	local db_ret = xkld_delivery.dbg:execute("order.delivery.get",params)
	if(db_ret.result.code ~= sys.error.success.code) then
		error('DBG-ERR:获取发货数据失败,parse:'..xtable.tojson(parse))
		return db_ret.result
	end
	return_data = xtable.merge(return_data,db_ret.data)

	print('获取发货配置信息')
	local db_ret = xkld_delivery.dbg:execute("order.delivery.get_delivery_config",db_ret.data)
	if(db_ret.result.code ~= sys.error.success.code) then
		error('DBG-ERR:获取发货配置信息失败,db_ret.data:'..xtable.tojson(db_ret.data))
		return db_ret.result
	end
	return_data = xtable.merge(return_data,db_ret.data)

	xkld_delivery.create_lifetime(return_data,"【发货获取】成功")
	return sys.error.success,return_data
end

--===================================发货请求=============================================
--发货请求
xkld_delivery.request_order = function(params)
	local response = {}
	local q = xqstring:new()
	local real_key = sys.decrypt_pwd(params.up_channel_no,params.token_key)

	print('2.1 构造签名和post_data')
	q:add("OpenID",real_key)
	q:add("key",params.account_name)
	q:add("proid",params.up_product_no)
	q:add("cardnum",params.product_num)
	q:add("game_userid",params.recharge_account_id)
	q:add("orderid",params.delivery_id)

	local raw = q:make({kvc="",sc="",req=true,ckey=false,encoding=xkld_delivery.encode})
	debug('raw:'..raw)
	local sign = xutility.md5.encrypt(raw,xkld_delivery.encode)
	debug('sign:'..sign)

	q:remove("OpenID")
	q:add("gasCardTel",'13800138000')
	q:add("chargeType",xkld_delivery.up_carrier_no[params.carrier_no])
	q:add("sign",sign)
	local post_data = q:make({kvc="=",sc="&",req=true,ckey=true,encoding=xkld_delivery.encode})
	print('post_data:'..post_data)

	print('2.2 请求下单接口')
	local url = params.recharge_url..'?'..post_data
	local content = xkld_delivery.http:get(url,xkld_delivery.encode)
	print("content:"..content)

	print('2.3 分析下单结果')
	if(xstring.empty(content)) then
		response.up_error_code = xkld_delivery.get_up_error_code(sys.error.response_empty.code)
		response.result_msg = '下单接口返回空'
		error(response.result_msg)
		return response
	end
	if(not xstring.start_with(content,'{') or not xstring.end_with(content,'}')) then
		response.up_error_code = xkld_delivery.get_up_error_code(sys.error.response_fmt_error.code)
		response.result_msg = '下单接口响应格式错误(返回非Json数据)'
		error(response.result_msg)
		return response
	end

	local data = xtable.parse(content)
	response.result_msg = string.format('%s|%s',data.error_code,data.reason)
	response.up_error_code = xkld_delivery.get_up_error_code(data.error_code)
	response.up_order_no = (xobject.empty(o,'result') and nil or o.result.sporder_id)
	print('response:'..xtable.tojson(response))
	return response
end

--===================================保存发货结果=============================================
--input:{delivery_id,channel_no,success_standard,result_source,result_msg,
--		query_timespan,up_error_code,robot_code}
xkld_delivery.save_result = function(delivery_info,response_data)
	print('保存发货结果')
	local input = {
		delivery_id = delivery_info.delivery_id,
		channel_no = delivery_info.channel_no,
		success_standard = xstring.empty(response_data.success_standard) and 0 or response_data.success_standard,
		result_source = xkld_delivery.config.result_source,
		result_msg = response_data.result_msg,
		query_timespan = delivery_info.query_timespan,
		up_error_code = response_data.up_error_code,
		robot_code = xkld_delivery.config.robot_code,
		up_order_no = xstring.empty(response_data.up_order_no) and 0 or response_data.up_order_no
	}
	local db_ret = xkld_delivery.dbg:execute("order.delivery.save",input)
	if(db_ret.result.code ~= sys.error.success.code) then
		error('发货保存失败:'..db_ret.result.code)
		error('保存参数:'..xtable.tojson(input))
		return db_ret.result
	end
	return db_ret.result,db_ret.data
end

xkld_delivery.get_up_error_code = function(code)
	return xkld_delivery.pre_code..code
end

--发货后的下一步处理
xkld_delivery.next_step = function (next_step,data)
	if(xstring.empty(next_step)) then
		return
	end
	local queues = xmq(next_step)
	local result = queues:send(data)
    print(result and "加入队列成功" or "加入队列失败")
end

--- 创建订单的生命周期
xkld_delivery.create_lifetime = function (data,content)
	if(xstring.empty(data.order_no)) then
		error("创建发货的生命周期时没有订单号")
		return
	end
	local result = xkld_delivery.dbg:execute("order.lifetime.save",{order_no = data.order_no,
		ip = xkld_delivery.config.robot_code,
		content = content,
		delivery_id = xstring.empty(data.delivery_id) and 0 or data.delivery_id})
	if(result.result.code ~= "success") then
		error("添加订单发货的生命周期失败:"..result.result.code)
	end
end

return xkld_delivery
