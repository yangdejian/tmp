require "sys"
require "custom.common.xhttp"
require "xqstring"
require "xxml"

gasoline_card_save = {fields = "card_no,carrier_no,status,is_complete", encoding = "gbk"}
gasoline_card_save.grs_dbg = xdbg("grs_db")

gasoline_card_save.main = function(args)
	print("------------------保存加油卡信息------------------")
	print("1. 检查参数")
	gasoline_card_save.params = xtable.parse(args[2], 1)
	if(xobject.empty(gasoline_card_save.params, gasoline_card_save.fields)) then
		error(string.format("缺少参数.需传入:%s,已传入:%s", gasoline_card_save.fields, args[2]))
		return sys.error.param_miss
	end

	print("2. 获取加油卡省份编码")
	local result = gasoline_card_save.get_card_province_no()

	print("3. 保存数据")
	gasoline_card_save.params.expire_date = tostring(gasoline_card_save.params.is_complete) == "0" and 100 or 10
	local dbg_result = gasoline_card_save.grs_dbg:execute("gasoline_card.archive.save", gasoline_card_save.params)
	if(dbg_result.result.code ~= sys.error.success.code) then
		error("保存数据失败,输入参数:"..xtable.tojson(gasoline_card_save.params))
	end
	return dbg_result.result
end

gasoline_card_save.get_card_province_no = function()
	gasoline_card_save.params.province_no = string.sub(gasoline_card_save.params.card_no, 7, 8)
	if(gasoline_card_save.params.province_no == "86") then
		gasoline_card_save.params.province_no = string.sub(gasoline_card_save.params.card_no, 9, 10)
	end
	gasoline_card_save.params.province_name = gasoline_card_save.province_no_list[tostring(gasoline_card_save.params.province_no)] or ""
	return true
end


gasoline_card_save.province_no_list = {}
gasoline_card_save.province_no_list["11"] = "北京市"
gasoline_card_save.province_no_list["12"] = "天津市"
gasoline_card_save.province_no_list["13"] = "河北省"
gasoline_card_save.province_no_list["14"] = "山西省"
gasoline_card_save.province_no_list["15"] = "内蒙古自治区"
gasoline_card_save.province_no_list["21"] = "辽宁省"
gasoline_card_save.province_no_list["22"] = "吉林省"
gasoline_card_save.province_no_list["23"] = "黑龙江省"
gasoline_card_save.province_no_list["31"] = "上海市"
gasoline_card_save.province_no_list["32"] = "江苏省"
gasoline_card_save.province_no_list["33"] = "浙江省"
gasoline_card_save.province_no_list["34"] = "安徽省"
gasoline_card_save.province_no_list["35"] = "福建省"
gasoline_card_save.province_no_list["36"] = "江西省"
gasoline_card_save.province_no_list["37"] = "山东省"
gasoline_card_save.province_no_list["41"] = "河南省"
gasoline_card_save.province_no_list["42"] = "湖北省"
gasoline_card_save.province_no_list["43"] = "湖南省"
gasoline_card_save.province_no_list["44"] = "广东省"
gasoline_card_save.province_no_list["45"] = "广西省"
gasoline_card_save.province_no_list["46"] = "海南省"
gasoline_card_save.province_no_list["50"] = "重庆市"
gasoline_card_save.province_no_list["51"] = "四川省"
gasoline_card_save.province_no_list["52"] = "贵州省"
gasoline_card_save.province_no_list["53"] = "云南省"
gasoline_card_save.province_no_list["54"] = "西藏自治区"
gasoline_card_save.province_no_list["61"] = "陕西省"
gasoline_card_save.province_no_list["62"] = "甘肃省"
gasoline_card_save.province_no_list["63"] = "青海省"
gasoline_card_save.province_no_list["64"] = "宁夏自治区"
gasoline_card_save.province_no_list["65"] = "新疆自治区"
gasoline_card_save.province_no_list["90"] = "深圳市"
gasoline_card_save.province_no_list["91"] = "北京龙禹"

return gasoline_card_save
