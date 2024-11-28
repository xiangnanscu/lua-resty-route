local route = require "resty.route"
local router = route.new()
local pjson = require "resty.repr"

-- router:use(function(self)

-- end)
local m2 = function(self)
  ngx.log(ngx.INFO, "开始处理请求: ", ngx.var.request_uri)
  local start = ngx.now()

  -- 调用下一个中间件
  self.yield()

  local duration = ngx.now() - start
  ngx.log(ngx.INFO, "请求处理完成, 耗时: ", duration, "秒")
end
ngx.log(ngx.INFO, "m2: ", tostring(m2))
router:use(m2)

local v1 = function(self)
  ngx.say("hello sleep world")
  ngx.sleep(1)
end
ngx.log(ngx.INFO, "view: ", tostring(v1))
router "/hello/:number" (v1)

router:get("/test", function(self)
  ngx.say("hello test")
end)

router:get("/test2", function(self)
  ngx.say("hello test")
end)

router:as "@home" (function(self) end)

local f1 = function(self)
end
ngx.log(ngx.INFO, "filter: ", tostring(f1))
router.filter "=/" (f1)
router.filter "/xxx" (f1)
router.filter "/xxx1" (f1)

ngx.log(ngx.INFO, "***************router done: ", pjson(router))
return router
