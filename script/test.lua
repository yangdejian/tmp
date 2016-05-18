
require 'sys'
require 'custom.common.wclient'

local comm = require 'utouu.comm'

function main()

	--local aa = [[{"id":2115,"name":"Ç¬å\ÇØ"}]]
	--local obj = xtable.parse(aa)
	--print('obj:'..xtable.tojson(obj))

	local http = wclient()
	local ret,err = utouu_comm.get_bonus_date(http,id)
	
end

--[[
	local aa = '\\'
	--local obj = xtable.parse(aa)
	print('obj:'..aa)
	print('len1:'..string.len(aa))
	print('len2:'..utfstrlen(aa))
	print(string.char(229,92))
	--string.gsub(aa,'')

	local x = {}
	for i=1,string.len(aa),1 do
	  	x[#x] = string.byte(aa,i)
	end

]]

function SubUTF8String(s, n)    
  local dropping = string.byte(s, n+1)    
  if not dropping then return s end    
  if dropping >= 128 and dropping < 192 then    
    return SubUTF8String(s, n-1)    
  end    
  return string.sub(s, 1, n)    
end  

function test_unit()
	local aa = [["Ç¬å\-ÇØ"]]
	local g = ''
	for i=1,string.len(aa),1 do
	  	g = g..string.byte(aa,i)..','
	end
	g = xstring.rtrim(g,',')
	print('xxx:'..'return string.char('..g..')')
	local stringEval = loadstring('return string.char('..g..')')
	return stringEval()
end

function utfstrlen(str)
local len = #str;
local left = len;
local cnt = 0;
local arr={0,0xc0,0xe0,0xf0,0xf8,0xfc};
while left ~= 0 do
local tmp=string.byte(str,-left);
local i=#arr;
while arr[i] do
if tmp>=arr[i] then left=left-i;break;end
i=i-1;
end
cnt=cnt+1;
end
return cnt;
end

function test1(xml)
	local content = [[<?xml version="1.0" encoding="UTF-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><soapenv:Body><ns1:refundResponse soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="http://tempuri.org/refund"><refundReturn xsi:type="xsd:string">1120</refundReturn></ns1:refundResponse></soapenv:Body></soapenv:Envelope>]]

	local new_content,total_hit = string.gsub(content,':','_')
	print('new_content:'..tostring(new_content))
	print('total_hit:'..tostring(total_hit))
	local is_ok = xml:load(new_content)
	print('is_ok:'..tostring(is_ok))
	local fault_code = xml:get("//soapenv_Envelope/soapenv_Body/soapenv_Fault/faultcode","innerText")
	local fault_msg = xml:get("//soapenv_Envelope/soapenv_Body/soapenv_Fault/faultstring","innerText")
	local err_code = xml:get("//soapenv_Envelope/soapenv_Body/ns1_refundResponse/refundReturn","innerText")

	print('fault_code:'..tostring(fault_code))
	print('fault_msg:'..tostring(fault_msg))
	print('err_code:'..tostring(err_code))
end


function test2(xml)
	local content = [[<?xml version="1.0" encoding="UTF-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
 <soapenv:Body>
  <soapenv:Fault>
   <faultcode xmlns:ns1="http://xml.apache.org/axis/">ns1:Client.NoSOAPAction</faultcode>
   <faultstring>no SOAPAction header!</faultstring>
   <detail>
    <ns2:hostname xmlns:ns2="http://xml.apache.org/axis/">bestpay_wg72</ns2:hostname>
   </detail>
  </soapenv:Fault>
 </soapenv:Body>
</soapenv:Envelope>]]

	local new_content,total_hit = string.gsub(content,':','_')
	print('new_content:'..tostring(new_content))
	print('total_hit:'..tostring(total_hit))
	local is_ok = xml:load(new_content)
	print('is_ok:'..tostring(is_ok))
	local fault_code = xml:get("//soapenv_Envelope/soapenv_Body/soapenv_Fault/faultcode","innerText")
	local fault_msg = xml:get("//soapenv_Envelope/soapenv_Body/soapenv_Fault/faultstring","innerText")
	local err_code = xml:get("//soapenv_Envelope/soapenv_Body/ns1_refundresponse/refundreturn","innerText")

	print('fault_code:'..tostring(fault_code))
	print('fault_msg:'..tostring(fault_msg))
	print('err_code:'..tostring(err_code))

end