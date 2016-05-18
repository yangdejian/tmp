
require 'sys'
require "xqstring"
require "custom.common.xhttp"




function main()

	lufu()

end

function lufu()

	local coopid = 'grsJd'
    local key = sys.decrypt_pwd('grsJd','AB24A47005EB1908CBE0537E72C271B68067976F599B7FB009954526690A0927C78F2383A06BD33C')
    print('key:'..tostring(key))
    print(string.len(key))
    local face = 30
    local ordernum = 1
    local now_str = os.date('%Y%m%d%H%M%S',os.time())
    print('now:'..now_str)

	local q = xqstring:new()
    q:add("orderNo", "YY"..now_str)
    q:add("coopId", coopid)
    q:add("productStandard", face)
    q:add("orderNum", ordernum)
    q:add("totalStandard", face*ordernum)
    -- 1000115100001625922(杨哥)
    -- 1000113300007265694(副卡)
    q:add("rechargeAccount", "1000113300007265694") 
    q:add("timestamp", now_str)
    q:add("notifyUrl", "http://192.168.101.139:9999/t/order/notify")
    q:sort()

    local raw = key..q:make({kvc="",sc="",req=true,ckey=true,encoding="gbk"})..key
    print('raw:'..raw)
    local sign = xutility.md5.encrypt(raw,'gbk')
    q:add("sign", sign)

    local http = xhttp()

    local post_data = q:make({kvc="=",sc="&",req=true,ckey=true,encoding="gbk"})
    local url = 'http://192.168.101.139:8888/order/request?'..post_data
    print('url:'..url)
    local content = http:get(url,"gbk")
    print('content:'..tostring(content))

end
