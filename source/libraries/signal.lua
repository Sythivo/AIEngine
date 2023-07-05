--[=[
	Signal
	  lightweight event module, lua context based, non-instance

	author: Sythivo
--]=]

export type Connection = {
	Connected : boolean;
	Disconnect : (self : Connection) -> ();
}

export type SignalClass<T... = ()> = {
	Fire : (self : SignalClass<T...>, T...) -> ();
	Wait : (self : SignalClass<T...>) -> T...;
	Once : (self : SignalClass<T...>, func: (T...) -> ()) -> Connection;
	Connect : (self : SignalClass<T...>, func: (T...) -> ()) -> Connection;
	ConnectParallel : (self : SignalClass<T...>, func: (T...) -> ()) -> Connection;
}

local Signal = ({});

Signal.prototype = {};
Signal.prototype.__index = Signal.prototype;

function Signal.new<T...>()
	return (setmetatable({
		listeners = ({});
		parallel_listeners = ({});
	}, Signal.prototype));
end

function Signal.prototype:Connect<T...>(func: (T...) -> ()) : Connection
	local listener = ({ func; true; });
	
	table.insert(self.listeners, listener);

	return ({
		Connected = true;
		Disconnect = (function(connection)
			listener[2] = (false);
			local id = table.find(self.listeners, listener);
			if (id) then
				table.remove(self.listeners, id);
				connection.Connected = false;
			end
		end);
	});
end

function Signal.prototype:Fire<T...>(...) : ()
	for _, parallel_listener in self.parallel_listeners do
		if (parallel_listener[2]) then
			task.spawn(function()
				task.desynchronize();
				parallel_listener[1]();
			end, ...)
		end
	end
	for _, listener in self.listeners do
		if (listener[2]) then
			task.spawn(listener[1], ...);
		end
	end
end

function Signal.prototype:ConnectParallel<T...>(func: (T...) -> ()) : Connection
	local listener = ({ func; true; });
	
	table.insert(self.parallel_listeners, listener);

	return ({
		Connected = true;
		Disconnect = (function(connection)
			listener[2] = (false);
			local id = table.find(self.parallel_listeners, listener);
			if (id) then
				table.remove(self.parallel_listeners, id);
				connection.Connected = false;
			end
		end);
	});
end

function Signal.prototype:Wait<T...>() : T...
	local thread = coroutine.running();
	local connection : Connection;
	connection = self:Connect(function(...)
		if (connection and connection.Connected) then
			connection:Disconnect();
		end
		coroutine.resume(thread, ...);
	end)
	return coroutine.yield();
end

function Signal.prototype:Once<T...>(func: (T...) -> ()) : Connection
	local connection : Connection;
	connection = self:Connect(function(... : T...)
		if (connection and connection.Connected) then
			connection:Disconnect();
		end
		func(...);
	end)
	return connection;
end

function Signal.prototype:Clone<T...>() : SignalClass<T...>
	return Signal.new()::SignalClass<T...>;
end

function Signal.prototype:Destroy()
	table.clear(self.parallel_listeners);
	table.clear(self.listeners);
	self.parallel_listeners = nil;
	self.listeners = nil;
end


return Signal;