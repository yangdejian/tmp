require 'sys'
require "custom.common.xhttp"

--作者 阳德健
--流程作用 由oracle_job处理为压单超时的订单,处理它们的下一步
--压单超时包含：预付支付超时、绑定超时、发货超时
exp_next_step_handle = {}
--exp_next_step_handle.con_object=xdbg()
--exp_next_step_handle.scan_config=require("scan_config")

exp_next_step_handle.main = function(args)

	print('--------------Hello,World!---------------')
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

exp_next_step_handle.main_flow = function(args)

	local trace_args={}
	
	print("1. 标记压单超时的需要处理下一步流程的处理批次")
	local result,data=exp_next_step_handle.set_batch_id_to_steps()
	trace_args.total_count=data.mark_count
	trace_args.batch_id=data.batch_id
	if(result.code~="success" or data.mark_count<=0) then
		return result,trace_args
	end

	print("2. 获取批次数据,发送到相应消息队列")
	local result,data=exp_next_step_handle.get_send_data({batch_id=data.batch_id,mark_count=data.mark_count})
	if(result.code~="success") then
		return result,trace_args
	end
	local retry_data=data.messages
	print('send_datas:'..xtable.tojson(retry_data))

	print("3. 批量将数据加入至相应队列中")
	local result,data=exp_next_step_handle.join_message_queue(retry_data)
	trace_args.fail_count=data.fail_count
	if(result.code~="success") then
		return result,trace_args
	end
	if(data.fail_count > 0) then
		print("发送消息队列失败数："..tostring(data.fail_count))
		return sys.error.failure,trace_args
	end

	return sys.error.success,trace_args
end

-----------------------------------------------------------------------------
------------------------------- 辅助函数 ------------------------------------
--- 获取需要后补的消息队列数据
--- input:{batch_id=int,mark_count=int}
--- return reuslt,{messages=[]}
exp_next_step_handle.get_send_data=function(input)
	
	local db_res=exp_next_step_handle.con_object:execute("exception.auto_next_step.get_steps_by_scan_batch",{
		batch_id=input.batch_id,
		batch_handle_count=input.mark_count,
		flow_timeout_range=exp_next_step_handle.scan_config.timeout_flow_lower_limit})
	if(db_res.result.code~="success") then
		return db_res.result
	end

	local retry_data = {}
	for i,v in pairs(db_res.data.steps) do
		if(not xstring.empty(v.json_data)) then
			local mq_group = v.next_step_code
			retry_data[mq_group] = retry_data[mq_group] or {}
			print('jsondata:'..tostring(v.json_data))
			local obj = xtable.parse(v.json_data)
			table.insert(retry_data[mq_group], obj)
			exp_next_step_handle.insert_order_life(xtable.merge(obj,v))
		end
	end

	return db_res.result,{messages=retry_data}
end

--- 标记批次
--- return result,{mark_count=0,batch_id=1}
exp_next_step_handle.set_batch_id_to_steps=function()
	local mark_input={flow_timeout_range=exp_next_step_handle.scan_config.timeout_flow_lower_limit,
		mark_row_num=exp_next_step_handle.scan_config.handle_num_once}
	local batch=exp_next_step_handle.con_object:execute("exception.auto_next_step.mark_handle_steps",mark_input)

	if(batch.result.code~="success" or tonumber(batch.data.count)<=0) then
		return batch.result,{mark_count=0}
	end
	return batch.result,{mark_count=batch.data.count,batch_id=batch.data.batch_id}
end

exp_next_step_handle.join_message_queue = function(data)
	local send_faild_count=0
	for i,v in pairs(data) do
		local queues=xmq(i)
		local res=queues:send(v)
		if(not(res)) then
			send_faild_count=send_faild_count+1	
		end
	end
	return sys.error.success,{fail_count=send_faild_count}
end

exp_next_step_handle.insert_order_life = function (params)
	if(xstring.empty(params.order_no) or params.order_no == '_' 
		or params.order_no == '0' or params.order_no == '*') then
		print('检测到订单号无效,无需插入生命周期')
		print('order_no:'..tostring(params.order_no))
		return sys.error.success
	end
	local input = {
		order_no = params.order_no,
		delivery_id = params.delivery_id or 0,
		ip = flowlib.get_local_ip(),
		content = '【自动后补】NEXT:'..tostring(params.next_step_code)
	}
	print("保存参数:"..xtable.tojson(input))
	local dbg_result = exp_next_step_handle.con_object:execute("order.lifetime.save", input)
	if(dbg_result.result.code ~= 'success') then
		print('DBG_ERR插入生命周期失败')
		return dbg_result.result
	end
	print("插入生命周期成功!")
	return dbg_result.result
end

--========================================监控================================================
exp_next_step_handle.send_monitor =function(params)
	params = params or {}
	params.name = exp_next_step_handle.scan_config.scan_monitor_name
	params.fix_monitor_type = exp_next_step_handle.scan_config.scan_monitor_type.down_notify
	params.desc = "压单超时的下一步处理"
	params.total_count = params.total_count or 0
	params.fail_count = params.fail_count or 0

	if(params.total_count > 0) then
		print("统计保存")
		--sys.monitor.save(nil,params)
	end
end

return exp_next_step_handle
