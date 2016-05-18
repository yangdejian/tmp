require "sys"
require "custom.common.xhttp"
require "custom.common.qparam"
require 'xsign'
require "custom.common.xxml"
require 'xqstring'

--作者 李亚
-- 流程作用 淘宝通知流程

tb_order_notify_config ={fields ='order_no', charset= 'gbk',notify_count = 10,pkg = require("config.package")}
tb_order_notify = {request = {}, nexts = {}, save = {}, info = {},monitor = {} }
tb_order_notify.xdbg=xdbg()
tb_order_notify.ip = flowlib.get_local_ip()

tb_order_notify.main = function(args)
	print("---------------------淘宝订单通知流程开始--------------------")
	print("1. 淘宝通知检查必传参数】")
	local params = xtable.parse(args[2], 1)
	if(xobject.empty(params, tb_order_notify_config.fields)) then
		print("ERR输入参数有误")
		return sys.error.param_error
	end

	print("2. 通知主流程")
	local result,order,save_result =tb_order_notify.main_flow(params)

	print("3. 淘宝通知完成的生命周期")
	tb_order_notify.create_lifetime(order)

	print("4. 淘宝订单通知流程完成")
end

tb_order_notify.main_flow = function(params)    
	print("1.1 获取要通知的数据.订单号："..params.order_no)
	input_params =params
	local res=tb_order_notify.info.get_notify_info(params)
	if(not(xstring.equals(res.result.code, "success"))) then
		input_params.content = "【通知失败】"..res.result.msg
		return res.result,input_params
	end

	print("1.2 通知下游")
	input_params = xtable.merge(input_params,res.data)
	local result,notify_result = tb_order_notify.request.notify(res.data,params.times)
	input_params.desc=notify_result.msg
	if(not(xstring.equals(result.code, "success"))) then
		input_params.content = "【通知失败】"..notify_result.msg
		return notify_result,input_params
	end 

	print("1.3 通知保存")
	local save_result =  tb_order_notify.save.notify_save(notify_result,res.data )
	 if(xstring.equals(save_result.result.code, "success")) then
	  	print("1.4 通知保存的下一步"..save_result.data.next_step_code)
	    tb_order_notify.nexts.notify_next_step(save_result.data.next_step_code,res.data)
		next_step="【"..save_result.data.next_step_code.."】"
	end
    input_params.content = "【通知结束】"..notify_result.code..tostring(next_step).."【通知保存结果】"..save_result.result.code
	
	return  result,input_params,save_result.result

end

---==========================================获取通知===================================
--返回要通知的数据
tb_order_notify.info.get_notify_info = function (params)
	local res=tb_order_notify.xdbg:execute("order.notify.info_query",{order_no = params.order_no,notify_robot_code = flowlib.get_local_ip()})
	tb_order_notify.create_lifetime(xtable.merge({content = "【查询通知】"..res.result.code},params))
	return res

end

--==========================================通知===================================
--通知 通知有次数且失败则直接return 否则走下一步保存
tb_order_notify.request.notify=function (data ,current_times)	
	local result = tb_order_notify.request.notify_up_data(data)
	print("发送通知结果："..tostring(result.msg))
	local times= current_times or 1

	if(not(xstring.equals(result.code, "success")) and times < tb_order_notify_config.notify_count) then
		print("通知失败，次数还有，重新发送,当前次数："..times)
		tb_order_notify.request.notify_send(times,data.order_no)
		return sys.error.failure,result
	end
	return sys.error.success,result
end
--通知发送
tb_order_notify.request.notify_send = function(times,order_no)
	local notify_queues = xmq("tb_order_notify")
		local result = notify_queues:send({times = times  + 1,order_no = order_no})
		print(result and  "加入通知队列成功" or "加入通知队列失败")
