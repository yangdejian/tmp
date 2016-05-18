
local _config_scan={}

--超时扫描时间下限(s)
_config_scan.timeout_flow_lower_limit=30*24*60*60

--一次性后补处理条数
_config_scan.handle_num_once=100

--单次处理累加超时时间(s)
_config_scan.flow_timeout_overlap=5*60

--后补监控枚举类型
_config_scan.scan_monitor_type={
  down_request  = 10,
  down_query  = 11,
  down_notify  = 12,
  down_pay  = 13,
  down_refund  = 15,
  up_delivery  = 20,
  up_query  = 21,
  up_bind  = 22,
  up_payment  = 23,
  up_refund  = 24,
  up_settle  = 25,
  checksheet  = 30,
  sms_send  = 40,
  data_sync  = 50,
  system_warning  = 60,
  flow_fix  = 70,
  system  = 90
}

--后补监控名称
_config_scan.scan_monitor_name="flow_fix"

return _config_scan
