--!strict
-- Écriture du terrain Roblox à partir d'un champ de hauteur (Relief) : choix des matériaux selon la pente,
-- l'altitude, l'humidité et les chemins, puis écriture par blocs (WriteVoxelChannels, rives eau/roche
-- mélangées ; repli sur WriteVoxels). Le travail est découpé pour ne pas bloquer le serveur.

local Relief = require(script.Parent.Relief)

local TerrainGen = {}

local RES = 4
local CHUNK = 64

-- Couleurs globales des matériaux (le terrain est partagé par tous les mondes, d'où une palette par monde
-- construite sur des matériaux différents : herbe verte au village et sur la côte, herbe dorée au Val…).
TerrainGen.Colors = {
	[Enum.Material.Grass] = Color3.fromRGB(104, 150, 70),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(176, 146, 62),
	[Enum.Material.Ground] = Color3.fromRGB(112, 84, 54),
	[Enum.Material.Mud] = Color3.fromRGB(88, 70, 50),
	[Enum.Material.Rock] = Color3.fromRGB(124, 122, 118),
	[Enum.Material.Sandstone] = Color3.fromRGB(176, 118, 76),
	[Enum.Material.Limestone] = Color3.fromRGB(196, 182, 150),
	[Enum.Material.Slate] = Color3.fromRGB(92, 99, 108),
	[Enum.Material.Basalt] = Color3.fromRGB(62, 64, 70),
	[Enum.Material.Sand] = Color3.fromRGB(220, 200, 152),
	[Enum.Material.Cobblestone] = Color3.fromRGB(138, 132, 122),
	[Enum.Material.Snow] = Color3.fromRGB(236, 242, 248),
	[Enum.Material.Pavement] = Color3.fromRGB(150, 144, 134),
	[Enum.Material.Salt] = Color3.fromRGB(226, 222, 210),
}

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
	},
	W1 = {
		flat = Enum.Material.LeafyGrass,
		flat2 = Enum.Material.Ground,
		slope = Enum.Material.Ground,
		cliff = Enum.Material.Sandstone,
		path = Enum.Material.Ground,
		shore = Enum.Material.Mud,
		bed = Enum.Material.Mud,
		high = Enum.Material.Snow,
		snowline = 270,
		deep = Enum.Material.Sandstone,
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
	},
} :: { [string]: Palette }

-- Matériau de surface d'une colonne (fonction pure, réutilisée par les aperçus).
function TerrainGen.SurfaceMaterial(pal: Palette, s: Relief.Sample, slope: number, x: number, z: number, paved: boolean?): Enum.Material
	local h = s.h
	if paved then
		return Enum.Material.Cobblestone
	end
	if s.water and h < s.water - 0.5 then
		return pal.bed
	end
	if s.path > 0.5 and slope < 0.9 then
		return pal.path
	end
	if h > pal.snowline + math.noise(x / 50, z / 50, 3) * 25 and slope < 1.2 then
		return pal.high
	end
	if slope > 1.05 then
		return pal.cliff
	end
	if s.wet > 0.4 then
		return pal.shore
	end
	if slope > 0.6 then
		return if math.noise(x / 30, z / 30, 5) > 0 then pal.slope else pal.cliff
	end
	local n = math.noise(x / 46, z / 46, 8)
	if n > 0.32 and s.plateau < 0.5 then
		return pal.flat2
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
					for j = 1, ny do
						local vb = yb + (j - 1) * RES
						local vt = vb + RES
						if vt <= h then
							local depth = h - vt
							mcol[j][k] = if depth < 4 then surf elseif depth < 14 and surf ~= pal.cliff then pal.slope else pal.deep
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
	terrain.Decoration = true
end

return TerrainGen
