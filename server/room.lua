local skynet = require "skynet"
local snax = require "snax"

local gate

function accept.update(session, data)
	print("room ->", session, data)
	gate.post.post(session, "pong")
end

function init(udpserver)
	gate = snax.bind(udpserver, "udpserver")
	local session = gate.req.register(skynet.self(), "XXXX")

end

