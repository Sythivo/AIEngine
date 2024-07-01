--!strict
--[=[
	memory.lua
	  light-weight collection management and cleaner

	author: Sythivo
--]=]

local IDisposable_Keys = {
	'Dispose'; 'dispose';
};

local get_next = function(table : {[string]: any}, keys : {string})
	for _, key in keys do
		local value = table[key];
		if (value) then
			return value;
		end
	end
	return;
end;

local Memory = {};
Memory.__index = Memory;

local methods = {};
Memory.methods = methods;

function Memory.new()
	return setmetatable({
		collection = {}::{any};
	}, Memory);
end

function Memory.DisposeValue(value : any)
	local method = Memory.methods[typeof(value)];

	if (method and type(method) == "function") then
		local success, err = pcall(method, value);
		if (not success) then
			warn(`[Memory] Failed to CleanUp : {err}`)
		end
	end
end

local disposalFunction = Memory.DisposeValue;

--[[Methods]] do
	methods.table = function(table : {[any] : any})
		local IDisposable = get_next(table, IDisposable_Keys);
		if (type(IDisposable) == "function") then
			IDisposable(table)
			return;
		end

		for index, value in table do
			disposalFunction(value);
			table[index] = nil;
		end
	end;
	methods.Instance = function(Instance : Instance)
		if (Instance:IsA("Tween")) then
			Instance:Cancel();
		end
		Instance:Destroy();
	end;
	methods.RBXScriptConnection = function(RBXScriptConnection : RBXScriptConnection)
		RBXScriptConnection:Disconnect();
	end;
end

function Memory:Add<T...>(... : T...) : T...
	local pack = table.pack(...)::any;
	
	pack.n = nil;

	for _, value in pack do
		table.insert(self.collection, value);
	end

	return ...;
end

function Memory:RemoveAt(index : number): ()
	if (self.collection[index]) then
		self.collection[index] = nil
	end
end

function Memory:GetAt(index : number): any?
	return self.collection[index];
end

function Memory:GetIndex(value : any): number
	for index, v in self.collection do
		if (v == value) then
			return index;
		end
	end
	return -1;
end

function Memory:DisposeAt(index : number?)
	if (index and self.collection[index]) then
		disposalFunction(self.collection[index]);
		table.remove(self.collection, index);
	end
end

function Memory:Dispose()
	for i = #self.collection, 1, -1 do
		local value = self.collection[i];
		disposalFunction(value);
		table.remove(self.collection, i);
	end
end

return Memory;