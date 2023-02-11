--[=[
	Investigate
	  Example Investigate Mechanism for AIEngine

	author: Sythivo
--]=]

local ServerScriptService = game:GetService("ServerScriptService");

local AIEngine = require(ServerScriptService:WaitForChild("AIEngine"));

type Solvers = {
	Scanner : (AI : Model, Players : {Player}) -> Player?;
	Validate : (AI : Model, Player : Player) -> boolean?;
	ValidateScan : (AI : Model, Player : Player) -> boolean?;
}

return function(AI : AIEngine.AI & any, PlayerSolvers : Solvers)
	local Mechanism : AIEngine.Mechanism & any = AIEngine.createMechanism();
	
	Mechanism.Name = "Investigate";

	local Debug = AI.Debug;

	Mechanism.Unique = "";
	Mechanism.UniqueQueues = {};

	local RemoveUniqueId = function(UniqueId : string)
		local id = table.find(Mechanism.UniqueQueues, UniqueId);
		if (id) then
			table.remove(Mechanism.UniqueQueues, id);
		end
	end

	Mechanism.OnLoaded:Once(function()
		local Character =  AI.Character;
		local Humanoid : Humanoid = Character.Humanoid;

		local ReturnToNormalState = function()
			AI.State = 1;
			AI.TargetPlayer = nil;
		end

		local PathAgent = AI.PathAgent;

		local Investigate = function(UniqueId)
			local TargetPlayer : Player = AI.TargetPlayer;
			if (not TargetPlayer) then
				ReturnToNormalState();
				return;
			end
			local TargetCharacter = TargetPlayer.Character;
			if (not TargetCharacter or not PlayerSolvers.Validate(Character, TargetPlayer)) then
				ReturnToNormalState();
				return;
			end

			task.wait(AI.InvestigateDelay or 1);
			--// Just to make sure the player is still there
			TargetCharacter = TargetPlayer.Character;
			if (not TargetCharacter or not PlayerSolvers.Validate(Character, TargetPlayer)) then
				ReturnToNormalState();
				return;
			end
			local PlayerPivot = TargetCharacter:GetPivot();
			local TargetPosition = PlayerPivot.Position;
			PathAgent:ComputeAsync((AI.Character.PrimaryPart::BasePart).Position, TargetPosition);
			if (AI.State ~= 3 or Mechanism.Unique ~= UniqueId) then
				return;
			end
			if (PathAgent.Status == Enum.PathStatus.Success) then
				local Waypoints = PathAgent:GetWaypoints();

				Debug:Clear();
				local WaypointsSize = #Waypoints;
				local RenderParts = table.create(WaypointsSize);

				--// Render the path
				if (Debug.Enabled) then
					Debug:RenderPoint(Waypoints[1].Position, Color3.fromRGB(98, 255, 98), "START"):InMemory():SetParent(workspace);
					for i = 2, WaypointsSize - 1, 1 do
						RenderParts[i] = Debug:RenderPoint(Waypoints[i].Position, Color3.fromRGB(50, 127, 131)):InMemory():SetParent(workspace);
					end
					Debug:RenderPoint(Waypoints[WaypointsSize].Position, Color3.fromRGB(255, 245, 98), "END"):InMemory():SetParent(workspace);
				end

				for i, Waypoint in Waypoints do
					--// Check if the AI is still in the investigate state and if the investigate request is the same
					if (AI.State ~= 3 or Mechanism.Unique ~= UniqueId) then
						return;
					end
					if (i == 1) then
						continue;
					end
					--// Set the visualizer
					local LastRenderPart = RenderParts[i - 1];
					if (LastRenderPart and not LastRenderPart.Locked) then
						LastRenderPart:SetVisualizer(Color3.fromRGB(50, 127, 131));
					end
					local RenderPart = RenderParts[i];
					if (RenderPart) then
						RenderPart:SetVisualizer(Color3.fromRGB(98, 247, 255), "TARGET");
					end
					--// Move to the waypoint
					Humanoid:MoveTo(Waypoint.Position);
					Humanoid.MoveToFinished:Wait();
				end
			end
			if (AI.State ~= 3) then
				return;
			end
			ReturnToNormalState();
		end

		Mechanism:OnState(3, function()
			local UniqueId = Mechanism.createUniqueAddress(4, Mechanism.UniqueQueues);
			table.insert(Mechanism.UniqueQueues, UniqueId);
			Mechanism.Unique = UniqueId;
			Investigate(UniqueId);
			RemoveUniqueId(UniqueId);
		end)
	end);

	return Mechanism;
end;