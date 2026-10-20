--!nonstrict
-- Rendu des héros dans le monde (entièrement côté client) :
--   socles des bases et des camps, coffre, gardien, statue de prestige, héros sauvages / au sol / défenseurs de duel,
--   leaders qui accompagnent chaque joueur, héros portés au-dessus de la tête.
-- Budget de modèles selon la qualité graphique (les plus proches d'abord) et créations étalées dans le temps.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Util.Format)
local HeroMath = require(Shared.Logic.HeroMath)
local Factory = require(Shared.Visuals.HeroModelFactory)
local HeroAnimator = require(Shared.Visuals.HeroAnimator)
local HeroFX = require(Shared.Visuals.HeroFX)

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local player = Players.LocalPlayer

local HeroDisplay = {}
local C

local BUDGET = { High = 70, Medium = 45, Low = 24 }
local RADIUS = { High = 260, Medium = 190, Low = 130 }
local ANIM_RADIUS = 140
local HIGHLIGHT_MAX = 10
local quality = "High"

local folder: Folder
type Slot = {
	key: string,
	kind: string,
	source: any,
	heroId: string?,
	mut: { string },
	height: number,
	priority: number,
	rig: any?,
	animator: any?,
	fxFolder: Instance?,
	fxUpdate: ((number) -> ())?,
	mutFx: { Instance },
	plate: BillboardGui?,
	plateUpdate: (() -> ())?,
	cf: CFrame?,
	lastPos: Vector3?,
	speed: number,
	lastState: string?,
	highlight: boolean,
	signature: string,
}
local slots: { [string]: Slot } = {}
local hitStopUntil = 0
local creating = 0

local function parseMut(s: any): { string }
	if typeof(s) ~= "string" or s == "" then
		return {}
	end
	return string.split(s, ",")
end

local function camPos(): Vector3
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

local function flatLook(cf: CFrame): Vector3
	local lv = cf.LookVector
	local f = Vector3.new(lv.X, 0, lv.Z)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

-- ============================================================================ Création / destruction des modèles
local function destroyVisual(s: Slot)
	if s.rig then
		s.rig.model:Destroy()
		s.rig = nil
	end
	if s.fxFolder then
		s.fxFolder:Destroy()
		s.fxFolder = nil
		s.fxUpdate = nil
	end
	if s.plate then
		s.plate:Destroy()
		s.plate = nil
		s.plateUpdate = nil
	end
	s.animator = nil
	s.mutFx = {}
	s.highlight = false
end

local function statueLook(rig: any, tier: number)
	local color = if tier >= 3 then Color3.fromRGB(170, 230, 255) elseif tier == 2 then Color3.fromRGB(255, 200, 80) else Color3.fromRGB(200, 200, 195)
	local mat = if tier >= 3 then Enum.Material.Glass elseif tier == 2 then Enum.Material.Foil else Enum.Material.Marble
	for _, d in rig.model:GetDescendants() do
		if d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") then
			d:Destroy()
		elseif d:IsA("MeshPart") then
			d.TextureID = ""
			d.Material = mat
			d.Color = color
		elseif d:IsA("BasePart") then
			d.Material = mat
			d.Color = color
		end
	end
end

-- Étiquette au-dessus d'un héros exposé (nom, étoiles, production, mutations).
local function pedestalPlate(s: Slot, part: BasePart): (BillboardGui, () -> ())
	local def = Heroes.Get(s.heroId :: string)
	local r = Rarities.Get(def.rarity)
	local bb = Kit.new("BillboardGui", { Name = "Plate", Size = UDim2.fromOffset(170, 58), StudsOffsetWorldSpace = Vector3.new(0, s.height + 1.6, 0), MaxDistance = 48, LightInfluence = 0, AlwaysOnTop = false, Adornee = part, Parent = folder })
	local name = Kit.Label(bb, { Text = def.name, Size = UDim2.new(1, 0, 0.4, 0), Font = Theme.Font.Title, Color = if def.rarity == "Common" then Theme.Color.Text else r.color:Lerp(Color3.new(1, 1, 1), 0.25) })
	local info = Kit.Label(bb, { Text = "", Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.fromScale(0, 0.4), Font = Theme.Font.Body, Color = Theme.Color.Gold })
	local mut = Kit.Label(bb, { Text = "", Rich = true, Size = UDim2.new(1, 0, 0.28, 0), Position = UDim2.fromScale(0, 0.7), Font = Theme.Font.Body })
	local _ = name
	local function upd()
		local stars = part:GetAttribute("Stars") or 0
		local lvl = part:GetAttribute("Lvl") or 1
		local prod = part:GetAttribute("Prod")
		info.Text = Kit.Stars(stars) .. "  Niv." .. lvl .. (if prod then "  ⚡" .. Format.Short(prod) .. "/s" else "")
		mut.Text = Kit.MutationText(s.mut)
	end
	upd()
	return bb, upd
end

-- Étiquette d'un héros sauvage / défenseur : nom, rareté, niveau, PV, compte à rebours au sol.
local function entityPlate(s: Slot, anchor: BasePart): (BillboardGui, () -> ())
	local def = Heroes.Get(s.heroId :: string)
	local r = Rarities.Get(def.rarity)
	local bb = Kit.new("BillboardGui", { Name = "Plate", Size = UDim2.fromOffset(180, 66), StudsOffsetWorldSpace = Vector3.new(0, s.height * 0.5 + 2.2, 0), MaxDistance = 110, LightInfluence = 0, AlwaysOnTop = true, Adornee = anchor, Parent = folder })
	local name = Kit.Label(bb, { Text = def.name, Size = UDim2.new(1, 0, 0.34, 0), Font = Theme.Font.Title, Color = if def.rarity == "Common" then Theme.Color.Text else r.color:Lerp(Color3.new(1, 1, 1), 0.2) })
	local sub = Kit.Label(bb, { Text = "", Size = UDim2.new(1, 0, 0.24, 0), Position = UDim2.fromScale(0, 0.34), Font = Theme.Font.Body, Color = r.color:Lerp(Color3.new(1, 1, 1), 0.5) })
	local barFrame, barSet = Kit.Bar(bb, { Size = UDim2.new(0.86, 0, 0.2, 0), Position = UDim2.fromScale(0.07, 0.62), Color = Color3.fromRGB(255, 90, 90) })
	Kit.Label(bb, { Text = Kit.MutationText(s.mut), Rich = true, Size = UDim2.new(1, 0, 0.18, 0), Position = UDim2.fromScale(0, 0.84), Font = Theme.Font.Body })
	local _ = name
	local function upd()
		local lvl = anchor:GetAttribute("Level") or 1
		local kind = anchor:GetAttribute("Kind")
		local hp, maxHp = anchor:GetAttribute("HP") or 0, anchor:GetAttribute("MaxHP") or 1
		if kind == "Downed" or anchor:GetAttribute("State") == "Downed" then
			local left = (anchor:GetAttribute("DownUntil") or 0) - Workspace:GetServerTimeNow()
			sub.Text = "À TERRE · " .. string.format("%.0f s", math.max(0, left))
			sub.TextColor3 = Theme.Color.Gold
			barSet(math.clamp(left / 8, 0, 1), "")
			local fill = barFrame:FindFirstChild("Fill") :: Frame
			fill.BackgroundColor3 = Theme.Color.Gold
		else
			sub.Text = r.name.fr .. " · Niv." .. lvl .. (if kind == "Defender" then " · défenseur" else "")
			sub.TextColor3 = r.color:Lerp(Color3.new(1, 1, 1), 0.5)
			barSet(hp / math.max(1, maxHp), Format.Short(hp))
			local fill = barFrame:FindFirstChild("Fill") :: Frame
			fill.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
		end
	end
	upd()
	return bb, upd
end

local function createVisual(s: Slot)
	if not s.heroId or not Heroes.List[s.heroId] then
		return
	end
	local ok, rig = pcall(Factory.Create, s.heroId, s.height)
	if not ok then
		warn("[HeroDisplay] " .. tostring(rig))
		return
	end
	local def = Heroes.Get(s.heroId)
	rig.model.Parent = folder
	s.rig = rig
	s.mutFx = {}
	if s.kind ~= "Statue" then
		s.animator = HeroAnimator.new(rig, def.kit)
		HeroFX.CrystalGlow(rig, Color3.fromHex(def.crystal))
		if #s.mut > 0 then
			s.mutFx = HeroFX.Mutations(rig.model, s.mut, false)
		end
	else
		statueLook(rig, s.source:GetAttribute("Tier") or 1)
	end
	if s.kind == "Pedestal" or s.kind == "Camp" then
		local part = s.source :: BasePart
		local top = Vector3.new(part.Position.X, (part:GetAttribute("TopY") or part.Position.Y) - 0.05, part.Position.Z)
		local base = CFrame.lookAt(top, top + flatLook(part.CFrame))
		s.fxFolder, s.fxUpdate = HeroFX.Display(folder, base, def.rarity, s.height, quality)
		s.plate, s.plateUpdate = pedestalPlate(s, part)
	elseif s.kind == "Entity" then
		local anchor = s.source :: BasePart
		s.plate, s.plateUpdate = entityPlate(s, anchor)
		if Rarities.AtLeast(def.rarity, "Legendary") then
			local l = Instance.new("PointLight")
			l.Color = Rarities.Get(def.rarity).color
			l.Range = 18
			l.Brightness = 2
			l.Parent = rig.root
		end
	elseif s.kind == "Carried" then
		local l = Instance.new("PointLight")
		l.Color = Rarities.Get(def.rarity).color
		l.Range = 14
		l.Brightness = 1.6
		l.Parent = rig.root
		local anim = s.animator :: any
		anim:SetState("Carried")
	end
	if s.animator and (s.kind == "Pedestal" or s.kind == "Camp" or s.kind == "Vault") then
		(s.animator :: any):SetState("Display")
	end
end

-- ============================================================================ Repères (pieds) et états par type
local plotFacing: { [number]: Vector3 } = {}

local function slotCF(s: Slot, dt: number): (CFrame?, string?)
	local src = s.source
	local kind = s.kind
	if kind == "Pedestal" or kind == "Camp" or kind == "Vault" or kind == "Guardian" or kind == "Statue" then
		if not src.Parent then
			return nil
		end
		local part = src :: BasePart
		local topY = part:GetAttribute("TopY") or (part.Position.Y + part.Size.Y / 2)
		local look = flatLook(part.CFrame)
		if kind == "Vault" then
			look = plotFacing[part:GetAttribute("PlotIndex") or 0] or look
		elseif kind == "Guardian" or kind == "Statue" then
			topY = part.Position.Y + part.Size.Y / 2
		end
		local top = Vector3.new(part.Position.X, topY, part.Position.Z)
		return CFrame.lookAt(top, top + look), (if kind == "Guardian" then "Idle" else "Display")
	elseif kind == "Entity" then
		local anchor = src :: BasePart
		if not anchor.Parent then
			return nil
		end
		local hover = anchor:GetAttribute("Hover") or s.height * 0.5
		local target = anchor.CFrame * CFrame.new(0, -hover, 0)
		local prev = s.cf or target
		local cf = prev:Lerp(target, 1 - math.exp(-dt * 14))
		local st = anchor:GetAttribute("State") or "Idle"
		local kindAttr = anchor:GetAttribute("Kind")
		local state = "Idle"
		if st == "Downed" or kindAttr == "Downed" then
			state = "Downed"
		elseif s.speed > 13 then
			state = "Run"
		elseif s.speed > 1.5 then
			state = "Walk"
		end
		return cf, state
	elseif kind == "Companion" then
		local p = src :: Player
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then
			return nil
		end
		local feetY = hrp.Position.Y - hum.HipHeight - hrp.Size.Y / 2
		local lv = flatLook(hrp.CFrame)
		local right = Vector3.new(-lv.Z, 0, lv.X)
		local side = math.max(3, s.height * 0.45)
		local goal = Vector3.new(hrp.Position.X, feetY, hrp.Position.Z) + right * side - lv * 2.5
		local prev = s.cf and s.cf.Position or goal
		local pos = prev:Lerp(goal, 1 - math.exp(-dt * 6))
		-- rester au niveau du sol du joueur
		pos = Vector3.new(pos.X, feetY + (pos.Y - feetY) * 0.2, pos.Z)
		local moveDir = Vector3.new(pos.X - prev.X, 0, pos.Z - prev.Z)
		local face = if moveDir.Magnitude > 0.02 then moveDir.Unit else lv
		local prevLook = if s.cf then flatLook(s.cf) else face
		local look = prevLook:Lerp(face, 1 - math.exp(-dt * 8))
		if look.Magnitude < 0.01 then
			look = face
		end
		local speed = hrp.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local state = if speed.Magnitude > 18 then "Run" elseif speed.Magnitude > 2 then "Walk" else "Idle"
		return CFrame.lookAt(pos, pos + look.Unit), state
	elseif kind == "Assist" then
		-- assistants : petite escorte derrière le joueur (gauche, centre, droite)
		local p = src :: Player
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 or p:GetAttribute("Carrying") then
			return nil
		end
		local i = tonumber(string.match(s.key, ":(%d+)$")) or 1
		local feetY = hrp.Position.Y - hum.HipHeight - hrp.Size.Y / 2
		local lv = flatLook(hrp.CFrame)
		local right = Vector3.new(-lv.Z, 0, lv.X)
		local lateral = ({ -4.5, 0, 4.5 })[i] or 0
		local goal = Vector3.new(hrp.Position.X, feetY, hrp.Position.Z) + right * lateral - lv * (6 + (if i == 2 then 2 else 0))
		local prev = s.cf and s.cf.Position or goal
		local pos = prev:Lerp(goal, 1 - math.exp(-dt * 5))
		pos = Vector3.new(pos.X, feetY + (pos.Y - feetY) * 0.2, pos.Z)
		local moveDir = Vector3.new(pos.X - prev.X, 0, pos.Z - prev.Z)
		local face = if moveDir.Magnitude > 0.02 then moveDir.Unit else lv
		local speed = hrp.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local state = if speed.Magnitude > 18 then "Run" elseif speed.Magnitude > 2 then "Walk" else "Idle"
		return CFrame.lookAt(pos, pos + face), state
	elseif kind == "Carried" then
		local p = src :: Player
		local char = p.Character
		local head = char and char:FindFirstChild("Head") :: BasePart?
		if not head then
			return nil
		end
		local top = head.Position + Vector3.new(0, head.Size.Y / 2 + 0.6, 0)
		return CFrame.lookAt(top, top + flatLook(head.CFrame)), "Carried"
	end
	return nil
end

-- ============================================================================ Inventaire des emplacements
local function setSlot(key: string, kind: string, source: any, heroId: string?, mut: { string }, height: number, priority: number)
	local s = slots[key]
	local sig = tostring(heroId) .. "|" .. table.concat(mut, ",") .. "|" .. string.format("%.2f", height)
	if s and s.signature == sig then
		return
	end
	if s then
		destroyVisual(s)
	end
	if not heroId then
		slots[key] = nil
		return
	end
	slots[key] = {
		key = key,
		kind = kind,
		source = source,
		heroId = heroId,
		mut = mut,
		height = height,
		priority = priority,
		mutFx = {},
		speed = 0,
		highlight = false,
		signature = sig,
	}
end

local function removeSlot(key: string)
	local s = slots[key]
	if s then
		destroyVisual(s)
		slots[key] = nil
	end
end

local function heightFor(heroId: string, cap: number?): number
	local h = HeroMath.DisplayHeight(heroId, true)
	if cap then
		h = math.min(h, cap)
	end
	return h
end

-- Socles (bases et camps)
-- Pièces déjà surveillées : avec StreamingEnabled une pièce peut sortir puis revenir (le signal d'étiquette se
-- redéclenche) ; on ne s'abonne qu'une fois et on se désabonne quand elle quitte le Workspace.
local watched: { [Instance]: { RBXScriptConnection } } = {}

local function beginWatch(inst: Instance): { RBXScriptConnection }?
	if watched[inst] then
		return nil
	end
	local list = {}
	watched[inst] = list
	return list
end

local function endWatch(inst: Instance)
	local list = watched[inst]
	if list then
		watched[inst] = nil
		for _, c in list do
			c:Disconnect()
		end
	end
end

local function watchPedestal(part: Instance, kind: string)
	if not part:IsA("BasePart") then
		return
	end
	local conns = beginWatch(part)
	if not conns then
		return
	end
	local key = kind .. ":" .. part:GetFullName()
	local function refresh()
		local heroId = part:GetAttribute("HeroId")
		if heroId and not Heroes.List[heroId] then
			heroId = nil
		end
		if part:GetAttribute("Dueling") or part:GetAttribute("InTransit") then
			heroId = nil
		end
		if heroId then
			local pi = part:GetAttribute("PlotIndex")
			if pi and not plotFacing[pi] then
				plotFacing[pi] = flatLook(part.CFrame)
			end
		end
		setSlot(key, kind, part, heroId, parseMut(part:GetAttribute("Mut")), if heroId then heightFor(heroId) else 0, 0)
		local s = slots[key]
		if s and s.plateUpdate then
			s.plateUpdate()
		end
	end
	table.insert(conns, part.AttributeChanged:Connect(function(name)
		if name == "HeroId" or name == "Mut" or name == "Dueling" or name == "InTransit" then
			refresh()
		elseif name == "Stars" or name == "Lvl" or name == "Prod" then
			local s = slots[key]
			if s and s.plateUpdate then
				s.plateUpdate()
			end
		end
	end))
	table.insert(conns, part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(Workspace) then
			removeSlot(key)
			endWatch(part)
		end
	end))
	refresh()
