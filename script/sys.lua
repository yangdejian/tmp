
local __m_package_path = package.path
local path=[[../bin/lua/custom/common/xlib]]
package.path = string.format('%s;%s/?.lua;%s/?.luac;%s/?.dll',
	__m_package_path, path,path,path)

error = logger.error
debug = logger.debug

require 'custom.common.utils'
require "xstring"
require "xjson"
require "xtable"
require "xnumber"
require "xdate"
require "xdbg"
require "xmq"
require "xobject"
require "xutility"

sys = {}
sys.error = require "error_code"
sys.monitor = require "lib.monitorlib"
sys.open_monitor = true
sys.monitor_store_number = 10
sys.monitor_store_time = 1--µ•Œª√Î
sys.encrypt_encoding="utf-8"
sys.pwd_des="utf8/pkcs7/ecb"

sys.encrypt_pwd = function (en_key,pwd)
  local key =  string.sub(string.upper(xutility.md5.encrypt(en_key,sys.encrypt_encoding)),1,8)
  return base.DesEncryptS(pwd,key,sys.pwd_des)
end

sys.decrypt_pwd = function (en_key,pwd)
  local key =  string.sub(string.upper(xutility.md5.encrypt(en_key,sys.encrypt_encoding)),1,8)
  return base.DesDecryptS(pwd,key,sys.pwd_des)
end

return sys
