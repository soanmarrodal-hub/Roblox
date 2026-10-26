--!strict
-- Écriture du terrain Roblox à partir d'un champ de hauteur (Relief) : choix des matériaux selon la pente,
-- l'altitude, l'humidité et les chemins, puis écriture par blocs (WriteVoxelChannels, rives eau/roche
-- mélangées ; repli sur WriteVoxels). Le travail est découpé pour ne pas bloquer le serveur.

local Relief = require(script.Parent.Relief)

local TerrainGen = {}

local RES = 4
local CHUNK = 64

-- Couleurs globales des matériaux (le terrain est partagé par tous les lieux) : direction artistique
-- commune dans Shared/Config/Palette.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArtPalette = require(ReplicatedStorage.Shared.Config.Palette)

TerrainGen.Colors = {} :: { [Enum.Material]: Color3 }
for name, col in ArtPalette.Terrain do
	TerrainGen.Colors[(Enum.Material :: any)[name]] = col
end

export type Palette = {
	flat: Enum.Material,
	flat2: Enum.Material,
	slope: Enum.Material,
	cliff: Enum.Material,
	path: Enum.Material,
	shore: Enum.Material,
	bed: Enum.Material,
	high: Enum.Material,
	snowline: number,
	deep: Enum.Material,
	patch: Enum.Material, -- petites taches dans l'herbe (terre nue, herbe sèche…)
	strata: { Enum.Material }, -- couches des falaises, de bas en haut (bandes de 5 studs)
}

TerrainGen.Palettes = {
	Hub = {
		flat = Enum.Material.Grass,
		flat2 = Enum.Material.LeafyGrass,
		slope = Enum.Material.Ground,
		cliff = Enum.Material.Rock,
		path = Enum.Material.Cobblestone,
		shore = Enum.Material.Ground,
		bed = Enum.Material.Mud,
		high = Enum.Material.Snow,
		snowline = 210,
		deep = Enum.Material.Rock,
		patch = Enum.Material.LeafyGrass,
		strata = { Enum.Material.Rock, Enum.Material.Sandstone, Enum.Material.Rock, Enum.Material.Limestone },
	},
	-- Val d'Automne : herbe verte, nappes d'herbe sèche, chemins pavés beiges, falaises en strates
	W1 = {
		flat = Enum.Material.Grass,
		flat2 = Enum.Material.LeafyGrass,
		slope = Enum.Material.Ground,
		cliff = Enum.Material.Rock,
		path = Enum.Material.Cobblestone,
		shore = Enum.Material.Mud,
		bed = Enum.Material.Mud,
		high = Enum.Material.Snow,
		snowline = 270,
		deep = Enum.Material.Rock,
		patch = Enum.Material.Ground,
		strata = { Enum.Material.Rock, Enum.Material.Sandstone, Enum.Material.Rock, Enum.Material.Limestone, Enum.Material.Sandstone, Enum.Material.Rock },
	},
	W2 = {
		flat = Enum.Material.Grass,
		flat2 = Enum.Material.Rock,
		slope = Enum.Material.Slate,
		cliff = Enum.Material.Slate,
		path = Enum.Material.Ground,
		shore = Enum.Material.Sand,
		bed = Enum.Material.Sand,
		high = Enum.Material.Snow,
		snowline = 280,
		deep = Enum.Material.Basalt,
		patch = Enum.Material.LeafyGrass,
		strata = { Enum.Material.Slate, Enum.Material.Basalt, Enum.Material.Slate, Enum.Material.Rock },
	},
} :: { [string]: Palette }

