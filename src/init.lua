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

local Modules = script:WaitForChild("Modules");
local Libraries = script:WaitForChild("Libraries");

local Signal = require(Libraries:WaitForChild("Signal"));

local FFlag = require(Modules:WaitForChild("fflag")).new();
local Debug = require(Modules:WaitForChild("debug"));

export type Signal<T... = ()> = Signal.Signal<T...>;

type Shared = {
	createSignal : () -> Signal;
};

type Referenced = {
	__ref : AI;
};

export type State = { [string]: any } & {
	value : number | string;
	changed : boolean;
};

export type Mechanism = Referenced & Shared & {
	Name : string?;

	OnLoaded : Signal;

	OnState : (self : Mechanism, State : number | string, Callback : (state : State) -> ()) -> Signal.Connection;
	WhileState : (self : Mechanism, State : number | string, Callback : (state : State) -> ()) -> Signal.Connection;
};

export type AI = Shared & {
	Debug : typeof(Debug.new());
	Mechanisms : {Mechanism};
	Character : Model;
	PathAgentParams : AgentParamaters?;
	PathAgent : Path;
	State : State;

	OnHeartBeat : Signal<number>;
	OnStateChange : Signal<State>;
	OnFallingLimit : Signal<>;
	Destroyed : Signal<>;

	Heatbeat : RBXScriptConnection;

	EmitState : (self : AI, State : State | number | string) -> ();
	createMechanism : () -> Mechanism;
	LoadMechanism : (self : AI, Mechanism : Mechanism) -> ();

	Physical : Phyiscal;
	Movement : Movement;
};
type Phyiscal = Referenced & {
	GetHumanoidRoot : (self : Phyiscal) -> (Humanoid?, BasePart?);
	OnTouched : (self : Phyiscal, callback : (part : BasePart) -> (), onlyChild : boolean?) -> {RBXScriptConnection};
};
type Movement = Referenced & {
	MovingSpeed : number;
	
	MoveTo : (self : Movement, Position : Vector3) -> RBXScriptSignal;
	IsStuck : (self : Movement) -> boolean;
	IsMoving : (self : Movement) -> boolean;
	CancelMoveTo : (self : Movement) -> ();
	SetWalkSpeed : (self : Movement, Speed : number) -> ();
	ComputePathAsync : (self : Movement, Position : Vector3) -> (number, {PathWaypoint});
	CyclicLoopAsync : (self : Movement, state : State | number | string, vectors : {Vector3}, iteration : (number, Vector3) -> number) -> ();
};

local GeometricXZPlane = Vector3.new(1,0,1);
local ToXZPlane = function(vector : Vector3) : Vector3
	return (GeometricXZPlane * vector);
end

local FloorResolution = function(num : number, resolution : number) : number
	return math.floor(num*resolution)/resolution;
end

local function IsLiteral(value : any) : boolean
	return (typeof(value) == "number" or typeof(value) == "string");
end

local AIEngine = {};

AIEngine.FFlag = FFlag;

FFlag:DEFINE("EngineDebuggingLevel", RunService:IsStudio() and 1 or 0);

AIEngine.FFlags = {
	EngineDebuggingLevel = "EngineDebuggingLevel";
};

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
		PathAgentParams = agent; --// Pathfinding agent parameters
		PathAgent = PathfindingService:CreatePath(agent); --// Pathfinding agent

		OnHeartBeat = Signal.new(); --// Heartbeat signal
		OnStateChange = Signal.new(); --// State change signal
		
		OnFallingLimit = Signal.new(); --// FallingLimit signal
		Destroyed = Signal.new(); --// FallingLimit signal
	}, AIEngine.prototype);

	self.Physical = table.clone(self.Physical);
	self.Physical.__ref = self; self.Physical:__init();
	self.Movement = table.clone(self.Movement);
	self.Movement.__ref = self; self.Movement:__init();

	self.State = AIEngine.newState(-1, true); --// State of the AI, default: Unknown(-1)

	self.Heatbeat = RunService.Heartbeat:Connect(function(Step)
		self.OnHeartBeat:Fire(Step);
	end);

	if (FFlag.EngineDebuggingLevel >= 2) then
		local Debug = self.Debug;
		local Humanoid, RootPart = self.Physical:GetHumanoidRoot();
		if (Humanoid and RootPart) then
			local WalkingPoint = Debug:RenderPoint(Humanoid.WalkToPoint, Color3.fromRGB(0, 165, 96), "Humanoid Walk Point");
			self.OnHeartBeat:Connect(function(deltaTime)
				WalkingPoint.element.Position = WalkingPoint.element.Position:Lerp(Humanoid.WalkToPoint, math.clamp(deltaTime/60, 0, 1));
				WalkingPoint:SetPosition(Humanoid.WalkToPoint);
			end)
			WalkingPoint:SetParent(workspace);
		end
	end

	return self;
end

type newState = (value : number | string, changed : boolean?) -> State;
AIEngine.newState = function(value : number | string, changed : boolean?)
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

function AIEngine.prototype:EmitState(state : State | number | string)
	if (FFlag.EngineDebuggingLevel >= 3) then
		print("[AI] State Emitted", state);
	end

	if (IsLiteral(state)) then
		local changed = self.State.value ~= state;
		state = AIEngine.newState(state::(number|string), changed);
	end

	rawset(self.Isolated, "State", state);
	self.OnStateChange:Fire(state);
end

