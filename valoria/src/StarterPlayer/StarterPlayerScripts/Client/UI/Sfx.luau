--!strict
-- Effets sonores de l'interface : un nom → un son. Les sons 8 bits du jeu sont générés par
-- tools/audio/sfx.py (assets/sfx/<Nom>.ogg) ; une fois téléversés, leurs identifiants se renseignent dans
-- UI/SoundAssets.luau. En attendant, des sons intégrés au client Roblox (rbxasset://) les remplacent, chacun
-- avec sa propre hauteur. Anti-rafale : un même son ne rejoue pas avant `gap` secondes (survol, pièces…).

local SoundService = game:GetService("SoundService")

local SoundAssets = require(script.Parent.SoundAssets)

local Sfx = {}

Sfx.enabled = true -- coupé par le réglage « Effets sonores »
Sfx.volume = 1 -- volume général des effets

export type Def = {
	fallback: string, -- son intégré de remplacement
	volume: number,
	pitch: number?, -- hauteur du son de remplacement
	gap: number?, -- délai minimal entre deux lectures
	vary: number?, -- variation aléatoire de hauteur (± fraction)
}

local PING = "rbxasset://sounds/electronicpingshort.wav"
local UNSHEATH = "rbxasset://sounds/unsheath.wav"
local LUNGE = "rbxasset://sounds/swordlunge.wav"
local SLASH = "rbxasset://sounds/swordslash.wav"

Sfx.List = {
	-- interface
	Click = { fallback = PING, volume = 0.25, pitch = 1.6, gap = 0.03 },
	Hover = { fallback = PING, volume = 0.06, pitch = 2.6, gap = 0.08, vary = 0.06 },
	Open = { fallback = PING, volume = 0.22, pitch = 1.35, gap = 0.1 },
	Close = { fallback = PING, volume = 0.2, pitch = 1.1, gap = 0.1 },
	Tab = { fallback = PING, volume = 0.16, pitch = 2.0, gap = 0.05 },
	Toggle = { fallback = PING, volume = 0.2, pitch = 1.7, gap = 0.05 },
	Error = { fallback = PING, volume = 0.3, pitch = 0.6, gap = 0.15 },
	Notify = { fallback = PING, volume = 0.25, pitch = 1.25, gap = 0.1 },
	Success = { fallback = PING, volume = 0.3, pitch = 1.5, gap = 0.1 },
	Pop = { fallback = PING, volume = 0.2, pitch = 1.9, gap = 0.04, vary = 0.1 },
	Whoosh = { fallback = LUNGE, volume = 0.2, pitch = 1.4, gap = 0.1 },
	-- monnaies et récompenses
	Coin = { fallback = PING, volume = 0.15, pitch = 2.2, gap = 0.05 },
	Gem = { fallback = PING, volume = 0.2, pitch = 2.5, gap = 0.05 },
	Rune = { fallback = PING, volume = 0.2, pitch = 1.2, gap = 0.08 },
	Reward = { fallback = PING, volume = 0.4, pitch = 1.9, gap = 0.2 },
	Fanfare = { fallback = PING, volume = 0.4, pitch = 0.9, gap = 0.3 },
	LevelUp = { fallback = PING, volume = 0.45, pitch = 0.8, gap = 0.3 },
	Purchase = { fallback = PING, volume = 0.35, pitch = 2.0, gap = 0.1 },
	Unlock = { fallback = UNSHEATH, volume = 0.35, pitch = 1.3, gap = 0.2 },
	-- héros et invocations
	Summon = { fallback = UNSHEATH, volume = 0.5, gap = 0.1 },
	Reveal = { fallback = LUNGE, volume = 0.45, gap = 0.04, vary = 0.05 },
	RevealRare = { fallback = LUNGE, volume = 0.5, pitch = 1.2, gap = 0.1 },
	Equip = { fallback = UNSHEATH, volume = 0.25, pitch = 1.6, gap = 0.08 },
	Trash = { fallback = LUNGE, volume = 0.25, pitch = 0.7, gap = 0.1 },
	-- combat
	Slash = { fallback = SLASH, volume = 0.25, vary = 0.08 },
} :: { [string]: Def }

local pool: { [string]: Sound } = {}
local last: { [string]: number } = {}

local function soundOf(name: string, def: Def): Sound
	local s = pool[name]
	if s then
		return s
	end
	local snd = Instance.new("Sound")
	snd.Name = name
	local asset = SoundAssets[name]
	snd.SoundId = asset or def.fallback
	snd:SetAttribute("Base", if asset then 1 else (def.pitch or 1))
	snd.Volume = def.volume
	snd.Parent = SoundService
	pool[name] = snd
	return snd
end

-- Joue un effet ; `pitch` multiplie la hauteur (séries de pièces qui montent, par exemple).
function Sfx.Play(name: string, pitch: number?)
	if not Sfx.enabled then
		return
	end
	local def = Sfx.List[name]
	if not def then
		return
	end
	local now = os.clock()
	if def.gap and now - (last[name] or 0) < def.gap then
		return
	end
	last[name] = now
	local snd = soundOf(name, def)
	local base = snd:GetAttribute("Base")
	local vary = def.vary or 0.04
	snd.PlaybackSpeed = (if type(base) == "number" then base else 1) * (pitch or 1) * (1 - vary + math.random() * vary * 2)
	snd.Volume = def.volume * Sfx.volume
	SoundService:PlayLocalSound(snd)
end

return Sfx
