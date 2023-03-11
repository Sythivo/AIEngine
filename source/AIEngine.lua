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

local modules = script:WaitForChild("modules");
local libraries = script:WaitForChild("libraries");

local FFlag = require(modules:WaitForChild("fflag")).new();
local Debug = require(modules:WaitForChild("debug"));
local Signal = require(libraries:WaitForChild("signal"));

export type Signal<T... = ()> = Signal.SignalClass<T...>;

type Shared = {
	createSignal : () -> Signal;
};

type Referenced = {
	__ref : AI;
};

export type State = { [string]: any } & {
	value : number;
	changed : boolean;
};

export type Mechanism = Referenced & Shared & {
	Name : string?;

	OnHeartBeat : Signal<number>;
	OnStateChange : Signal<State>;
	OnLoaded : Signal;

	OnState : (self : Mechanism, State : number, Callback : (state : State) -> ()) -> Signal.Connection;
	WhileState : (self : Mechanism, State : number, Callback : (state : State) -> ()) -> Signal.Connection;
};

export type AI = Shared & {
	Debug : typeof(Debug.new());
	Mechanisms : {Mechanism};
	Character : Model;
	PathAgent : Path;
	State : State;

	Heatbeat : RBXScriptConnection;

	EmitState : (self : AI, State : State | number) -> ();
	createMechanism : () -> Mechanism;
	LoadMechanism : (self : AI, Mechanism : Mechanism) -> ();

	Physical : Phyiscal;
	Movement : Movement;
};
type Phyiscal = Referenced & {
	GetHumanoidRoot : (self : Phyiscal) -> (Humanoid, BasePart);
};
type Movement = Referenced & {
	MoveTo : (self : Movement, Position : Vector3) -> RBXScriptSignal;
	CancelMoveTo : (self : Movement) -> ();
	SetWalkSpeed : (self : Movement, Speed : number) -> ();
	ComputePathAsync : (self : Movement, Position : Vector3) -> (number, {PathWaypoint});
	CyclicLoopAsync : (self : Movement, state : State | number, vectors : {Vector3}, iteration : (number, Vector3) -> number) -> ();
};

local AIEngine = ({});

AIEngine.FFlag = FFlag;

FFlag:DEFINE("EngineDebuggingLevel", RunService:IsStudio() and 1 or 0);

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

	self.Physical = table.clone(self.Physical);
	self.Physical.__ref = self;
	self.Movement = table.clone(self.Movement);
	self.Movement.__ref = self;

	self.State = AIEngine.newState(-1, true); --// State of the AI, default: Unknown(-1)

	self.Heatbeat = RunService.Heartbeat:Connect(function(Step)
		for _, mechanism in self.Mechanisms do
			mechanism.OnHeartBeat:Fire(Step);
		end
	end);

	return self;
end

type newState = (value : number, changed : boolean?) -> State;
AIEngine.newState = function(value : number, changed : boolean?)
	return ({
		value = value;
		changed = changed;
	});
end::newState;

