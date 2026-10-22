--!strict
-- Animations locales du décor étiqueté par le serveur : « Spin » (rotation), « Bob » (flottement),
-- « Pulse » (néons qui respirent), « SpinModel » (ailes du moulin, faisceau du phare).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Decor = {}

type Item = { inst: Instance, base: CFrame, tags: { [string]: number }, baseT: number, seed: number }
local items: { [Instance]: Item } = {}

local function track(inst: Instance, tag: string)
	local it = items[inst]
	if not it then
		local base = if inst:IsA("BasePart") then inst.CFrame elseif inst:IsA("Model") then inst:GetPivot() else CFrame.identity
		it = {
			inst = inst,
			base = base,
			tags = {},
			baseT = if inst:IsA("BasePart") then inst.Transparency else 0,
			seed = math.random() * 10,
		}
		items[inst] = it
	end
	local v = inst:GetAttribute(tag)
	;(it :: Item).tags[tag] = if type(v) == "number" then v else 1
end

local function untrack(inst: Instance)
	items[inst] = nil
end

local function step()
	local t = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	for inst, it in items do
		if not inst.Parent then
			items[inst] = nil
			continue
		end
		local pos = it.base.Position
		if (pos - camPos).Magnitude > 320 then
			continue
		end
		local tg = it.tags
		if inst:IsA("BasePart") then
			local cf = it.base
			if tg.Spin then
				cf = CFrame.new(cf.Position) * CFrame.Angles(0, t * tg.Spin * math.pi * 2 + it.seed, 0) * (cf - cf.Position)
			end
			if tg.Bob then
				cf = cf + Vector3.new(0, math.sin(t * 2 * tg.Bob + it.seed) * 0.6, 0)
			end
			if tg.Spin or tg.Bob then
				inst.CFrame = cf
			end
			if tg.Pulse then
				inst.Transparency = math.clamp(it.baseT + (math.sin(t * 2.4 + it.seed) * 0.5 + 0.5) * 0.3, 0, 1)
			end
		elseif inst:IsA("Model") and tg.SpinModel then
			local a = t * tg.SpinModel * math.pi * 2
			local base = it.base
			if inst:GetAttribute("Axis") == "Y" then
				inst:PivotTo(CFrame.new(base.Position) * CFrame.Angles(0, a, 0) * (base - base.Position))
			else
				inst:PivotTo(base * CFrame.Angles(0, 0, a))
			end
		end
	end
end

function Decor.Init()
	for _, tag in { "Spin", "Bob", "Pulse", "SpinModel" } do
		for _, inst in CollectionService:GetTagged(tag) do
			track(inst, tag)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
			track(inst, tag)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
	end
	RunService.Heartbeat:Connect(step)
end

return Decor
