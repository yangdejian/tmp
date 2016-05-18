require "bit"

zsh_encryptlib = {}

---≥‰÷µø®√‹¬Îº”√‹
zsh_encryptlib.recharge_card_pwd_encrypt = function(card_pwd)
	local str = ""
	for i=1,#card_pwd,1 do
		local b = string.byte(string.sub(card_pwd, i, i))
		local s = string.format("%02x",bit.bxor(b,158))
		if(#s == 1) then
			str = str.."0"
		end
		str = str..s
	end
	return str
end


return zsh_encryptlib

