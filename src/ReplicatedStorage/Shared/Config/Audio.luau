--!nonstrict
-- Sons et musiques. Par défaut, seuls des sons intégrés au client Roblox (rbxasset://) sont utilisés,
-- donc tout fonctionne sans téléversement. Remplacez par vos propres "rbxassetid://<id>" pour la version finale.
-- Les musiques sont vides par défaut : collez l'id d'une piste de la bibliothèque Roblox (Creator Store > Audio).

local Audio = {}

Audio.Sfx = {
	Click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5 },
	Notify = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.35 },
	Error = { id = "rbxasset://sounds/button.wav", volume = 0.5, pitch = 0.7 },
	Fanfare = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = 1.3 },
	Alarm = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8, pitch = 0.6 },
	LevelUp = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = 1.6 },
	Slash = { id = "rbxasset://sounds/swordslash.wav", volume = 0.45 },
	Lunge = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.5 },
	Skill = { id = "rbxasset://sounds/unsheath.wav", volume = 0.5 },
	Boom = { id = "rbxasset://sounds/Rocket shot.wav", volume = 0.45, pitch = 0.8 },
	Whoosh = { id = "rbxasset://sounds/Rocket whoosh 01.wav", volume = 0.35, pitch = 1.4 },
	Hit = { id = "rbxasset://sounds/collide.wav", volume = 0.35 },
	Hurt = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.3 },
	Collect = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = 1.9 },
	Capture = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = 0.9 },
	Reveal = { id = "rbxasset://sounds/Launching rocket.wav", volume = 0.4, pitch = 1.2 },
	Splat = { id = "rbxasset://sounds/splat.wav", volume = 0.4 },
	Jump = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.4 },
}

-- Musiques d'ambiance par zone (bible §21). "" = silence.
Audio.Music = {
	Hub = "",
	Forest = "",
	Desert = "",
	Neon = "",
	Glacier = "",
	Volcano = "",
	Storm = "",
	Boss = "",
	Duel = "",
}

-- Ambiances en boucle (vent, insectes…), facultatives.
Audio.Ambience = {
	Hub = "",
	Forest = "",
	Desert = "",
	Neon = "",
	Glacier = "",
	Volcano = "",
}

return Audio
