
require 'sys'
require 'custom.common.wclient'
require 'custom.common.xhtml'



function main()

	login()
end

function login()
	local domain = 'http://www.utcard.cn'
	local http = wclient()
	local html = xhtml()

    print('第一步：获取新的JessionID和ServerID')
	local trade_input = {
		method = "get",
		encoding = "UTF-8",
		content = "text",
		gzip = true,
		data = '',
		url = 'http://www.utcard.cn/trade-center',
		header = [[Host: www.utcard.cn
Connection: keep-alive
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.101 Safari/537.36
Accept-Encoding: gzip, deflate, sdch
Accept-Language: zh-CN,zh;q=0.8]]
	}

	clear_cookies(http)
	local content = http:query(trade_input, {}, 300)
	print('content:'..tostring(content))
	local cookies = http:get_all_cookie(domain)
	print('cookies:'..tostring(cookies))

    print('第二步：获取授权CODE')
	local request_input = {
		method = "get",
		encoding = "UTF-8",
		content = "text",
		gzip = true,
		data = '',
		url = 'http://www.utcard.cn/authorize',
		header = [[Host: www.utcard.cn
Connection: keep-alive
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.101 Safari/537.36
Referer: http://www.utcard.cn/guide
Accept-Encoding: gzip, deflate, sdch
Accept-Language: zh-CN,zh;q=0.8]]
	}

	--Cookie: Hm_lvt_d1465a68d33395555c8f3729ee367842=1462327916; td_cookie=3527515483; JSESSIONID=F3847B61DD00BF0A21F7D193BE1B07E8; bidding_ipo_time_sort=-1; SERVERID=a6cd409da1955d3d65c4e8a36419da60|1462853518|1462853515; CNZZDATA1257117916=1794138884-1452589768-http%253A%252F%252Fstock.utouu.com%252F%7C1462851228
	local content = http:query(request_input, {}, 300)
	print('content:'..tostring(content))
	local rep_sta = http:get_response_status()
	print('rep_sta:'..tostring(rep_sta))
	local rep_header =  http:get_response_headers()
	print('rep_header:'..xtable.tojson(rep_header))
	local location = http:get_response_Header('Location')
	print('location:'..xtable.tojson(location))
	local cookies = http:get_all_cookie(domain)
	print('cookies:'..tostring(cookies))

	local load_ret = html:load(content)
	print('load_ret:'..tostring(load_ret))
	if(not load_ret) then
		print('HTML加载失败!')
		return
	end

	local ret = html:getFormInputs('/html/body/div/form')
	print('ret:'..xtable.tojson(ret))
	if(xtable.empty(ret)) then
		print('没有找到登录表单!')
		return
	end

    print('第三步：请求登录接口')
	local user_name = '13051880135'
	local pwd = '198681'
	local post_data = string.format('username=%s&password=%s&oauth20_state=%s&authCode=%s&authCode=%s&authCode=%s',
		username,pwd,ret["oauth20_state"],ret["authCode"][1],ret["authCode"][2],ret["authCode"][3])
	print('post_data:'..tostring(post_data))




end

