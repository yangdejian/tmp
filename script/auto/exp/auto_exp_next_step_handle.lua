require "sys"
require "auto_mq_receiver"


function main(args)
	local script_name = args[1]
	auto_mq_receiver.main(script_name:match("/auto_(.-).lua"))
end
