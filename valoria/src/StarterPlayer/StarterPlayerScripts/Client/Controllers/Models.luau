--!strict
-- Fabrique de modèles voxel côté client : gabarit « cuit » (unions envoyées par le serveur) si disponible,
-- sinon variante allégée (LOD) construite localement ; mise à l'échelle et animateur prêt à l'emploi.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(ReplicatedStorage.Shared.Voxel.Builder)
local Animator = require(ReplicatedStorage.Shared.Anim.Animator)

local Models = {}

export type Built = { model: Model, root: BasePart, anim: any, meta: { [string]: any }, height: number, radius: number, flying: boolean }

local bakedFolder: Folder? = nil

local function isBaked(name: string, tint: string?): boolean
	if not bakedFolder then
		bakedFolder = ReplicatedStorage:FindFirstChild("VoxelBaked") :: Folder?
	end
	local f = bakedFolder
	return f ~= nil and f:FindFirstChild(Builder.KeyOf(name, { tint = tint })) ~= nil
end

function Models.Build(name: string, opts: { tint: string?, scale: number?, style: string?, seed: number?, lowDetail: boolean? }?): Built?
	local o: any = opts or {}
	local lod = o.lowDetail == true or not isBaked(name, o.tint)
	local model = Builder.Spawn(name, { tint = o.tint, lod = lod })
	if not model then
		return nil
	end
	local scale = o.scale or 1
	if math.abs(scale - 1) > 0.01 then
		model:ScaleTo(scale)
	end
	local meta = Builder.Meta(name)
	local anim = Animator.new(model, meta, Builder.Rig(name), { style = o.style or meta.style, flying = meta.flying, seed = o.seed })
	return {
		model = model,
		root = model.PrimaryPart :: BasePart,
		anim = anim,
		meta = meta,
		height = (meta.height or 5) * scale,
		radius = (meta.radius or 2) * scale,
		flying = meta.flying == true,
	}
end

return Models
