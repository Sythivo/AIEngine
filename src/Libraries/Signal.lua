--!strict
--[=[
	Signal
	  lightweight event module, lua context based, non-instance

	author: Sythivo
--]=]

local Connection = {};
Connection.__index = Connection;

function Connection.new(callback : (...any) -> ...any)
	return setmetatable({
		Connected = true;
		Callback = callback;
	}, Connection);
end

function Connection:Disconnect()
	self.Connected = false;
end

table.freeze(Connection);

export type Connection = typeof(Connection.new(function() end));

export type SignalPrototype<T...> = {
	__index : SignalPrototype<T...>;
	Fire : (self : Signal<T...>, T...) -> ();
	Wait : (self : Signal<T...>) -> T...;
	Once : (self : Signal<T...>, func: (T...) -> ()) -> Connection;
	Connect : (self : Signal<T...>, func: (T...) -> ()) -> Connection;
	ConnectParallel : (self : Signal<T...>, func: (T...) -> ()) -> Connection;
}

export type Signal<T... = ()> = typeof(
	setmetatable(
		{connections={}::{Connection}; parallel_connections={}::{Connection}},
		{}::SignalPrototype<T...>
	)
);

local Signal = {};
Signal.__index = Signal;

function Signal.new<T...>() : Signal<T...>
	return setmetatable({
		connections = {}::{Connection};
		parallel_connections = {}::{Connection};
	}, Signal);
end

function Signal:Connect<T...>(func: (T...) -> ())
	local connection = Connection.new(func);
	
	table.insert(self.connections, connection);

	return connection;
end

function Signal:ConnectParallel<T...>(func: (T...) -> ())
	local connection = Connection.new(func);
	
	table.insert(self.parallel_connections, connection);

	return connection;
end

function Signal:Fire<T...>(...) : ()
	for _, connection in self.parallel_connections do
		if (connection.Connected) then
			task.spawn(function(...)
				task.desynchronize();
				connection.Callback(...);
			end, ...)
		end
	end
	for _, connection in self.connections do
		if (connection.Connected) then
			task.spawn(connection.Callback, ...);
		end
	end

	for i = #self.connections, 1, -1 do
		local connection = self.connections[i];
		if (not connection.Connected) then
			table.remove(self.connections, i);
		end
	end

	for i = #self.parallel_connections, 1, -1 do
		local connection = self.parallel_connections[i];
		if (not connection.Connected) then
			table.remove(self.parallel_connections, i);
		end
	end
end

function Signal:Wait<T...>() : T...
	local thread = coroutine.running();
	self:Once(function(...)
		coroutine.resume(thread, ...);
	end)
	return coroutine.yield();
end

function Signal:Once<T...>(func: (T...) -> ()) : Connection
	local connection;
	connection = self:Connect(function(... : T...)
		if (connection and connection.Connected) then
			connection:Disconnect();
		end
		func(...);
	end)
	return connection;
end

function Signal:Clone<T...>() : Signal<T...>
	return Signal.new();
end

function Signal:Destroy()
	table.clear(self.parallel_listeners);
	table.clear(self.listeners);
end

return table.freeze(Signal);