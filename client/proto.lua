local sproto = require "sproto"

local function loadproto()
	local f = assert(io.open "proto/lobby.sproto")
	local proto = f:read "a"
	f:close()
	return sproto.parse(proto)
end

local P = assert(loadproto())

local proto = {}

function proto.request(type, obj)
	local data , tag = P:request_encode(type,obj)
	return sproto.pack(string.pack("<I4",tag) .. data), tag
end

function proto.response(type, blob)
	local data = sproto.unpack(blob)
	return P:response_decode(type, data)
end

return proto
