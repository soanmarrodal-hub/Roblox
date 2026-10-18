--!nonstrict
-- Visuels des ennemis : mobs des îles, boss mondiaux (3 phases) et gardiens de sanctuaire.
-- Silhouettes procédurales (Visuals/EnemyVisuals), barres de PV, grande barre de boss en haut de l'écran.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Enemies = require(Shared.Config.Enemies)
local Format = require(Shared.Util.Format)
local EnemyVisuals = require(Shared.Visuals.EnemyVisuals)
local VFX = require(Shared.Visuals.VFX)

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local EnemiesCtl = {}
local C

local ENEMY_KINDS = { Mob = true, Boss = true, Guardian = true }
local RENDER_RADIUS = 320

type Item = {
	anchor: BasePart,
	kind: string,
	def: any,
	size: number,
	visual: any?,
	plate: BillboardGui?,
	hpSet: ((number, string?) -> ())?,
	cf: CFrame?,
	lastHp: number,
	flash: number,
	dying: boolean,
}
local items: { [BasePart]: Item } = {}
local folder: Folder
local bossBar: Frame
local bossSet: (number, string?) -> ()
local bossName: TextLabel
local bossPhase: TextLabel

local function sizeOf(kind: string, def: any, anchor: BasePart): number
	local sc = anchor:GetAttribute("Scale") or 1
	if kind == "Mob" then
		return sc * 4
	end
	return sc * 8 * (if def and def.look then 1 else 1)
end

local function buildPlate(it: Item)
	local def = it.def
	local isBig = it.kind ~= "Mob"
	local bb = Kit.new("BillboardGui", {
		Name = "EnemyPlate",
		Size = if isBig then UDim2.fromOffset(220, 46) else UDim2.fromOffset(140, 34),
		StudsOffsetWorldSpace = Vector3.new(0, it.size * 0.6 + 2, 0),
		MaxDistance = if isBig then 200 else 70,
		AlwaysOnTop = true,
		LightInfluence = 0,
		Adornee = it.anchor,
		Parent = folder,
	})
	local lvl = it.anchor:GetAttribute("Level")
	local name = it.anchor:GetAttribute("Name") or (def and def.name) or "?"
	Kit.Label(bb, { Text = if lvl and it.kind == "Mob" then name .. " · Niv." .. lvl else name, Size = UDim2.new(1, 0, 0.5, 0), Font = Theme.Font.Title, Color = if it.kind == "Boss" then Theme.Color.Error elseif it.kind == "Guardian" then Theme.Color.Gold else Theme.Color.Text })
	local _, set = Kit.Bar(bb, { Size = UDim2.new(0.9, 0, 0.38, 0), Position = UDim2.fromScale(0.05, 0.56), Color = Color3.fromRGB(255, 80, 80) })
	it.plate = bb
	it.hpSet = set
end

local function createVisual(it: Item)
	local def = it.def
	if not def or not def.look then
		return
	end
	local look = table.clone(def.look)
	look.size = it.size
	local v = EnemyVisuals.Build(look, tostring(it.anchor:GetAttribute("Name") or "Enemy"))
	for _, e in v.parts do
		e.part.CanCollide = false
		e.part.CanQuery = false
		e.part.CanTouch = false
	end
	v.model.Parent = folder
	it.visual = v
	if it.kind ~= "Mob" and def.look.glow then
		local l = Instance.new("PointLight")
		l.Color = def.look.glow
		l.Range = math.min(60, it.size * 1.5)
		l.Brightness = 2
		l.Parent = v.parts[1].part
	end
	buildPlate(it)
end

local function destroyVisual(it: Item)
	if it.visual then
		it.visual.model:Destroy()
		it.visual = nil
	end
	if it.plate then
		it.plate:Destroy()
		it.plate = nil
		it.hpSet = nil
	end
end

local function watch(anchor: Instance)
	if not anchor:IsA("BasePart") then
		return
	end
	local kind = anchor:GetAttribute("Kind")
	if not ENEMY_KINDS[kind] then
		return
	end
	local def = Enemies.GetAny(tostring(anchor:GetAttribute("Ref")))
	local it: Item = {
		anchor = anchor,
		kind = kind,
		def = def,
		size = sizeOf(kind, def, anchor),
		lastHp = anchor:GetAttribute("HP") or 0,
		flash = 0,
		dying = false,
	}
	items[anchor] = it
	anchor:GetAttributeChangedSignal("HP"):Connect(function()
		local hp = anchor:GetAttribute("HP") or 0
		if hp < it.lastHp then
			it.flash = 0.12
		end
		it.lastHp = hp
	end)
	anchor:GetAttributeChangedSignal("Phase"):Connect(function()
		local ph = anchor:GetAttribute("Phase") or 1
		if def and def.phases and def.phases[ph] then
			VFX.Burst(anchor.Position, def.phases[ph], 40, 40, 1.5)
			VFX.Ring(anchor.Position, it.size * 1.4, def.phases[ph], 1, 1.5)
			C.Combat.Shake(0.8)
			C.Sound.Play("Boom", anchor.Position)
		end
	end)
	anchor.AncestryChanged:Connect(function()
		if not anchor:IsDescendantOf(Workspace) then
			local current = items[anchor]
			if current then
				-- petite explosion de disparition
				if current.visual and current.cf then
					VFX.Burst(current.cf.Position + Vector3.new(0, current.size * 0.4, 0), def and def.look and (def.look.glow or def.look.colors[1]) or Color3.new(1, 1, 1), 18, 22, 0.8)
				end
				destroyVisual(current)
				items[anchor] = nil
			end
		end
	end)
