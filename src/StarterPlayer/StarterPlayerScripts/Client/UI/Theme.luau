--!nonstrict
-- Charte graphique de l'interface (bible §20 « Interface et lisibilité ») :
-- panneaux bleu nuit translucides, liserés lumineux, typographie ronde et lisible sur téléphone.

local Theme = {}

Theme.Font = {
	Title = Enum.Font.LuckiestGuy,
	Body = Enum.Font.FredokaOne,
	Light = Enum.Font.Gotham,
	Bold = Enum.Font.GothamBold,
}

Theme.Color = {
	Panel = Color3.fromRGB(18, 22, 48),
	PanelLight = Color3.fromRGB(34, 42, 86),
	PanelDark = Color3.fromRGB(10, 12, 28),
	Stroke = Color3.fromRGB(120, 170, 255),
	Text = Color3.fromRGB(245, 248, 255),
	TextDim = Color3.fromRGB(170, 182, 215),
	Accent = Color3.fromRGB(91, 200, 255),
	Gold = Color3.fromRGB(255, 205, 70),
	Energy = Color3.fromRGB(110, 230, 255),
	Gems = Color3.fromRGB(255, 110, 210),
	Crystal = Color3.fromRGB(180, 140, 255),
	Success = Color3.fromRGB(100, 230, 120),
	Warning = Color3.fromRGB(255, 180, 60),
	Error = Color3.fromRGB(255, 80, 90),
	Storm = Color3.fromRGB(170, 120, 255),
	Button = Color3.fromRGB(60, 120, 255),
	ButtonGreen = Color3.fromRGB(60, 190, 110),
	ButtonRed = Color3.fromRGB(220, 70, 80),
	ButtonGold = Color3.fromRGB(240, 170, 40),
	ButtonGray = Color3.fromRGB(80, 90, 120),
	Bronze = Color3.fromRGB(205, 127, 50),
	Silver = Color3.fromRGB(200, 210, 225),
}

Theme.Icon = {
	Energy = "⚡",
	Gems = "💎",
	Crystals = "🔮",
	Shards = "✦",
	Power = "⚔",
	Rank = "★",
	Storm = "🌀",
	Team = "🛡",
	Summon = "✨",
	Index = "📖",
	Quests = "📜",
	Shop = "🛒",
	Trade = "🤝",
	Map = "🗺",
	Settings = "⚙",
	Base = "🏠",
	Forge = "🔨",
	Codes = "🎁",
	Close = "✕",
	Lock = "🔒",
	Star = "★",
	Dodge = "💨",
	Attack = "⚔",
}

-- Couleurs des éclats par île (lisibles sur fond sombre).
Theme.ShardColor = {
	Ether = Color3.fromRGB(110, 255, 140),
	Solar = Color3.fromRGB(255, 200, 70),
	Prism = Color3.fromRGB(255, 80, 210),
	Frost = Color3.fromRGB(150, 225, 255),
	Magma = Color3.fromRGB(255, 110, 50),
}

Theme.Tier = {
	Gold = Color3.fromRGB(255, 205, 70),
	Silver = Color3.fromRGB(200, 210, 225),
	Bronze = Color3.fromRGB(205, 127, 50),
}

return Theme
