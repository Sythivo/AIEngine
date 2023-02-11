--[=[
	Debug
	  Special Debugging Module for AIEngine

	author: Sythivo
--]=]

local RunService = game:GetService("RunService");

local Memory = require(script.Parent:WaitForChild("libraries"):WaitForChild("memory"));

local debug = ({});

debug.Enabled = RunService:IsStudio();

debug.prototype = {};
debug.prototype.__index = debug.prototype;

local New = function(class : string) : (Properties : any) -> Instance
	local object = Instance.new(class);
	return function(Properties : any)
		if (type(Properties) ~= "table") then
			return object;
		end;

		for i, v in Properties do
			if (typeof(v) == "Instance" and type(i) == "number") then
				v.Parent = (object);
				continue;
			end

			object[i] = v;
		end

		return object;
	end;
end

local CreateVisualPart = function()
	return New "Part" {
		CanQuery = false;
		CanCollide = false;
		CanTouch = false;
		Anchored = true;
		TopSurface = Enum.SurfaceType.Smooth;
		Material = Enum.Material.Neon;
		BottomSurface = Enum.SurfaceType.Smooth;
		Size = Vector3.new(0.5, 0.5, 0.5);
	};
end

local CreatePointVisualizer = function(Color : Color3, Text : string?)
	local StartAttachment = New "Attachment" {};
	local EndAttachment = New "Attachment" {
		Position = Vector3.new(0, 9, 0);
	};
	local Beam = New "Beam" {
		Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color), ColorSequenceKeypoint.new(1, Color)};
		LightInfluence = 1;
		FaceCamera = true;
		Width0 = 0.5;
		Width1 = 0.5;
		TextureSpeed = 0.2;
		TextureLength = 2;
		Texture = "rbxassetid://3517446796";
		Attachment0 = StartAttachment;
		Attachment1 = EndAttachment;
	};
	if (Text) then
		New "BillboardGui" {
			Parent = EndAttachment;
			LightInfluence = 0;
			StudsOffset = Vector3.new(0, 0.75, 0);
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
			ClipsDescendants = true;
			Active = true;
			AlwaysOnTop = false;
			Brightness = 2;
			Size = UDim2.new(3, 5, 0.75, 5);
			New "TextLabel" {
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal);
				TextColor3 = Color;
				Text = Text;
				Size = UDim2.new(1, 0, 1, 0);
				BackgroundTransparency = 1;
				TextWrapped = true;
				TextScaled = true;
			};
		};
	end

	return StartAttachment, EndAttachment, Beam;
end

function debug.new()
	return (setmetatable({
		Enabled = debug.Enabled;
		Memory = Memory.new();
	}, debug.prototype));
end

type Point = {
	Visualizer : {
		StartAttachment : Attachment?;
		EndAttachment : Attachment?;
		Beam : Beam?;
	};
	element : Part;
	InMemory : (self : Point) -> Point;
	SetParent : (self : Point, parent : Instance) -> Point;
	SetVisualizer : (self : Point, Color : Color3, Text : string?) -> Point;
	SetPosition : (self : Point, Vector : Vector3) -> Point;
	DestroyVisualizer : (self : Point) -> Point;
	Destroy : (self : Point) -> ();
}

function debug.prototype:RenderPoint(Vector : Vector3, Color : Color3, Text : string?) : Point
	local debugger = self;
	local Point = ({});
	
	Point.Visualizer = {
		StartAttachment = nil;
		EndAttachment = nil;
		Beam = nil;
	};

	Point.element = CreateVisualPart();

	function Point:InMemory()
		debugger.Memory:Add(self.element);
		return self;
	end

	function Point:SetParent(parent : Instance)
		self.element.Parent = parent;
		return self;
	end

	function Point:DestroyVisualizer()
		for i, v in Point.Visualizer do
			if (v) then
				v:Destroy();
				Point.Visualizer[i] = nil;
			end
		end

		return self;
	end

	function Point:SetVisualizer(Color : Color3, Text : string?)
		self:DestroyVisualizer();

		if (Text) then
			local StartAttachment, EndAttachment, Beam = CreatePointVisualizer(Color, Text);
			Point.Visualizer.StartAttachment = StartAttachment; Point.Visualizer.EndAttachment = EndAttachment; Point.Visualizer.Beam = Beam;
			StartAttachment.Parent = self.element; EndAttachment.Parent = self.element; Beam.Parent = self.element;
		end

		self.element.Color = Color;

		return self;
	end

	function Point:SetPosition(Vector)
		self.element.Position = Vector;
		return self;
	end

	function Point:Destroy()
		self:DestroyVisualizer();
		self.element:Destroy();
	end

	Point:SetVisualizer(Color, Text);
	Point:SetPosition(Vector);

	return Point;
end

function debug.prototype:Clear()
	self.Memory:Clean();
end

return debug;