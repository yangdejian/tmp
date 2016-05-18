require "sys"

--{happen_time:'20151020155800',level:'90',content:'xxxxxx',source:'20',source_sign:'下游通知|192.168.101.111'}
function main(args)

	--send_update_cmmmand()
	send_distrb_command()
end

function send_distrb_command()
	local queues = xmq("analyze_distrb")
	local send_msg = xtable.parse('{"min_bonus":"1","min_profit_rate":"0.02","ft_date":"17","analyze_group_code":"profit_analyze"}')
	local res = queues:send(send_msg)
end

function send_update_cmmmand()
	local queues = xmq("update_all_from_tc")
	local send_msg = xtable.parse('{"start_page_index":"1"}')
	local res = queues:send(send_msg)
end

function send_profit_analyze()
	local queues = xmq("profit_analyze")
	local send_msg = xtable.parse('[{"name":"苏伯府","code":"132736","id":"272","min_bonus":"1","ft_date":"06"},{"name":"光辉岁月","code":"132737","id":"273","min_bonus":"1","ft_date":"07"}]')
	local res = queues:send(send_msg)
end
