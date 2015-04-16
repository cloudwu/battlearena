local socket = require "socket"
local proto = require "proto"
local time = require "time"

local fd = assert(socket.login {
	host = "127.0.0.1",
	port = 8001,
	server = "sample",
	user = "hello",
	pass = "password",
})


fd:connect("127.0.0.1", 8888)

local function request(fd, type, obj, cb)
	local data, tag = proto.request(type, obj)
	local function callback(ok, msg)
		if ok then
			return cb(proto.response(tag, msg))
		else
			print("error:", msg)
		end
	end
	fd:request(data, callback)
end

local function dispatch(fd)
	local cb, ok, blob = fd:dispatch(0)
	if cb then
		cb(ok, blob)
	end
end

local udp

request(fd, "join", { room = 1 } , function(obj)
	obj.secret = fd.secret
	udp = socket.udp(obj)
	udp:sync()
end)

for i=1,200 do
	time.sleep(1)
	if i==10 then
		udp:send "Hello"
	end
	if udp then
		local time, lag, etime, data = udp:recv()
		if time then
			print("UDP", time, lag, etime, data)
		end
	end
	dispatch(fd)
end
