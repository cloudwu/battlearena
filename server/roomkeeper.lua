local snax = require "snax"
local host
local port = 9999
local udpgate
local rooms = {}

function response.apply(roomid)
	local room = rooms[roomid]
	if room == nil then
		room = snax.newservice("room", roomid, udpgate.handle)
		rooms[roomid] = room
	end
	return room.handle , host, port
end

-- todo : close room ?

function init()
	local skynet = require "skynet"
-- todo: we can use a gate pool
	host = skynet.getenv "udp_host"
	udpgate = snax.newservice("udpserver", "0.0.0.0", port)
end
