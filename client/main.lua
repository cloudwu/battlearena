local socket = require "socket"
local proto = require "proto"
local timesync = require "timesync"

local IP = "127.0.0.1"

local fd = assert(socket.login {
	host = IP,
	port = 8001,
	server = "sample",
	user = "hello",
	pass = "password",
})


fd:connect(IP, 8888)

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

for i=1,1000 do
	timesync.sleep(1)
	if (i == 100 or i == 200 or i ==300 or i == 600) and udp then
		local gtime = timesync.globaltime()
		if gtime then
			print("send time", gtime)
			udp:send ("Hello" .. i .. ":1")
			udp:send ("Hello" .. i .. ":2")
			udp:send ("Hello" .. i .. ":3")
		end
	end
	if udp then
		local time, session, data = udp:recv()
		if time then
			print("UDP", "time=", time, "session =", session, "data=", data)
		end
	end
	dispatch(fd)
end