end

local function watchSpot(part: Instance, kind: string, cap: number)
	if not part:IsA("BasePart") then
		return
	end
	local conns = beginWatch(part)
	if not conns then
		return
	end
	local key = kind .. ":" .. part:GetFullName()
	local function refresh()
		local heroId = part:GetAttribute("HeroId")
		if heroId and not Heroes.List[heroId] then
			heroId = nil
		end
		local h = 0
		if heroId then
			h = heightFor(heroId, cap)
			if kind == "Statue" then
				h = math.min(cap, h) * (1 + 0.15 * (((part:GetAttribute("Tier") or 1) :: number) - 1))
			end
		end
		local extra = if kind == "Statue" then { tostring(part:GetAttribute("Tier") or 1) } else parseMut(part:GetAttribute("Mut"))
		setSlot(key, kind, part, heroId, if kind == "Statue" then {} else extra, h, 0)
	end
	table.insert(conns, part.AttributeChanged:Connect(function(name)
		if name == "HeroId" or name == "Mut" or name == "Tier" then
			if kind == "Statue" then
				removeSlot(key)
			end
			refresh()
		end
	end))
	table.insert(conns, part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(Workspace) then
			removeSlot(key)
			endWatch(part)
		end
	end))
	refresh()
end

-- Entités héros (sauvages, au sol, défenseurs de duel)
local HERO_KINDS = { Wild = true, Defender = true, Dropped = true, Downed = true }

