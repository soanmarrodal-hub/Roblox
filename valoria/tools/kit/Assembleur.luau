--!strict
-- Assembleur du kit de sol Valoria (Roblox Studio). Après avoir inséré ValoriaKit_ValDAutomne.rbxmx dans
-- l'Explorateur (le dossier du kit peut rester dans ServerStorage), dans la barre de commande :
--
--   local A = require(game.ServerStorage.ValoriaKit_ValDAutomne.Assembleur)
--   A.Construire([[
--   h h # h h
--   h # # # h
--   h h # h h
--   ]], CFrame.new(0, 0, 0), workspace, { bordures = true, deco = true })
--
-- Une lettre par dalle de 8 × 8 studs, première ligne au nord (-Z) ; légende dans le module « Disposition ».
-- Chaque module existe en plusieurs variantes (Sol_Herbe_A, _B, _C…) : l'assembleur en choisit une par dalle
-- et la tourne selon les raccords. Le décor est rangé à part (dossier « Deco »), sans collision.

local Disposition = require(script.Parent.Disposition)

local Assembleur = {}

local variants: { [string]: { Model } } = {}

-- Variantes d'un module (« Module_A », « Module_B »…), où qu'elles soient rangées dans le kit.
local function variantsOf(kit: Instance, module: string): { Model }
	local list = variants[module]
	if list then
		return list
	end
	local found: { Model } = {}
	for _, d in kit:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Module") == module and d:GetAttribute("Variante") ~= nil then
			table.insert(found, d)
		end
	end
	table.sort(found, function(a, b)
		return a.Name < b.Name
	end)
	variants[module] = found
	return found
end

-- Les modules du kit sont construits à l'origine : on déplace chaque pièce d'un même repère.
local function place(model: Model, cf: CFrame)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = cf * d.CFrame
		end
	end
	pcall(function()
		model.WorldPivot = cf
	end)
end

-- Construit une zone ; renvoie son dossier (couches Sol, Relief, Bordures, Rochers, Deco).
function Assembleur.Construire(plan: string, origine: CFrame?, parent: Instance?, options: { [string]: any }?): Folder
	local kit = script.Parent
	local origin = origine or CFrame.identity
	local zone = Instance.new("Folder")
	zone.Name = "ZoneAssemblee"
	local layers: { [string]: Folder } = {}
	for _, pl in Disposition.Build(plan, options :: any) do
		local list = variantsOf(kit, pl.module)
		if #list == 0 then
			warn("[Assembleur] module absent du kit : " .. pl.module)
			continue
		end
		local layer = layers[pl.layer]
		if not layer then
			local f = Instance.new("Folder")
			f.Name = pl.layer
			f.Parent = zone
			layers[pl.layer] = f
			layer = f
		end
		local m = list[pl.seed % #list + 1]:Clone()
		place(m, origin * CFrame.new(pl.x, pl.y, pl.z) * CFrame.Angles(0, pl.yaw, 0))
		m.Name = pl.module
		m.Parent = layer
	end
	zone.Parent = parent or workspace
	return zone
end

return Assembleur
