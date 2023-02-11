--[=[
	Address Generator
	  Generates a unique string for a given size.

	author: Sythivo
--]=]

local AddressCharacterSet = (table.create(59));

for i = 48, 57 do
	table.insert(AddressCharacterSet, string.char(i));
end
for i = 65, 90 do
	table.insert(AddressCharacterSet, string.char(i));
end
for i = 97, 122 do
	table.insert(AddressCharacterSet, string.char(i));
end
local AddressSetSize = #AddressCharacterSet;

--[[
	Generates a unique string.
	@param size characters in the string
	@param exclude strings to exclude
]]
local function createUniqueAddress(size : number, exclude : {string}?) : string
	local Address = (table.create(size));
	for i = 1, size do
		table.insert(Address, AddressCharacterSet[math.random(1, AddressSetSize)]);
	end
	Address = table.concat(Address);
	if (exclude and table.find(exclude, Address)) then
		return createUniqueAddress(size, exclude);
	end
	return Address;
end

return createUniqueAddress;