--[[Physical]] do
	local Physical = ({
		__init = function(self)
			local AI = self.__ref::AI;
			local _, RootPart = self:GetHumanoidRoot();
			local _, Size = AI.Character:GetBoundingBox();
			
			RootPart.Destroying:Once(function()
				AI.Destroyed:Fire();
			end);
			local limitHeight = workspace.FallenPartsDestroyHeight/2;
			RunService.Stepped:Connect(function()
				if (limitHeight + Size.Y > RootPart.Position.Y) then
					AI.OnFallingLimit:Fire();
				end
			end)
		end
	});

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

	function Physical:OnTouched(callback : (part : BasePart) -> (), onlyChild : boolean?)
		local AI = self.__ref::AI;
		local connections = {};
		local Character = AI.Character;
		for _, v in onlyChild and Character:GetChildren() or Character:GetDescendants() do
			if (v:IsA("BasePart")) then
				table.insert(connections, v.Touched:Connect(callback));
			end
		end
		if (#connections >= 20) then
			warn(`[AIEngine] You may experience degraded performance, due to high amount of connected touch events: {#connections}`);
			if (not onlyChild) then
				warn(`[AIEngine] Suggestion: Consider using 'onlyChild' parameter or a dedicated Part for touch events`);
			end
		end
		return connections;
	end

	AIEngine.prototype.Physical = Physical;
end

--[[Movement]] do
	local Movement = ({
		__init = function(self)
			local AI = self.__ref::AI;
			local Humanoid = AI.Physical:GetHumanoidRoot();
			if (Humanoid) then
				self.Running = Humanoid.Running:Connect(function(speed : number)
					self.MovingSpeed = speed;
				end)
			end
			self.MovingSpeed = 0;
		end
	});

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

	function Movement:IsMoving()
		return self.MovingSpeed > 0;
	end

	function Movement:IsStuck()
		local AI = self.__ref::AI;

		local Humanoid, RootPart = AI.Physical:GetHumanoidRoot();
		if (Humanoid) then
			local PointDistance = (ToXZPlane(RootPart.CFrame.Position) - ToXZPlane(Humanoid.WalkToPoint)).Magnitude;
			if (PointDistance <= 0.25) then
				return false;
			end
			
			if (FloorResolution(ToXZPlane(RootPart.AssemblyLinearVelocity).Magnitude, 10) == 0 and 
				FloorResolution(RootPart.AssemblyAngularVelocity.Magnitude, 10) == 0) then
				return true;
			end
		end
		return false
	end

	function Movement:CyclicLoopAsync(state : State | number | string, vectors : {Vector3}, iteration : (number, Vector3) -> number, lifeWait : number?)
		if (#vectors == 0) then
			return;
		end
		
		local optimizedVectors = table.clone(vectors);
		for i = #optimizedVectors, 1, -1 do
			local last = optimizedVectors[i - 1];
			local vector = optimizedVectors[i];
			if (last and vector and (vector - last).Magnitude <= 0.2) then
				table.remove(optimizedVectors, i);
			end
		end
		
		vectors = optimizedVectors;

		local AI = self.__ref::AI;
		
		local Humanoid = AI.Physical:GetHumanoidRoot();
		
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

		local isStateLiteral = IsLiteral(state);
		
		local CompletedReason = 0;
		local startedTime = time() + (lifeWait or 4);

		local HeartbeatConnection : RBXScriptConnection;
		HeartbeatConnection = AI.OnHeartBeat:Connect(function()
			if (self:IsStuck()) then
				if (startedTime <= time()) then
					HeartbeatConnection:Disconnect();
					if (FFlag.EngineDebuggingLevel >= 3) then
						print("[AI] Stuck");
					end
					CompletedReason = 1;
					self:CancelMoveTo();
				elseif (Humanoid) then
					self:MoveTo(Humanoid.WalkToPoint);
				end
			end
		end);

		for i, vector : Vector3 in vectors do
			if (CompletedReason ~= 0) then
				break;
			end
			local action = iteration(i, vector);
			if (action) then
				if (action == 1) then
					CompletedReason = 2;
					break;
				elseif (action == 2) then
					continue;
				end
			end

			if (isStateLiteral) then
				if (AI.State.value ~= state) then
					CompletedReason = -1;
					break;
				end
			elseif (AI.State ~= state) then
				CompletedReason = -1;
				break;
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
		
		if (HeartbeatConnection.Connected) then
			HeartbeatConnection:Disconnect();
		end

		return CompletedReason;
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

function AIEngine.mechanics_prototype:WhileState(State : number | string, Callback : (state : State) -> ())
	local AI = self.__ref::AI;
	local Active = false;
	local Update = function()
		if (AI.State.value == State and not Active) then
			if (FFlag.EngineDebuggingLevel >= 3) then
				print("[AI] Entering StateLoop", State);
			end
			Active = true;
			while (AI.State.value == State) do
				Callback(AI.State);
				AI.OnHeartBeat:Wait();
			end
			if (FFlag.EngineDebuggingLevel >= 3) then
				print("[AI] Exitting StateLoop", State);
			end
			Active = false;
		end
	end
	task.spawn(Update);
	return AI.OnStateChange:Connect(Update);
end

function AIEngine.mechanics_prototype:OnState(State : number | string, Callback : (state : State) -> ())
	local AI = self.__ref::AI;
	return AI.OnStateChange:Connect(function(state : State)
		if (state.value == State) then
			Callback(state);
		end
	end);
end

return AIEngine;