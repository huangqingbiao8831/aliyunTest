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
function aliyun_Voiceprint_Create_Register(userId,username)
	local res_url = "http://green.cn-shanghai.aliyuncs.com/green/voice/auth/start/register"
	local tt={}
	local request_str = string.format("{\"userId\":\"%s\",\"userName\":\"%s\"}",userId,username)
	local request_body = request_str
	local hmackey = "RqHN1RV0k5hiUvScFPatAcY2ZDLsIM"
	local keyId = "LTAIGbVicEUrai13"
	local random_str = randomLetter(20)
	--print("random_str:"..random_str)
	local date_str = os.date("!%a, %d %b %Y %X GMT")
	local content_md5 = aliyun_GetMd52Base64(request_str)
	local xacs_header = "x-acs-signature-method:HMAC-SHA1\n" .."x-acs-signature-nonce:" ..random_str .."\n" .."x-acs-signature-version:1.0\n" .."x-acs-version:2018-05-09\n" .."/green/voice/auth/start/register" 
	local auth_str = "POST\napplication/json\n" ..content_md5.."\n".."application/json\n" ..date_str .."\n" ..xacs_header 
	--print(auth_str)
	local auth_siga = sha1.hmac("RqHN1RV0k5hiUvScFPatAcY2ZDLsIM",auth_str)
	local auth_result = "acs" .." " ..keyId ..":" ..base64Enc(Bin2HexstrTransfer(auth_siga))
	--print("Signature:" ..auth_result)
	
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
		--print("begin register:\n" ..inspect(data))
		return data,code1
	else
		--print("aliyun_Voiceprint_Create_Register error code:" ..code1)
		--print("aliyun_Voiceprint_Create_Register error response msg:\n" ..inspect(tt))
		return nil,code1
	end
end

--[[
  使用TTS获取返回值的语音文件，并转为base64字符串返回。
--]]
function getVoice2base64(content)
	if nil == content then
	    print("content is NULL,return nil")
	end
	local str = string.format("curl -s -o hello.wav \"http://tsn.baidu.com/text2audio?tex=%s&lan=zh&cuid=111&ctp=1&aue=6&per=0&tok=25.fb1b1c6b8319235b3c76a9a217be4ae3.315360000.1843623481.282335-10455099&.wav\"",content)
	print("commandline:" ..str)
	local ret = os.execute(str)
	os.execute("sleep " .. 5)
	--if ret == 0 then
	--	print("execute curl error")
	--	return nil
    --	end
	local fileIn,err = io.open("hello.wav","rb")
--	fileIn:seek("set",44)
--	local bin = fileIn:read("*a")
	local bin = fileIn:read("*all")
	local length = fileIn:seek("end")
	fileIn:close()
	local resbase64 = base64Enc(bin)
	os.remove("hello.wav")
	return resbase64
end

--[[
  读取录音文件，并生成base64字符串
  输入：录音文件
  输出：转化后的base64字符串
--]]
function FreeSwitchGetRecordfile2base64(filename)
	--后面需要增加文件的合法性等异常的验证，目前先假定文件是合法的。
	local fileIn,err = io.open(filename,"rb")
	--fileIn:seek("set",44)
	--local bin = fileIn:read("*a")
	local bin = fileIn:read("*all")
	local length = fileIn:seek("end")
	fileIn:close()
	local resbase64 = base64Enc(bin)
	--os.remove(filename)
	return resbase64
