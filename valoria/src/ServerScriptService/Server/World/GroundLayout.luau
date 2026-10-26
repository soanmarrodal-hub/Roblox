--!strict
-- Disposition d'une zone en modules du kit de sol, à partir d'un plan texte : une lettre par dalle de 8 × 8
-- studs, première ligne au nord (-Z), première colonne à l'ouest (-X), plan centré sur l'origine.
-- Raccords automatiques : chemins (droit, virage, T, croix, fin, seul) selon les dalles pavées voisines,
-- rampes et escaliers tournés vers le bloc surélevé voisin, falaises dos au vide. Bordures et décor en option.
-- Fonction pure (aucune instance) : partagée par le jeu, l'export du kit et l'assembleur de Roblox Studio.
--
-- Légende :
--   .  rien            h  Sol_Herbe        t  Sol_Terre        m  Sol_Mixte        p  Sol_Paves
--   #  chemin pavé (module choisi selon les voisins # et p)
--   4  Bloc_Terrain_H4 8  Bloc_Terrain_H8  F  Falaise_H16
--   /  Pente_H4 (monte vers le bloc voisin)          e  Escalier_H4 (idem)
--   r  R  G  rocher petit / moyen / grand posé sur une dalle d'herbe

local GroundLayout = {}

GroundLayout.TILE = 8

export type Placement = {
	module: string, -- nom du module (« Chemin_Virage », « Deco_Fleurs »…)
	x: number, -- position locale (studs), plan centré sur l'origine
	y: number,
	z: number,
	yaw: number, -- rotation autour de Y (radians)
	seed: number, -- graine de la variante
	layer: string, -- « Sol », « Relief », « Bordures », « Rochers » ou « Deco »
	col: number,
	row: number,
}
export type Options = { bordures: boolean?, deco: boolean?, seed: number? }

-- côtés : 1 nord (-Z), 2 est (+X), 3 sud (+Z), 4 ouest (-X) ; bit du masque = 2^(côté - 1)
local DC = { 0, 1, 0, -1 }
local DR = { -1, 0, 1, 0 }

-- Rotation d'un quart de tour dans le sens horaire vu du dessus : nord → est → sud → ouest.
local function quarter(k: number): number
	return -k * math.pi / 2
end

local function rotMask(m: number, k: number): number
	k %= 4
	return bit32.band(bit32.bor(bit32.lshift(m, k), bit32.rshift(m, 4 - k)), 15)
end

