local skynet = require "skynet"
local socket = require "socket"
local crypt = require "crypt"
local snax = require "snax"

local U
local S = {}
local SESSION = 0
local timeout = 10 * 60 * 100	-- 10 mins

--[[
	8 bytes hmac   crypt.hmac_hash(key, session .. data)
	4 bytes session
	padding data
]]

function response.register(service, key)
	SESSION = (SESSION + 1) & 0xffffffff
	S[SESSION] = {
		session = SESSION,
		key = key,
		room = snax.bind(service, "room"),
		address = nil,
		time = skynet.now(),
	}
	return SESSION
end

function response.unregister(session)
	S[session] = nil
end

function accept.post(session, data)
	local s = S[session]
	if s and s.address then
		socket.sendto(U, s.address, data)
	else
		snax.printf("Session is invalid %d", session)
	end
end

local function udpdispatch(str, from)
	local session = string.unpack("<L", str, 9)
	local s = S[session]
	if s then
		if s.address ~= from then
			if crypt.hmac_hash(s.key, str:sub(9)) ~= str:sub(1,8) then
				snax.printf("Invalid signature of session %d from %s", session, socket.udp_address(from))
				return
			end
			s.address = from
		end
		s.time = skynet.now()
		s.room.post.update(str:sub(9))
	else
		snax.printf("Invalid session %d from %s" , session, socket.udp_address(from))
	end
end

local function keepalive()
	-- trash session after no package last 10 mins (timeout)
	while true do
		local i = 0
		local ti = skynet.now()
		for session, s in pairs(S) do
			i=i+1
			if i > 100 then
				skynet.sleep(3000)	-- 30s
				ti = skynet.now()
				i = 1
			end
			if ti > s.time + timeout then
				S[session] = nil
			end
		end
		skynet.sleep(6000)	-- 1 min
	end
end

function init(host, port, address)
	U = socket.udp(udpdispatch, host, port)
	skynet.fork(keepalive)
end

function exit()
	if U then
		socket.close(U)
		U = nil
	end
end


