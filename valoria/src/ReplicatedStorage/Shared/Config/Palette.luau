--!strict
-- Direction artistique du sol : palette commune au kit de modules (World/GroundKit), aux détails au sol
-- (Logic/GroundDetail) et aux couleurs des matériaux du terrain (World/TerrainGen).
-- Voxel 3D stylisé : formes lisibles, blocs visibles sans effet « gros pixel », couleurs naturelles
-- légèrement saturées. Chaque famille a plusieurs nuances proches pour varier sans casser la cohérence.

local Palette = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

export type Ground = {
	grass: { Color3 }, -- herbe verte (dessus des dalles, touffes)
	grassDry: { Color3 }, -- herbe sèche dorée
	moss: { Color3 }, -- mousse dans les joints et sur les pierres
	dirt: { Color3 }, -- terre brune (semelles, côtés des blocs)
	dirtDark: Color3, -- joints des pavés
	cobble: { Color3 }, -- pavés beiges
	cobbleGray: { Color3 }, -- pavés gris clair
	rock: { Color3 }, -- rochers
	strata: { Color3 }, -- couches des falaises (de haut en bas, en boucle)
	leaves: { Color3 }, -- feuilles d'automne
	wood: { Color3 }, -- racines, bûches
	flowers: { Color3 },
}

-- Monde 1 : le Val d'Automne (base des futurs mondes)
Palette.ValDAutomne = {
	grass = { rgb(92, 148, 60), rgb(106, 162, 68), rgb(78, 130, 52), rgb(124, 174, 78) }, -- [1] = teinte de base commune
	grassDry = { rgb(190, 164, 76), rgb(172, 150, 68) },
	moss = { rgb(84, 132, 54), rgb(100, 146, 60) },
	dirt = { rgb(122, 88, 56), rgb(108, 78, 50), rgb(136, 100, 64) }, -- [1] = teinte de base commune
	dirtDark = rgb(82, 60, 42),
	cobble = { rgb(214, 198, 164), rgb(200, 184, 150), rgb(224, 210, 178), rgb(190, 172, 140) },
	cobbleGray = { rgb(182, 178, 168), rgb(168, 164, 156) },
	rock = { rgb(134, 130, 124), rgb(118, 114, 110), rgb(150, 144, 136) },
	strata = { rgb(176, 128, 86), rgb(198, 180, 142), rgb(132, 126, 120), rgb(160, 112, 76) },
	leaves = { rgb(224, 112, 40), rgb(198, 66, 42), rgb(238, 184, 62), rgb(214, 142, 50) },
	wood = { rgb(110, 78, 50), rgb(92, 64, 42) },
	flowers = { rgb(240, 82, 92), rgb(250, 210, 80), rgb(250, 248, 236), rgb(172, 122, 232) },
} :: Ground

-- Matériaux Roblox (noms d'Enum.Material) associés aux familles.
Palette.Materials = {
	grass = "Grass",
	grassDry = "LeafyGrass",
	moss = "LeafyGrass",
	dirt = "Ground",
	cobble = "Limestone",
	cobbleGray = "Slate",
	rock = "Rock",
	strata = { "Sandstone", "Limestone", "Rock", "Sandstone" },
	wood = "Wood",
	leaves = "SmoothPlastic",
	flowers = "SmoothPlastic",
}

-- Couleurs des matériaux du terrain (Terrain:SetMaterialColor, communes à tous les lieux).
Palette.Terrain = ({
	Grass = rgb(100, 158, 64),
	LeafyGrass = rgb(184, 156, 70),
	Ground = rgb(120, 88, 56),
	Mud = rgb(90, 70, 50),
	Rock = rgb(124, 120, 114),
	Sandstone = rgb(164, 118, 82),
	Limestone = rgb(178, 162, 130),
	Slate = rgb(92, 99, 108),
	Basalt = rgb(62, 64, 70),
	Sand = rgb(220, 200, 152),
	Cobblestone = rgb(196, 180, 148),
	Snow = rgb(236, 242, 248),
	Pavement = rgb(150, 144, 134),
	Salt = rgb(226, 222, 210),
}) :: { [string]: Color3 }

return Palette
