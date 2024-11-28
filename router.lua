local route = require "resty.route"
local router = route.new()
local pjson = require "resty.repr"


local f1 = function(self)

end
router.filter "=/kkkk" (f1)
router:use(function(self)
  ngx.log(ngx.INFO, "⬛️M1中间件start: ")
  -- 调用下一个中间件
  -- self.yield()
  ngx.log(ngx.INFO, "△M1中间件end: ")
end)
local m2 = function(self)
  ngx.log(ngx.INFO, "⬛️M2中间件start: ", ngx.var.request_uri)
  local start = ngx.now()

  -- 调用下一个中间件
  self.yield()

  local duration = ngx.now() - start
  ngx.log(ngx.INFO, "△M2中间件end: 耗时: ", duration, "秒")
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

router:get("/test3", function(self)
  ngx.say("hello test")
end)

-- router:as "@home" (function(self) end)
-- router:get "/" "@home"


ngx.log(ngx.INFO, "filter: ", tostring(f1))

-- router.filter "/xxx" (f1)
-- router.filter "/xxx1" (f1)
router:on(404, function(self) ngx.say('haha') end)
ngx.log(ngx.INFO, "***************router done: ", pjson(router), pjson(router[1]))
return router