--- 获取账户列表
--- 同样的，返回html，表示没有登录
function query_account_info()
	local http = wclient()
	local request_input = {
		method = "post",
		encoding = "UTF-8",
		content = "text",
		gzip = true,
		data = '',
		url = 'http://www.utcard.cn/account/info',
		header = [[Host: www.utcard.cn
Connection: keep-alive
Accept: application/json, text/javascript, */*; q=0.01
Origin: http://www.utcard.cn
X-Requested-With: XMLHttpRequest
User-Agent: Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.101 Safari/537.36
Referer: http://www.utcard.cn/account
Accept-Encoding: gzip, deflate
Accept-Language: zh-CN,zh;q=0.8]]
	}

	local cookies = [[td_cookie=3523176925;JSESSIONID=F2A5E799C9A6CE422E0EE10E0549CF54;bidding_ipo_time_sort=-1;CNZZDATA1257117916=1794138884-1452589768-http%253A%252F%252Fstock.utouu.com%252F%7C1462845828;SERVERID=41dd1778c35414ce2f056f26d214729b|1462850145|1462848886]]
	local domain = 'http://www.utcard.cn'
	--http:set_cookie(domain, 'td_cookie=ydj_test; Expires=Tue, 15-Mar-2011 08:53:21 GMT; Path=/')
	--http:set_cookie(domain, 'bidding_ipo_time_sort=ydj_test; Expires=Tue, 15-Mar-2011 08:53:21 GMT; Path=/')
	--http:set_httponly_cookie(domain, 'JSESSIONID=000000; Expires=Tue, 15-Mar-2011 08:53:21 GMT; Path=/')
	--http:set_cookie(domain,'td_cookie=3523176925;path=/')
	--http:set_cookie(domain,'bidding_ipo_time_sort=-1;path=/')
	http:set_cookie(domain,'SERVERID=a6cd409da1955d3d65c4e8a36419da60|1462859209|1462859187;path=/')
	http:set_httponly_cookie(domain,'JSESSIONID=EAF2AA9E9DD1FED9E601045DCE4C25A5;path=/')

	local content = http:query(request_input, {}, 300)
	print('content:'..tostring(content))
end

--- sale：卖出
--- 返回HTML表示没有登录
function sale()
	local http = wclient()
	local post_data = 'unitCode=133369&unitId=942&salePrice=25&saleAmount=1'
	local request_input = {
		method = "post",
		encoding = "UTF-8",
		content = "text",
		gzip = true,
		data = post_data,
		url = 'http://www.utcard.cn/trade/sale',
		header = [[Host: www.utcard.cn
Connection: keep-alive
Accept: application/json, text/javascript, */*; q=0.01
Origin: http://www.utcard.cn
X-Requested-With: XMLHttpRequest
User-Agent: Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.101 Safari/537.36
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
Referer: http://www.utcard.cn/utcard/133369
Accept-Encoding: gzip, deflate
Accept-Language: zh-CN,zh;q=0.8]]
	}

	local cookies = [[td_cookie=3523176925;JSESSIONID=F2A5E799C9A6CE422E0EE10E0549CF54;bidding_ipo_time_sort=-1;CNZZDATA1257117916=1794138884-1452589768-http%253A%252F%252Fstock.utouu.com%252F%7C1462845828;SERVERID=41dd1778c35414ce2f056f26d214729b|1462850145|1462848886]]
	local domain = 'http://www.utcard.cn'

	http:set_cookie(domain, 'td_cookie=ydj_test; Expires=Tue, 15-Mar-2011 08:53:21 GMT; Path=/')
	http:set_cookie(domain, 'bidding_ipo_time_sort=ydj_test; Expires=Tue, 15-Mar-2011 08:53:21 GMT; Path=/')
	http:set_httponly_cookie(domain, 'JSESSIONID=000000; Expires=Tue, 15-Mar-2011 08:53:21 GMT; Path=/')
	--http:set_cookie(domain,'td_cookie=3523176925;path=/')
	--http:set_cookie(domain,'bidding_ipo_time_sort=-1;path=/')
	http:set_cookie(domain,'SERVERID=41dd1778c35414ce2f056f26d214729b|1462850145|1462848886;path=/')
	--http:set_httponly_cookie(domain,'JSESSIONID=F2A5E799C9A6CE422E0EE10E0549CF54;path=/')

	local content = http:query(request_input, {}, 300)
	print('content:'..tostring(content))
end

function clear_cookies(http)

	local domain = 'http://www.utcard.cn'

	http:set_cookie(domain,'SERVERID=000; Expires=Tue, 15-Mar-2011 08:53:21 GMT; Path=/')
	http:set_httponly_cookie(domain, 'JSESSIONID=000; Expires=Tue, 15-Mar-2011 08:53:21 GMT; Path=/')

end

function set_cookies(http,cookies)

	local domain = 'http://www.utcard.cn'
	local arr = xstring.split(cookies,';')
	for i,v in pairs(arr) do
		local cookie = xstring.trim(v)
		if(xstring.start_with(cookie,'SERVERID')) then
			http:set_cookie(domain,string.format("%s;Path=/", cookie))
		end
		if(xstring.start_with(cookie,'JSESSIONID')) then
			http:set_httponly_cookie(domain, string.format("%s;Path=/", cookie))
		end
	end

