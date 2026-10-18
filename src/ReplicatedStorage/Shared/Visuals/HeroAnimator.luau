--!nonstrict
-- Animations procédurales des héros (bible : 7 animations minimum — repos, marche, course, saut, compétence,
-- attaque, réaction d'alerte) déclinées par kit (Critter, Golem, Archer, Fairy, Titan, Fox, Assassin, Priestess,
-- Knight, Sovereign). Agit sur les Motor6D du rig et renvoie un décalage du corps entier.

local HeroAnimator = {}
HeroAnimator.__index = HeroAnimator

export type KitStyle = {
	bob: number, -- amplitude verticale (fraction de la hauteur)
	speed: number, -- cadence de marche
	leg: number, -- amplitude des jambes (radians)
	arm: number,
	sway: number, -- roulis du corps
	hover: number, -- lévitation permanente (fraction de la hauteur)
	squash: number,
	lean: number,
}

local KITS: { [string]: KitStyle } = {
	Critter = { bob = 0.07, speed = 9, leg = 0.5, arm = 0.5, sway = 0.06, hover = 0, squash = 0.08, lean = 0.08 },
	Fox = { bob = 0.05, speed = 11, leg = 0.7, arm = 0.6, sway = 0.05, hover = 0, squash = 0.05, lean = 0.18 },
	Golem = { bob = 0.025, speed = 5, leg = 0.35, arm = 0.45, sway = 0.08, hover = 0, squash = 0.03, lean = 0.06 },
	Knight = { bob = 0.02, speed = 5.5, leg = 0.32, arm = 0.35, sway = 0.05, hover = 0, squash = 0.02, lean = 0.05 },
	Titan = { bob = 0.02, speed = 4.2, leg = 0.28, arm = 0.4, sway = 0.07, hover = 0, squash = 0.02, lean = 0.04 },
	Archer = { bob = 0.03, speed = 8.5, leg = 0.55, arm = 0.35, sway = 0.03, hover = 0, squash = 0.02, lean = 0.12 },
	Assassin = { bob = 0.025, speed = 10, leg = 0.6, arm = 0.5, sway = 0.03, hover = 0, squash = 0.02, lean = 0.22 },
	Fairy = { bob = 0.04, speed = 4, leg = 0.1, arm = 0.2, sway = 0.04, hover = 0.08, squash = 0, lean = 0.1 },
	Priestess = { bob = 0.03, speed = 3.5, leg = 0.08, arm = 0.15, sway = 0.03, hover = 0.05, squash = 0, lean = 0.06 },
	Sovereign = { bob = 0.025, speed = 3, leg = 0.05, arm = 0.12, sway = 0.02, hover = 0.06, squash = 0, lean = 0.05 },
}

local ONE_SHOT = { Attack = 0.45, Skill = 1.0, Alert = 0.8, Jump = 0.7, Reveal = 1.6 }

function HeroAnimator.new(rig: any, kit: string)
	local self = setmetatable({}, HeroAnimator)
	self.rig = rig
	self.style = KITS[kit] or KITS.Critter
	self.kit = kit
	self.t = math.random() * 10
	self.state = "Idle"
	self.oneShot = nil :: string?
	self.oneShotT = 0
	self.speedFactor = 0
	self.phaseOffset = math.random() * math.pi * 2
	return self
end

-- État continu : "Idle" | "Walk" | "Run" | "Downed" | "Carried" | "Display"
function HeroAnimator:SetState(s: string)
	self.state = s
end

-- Animation ponctuelle : "Attack" | "Skill" | "Alert" | "Jump" | "Reveal"
function HeroAnimator:Play(name: string)
	self.oneShot = name
	self.oneShotT = 0
end

local function J(self, name: string, cf: CFrame)
	local j = self.rig.joints[name]
	if j then
		j.Transform = cf
	end
end