local function watchEntity(anchor: Instance)
	if not anchor:IsA("BasePart") then
		return
	end
	local kind = anchor:GetAttribute("Kind")
	local ref = anchor:GetAttribute("Ref")
	if not HERO_KINDS[kind] or not ref or not Heroes.List[ref] then
		return
	end
	local conns = beginWatch(anchor)
	if not conns then
		return
	end
	local key = "Entity:" .. tostring(anchor:GetAttribute("EntityId"))
	local function refresh()
		local scale = anchor:GetAttribute("Scale") or Heroes.Get(ref).size
		setSlot(key, "Entity", anchor, ref, parseMut(anchor:GetAttribute("Mut")), scale * 5, 3)
	end
	refresh()
	table.insert(conns, anchor.AttributeChanged:Connect(function(name)
		local s = slots[key]
		if name == "Mut" then
			refresh()
		elseif name == "State" and s and s.animator then
			local st = anchor:GetAttribute("State")
			if st == "Attack" then
				s.animator:Play("Attack")
			elseif st == "Skill" then
				s.animator:Play("Skill")
			end
		elseif (name == "HP" or name == "Kind" or name == "DownUntil") and s and s.plateUpdate then
			s.plateUpdate()
		end
	end))
	table.insert(conns, anchor.AncestryChanged:Connect(function()
		if not anchor:IsDescendantOf(Workspace) then
			removeSlot(key)
			endWatch(anchor)
		end
	end))
