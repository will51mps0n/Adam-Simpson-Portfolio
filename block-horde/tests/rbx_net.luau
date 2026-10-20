-- Stand-in for Shared/Net: remotes that swallow everything sent through them.
local remote = {
	FireAllClients = function() end,
	FireClient = function() end,
}
return {
	event = function()
		return remote
	end,
	unreliable = function()
		return remote
	end,
}
