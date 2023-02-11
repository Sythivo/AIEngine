--[=[
	Roam
	  Example Roaming Mechanism for the AI Engine

	author: Sythivo
--]=]

local ServerScriptService = game:GetService("ServerScriptService");

local AIEngine = require(ServerScriptService:WaitForChild("AIEngine"));

return function(AI : AIEngine.AI, RoamPoints : {Vector3})
	if (#RoamPoints < 2) then
		error("[Horror AI Preset] RoamPoints must have at least 2 points");
		return;
	end
	local Mechanism : AIEngine.Mechanism = AIEngine.createMechanism();
	
	Mechanism.Name = "Roam";

	local Debug = AI.Debug;

	Mechanism.OnLoaded:Once(function()
		local Humanoid = AI.Character:WaitForChild("Humanoid")::Humanoid;
		local RoamIndex = 1;
		Mechanism:WhileState(1, function()
			local CurrentRoamPoint = RoamPoints[RoamIndex];
			if (not CurrentRoamPoint) then
				RoamIndex = 1;
				CurrentRoamPoint = RoamPoints[RoamIndex];
			end
			AI.PathAgent:ComputeAsync((AI.Character.PrimaryPart::BasePart).Position, CurrentRoamPoint);
			if (AI.State ~= 1) then
				return;
			end
			if (AI.PathAgent.Status == Enum.PathStatus.Success) then
				local Waypoints = AI.PathAgent:GetWaypoints();

				Debug:Clear();
				local WaypointsSize = #Waypoints;
				local RenderParts = table.create(WaypointsSize);
				if (Debug.Enabled) then
					Debug:RenderPoint(Waypoints[1].Position, Color3.fromRGB(98, 255, 98), "START"):InMemory():SetParent(workspace);
					for i = 2, WaypointsSize - 1, 1 do
						RenderParts[i] = Debug:RenderPoint(Waypoints[i].Position, Color3.fromRGB(50, 127, 131)):InMemory():SetParent(workspace);
					end
					Debug:RenderPoint(Waypoints[WaypointsSize].Position, Color3.fromRGB(255, 245, 98), "END"):InMemory():SetParent(workspace);
				end

				for i, Waypoint in Waypoints do
					if (AI.State ~= 1) then
						return;
					end
					if (i == 1) then
						continue;
					end
					local LastRenderPart = RenderParts[i - 1];
					if (LastRenderPart and not LastRenderPart.Locked) then
						LastRenderPart:SetVisualizer(Color3.fromRGB(50, 127, 131));
					end
					local RenderPart = RenderParts[i];
					if (RenderPart) then
						RenderPart:SetVisualizer(Color3.fromRGB(98, 247, 255), "TARGET");
					end
					Humanoid:MoveTo(Waypoint.Position);
					Humanoid.MoveToFinished:Wait();
				end
			end
			RoamIndex += 1;
			if (AI.State ~= 1) then
				return;
			end
		end);
	end);

	return Mechanism;
end;