-- Couche de falaise à l'altitude locale `y` : bandes d'environ 5 studs, d'épaisseurs inégales, ondulées.
function TerrainGen.Strata(pal: Palette, y: number, x: number, z: number): Enum.Material
	local band = math.floor((y + 2.5 * math.sin(y * 0.37) + math.noise(x / 40, z / 40, 31) * 4) / 5)
	return pal.strata[band % #pal.strata + 1]
end

-- Matériau de surface d'une colonne (fonction pure, réutilisée par les aperçus).
function TerrainGen.SurfaceMaterial(pal: Palette, s: Relief.Sample, slope: number, x: number, z: number, paved: boolean?): Enum.Material
	local h = s.h
	if paved then
		return Enum.Material.Cobblestone
	end
	if s.water and h < s.water - 0.5 then
		return pal.bed
	end
	-- bords de chemin irréguliers : la terre battue mord sur l'herbe par endroits
	if s.path > 0.5 + math.noise(x / 7, z / 7, 11) * 0.3 and slope < 0.9 then
		return pal.path
	end
	if h > pal.snowline + math.noise(x / 50, z / 50, 3) * 25 and slope < 1.2 then
		return pal.high
	end
	if slope > 1.05 then
		return TerrainGen.Strata(pal, h, x, z)
	end
	if s.wet > 0.4 + math.noise(x / 9, z / 9, 12) * 0.2 then
		return pal.shore
	end
	if slope > 0.6 then
		return if math.noise(x / 30, z / 30, 5) + math.noise(x / 9, z / 9, 6) * 0.4 > 0 then pal.slope else pal.cliff
	end
	-- affleurements rocheux sur les pentes douces
	if slope > 0.32 and math.noise(x / 13, z / 13, 21) > 0.42 then
		return pal.cliff
	end
	-- grandes nappes (bruit large + détail fin pour des contours irréguliers), puis petites taches
	local n = math.noise(x / 46, z / 46, 8) + math.noise(x / 12, z / 12, 9) * 0.3
	if n > 0.32 and s.plateau < 0.5 then
		return pal.flat2
	end
	if math.noise(x / 9, z / 9, 13) > 0.56 then
		return pal.patch
	end
	return pal.flat
end

export type Built = { heights: { { number } }, n: number, x0: number, z0: number }

-- Construit le terrain d'un lieu. `origin` = centre monde ; `paved(x, z)` (local) force les pavés.
function TerrainGen.Build(spec: Relief.Spec, origin: Vector3, paletteKey: string, paved: ((x: number, z: number) -> boolean)?): Built
	local terrain = workspace.Terrain
	local pal = TerrainGen.Palettes[paletteKey] or TerrainGen.Palettes.Hub
	local half = spec.half
	local x0 = math.floor((origin.X - half) / RES) * RES
	local z0 = math.floor((origin.Z - half) / RES) * RES
	local n = math.floor(2 * half / RES) + 2
	-- 1) hauteurs et échantillons
	local H: { { number } } = table.create(n)
	local S: { { Relief.Sample } } = table.create(n)
	for ix = 1, n do
		local col = table.create(n)
		local scol = table.create(n)
		local x = x0 + (ix - 0.5) * RES - origin.X
		for iz = 1, n do
			local z = z0 + (iz - 0.5) * RES - origin.Z
			local s = Relief.Sample(spec, x, z)
			col[iz] = s.h
			scol[iz] = s
		end
		H[ix] = col
		S[ix] = scol
		if ix % 24 == 0 then
			task.wait()
		end
	end
	-- 2) écriture par blocs de 64 × 64 studs
	local nc = CHUNK // RES
	local useChannels = true
	for cx = 1, n, nc do
		for cz = 1, n, nc do
			local ex = math.min(n, cx + nc - 1)
			local ez = math.min(n, cz + nc - 1)
			local lo, hi = 1e9, -1e9
			for ix = cx, ex do
				for iz = cz, ez do
					local h = H[ix][iz]
					lo = math.min(lo, h)
					hi = math.max(hi, h)
					local w = S[ix][iz].water
					if w then
						hi = math.max(hi, w)
					end
				end
			end
			local yb = math.floor((origin.Y + lo - 12) / RES) * RES
			local yt = math.ceil((origin.Y + hi + 2) / RES) * RES
			local ny = (yt - yb) // RES
			local sx, sz = ex - cx + 1, ez - cz + 1
			local mats = table.create(sx)
			local occ = table.create(sx)
			local liq = table.create(sx)
			for i = 1, sx do
				local ix = cx + i - 1
				local mcol, ocol, lcol = table.create(ny), table.create(ny), table.create(ny)
				for j = 1, ny do
					mcol[j] = table.create(sz, Enum.Material.Air)
					ocol[j] = table.create(sz, 0)
					lcol[j] = table.create(sz, 0)
				end
				for k = 1, sz do
					local iz = cz + k - 1
					local h = origin.Y + H[ix][iz]
					local s = S[ix][iz]
					local lx = x0 + (ix - 0.5) * RES - origin.X
					local lz = z0 + (iz - 0.5) * RES - origin.Z
					local dxh = (H[math.min(n, ix + 1)][iz] - H[math.max(1, ix - 1)][iz]) / (2 * RES)
					local dzh = (H[ix][math.min(n, iz + 1)] - H[ix][math.max(1, iz - 1)]) / (2 * RES)
					local slope = math.sqrt(dxh * dxh + dzh * dzh)
					local surf = TerrainGen.SurfaceMaterial(pal, s, slope, lx, lz, paved and paved(lx, lz))
					local water = if s.water then origin.Y + s.water else nil
					-- colonne de falaise : chaque voxel prend la couche de son altitude (strates visibles sur la paroi)
					local cliffCol = slope > 1.05 and surf ~= pal.high and surf ~= pal.path
					for j = 1, ny do
						local vb = yb + (j - 1) * RES
						local vt = vb + RES
						if vt <= h then
							local depth = h - vt
							mcol[j][k] = if cliffCol and depth < 14
								then TerrainGen.Strata(pal, vb + RES / 2 - origin.Y, lx, lz)
								elseif depth < 4 then surf
								elseif depth < 14 and surf ~= pal.cliff then pal.slope
								else pal.deep
							ocol[j][k] = 1
						elseif vb < h then
							mcol[j][k] = surf
							ocol[j][k] = math.clamp((h - vb) / RES, 0.05, 1)
						end
						if water and vb < water then
							local frac = math.clamp((water - vb) / RES, 0, 1)
							lcol[j][k] = frac
						end
					end
				end
				mats[i] = mcol
				occ[i] = ocol
				liq[i] = lcol
			end
			local region = Region3.new(Vector3.new(x0 + (cx - 1) * RES, yb, z0 + (cz - 1) * RES), Vector3.new(x0 + ex * RES, yt, z0 + ez * RES))
			local ok = false
			if useChannels then
				ok = pcall(function()
					terrain:WriteVoxelChannels(region, RES, { SolidMaterial = mats, SolidOccupancy = occ, LiquidOccupancy = liq })
				end)
				if not ok then
					useChannels = false
				end
			end
			if not ok then
				-- repli : l'eau remplace l'air au-dessus du sol
				for i = 1, sx do
					for j = 1, ny do
						for k = 1, sz do
							if liq[i][j][k] > 0 and occ[i][j][k] < 0.5 then
								mats[i][j][k] = Enum.Material.Water
								occ[i][j][k] = liq[i][j][k]
							end
						end
					end
				end
				terrain:WriteVoxels(region, RES, mats, occ)
			end
			task.wait()
		end
	end
	return { heights = H, n = n, x0 = x0, z0 = z0 }
end

function TerrainGen.ApplyColors()
	local terrain = workspace.Terrain
	for mat, col in TerrainGen.Colors do
		pcall(function()
			terrain:SetMaterialColor(mat, col)
		end)
	end
	terrain.WaterColor = Color3.fromRGB(46, 118, 140)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.18
	terrain.WaterWaveSpeed = 9
	-- l'herbe animée (Decoration, GrassLength) et les matériaux 2022 se règlent dans default.project.json :
	-- ces propriétés ne sont pas modifiables par script
end

return TerrainGen
