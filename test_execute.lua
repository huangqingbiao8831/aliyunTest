local ret = os.execute();



if ret ~= 0 then
    print("the system shell is available, ret = "..ret.."\n\n")
else
    print("the system shell is not available, ret = "..ret.."\n\n")
end

local str = "curl -o hello.wav \"http://tsn.baidu.com/text2audio?tex=%E5%AF%B9%E4%B8%8D%E8%B5%B7%EF%BC%81%E6%B2%A1%E6%9C%89%E8%AF%86%E5%88%AB%E5%88%B0%E6%82%A8%E7%9A%84%E8%AF%AD%E9%9F%B3%EF%BC%8C%E8%AF%B7%E6%8C%89%E9%94%AE%E6%A0%87%E6%B3%A8%EF%BC%8C%E6%8C%89%E9%94%AE%E4%B8%80%E4%BC%9A%E8%AE%AE%E6%9C%8D%E5%8A%A1%EF%BC%8C%E6%8C%89%E9%94%AE%E4%BA%8C%E6%8E%A8%E9%94%80%E6%88%BF%E4%BA%A7%E6%9C%8D%E5%8A%A1%EF%BC%8C%E6%8C%89%E9%94%AE%E4%B8%89%E6%9F%A5%E8%B4%A6%E5%8D%95%E6%9C%8D%E5%8A%A1%EF%BC%81&lan=zh&cuid=111&ctp=1&aue=6&per=0&tok=25.fb1b1c6b8319235b3c76a9a217be4ae3.315360000.1843623481.282335-10455099&.wav\""

os.execute(str);
print("this is a test for os.execute\n");

local copyret = os.execute("copy " .."luatest.lua".. ",".."luatest.lua.bak")
print("copyret = "..copyret)

os.execute("pause");

