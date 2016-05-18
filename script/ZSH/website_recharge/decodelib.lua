require "bit"

zsh_decodelib = {}

---加油卡归属人名字解密
zsh_decodelib.card_holder_decode = function(input)
	local _keyStr = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
	local Rz1 = ""
	local lTHvBZPWD2, elVov3, bUpPmsYq4
	local VTCM5, NkwrAg6, Vk7, srp8
	local oszZez9 = 1
	input = string.sub(input, 2)
	input = string.match(input, "^[%w+/=]+")
	local r = {}
	while (oszZez9 <= #input) do
		VTCM5 = string.find(_keyStr, string.sub(input, oszZez9, oszZez9)) - 1
		oszZez9 = oszZez9 + 1
		NkwrAg6 = string.find(_keyStr, string.sub(input, oszZez9, oszZez9)) - 1
		oszZez9 = oszZez9 + 1
		Vk7 = string.find(_keyStr, string.sub(input, oszZez9, oszZez9)) - 1
		oszZez9 = oszZez9 + 1
		srp8 = string.find(_keyStr, string.sub(input, oszZez9, oszZez9)) - 1
		oszZez9 = oszZez9 + 1
		lTHvBZPWD2 = bit.bor(bit.blshift(VTCM5, 2), bit.brshift(NkwrAg6, 4))
		elVov3 = bit.bor(bit.blshift(bit.band(NkwrAg6, 15), 4), bit.brshift(Vk7, 2))
		bUpPmsYq4 = bit.bor(bit.blshift(bit.band(Vk7, 3), 6), srp8)
		table.insert(r, string.format("%c", lTHvBZPWD2))
		if(Vk7 ~= 64) then
			table.insert(r, string.format("%c", elVov3))
		end
		if(srp8 ~= 64) then
			table.insert(r, string.format("%c", bUpPmsYq4))
		end
	end
	return zsh_decodelib.__utf8_decode(table.concat(r, ""))
end

zsh_decodelib.__utf8_decode = function(utftext)
	local kmb1 = {}
	local N2, zM3, c2, c3 = 1
	while (N2 <= #utftext) do
		zM3 = string.byte(string.sub(utftext, N2, N2))
		if(zM3 < 128) then
			table.insert(kmb1, string.format("%c", zM3))
			N2 = N2 + 1
		elseif(zM3 > 191 and zM3 < 224) then
			c2 = string.byte(string.sub(utftext, N2 + 1, N2 + 1))
			table.insert(kmb1, string.format("%c", bit.bor(bit.blshift(bit.band(zM3, 31), 6), bit.band(c2, 63))))
			N2 = N2 + 2
		else
			c2 = string.byte(string.sub(utftext, N2 + 1, N2 + 1))
			c3 = string.byte(string.sub(utftext, N2 + 2, N2 + 2))
			table.insert(kmb1, zsh_decodelib.__from_char_code(bit.bor(bit.bor(bit.blshift(bit.band(zM3, 15), 12), bit.blshift(bit.band(c2, 63), 6)), bit.band(c3, 63))))
			N2 = N2 + 3
		end
	end
	return table.concat(kmb1, "")
end

zsh_decodelib.__from_char_code = function(data)
	return base.UnEscape("%u"..string.format("%x", data))
end


return zsh_decodelib
