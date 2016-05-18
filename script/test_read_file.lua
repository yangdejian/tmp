
require 'sys'



function main()

	local file = io.open([[..\LossGovr.txt]],"r")
	local ls={}
	local i=0
	for l in file:lines() do
		i=i+1
		ls[i]=l
	end
	file:close()
	
	for i,v in pairs(ls) do
		print(string.format('µÚ%sÐÐ:%s',i,v))
	end

	--[[print('Hello,World!')

	local real_key = sys.decrypt_pwd('jyk_njhc','5395111E60612F07C377C3466BED9EE3')
	print('real_key:'..real_key)

	local raw_key = 'ygryuihfde68716'
	local en_key = sys.encrypt_pwd('jyk_njhc',raw_key)
	print('en_key:'..en_key)
	print(string.len(en_key))]]

end
