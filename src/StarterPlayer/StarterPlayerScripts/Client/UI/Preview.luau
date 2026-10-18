--!nonstrict
-- Aperçu 3D d'un héros dans l'interface (ViewportFrame + WorldModel) : rotation lente, glisser pour tourner,
-- animation de repos procédurale. Utilisé par la fiche héros, l'invocation et l'index.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Factory = require(Shared.Visuals.HeroModelFactory)
local HeroAnimator = require(Shared.Visuals.HeroAnimator)

local Kit = require(script.Parent.Kit)

local Preview = {}
Preview.__index = Preview

function Preview.new(parent: Instance, props: { [string]: any }?)
	local p = props or {}
	local self = setmetatable({}, Preview)
	local vp = Kit.new("ViewportFrame", {
		Name = "Preview",
		Size = p.Size or UDim2.fromScale(1, 1),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		BackgroundTransparency = if p.Background then 0 else 1,
		BackgroundColor3 = p.Background or Color3.new(0, 0, 0),
		Ambient = Color3.fromRGB(170, 175, 200),
		LightColor = Color3.fromRGB(255, 248, 235),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		ZIndex = p.ZIndex or 2,
		LayoutOrder = p.LayoutOrder or 0,
		Parent = parent,
	})
	if p.Background then
		Kit.Corner(vp, 14)
	end
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	self.vp = vp
	self.world = world
	self.cam = cam
	self.yaw = math.rad(-20)
	self.spin = if p.Spin == nil then true else p.Spin
	self.rig = nil
	self.animator = nil
	self.dragging = false
	-- glisser pour tourner
	vp.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self.dragging = true
			self.lastX = input.Position.X
		end
	end)
	vp.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self.dragging = false
		end
	end)
	self.moveConn = UserInputService.InputChanged:Connect(function(input)
		if self.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local dx = input.Position.X - (self.lastX or input.Position.X)
			self.lastX = input.Position.X
			self.yaw += dx * 0.012
		end
	end)
	self.conn = RunService.RenderStepped:Connect(function(dt)
		self:_step(dt)
	end)
	return self
end

function Preview:Set(heroId: string?, options: { [string]: any }?)
	if self.rig then
		self.rig.model:Destroy()
		self.rig = nil
		self.animator = nil
	end
	if not heroId or not Heroes.List[heroId] then
		return
	end
	local def = Heroes.Get(heroId)
	local ok, rig = pcall(Factory.Create, heroId, 5)
	if not ok then
		warn("[Preview] " .. tostring(rig))
		return
	end
	rig.model.Parent = self.world
	self.rig = rig
	self.animator = HeroAnimator.new(rig, def.kit)
	self.animator:SetState(if options and options.state then options.state else "Idle")
	if options and options.silhouette then
		for _, d in rig.model:GetDescendants() do
			if d:IsA("SurfaceAppearance") then
				d:Destroy()
			elseif d:IsA("MeshPart") then
				d.TextureID = ""
				d.Color = Color3.fromRGB(20, 22, 40)
				d.Material = Enum.Material.SmoothPlastic
			elseif d:IsA("BasePart") then
				d.Color = Color3.fromRGB(20, 22, 40)
				d.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	local r = Rarities.Get(def.rarity)
	self.vp.LightColor = Color3.fromRGB(255, 248, 235):Lerp(r.color, 0.15)
end

function Preview:Play(anim: string)
	if self.animator then
		self.animator:Play(anim)
	end
end

function Preview:_step(dt: number)
	if not self.vp:IsDescendantOf(game) then
		-- l'interface parente a été détruite : on libère les connexions
		self:Destroy()
		return
	end
	if not self.rig or not self.vp.Visible then
		return
	end
	if self.spin and not self.dragging then
		self.yaw += dt * 0.5
	end
	local offset = if self.animator then self.animator:Step(dt) else CFrame.new()
	self.rig.model:PivotTo(CFrame.Angles(0, self.yaw, 0) * offset)
	-- cadrage : modèle de 5 studs centré
	local h = 5
	local dist = h / (2 * math.tan(math.rad(self.cam.FieldOfView) / 2)) * 1.25
	local target = Vector3.new(0, h * 0.5, 0)
	self.cam.CFrame = CFrame.lookAt(target + Vector3.new(0, h * 0.12, -dist), target)
end

function Preview:Destroy()
	if self.conn then
		self.conn:Disconnect()
	end
	if self.moveConn then
		self.moveConn:Disconnect()
	end
	self.vp:Destroy()
end

return Preview
