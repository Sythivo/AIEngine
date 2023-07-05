--[=[
	Hearing
	  Example Hearing Mechanism for AIEngine

	author: Sythivo
--]=]

local Players = game:GetService("Players");
local TweenService = game:GetService("TweenService");
local ServerScriptService = game:GetService("ServerScriptService");

local AIEngine = require(ServerScriptService:WaitForChild("AIEngine"));

type HearingSolvers = {
	Scanner : (AI : Model, Players : {Player}) -> {Player};
	Validate : (AI : Model, Player : Player) -> boolean?;
}

return function(AI : AIEngine.AI & any, PlayerHearingSolvers : HearingSolvers)
	local Mechanism : AIEngine.Mechanism & any = AIEngine.createMechanism();

	Mechanism.Name = "Hearing";
	
	local Debug = AI.Debug;

	Mechanism.OnLoaded:Once(function()
		local Character =  AI.Character;

		local HeardPlayers = {};

		AI.OnHeartBeat:Connect(function()
			if (AI.State.value ~= 1) then
				return;
			end
			local CharacterPivot = Character:GetPivot();
			local Players = PlayerHearingSolvers.Scanner(Character, Players:GetPlayers());
			for i, Player in Players do
				if ((HeardPlayers[Player] or 0) < time()) then
					HeardPlayers[Player] = time() + 5; --// Cooldown
					local State = AIEngine.newState(3, true);
					State.Player = Player;
					State.Delay = 0;
					AI:EmitState(State);

					local TargetCharacter = Player.Character;
					if (TargetCharacter and AIEngine.FFlag.EngineDebuggingLevel >= 1) then
						local Point = Debug:RenderPoint(TargetCharacter:GetPivot().Position - Vector3.new(0,2.5,0), Color3.fromRGB(0,0,0), "SOUND"):SetParent(workspace);

						TweenService:Create(Point.element, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
							Position = CharacterPivot.Position - Vector3.new(0,2.5,0);
						}):Play();

						task.delay(0.6, function()
							Point:Destroy();
						end)
					end
				end
			end
		end)
	end);

	return Mechanism;
end;