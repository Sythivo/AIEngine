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

	Mechanism.OnLoaded:Once(function()
		local Character =  AI.Character;

		local ReturnToNormalState = function()
			AI:EmitState(1);
		end

		local Investigate = function(State : AIEngine.State)
			local TargetPlayer : Player = State.Player;
			if (not TargetPlayer) then
				ReturnToNormalState();
				return;
			end
			local TargetCharacter = TargetPlayer.Character;
			if (not TargetCharacter or not PlayerSolvers.Validate(Character, TargetPlayer)) then
				ReturnToNormalState();
				return;
			end

			task.wait(State.Delay or 1);
			--// Just to make sure the player is still there
			TargetCharacter = TargetPlayer.Character;
			if (not TargetCharacter or not PlayerSolvers.Validate(Character, TargetPlayer)) then
				ReturnToNormalState();
				return;
			end
			local PlayerPivot = TargetCharacter:GetPivot();
			local TargetPosition = PlayerPivot.Position;

			local status, Waypoints = AI.Movement:ComputePathAsync(TargetPosition);
			if (Mechanism.Unique ~= State) then
				return;
			end
			if (status <= 0) then
				AI.Movement:CyclicLoopAsync(State, AIEngine.WaypointToVector(Waypoints), function(i, vector)
					if (i == 1) then
						return 2;
					end
					return;
				end);
			end
			if (Mechanism.Unique ~= State) then
				return;
			end
			if (AI.State ~= State) then
				return;
			end
			ReturnToNormalState();
		end

		Mechanism:OnState(3, function(state)
			Mechanism.Unique = state;
			Investigate(state);
		end)
	end);

	return Mechanism;
end;