end

local function step(dt: number)
	local cam = Workspace.CurrentCamera
	local cp = cam and cam.CFrame.Position or Vector3.zero
	local now = Workspace:GetServerTimeNow()
	local t = os.clock()
	local nearestBoss, nearestD = nil, 260
	for anchor, it in items do
		local d = (anchor.Position - cp).Magnitude
		if d > RENDER_RADIUS then
			if it.visual then
				destroyVisual(it)
			end
			continue
		end
		if not it.visual then
			createVisual(it)
			if not it.visual then
				continue
			end
		end
		local hover = anchor:GetAttribute("Hover") or it.size * 0.5
		local target = anchor.CFrame * CFrame.new(0, -hover, 0)
		it.cf = if it.cf then it.cf:Lerp(target, 1 - math.exp(-dt * 12)) else target
		local state = anchor:GetAttribute("State") or "Idle"
		local atkAt = anchor:GetAttribute("AttackAt") or 0
		EnemyVisuals.Pose(it.visual, it.cf :: CFrame, t, state, now - atkAt)
		-- éclair blanc à l'impact
		if it.flash > 0 then
			it.flash -= dt
			local hl = it.visual.model:FindFirstChild("HitFlash") :: Highlight?
			if not hl then
				hl = Instance.new("Highlight")
				hl.Name = "HitFlash"
				hl.FillColor = Color3.new(1, 1, 1)
				hl.OutlineTransparency = 1
				hl.DepthMode = Enum.HighlightDepthMode.Occluded
				hl.Parent = it.visual.model
			end
			hl.FillTransparency = 1 - math.clamp(it.flash / 0.12, 0, 1) * 0.6
			hl.Enabled = it.flash > 0
		end
		if it.hpSet then
			local hp, mx = anchor:GetAttribute("HP") or 0, anchor:GetAttribute("MaxHP") or 1
			it.hpSet(hp / math.max(1, mx), if it.kind ~= "Mob" then Format.Short(hp) else nil)
			if it.plate then
				it.plate.Enabled = it.kind ~= "Mob" or hp < mx or d < 40
			end
		end
		if it.kind ~= "Mob" and d < nearestD and state ~= "Sleep" then
			nearestBoss, nearestD = it, d
		end
	end
	-- grande barre de boss / gardien
	if nearestBoss then
		local a = nearestBoss.anchor
		bossBar.Visible = true
		local hp, mx = a:GetAttribute("HP") or 0, a:GetAttribute("MaxHP") or 1
		bossSet(hp / math.max(1, mx), Format.Short(hp) .. " / " .. Format.Short(mx))
		bossName.Text = a:GetAttribute("Name") or ""
		local ph = a:GetAttribute("Phase")
		bossPhase.Text = if ph and nearestBoss.kind == "Boss" then "Phase " .. ph .. "/3" else ""
		local def = nearestBoss.def
		local bar = bossBar:FindFirstChild("Bar")
		local fill = bar and bar:FindFirstChild("Fill") :: Frame?
		if fill and def and def.phases and ph and def.phases[ph] then
			fill.BackgroundColor3 = def.phases[ph]
		end
	else
		bossBar.Visible = false
	end
end

local function bossRecap(p)
	if not p or not p.ended then
		return
	end
	local share = p.share or 0
	C.HUD.Toast(string.format("%s vaincu ! Ta part : %.1f %%%s", p.name or "Boss", share * 100, if p.chest then " · coffre obtenu" else ""), "Success")
end

function EnemiesCtl.Init(controllers)
	C = controllers
	folder = Instance.new("Folder")
	folder.Name = "EnemyVisuals"
	folder.Parent = Workspace
end

function EnemiesCtl.Start()
	local root = C.HUD.root
	bossBar = Kit.Panel(root, { Name = "BossBar", Size = UDim2.fromOffset(460, 54), Position = UDim2.new(0.5, 0, 0, 128), AnchorPoint = Vector2.new(0.5, 0), Color = Color3.fromRGB(40, 12, 20), StrokeColor = Theme.Color.Error, Visible = false })
	bossName = Kit.Label(bossBar, { Text = "", Size = UDim2.new(0.7, 0, 0, 22), Position = UDim2.fromOffset(12, 4), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Title, Color = Color3.fromRGB(255, 200, 200) })
	bossPhase = Kit.Label(bossBar, { Text = "", Size = UDim2.new(0.3, -12, 0, 20), Position = UDim2.new(0.7, 0, 0, 5), AlignX = Enum.TextXAlignment.Right, Font = Theme.Font.Body, Color = Theme.Color.Gold })
	local _, set = Kit.Bar(bossBar, { Name = "Bar", Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, 30), Color = Color3.fromRGB(255, 70, 70), Smooth = true })
	bossSet = set
	CollectionService:GetInstanceAddedSignal("Entity"):Connect(watch)
	for _, e in CollectionService:GetTagged("Entity") do
		task.spawn(watch, e)
	end
	Net.Event("BossState").OnClientEvent:Connect(bossRecap)
	RunService.RenderStepped:Connect(step)
end

return EnemiesCtl
