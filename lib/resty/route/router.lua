local encode       = require "cjson.safe".encode
local setmetatable = setmetatable
local create       = coroutine.create
local function resume_with_debug(co, ...)
  ngx.log(ngx.INFO, "RESUME: ", tostring(co))
  return coroutine.resume(co, ...)
end
local resume   = resume_with_debug

local status   = coroutine.status
local yield    = coroutine.yield
local pcall    = pcall
local type     = type
local next     = next
local ngx      = ngx
local log      = ngx.log
local redirect = ngx.redirect
local exit     = ngx.exit
local exec     = ngx.exec
local header   = ngx.header
local print    = ngx.print
local OK       = ngx.OK
local ERR      = ngx.ERR
local WARN     = ngx.WARN
local HTTP_200 = ngx.HTTP_OK
local HTTP_302 = ngx.HTTP_MOVED_TEMPORARILY
local HTTP_500 = ngx.HTTP_INTERNAL_SERVER_ERROR
local HTTP_404 = ngx.HTTP_NOT_FOUND
local function process(self, i, t, ok, ...)
  if ok then
    if i == 3 then return self:done(...) end
    if status(t) == "suspended" then
      local f = self[1]
      local n = f.n + 1
      f.n = n
      f[n] = t
    end
  else
    return self:fail(...)
  end
end
local function execute(self, i, t, ...)
  if t then process(self, i, t, resume(t, self.context, ...)) end
end
local function go(self, i)
  local a = self[i]
  local n = a.n
  for j = 1, n do
    execute(self, i, a[j](self.method, self.location))
  end
end
local function finish(self, code, func, ...)
  if code then
    local t = self[2]
    if next(t) then
      local f
      if t[code] then
        f = t[code]
      elseif code == OK and t.ok then
        f = t.ok
      elseif code == 499 and t.abort then
        f = t.abort
      elseif code >= 100 and code <= 199 and t.info then
        f = t.info
      elseif code >= 200 and code <= 299 and t.success then
        f = t.success
      elseif code >= 300 and code <= 399 and t.redirect then
        f = t.redirect
      elseif code >= 400 and code <= 499 and t["client error"] then
        f = t["client error"]
      elseif code >= 500 and code <= 599 and t["server error"] then
        f = t["server error"]
      elseif code >= 400 and code <= 599 and t.error then
        f = t.error
      elseif t[-1] then
        f = t[-1]
      end
      if f then
        ngx.log(ngx.ERR, "router:finish: ", code)
        local o, e = pcall(f, self.context, code)
        if not o then log(WARN, e) end
      end
    end
  end
  local f = self[1]
  local n = f.n
  ngx.log(ngx.INFO, "⬛️⬛️中间件after, start: ")
  for i = n, 1, -1 do
    local t = f[i]
    f[i] = nil
    f.n = i - 1
    local o, e = resume(t)
    if not o then log(WARN, e) end
  end
  ngx.log(ngx.INFO, "⬛️⬛️中间件after, end: ")
  return func(...)
end
local router = { yield = yield }
router.__index = router
function router.new(...)
  --1. suspended 协程 2. event listener 3. 视图函数  4. 过滤器 5. 中间件
  local self = setmetatable({ { n = 0 }, ... }, router)
  self.context = setmetatable({ route = self }, { __index = self })
  self.context.context = self.context
  return self
end

function router:redirect(uri, code)
  code = code or HTTP_302
  return finish(self, code, redirect, uri, code)
end

function router:exit(code)
  code = code or OK
  return finish(self, code, exit, code)
end

function router:exec(uri, args)
  return finish(self, OK, exec, uri, args)
end

function router:done()
  return self:exit(HTTP_200)
end

function router:abort()
  return self:exit(499)
end

function router:fail(error, code)
  if type(error) == "string" then
    log(ERR, error)
  end
  return self:exit(code or type(error) == "number" and error or HTTP_500)
end

function router:to(location, method)
  method = method or "get"
  self.location = location
  self.method = method
  if self[5] then -- middlewares
    ngx.log(ngx.INFO, "⬛️⬛️中间件before, start: ", location)
    go(self, 5)
    self[5] = nil
    ngx.log(ngx.INFO, "⬛️⬛️中间件before,  end: ", location)
  end
  ngx.log(ngx.INFO, "⬛️⬛️⬛️⬛️filter before,  start: ", location)
  go(self, 4) -- filters
  ngx.log(ngx.INFO, "⬛️⬛️⬛️⬛️filter before,  end: ", location)
  local named = self[3][location]
  if named then
    execute(self, 3, type(named) == "function" and create(named) or create(function(...) named(...) end))
  else
    ngx.log(ngx.INFO, "router:to: unnamed route: ", location)
    go(self, 3) -- views 函数
  end
  self:fail(HTTP_404)
end

function router:render(content, context)
  local template = self.context.template
  if template then
    template.render(content, context or self.context)
  else
    print(content)
  end
  return self
end

function router:json(data)
  if type(data) == "table" then
    data = encode(data)
  end
  header.content_type = "application/json"
  print(data)
  return self
end

return router