end

-- Leaders et héros portés de chaque joueur
local function watchPlayer(p: Player)
	local function refreshLeader()
		local id = p:GetAttribute("LeaderHero")
		if id and not Heroes.List[id] then
			id = nil
		end
		local h = if id then math.min(Heroes.Get(id).size * 5, 7.5) else 0
		setSlot("Companion:" .. p.UserId, "Companion", p, id, parseMut(p:GetAttribute("LeaderMut")), h, if p == player then 5 else 2)
	end
	local function refreshCarry()
		local id = p:GetAttribute("Carrying")
		if id and not Heroes.List[id] then
			id = nil
		end
		local h = if id then math.clamp(Heroes.Get(id).size * 5 * 0.55, 2.5, 5) else 0
		setSlot("Carried:" .. p.UserId, "Carried", p, id, parseMut(p:GetAttribute("CarryMut")), h, 6)
	end
	-- assistants (attribut « Assists » : ids séparés par des virgules)
	local function refreshAssists()
		local raw = p:GetAttribute("Assists")
		local ids = if typeof(raw) == "string" and raw ~= "" then string.split(raw, ",") else {}
		for i = 1, 3 do
			local id = ids[i]
			if id and not Heroes.List[id] then
				id = nil
			end
			local h = if id then math.min(Heroes.Get(id).size * 3.6, 5) else 0
			setSlot("Assist:" .. p.UserId .. ":" .. i, "Assist", p, id, {}, h, if p == player then 3 else 1)
		end
	end
	p:GetAttributeChangedSignal("Assists"):Connect(refreshAssists)
	refreshAssists()
	p:GetAttributeChangedSignal("LeaderHero"):Connect(refreshLeader)
	p:GetAttributeChangedSignal("LeaderMut"):Connect(refreshLeader)
	p:GetAttributeChangedSignal("Carrying"):Connect(refreshCarry)
	p:GetAttributeChangedSignal("CarryMut"):Connect(refreshCarry)
	refreshLeader()
	refreshCarry()