end
--[[
  根据用户读的content内容产生录音文件，然后读取录音文件并转化成base64格式上传。
  输入：要录音的字符串
  输出：产生要输出的录音base64编码字符串
--]]
function freeswitchRecordandgetVoiceBase64(content)
	--baidu_play_voice("请在语音播放结束后，复述所播放的数字,系统将录音采集您的语音进行声纹注册,按井号键结束录音")
	--baidu_play_voice(content)
	recording_dir = '/tmp/'
	filename = session:getVariable("caller_id_number") .."_" ..os.time() ..".wav"
	recording_filename = string.format('%s%s', recording_dir, filename)
	baidu_play_voice("开始录音")
	if session:ready() then
		--session:setInputCallback('onInputCBF', '');
		max_len_secs = 30
		silence_threshold = 60
		silence_secs = 2
		session:setVariable("playback_terminators", "#")
		test = session:recordFile(recording_filename, max_len_secs, silence_threshold, silence_secs);
		session:consoleLog("CRIT", "session:recordFile() = " .. test )
		return FreeSwitchGetRecordfile2base64(recording_filename)
	end
end

--[[
      注册声纹，提交用户声纹模型。
	  调用接口：/green/voice/auth/register
	  接口掉三次
--]]
function aliyun_Voiceprint_Commit_register(session,content)
	local res_url = "http://green.cn-shanghai.aliyuncs.com/green/voice/auth/register"
	local tt={}
	--local voice = getVoice2base64(content)
	local voice = freeswitchRecordandgetVoiceBase64(content)
	--print("content:" ..content)
	--print("session:" ..session)
	local request_str = string.format("{\"session\": \"%s\",\"content\": \"%s\", \"voice\": \"%s\"}",session,content,voice)
	local request_body = request_str
	local hmackey = "RqHN1RV0k5hiUvScFPatAcY2ZDLsIM"
	local keyId = "LTAIGbVicEUrai13"
	local random_str = randomLetter(20)
	--print("random_str:"..random_str)
	local date_str = os.date("!%a, %d %b %Y %X GMT")
	local content_md5 = aliyun_GetMd52Base64(request_str)
	local xacs_header = "x-acs-signature-method:HMAC-SHA1\n" .."x-acs-signature-nonce:" ..random_str .."\n" .."x-acs-signature-version:1.0\n" .."x-acs-version:2018-05-09\n" .."/green/voice/auth/register" 
	local auth_str = "POST\napplication/json\n" ..content_md5.."\n".."application/json\n" ..date_str .."\n" ..xacs_header 
	--print(auth_str)
	local auth_siga = sha1.hmac("RqHN1RV0k5hiUvScFPatAcY2ZDLsIM",auth_str)
	local auth_result = "acs" .." " ..keyId ..":" ..base64Enc(Bin2HexstrTransfer(auth_siga))
	--print("Signature:" ..auth_result)
	
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
		--print("start register:\n" ..inspect(data))
		return data,code1
	else
	    --print("aliyun_Voiceprint_Commit_register error code:\n" ..code1)
	    --print("aliyun_Voiceprint_Commit_register invoke error:\n" ..inspect(data))
    	return tt,code1
    end
end

--[[
   开始比对声纹，建立待比对声纹用户信息。
   调用接口：/green/voice/auth/start/check
--]]
function aliyun_Voiceprint_Start_check(userId,username)
	local res_url = "http://green.cn-shanghai.aliyuncs.com/green/voice/auth/start/check"
	local tt={}
	local request_str = string.format("{\"userId\":\"%s\",\"userName\":\"%s\"}",userId,username)
	local request_body = request_str
	local hmackey = "RqHN1RV0k5hiUvScFPatAcY2ZDLsIM"
	local keyId = "LTAIGbVicEUrai13"
	local random_str = randomLetter(20)
	--print("random_str:"..random_str)
	local date_str = os.date("!%a, %d %b %Y %X GMT")
	local content_md5 = aliyun_GetMd52Base64(request_str)
	local xacs_header = "x-acs-signature-method:HMAC-SHA1\n" .."x-acs-signature-nonce:" ..random_str .."\n" .."x-acs-signature-version:1.0\n" .."x-acs-version:2018-05-09\n" .."/green/voice/auth/start/check" 
	local auth_str = "POST\napplication/json\n" ..content_md5.."\n".."application/json\n" ..date_str .."\n" ..xacs_header 
	--print(auth_str)
	local auth_siga = sha1.hmac("RqHN1RV0k5hiUvScFPatAcY2ZDLsIM",auth_str)
	local auth_result = "acs" .." " ..keyId ..":" ..base64Enc(Bin2HexstrTransfer(auth_siga))
	--print("Signature:" ..auth_result)
	
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
		--print("begin voicePrint check:\n" ..inspect(data))
		return data,code1
	else
		--print("aliyun_Voiceprint_Start_check error code:" ..code1)
		--print("aliyun_Voiceprint_Start_check error response msg:\n" ..inspect(tt))
		return tt,code1
	end
