
require 'sys'
require "custom.common.xhttp"
--require 'sqlite3'
--require "CLRPackage"
--require 'lib4net'

--import('System.Data')
--import('System.Data.SQLite')


function main()  

	print("Hello!1111")

    --DRIVER=SQLite3 ODBC Driver;

    local connstr=[=[Provider=sqlserver;Data Source=E:\sqlite3\test.db;Version=3;FailIfMissing=false;User Id=api;password=123456;]=]
    local sqlitedb = db.DbAdapter(connstr)

    local sql = 'select * from person'
    local dt = sqlitedb:ExecuteQuery(sql,{})
    
    --local tb=cdb:get_data_table("select * from v_user")//查询数据
    

	--[[local constr = [=[Data Source=E:\sqlite3\test.db;Pooling=true;FailIfMissing=false]=]
	local pay_db = luanet.Lib4Net.Scripts.DB.db('System.Data.SQLite',constr)
	local db_ret = pay_db:scalar('select * from person')
	print('db_ret:'..tostring(db_ret))]]
end
