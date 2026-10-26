--!strict
-- Charte de l'interface : l'esprit Pet Simulator 99 (boutons dodus, contours épais, dégradés vifs,
-- animations rebondies) dans un habillage chevaleresque (parchemin, or, bannières) avec une touche pixel
-- (icônes pixel art, police « Arcade » pour les chiffres et étiquettes, damiers en fond).

local Theme = {}

Theme.Font = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
Theme.Pixel = Font.fromEnum(Enum.Font.Arcade)
Theme.Script = Font.fromEnum(Enum.Font.Fondamento) -- calligraphie (carte, titres)
Theme.Hand = Font.fromEnum(Enum.Font.Kalam) -- écriture à la plume (annotations de la carte)

-- Encres et papier de la carte de voyage (parchemin croquis).
Theme.Paper = Color3.fromRGB(236, 214, 168)
Theme.PaperDark = Color3.fromRGB(196, 160, 104)
Theme.Sepia = Color3.fromRGB(96, 62, 34)
Theme.RedInk = Color3.fromRGB(170, 44, 32)

Theme.Ink = Color3.fromRGB(42, 28, 38)
Theme.Panel = Color3.fromRGB(255, 247, 228)
Theme.PanelDeep = Color3.fromRGB(242, 228, 198)
Theme.PanelLine = Color3.fromRGB(214, 190, 146)
Theme.Text = Color3.fromRGB(70, 46, 40)
Theme.Muted = Color3.fromRGB(150, 122, 98)
Theme.White = Color3.new(1, 1, 1)

Theme.C = {
	green = Color3.fromRGB(98, 214, 84),
	blue = Color3.fromRGB(70, 164, 255),
	red = Color3.fromRGB(240, 86, 76),
	gold = Color3.fromRGB(255, 194, 52),
	orange = Color3.fromRGB(255, 142, 52),
	purple = Color3.fromRGB(168, 108, 255),
	teal = Color3.fromRGB(56, 208, 186),
	pink = Color3.fromRGB(255, 110, 180),
	gray = Color3.fromRGB(156, 162, 178),
	brown = Color3.fromRGB(182, 120, 70),
	navy = Color3.fromRGB(48, 62, 104),
}

function Theme.Dark(c: Color3, f: number?): Color3
	return c:Lerp(Color3.new(0, 0, 0), f or 0.3)
end

function Theme.Light(c: Color3, f: number?): Color3
	return c:Lerp(Color3.new(1, 1, 1), f or 0.35)
end

Theme.Base = Vector2.new(1280, 720) -- résolution de référence de la mise à l'échelle

return Theme
