require 'sys'
require 'custom.common.wclient'

distrb_task = {fields = "min_bonus,min_profit_rate,ft_date,analyze_group_code"} --ft_date:'08'

distrb_task.datafile = require 'utouu.datafile'
distrb_task.CONFIG = {errlog=[[..\FlowError.txt]]} 
distrb_task.http = wclient()

distrb_task.main = function(args)
	print("----------------筛选需要分析的府----------------")
	print("I. 检查必须参数")
	local params=xtable.parse(args[2], 1)
	if(xobject.empty(params, distrb_task.fields)) then
		error("缺少必须参数")
		return
	end

	print("II. 进入主流程")
	local ret,msg,succ_count = distrb_task.main_flow(params)
	if(not ret) then
		error('主流程执行失败:'..tostring(msg))
	end

	print('III. 读取完成')
	local ret,err = distrb_task.datafile.read_over({
		is_succ = ret,msg = msg,total_count = succ_count
	})
	if(not ret) then
		error('保存读取状态失败,'..tostring(err))
	end

	print('流程执行完成,is_ok:'..tostring(ret))
end

distrb_task.main_flow = function(params)
	print('1. 开始读取')
	local ret,err = distrb_task.datafile.start_read()
	if(not ret) then
		error('开始读取状态错误,'..tostring(err))
		return false,tostring(err)
	end

	print('2. 装载所有的府')
	local govs = distrb_task.datafile.DATAS_Items()
	if(xtable.empty(govs)) then
		print('没有任何府数据')
		return false,'没有任何府数据可供加载!'
	end

	print('3. 筛选府:分红大于N元的,分红日=今天或空')
	local send_datas = {}
	for i,v in pairs(govs) do
		if(not xstring.empty(v.stock_avg_bonus) and tonumber(v.stock_avg_bonus) >= tonumber(params.min_bonus)) then
			if(xstring.empty(v.ft_date) or tostring(v.ft_date) == params.ft_date) then
				table.insert(send_datas,{
					name = v.name,
					code = v.code,
					id = v.id,
					min_bonus = params.min_bonus,
					ft_date = params.ft_date,
					min_profit_rate = params.min_profit_rate
				})
			end
		end
	end

	print('4. 发给分析流程队列,总数:'..tostring(#send_datas))
	local queues=xmq(params.analyze_group_code)
	local res=queues:send(send_datas)
	print(res and '队列发送成功!' or '队列发送失败!')

	return true,'筛选完成!',#send_datas
end

return distrb_task