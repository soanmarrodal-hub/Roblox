--!strict
-- Textes d'interface : français (référence), anglais, espagnol, portugais (bible §20).

local Locale = {}

local T: { [string]: { [string]: string } } = {
	energy = { fr = "Énergie", en = "Energy", es = "Energía", pt = "Energia" },
	gems = { fr = "Gemmes", en = "Gems", es = "Gemas", pt = "Gemas" },
	shards = { fr = "Éclats", en = "Shards", es = "Fragmentos", pt = "Fragmentos" },
	team = { fr = "Équipe", en = "Team", es = "Equipo", pt = "Equipe" },
	summon = { fr = "Invocation", en = "Summon", es = "Invocar", pt = "Invocar" },
	index = { fr = "Index", en = "Index", es = "Índice", pt = "Índice" },
	quests = { fr = "Quêtes", en = "Quests", es = "Misiones", pt = "Missões" },
	shop = { fr = "Boutique", en = "Shop", es = "Tienda", pt = "Loja" },
	trade = { fr = "Échanges", en = "Trades", es = "Intercambios", pt = "Trocas" },
	map = { fr = "Carte", en = "Map", es = "Mapa", pt = "Mapa" },
	settings = { fr = "Paramètres", en = "Settings", es = "Ajustes", pt = "Configurações" },
	base = { fr = "Base", en = "Base", es = "Base", pt = "Base" },
	returnBase = { fr = "Retour base", en = "Return home", es = "Volver a la base", pt = "Voltar à base" },
	collect = { fr = "Collecter", en = "Collect", es = "Recoger", pt = "Coletar" },
	harvest = { fr = "Récolter", en = "Harvest", es = "Cosechar", pt = "Colher" },
	capture = { fr = "Capturer", en = "Capture", es = "Capturar", pt = "Capturar" },
	steal = { fr = "Voler", en = "Steal", es = "Robar", pt = "Roubar" },
	defend = { fr = "Défendre", en = "Defend", es = "Defender", pt = "Defender" },
	attack = { fr = "Attaque", en = "Attack", es = "Ataque", pt = "Ataque" },
	dodge = { fr = "Esq.", en = "Dodge", es = "Esq.", pt = "Esq." },
	power = { fr = "Puissance", en = "Power", es = "Poder", pt = "Poder" },
	nextStorm = { fr = "Prochaine tempête", en = "Next storm", es = "Próxima tormenta", pt = "Próxima tempestade" },
	stormIn = { fr = "Tempête dans", en = "Storm in", es = "Tormenta en", pt = "Tempestade em" },
	stormActive = { fr = "TEMPÊTE !", en = "STORM!", es = "¡TORMENTA!", pt = "TEMPESTADE!" },
	display = { fr = "Exposer", en = "Display", es = "Exponer", pt = "Expor" },
	leader = { fr = "Leader", en = "Leader", es = "Líder", pt = "Líder" },
	vault = { fr = "Coffre", en = "Vault", es = "Cofre", pt = "Cofre" },
	upgrade = { fr = "Améliorer", en = "Upgrade", es = "Mejorar", pt = "Melhorar" },
	pull1 = { fr = "x1", en = "x1", es = "x1", pt = "x1" },
	pull10 = { fr = "x10", en = "x10", es = "x10", pt = "x10" },
	rates = { fr = "Taux", en = "Rates", es = "Probabilidades", pt = "Chances" },
	pity = { fr = "Pitié", en = "Pity", es = "Garantía", pt = "Garantia" },
	close = { fr = "Fermer", en = "Close", es = "Cerrar", pt = "Fechar" },
	claim = { fr = "Réclamer", en = "Claim", es = "Reclamar", pt = "Resgatar" },
	buy = { fr = "Acheter", en = "Buy", es = "Comprar", pt = "Comprar" },
	baseAttacked = { fr = "Ta base est attaquée par", en = "Your base is attacked by", es = "Tu base es atacada por", pt = "Sua base é atacada por" },
	abandon = { fr = "Abandonner", en = "Give up", es = "Abandonar", pt = "Desistir" },
	rank = { fr = "Rang", en = "Rank", es = "Rango", pt = "Nível" },
	locked = { fr = "Verrouillé", en = "Locked", es = "Bloqueado", pt = "Bloqueado" },
	quality = { fr = "Qualité graphique", en = "Graphics quality", es = "Calidad gráfica", pt = "Qualidade gráfica" },
	language = { fr = "Langue", en = "Language", es = "Idioma", pt = "Idioma" },
	cameraShake = { fr = "Secousses de caméra", en = "Camera shake", es = "Vibración de cámara", pt = "Tremor de câmera" },
	music = { fr = "Musique", en = "Music", es = "Música", pt = "Música" },
	sfx = { fr = "Effets sonores", en = "Sound effects", es = "Efectos", pt = "Efeitos" },
	skip = { fr = "Toucher pour passer", en = "Tap to skip", es = "Toca para saltar", pt = "Toque para pular" },
	codes = { fr = "Codes", en = "Codes", es = "Códigos", pt = "Códigos" },
	redeem = { fr = "Valider", en = "Redeem", es = "Canjear", pt = "Resgatar" },
	forge = { fr = "Forge", en = "Forge", es = "Forja", pt = "Forja" },
	fuse = { fr = "Fusionner", en = "Fuse", es = "Fusionar", pt = "Fundir" },
	levelUp = { fr = "Niveau +1", en = "Level +1", es = "Nivel +1", pt = "Nível +1" },
	daily = { fr = "Quotidiennes", en = "Daily", es = "Diarias", pt = "Diárias" },
	weekly = { fr = "Hebdomadaires", en = "Weekly", es = "Semanales", pt = "Semanais" },
	guided = { fr = "Guidées", en = "Guided", es = "Guiadas", pt = "Guiadas" },
	contracts = { fr = "Contrats", en = "Contracts", es = "Contratos", pt = "Contratos" },
	inventory = { fr = "Inventaire", en = "Inventory", es = "Inventario", pt = "Inventário" },
	production = { fr = "Production", en = "Production", es = "Producción", pt = "Produção" },
	level = { fr = "Niv.", en = "Lv.", es = "Niv.", pt = "Nv." },
	gate = { fr = "Porte", en = "Gate", es = "Puerta", pt = "Portão" },
	open = { fr = "Ouvrir", en = "Open", es = "Abrir", pt = "Abrir" },
	teleport = { fr = "Téléporter", en = "Teleport", es = "Teletransportar", pt = "Teletransportar" },
}

Locale.Languages = { "fr", "en", "es", "pt" }
Locale.Current = "fr"

function Locale.t(key: string): string
	local e = T[key]
	if not e then
		return key
	end
	return e[Locale.Current] or e.fr or key
end

function Locale.Set(lang: string)
	if table.find(Locale.Languages, lang) then
		Locale.Current = lang
	end
end

-- Choisit une langue à partir du code régional Roblox (ex. "fr-fr").
function Locale.FromLocaleId(id: string): string
	local code = string.sub(string.lower(id), 1, 2)
	if table.find(Locale.Languages, code) then
		return code
	end
	return "fr"
end

return Locale
