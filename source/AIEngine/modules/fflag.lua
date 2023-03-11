--[=[
	Fast Flag
	  A module to manage fast flags settings and access to experimental features.

	author: Sythivo
--]=]

type FlagInfo = {
	name : string;
	value : any;
	type : string;
};

type DEFINE_FLAG = <T>(self: FastFlag, name : string, value : T) -> ();
type FastFlag = {
	Flags : {[string]: FlagInfo};
	DEFINE : DEFINE_FLAG;
	SETFASTFLAG : DEFINE_FLAG;
	DUMP : (self : FastFlag) -> string;
};

local FastFlag = ({});

local createFlagInfo = function(name : string, value : any) : FlagInfo
	return ({
		name = name;
		value = value;
		type = typeof(value);
	});
end

function FastFlag:__index(key)
	local flag : FlagInfo? = self.Flags[key];
	if (flag) then
		return (flag.value);
	end
	return rawget(self, key) or rawget(FastFlag, key);
end

function FastFlag.new() : FastFlag
	local self = setmetatable({
		Flags = ({});
	}, FastFlag);

	return self;
end

function FastFlag:DEFINE(name : string, value : any)
	self.Flags[name] = createFlagInfo(name, value);
end

function FastFlag:SETFASTFLAG(name : string, value : any)
	return self:DEFINE(name, value);
end

function FastFlag:DUMP() : string
	local list = ({});
	for i, v in self.Flags do
		table.insert(list, ("%s: {default: %s, type: %s}"):format(i, v.value, v.type));
	end
	return table.concat(list, "\n");
end

return FastFlag;