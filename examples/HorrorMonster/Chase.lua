--[=[
	Chase
	  Example Chase Mechanism for AIEngine

	author: Sythivo
--]=]

local Players = game:GetService("Players");
local ServerScriptService = game:GetService("ServerScriptService");

local AIEngine = require(ServerScriptService:WaitForChild("AIEngine"));

type Solvers = {
	Scanner : (AI : Model, Players : {Player}) -> Player?;
	Validate : (AI : Model, Player : Player) -> boolean?;
	ValidateScan : (AI : Model, Player : Player) -> boolean?;
}

export type ChaseMechanism = AIEngine.Mechanism & {
	OnChaseStart : AIEngine.Signal<Player>;
	OnChaseEnded : AIEngine.Signal<Player?>;
}

return function(AI : AIEngine.AI & any, PlayerSolvers : Solvers) : ChaseMechanism
	local Mechanism : AIEngine.Mechanism & any = AIEngine.createMechanism();

	Mechanism.Name = "Chase";
	
	local Debug = AI.Debug;

	Mechanism.OnChaseStart = Mechanism.createSignal();
	Mechanism.OnChaseEnded = Mechanism.createSignal();

	Mechanism.OnLoaded:Once(function()
		local Character =  AI.Character;
		local Humanoid : Humanoid = Character.Humanoid;

		local Render;

		local ReturnToNormalState = function()
			AI.State = 1;
			AI.TargetPlayer = nil;
			Render = nil;
		end
		local EnterToInvestigatingState = function()
			AI.State = 3;
			AI.InvestigateDelay = 1;
			Render = nil;
		end

		Mechanism.OnHeartBeat:Connect(function()
			local Player = PlayerSolvers.Scanner(Character, Players:GetPlayers());
			if (Player) then
				if (AI.TargetPlayer ~= Player) then
					if (AI.TargetPlayer) then
						Mechanism.OnChaseEnded:Fire(AI.TargetPlayer);
					end
					Mechanism.OnChaseStart:Fire(Player);
				end
				AI.State = 2;
				AI.TargetPlayer = Player;
			end
		end)

		Mechanism.OnStateChange:Connect(function(OldState, NewState)
			if (NewState == 1) then
				Mechanism.OnChaseEnded:Fire();
			end
		end)

		Mechanism:WhileState(2, function()
			if (not Render) then
				Debug:Clear();
				Render = Debug:RenderPoint(Vector3.zero, Color3.fromRGB(255, 98, 98), "CHASE"):InMemory():SetParent(workspace);
			end
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
			if (not PlayerSolvers.ValidateScan(Character, TargetPlayer)) then
				EnterToInvestigatingState();
				return;
			end
			local PlayerPivot = TargetCharacter:GetPivot();
			local TargetPosition = PlayerPivot.Position;
			
			Render:SetPosition(TargetPosition - Vector3.new(0,2,0));

			Humanoid:MoveTo(TargetPosition);
		end);
	end);

	return Mechanism;
end;