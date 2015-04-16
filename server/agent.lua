local snax = require "snax"
local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local sproto = require "sproto"

local roomkeeper
local gate, room
local U = {}
local proto

function response.login(source, uid, sid, secret)
	-- you may use secret to make a encrypted data stream
	roomkeeper = snax.queryservice "roomkeeper"
	snax.printf("%s is login", uid)
	gate = source
	U.userid = uid
	U.subid = sid
	U.key = secret
	-- you may load user data from database
end

local function logout()
	if gate then
		skynet.call(gate, "lua", "logout", U.userid, U.subid)
	end
	snax.exit()
end

function response.logout()
	-- NOTICE: The logout MAY be reentry
	snax.printf("%s is logout", U.userid)
	if room then
		room.req.leave(U.session)
	end
	logout()
end

function response.afk()
	-- the connection is broken, but the user may back
	snax.printf("AFK")
end

local function decode_proto(msg, sz)
	local blob = sproto.unpack(msg,sz)
	local type, offset = string.unpack("<I4", blob)
	local ret, name = proto:request_decode(type, blob:sub(5))
	return name, ret
end

local function encode_proto(name, obj)
	return sproto.pack(proto:response_encode(name, obj))
end


local client_request = {}

function client_request.join(msg)
	local handle, host, port = roomkeeper.req.apply(msg.room)
	local r = snax.bind(handle , "room")
	local session = assert(r.req.join(skynet.self(), U.key))
	U.session = session
	room = r
	return { session = session, host = host, port = port }
end

local function dispatch_client(_,_,name,msg)
	local f = assert(client_request[name])
	skynet.ret(encode_proto(name, f(msg)))
end

function init()
	skynet.register_protocol {
		name = "client",
		id = skynet.PTYPE_CLIENT,
		unpack = decode_proto,
	}

	-- todo: dispatch client message
	skynet.dispatch("client", dispatch_client)

	proto = sprotoloader.load(1)
end
