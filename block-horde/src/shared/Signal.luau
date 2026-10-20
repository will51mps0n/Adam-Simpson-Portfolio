--!strict
-- Minimal signal for talking between modules on the same machine.

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable({} :: { handlers: { (...any) -> () } }, Signal))

function Signal.new(): Signal
	return setmetatable({ handlers = {} }, Signal)
end

-- Returns a function that disconnects the handler.
function Signal.Connect(self: Signal, handler: (...any) -> ()): () -> ()
	table.insert(self.handlers, handler)
	return function()
		local index = table.find(self.handlers, handler)
		if index then
			table.remove(self.handlers, index)
		end
	end
end

function Signal.Fire(self: Signal, ...: any)
	for _, handler in table.clone(self.handlers) do
		handler(...)
	end
end

return Signal
