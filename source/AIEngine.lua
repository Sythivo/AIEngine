--[=[
	AIEngine
	  AI Engine for Roblox

	author: Sythivo
--]=]

type AgentParamaters = {
	AgentRadius : number?;
	AgentHeight : number?;
	AgentCanJump : boolean?;
	Costs : {
		[string] : number;
	}?;
};

local RunService = game:GetService("RunService");
local PathfindingService = game:GetService("PathfindingService");

local libraries = script:WaitForChild("libraries");

local Debug = require(script:WaitForChild("debug"));
local Signal = require(libraries:WaitForChild("signal"));
local createUniqueAddress = require(script:WaitForChild("address"));

export type Signal<T... = ()> = Signal.SignalClass<T...>;

type Shared = {
	createUniqueAddress : (size : number, exclude : {string}?) -> string;
	createSignal : () -> Signal;
};

export type Mechanism = Shared & {
	Name : string?;
	AIState : number;
	OnHeartBeat : Signal<number>;
	OnStateChange : Signal<number>;
	OnLoaded : Signal;
	OnState : (self : Mechanism, State : number, Callback : (number) -> ()) -> Signal.Connection;
	WhileState : (self : Mechanism, State : number, Callback : (number) -> ()) -> Signal.Connection;
};

export type AI = Shared & {
	Debug : typeof(Debug.new());
	Mechanisms : {Mechanism};
	Character : Model;
	PathAgent : Path;
	State : number;
	Heatbeat : RBXScriptConnection;
	createMechanism : () -> Mechanism;
};

local AIEngine = ({});

--// AI Engine Prototype
AIEngine.prototype = ({});
function AIEngine.prototype:__index(key)
	local value = self.Isolated[key];
	if (value) then
		return (value);
	end
	return rawget(self, key) or rawget(AIEngine.prototype, key);
end
function AIEngine.prototype:__newindex(key, value)
	if (key == "State") then
		self:EmitState(value);
	else
		rawset(self.Isolated, key, value);
	end
end

--// Mechanism Prototype
AIEngine.mechanics_prototype = ({});
AIEngine.mechanics_prototype.__index = AIEngine.mechanics_prototype;

--[[
	Creates a new AI Engine
	@param character The character to control
	@param agent The pathfinding agent
]]
function AIEngine.new(character : Model, agent : AgentParamaters?) : AI
	local self = setmetatable({
		Isolated = ({}); --// Isolated variables, public
		Debug = Debug.new(); --// Debugging
		Mechanisms = ({}); --// List of mechanisms
		Character = character; --// Character
		PathAgent = PathfindingService:CreatePath(agent); --// Pathfinding agent
	}, AIEngine.prototype);

	self.State = -1; --// State of the AI, default: Unknown(-1)

	self.Heatbeat = RunService.Heartbeat:Connect(function(Step)
		for _, mechanism in self.Mechanisms do
			mechanism.OnHeartBeat:Fire(Step);
		end
	end);

	return self;
end

--[[
	Creates a new mechanism
]]
function AIEngine.createMechanism() : Mechanism
	local self = setmetatable({
		OnHeartBeat = Signal.new();
		OnStateChange = Signal.new();
		OnLoaded = Signal.new();
	}, AIEngine.mechanics_prototype);

	self.AIState = -1; --// State of the AI, default: Unknown(-1)

	return self;
end

AIEngine.prototype.createSignal = Signal.new;
AIEngine.prototype.createUniqueAddress = createUniqueAddress;
AIEngine.mechanics_prototype.createSignal = Signal.new;
AIEngine.mechanics_prototype.createUniqueAddress = createUniqueAddress;

--// AI Methods

function AIEngine.prototype:LoadMechanism(Mechanism : Mechanism)
	if (table.find(self.Mechanisms, Mechanism)) then
		warn("[AIEngine] Mechanism already loaded");
		return;
	end
	table.insert(self.Mechanisms, Mechanism);
	Mechanism.AIState = self.State;
	Mechanism.OnLoaded:Fire();
end

function AIEngine.prototype:EmitState(State : number)
	rawset(self.Isolated, "State", State);
	for _, mechanism in self.Mechanisms do
		mechanism.AIState = self.State;
		mechanism.OnStateChange:Fire(State);
	end
end

--// Mechanism Methods

function AIEngine.mechanics_prototype:WhileState(State : number, Callback : (number) -> ())
	local Active = false;
	local Update = function(NewState : number)
		if (NewState == State and not Active) then
			Active = true;
			while (self.AIState == State) do
				Callback(NewState);
				self.OnHeartBeat:Wait();
			end
			Active = false;
		end
	end
	Update(self.AIState);
	return self.OnStateChange:Connect(Update);
end

function AIEngine.mechanics_prototype:OnState(State : number, Callback : (number) -> ())
	return self.OnStateChange:Connect(function()
		if (self.AIState == State) then
			Callback(State);
		end
	end);
end

return AIEngine;