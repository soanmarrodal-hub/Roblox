--!nonstrict
-- Combat côté client : pavé tactile (attaque, 3 compétences du leader, esquive, saut), raccourcis clavier/manette,
-- verrouillage de cible, recharges, impulsions (dash, esquive, recul) et secousses de caméra.
-- Le serveur reste seul juge des dégâts (CombatService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Heroes = require(Shared.Config.Heroes)
local Skills = require(Shared.Config.Skills)
local Islands = require(Shared.Config.Islands)
local Locale = require(Shared.Locale)

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local player = Players.LocalPlayer

local Combat = {}
local C
local buttons: { [string]: TextButton } = {}
local cooldownSetters: { [string]: (number, string?) -> () } = {}
local chargeRing: Frame
local lastAttack = 0
local lastDodge = 0
local ATTACK_CD = Skills.Get("BasicAttack").cooldown
local DODGE_CD = 1.2
local lockedId: number? = nil
local lockMarker: BillboardGui
local shakeAmount = 0
local shakeEnabled = true
local lastHealth = 0

local HOSTILE = { Mob = true, Boss = true, Guardian = true, Wild = true, Defender = true }

-- ============================================================================ Outils
local function root(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoid(): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function leaderDef(): any
	local id = player:GetAttribute("LeaderHero")
	return id and Heroes.List[id]
end

local function skillFor(slot: number): any
	local def = leaderDef()
	if not def then
		return nil
	end
	if slot == 1 then
		return Skills.List[Heroes.Roles[def.role].roleSkill]
	elseif slot == 2 then
		return Skills.List[Skills.ElementByIsland[def.island]]
	end
	return Skills.List[def.signature]
end

local function entityById(id: number): BasePart?
	for _, e in CollectionService:GetTagged("Entity") do
		if e:GetAttribute("EntityId") == id then
			return e :: BasePart
		end
	end
	return nil
end

-- Une entité peut-elle être frappée par le joueur ? (les défenseurs/sauvages au sol ne le sont pas)
local function attackable(e: Instance): boolean
	local kind = e:GetAttribute("Kind")
	if not HOSTILE[kind] then
		return false
	end
	if (e:GetAttribute("HP") or 0) <= 0 then
		return false
	end
	local st = e:GetAttribute("State")
	return st ~= "Dead" and st ~= "Downed"
end

-- Direction de visée : souris sur PC, cible verrouillée ou devant le personnage sur mobile.
local function aimDirection(): Vector3
	local r = root()
	if not r then
		return Vector3.new(0, 0, -1)
	end
	if lockedId then
		local e = entityById(lockedId)
		if e then
			local d = e.Position - r.Position
			d = Vector3.new(d.X, 0, d.Z)
			if d.Magnitude > 0.1 then
				return d.Unit
			end
		end
	end
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local m = UserInputService:GetMouseLocation()
		local cam = Workspace.CurrentCamera
		local ray = cam:ViewportPointToRay(m.X, m.Y)
		-- intersection avec le plan horizontal du personnage
		if math.abs(ray.Direction.Y) > 1e-3 then
			local t = (r.Position.Y - 2 - ray.Origin.Y) / ray.Direction.Y
			if t > 0 then
				local hit = ray.Origin + ray.Direction * t
				local d = Vector3.new(hit.X - r.Position.X, 0, hit.Z - r.Position.Z)
				if d.Magnitude > 1 then
					return d.Unit
				end
			end
		end
	end
	local hum = humanoid()
	if hum and hum.MoveDirection.Magnitude > 0.1 then
		return hum.MoveDirection.Unit
	end
	local lv = r.CFrame.LookVector
	return Vector3.new(lv.X, 0, lv.Z).Unit
end

-- Choisit automatiquement la meilleure cible (devant, proche) si rien n'est verrouillé.
local function autoTarget(range: number): number?
	local r = root()
	if not r then
		return nil
	end
	if lockedId then
		local e = entityById(lockedId)
		if e and attackable(e) and (e.Position - r.Position).Magnitude < range * 1.5 then
			return lockedId
		end
		lockedId = nil
	end
	local fwd = aimDirection()
	local best, bestScore = nil, math.huge
	for _, e in CollectionService:GetTagged("Entity") do
		if e:IsA("BasePart") and attackable(e) then
			local d = e.Position - r.Position
			local dist = d.Magnitude
			if dist < range then
				local flat = Vector3.new(d.X, 0, d.Z)
				local facing = if flat.Magnitude > 0.1 then fwd:Dot(flat.Unit) else 1
				local score = dist * (1.6 - facing * 0.6)
				if score < bestScore then
					best, bestScore = e:GetAttribute("EntityId"), score
				end
			end
		end
	end
	return best
end

local function faceDirection(dir: Vector3)
	local r = root()
	if r and dir.Magnitude > 0.1 then
		r.CFrame = CFrame.lookAt(r.Position, r.Position + Vector3.new(dir.X, 0, dir.Z))
	end
end

-- ============================================================================ Actions
function Combat.Attack()
	if os.clock() - lastAttack < ATTACK_CD then
		return
	end
	if player:GetAttribute("Carrying") then
		return
	end
	lastAttack = os.clock()
	local target = autoTarget(40)
	local dir = aimDirection()
	if target then
		local e = entityById(target)
		local r = root()
		if e and r then
			local d = e.Position - r.Position
			if Vector3.new(d.X, 0, d.Z).Magnitude > 0.1 then
				dir = Vector3.new(d.X, 0, d.Z).Unit
			end
		end
	end
	faceDirection(dir)
	Net.Event("Attack"):FireServer(dir, target)
	if C.HeroDisplay then
		C.HeroDisplay.PlayLeader("Attack")
	end
	C.Sound.Play("Slash", nil, 0.2)
end

function Combat.Skill(slot: number)
	local skill = skillFor(slot)
	if not skill then
		C.HUD.Toast("Choisis un leader dans le menu Équipe", "Info")
		return
	end
	if player:GetAttribute("Carrying") then
		C.HUD.Toast("Impossible en portant un héros", "Error")
		return
	end
	local cdEnd = player:GetAttribute("CD" .. slot) or 0
	if Workspace:GetServerTimeNow() < cdEnd - 0.05 then
		return
	end
	if slot == 3 and (player:GetAttribute("Charge") or 0) < (skill.charge or 100) then
		C.HUD.Toast("Signature pas encore chargée", "Info")
		return
	end
	local target = autoTarget(60)
	local dir = aimDirection()
	if target then
		local e = entityById(target)
		local r = root()
		if e and r then
			local d = e.Position - r.Position
			if Vector3.new(d.X, 0, d.Z).Magnitude > 0.1 then
				dir = Vector3.new(d.X, 0, d.Z).Unit
			end
		end
	end
	faceDirection(dir)
	Net.Event("Skill"):FireServer(slot, dir, target)
	if C.HeroDisplay then
		C.HeroDisplay.PlayLeader("Skill")
	end
	C.Sound.Play("Skill")
end

function Combat.Dodge()
	if os.clock() - lastDodge < DODGE_CD then
		return
	end
	lastDodge = os.clock()
	local hum = humanoid()
	local dir = if hum and hum.MoveDirection.Magnitude > 0.1 then hum.MoveDirection.Unit else aimDirection()
	Net.Event("Dodge"):FireServer(dir)
end

function Combat.Jump()
	local hum = humanoid()
	if hum then
		hum.Jump = true
	end
end

function Combat.Shake(amount: number)
	if shakeEnabled then
		shakeAmount = math.max(shakeAmount, amount)
	end
end

function Combat.LockedId(): number?
	return lockedId
end

function Combat.SetLock(id: number?)
	lockedId = id
end

-- Impulsion locale (le personnage appartient au client : la vitesse est répliquée).
local function impulse(dir: Vector3, distance: number, duration: number, up: number?)
	local r = root()
	if not r then
		return
	end
	local att = r:FindFirstChild("RootAttachment") :: Attachment?
	if not att then
		return
	end
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = 1e6
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	lv.VectorVelocity = flat.Unit * (distance / duration) + Vector3.new(0, up or 0, 0)
	lv.Parent = r
	task.delay(duration, function()
		lv:Destroy()
	end)
end

local function onPlayerFx(p)
	if p.kind == "Dash" then
		impulse(p.dir, p.distance or 15, 0.18)
		C.Sound.Play("Whoosh")
	elseif p.kind == "Dodge" then
		impulse(p.dir, p.distance or 14, 0.2)
		C.Sound.Play("Whoosh")
		-- traînée et transparence brève (invulnérabilité)
		local char = player.Character
		if char then
			for _, d in char:GetDescendants() do
				if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
					d.LocalTransparencyModifier = 0.6
					task.delay(0.3, function()
						d.LocalTransparencyModifier = 0
					end)
				end
			end
		end
	elseif p.kind == "Knock" then
		local force = p.force or 40
		impulse(p.dir, force * 0.35, 0.22, force * 0.4)
		Combat.Shake(0.6)
	end
end

-- ============================================================================ Pavé tactile
local function skillButton(root: Frame, name: string, pos: UDim2, size: number, color: Color3, cb: () -> ()): TextButton
	local b = Kit.RoundButton(root, { Name = name, Icon = "", Size = UDim2.fromOffset(size, size), Position = pos, Color = color, OnClick = cb, AnchorPoint = Vector2.new(0.5, 0.5) })
	cooldownSetters[name] = Kit.Cooldown(b)
	buttons[name] = b
	return b
end

local function keyHint(b: TextButton, text: string)
	if UserInputService.KeyboardEnabled then
		local l = Kit.Label(b, { Name = "Key", Text = text, Size = UDim2.fromOffset(22, 18), Position = UDim2.new(0, -2, 0, -2), Font = Theme.Font.Bold, Color = Theme.Color.Gold, ZIndex = 8 })
		local _ = l
	end
end

local function buildPad()
	local hudRoot = C.HUD.root :: Frame
	local pad = Kit.new("Frame", { Name = "CombatPad", Size = UDim2.fromOffset(380, 290), Position = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1, Parent = hudRoot })
	local function at(x: number, y: number): UDim2
		return UDim2.new(1, x, 1, y)
	end
	local atk = skillButton(pad, "Attack", at(-95, -95), 104, Color3.fromRGB(230, 80, 70), Combat.Attack)
	;(atk:FindFirstChild("Icon") :: TextLabel).Text = Theme.Icon.Attack
	keyHint(atk, "🖱")
	local s1 = skillButton(pad, "Skill1", at(-222, -72), 70, Color3.fromRGB(70, 130, 230), function()
		Combat.Skill(1)
	end)
	keyHint(s1, "1")
	local s2 = skillButton(pad, "Skill2", at(-200, -175), 70, Color3.fromRGB(70, 180, 120), function()
		Combat.Skill(2)
	end)
	keyHint(s2, "2")
	local s3 = skillButton(pad, "Skill3", at(-100, -222), 80, Color3.fromRGB(190, 90, 255), function()
		Combat.Skill(3)
	end)
	keyHint(s3, "3")
	-- anneau de charge de la signature
	chargeRing = Kit.new("Frame", { Name = "Charge", Size = UDim2.new(1, 10, 1, 10), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 1, Parent = s3 })
	Kit.Corner(chargeRing, 999)
	local ringStroke = Kit.new("UIStroke", { Color = Theme.Color.Gold, Thickness = 4, Transparency = 0, Parent = chargeRing })
	Kit.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.501, 1), NumberSequenceKeypoint.new(1, 1) }), Rotation = 90, Parent = ringStroke })
	local dodge = skillButton(pad, "Dodge", at(-322, -52), 58, Color3.fromRGB(90, 200, 230), Combat.Dodge)
	;(dodge:FindFirstChild("Icon") :: TextLabel).Text = Theme.Icon.Dodge
	keyHint(dodge, "Q")
	local jump = skillButton(pad, "Jump", at(-30, -200), 54, Color3.fromRGB(110, 120, 160), Combat.Jump)
	;(jump:FindFirstChild("Icon") :: TextLabel).Text = "⤒"
	if not UserInputService.TouchEnabled then
		jump.Visible = false
	end
	-- libellés des compétences
	for slot = 1, 3 do
		local b = buttons["Skill" .. slot]
		Kit.Label(b, { Name = "SkillName", Text = "", Size = UDim2.new(1.6, 0, 0, 16), Position = UDim2.new(0.5, 0, 1, 2), AnchorPoint = Vector2.new(0.5, 0), Font = Theme.Font.Body, ZIndex = 8 })
	end
