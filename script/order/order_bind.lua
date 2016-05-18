require "sys"
require "xutility"
require "custom.common.xlib.xqstring"
require "custom.common.xxml"
require "custom.common.xhttp"

--处理订单绑定
order_bind = {encoding = 'gb2312',method = {},fields ='order_no'}
order_bind.enum={delivery_type={kami="1",zhichong="2",bank="3"},business_type = {jyk="11"},sup_business_type={jyk="10"}}
order_bind.xdbg = xdbg()
order_bind.ip = flowlib.get_local_ip()

order_bind.main = function(args)
	print("---------------------订单绑定流程开始--------------------")
	print("1. 订单绑定检查必传参数")
	local params=xtable.parse(args[2], 1)
	local check_result = order_bind.method.check_params(params)
   	if(check_result.code ~=sys.error.success.code) then
   		print("ERR输入参数有误")
   		return
   	end
	params = {order_no = params.order_no}
	print("2. 订单绑定主流程")
	local result,order =order_bind.main_flow(params)

	print("3. 处理后续流程")
	order_bind.method.send_mq(order)

    --print("4. 订单绑定流程统计")
    --order_bind.send_monitor(order,result)

	print("4. 订单绑定完成的生命周期")
	order_bind.create_lifetime(order)

	print("5. 订单绑定流程完成")
end


order_bind.main_flow = function(params)
    print("2.1 获取产品列表、渠道等信息")
    local get_result,product_info = order_bind.method.get_bind_info(params)
    local input_params = xtable.merge(params,product_info)
    if(get_result.code ~=sys.error.success.code) then
    	input_params.content = "【绑定失败】"..get_result.code
   		return get_result,input_params
   	end

    print("2.2 获取卡密或银行等信息")
    local kami_result,card_info,product,save_result,save_data = order_bind.method.get_ext_info(input_params)
    if(kami_result.code ~=sys.error.success.code) then
    	input_params.content = "【绑定失败】"..kami_result.msg
    	input_params = xtable.merge(input_params,save_data)
        if(save_result.code~=sys.error.success.code) then
        	input_params.content = input_params.content.."【调用失败pro】"..save_result.code
        end
   		return kami_result,input_params
   	end

	print("2.3 订单绑定")
	input_params = xtable.merge(input_params,card_info)
	input_params = xtable.merge(input_params,product)
	local create_result,order = order_bind.method.create_bind(input_params)
	input_params = xtable.merge(input_params,order)
	input_params.content = "【绑定结束】"..create_result.code

   	return  create_result,input_params
end

--- 检查参数
order_bind.method.check_params=function (params)
	if(xobject.empty(params, order_bind.fields)) then
		return sys.error.param_miss
	end
	return sys.error.success
end

--- 获取卡密渠道等信息
order_bind.method.get_bind_info = function(params)
	local info=order_bind.xdbg:execute("order.bind.get_product_info",{order_no=params.order_no})
	order_bind.create_lifetime(xtable.merge({content = "【绑定获取】"..info.result.code},params))
    return info.result,xobject.empty(info,"data")and {} or info.data

end

--- 接口获取ext信息,如果是卡密则返回卡密，银行卡则返回绑定账户，直充不返回值
order_bind.method.get_ext_info = function (pro)
	local ext_result = sys.error.failure
	local ext_info={}

	print(xtable.tojson(pro.products))
	for i, item in pairs(pro.products) do
		if(item.delivery_type == order_bind.enum.delivery_type.kami) then
			print("调用接口获取卡密")
			ext_result,ext_info = order_bind.method.get_card_info(xtable.merge(item,pro))
			if(ext_result.code == sys.error.success.code) then
				return ext_result,ext_info,item
			end	
		elseif(item.delivery_type == order_bind.enum.delivery_type.bank) then
			print("获取银行卡账户信息")
			ext_result,ext_info = order_bind.method.get_pay_account_info(xtable.merge(item,pro))
			if(ext_result.code == sys.error.success.code) then
				return ext_result,ext_info,item
			end	
		elseif(item.delivery_type == order_bind.enum.delivery_type.zhichong) then
			print("直充")
			return sys.error.success,ext_info,item	
		end
	end

	local res,data = order_bind.method.get_ext_error(xtable.merge(pro,{msg = ext_result.msg}))
	return ext_result,{},{},res,data
end

--取卡密失败调用数据库存储过程置为失败
order_bind.method.get_ext_error = function (pro) 
	local res =  order_bind.xdbg:execute("order.bind.get_ext_error",pro)
	return res.result,xobject.empty(res,"data") and {} or res.data