type WaypointToVector = ((waypoints : PathWaypoint) -> Vector3) & ((waypoints : {PathWaypoint}) -> {Vector3});
AIEngine.WaypointToVector = function(waypoints : PathWaypoint | {PathWaypoint})
	if (type(waypoints) == "table") then
		local vectors = table.create(#waypoints);
		for _, waypoint in waypoints do
			table.insert(vectors, waypoint.Position);
		end
		return vectors;
	else
		return waypoints.Position;
	end
end::WaypointToVector;

--[[
	Creates a new mechanism
]]
function AIEngine.createMechanism() : Mechanism
	local self = setmetatable({
		OnHeartBeat = Signal.new();
		OnStateChange = Signal.new();
		OnLoaded = Signal.new();
	}, AIEngine.mechanics_prototype);

	return self;
end

AIEngine.prototype.createSignal = Signal.new;
AIEngine.mechanics_prototype.createSignal = Signal.new;

--// AI Methods

function AIEngine.prototype:LoadMechanism(Mechanism : Mechanism)
	if (table.find(self.Mechanisms, Mechanism)) then
		warn("[AIEngine] Mechanism already loaded");
		return;
	end
	if (FFlag.EngineDebuggingLevel >= 2) then
		local name = Mechanism.Name or "Unnamed";
		print("[AIEngine] Loading Mechanism:", name);
	end
	table.insert(self.Mechanisms, Mechanism);
	Mechanism.__ref = self;
	Mechanism.OnLoaded:Fire();
end

function AIEngine.prototype:EmitState(state : State | number)
	if (FFlag.EngineDebuggingLevel >= 3) then
		print("[AI] State Emitted", state);
	end

	if (typeof(state) == "number") then
		local changed = self.State.value ~= state;
		state = AIEngine.newState(state, changed);
	end

	rawset(self.Isolated, "State", state);
	for _, mechanism in self.Mechanisms do
		mechanism.OnStateChange:Fire(state);
	end
end

--[[Physical]] do
	local Physical = ({});

	function Physical:GetHumanoidRoot()
		local AI = self.__ref::AI;
		local Character = AI.Character;
		if (Character) then
			local Humanoid = Character:FindFirstChild("Humanoid");
			if (Humanoid) then
				local RootPart = Humanoid.RootPart;
				if (RootPart) then
					return Humanoid, RootPart;
				end
			end
		end
		return;
	end

	AIEngine.prototype.Physical = Physical;
end

--[[Movement]] do
	local Movement = ({});

	function Movement:MoveTo(vector : Vector3) : RBXScriptSignal?
		local AI = self.__ref::AI;

		if (FFlag.EngineDebuggingLevel >= 4) then
			print("[AI] Moving To Vector<WorldSpace>", vector);
		end
		local Humanoid = AI.Physical:GetHumanoidRoot();
		if (Humanoid) then
			Humanoid:MoveTo(vector);
			return Humanoid.MoveToFinished;
		end
		return;
	end
	
	function Movement:CancelMoveTo()
		local AI = self.__ref::AI;

		local Humanoid, RootPart = AI.Physical:GetHumanoidRoot();
		if (Humanoid) then
			Humanoid:MoveTo(RootPart.CFrame.Position);
		end
	end

	function Movement:CyclicLoopAsync(state : State | number, vectors : {Vector3}, iteration : (number, Vector3) -> number)
		local AI = self.__ref::AI;

		local DEBUG = FFlag.EngineDebuggingLevel >= 1;
		
		local cyclesize = #vectors;
		local DEBUG_RenderParts;
		if (DEBUG) then
			local Debug = AI.Debug;
			Debug:Clear();
			DEBUG_RenderParts = table.create(cyclesize);
			Debug:RenderPoint(vectors[1], Color3.fromRGB(98, 255, 98), "START"):InMemory():SetParent(workspace);
			for i = 2, cyclesize - 1, 1 do
				DEBUG_RenderParts[i] = Debug:RenderPoint(vectors[i], Color3.fromRGB(50, 127, 131)):InMemory():SetParent(workspace);
			end
			Debug:RenderPoint(vectors[cyclesize], Color3.fromRGB(255, 245, 98), "END"):InMemory():SetParent(workspace);
		end

		local isStateNumber = typeof(state) == "number";
		
		for i, vector : Vector3 in vectors do
			local action = iteration(i, vector);
			if (action) then
				if (action == 1) then
					return;
				elseif (action == 2) then
					continue;
				end
			end

			if (isStateNumber) then
				if (AI.State.value ~= state) then
					return;
				end
			else
				if (AI.State ~= state) then
					return;
				end
			end

			if (DEBUG) then
				local LastRenderPart = DEBUG_RenderParts[i - 1];
				if (LastRenderPart and not LastRenderPart.Locked) then
					LastRenderPart:SetVisualizer(Color3.fromRGB(50, 127, 131));
				end
				local RenderPart = DEBUG_RenderParts[i];
				if (RenderPart) then
					RenderPart:SetVisualizer(Color3.fromRGB(98, 247, 255), "TARGET");
				end
			end
			
			local movementFinished = self:MoveTo(vector);
			if (movementFinished) then
				movementFinished:Wait();
			end
		end
	end
	
	function Movement:SetWalkSpeed(speed : number)
		local AI = self.__ref::AI;

		local Humanoid = AI.Physical:GetHumanoidRoot();
		if (Humanoid) then
			Humanoid.WalkSpeed = speed;
		end
	end
	
	function Movement:ComputePathAsync(vector : Vector3)
		local AI = self.__ref::AI;

		local svector = AI.Character:GetPivot().Position;
		AI.PathAgent:ComputeAsync(svector, vector);
		return AI.PathAgent.Status.Value, AI.PathAgent:GetWaypoints();
	end

	AIEngine.prototype.Movement = Movement;
end

--// Mechanism Methods

function AIEngine.mechanics_prototype:WhileState(State : number, Callback : (state : State) -> ())
	local AI = self.__ref::AI;
	local Active = false;
	local Update = function(state : State)
		if (state.value == State and not Active) then
			if (FFlag.EngineDebuggingLevel >= 3) then
				print("[AI] Entering StateLoop", State);
			end
			Active = true;
			while (AI.State.value == State) do
				Callback(state);
				self.OnHeartBeat:Wait();
			end
			if (FFlag.EngineDebuggingLevel >= 3) then
				print("[AI] Exitting StateLoop", State);
			end
			Active = false;
		end
	end
	Update(AI.State);
	return self.OnStateChange:Connect(Update);
end

function AIEngine.mechanics_prototype:OnState(State : number, Callback : (state : State) -> ())
	return self.OnStateChange:Connect(function(state : State)
		if (state.value == State) then
			Callback(state);
		end
	end);
end

return AIEngine;