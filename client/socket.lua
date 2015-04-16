local lsocket = require "lsocket"
local crypt = require "crypt"
local gettime = require("time").time

local socket = {}

local function closefd(self)
	if self.__fd then
		self.__fd:close()
		self.__fd = nil
	end
end

local function readline(self)
	local str = self.__read
	local nl = str:find("\n", 1, true)
	if nl then
		self.__read = str:sub(nl+1)
		return str:sub(1, nl-1)
	end

	while lsocket.select(self.__select_rd) do
		str = str .. self.__fd:recv()
		local nl = str:find("\n", 1, true)
		if nl then
			self.__read = str:sub(nl+1)
			return str:sub(1, nl-1)
		end
	end
end

local function writeline(self, text)
	text = text .. "\n"
	local n = #text
	local wt = self.__fd:send(text)
	if wt == nil then
		lsocket.select(nil, {self.__fd})
		wt = 0
	end
	local unsend = wt+1
	while wt < n do
		n = n - wt
		wt = assert(self.__fd:send(text:sub(unsend)))
		unsend = unsend + wt
	end
end

local function connect(addr, port)
	local fd = assert(lsocket.connect(addr, port))
	return {
		__fd = fd,
		login = login,
		__read = "",
		__select_rd = { fd },
	}
end

local function split_package(text)
	-- read whole package, todo
	local ok, str, offset = pcall(string.unpack, ">s2", text)
	if not ok then
		return
	end
	return str, text:sub(offset)
end

local function read_package(self, timeout)
	local result, text = split_package(self.__read)
	if result then
		self.__read = text
		return result
	end
-- wait for 1/1000 s, todo: remove it
	local r = lsocket.select(self.__select_rd,timeout)
	if r then
		local rd = self.__fd:recv()
		if rd then
			local text = self.__read .. rd
			local result, text = split_package(text)
			if result then
				self.__read = text
				return result
			else
				self.__read = text
				return false	-- block
			end
		else
			return rd
		end
	else
		return false
	end
end

local function auth(self, timeout)
	if self.__auth == nil then
		local handshake = self.__token .. self.__index
		self.__index = self.__index + 1
		local hmac = crypt.hmac_hash(self.__secret, handshake)
		local package = string.pack(">s2", handshake .. ":" .. crypt.base64encode(hmac))
		local n = #package
		local sb = self.__fd:send(package)
		if sb == false then
			return false
		end
		local unsend = sb + 1
		while sb < n do
			n = n - sb
			sb = self.__fd:send(package:sub(unsend))
			if sb == nil then
				return nil
			end
			if sb == false then
				sb = 0
			else
				unsend = unsend + sb
			end
		end
		self.__auth = false
		return false
	else
		-- recv response
		local pack = read_package(self,timeout)
		if pack then
			if pack ~= "200 OK" then
				self.__auth = nil
				closefd(self)
				error(pack)
			end
			self.__auth = true
		elseif pack == nil then
			-- disconnect
			self.__auth = nil
			return nil
		else
			-- block
			return false
		end
	end
	return true
end

local function send_request(self, data)
	local n = #data
	local sb = self.__fd:send(data)
	if not sb then
		closefd(self)
		return
	end
	local unsend = sb + 1
	while sb < n do
		n = n - sb
		local sb = self.__fd:send(v.data:sub(unsend))
		if not sb then
			closefd(self)
			return
		end
		unsend = unsend + sb
	end
end

local function recv_response(self, timeout)
	if self.__fd == nil then
		return nil
	end
	timeout = timeout or 0
	if not self.__auth then
		local ret = auth(self, timeout)
		if not ret then
			return ret
		end
		for _, v in ipairs(self.__request) do
			send_request(self, v.data)
			if not self.__fd then
				return nil
			end
		end
	end
	local v = read_package(self,timeout)
	if not v then
		return v
	end
	local size = #v - 5
	local content, ok, session = string.unpack("c"..tostring(size).."B>I4", v)
	for k,v in ipairs(self.__request) do
		if v.session == session then
			local cb = v.callback
			table.remove(self.__request, k)
			return cb, ok~=0, content
		end
	end
	error("Invalid session " .. session)

	return cb, ok~=0, content
end

