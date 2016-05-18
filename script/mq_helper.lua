require 'custom.common.utils'
require "custom.common.dblib"
function main()
	--Delete()
	get_list()
end

function send()
	local adapter = mq.MQAdapter("server0")
	local ret = adapter:SaveData("FR.OrderWaitBind",{"F2015081409532833425"},180000,true) --保存数据
	print("保存结果:" .. tostring(ret))
end

function rev()
	local adapter = mq.MQAdapter("server0")
	local vec = base.StringVector()
	local ret = adapter:GetData("FR.WaitBindOrder",5,vec)  --获取数据
	print("接收数据开始")
	if(ret)then
		print("size:".. tostring(vec:size()))
		for i=0,vec:size()-1,1 do
			print("i:" .. ":" .. tostring(vec:get(i)))
		end
	else
		print("没有数据")
	end
	print("接收完成")
end


function get_list()
	print("取所有队列出来")
	local adapter = mq.MQAdapter("server0")
	local vec = base.StringVector()
	local status = adapter:All(vec)
	if(not status)then
		print("获取队列名称列表失败")
	end
	print("==========================队列列表============================")
	for i=0,vec:size()-1,1 do
		local name = vec:get(i)
		local count = adapter:Count(name)
		print(string.format("[%2s]%-40s数量:%s",i,tostring(name),tostring(count)))
	end
	print("============================完成==============================")
end
--删除
function Delete()
	local adapter = mq.MQAdapter("server0")
	local status = adapter:Delete("FR.OrderWaitNotify.b")
	print("删除结果:" .. tostring(status))
end