end

--- 创建发货数据
order_bind.method.create_bind = function (info)
	local order=order_bind.xdbg:execute("order.bind.create",info)
	return order.result,not(xobject.empty(order,'data')) and  order.data or {}
end

--==================================获取充值卡密=============================================
order_bind.method.get_card_info = function (data)
	local url  = order_bind.method.card_make(data)
	print("url=:"..url)
	return order_bind.method.card_request(url)
end
order_bind.method.get_pay_account_info =function (data)
	local account=order_bind.xdbg:execute("order.bind.get_bank_account",data)
	return account.result,not(xobject.empty(account,'data')) and  account.data or {}
end
--构建签名及URL【收卡系统取卡接口】
order_bind.method.card_make=function(params)
	local param=xqstring:new()
	param:add("businesstype",order_bind.enum.sup_business_type.jyk)
	param:add("carrierno",params.carrier_no)
	param:add("cityno",params.city_no)
	param:add("discount",params.down_real_discount)
	param:add("face",params.bind_standard)
	param:add("orderno",params.delivery_id)
	param:add("partnerno",params.sup_up_channel)
	param:add("provinceno",params.province_sup)
	local token=sys.decrypt_pwd(params.sup_up_channel,params.token_key)

	local q = xqstring:new(param)
	local raw = q:make({kvc = "=", sc = "&", req = true, ckey = true, encoding = order_bind.encoding})..token
	print(raw)
	q:add("sign", string.lower(utils.md5(raw, order_bind.encoding)))

	return  string.format("%s?%s", params.get_card_url, q:make({kvc = "=", sc = "&", req = true, ckey = true, encoding = order_bind.encoding}))
end

---SUP系统取卡
order_bind.method.card_request=function(url)
	local xml =xxml()
	local http = xhttp()
	local msg=""
	local cardinfo={}
	for i=1,3,1 do
		print("取卡次数:"..tostring(i))
		local content=http:get(url,order_bind.encoding)

		if(xml:load(content)) then
			local ret=xml:get("//response/result","innerText")
			msg=xml:get("//response/msg","innerText")
			if(ret=="0") then
				print("取卡成功")
				cardinfo.card_delivery_no=xml:get("//response/deliveryid","innerText")
				cardinfo.batch_no=xml:get("//response/batchno","innerText")
				cardinfo.card_no=xml:get("//response/cardno","innerText")
				local card_pwd=xml:get("//response/pwd","innerText")
				cardinfo.card_pwd=sys.encrypt_pwd(cardinfo.card_no,card_pwd)
				cardinfo.real_discount=xml:get("//response/discount","innerText")
				cardinfo.need_face_confirm=xml:get("//response/faceconfirm","innerText")
				cardinfo.card_type=xml:get("//response/cardtype","innerText")
				print("取卡结果"..xtable.tojson(cardinfo))
				return sys.error.success,cardinfo
			end
			print("content:"..tostring(content))
		else
			print("content:"..tostring(content))
			msg ="返回数据不是正确的xml格式"
		end
	end
	print("取卡失败,"..tostring(msg))
	return {code = 'failure',msg ="取卡失败,"..tostring(msg) }
end
--- 绑定失败或成功后处理后续流程
order_bind.method.send_mq=function (data)
	print("下一步："..tostring(data.next_step))
	if(xstring.empty(data.next_step)) then
		return
	end
	local mqinput={order_no=data.order_no,delivery_id=data.delivery_id,recharge_account_id = data.recharge_account_id}
	local queues = xmq(data.next_step)
	print(xtable.tojson(mqinput))
	local result = queues:send(mqinput)
	print("发送mq结果"..tostring(result))
end
--- grs系统的business_type转换成sup的
order_bind.method.to_sup_businesstype = function (businesstype)
	if(businesstype ==order_bind.enum.business_type.jyk) then
		return order_bind.enum.sup_business_typeorder_bind
	end
end
--- 创建订单的生命周期
order_bind.create_lifetime = function (order)
	local next_string=''
	if(not(xstring.empty(order.next_step))) then
		next_string ="【"..order.next_step.."】"
	end
	local result = order_bind.xdbg:execute("order.lifetime.save",{ 
		order_no = order.order_no,
		ip = order_bind.ip,
		content = order.content..next_string,
		delivery_id = 0
		})
	if(result.result.code~=sys.error.success.code) then
		print("添加订单绑定的生命周期失败"..result.result.code.."order_no"..order.order_no)
	end
end
return order_bind
