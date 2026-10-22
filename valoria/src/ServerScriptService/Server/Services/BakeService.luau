--!strict
-- « Cuisson » des modèles voxel : au démarrage du serveur, les boîtes de chaque os sont fusionnées en
-- quelques unions (GeometryService:UnionAsync, couleurs d'origine conservées). Un héros passe ainsi d'un
-- millier de pièces à une quarantaine. Les gabarits cuits sont rangés dans ReplicatedStorage.VoxelBaked ;
-- les clients les clonent dès qu'ils existent (sinon ils construisent la version en boîtes).
-- En cas d'échec d'une union, le groupe garde ses boîtes : le jeu fonctionne dans tous les cas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Builder = require(Shared.Voxel.Builder)
local Heroes = require(Shared.Config.Heroes)
local Enemies = require(Shared.Config.Enemies)
local Worlds = require(Shared.Config.Worlds)
local R = require(script.Parent.Parent.Registry)
local Union = require(script.Parent.Parent.World.Union)

local BakeService = {}
BakeService.Enabled = true

local folder: Folder
local done: { [string]: boolean } = {}
local queued: { [string]: boolean } = {}
local queue: { { name: string, tint: string? } } = {}

function BakeService.Bake(self: any, name: string, tint: string?)
	local key = Builder.KeyOf(name, { tint = tint })
	if done[key] then
		return
	end
	done[key] = true
	local decoded = Builder.Decode(name, false, tint)
	if not decoded then
		return
	end
	local allOk = true
	local model = Builder.Assemble(name, decoded, function(_bone: string, mat: string, boxes: { Builder.Box }): { BasePart }
		local parts, ok = Union.Group(boxes, mat, false)
		allOk = allOk and ok
		return parts
	end)
	if not allOk then
		-- inutile de répliquer une version en boîtes : les clients la construisent eux-mêmes
		model:Destroy()
		return
	end
	model.Name = key
	model.Parent = folder
	Builder.Forget(name)
end

function BakeService.Request(self: any, name: string, tint: string?)
	local key = Builder.KeyOf(name, { tint = tint })
	if queued[key] or done[key] or not self.Enabled then
		return
	end
	queued[key] = true
	table.insert(queue, { name = name, tint = tint })
end

function BakeService.Init(self: any)
	folder = Instance.new("Folder")
	folder.Name = "VoxelBaked"
	folder.Parent = ReplicatedStorage
end

function BakeService.Start(self: any)
	if not self.Enabled then
		return
	end
	if Union.Disabled then
		return
	end
	-- priorité : ennemis du premier monde, héros équipés des joueurs présents, puis le reste
	for _, w in Worlds.List do
		for _, z in w.zones do
			local e = Enemies.Get(z.enemy)
			if e then
				self:Request(e.model, e.tint)
			end
		end
		local b = Enemies.Get(w.boss.enemy)
		if b then
			self:Request(b.model, b.tint)
		end
	end
	local function requestTeam(player: Player)
		local data = R.DataService:Get(player)
		if data then
			for _, uid in data.team do
				local h = data.heroes[uid]
				if h then
					self:Request(h.id)
				end
			end
		end
	end
	R.DataService.Loaded:Connect(requestTeam)
	for _, p in Players:GetPlayers() do
		requestTeam(p)
	end
	for _, h in Heroes.Ordered do
		self:Request(h.id)
	end
	for _, e in Enemies.Ordered do
		self:Request(e.model, e.tint)
	end
	task.spawn(function()
		task.wait(3)
		while true do
			local job = table.remove(queue, 1)
			if job then
				local ok, err = pcall(self.Bake, self, job.name, job.tint)
				if not ok then
					warn("[BakeService] " .. job.name .. " : " .. tostring(err))
				end
				task.wait(0.05)
			else
				task.wait(1)
			end
		end
	end)
end

return BakeService