end




-------------------------------------------- 暂时不用 ------------------------------------------

function testLoadHTML()

	local html_str = [[<!DOCTYPE html>
<html>
<head>
	




 
<link type="image/x-icon" href="https://api.open.utouu.com/skin/images/favicon.ico" rel="shortcut icon" />

	<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
	<meta name="ms-https-connections-only" content="true"/>
	<base href="https://api.open.utouu.com/">
	<meta name="viewport" content="initial-scale=1,maximum-scale=1,minimum-scale=1,user-scalable=no">
	<meta charset="UTF-8">
	<title>UTOUU账号安全登录</title>
    <style>
        body{background: #fff;}
        /* reset */
        html,body,h1,h2,h3,h4,h5,h6,div,dl,dt,dd,ul,ol,li,p,blockquote,pre,hr,figure,table,caption,th,td,form,fieldset,legend,input,button,textarea,menu{margin:0;padding:0;}
        header,footer,section,article,aside,nav,address,figure,figcaption,menu,details{display:block;}
        table{border-collapse:collapse;border-spacing:0;}
        caption,th{text-align:left;font-weight:normal;}
        html,body,fieldset,img,iframe,abbr{border:0;}
        i,cite,em,var,address,dfn{font-style:normal;}
        [hidefocus],summary{outline:0;}
        li{list-style:none;}
        h1,h2,h3,h4,h5,h6,small{font-size:100%;font-weight: 500;}
        sup,sub{font-size:83%;}
        pre,code,kbd,samp{font-family:inherit;}
        q:before,q:after{content:none;}
        textarea{overflow:auto;resize:none;}
        label,summary{cursor:default;}
        a,button{cursor:pointer;color: #333;}
        strong,b{font-weight:bold;}
        del,ins,u,s,a,a:hover{text-decoration:none;}
        body{color:#333333;font: 14px/1.5 "Helvetica Neue","Microsoft Yahei",Helvetica,Arial,"Hiragino Sans GB","Heiti SC","WenQuanYi Micro Hei",sans-serif;display: block;-webkit-font-smoothing: antialiased;outline:0;background: #f5f5f5;}
        body:before,div:before {content: "";display: block;height: 0;line-height: 0;border:0;margin: 0;}

        /**  */
        .clearfix {clear: both;line-height: 0;border: 0;margin: 0;padding: 0;zoom: 1;}
        .clearbox {}
        .clearbox:after {display: block;content: "";height: 0;line-height: 0;padding: 0;margin: 0;clear: both;}
        .transition {-webkit-transition: all 0.5s;-moz-transition: all 0.5s;-ms-transition: all 0.5s;-o-transition: all 0.5s;transition: all 0.5s;}
        .fl {float: left;display: inline-block;}
        .fr {float: right;display: inline-block;}
        .tl {text-align: left;}
        .tr {text-align: right;}
        .tc {text-align:center;}
        .mc {margin: 0 auto;}
        .box-shadow {box-shadow: 0 2px 6px #dadada;}
        .warp_box{width: 1206px;margin: 0 auto;position: relative;}
        .fcolor_red{color: #f64747;}
        .fcolor_green{color: #00b16a;}
        .fcolor_orange{color: #ff6601;}
        .fcolor_pink{color: #ff3366;}
		.name_inp{outline: none;}

        /* login */
        .login_box{background: #fff;padding: 40px;width: 700px;margin: 0 auto;position: relative;}
        .login_plat{position: absolute;top: 40px;right: 40px;font-size:18px;}
        .login_box img{margin: 0 0 40px;display: block;}
        .login_box .fl{width: 270px;}
        .login_box .fr{padding-left:37px;width: 320px;border-left: 1px solid #e5e5e5;}
        .login_box .ipn_one{width: 260px;height: 40px;position: relative;margin-bottom: 10px;}
        .login_box .ipn_one i{width: 20px;height: 20px;position: absolute;right: 9px;top: 9px;cursor: pointer;display: none;}
        .login_box .fl input[type=text],.login_box .fl input[type=password]{width: 243px;height: 38px;line-height: 38px;border: 1px solid #ccc;padding-left: 15px;}
        .login_box .fl_b_box{text-align: right;margin-top: 40px;}
        .login_box .fl_b_box a{font-size: 14px;color: #666;padding: 0 0 0 17px;line-height: 18px;}
        .login_box .fl_b_box a:hover{color: #ff3366;}
        .login_box .fl_b_box a:first-child{padding-right: 17px;}
        .login_box .fl_b_box a:last-child{border-left: 1px solid #666;}
        .login_box .fr p{line-height: 40px;border-bottom: 1px solid #e5e5e5;}
        .login_box .fr p a{color: #4c9bff;}
        .login_box .fr p:last-child{border-bottom: 0;}
        .login_box .fr p:nth-last-child(2){border-bottom: 0;}
        .login_box .fr input{vertical-align: middle;margin-right: 5px;}
        .login_box .btn_login{display: block;width: 260px;height: 40px;line-height: 40px;background: #ff3366;color: #fff;text-align: center;border-radius: 2px;font-size:16px;border: 0;cursor: pointer;}
        .login_line{border-top:1px solid #e5e5e5;padding-top:30px;}
    </style>
</head>
<body>
<div class="login_box clearbox">
	<form name="loginForm" id="loginForm" action="https://api.open.utouu.com//oauth/grant" method="post">
	    <img src="https://api.open.utouu.com//skin/images/logo_login.png" width="200" height="69" />
	    <div class="login_plat">
            <a href="http://open.utouu.com" target="_blank">开放平台</a>
             |
            <a href="http://open.utouu.com/user-auth" target="_blank">授权管理</a>
        </div>
        <div class="login_line">
		    <div class="fl">
		        <div class="ipn_one">
		            <input type="text" class="name_inp"  name="username" placeholder="请输入UTOUU帐号" />
		            <i class="i_clear"></i>
		        </div>
		        <div class="ipn_one">
		            <input type="password" name="password" placeholder="请输入密码" />
		        </div>
		       <input type="submit" id="inputSubmit" class="btn_login" value="授权登录">
		        <!-- <input type="submit"  style="display: none"  id="inputSubmit" /> -->
		        <div style="text-align: right;margin-top: 5px;color: #ff3366;"> </div>
		        <div class="fl_b_box">
		            <a href="https://api.open.utouu.com//forget" target="_blank" >忘记密码？</a>
		            <a href="https://api.open.utouu.com//register" target="_blank" >注册新账号</a>
		        </div>
		    </div>
		    <div class="fr">
		       <!--  <p>该网站已有超过100000位用户使用有糖账号登录</p> -->
		        <p><span class="fcolor_pink">有糖卡</span> 将获得以下权限：
		         	<input type="hidden" name="oauth20_state" value="4681472b-9667-4084-8185-6be5967ba687" />
		        </p>
		        
		        	<p>
			         
			        	 <input type="checkbox" name="authCode" value="100011"  checked="checked" disabled="disabled" />获得您的昵称和头像
			        	 <input type="hidden" name="authCode" value="100011" />
			          
		         	</p>
		        
		        	<p>
			         
			        	 <input type="checkbox" name="authCode" value="10002"  checked="checked" disabled="disabled" />获取您的糖卡信息
			        	 <input type="hidden" name="authCode" value="10002" />
			          
		         	</p>
		        
		        	<p>
			         
			        	 <input type="checkbox" name="authCode" value="10003"  checked="checked" disabled="disabled" />获取您的资金信息
			        	 <input type="hidden" name="authCode" value="10003" />
			          
		         	</p>
		        
		        <p><br />授权后表明您已同意 <a href="http://open.utouu.com/agreement_chs" target="_blank" >有糖登录服务协议</a> </p>
		    </div>
	    </div>
   </form>
</div>
  <script type="text/javascript">
  	function formSubmit(){
   	 	document.getElementById("loginForm").submit()
    }
  </script>
</body>
</html>]]

	local html = xhtml()
	local load_ret = html:load(html_str)
	print('load_ret:'..tostring(load_ret))
	if(not load_ret) then
		print('HTML加载失败!')
		return
	end

	local ret = html:getFormInputs('/html/body/div/form')
	print('ret:'..xtable.tojson(ret))
end