end

-- ============================================================================ API
-- Courte pause de l'animation du leader local (coup porté).
function HeroDisplay.HitStop(duration: number)
	hitStopUntil = math.max(hitStopUntil, os.clock() + duration)
end

function HeroDisplay.PlayLeader(anim: string)
	HeroDisplay.PlayCompanion(player.UserId, anim)
end

function HeroDisplay.PlayCompanion(userId: number, anim: string)
	local s = slots["Companion:" .. userId]
	if s and s.animator then
		s.animator:Play(anim)
	end
end

-- Animation ponctuelle d'un héros exposé sur un socle (par ex. alerte de vol).
function HeroDisplay.AlertPedestals(plotIndex: number)
	for _, s in slots do
		if s.kind == "Pedestal" and s.animator and s.source:GetAttribute("PlotIndex") == plotIndex then
			s.animator:Play("Alert")
		end
	end
end

-- ============================================================================ Boucles
local function lodPass()
	local cp = camPos()
	local budget = BUDGET[quality] or 60
	local radius = RADIUS[quality] or 220
	local list = {}
	for _, s in slots do
		local pos
		local src = s.source
		if typeof(src) == "Instance" and src:IsA("BasePart") then
			pos = src.Position
		elseif typeof(src) == "Instance" and src:IsA("Player") then
			local ch = src.Character
			local r = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
			pos = r and r.Position
		end
		if pos then
			local d = (pos - cp).Magnitude
			table.insert(list, { s = s, score = d - s.priority * 40, d = d })
		elseif s.rig then
			destroyVisual(s)
		end
	end
	table.sort(list, function(a, b)
		return a.score < b.score
	end)
	local highlights = 0
	for i, item in list do
		local s = item.s
		local want = i <= budget and item.d <= radius * (if s.priority >= 3 then 1.4 else 1)
		if want and not s.rig then
			if creating < 3 then
				creating += 1
				createVisual(s)
			end
		elseif not want and s.rig then
			destroyVisual(s)
		end
		-- contour des mutations : seulement pour les plus proches
		if s.rig and #s.mut > 0 then
			local wantHl = highlights < HIGHLIGHT_MAX and item.d < 70
			if wantHl then
				highlights += 1
			end
			if wantHl ~= s.highlight then
				s.highlight = wantHl
				local hl = s.rig.model:FindFirstChild("MutationHighlight")
				if wantHl and not hl then
					local created = HeroFX.Mutations(s.rig.model, { s.mut[1] }, true)
					for _, inst in created do
						if inst:IsA("ParticleEmitter") then
							inst:Destroy()
						else
							table.insert(s.mutFx, inst)
						end
					end
				elseif not wantHl and hl then
					hl:Destroy()
				end
			end
		end
	end
	creating = 0
