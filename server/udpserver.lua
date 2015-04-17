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
	4 bytes localtime
	4 bytes eventtime		-- if event time is ff ff ff ff , time sync
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
		lastevent = nil,
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

local function timesync(session, localtime, from)
	-- return globaltime .. localtime .. eventtime .. session , eventtime = 0xffffffff
	local now = skynet.now()
	socket.sendto(U, from, string.pack("<IIII", now, localtime, 0xffffffff, session))
end

local function udpdispatch(str, from)
	local localtime, eventtime, session = string.unpack("<III", str, 9)
	local s = S[session]
	if s then
		if s.address ~= from then
			if crypt.hmac_hash(s.key, str:sub(9)) ~= str:sub(1,8) then
				snax.printf("Invalid signature of session %d from %s", session, socket.udp_address(from))
				return
			end
			s.address = from
		end
		if eventtime == 0xffffffff then
			return timesync(session, localtime, from)
		end
		s.time = skynet.now()
		-- NOTICE: after 497 days, the time will rewind
		if s.time > eventtime + timeout then
			snax.printf("The package is delay %f sec", (s.time - eventtime)/100)
			return
		elseif eventtime > s.time then
			-- drop this package, and force time sync
			return timesync(session, localtime, from)
		elseif s.lastevent and eventtime < s.lastevent then
			-- drop older event
			return
		end
		s.lastevent = eventtime
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