local function connect_gameserver(self, addr, port)
	self.__fd = assert(lsocket.connect(addr, port))
	self.login = nil
	self.dispatch = recv_response
	self.__host = addr
	self.__port = port
	self.__read = ""
	self.__select_rd[1] = self.__fd
	self.__request = {}
	self.__auth = nil
	self.__index = 1
	self.__session = 1
end

local function reconnect_gameserver(self)
	closefd(self)
	self.__fd = assert(lsocket.connect(self.__host, self.__port))
	self.__read = ""
	self.__select_rd[1] = self.__fd
	self.__auth = nil
	self.__index = self.__index + 1
end

local function request_gameserver(self, req, callback)
	local session = self.__session
	local r = {
		session = session,
		data = string.pack(">I2", #req + 4)..req..string.pack(">I4", session),
		callback = assert(callback),
	}
	table.insert(self.__request, r)
	self.__session = session + 1
	if self.__auth then
		send_request(self, r.data)
	end
end

function socket.login(token)
	local self = connect(token.host, token.port)
	local challenge = crypt.base64decode(readline(self))
	local clientkey = crypt.randomkey()
	writeline(self, crypt.base64encode(crypt.dhexchange(clientkey)))
	local secret = crypt.dhsecret(crypt.base64decode(readline(self)), clientkey)

	local hmac = crypt.hmac64(challenge, secret)
	writeline(self, crypt.base64encode(hmac))

	local function encode_token(token)
		return string.format("%s@%s:%s",
			crypt.base64encode(token.user),
			crypt.base64encode(token.server),
			crypt.base64encode(token.pass))
	end

	local etoken = crypt.desencode(secret, encode_token(token))
	local b = crypt.base64encode(etoken)
	writeline(self, crypt.base64encode(etoken))

	local result = readline(self)
	local code = tonumber(string.sub(result, 1, 3))
	closefd(self)
	if code == 200 then
		self.__secret = secret
		local subid = crypt.base64decode(string.sub(result, 5))
		self.__token = string.format("%s@%s#%s:", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid))
		crypt.base64decode(string.sub(result, 5))
		self.secret = secret
		self.connect = connect_gameserver
		self.request = request_gameserver
		self.reconnect = reconnect_gameserver
		return self
	else
		error(string.sub(result, 5))
	end
end

local function udp_sync(self)
	local now = gettime()
	local data = string.pack("<IIH", self.__session, now, 0xffff)
	data = crypt.hmac_hash(self.__secret, data) .. data
	self.__fd:send(data)
end

local function udp_send(self, data)
	assert(self.__lag, "sync first")
	data = string.pack("<IIH", self.__session, self.__servertime + gettime(), self.__lag) .. data
	data = crypt.hmac_hash(self.__secret, data) .. data
	self.__fd:send(data)
end

local function udp_recv(self)
	local data = self.__fd:recv()
	if data then
		local session, time, lag = string.unpack("<IIH", data)
		local now = gettime()
		if lag == 0xffff then
			local req_time = string.unpack("<I", data, 11)
			self.__lag = (now - req_time) // 2
			self.__servertime = time + self.__lag - now
			return time + self.__lag, self.__lag
		else
			local server_time = time + lag + self.__lag
			local local_time = self.__servertime + now
			local diff = local_time - server_time
			if diff > 0 then
				-- if local_time > server_time,  then
				--     1. lag of this time is great than self.__lag
				--  or 2. self.__servertime should be larger, but in excess of self.__lag .
				local adjust = diff // 2
				if adjust > self.__lag then
					adjust = self.__lag
				end
				self.__servertime = self.__servertime + adjust
				self.__lag = self.__lag + diff - adjust
			elseif diff < 0 then
				local adjust = -diff // 2
				if adjust >= self.__lag then
					adjust = self.__lag // 2
				end
				self.__servertime = self.__servertime - adjust
				self.__lag = self.__lag  + diff + adjust
			end
			return now + self.__servertime, self.__lag, time, data:sub(11)
		end
	end
end

local function udp_time(self)
	local diff = self.__servertime
	if diff then
		return gettime() + diff
	end
end

function socket.udp(conf)
	local fd = assert(lsocket.connect("udp", conf.host, conf.port))
	return {
		__fd = fd,
		__secret = conf.secret,
		__session = conf.session,
		__lag = nil,
		__servertime = nil,
		send = udp_send,
		recv = udp_recv,
		sync = udp_sync,
		time = udp_time,
	}
end

return socket