end

local function refreshSkillIcons()
	local def = leaderDef()
	for slot = 1, 3 do
		local b = buttons["Skill" .. slot]
		if b then
			local icon = b:FindFirstChild("Icon") :: TextLabel
			local name = b:FindFirstChild("SkillName") :: TextLabel
			local sk = skillFor(slot)
			if not def or not sk then
				icon.Text = "?"
				name.Text = ""
				b.BackgroundTransparency = 0.5
			else
				b.BackgroundTransparency = 0.15
				if slot == 1 then
					icon.Text = Heroes.Roles[def.role].icon
				elseif slot == 2 then
					icon.Text = Islands.Get(def.island).symbol
				else
					icon.Text = "✦"
					icon.TextColor3 = Color3.fromHex(def.crystal)
				end
				name.Text = sk.name
			end
		end
	end
end

-- ============================================================================ Boucle
local function update(dt: number)
	local now = Workspace:GetServerTimeNow()
	-- recharges
	local atkLeft = ATTACK_CD - (os.clock() - lastAttack)
	if cooldownSetters.Attack then
		cooldownSetters.Attack(math.max(0, atkLeft / ATTACK_CD))
	end
	if cooldownSetters.Dodge then
		local left = DODGE_CD - (os.clock() - lastDodge)
		cooldownSetters.Dodge(math.max(0, left / DODGE_CD))
	end
	for slot = 1, 3 do
		local setter = cooldownSetters["Skill" .. slot]
		local sk = skillFor(slot)
		if setter and sk then
			local left = (player:GetAttribute("CD" .. slot) or 0) - now
			if left > 0 then
				setter(left / math.max(0.1, sk.cooldown), string.format("%.0f", math.ceil(left)))
			elseif slot == 3 then
				local need = sk.charge or 100
				local ch = player:GetAttribute("Charge") or 0
				setter(if ch >= need then 0 else 0.0001, "")
			else
				setter(0)
			end
		end
	end
	-- anneau de charge
	if chargeRing then
		local sk = skillFor(3)
		local need = sk and sk.charge or 100
		local ch = math.clamp((player:GetAttribute("Charge") or 0) / need, 0, 1)
		local stroke = chargeRing:FindFirstChildOfClass("UIStroke") :: UIStroke
		local g = stroke and stroke:FindFirstChildOfClass("UIGradient")
		if g then
			-- remplissage du bas vers le haut
			g.Rotation = -90
			local k = math.clamp(ch, 0.001, 0.998)
			g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(k, 0), NumberSequenceKeypoint.new(k + 0.001, 0.85), NumberSequenceKeypoint.new(1, 0.85) })
		end
		stroke.Color = if ch >= 1 then Theme.Color.Gold:Lerp(Color3.new(1, 1, 1), (math.sin(os.clock() * 8) + 1) / 4) else Theme.Color.Gold
	end
	-- marqueur de verrouillage
	local target = lockedId and entityById(lockedId)
	if target and attackable(target) then
		lockMarker.Adornee = target
		lockMarker.Enabled = true
		lockMarker.StudsOffsetWorldSpace = Vector3.new(0, target.Size.Y * 0.5 + 2, 0)
	else
		if lockedId and not target then
			lockedId = nil
		end
		lockMarker.Enabled = false
	end
	-- secousse de caméra
	if shakeAmount > 0.01 then
		local cam = Workspace.CurrentCamera
		local s = shakeAmount
		cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * s * 0.02)
		shakeAmount = math.max(0, shakeAmount - dt * 3)
	end
