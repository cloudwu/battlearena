local snax = require "snax"
local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local sproto = require "sproto"

local gate
local userid, subid
local proto

function response.login(source, uid, sid, secret)
	-- you may use secret to make a encrypted data stream
	snax.printf("%s is login", uid)
	gate = source
	userid = uid
	subid = sid
	-- you may load user data from database
end

local function logout()
	if gate then
		skynet.call(gate, "lua", "logout", userid, subid)
	end
	snax.exit()
end

function response.logout()
	-- NOTICE: The logout MAY be reentry
	snax.printf("%s is logout", userid)
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

local function dispatch_client(_,_,name,msg)
	local sleep = math.random(100)
	snax.printf("Recv %s, sleep %d return",msg.what, sleep)
	skynet.sleep(sleep)
	skynet.ret(encode_proto(name, { sleep = sleep }))
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
