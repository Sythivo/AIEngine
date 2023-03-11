local ServerScriptService = game:GetService("ServerScriptService");

local AIEngine = require(ServerScriptService:WaitForChild("AIEngine"));

local HorrorMechanics = ServerScriptService:WaitForChild("MechanicsExamples"):WaitForChild("HorrorMonster");

local AI = AIEngine.new(script.Parent, {
	AgentHeight = 3;
	AgentRadius = 2.5;
	AgentCanJump = false;
});

for _, v : Instance in AI.Character:GetDescendants() do
	if (v:IsA("BasePart")) then
		v:SetNetworkOwner(nil);
	end
end

local VisionRange = 1000;
local HearingRange = 50;
local HearingPlayerWalkSpeed = 16;

-- 0 - 4 levels
AIEngine.FFlag:SETFASTFLAG("EngineDebuggingLevel", 2);

local XZPlane = Vector3.new(1,0,1);

local RoamingMechanism = require(HorrorMechanics:WaitForChild("Roam"));
local ChasingMechanism = require(HorrorMechanics:WaitForChild("Chase"));
local HearingMechanism = require(HorrorMechanics:WaitForChild("Hearing"));
local InvestigatingMechanism = require(HorrorMechanics:WaitForChild("Investigate"));

local RoamingPointsDirectory = workspace:WaitForChild("RoamingPoints");

local RoamingSpots = RoamingPointsDirectory:GetChildren();
local RoamingPoints = table.create(#RoamingSpots);

for i, v in RoamingSpots do
	RoamingPoints[i] = v.Position;
end

RoamingPointsDirectory:Destroy();

local RayParams = RaycastParams.new();
RayParams.FilterType = Enum.RaycastFilterType.Exclude;
RayParams.FilterDescendantsInstances = ({AI.Character});
RayParams.IgnoreWater = true;
RayParams.RespectCanCollide = true;

local PlayerSolvers = {};
local PlayerHearingSolvers = {};
PlayerSolvers.Validate = function(AI : Model, Player : Player) : boolean?
	local Character = Player.Character;
	if (Character) then
		local Humanoid : Humanoid = Character:FindFirstChild("Humanoid");
		return Humanoid and Humanoid.Health > 0;
	end
	return;
end;
PlayerSolvers.ValidateScan = function(AI : Model, Player : Player) : boolean?
	if (not PlayerSolvers.Validate(AI, Player) or Player:GetAttribute("IsSafe")) then
		return;
	end
	local RootPivot = AI:GetPivot();
	local RootPosition = RootPivot.Position;
	local Character = Player.Character;

	local Direction = (Character:GetPivot().Position - RootPosition).Unit;
	local Result = workspace:Raycast(RootPosition, Direction * VisionRange, RayParams);

	if (Result and Result.Instance:IsDescendantOf(Character)) then
		local DotProduct = Direction:Dot(RootPivot.LookVector);

		if (DotProduct > 0) then
			return true;
		end
	end
	return;
end;
PlayerSolvers.Scanner = function(AI : Model, Players : {Player}) : Player?
	local RootPivot = AI:GetPivot();
	local RootPosition = RootPivot.Position;
	table.sort(Players, function(a, b)
		if (not a.Character) then
			return false;
		end
		if (not b.Character) then
			return true;
		end
		return (a.Character:GetPivot().Position - RootPosition).Magnitude < (b.Character:GetPivot().Position - RootPosition).Magnitude;
	end);
	for _, Player in Players do
		if (PlayerSolvers.ValidateScan(AI, Player)) then
			return Player;
		end
	end
	return;
end;
PlayerHearingSolvers.Validate = PlayerSolvers.Validate;
PlayerHearingSolvers.Scanner  = function(AI : Model, Players : {Player}) : {Player}
	local RootPivot = AI:GetPivot();
	local RootPosition = RootPivot.Position;
	local HeardPlayers = {};
	for _, Player in Players do
		if (PlayerSolvers.Validate(AI, Player)) then
			local Character = Player.Character;
			if (Character) then
				local RootPart : BasePart = Character:FindFirstChild("HumanoidRootPart");
				if (RootPart) then
					local Range = (Character:GetPivot().Position - RootPosition).Magnitude;
					if (((RootPart.AssemblyLinearVelocity * XZPlane).Magnitude/HearingPlayerWalkSpeed)/Range * HearingRange >= 1) then
						table.insert(HeardPlayers, Player);
					end
				end
			end
		end
	end
	return HeardPlayers;
end;

AI:EmitState(1); --// Roaming

local ChasingMechanismInstance = ChasingMechanism(AI, PlayerSolvers);

ChasingMechanismInstance.OnChaseStart:Connect(function(Player)
	print("[Horror Agent Sample] AI Chasing", Player);
end);
ChasingMechanismInstance.OnChaseEnded:Connect(function(Player)
	print("[Horror Agent Sample] AI Not Chasing", Player);
end);

AI:LoadMechanism(ChasingMechanismInstance);
AI:LoadMechanism(RoamingMechanism(AI, RoamingPoints));
AI:LoadMechanism(HearingMechanism(AI, PlayerHearingSolvers));
AI:LoadMechanism(InvestigatingMechanism(AI, PlayerSolvers));