end

-- Toucher/cliquer une entité la verrouille.
local function tryLockAt(screenPos: Vector2): boolean
	local cam = Workspace.CurrentCamera
	local ray = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
	local best, bestD = nil, 2.5
	for _, e in CollectionService:GetTagged("Entity") do
		if e:IsA("BasePart") and attackable(e) then
			local toE = e.Position - ray.Origin
			local t = toE:Dot(ray.Direction)
			if t > 0 and t < 250 then
				local perp = (toE - ray.Direction * t).Magnitude / math.max(1, e.Size.Y * 0.5)
				if perp < bestD then
					best, bestD = e, perp
				end
			end
		end
	end
	if best then
		lockedId = best:GetAttribute("EntityId")
		return true
	end
	return false
end

function Combat.Init(controllers)
	C = controllers
end

function Combat.Start()
	buildPad()
	lockMarker = Instance.new("BillboardGui")
	lockMarker.Name = "LockMarker"
	lockMarker.Size = UDim2.fromOffset(46, 46)
	lockMarker.AlwaysOnTop = true
	lockMarker.Enabled = false
	lockMarker.Parent = player:WaitForChild("PlayerGui")
	local ring = Kit.Label(lockMarker, { Text = "◎", Size = UDim2.fromScale(1, 1), Color = Theme.Color.Error, Font = Theme.Font.Title })
	local _ = ring
	refreshSkillIcons()
	player:GetAttributeChangedSignal("LeaderHero"):Connect(refreshSkillIcons)
	Net.Event("PlayerFx").OnClientEvent:Connect(onPlayerFx)
	C.Data.Changed:Connect(function(d)
		shakeEnabled = not (d and d.settings and d.settings.shake == false)
	end)
	RunService:BindToRenderStep("AstralCombat", Enum.RenderPriority.Camera.Value + 1, update)
	-- dégâts subis : secousse + son
	local function hook(char: Model)
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
		if not hum then
			return
		end
		lastHealth = hum.Health
		hum.HealthChanged:Connect(function(h)
			if h < lastHealth - 0.5 then
				Combat.Shake(math.clamp((lastHealth - h) / hum.MaxHealth * 4, 0.15, 1))
			end
			lastHealth = h
		end)
		hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping then
				C.Sound.Play("Jump")
			end
		end)
	end
	if player.Character then
		task.spawn(hook, player.Character)
	end
	player.CharacterAdded:Connect(hook)
	-- clavier / manette
	local function bind(name: string, fn: () -> (), ...)
		ContextActionService:BindAction(name, function(_, state)
			if state == Enum.UserInputState.Begin then
				fn()
			end
			return Enum.ContextActionResult.Pass
		end, false, ...)
	end
	bind("AstralSkill1", function()
		Combat.Skill(1)
	end, Enum.KeyCode.One, Enum.KeyCode.ButtonL1)
	bind("AstralSkill2", function()
		Combat.Skill(2)
	end, Enum.KeyCode.Two, Enum.KeyCode.ButtonR1)
	bind("AstralSkill3", function()
		Combat.Skill(3)
	end, Enum.KeyCode.Three, Enum.KeyCode.ButtonY)
	bind("AstralDodge", Combat.Dodge, Enum.KeyCode.Q, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonB)
	bind("AstralAttackPad", Combat.Attack, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonR2, Enum.KeyCode.F)
	bind("AstralInteract", function()
		C.HUD.TriggerContext()
	end, Enum.KeyCode.E, Enum.KeyCode.DPadUp)
	bind("AstralReturn", function()
		Net.Event("ReturnBase"):FireServer()
	end, Enum.KeyCode.B)
	bind("AstralMap", function()
		C.Menus.Toggle("Map")
	end, Enum.KeyCode.M)
	bind("AstralTeam", function()
		C.Menus.Toggle("Team")
	end, Enum.KeyCode.T)
	bind("AstralClose", function()
		C.Menus.Close()
	end, Enum.KeyCode.Escape, Enum.KeyCode.ButtonSelect)
	-- clic gauche dans le monde : attaque ; toucher une entité : verrouillage
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if C.Menus.IsOpen() then
				return
			end
			tryLockAt(UserInputService:GetMouseLocation())
			Combat.Attack()
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local inset = game:GetService("GuiService"):GetGuiInset()
			tryLockAt(Vector2.new(input.Position.X, input.Position.Y) + inset)
		end
	end)
	local _ = Locale
end

return Combat
