local skynet = require "skynet"
local socket = require "socket"
local crypt = require "crypt"
local snax = require "snax"

local U
local S = {}
local SESSION = 0

function response.register(service, key)
	SESSION = SESSION + 1
	S[SESSION] = {
		session = SESSION,
		key = key,
		room = snax.bind(service, "room"),
		address = nil,
	}
	return SESSION
end

function accept.post(session, data)
	local s = S[session]
	if s and s.address then
		print("Send to ", session)
		socket.sendto(U, s.address, data)
	else
		print("post invalid ", session)
	end
end

local function udpdispatch(str, from)
	local session, index = string.unpack("<L", str)
	str = str:sub(index)
	local s = S[session]
	if s then
		s.address = from
		s.room.post.update(session, str)
	else
		print("Invalid session" , session)
	end
end

function init(host, port, address)
	U = socket.udp(udpdispatch, host, port)
end

function exit()
	if U then
		socket.close(U)
		U = nil
	end
end