end

local rainbowT = 0
local function step(dt: number)
	local cp = camPos()
	rainbowT += dt
	local t = os.clock()
	for _, s in slots do
		local rig = s.rig
		if rig then
			local cf, state = slotCF(s, dt)
			if not cf then
				rig.model.Parent = nil
			else
				if rig.model.Parent ~= folder then
					rig.model.Parent = folder
				end
				-- vitesse estimée (entités)
				if s.lastPos then
					local v = (Vector3.new(cf.X, 0, cf.Z) - Vector3.new(s.lastPos.X, 0, s.lastPos.Z)).Magnitude / math.max(dt, 1e-3)
					s.speed += (v - s.speed) * math.min(1, dt * 6)
				end
				s.lastPos = cf.Position
				s.cf = cf
				local near = (cf.Position - cp).Magnitude < ANIM_RADIUS
				local offset = CFrame.new()
				if s.animator and near then
					if state and state ~= s.lastState then
						s.animator:SetState(state)
						s.lastState = state
					end
					-- arrêt sur image du leader local quand il touche (bible §13)
					local frozen = hitStopUntil > os.clock() and s.key == "Companion:" .. player.UserId
					offset = s.animator:Step(if frozen then 0 else dt)
				elseif s.animator and s.lastState ~= "Far" then
					s.animator:Reset()
					s.lastState = "Far"
				end
				rig.model:PivotTo(cf * offset)
				if s.fxUpdate and near then
					s.fxUpdate(t)
				end
				if s.highlight then
					local hl = rig.model:FindFirstChild("MutationHighlight") :: Highlight?
					if hl and hl:GetAttribute("Rainbow") then
						local c = Color3.fromHSV((rainbowT * 0.2) % 1, 0.7, 1)
						hl.FillColor = c
						hl.OutlineColor = c
					end
				end
			end
		end
	end