-- Chemins : module et masque de référence (côtés raccordés quand le module n'est pas tourné).
local PATHS: { { name: string, mask: number } } = {
	{ name = "Chemin_Croix", mask = 15 },
	{ name = "Chemin_T", mask = 7 }, -- nord, est, sud
	{ name = "Chemin_Droit", mask = 5 }, -- nord, sud
	{ name = "Chemin_Virage", mask = 3 }, -- nord, est
	{ name = "Chemin_Fin", mask = 1 }, -- nord
	{ name = "Chemin_Seul", mask = 0 },
}

-- Module et rotation (quarts de tour) d'une dalle de chemin selon son masque de voisins pavés.
function GroundLayout.PathFor(mask: number): (string, number)
	for _, e in PATHS do
		for k = 0, 3 do
			if rotMask(e.mask, k) == mask then
				return e.name, k
			end
		end
	end
	return "Chemin_Seul", 0
end

local function hash(a: number, b: number, c: number): number
	local h = bit32.bxor(bit32.band(a * 73856093, 0x7fffffff), bit32.band(b * 19349663, 0x7fffffff), bit32.band(c * 83492791, 0x7fffffff))
	h = bit32.band(bit32.bxor(h, bit32.rshift(h, 13)) * 1274126177, 0x7fffffff)
	return bit32.bxor(h, bit32.rshift(h, 16))
end

local HEIGHT: { [string]: number } = { ["4"] = 4, ["8"] = 8, F = 16 }
local SIMPLE: { [string]: string } = { h = "Sol_Herbe", t = "Sol_Terre", m = "Sol_Mixte", p = "Sol_Paves" }
local RAISED: { [string]: string } = { ["4"] = "Bloc_Terrain_H4", ["8"] = "Bloc_Terrain_H8", F = "Falaise_H16" }
local ROCKS: { [string]: string } = { r = "Rocher_Petit", R = "Rocher_Moyen", G = "Rocher_Grand" }
local DECO: { [string]: { string } } = {
	h = { "Deco_Touffe", "Deco_Fleurs", "Deco_Feuilles", "Deco_HerbeHaute", "Deco_Touffe" },
	m = { "Deco_Touffe", "Deco_Cailloux", "Deco_Feuilles", "Deco_Mousse" },
	t = { "Deco_Cailloux", "Deco_Bois", "Deco_Racine", "Deco_Brindille", "Deco_Champignons" },
	["#"] = { "Deco_Feuilles", "Deco_Mousse" },
	p = { "Deco_Feuilles" },
	raised = { "Deco_Touffe", "Deco_Fleurs", "Deco_HerbeHaute", "Deco_Feuilles" },
}

-- Lit un plan (lignes de même longueur, espaces ignorés).
function GroundLayout.Parse(plan: string): { { string } }
	local rows: { { string } } = {}
	for line in string.gmatch(plan, "[^\n]+") do
		local cells: { string } = {}
		for ch in string.gmatch(line, "%S") do
			table.insert(cells, ch)
		end
		if #cells > 0 then
			table.insert(rows, cells)
		end
	end
	return rows
end

-- Placements de tous les modules d'un plan.
function GroundLayout.Build(plan: string, options: Options?): { Placement }
	local opt: Options = options or {}
	local salt = opt.seed or 1
	local g = GroundLayout.Parse(plan)
	local nr = #g
	local nc = 0
	for _, row in g do
		nc = math.max(nc, #row)
	end
	local T = GroundLayout.TILE
	local function cell(r: number, c: number): string
		local row = g[r]
		return if row and row[c] then row[c] else "."
	end
	local function paved(ch: string): boolean
		return ch == "#" or ch == "p"
	end
	local out: { Placement } = {}
	for r = 1, nr do
		for c = 1, nc do
			local ch = cell(r, c)
			if ch ~= "." then
				local x = (c - (nc + 1) / 2) * T
				local z = (r - (nr + 1) / 2) * T
				local seed = hash(c + 1000, r + 2000, salt)
				local function put(module: string, k: number, layer: string, y: number?, yaw: number?, dx: number?, dz: number?, s: number?)
					table.insert(out, {
						module = module,
						x = x + (dx or 0),
						y = y or 0,
						z = z + (dz or 0),
						yaw = quarter(k) + (yaw or 0),
						seed = s or seed,
						layer = layer,
						col = c,
						row = r,
					})
				end
				local h = HEIGHT[ch]
				if SIMPLE[ch] then
					put(SIMPLE[ch], seed % 4, "Sol")
				elseif ch == "#" then
					local mask = 0
					for side = 1, 4 do
						if paved(cell(r + DR[side], c + DC[side])) then
							mask += 2 ^ (side - 1)
						end
					end
					local module, k = GroundLayout.PathFor(mask)
					put(module, k, "Sol")
					if opt.bordures then
						for side = 1, 4 do
							local n = cell(r + DR[side], c + DC[side])
							if not paved(n) and not HEIGHT[n] and n ~= "/" and n ~= "e" then
								put("Bordure_Pierre", side - 1, "Bordures", nil, nil, nil, nil, hash(c, r, side + salt))
							end
						end
					end
				elseif h then
					put(RAISED[ch], seed % 4, "Relief")
				elseif ch == "/" or ch == "e" then
					-- monte vers le premier voisin surélevé (nord, est, sud, ouest)
					local k = 0
					for side = 1, 4 do
						if HEIGHT[cell(r + DR[side], c + DC[side])] then
							k = side - 1
							break
						end
					end
					put(if ch == "/" then "Pente_H4" else "Escalier_H4", k, "Relief")
				elseif ROCKS[ch] then
					put("Sol_Herbe", seed % 4, "Sol")
					-- petits et moyens rochers décalés dans la dalle, le grand au centre
					local rs = hash(c, r, 77 + salt)
					local off = if ch == "G" then 0 else 1
					put(ROCKS[ch], 0, "Rochers", nil, (rs % 628) / 100, ((rs % 5) - 2) * off, (((rs // 7) % 5) - 2) * off, rs)
				end
				-- décor (facultatif, séparé du sol)
				if opt.deco then
					local list = if h then DECO.raised else DECO[ch] or DECO[if ROCKS[ch] then "h" else ""]
					if list then
						local n = hash(c, r, 31 + salt) % 3
						if ch == "#" or ch == "p" then
							n = if hash(c, r, 37 + salt) % 4 == 0 then 1 else 0
						end
						for i = 1, n do
							local d = hash(c * 7 + i, r * 13 + i, 41 + salt)
							local dx = (d % 600) / 100 - 3
							local dz = ((d // 600) % 600) / 100 - 3
							put(list[d % #list + 1], 0, "Deco", h or 0, (d % 628) / 100, dx, dz, d)
						end
					end
				end
			end
		end
	end
	return out
end

return GroundLayout
