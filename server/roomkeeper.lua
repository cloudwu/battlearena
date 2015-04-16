local snax = require "snax"

-- todo: we can use a gate pool
local host = "127.0.0.1"
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
	udpgate = snax.newservice("udpserver",host, port)
end
