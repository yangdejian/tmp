require 'sys'
require 'custom.common.wclient'

utcard_profit_analyze = {fields = "name,code,id,min_bonus,min_profit_rate,ft_date"} -- ft_date:'06'

utcard_profit_analyze.comm = require 'utouu.comm'
utcard_profit_analyze.datafile = require 'utouu.datafile'

utcard_profit_analyze.CONFIG = {errlog=[[..\LostGoverments_%s.txt]],ftdir=[[..\govments]],timeout=3000}
utcard_profit_analyze.http = wclient()

utcard_profit_analyze.main = function(args)
	print("----------------分析府利润----------------")
	print("I. 检查必须参数")
	local params=xtable.parse(args[2], 1)
	if(xobject.empty(params, utcard_profit_analyze.fields)) then
		error("缺少必须参数")
		return
	end

	print("II. 进入主流程")
	local ret,data = utcard_profit_analyze.analyze(params)
	if(not ret) then
		error('分析失败:'..tostring(data))
		utcard_profit_analyze.write_errlog(params,data)
	else
		error('分析成功:'..xtable.tojson(data))
		utcard_profit_analyze.save_to_txt(params,data)
	end

	print('流程执行完成')
end

utcard_profit_analyze.update_bonus_date = function(id,ft_date)
	print('更新分红日期保存到府:ID='..id)
	local ret = utcard_profit_analyze.datafile.update_utcard({
		id=id,
		ft_date=ft_date,
		last_update_time=utcard_profit_analyze.datafile.get_now('-')
	})
	print(ret and '更新成功' or '更新失败')
end

utcard_profit_analyze.analyze = function(params)

	print('1.确认分红日期')
	local ret,bonus_date = utcard_profit_analyze.comm.get_bonus_date(utcard_profit_analyze.http,params.id)
	if(not ret or xstring.empty(bonus_date)) then
		return false,"无法获取分红日期,"..tostring(bonus_date)
	end

	local ft_date = string.sub(bonus_date,-2)
	if(ft_date ~= params.ft_date) then
		utcard_profit_analyze.update_bonus_date(params.id,ft_date)
		return false,"分红日期不对!d:"..tostring(bonus_date)
	end

	print('2.确认分红金额')
	local ret,avg_bonus = utcard_profit_analyze.comm.get_avg_bonus(utcard_profit_analyze.http,params.code)
	if(not ret) then
		return false,"无法获取分红金额,"..tostring(avg_bonus)
	end
	if(avg_bonus < tonumber(params.min_bonus)) then
		return false,string.format("分糖%s小于要求最少分红%s",tostring(avg_bonus),tostring(params.min_bonus))
	end

	print('3.获取买入十档+卖出十档')
	local ret,ten_buy,ten_sell = utcard_profit_analyze.get_ten_buy(params)
	if(not ret) then
		return false,"无法获取买入十档,"..tostring(ten_buy)
	end

	print('4.分析这十档')
	local min_sell = utcard_profit_analyze.get_min_sell_price(ten_sell)
	if(xtable.empty(min_sell)) then
		return false,"没有人出手,无法分析" -- (没人卖,即无法获取利润)
	end

	local max_buy = utcard_profit_analyze.get_max_buy_price(ten_buy)
	if(xtable.empty(max_buy)) then
		return false,"没有人收购,无法分析"  -- (买了卖不出去)
	end

	local max_profit = max_buy.price + avg_bonus - (min_sell.price + max_buy.price*0.01)
	local max_profit_count = math.min(max_buy.amount,min_sell.amount)
	print(string.format('最高利润=%s*%s=%s',max_profit,max_profit_count,max_profit*max_profit_count))
	if(max_profit <= 0) then
		return false,"第一档就亏损:"..tostring(max_profit)
	end

	if(min_sell.price > 0) then
		local profit_rate = max_profit/min_sell.price
		if(profit_rate < tonumber(params.min_profit_rate)) then
			return false,string.format('利润率%s低于想要的利润率:%s',tostring(profit_rate),tostring(params.min_profit_rate))
		end
	end

	local return_data = {
		max_profit = max_profit,
		max_profit_count = max_profit_count,
		max_total_profit = max_profit * max_profit_count,
		min_sell_price = min_sell.price,
		max_buy_price = max_buy.price,
		cost = min_sell.price * max_profit_count,
		avg_bonus = avg_bonus,
		bonus_date = bonus_date
	}

	for i,v in pairs(ten_sell) do
		if(tonumber(v.price)>=24) then
			local key = 'MAI_'..xstring.lpading(i,2,'0')
			return_data[key] = return_data[key] or {}
			local my_buy_in = v

			for j,w in pairs(ten_buy) do
				if(tonumber(w.price)>=24) then
					local cost = my_buy_in.price + w.price*0.01
					local profit = w.price + avg_bonus - cost
					if(profit > 0) then
						local profit_count = math.min(w.amount,my_buy_in.amount)
						local content = string.format('从第 %s 档买入,卖给第 %s 档,成本:%s*%s=%s,利润:%s*%s=%s',
							xstring.lpading(i,2,'0'),
							xstring.lpading(j,2,'0'),
							cost,profit_count,cost*profit_count,
							profit,profit_count,profit*profit_count)
						table.insert(return_data[key],content)
					end
				end
			end
		end
	end

	print('return_data:'..xtable.tojson(return_data))

	return true,return_data

