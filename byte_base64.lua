-- Lua 5.1+ base64 v3.0 (c) 2009 by Alex Kloss <alexthkloss@web.de>
-- licensed under the terms of the LGPL2

-- character table string
#!/usr/bin/env lua
-- Lua 5.1+ base64 v3.0 (c) 2009 by Alex Kloss <alexthkloss@web.de>
-- licensed under the terms of the LGPL2

-- character table string
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- encoding
function enc(data)
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

-- decoding
function dec(data)
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
只需要编解码部分就可以了，其它的不需要。
-- command line if not called as library
if (arg ~= nil) then
	local func = 'enc'
	for n,v in ipairs(arg) do
		if (n > 0) then
			if (v == "-h") then print "base64.lua [-e] [-d] text/data" break
			elseif (v == "-e") then func = 'enc'
			elseif (v == "-d") then func = 'dec'
			else print(_G[func](v)) end
		end
	end
else
	module('base64',package.seeall)
end

--]]
--[[
    完成把十六进制字符串转化成二进制数据
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

local s = "6c167b515c93ec7b782afe84bf989280"
local result = Bin2HexstrTransfer(s)
local  trans_res = enc(result)
print(trans_res)