end

--[[
   比对声纹，提交待比对声纹模型。
   调用接口：/green/voice/auth/check
--]]
function aliyun_Voiceprint_Auth_check(userId,username,content)
	local res_url = "http://green.cn-shanghai.aliyuncs.com/green/voice/auth/check"
	local tt={}
	--local voice = getVoice2base64(content)
	local voice = freeswitchRecordandgetVoiceBase64(content)
	--print("content:" ..content)
	local request_str = string.format("{\"userId\":\"%s\",\"userName\":\"%s\",\"content\": \"%s\", \"voice\": \"%s\"}",userId,username,content,voice)
	local request_body = request_str
	local hmackey = "RqHN1RV0k5hiUvScFPatAcY2ZDLsIM"
	local keyId = "LTAIGbVicEUrai13"
	local random_str = randomLetter(20)
	--print("random_str:"..random_str)
	local date_str = os.date("!%a, %d %b %Y %X GMT")
	local content_md5 = aliyun_GetMd52Base64(request_str)
	local xacs_header = "x-acs-signature-method:HMAC-SHA1\n" .."x-acs-signature-nonce:" ..random_str .."\n" .."x-acs-signature-version:1.0\n" .."x-acs-version:2018-05-09\n" .."/green/voice/auth/check" 
	local auth_str = "POST\napplication/json\n" ..content_md5.."\n".."application/json\n" ..date_str .."\n" ..xacs_header 
	--print(auth_str)
	local auth_siga = sha1.hmac("RqHN1RV0k5hiUvScFPatAcY2ZDLsIM",auth_str)
	local auth_result = "acs" .." " ..keyId ..":" ..base64Enc(Bin2HexstrTransfer(auth_siga))
	--print("Signature:" ..auth_result)
	
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
	--	print("start check compare:\n" ..inspect(data))
		return data,code1
	else
	    --print("aliyun_Voiceprint_Auth_check error code:\n" ..code1)
	    --print("aliyun_Voiceprint_Auth_check invoke error:\n" ..inspect(data))
    	return tt,code1
    end
  
end

--[[
   删除用户声纹模型。
   调用接口：/green/voice/auth/unregister
--]]
function aliyun_Voiceprint_Auth_Unregister(userId,username)
	local res_url = "http://green.cn-shanghai.aliyuncs.com/green/voice/auth/unregister"
	local tt={}
	local request_str = string.format("{\"userId\":\"%s\",\"userName\":\"%s\"}",userId,username)
	local request_body = request_str
	local hmackey = "RqHN1RV0k5hiUvScFPatAcY2ZDLsIM"
	local keyId = "LTAIGbVicEUrai13"
	local random_str = randomLetter(20)
	print("random_str:"..random_str)
	local date_str = os.date("!%a, %d %b %Y %X GMT")
	local content_md5 = aliyun_GetMd52Base64(request_str)
	local xacs_header = "x-acs-signature-method:HMAC-SHA1\n" .."x-acs-signature-nonce:" ..random_str .."\n" .."x-acs-signature-version:1.0\n" .."x-acs-version:2018-05-09\n" .."/green/voice/auth/unregister" 
	local auth_str = "POST\napplication/json\n" ..content_md5.."\n".."application/json\n" ..date_str .."\n" ..xacs_header 
	--print(auth_str)
	local auth_siga = sha1.hmac("RqHN1RV0k5hiUvScFPatAcY2ZDLsIM",auth_str)
	local auth_result = "acs" .." " ..keyId ..":" ..base64Enc(Bin2HexstrTransfer(auth_siga))
	--print("Signature:" ..auth_result)
	
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
		--print("begin register:\n" ..inspect(data))
		return data,code1
	else
		--print("aliyun_Voiceprint_Auth_Unregister error code:" ..code1)
		--print("aliyun_Voiceprint_Auth_Unregister error response msg:\n" ..inspect(tt))
		return tt,code1
	end
