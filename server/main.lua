local skynet = require "skynet"
local snax = require "snax"

skynet.start(function()
	skynet.newservice("console")
	skynet.newservice("debug_console",8000)

--	local udp = snax.newservice("udpserver","127.0.0.1", 9999)
--	local room = snax.newservice("room", udp.handle)

	local loginserver = skynet.newservice("logind")
	local gate = skynet.newservice("gated", loginserver)

	skynet.call(gate, "lua", "open" , {
		address = skynet.getenv "gate_address",
		port = tonumber(skynet.getenv "gate_port"),
		maxclient = tonumber(skynet.getenv "max_client"),
		servername = skynet.getenv "gate_name",
	})


	skynet.exit()
end)


