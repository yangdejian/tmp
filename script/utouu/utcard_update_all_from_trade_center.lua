require 'sys'
require 'custom.common.wclient'

all_update_from_TC = {fields="start_page_index"}

all_update_from_TC.comm = require 'utouu.comm'
all_update_from_TC.datafile = require 'utouu.datafile'

all_update_from_TC.CONFIG = {timeout=3000}
all_update_from_TC.http = wclient()

all_update_from_TC.main = function(args)
	print("----------------更新所有的府信息(交易中心)----------------")

	print("I. 检查必须参数")
	local params = xtable.parse(args[2], 1)
	if(xobject.empty(params, all_update_from_TC.fields)) then
   		print("缺少参数")
		return
	end

	print('II. 进入主流程')
	local ret,err,succ_count = all_update_from_TC.main_flow(params)

	print('IV. 保存更新结果')
	local ret,err = all_update_from_TC.datafile.update_over({
		is_succ = ret,
		msg = tostring(err),
		total_count = succ_count
	})
	if(not ret) then error('更新结果保存失败,err:'..err) end

	print('流程执行完成,is_ok:'..tostring(ret))
end

all_update_from_TC.main_flow = function(params)
	print('1. 开始更新')
	local ret,err = all_update_from_TC.datafile.start_update()
	if(not ret) then
		error('开始更新失败,'..tostring(err))
		return false,err
	end

	print('2. 获取府数据')
	local ret,datas = all_update_from_TC.get_all_utcard_list(params)
	if(not ret) then
		error('获取府数据错误,'..tostring(datas))
		return false,datas
	end

	print('3. 更新府数据')
	local succ_count = 0
	for i,v in pairs(datas) do
		local ret = all_update_from_TC.datafile.update_utcard(v)
		if(ret) then succ_count = succ_count + 1 end
	end
	return true,(succ_count==#datas and '更新全部完成!' or '更新部分完成!'),succ_count
end

all_update_from_TC.get_all_utcard_list = function(params)
	print('获取所有的糖卡列表')
	local govs = {}
	local i = params.start_page_index
	local err = nil
	while true do
		local ret,arr = all_update_from_TC.query_page_x(i)
		if(not ret) then
			err = tostring(arr)
			error('查询失败:'..err)
			break
		end
		if(xtable.empty(arr)) then
			error('已经没有数据了!')
			break
		end
		table.insert(govs,arr)
		i = i + 1
	end
	if(err) then
		return false,err
	end

	print('组合所有数据')
	local return_data = {}
	for i,v in pairs(govs) do
		for j,gov in pairs(v) do

			--- 第一次添加进来的府，需要获取分红日期和布衣数量(获取布衣数量：TODO)
			if(not all_update_from_TC.datafile.is_exists(gov.id)) then
				print('获取分红日期,ID:'..tostring(gov.id))
				local ret,bonus_date = all_update_from_TC.comm.get_bonus_date(all_update_from_TC.http,gov.id)
				if(not ret or xstring.empty(bonus_date)) then
					error("无法获取分红日期,"..tostring(bonus_date))
					break
				end
				gov.ft_date = string.sub(bonus_date,-2)
			end

			--- 转换上架时间
			gov.ipo_time = xstring.empty(gov.ipo_time) and '' or os.date("%Y-%m-%d",tonumber(gov.ipo_time)/1000)
			table.insert(return_data,gov)
		end
	end

	print('return_data:'..xtable.tojson(return_data))
	return true,return_data
end

all_update_from_TC.query_page_x = function(page_index)
	print(string.format('..... 下 载 第 %s 页 府 数 据 .....',page_index))

	local request_input = all_update_from_TC.header.utcard_list(page_index)
	print('input:'..xtable.tojson(request_input))
	local content = all_update_from_TC.http:query(request_input, {}, all_update_from_TC.CONFIG.timeout)
	--print('content:'..tostring(content))

	if(xstring.empty(content)) then
		return false,'请求返回空'
	end

	local obj = xtable.parse(content)
	if(not obj.success) then
		return false,'查询失败:'..xtable.tojson(obj)
	end

	print('total:'..tostring(obj.data.total))
	return true,obj.data.rows

end

all_update_from_TC.header = {}
all_update_from_TC.header.utcard_list = function(page_index)
    return {
		method = "post",
		encoding = "UTF-8",
		content = "text",
		gzip = true,
		data = 'ipo_time=1&sort=stock_trade_price&order=DESC&page='..tostring(page_index)..'&limit=20',
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
end


return all_update_from_TC