end
--根据返回数据,构建通知发送
tb_order_notify.request.notify_up_data = function(data)
	local http=xhttp()
	local path = data.notify_url..tb_order_notify.request.set_input_params(data,notify)
	print("通知url:"..path)
	--发送通知
	local send_result=http:get(path,tb_order_notify_config.charset)
	
	send_result= string.gsub(string.gsub(send_result,'\r',''),'\n','')
	print("result："..tostring(send_result))
	local xml = xxml()
	if(xml:load(send_result)) then
			local ret=xml:get("//response/result","innerText")
			if(ret=="T") then
				print("通知成功，淘宝回复True")
				return sys.error.success
			elseif(ret=="F") then
				print("通知成功，淘宝回复False")
				local failCode=xml:get("//response/failCode","innerText")
				local failDesc=xml:get("//response/failDesc","innerText")
				return {code = failCode,msg =failDesc }
			else
				return {code = sys.error.failure.code,msg ="返回结果未知" }
			end
	else
			msg ="返回数据不是正确的xml格式"
			return {code = sys.error.failure.code,msg =msg }
	end
	send_result = not(xstring.empty(send_result)) and send_result or'下游返回空'
	return {code = sys.error.failure.code,msg =send_result }
end
--设置发送的数据格式?后面的拼接
tb_order_notify.request.set_input_params = function(data,notify)	

	print("所传参数"..xtable.tojson(data))
	local q = xqstring:new()
	q:add('bizType',data.ext_business_type)
	q:add('coopOrderNo',data.order_no)
	q:add('coopOrderStatus',data.tb_status )
	q:add('failCode',data.fail_code)
	q:add('failDesc',data.fail_desc)
	q:add('supplierId',data.expand_channel_no)
	q:add('tbOrderNo',data.down_order_no)
	q:add('ts',tostring(os.time())..'000')
	q:sort()

	local token = sys.decrypt_pwd(data.down_channel_no,data.token)
	local post_data = q:make({kvc = "", sc = "", req = true, ckey = true, encoding = tb_order_notify_config.charset})
      local  raw = post_data..token
      print("raw:"..raw)
	  local sign =  string.lower(utils.md5(raw,tb_order_notify_config.charset))
	  q:add('sign',sign)
	  q:remove("failDesc")
	  q:add('failDesc',base.UrlEncode(data.fail_desc,"utf-8","All"))
	  local return_data= q:make({kvc = "=", sc = "&", req = true, ckey = true, encoding = tb_order_notify_config.charset})
	  return '?'..return_data
end

---============================================通知保存==========================================
--通知保存 通知结果成功则返回保存结果
tb_order_notify.save.notify_save=function (result,data )
	local notify_result= xstring.equals(result.code, "success") and tb_order_notify_config.pkg.delivery.notify_result.success or tb_order_notify_config.pkg.delivery.notify_result.failure
	return  tb_order_notify.save.notify_result_save(notify_result,result.msg,data)
end

--通知结果保存
tb_order_notify.save.notify_result_save = function(status,content,data)
	local save_result = tb_order_notify.xdbg:execute("order.notify.result_save",{notify_result= status,notify_msg = content,notify_id = data.notify_id})
	if(not(xstring.equals(save_result.result.code, "success"))) then
		print("通知成功修改结果时返回错误:"..xtable.tojson(save_result))
	end

	return save_result
end

--返回的下一步处理
tb_order_notify.nexts.notify_next_step=function (next_step_code,data)
	if(not(xstring.empty(next_step_code))) then			
			local queues = xmq(next_step_code)
			local send_result =queues:send({order_no= data.order_no})
			print(send_result and  "加入队列成功" or "加入对列失败")
	end
end



tb_order_notify.create_lifetime = function (data)
	local result = tb_order_notify.xdbg:execute("order.lifetime.save",{ 
		order_no = data.order_no,
		ip = tb_order_notify.ip,
		content = data.content,
		delivery_id = 0
		})
	if(not(xstring.equals(result.result.code,"success"))) then
		print("添加淘宝订单通知的生命周期失败"..result.result.code.."order_no"..data.order_no)
	end

end

return tb_order_notify