end


--tts播放
function baidu_play_voice(content)
	local token = freeswitch.getGlobalVariable("tok")
	local hello = string.format("http://tsn.baidu.com/text2audio?tex=%s&lan=zh&cuid=111&ctp=1&aue=6&per=0&tok=%s&.wav",content,token)
	session:streamFile(hello)
end

--tts播放数字
function baidu_play_digital(content)
	local token = freeswitch.getGlobalVariable("tok")
	local hello = string.format("http://tsn.baidu.com/text2audio?tex=%s&lan=zh&cuid=111&ctp=1&vol=15&spd=0&aue=6&per=0&tok=%s&.wav",content,token)
	session:streamFile(hello)
end

--freeswitch 做声纹采集端，获取文件并做注册流程
function freeswitch_voiceprint_register()
  --接通会话
  session:answer()
  --播放一个欢迎词
  baidu_play_voice("声纹注册需要采集声纹多次，请按照语音提示进行注册操作！")
  --发起开始注册
  local userId = session:getVariable("caller_id_number");
  freeswitch.consoleLog("CRIT", "主叫号码为以及声纹登记的userId：" ..userId)
  local username = "test123"
  local data,code = aliyun_Voiceprint_Create_Register(userId,username)
  if 200 ~= code then
     baidu_play_voice("开始注册消息没有收到200响应，注册流程结束")
	 return code
  else
     freeswitch.consoleLog("CRIT", "开始注册响应:\n" ..inspect(data))
	 local session = data["data"]["session"]
	 local content = data["data"]["content"]
	 freeswitch.consoleLog("CRIT", "开始注册消息回复，session:" ..session .."content:" ..content)
	 baidu_play_voice("开始采样，请根据语音提示操作，在提示开始录音后，复述您所听到的数字")
	 baidu_play_digital("数字为：" ..content)
	 local cr1_data,cr1_code = aliyun_Voiceprint_Commit_register(session,content) --发起第一次注册
	 if 200 ~= cr1_code then
		baidu_play_voice("第一次注册消息没有收到200响应，注册流程结束")
		return cr1_code
	 else 
		local cr1_session = cr1_data["data"]["session"]
		local cr1_content = cr1_data["data"]["content"]
		freeswitch.consoleLog("CRIT", "第一次注册：session:" ..cr1_session .."content:" ..cr1_content)
		freeswitch.consoleLog("CRIT", "第一次注册响应:\n" ..inspect(cr1_data))
		baidu_play_voice("请再次复述您将要听到的数字")
		baidu_play_digital("数字为：" ..cr1_content)
		local cr2_data,cr2_code = aliyun_Voiceprint_Commit_register(cr1_session,cr1_content) --发起第二次注册
		if 200 ~= cr2_code then
			baidu_play_voice("第二次声纹认证失败")
		else
			freeswitch.consoleLog("CRIT", "第二次次注册响应:\n" ..inspect(cr2_data))
			local cr2_session = cr2_data["data"]["session"]
			local cr2_content = cr2_data["data"]["content"]
			baidu_play_voice("再次复述您将要听到的数字")
			baidu_play_digital("数字为：" ..cr2_content)
			local cr3_data,cr3_code = aliyun_Voiceprint_Commit_register(cr2_session,cr2_content) --发起第三次注册
			if 200 ~= cr3_code then
				baidu_play_voice("第三次注册消息没有收到200响应，注册流程结束")
				freeswitch.consoleLog("CRIT", "第三次注册失败,session:" ..cr2_session .."content:" ..cr2_content)
				return cr3_code
			else
				freeswitch.consoleLog("CRIT", "第三次注册收到消息为:\n" ..inspect(cr3_data))
				local loopflag = 1
				local tmp_data = cr3_data
				while loopflag == 1 do
					local tmp_code = tmp_data["code"]
					if 288 == tmp_code then
						local tmp_session = tmp_data["data"]["session"]
						local tmp_content = tmp_data["data"]["content"]
						baidu_play_voice("再次复述您将要听到的数字")
						baidu_play_digital("数字为：" ..tmp_content)
						local h_data,h_code = aliyun_Voiceprint_Commit_register(tmp_session,tmp_content)
						tmp_data = h_data
					elseif 200 == tmp_code then
						baidu_play_voice("声纹登记成功，欢迎使用！")
						loopflag = 0
					else
					    baidu_play_voice("声纹登记失败，请重新登记！")
						loopflag = 0
					end
				end
			end
		end
	 end
  end
  return nil
