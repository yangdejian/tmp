require "sys"
require "custom.common.recognizelib"

zsh_image_code = {net_file_name = "zhongshihua.net",
				net_recognize_value = 0.5,
				image_code_length = 5,
				download_image_code_limit = 3}
zsh_image_code.recognize = recognize()

--下载图片验证码并且识别
zsh_image_code.download = function(http, current_times)
	current_times = current_times or 0
	local input = {}
	input.url = "http://www.sinopecsales.com/gas/YanZhengMaServlet?"..os.time()
	input.net = zsh_image_code.net_file_name
	input.value = zsh_image_code.net_recognize_value
	input.len = zsh_image_code.image_code_length
	input.result = ""
	local result, msg = zsh_image_code.recognize:net_recognize(http, input)
	print("数字验证码识别结果:"..tostring(input.result))
	if(not(result) or input.result == nil) then
		error(msg)
		if(current_times < zsh_image_code.download_image_code_limit) then
			error(string.format("数字验证码识别失败,第%s次重试", current_times + 1))
			return zsh_image_code.download(http, current_times + 1)
		end
		return sys.error.delivery.number_code_error
	end
	--识别后需判断第一个和第三个是否是字符，第二个是号是运算符+或x,第四个是=号，第5个是w
	local a = tonumber(string.sub(input.result, 1, 1))
	local b = tonumber(string.sub(input.result, 3, 3))
	local d = string.sub(input.result, 2, 2)
	if(a == nil or b == nil) then
		error("数字验证码识别错误,需重新获取数字验证码")
		return sys.error.delivery.number_code_error
	end
	if(d == "+") then
		print("验证码计算结果:"..tostring(a + b))
		return sys.error.success, a + b
	elseif(d == "x") then
		print("验证码计算结果:"..tostring(a * b))
		return sys.error.success, a * b
	end
	return sys.error.delivery.number_code_error
end


return zsh_image_code