end

utcard_profit_analyze.get_ten_buy = function(params)
	print('获取糖票十档')
	local request_input = utcard_profit_analyze.header.ucard_ten(params.id)
	local ret,obj = utcard_profit_analyze.comm.http_request(utcard_profit_analyze.http,request_input)
	if(not ret) then
		return false,tostring(obj)
	end
	if(not obj.success) then
		return false,xtable.tojson(obj)
	end
	return true,obj.data.ten_buy,obj.data.ten_sell
end

utcard_profit_analyze.get_max_buy_price = function(ten_buy)
	print('获取最高收购价')
	local max_buy = {}
	for i,v in pairs(ten_buy) do
		if(v.price > 0) then
			if(xtable.empty(max_buy) or v.price > max_buy.price) then
				max_buy = v
			end
		end
	end
	print('最高收购:'..xtable.tojson(max_buy))
	return max_buy
end

utcard_profit_analyze.get_min_sell_price = function(ten_sell)
	print('获取最低出售价')
	local min_sell = {}
	for i,v in pairs(ten_sell) do
		if(v.price > 0) then
			if(xtable.empty(min_sell) or v.price < min_sell.price) then
				min_sell = v
			end
		end
	end
	print('最低出售:'..xtable.tojson(min_sell))
	return min_sell
end

utcard_profit_analyze.save_to_txt = function(params,data)
	print('保存成文件')
	local file = string.format([[%s\[%s][%s][%s][%s][%s-%s].txt]],
		utcard_profit_analyze.CONFIG.ftdir,
		data.bonus_date,
		os.date('%Y%m%d%H%M%S',os.time()),
		string.format('%.2f',data.max_total_profit),
		string.format('%s(%sx%s)',string.format('%.2f',data.cost),string.format('%.2f',data.min_sell_price),data.max_profit_count),
		params.code,
		params.name)

	print('file:'..file)

	local content = '分析数据：------------------------\r\n'
	local keys = {}
	for i,v in pairs(data) do
		table.insert(keys,i)
	end
	local sortFunc = function(a, b) return b < a end
	table.sort(keys,sortFunc)

	for i,key in pairs(keys) do
		local v = data[key]
		if(type(v) == 'table') then
			for j,w in ipairs(v) do
				content = content..string.format('%s_%s:%s\r\n',key,j,tostring(w))
			end
		else
			content = content..string.format('%s:%s\r\n',key,tostring(v))
		end
	end

	content = content..'\r\n输入参数：-----------------------\r\n'
	for i,v in pairs(params) do
		content = content..tostring(i)..':'..tostring(v)..'\r\n'
	end

	base.SaveFile(file,content)
end

utcard_profit_analyze.write_errlog = function(params,err)
	print('写入错误日志')
	local key = os.date('%Y%m%d',os.time())..'_'..params.code
	local content = string.format('府:%s(%s),最少分红:%s,ERR:%s',
		params.name,params.code,params.min_bonus,tostring(err))
	local log = string.format(utcard_profit_analyze.CONFIG.errlog,os.date('%m%d_%H%M'))
	base.WriteString("AnalyzeFailed", key, content, log)
end

utcard_profit_analyze.header={}
utcard_profit_analyze.header.ucard_ten = function(id)
    return {
		method = "get",
		encoding = "UTF-8",
		content = "text",
		gzip = true,
		data = '_='..tostring(id)..os.date('%Y%m%d%H%M%S'),
		url = 'http://www.utcard.cn/utcard/ten/'..tostring(id),
		header = [[Accept:application/json, text/javascript, */*; q=0.01
Accept-Encoding:gzip, deflate, sdch
Accept-Language:zh-CN,zh;q=0.8
Cache-Control:max-age=0
Connection:keep-alive
Host:www.utcard.cn
Referer:http://www.utcard.cn/utcard/133906
User-Agent:Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.101 Safari/537.36
X-Requested-With:XMLHttpRequest]]
	}
end


--获取糖卡详细信息用
--utcard_profit_analyze.header.ucard_detail_info = function(id)
--    return {
--		method = "get",
--		encoding = "UTF-8",
--		content = "text",
--		gzip = true,
--		data = '_='..tostring(id)..os.date('%Y%m%d%H%M%S'),
--		url = 'http://www.utcard.cn/utcard/info/'..tostring(id),
--		header = [[Accept:application/json, text/javascript, */*; q=0.01
--Accept-Encoding:gzip, deflate, sdch
--Accept-Language:zh-CN,zh;q=0.8
--Cache-Control:max-age=0
--Connection:keep-alive
--Host:www.utcard.cn
--Referer:http://www.utcard.cn/utcard/133906
--User-Agent:Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.101 Safari/537.36
--X-Requested-With:XMLHttpRequest]]
--	}
--end



return utcard_profit_analyze