require "sys"

-- 作者 阳德健
-- 流程作用:定时保持登录的检查流程
-- 需要登录,分发给登录流程;需要维持,分发给维持流程
cookie_check = {}
cookie_check.con_object = xdbg()
cookie_check.loginlib = require("lib.loginlib")
cookie_check.CONFIG = {
	group_name = flowlib.get_local_ip(),
	delay_secs = 3 * 60
}
cookie_check.status_flow_map = {['0'] = 'zsh_website_keep_cookie',['8'] = 'zsh_website_login_on'}


cookie_check.main = function(args)
	print("----------------[开始]保持登录的定时检查流程---------------")

	print("1. 获取登录账户列表")
	local result,list = cookie_check.get_login_accounts(cookie_check.CONFIG)
	if(result.code ~= sys.error.success.code) then
		return result
	end
	if(#list <= 0) then
		print('没有需要处理的账号')
		return sys.error.success
	end

	print("2. 按状态筛选数据")
	local messages = {}
	for i,v in pairs(list) do
		print("数据详情内容："..xtable.tojson(v))
		local flow = cookie_check.status_flow_map[tostring(v.status)]
		messages[flow] = messages[flow] or {}
		table.insert(messages[flow], v)
	end

	print("3. 把消息发送出去")
	local send_faild_count = 0
	for i,v in pairs(messages) do
		local queues = xmq(i)
		local res = queues:send(v)
		if(not(res)) then
			send_faild_count = send_faild_count + table.getn(v)	
		end
	end
	return sys.error.success,{fail_count = send_faild_count}

end

cookie_check.get_login_accounts = function(params)
	local dbg_ret = cookie_check.con_object:execute("web.account.get_account_list_wait_keep_or_login",params)
	if(dbg_ret.result.code ~= sys.error.success.code) then
		return dbg_ret.result
	end
	return dbg_ret.result,dbg_ret.data.items
end

return cookie_check
