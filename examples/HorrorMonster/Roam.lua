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

	Mechanism.OnLoaded:Once(function()
		local RoamIndex = 1;
		Mechanism:WhileState(1, function()
			local CurrentRoamPoint = RoamPoints[RoamIndex];
			if (not CurrentRoamPoint) then
				RoamIndex = 1;
				CurrentRoamPoint = RoamPoints[RoamIndex];
			end
			local status, Waypoints = AI.Movement:ComputePathAsync(CurrentRoamPoint);
			if (AI.State.value ~= 1) then
				return;
			end
			if (status <= 0) then
				local context = AI.Movement:CyclicLoopAsync(1, AIEngine.WaypointToVector(Waypoints), function(i, vector)
					if (i == 1) then
						return 2;
					end
					return;
				end);
				if (context == 1) then
					warn("Roam Stopped from being Stuck");
				elseif (context == -1) then
					warn("Roam Interrupted");
				elseif (context == 2) then
					warn("Roam Rule Cancel");
				end
			end
			RoamIndex += 1;
		end);
	end);

	return Mechanism;
end;