end

--基于freeswitch的声纹验证过程
function freeswitch_VPCheck_procedure()
    session:answer()
	local userId = session:getVariable("caller_id_number");
	local username = "test123"
	baidu_play_voice("开始声纹认证流程，请根据语音提示进行操作！")
	local data,code = aliyun_Voiceprint_Start_check(userId,username)
	if code ~= 200 then
		baidu_play_voice("声纹验证请求消息，服务端非成功响应！")
		freeswitch.consoleLog("CRIT", "声纹认证请求，得到服务端非200响应，响应消息为：\n" ..inspect(data))
		return code
	else
		freeswitch.consoleLog("CRIT", "声纹认证请求消息获得响应消息为：\n" ..inspect(data))
		local content = data["data"]["content"]
		baidu_play_digital("数字为：" ..tostring(content))
		local data1,code1 = aliyun_Voiceprint_Auth_check(userId,username,content)
		if 200 ~= code1 then
			baidu_play_voice("声纹认证消息获得服务端非200响应回复，服务端失败")
			freeswitch.consoleLog("CRIT", "声纹认证获得响应消息为：\n" ..inspect(data1))
		else
			local tmp_code = data1["code"]
			if 200 == tmp_code then
				local rate = data1["data"]["rate"]
				baidu_play_voice("声纹认证系统，获得成功响应，近似度为百分之" ..rate)
			else
				baidu_play_voice("数字复述的不正确")
			end
			freeswitch.consoleLog("CRIT", "声纹认证响应消息为：\n" ..inspect(data1))
		end
		return code1
	end	
	return nil
end

--基于freeswitch的声纹注销过程
function freeswitch_VPDeregister_procedure()
	session:answer()
	local userId = session:getVariable("caller_id_number")
	local username = "test123"	
	local data,code = aliyun_Voiceprint_Auth_Unregister(userId,username)
	if 200 ~= code then
		baidu_play_voice("声纹注销，获得服务端非200响应")
		freeswitch.consoleLog("CRIT", "声纹注销消息失败响应为：\n" ..inspect(data))
	else
		baidu_play_voice("声纹注销获得成功响应,您先前的注册的声纹已经被注销了")
		freeswitch.consoleLog("CRIT", "声纹注销消息成功响应为：\n" ..inspect(data))
	end
	return code
end
--[[
   main procedure...
--]]

--注册流程
--freeswitch_voiceprint_register()
--认证流程
--freeswitch_VPCheck_procedure()
--注销流程
--freeswitch_VPDeregister_procedure()

if "1" == argv[1] then
	freeswitch_voiceprint_register() --注册流程
elseif "2" == argv[1] then
	freeswitch_VPCheck_procedure() --验证流程
elseif "3" == argv[1] then
	freeswitch_VPDeregister_procedure() --注销流程
else
	baidu_play_voice("按键错误，退出声纹验证系统")
end

