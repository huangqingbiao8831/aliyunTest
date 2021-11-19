local http = require("socket.http")
local ltn12 = require("ltn12")
local cjson = require("cjson")
--local printTab = require("printtable")
local https = require 'ssl.https'
local inspect = require("inspect")
local md5 = require("md5")
--local base64 = require("base64")
--local evp = require("crypto.evp")
local sha1 = require ("sha1")

--local APPKEY="rKCHBLmYiFPuCQTS0HttLbUD"
--local APPSECRET="037dc446820ec143d1628c20146b9d34"
--[[
 处理流程：
   1、开始注册流程 对应接口为：aliyun_Voiceprint_Create_Register（），调用一次
   2、注册流程，对应接口为：aliyun_Voiceprint_Commit_register（），根据前一次的结果进行调用，需要调用三次。
   以上两个步骤是建立用户信息，在设计时采用一个注册流程控件完成，并提交目标用户的声纹采样，建立其声纹模型。
  
   3、开始对比声纹：
   4、比对声纹：
   使用中用到的库：
   1、md5： 采用luarocks install md5 命令进行下载。
   
  
--]]

function random(n, m)
    math.randomseed(os.clock()*math.random(1000000,90000000)+math.random(1000000,90000000))
    return math.random(n, m)
end

--[[
   产生随机字符串，输入参数是产生的位数。
--]]
function randomLetter(len)
    local rt = ""
    for i = 1, len, 1 do
        rt = rt..string.char(random(97,122))
    end
    return rt
end

--[[
 产生随机数字串，输入的是随机数字的长度。
--]]
function randomNumber(len)
    local rt = ""
    for i=1,len,1 do
        if i == 1 then
            rt = rt..random(1,9)
        else
            rt = rt..random(0,9)
        end
    end
    return rt
end

key = ""
function PrintTable(table , level)
  level = level or 1
  local indent = ""
  for i = 1, level do
    indent = indent.."  "
  end

  if key ~= "" then
    print(indent..key.." ".."=".." ".."{")
  else
    print(indent .. "{")
  end

  key = ""
  for k,v in pairs(table) do
     if type(v) == "table" then
        key = k
        PrintTable(v, level + 1)
     else
        local content = string.format("%s%s = %s", indent .. "  ",tostring(k), tostring(v))
      print(content)  
      end
  end
  print(indent .. "}")

end
--[[
   把十六进制的字符串，转化成二进制码流
--]]
function Bin2HexstrTransfer(hexStr)
	local s = ''
	for i = 1, string.len(hexStr) - 1, 2 do
		local doublebytestr = string.sub(hexStr, i, i+1);
		local n = tonumber(doublebytestr, 16);
		if 0 == n then
			--bytesfile:write('\00');
			s = s ..'\00'
		else
			--bytesfile:write(string.format("%c", n));
			s = s ..string.format("%c",n)
		end
	end
	return s
end

--base64编码表
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
--[[
二进制字节流编码成base64字符串
--]]
-- encoding
function base64Enc(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

--[[
对base64字符串转化成二进制字节流
--]]
-- decoding
function base64Dec(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

--[[
    主要是对请求body部分做md5加密，加密后再转换成base64格式，函数返回为base64字符串。
--]]
function aliyun_GetMd52Base64(encode_smss)
	if (nil == encode_smss) then
		return nil
	end
	--去掉字符串两侧的空格
	--local s = string.gsub(encode_smss, "^%s*(.-)%s*$", "%1")
	local md5_msg = md5.sumhexa(encode_smss)
	--print("md5:"..md5_msg)
	local base64_msg = base64Enc(Bin2HexstrTransfer(md5_msg))
	return base64_msg
end
--[[
   测试阿里的声纹验证接口，主要验证部分接口的调用过程。
   调用地址：
   http://green.cn-shanghai.aliyuncs.com/green/image/scan?clientInfo={%22userId%22:%22120234234%22,%22userNick%22:%22Mike%22,%22userType%22:%22others%22}
   预注册流程,即开始注册接口
   开始注册声纹，建立声纹用户信息。
   调用接口：/green/voice/auth/start/register
    接口调一次
--]]
function aliyun_Voiceprint_Create_Register()
	local res_url = "http://green.cn-shanghai.aliyuncs.com/green/voice/auth/start/register"
	local tt={}
	local request_str = [[{"userId":"8618913011709","userName":"test123"}]]
	local request_body = request_str
	local hmackey = "RqHN1RV0k5hiUvScFPatAcY2ZDLsIM"
	local keyId = "LTAIGbVicEUrai13"
	local random_str = randomLetter(20)
	print("random_str:"..random_str)
	local date_str = os.date("!%a, %d %b %Y %X GMT")
	local content_md5 = aliyun_GetMd52Base64(request_str)
	local xacs_header = "x-acs-signature-method:HMAC-SHA1\n" .."x-acs-signature-nonce:" ..random_str .."\n" .."x-acs-signature-version:1.0\n" .."x-acs-version:2018-05-09\n" .."/green/voice/auth/start/register" 
	local auth_str = "POST\napplication/json\n" ..content_md5.."\n".."application/json\n" ..date_str .."\n" ..xacs_header 
	print(auth_str)
	--local auth_siga = sha1.hmac("RqHN1RV0k5hiUvScFPatAcY2ZDLsIM",auth_str)
	local auth_siga = sha1.hmac(hmackey,auth_str)
	local auth_result = "acs" .." " ..keyId ..":" ..base64Enc(Bin2HexstrTransfer(auth_siga))
	print("Signature:" ..auth_result)
	
	local res1,code1,h1 = http.request {
		url = res_url,
		method = "POST",
		headers = {
			["Content-Type"] = "application/json",
			["Content-MD5"] = content_md5,
			["Accept"] = "application/json",
			["Date"] = date_str,
			["x-acs-version"] = "2018-05-09",
			["x-acs-signature-nonce"] = random_str,
			["x-acs-signature-version"] = "1.0",
			["x-acs-signature-method"] = "HMAC-SHA1",
			["Authorization"] = auth_result,
			["Content-Length"] = #request_body 
		},
		source = ltn12.source.string(request_body),
		sink = ltn12.sink.table(tt)
	}
	if (code1 == 200) then
		local nbody = table.concat(tt)
		local data = cjson.decode(nbody)
		--print(inspect(data))
		print(data["data"]["session"])
	end
	print(code1)
	print(inspect(tt))
end

--[[
      注册声纹，提交用户声纹模型。
	  调用接口：/green/voice/auth/register
	  接口掉三次
--]]

function aliyun_Voiceprint_Commit_register()
	
end

--[[
   开始比对声纹，建立待比对声纹用户信息。
   调用接口：/green/voice/auth/start/check
--]]
function aliyun_Voiceprint_Start_check()
   
end

--[[
   比对声纹，提交待比对声纹模型。
   调用接口：/green/voice/auth/check
--]]
function aliyun_Voiceprint_Auth_check()
  
end

--[[
   删除用户声纹模型。
   调用接口：/green/voice/auth/unregister
--]]
function aliyun_Voiceprint_Auth_Unregister()

end
--[[
   main function
--]]

aliyun_Voiceprint_Create_Register()