local function prefixJoints(self, prefix: string): { Motor6D }
	local out = {}
	for n, j in self.rig.joints do
		if string.sub(n, 1, #prefix) == prefix then
			table.insert(out, j)
		end
	end
	return out
end

-- Avance l'animation ; renvoie le décalage à appliquer au repère des pieds.
function HeroAnimator:Step(dt: number): CFrame
	local st = self.style
	local h = self.rig.height
	self.t += dt
	local t = self.t + self.phaseOffset
	local moving = self.state == "Walk" or self.state == "Run"
	local target = if self.state == "Run" then 1 elseif self.state == "Walk" then 0.6 else 0
	self.speedFactor += (target - self.speedFactor) * math.min(1, dt * 8)
	local m = self.speedFactor
	local freq = st.speed * (0.6 + m * 0.7)
	local cyc = t * freq
	-- base : respiration au repos, foulée en mouvement
	local breathe = math.sin(t * 2.2) * 0.012
	local bob = math.abs(math.sin(cyc)) * st.bob * m + st.hover + (if st.hover > 0 then math.sin(t * 1.8) * st.bob * 0.6 else breathe * 0.5)
	local roll = math.sin(cyc) * st.sway * m
	local lean = st.lean * m
	local squash = 1 - math.abs(math.sin(cyc)) * st.squash * m
	local body = CFrame.new(0, bob * h, 0) * CFrame.Angles(-lean, 0, roll)
	-- membres
	local leg = math.sin(cyc) * st.leg * m
	local arm = math.sin(cyc) * st.arm * m
	local idleArm = math.sin(t * 1.6) * 0.05
	J(self, "LegL", CFrame.Angles(leg, 0, 0))
	J(self, "LegR", CFrame.Angles(-leg, 0, 0))
	J(self, "ArmL", CFrame.Angles(-arm + idleArm, 0, -0.05 - idleArm * 0.5))
	J(self, "ArmR", CFrame.Angles(arm + idleArm, 0, 0.05 + idleArm * 0.5))
	J(self, "Head", CFrame.Angles(math.sin(t * 1.3) * 0.04 + lean * 0.5, math.sin(t * 0.7) * 0.08 * (1 - m), 0))
	-- signatures : oreilles, queue, ailes, cape, halo, orbites, arbres flottants
	local twitch = if math.sin(t * 0.9) > 0.97 then math.sin(t * 40) * 0.25 else 0
	J(self, "EarL", CFrame.Angles(0, 0, math.sin(t * 2) * 0.06 + twitch))
	J(self, "EarR", CFrame.Angles(0, 0, -math.sin(t * 2) * 0.06 - twitch))
	J(self, "Tail", CFrame.Angles(math.sin(t * 2.4) * 0.12, math.sin(t * 3 + 1) * (0.35 + m * 0.2), 0))
	local flap = math.sin(t * (if self.kit == "Fairy" then 7 else 3)) * (if self.kit == "Fairy" then 0.35 else 0.12)
	J(self, "WingL", CFrame.Angles(0, flap * 0.4, flap))
	J(self, "WingR", CFrame.Angles(0, -flap * 0.4, -flap))
	J(self, "Cape", CFrame.Angles(0.08 + math.sin(t * 2.5) * 0.06 + m * 0.25, 0, math.sin(t * 1.7) * 0.04))
	J(self, "Halo", CFrame.Angles(0, 0, t * 0.8))
	for _, j in prefixJoints(self, "Orbit") do
		j.Transform = CFrame.Angles(0, t * 0.9, 0) * CFrame.new(0, math.sin(t * 2) * 0.03 * h, 0)
	end
	for i = 1, 4 do
		J(self, "Float" .. i, CFrame.new(0, math.sin(t * 1.5 + i * 1.7) * 0.02 * h, 0) * CFrame.Angles(0, math.sin(t + i) * 0.1, 0))
	end
	for _, j in prefixJoints(self, "Weapon") do
		j.Transform = CFrame.Angles(math.sin(t * 1.4) * 0.03, 0, 0)
	end
	-- états particuliers
	if self.state == "Downed" then
		body = CFrame.new(0, 0.08 * h, 0) * CFrame.Angles(math.rad(-75), 0, math.rad(15))
		J(self, "Head", CFrame.Angles(0.3, 0, 0))
	elseif self.state == "Carried" then
		body = CFrame.Angles(math.sin(t * 2) * 0.15, t * 1.2, math.cos(t * 2) * 0.15)
	elseif self.state == "Display" then
		-- pose de vitrine : légère rotation de présentation
		body = body * CFrame.Angles(0, math.sin(t * 0.4) * 0.25, 0)
	end
	-- animations ponctuelles
	if self.oneShot then
		local dur = ONE_SHOT[self.oneShot] or 0.6
		self.oneShotT += dt
		local k = math.clamp(self.oneShotT / dur, 0, 1)
		local e = math.sin(k * math.pi)
		local name = self.oneShot
		if name == "Attack" then
			local heavy = self.kit == "Golem" or self.kit == "Titan" or self.kit == "Knight"
			if heavy then
				J(self, "ArmL", CFrame.Angles(-2.2 * e, 0, 0))
				J(self, "ArmR", CFrame.Angles(-2.2 * e, 0, 0))
				body = body * CFrame.new(0, -0.03 * h * e, -0.05 * h * e)
			else
				J(self, "ArmR", CFrame.Angles(-1.6 * e, 0, 0.3 * e))
				body = body * CFrame.new(0, 0, -0.12 * h * e) * CFrame.Angles(-0.2 * e, 0.3 * e, 0)
			end
		elseif name == "Skill" then
			body = body * CFrame.new(0, 0.15 * h * e, 0) * CFrame.Angles(0, k * math.pi * 2, 0)
			J(self, "ArmL", CFrame.Angles(-2.6 * e, 0, -0.4 * e))
			J(self, "ArmR", CFrame.Angles(-2.6 * e, 0, 0.4 * e))
		elseif name == "Alert" then
			body = body * CFrame.new(0, 0.1 * h * e, 0)
			J(self, "EarL", CFrame.Angles(-0.4 * e, 0, -0.3 * e))
			J(self, "EarR", CFrame.Angles(-0.4 * e, 0, 0.3 * e))
			J(self, "Tail", CFrame.Angles(-0.6 * e, 0, 0))
		elseif name == "Jump" then
			body = body * CFrame.new(0, 0.35 * h * e, 0) * CFrame.Angles(-0.25 * e, 0, 0)
			J(self, "LegL", CFrame.Angles(0.8 * e, 0, 0))
			J(self, "LegR", CFrame.Angles(0.6 * e, 0, 0))
		elseif name == "Reveal" then
			body = body * CFrame.Angles(0, k * math.pi * 2, 0) * CFrame.new(0, 0.2 * h * e, 0)
		end
		if k >= 1 then
			self.oneShot = nil
		end
	end
	if squash ~= 1 and not moving then
		squash = 1
	end
	return body
end

function HeroAnimator:Reset()
	for _, j in self.rig.joints do
		j.Transform = CFrame.new()
	end
end

return HeroAnimator