end

function HeroDisplay.Init(controllers)
	C = controllers
	folder = Instance.new("Folder")
	folder.Name = "HeroDisplays"
	folder.Parent = Workspace
end

function HeroDisplay.Start()
	local function onTag(tag: string, fn: (Instance) -> ())
		CollectionService:GetInstanceAddedSignal(tag):Connect(fn)
		for _, inst in CollectionService:GetTagged(tag) do
			task.spawn(fn, inst)
		end
	end
	onTag("Pedestal", function(p)
		watchPedestal(p, "Pedestal")
	end)
	onTag("CampPedestal", function(p)
		watchPedestal(p, "Camp")
	end)
	onTag("VaultPedestal", function(p)
		watchSpot(p, "Vault", 6)
	end)
	-- statues de l'Allée des Héros gelés (Glacier) : le héros est rendu dans sa gangue de glace
	onTag("FrozenStatue", function(p)
		watchSpot(p, "Vault", 4.4)
	end)
	onTag("GuardianSpot", function(p)
		watchSpot(p, "Guardian", 9)
	end)
	onTag("StatueSpot", function(p)
		watchSpot(p, "Statue", 9)
	end)
	onTag("Entity", watchEntity)
	for _, p in Players:GetPlayers() do
		task.spawn(watchPlayer, p)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(p)
		removeSlot("Companion:" .. p.UserId)
		removeSlot("Carried:" .. p.UserId)
		for i = 1, 3 do
			removeSlot("Assist:" .. p.UserId .. ":" .. i)
		end
	end)
	C.Data.Changed:Connect(function(d)
		local q = d and d.settings and d.settings.quality
		if q and q ~= quality then
			quality = q
			for _, s in slots do
				destroyVisual(s)
			end
		end
	end)
	task.spawn(function()
		while true do
			lodPass()
			task.wait(0.35)
		end
	end)
	-- plaques des entités (PV, compte à rebours)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, s in slots do
				if s.kind == "Entity" and s.plateUpdate then
					s.plateUpdate()
				end
			end
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return HeroDisplay
