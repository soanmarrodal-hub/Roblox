--!strict
-- Bibliothèque de poses d'attaque (images clés). Chaque clé donne, pour certains os, une rotation locale
-- additionnelle (radians, ordre X/Y/Z de CFrame.Angles) ; la clé spéciale `_root` décale le bassin (studs,
-- repère du modèle, -Z = vers l'avant) et `_tilt` l'incline. Entre deux clés, l'interpolation est adoucie.
--
-- Conventions (os au repos, personnage tourné vers -Z) :
--   X positif sur un bras ou une jambe = vers l'avant ; X négatif sur le torse = penché en avant.
--   Z positif lève le bras droit sur le côté (négatif pour le gauche).
--   Y positif = rotation vers la gauche (vu de dessus).

local Poses = {}

export type Key = { t: number, pose: { [string]: Vector3 } }
export type Clip = { dur: number, impact: number, keys: { Key }, release: number? }

local function v(x: number, y: number?, z: number?): Vector3
	return Vector3.new(x, y or 0, z or 0)
end

local function clip(dur: number, impact: number, keys: { { any } }, release: number?): Clip
	local out: { Key } = {}
	for _, k in keys do
		table.insert(out, { t = k[1] :: number, pose = (k[2] or {}) :: { [string]: Vector3 } })
	end
	return { dur = dur, impact = impact, keys = out, release = release }
end

------------------------------------------------------------------ bipèdes

Poses.Biped = {
	Slash = clip(0.62, 0.27, {
		{ 0, {} },
		{
			0.17,
			{
				UpperArmR = v(-2.3, 0.2, 0.55),
				ForearmR = v(1.1),
				HandR = v(0.3),
				Chest = v(0.12, 0.55, 0.05),
				Hips = v(0, 0.15),
				_root = v(0, -0.08, 0.15),
				ThighR = v(-0.15),
				ThighL = v(0.25),
			},
		},
		{
			0.29,
			{
				UpperArmR = v(0.9, -0.3, -0.45),
				ForearmR = v(0.35),
				HandR = v(-0.4),
				Chest = v(-0.3, -0.55, -0.08),
				Hips = v(0, -0.2),
				Head = v(0.1, 0.3),
				_root = v(0, -0.18, -0.55),
				ThighR = v(0.45),
				ShinR = v(-0.35),
				ThighL = v(-0.3),
				UpperArmL = v(-0.3, 0, -0.35),
			},
		},
		{ 0.42, { UpperArmR = v(0.6, -0.2, -0.3), ForearmR = v(0.4), Chest = v(-0.18, -0.35), _root = v(0, -0.1, -0.35), ThighR = v(0.3) } },
		{ 0.62, {} },
	}),
	Cleave = clip(0.85, 0.43, {
		{ 0, {} },
		{
			0.3,
			{
				UpperArmR = v(-2.7, 0.1, 0.25),
				UpperArmL = v(-2.5, -0.1, -0.3),
				ForearmR = v(0.8),
				ForearmL = v(0.8),
				Chest = v(0.28, 0.25),
				Head = v(-0.1),
				_root = v(0, 0.05, 0.25),
				ThighL = v(0.3),
				ThighR = v(-0.2),
			},
		},
		{
			0.45,
			{
				UpperArmR = v(1.1, -0.2, -0.2),
				UpperArmL = v(1.0, 0.2, 0.25),
				ForearmR = v(0.2),
				ForearmL = v(0.3),
				Chest = v(-0.55, -0.2),
				Hips = v(-0.15),
				Head = v(0.3),
				_root = v(0, -0.35, -0.75),
				ThighR = v(0.7),
				ShinR = v(-0.7),
				ThighL = v(-0.25),
				ShinL = v(-0.25),
			},
		},
		{ 0.6, { UpperArmR = v(0.9), UpperArmL = v(0.85), Chest = v(-0.45), _root = v(0, -0.3, -0.6), ThighR = v(0.55), ShinR = v(-0.55) } },
		{ 0.85, {} },
	}),
	Thrust = clip(0.55, 0.24, {
		{ 0, {} },
		{ 0.15, { UpperArmR = v(-0.3, 0, 0.25), ForearmR = v(1.6), Chest = v(0.05, 0.45), Hips = v(0, 0.2), _root = v(0, -0.06, 0.3), ThighL = v(0.3) } },
		{
			0.25,
			{
				UpperArmR = v(1.5, 0.1, 0.05),
				ForearmR = v(0.05),
				Chest = v(-0.2, -0.4),
				Hips = v(0, -0.25),
				Head = v(0.15, 0.2),
				_root = v(0, -0.22, -0.8),
				ThighR = v(0.6),
				ShinR = v(-0.45),
				ThighL = v(-0.4),
			},
		},
		{ 0.38, { UpperArmR = v(1.3), ForearmR = v(0.2), Chest = v(-0.12, -0.2), _root = v(0, -0.12, -0.5), ThighR = v(0.4) } },
		{ 0.55, {} },
	}),
	Lance = clip(0.75, 0.42, {
		{ 0, {} },
		{
			0.22,
			{ UpperArmR = v(-0.2, 0, 0.3), ForearmR = v(1.3), Chest = v(0.15, 0.3), _root = v(0, -0.45, 0.35), ThighR = v(0.5), ShinR = v(-1.0), ThighL = v(0.5), ShinL = v(-1.0) },
		},
		{
			0.34,
			{ UpperArmR = v(1.2), ForearmR = v(0.3), Chest = v(-0.3), _root = v(0, 1.4, -1.0), ThighR = v(0.4), ShinR = v(-0.9), ThighL = v(-0.2) },
		},
		{
			0.45,
			{ UpperArmR = v(1.6), ForearmR = v(0.0), Chest = v(-0.45), Head = v(0.2), _root = v(0, -0.25, -1.6), ThighR = v(0.8), ShinR = v(-0.8), ThighL = v(-0.45) },
		},
		{ 0.75, {} },
	}),
	Bow = clip(0.9, 0.62, {
		{ 0, {} },
		{ 0.2, { UpperArmL = v(1.45, -0.15, -0.1), ForearmL = v(0.05), UpperArmR = v(1.35, 0.1, 0.1), ForearmR = v(1.4), Chest = v(0, 0.75), Head = v(0, -0.6) } },
		{
			0.55,
			{ UpperArmL = v(1.5, -0.25, -0.05), ForearmL = v(0), UpperArmR = v(1.3, 0.6, 0.3), ForearmR = v(2.2), HandR = v(0, 0.3), Chest = v(-0.05, 0.85), Head = v(0.05, -0.7) },
		},
		{ 0.62, { UpperArmL = v(1.55, -0.25), UpperArmR = v(0.6, 0.6, 0.7), ForearmR = v(0.5), Chest = v(0, 0.85), Head = v(0, -0.7) } },
		{ 0.9, {} },
	}, 0.6),
	Throw = clip(0.7, 0.42, {
		{ 0, {} },
		{ 0.28, { UpperArmR = v(-2.6, 0, 0.35), ForearmR = v(0.9), Chest = v(0.2, 0.6), Hips = v(0, 0.25), UpperArmL = v(1.2, 0, -0.3), _root = v(0, 0, 0.3), ThighL = v(0.4) } },
		{ 0.4, { UpperArmR = v(1.2, -0.2, -0.2), ForearmR = v(0.1), Chest = v(-0.35, -0.5), Hips = v(0, -0.3), UpperArmL = v(-0.4), _root = v(0, -0.15, -0.5), ThighR = v(0.5), ThighL = v(-0.3) } },
		{ 0.7, {} },
	}, 0.4),
	Staff = clip(0.8, 0.45, {
		{ 0, {} },
		{ 0.25, { UpperArmR = v(-0.6, 0, 0.35), ForearmR = v(1.6), UpperArmL = v(0.9, 0, -0.4), ForearmL = v(1.0), Chest = v(0.15, 0.3), Head = v(-0.1) } },
		{ 0.42, { UpperArmR = v(1.9, -0.2, 0.1), ForearmR = v(0.2), UpperArmL = v(1.4, 0.3, -0.2), ForearmL = v(0.4), Chest = v(-0.2, -0.2), _root = v(0, 0.05, -0.3) } },
		{ 0.55, { UpperArmR = v(1.7), ForearmR = v(0.3), UpperArmL = v(1.2), Chest = v(-0.15) } },
		{ 0.8, {} },
	}, 0.42),
	Claw = clip(0.55, 0.24, {
		{ 0, {} },
		{ 0.14, { UpperArmR = v(-1.8, 0, 0.7), ForearmR = v(1.2), Chest = v(0.15, 0.5), _root = v(0, -0.1, 0.2) } },
		{ 0.25, { UpperArmR = v(1.0, -0.4, -0.5), ForearmR = v(0.3), Chest = v(-0.3, -0.5), Head = v(0.2), _root = v(0, -0.2, -0.6), ThighR = v(0.4) } },
		{ 0.34, { UpperArmL = v(-1.6, 0, -0.7), ForearmL = v(1.1), UpperArmR = v(0.6), Chest = v(-0.1, -0.5) } },
		{ 0.45, { UpperArmL = v(1.0, 0.4, 0.5), ForearmL = v(0.3), Chest = v(-0.3, 0.45), _root = v(0, -0.2, -0.6) } },
		{ 0.55, {} },
	}),
	Slam = clip(0.95, 0.52, {
		{ 0, {} },
		{
			0.38,
			{ UpperArmR = v(-2.9, 0, 0.2), UpperArmL = v(-2.9, 0, -0.2), ForearmR = v(0.4), ForearmL = v(0.4), Chest = v(0.35), Head = v(-0.2), _root = v(0, 0.4, 0.2) },
		},
		{
			0.52,
			{
				UpperArmR = v(0.9, 0, -0.1),
				UpperArmL = v(0.9, 0, 0.1),
				ForearmR = v(0.1),
				ForearmL = v(0.1),
				Chest = v(-0.75),
				Head = v(0.4),
				_root = v(0, -0.6, -0.4),
				ThighR = v(0.6),
				ShinR = v(-0.9),
				ThighL = v(0.6),
				ShinL = v(-0.9),
			},
		},
		{ 0.7, { UpperArmR = v(0.8), UpperArmL = v(0.8), Chest = v(-0.6), _root = v(0, -0.5, -0.35), ThighR = v(0.5), ShinR = v(-0.8), ThighL = v(0.5), ShinL = v(-0.8) } },
		{ 0.95, {} },
	}),
	Scythe = clip(0.8, 0.4, {
		{ 0, {} },
		{ 0.22, { UpperArmR = v(0.2, 0.3, 1.2), ForearmR = v(0.5), UpperArmL = v(1.1, 0, -0.3), Chest = v(0.1, 1.1), Hips = v(0, 0.4), _root = v(0, -0.1, 0.2) } },
		{ 0.4, { UpperArmR = v(0.5, -0.3, 1.1), ForearmR = v(0.2), Chest = v(-0.15, -1.3), Hips = v(0, -0.5), _root = v(0, -0.2, -0.5), ThighR = v(0.4) } },
		{ 0.55, { UpperArmR = v(0.4, 0, 0.9), Chest = v(-0.1, -1.0), Hips = v(0, -0.35) } },
		{ 0.8, {} },
	}),
	-- recul après un coup reçu (utilisé pour les ennemis bipèdes)
	Flinch = clip(0.35, 0, {
		{ 0, {} },
		{ 0.08, { Chest = v(0.3, 0.15), Head = v(0.25), UpperArmR = v(-0.3, 0, 0.3), UpperArmL = v(-0.3, 0, -0.3), _root = v(0, -0.05, 0.25) } },
		{ 0.35, {} },
	}),
}

------------------------------------------------------------------ quadrupèdes

Poses.Quadruped = {
	Bite = clip(0.6, 0.3, {
		{ 0, {} },
		{
			0.16,
			{ Chest = v(0.2), Neck = v(0.3), Head = v(0.25), LegFR1 = v(-0.4), LegFL1 = v(-0.4), LegBR1 = v(0.5), LegBL1 = v(0.5), _root = v(0, -0.35, 0.35) },
		},
		{
			0.28,
			{
				Chest = v(-0.25),
				Neck = v(-0.45),
				Head = v(-0.2),
				Jaw = v(0.75),
				LegFR1 = v(0.8),
				LegFL1 = v(0.7),
				LegBR1 = v(-0.6),
				LegBL1 = v(-0.6),
				_root = v(0, 0.4, -1.3),
			},
		},
		{ 0.34, { Neck = v(-0.35), Head = v(0.1), Jaw = v(0), _root = v(0, 0.05, -1.1), LegFR1 = v(0.4), LegFL1 = v(0.4) } },
		{ 0.6, {} },
	}),
	Charge = clip(0.7, 0.36, {
		{ 0, {} },
		{ 0.2, { Neck = v(0.35), Head = v(0.35), Chest = v(0.1), LegFR1 = v(-0.3), LegFL1 = v(-0.2), _root = v(0, -0.2, 0.5) } },
		{ 0.36, { Neck = v(-0.5), Head = v(-0.55), Chest = v(-0.2), LegFR1 = v(0.9), LegFL1 = v(0.7), LegBR1 = v(-0.8), LegBL1 = v(-0.7), _root = v(0, 0.25, -1.6) } },
		{ 0.48, { Neck = v(-0.3), Head = v(-0.3), _root = v(0, 0.1, -1.2) } },
		{ 0.7, {} },
	}),
	Claw = clip(0.55, 0.28, {
		{ 0, {} },
		{ 0.18, { LegFR1 = v(-1.4), LegFR2 = v(-0.8), Chest = v(0.35), Neck = v(0.2), _root = v(0, 0.3, 0.2) } },
		{ 0.3, { LegFR1 = v(1.0), LegFR2 = v(0.2), Chest = v(-0.25), Neck = v(-0.2), _root = v(0, -0.1, -0.5) } },
		{ 0.55, {} },
	}),
	Flinch = clip(0.35, 0, {
		{ 0, {} },
		{ 0.08, { Neck = v(0.35), Head = v(0.3), Chest = v(0.15), _root = v(0, 0, 0.3) } },
		{ 0.35, {} },
	}),
}

------------------------------------------------------------------ créatures ailées (wyvernes, dragons, gargouilles)

Poses.Flyer = {
	Breath = clip(1.0, 0.45, {
		{ 0, {} },
		{ 0.3, { Neck1 = v(0.45), Neck2 = v(0.35), Head = v(0.3), Jaw = v(0.1), Chest = v(0.2), _root = v(0, 0.3, 0.5) } },
		{ 0.45, { Neck1 = v(-0.35), Neck2 = v(-0.25), Head = v(-0.15), Jaw = v(0.85), Chest = v(-0.15), _root = v(0, 0, -0.4) } },
		{ 0.8, { Neck1 = v(-0.3), Neck2 = v(-0.2), Head = v(-0.1), Jaw = v(0.8), _root = v(0, 0, -0.3) } },
		{ 1.0, {} },
	}, 0.45),
	Claw = clip(0.7, 0.4, {
		{ 0, {} },
		{ 0.25, { _root = v(0, 1.4, 0.8), Chest = v(0.3), LegR1 = v(-0.5), LegL1 = v(-0.5), ThighR = v(-0.4), ThighL = v(-0.4) } },
		{
			0.4,
			{ _root = v(0, -0.5, -1.4), Chest = v(-0.5), LegR1 = v(1.1), LegL1 = v(1.1), ThighR = v(0.9), ThighL = v(0.9), UpperArmR = v(1.2), UpperArmL = v(1.2) },
		},
		{ 0.7, {} },
	}),
	Bite = clip(0.6, 0.3, {
		{ 0, {} },
		{ 0.18, { Neck1 = v(0.4), Neck2 = v(0.3), Head = v(0.2), _root = v(0, 0.2, 0.3) } },
		{ 0.3, { Neck1 = v(-0.5), Neck2 = v(-0.35), Jaw = v(0.7), _root = v(0, -0.1, -0.8) } },
		{ 0.38, { Jaw = v(0) } },
		{ 0.6, {} },
	}),
	Flinch = clip(0.35, 0, {
		{ 0, {} },
		{ 0.08, { Neck1 = v(0.3), Neck2 = v(0.2), Chest = v(0.2), Head = v(0.2), _root = v(0, 0.3, 0.3) } },
		{ 0.35, {} },
	}),
}

------------------------------------------------------------------ crabes

Poses.Crab = {
	Claw = clip(0.6, 0.3, {
		{ 0, {} },
		{ 0.18, { ClawR1 = v(-0.7, 0.2, 0.3), ClawR2 = v(0, 0.4), ClawL1 = v(-0.4, -0.2, -0.2), Body = v(0.15), _root = v(0, 0.1, 0.2) } },
		{ 0.3, { ClawR1 = v(0.6, -0.3, -0.2), ClawR2 = v(0, -0.5), Body = v(-0.15), _root = v(0, -0.05, -0.6) } },
		{ 0.42, { ClawL1 = v(0.5, 0.3, 0.2), ClawL2 = v(0, 0.5), ClawR1 = v(0.2) } },
		{ 0.6, {} },
	}),
	Flinch = clip(0.3, 0, {
		{ 0, {} },
		{ 0.08, { Body = v(0.2), ClawR1 = v(-0.3), ClawL1 = v(-0.3), _root = v(0, 0.05, 0.25) } },
		{ 0.3, {} },
	}),
}

------------------------------------------------------------------ tentacules (le choix du tentacule est fait par l'animateur)

Poses.Tentacled = {
	Tentacle = clip(1.0, 0.55, {
		{ 0, {} },
		{ 0.35, { Body = v(0.15), Head = v(0.2), _root = v(0, 0.4, 0.2) } },
		{ 0.55, { Body = v(-0.2), Head = v(-0.2), _root = v(0, -0.2, -0.4) } },
		{ 1.0, {} },
	}),
	Flinch = clip(0.35, 0, {
		{ 0, {} },
		{ 0.1, { Body = v(0.2), Head = v(0.25), _root = v(0, 0.2, 0.2) } },
		{ 0.35, {} },
	}),
}

------------------------------------------------------------------ attaques spéciales (une animation par héros)
-- Clés « Sp… » : Config/Heroes (`special.anim`). Une rotation complète du bassin (Hips / Body) est ramenée à
-- zéro par l'animateur à la fin du clip (pas de retour en arrière visible).

local TAU = math.pi * 2

-- bipèdes
Poses.Biped.SpOverhead = clip(1.0, 0.52, { -- Tobin : taille vaillante à deux mains
	{ 0, {} },
	{ 0.3, { UpperArmR = v(-2.9, 0, 0.25), UpperArmL = v(-2.6, 0, -0.3), ForearmR = v(-0.4), ForearmL = v(-0.4), Chest = v(0.35), Head = v(0.2), _root = v(0, 0.15, 0.35), ThighL = v(0.3), ThighR = v(-0.2) } },
	{ 0.42, { UpperArmR = v(-3.1, 0, 0.2), UpperArmL = v(-2.8, 0, -0.25), ForearmR = v(-0.4), ForearmL = v(-0.4), Chest = v(0.42), _root = v(0, 0.3, 0.3) } },
	{ 0.52, { UpperArmR = v(1.0, 0, -0.2), UpperArmL = v(0.9, 0, 0.2), ForearmR = v(0.2), Chest = v(-0.65), Head = v(-0.1), _root = v(0, -0.45, -1.1), ThighR = v(0.7), ShinR = v(-0.8), ThighL = v(-0.4) } },
	{ 0.72, { UpperArmR = v(0.9, 0, -0.2), UpperArmL = v(0.8, 0, 0.2), Chest = v(-0.55), _root = v(0, -0.4, -1.0), ThighR = v(0.6), ShinR = v(-0.7) } },
	{ 1.0, {} },
})
Poses.Biped.SpVolley = clip(1.1, 0.56, { -- Lise : pluie de flèches tirée vers le ciel
	{ 0, {} },
	{ 0.25, { UpperArmL = v(-2.3, 0, -0.1), UpperArmR = v(-2.0, 0, 0.5), ForearmR = v(1.2), Chest = v(0.45), Head = v(0.55), _root = v(0, -0.1, 0.2), ThighR = v(-0.3), ThighL = v(0.35) } },
	{ 0.5, { UpperArmL = v(-2.4, 0, -0.1), UpperArmR = v(-1.6, 0, 0.9), ForearmR = v(1.6), Chest = v(0.5), Head = v(0.6), _root = v(0, -0.15, 0.25) } },
	{ 0.56, { UpperArmL = v(-2.4, 0, -0.1), UpperArmR = v(-1.1, 0, 1.2), ForearmR = v(0.2), Chest = v(0.45), Head = v(0.6), _root = v(0, -0.1, 0.35) } },
	{ 0.8, { UpperArmL = v(-2.0, 0, -0.1), UpperArmR = v(-0.9, 0, 1.0), Chest = v(0.35), Head = v(0.45) } },
	{ 1.1, {} },
}, 0.56)
Poses.Biped.SpRapid = clip(0.95, 0.2, { -- Gaspard : trois coups de fourche
	{ 0, {} },
	{ 0.1, { UpperArmR = v(-0.6, 0, 0.2), UpperArmL = v(-0.5), Chest = v(0.2, 0.3), _root = v(0, 0, 0.3) } },
	{ 0.2, { UpperArmR = v(-1.5, 0, -0.1), UpperArmL = v(-1.3), ForearmR = v(-0.2), Chest = v(-0.3, -0.2), _root = v(0, -0.1, -0.8) } },
	{ 0.32, { UpperArmR = v(-0.6, 0, 0.2), UpperArmL = v(-0.5), Chest = v(0.2, 0.3), _root = v(0, 0, 0.1) } },
	{ 0.42, { UpperArmR = v(-1.5, 0, -0.1), UpperArmL = v(-1.3), ForearmR = v(-0.2), Chest = v(-0.3, -0.2), _root = v(0, -0.1, -1.0) } },
	{ 0.54, { UpperArmR = v(-0.6, 0, 0.2), UpperArmL = v(-0.5), Chest = v(0.2, 0.3), _root = v(0, 0, -0.2) } },
	{ 0.64, { UpperArmR = v(-1.6, 0, -0.1), UpperArmL = v(-1.4), ForearmR = v(-0.2), Chest = v(-0.4, -0.3), _root = v(0, -0.15, -1.2), ThighR = v(0.5), ShinR = v(-0.5) } },
	{ 0.95, {} },
})
Poses.Biped.SpPray = clip(1.2, 0.7, { -- Frère Anselme : prière, lévitation et éclat de lumière
	{ 0, {} },
	{ 0.35, { UpperArmR = v(-2.8, 0, 0.5), UpperArmL = v(-2.8, 0, -0.5), Head = v(0.55), Chest = v(0.3), _root = v(0, 0.4, 0), ThighR = v(-0.1) } },
	{ 0.55, { UpperArmR = v(-3.0, 0, 0.8), UpperArmL = v(-3.0, 0, -0.8), Head = v(0.6), Chest = v(0.3), _root = v(0, 1.0, 0), ShinR = v(-0.4), ShinL = v(-0.4) } },
	{ 0.7, { UpperArmR = v(-1.6, 0, 0.2), UpperArmL = v(-1.6, 0, -0.2), Chest = v(-0.2), _root = v(0, 0.6, -0.3) } },
	{ 0.95, { UpperArmR = v(-1.2, 0, 0.2), UpperArmL = v(-1.2, 0, -0.2), _root = v(0, 0.3, 0) } },
	{ 1.2, {} },
})
Poses.Biped.SpWhirl = clip(1.1, 0.6, { -- Chevalier des Moissons : tourbillon de la faux
	{ 0, {} },
	{ 0.2, { UpperArmR = v(-1.5, 0, 1.3), UpperArmL = v(-1.2, 0, -0.4), Hips = v(0, 0.7, 0), Chest = v(0.1, 0.5), _root = v(0, -0.2, 0.2) } },
	{ 0.45, { Hips = v(0, -1.9, 0), UpperArmR = v(-1.4, 0, 1.4), Chest = v(0, -0.3), _root = v(0, 0.3, -0.3) } },
	{ 0.7, { Hips = v(0, -4.5, 0), UpperArmR = v(-1.4, 0, 1.4), _root = v(0, 0.4, -0.4) } },
	{ 0.9, { Hips = v(0, -TAU, 0), UpperArmR = v(-0.8, 0, 0.9), _root = v(0, 0.1, -0.2) } },
	{ 1.1, { Hips = v(0, -TAU, 0) } },
})
Poses.Biped.SpQuake = clip(1.25, 0.75, { -- Golem moussu : bond et double coup de poing au sol
	{ 0, {} },
	{ 0.3, { UpperArmR = v(-2.9, 0, 0.4), UpperArmL = v(-2.9, 0, -0.4), Chest = v(0.4), _root = v(0, 0.6, 0.2), ThighR = v(-0.3), ThighL = v(-0.3) } },
	{ 0.55, { UpperArmR = v(-3.1, 0, 0.3), UpperArmL = v(-3.1, 0, -0.3), Chest = v(0.45), _root = v(0, 1.6, 0) } },
	{ 0.75, { UpperArmR = v(1.2, 0, -0.1), UpperArmL = v(1.2, 0, 0.1), Chest = v(-0.8), _root = v(0, -0.8, -0.5), ThighR = v(0.9), ShinR = v(-1.2), ThighL = v(0.9), ShinL = v(-1.2) } },
	{ 0.95, { UpperArmR = v(1.1, 0, -0.1), UpperArmL = v(1.1, 0, 0.1), Chest = v(-0.7), _root = v(0, -0.7, -0.5), ThighR = v(0.8), ShinR = v(-1.1), ThighL = v(0.8), ShinL = v(-1.1) } },
	{ 1.25, {} },
})
Poses.Biped.SpSkyward = clip(1.15, 0.72, { -- Paladin : l'épée levée vers l'aube, puis abattue
	{ 0, {} },
	{ 0.35, { UpperArmR = v(-3.1, 0, 0.05), UpperArmL = v(-0.4, 0, -0.5), Head = v(0.55), Chest = v(0.35), _root = v(0, 0.25, 0.1) } },
	{ 0.55, { UpperArmR = v(-3.1, 0, 0.05), UpperArmL = v(-0.5, 0, -0.6), Head = v(0.6), Chest = v(0.4), _root = v(0, 0.45, 0.1) } },
	{ 0.72, { UpperArmR = v(0.7, 0, -0.1), Chest = v(-0.45), Head = v(-0.1), _root = v(0, -0.3, -0.9), ThighR = v(0.6), ShinR = v(-0.6) } },
	{ 0.9, { UpperArmR = v(0.6, 0, -0.1), Chest = v(-0.4), _root = v(0, -0.3, -0.8), ThighR = v(0.5), ShinR = v(-0.5) } },
	{ 1.15, {} },
})
Poses.Biped.SpHeroic = clip(1.2, 0.68, { -- Chevalier Vert : bond et coup de hache du défi
	{ 0, {} },
	{ 0.25, { _root = v(0, -0.5, 0.2), ThighR = v(0.7), ShinR = v(-1.0), ThighL = v(0.7), ShinL = v(-1.0), UpperArmR = v(-1.0, 0, 0.5), Chest = v(-0.2) } },
	{ 0.45, { _root = v(0, 2.4, -0.6), UpperArmR = v(-3.0, 0, 0.2), UpperArmL = v(-2.8, 0, -0.2), Chest = v(0.4), ThighR = v(-0.3), ThighL = v(0.3) } },
	{ 0.68, { _root = v(0, -0.5, -1.6), UpperArmR = v(1.1), UpperArmL = v(1.0), Chest = v(-0.7), ThighR = v(0.8), ShinR = v(-0.9) } },
	{ 0.9, { _root = v(0, -0.45, -1.5), UpperArmR = v(1.0), UpperArmL = v(0.9), Chest = v(-0.6), ThighR = v(0.7), ShinR = v(-0.8) } },
	{ 1.2, {} },
})
Poses.Biped.SpReap = clip(1.1, 0.55, { -- Chevalier-Citrouille : grand fauchage rasant
	{ 0, {} },
	{ 0.25, { UpperArmR = v(-1.0, 0, 1.4), UpperArmL = v(-0.8, 0, -1.0), Hips = v(0, 1.2, 0), Chest = v(0.2, 0.6), _root = v(0, -0.4, 0.3), ThighR = v(0.5), ShinR = v(-0.7) } },
	{ 0.55, { Hips = v(0, -1.6, 0), UpperArmR = v(-0.6, 0, 1.5), Chest = v(-0.3, -0.6), _root = v(0, -0.5, -0.6), ThighR = v(0.5), ShinR = v(-0.7) } },
	{ 0.75, { Hips = v(0, -1.8, 0), UpperArmR = v(-1.8, 0, 0.8), _root = v(0, 0.2, -0.4) } },
	{ 1.1, {} },
})
Poses.Biped.SpFlurry = clip(1.0, 0.18, { -- Matelot : quatre coups de sabre à l'abordage
	{ 0, {} },
	{ 0.1, { UpperArmR = v(-2.0, 0.2, 0.6), Chest = v(0.1, 0.5) } },
	{ 0.18, { UpperArmR = v(0.8, -0.3, -0.5), Chest = v(-0.2, -0.5), _root = v(0, -0.1, -0.5) } },
	{ 0.3, { UpperArmR = v(-1.6, -0.4, -0.6), Chest = v(0.1, -0.5), _root = v(0, 0, -0.4) } },
	{ 0.38, { UpperArmR = v(0.6, 0.4, 0.8), Chest = v(-0.2, 0.5), _root = v(0, -0.1, -0.8) } },
	{ 0.5, { UpperArmR = v(-2.0, 0.2, 0.6), Chest = v(0.1, 0.5), _root = v(0, 0, -0.7) } },
	{ 0.58, { UpperArmR = v(0.8, -0.3, -0.5), Chest = v(-0.2, -0.5), _root = v(0, -0.1, -1.0) } },
	{ 0.7, { UpperArmR = v(-2.4, 0, 0.2), Chest = v(0.2), _root = v(0, 0.1, -0.9) } },
	{ 0.78, { UpperArmR = v(1.0, 0, -0.1), Chest = v(-0.4), _root = v(0, -0.3, -1.2), ThighR = v(0.5), ShinR = v(-0.5) } },
	{ 1.0, {} },
})
Poses.Biped.SpThrow = clip(1.05, 0.55, { -- Harponneuse : lancer de toutes ses forces
	{ 0, {} },
	{ 0.35, { UpperArmR = v(-2.7, 0, 0.9), ForearmR = v(-0.5), Chest = v(0.3, 0.8), UpperArmL = v(-1.2, 0, -0.6), _root = v(0, 0, 0.5), ThighR = v(-0.3), ThighL = v(0.4) } },
	{ 0.48, { UpperArmR = v(-2.8, 0, 1.0), ForearmR = v(-0.6), Chest = v(0.35, 0.95), UpperArmL = v(-1.3, 0, -0.6), _root = v(0, 0, 0.6), ThighR = v(-0.3), ThighL = v(0.4) } },
	{ 0.55, { UpperArmR = v(-0.4, 0, -0.4), ForearmR = v(0.1), Chest = v(-0.4, -0.7), _root = v(0, -0.1, -0.8), UpperArmL = v(0.3, 0, -0.3), ThighR = v(0.5), ThighL = v(-0.4) } },
	{ 0.75, { UpperArmR = v(-0.3, 0, -0.3), Chest = v(-0.35, -0.6), _root = v(0, -0.1, -0.7), ThighR = v(0.4) } },
	{ 1.05, {} },
}, 0.55)
Poses.Biped.SpLunge = clip(0.95, 0.42, { -- Templier des marées : fente au trident
	{ 0, {} },
	{ 0.2, { UpperArmR = v(-0.9, 0, 0.4), ForearmR = v(1.2), Chest = v(0.2, 0.6), _root = v(0, -0.3, 0.6), ThighL = v(0.6), ShinL = v(-0.7) } },
	{ 0.42, { UpperArmR = v(-1.6, 0, -0.1), ForearmR = v(0), Chest = v(-0.4, -0.4), _root = v(0, -0.5, -2.6), ThighL = v(-0.6), ThighR = v(0.9), ShinR = v(-0.6) } },
	{ 0.6, { UpperArmR = v(-1.5, 0, -0.1), Chest = v(-0.35, -0.35), _root = v(0, -0.5, -2.4), ThighL = v(-0.5), ThighR = v(0.8), ShinR = v(-0.5) } },
	{ 0.95, {} },
})
Poses.Biped.SpDive = clip(1.2, 0.72, { -- Gargouille : envol puis piqué griffes en avant
	{ 0, {} },
	{ 0.35, { _root = v(0, 3.0, 0.6), UpperArmR = v(-2.2, 0, 1.0), UpperArmL = v(-2.2, 0, -1.0), Chest = v(0.3), ThighR = v(-0.6), ThighL = v(-0.6) } },
	{ 0.55, { _root = v(0, 3.6, 0.3), UpperArmR = v(-2.4, 0, 1.1), UpperArmL = v(-2.4, 0, -1.1), Chest = v(0.35), ThighR = v(-0.6), ThighL = v(-0.6) } },
	{ 0.72, { _root = v(0, -0.3, -2.2), UpperArmR = v(0.9, 0, -0.6), UpperArmL = v(0.9, 0, 0.6), Chest = v(-0.6), ThighR = v(0.7), ThighL = v(0.7) } },
	{ 0.9, { _root = v(0, -0.2, -2.0), UpperArmR = v(0.8, 0, -0.5), UpperArmL = v(0.8, 0, 0.5), Chest = v(-0.5) } },
	{ 1.2, {} },
})
Poses.Biped.SpCast = clip(1.1, 0.62, { -- Sorcière des brumes : orbe rassemblé puis projeté
	{ 0, {} },
	{ 0.3, { UpperArmR = v(-1.5, 0, 0.7), UpperArmL = v(-1.5, 0, -0.7), ForearmR = v(1.0), ForearmL = v(1.0), Chest = v(0.2), Head = v(0.2), _root = v(0, 0.3, 0.2) } },
	{ 0.5, { UpperArmR = v(-1.9, 0, 0.5), UpperArmL = v(-1.9, 0, -0.5), ForearmR = v(1.5), ForearmL = v(1.5), Hips = v(0, 0.6, 0), _root = v(0, 0.6, 0.3) } },
	{ 0.62, { UpperArmR = v(-1.5, 0, -0.1), UpperArmL = v(-1.5, 0, 0.1), Chest = v(-0.35), Hips = v(0, -0.3, 0), _root = v(0, 0.2, -0.6) } },
	{ 0.85, { UpperArmR = v(-1.3, 0, -0.1), UpperArmL = v(-1.3, 0, 0.1), Chest = v(-0.3), _root = v(0, 0.2, -0.5) } },
	{ 1.1, {} },
}, 0.62)
Poses.Biped.SpLeap = clip(1.3, 0.85, { -- Dragon-chevalier : saut du dragon, lance plantée
	{ 0, {} },
	{ 0.2, { _root = v(0, -0.7, 0.1), ThighR = v(0.9), ShinR = v(-1.3), ThighL = v(0.9), ShinL = v(-1.3), Chest = v(-0.3) } },
	{ 0.5, { _root = v(0, 6.0, -1.0), UpperArmR = v(-2.6, 0, 0.3), Chest = v(0.3), ThighR = v(-0.4), ThighL = v(0.4) } },
	{ 0.65, { _root = v(0, 6.4, -1.6), UpperArmR = v(-0.3, 0, 0.2), ForearmR = v(-0.6), ThighR = v(-0.3), ThighL = v(0.3) } },
	{ 0.85, { _root = v(0, -0.6, -2.2), UpperArmR = v(0.9), Chest = v(-0.6), ThighR = v(0.9), ShinR = v(-1.1), ThighL = v(0.6), ShinL = v(-0.8) } },
	{ 1.05, { _root = v(0, -0.5, -2.1), UpperArmR = v(0.8), Chest = v(-0.5), ThighR = v(0.8), ShinR = v(-1.0), ThighL = v(0.5), ShinL = v(-0.7) } },
	{ 1.3, {} },
})
Poses.Biped.SpRend = clip(0.95, 0.38, { -- Démon des abysses : griffes croisées
	{ 0, {} },
	{ 0.2, { UpperArmR = v(-2.4, 0, 1.1), UpperArmL = v(-2.4, 0, -1.1), Chest = v(0.35), _root = v(0, 0.2, 0.3) } },
	{ 0.38, { UpperArmR = v(0.7, 0, -0.7), UpperArmL = v(0.7, 0, 0.7), Chest = v(-0.5), _root = v(0, 0.4, -1.4) } },
	{ 0.55, { UpperArmR = v(0.6, 0, -0.6), UpperArmL = v(0.6, 0, 0.6), Chest = v(-0.45), _root = v(0, 0.2, -1.3) } },
	{ 0.95, {} },
})
Poses.Biped.SpThunder = clip(1.15, 0.7, { -- Chevalier-Tempête : la lance appelle la foudre puis se plante
	{ 0, {} },
	{ 0.35, { UpperArmR = v(-3.0, 0, 0.2), UpperArmL = v(-3.0, 0, -0.2), ForearmR = v(-0.2), Head = v(0.5), Chest = v(0.3), _root = v(0, 0.5, 0) } },
	{ 0.55, { UpperArmR = v(-3.1, 0, 0.2), UpperArmL = v(-3.1, 0, -0.2), ForearmR = v(-0.2), Head = v(0.55), Chest = v(0.35), _root = v(0, 1.2, 0) } },
	{ 0.7, { UpperArmR = v(0.4, 0, -0.1), UpperArmL = v(0.4, 0, 0.1), ForearmR = v(-0.6), ForearmL = v(-0.6), Chest = v(-0.6), _root = v(0, -0.6, -0.4), ThighR = v(0.8), ShinR = v(-1.0), ThighL = v(0.5), ShinL = v(-0.6) } },
	{ 0.9, { UpperArmR = v(0.4, 0, -0.1), UpperArmL = v(0.4, 0, 0.1), Chest = v(-0.55), _root = v(0, -0.55, -0.4), ThighR = v(0.7), ShinR = v(-0.9) } },
	{ 1.15, {} },
})

-- quadrupèdes
Poses.Quadruped.SpPounce = clip(1.0, 0.45, { -- Brindille : bond et double morsure
	{ 0, {} },
	{ 0.18, { Chest = v(0.25), Neck = v(0.3), LegFR1 = v(-0.5), LegFL1 = v(-0.5), LegBR1 = v(0.6), LegBL1 = v(0.6), _root = v(0, -0.45, 0.4) } },
	{ 0.36, { _root = v(0, 2.4, -1.6), LegFR1 = v(-1.0), LegFL1 = v(-1.0), LegBR1 = v(1.0), LegBL1 = v(1.0), Neck = v(-0.3), Jaw = v(0.6) } },
	{ 0.45, { _root = v(0, 0.2, -2.2), Neck = v(-0.5), Head = v(-0.2), Jaw = v(0), LegFR1 = v(0.8), LegFL1 = v(0.8) } },
	{ 0.6, { _root = v(0, 0.3, -2.0), Neck = v(-0.2), Jaw = v(0.7) } },
	{ 0.7, { _root = v(0, 0.2, -2.0), Neck = v(-0.5), Jaw = v(0) } },
	{ 1.0, {} },
})
Poses.Quadruped.SpRam = clip(1.1, 0.6, { -- Sanglier de guerre : charge cuirassée
	{ 0, {} },
	{ 0.25, { Neck = v(0.4), Head = v(0.4), LegFR1 = v(-0.5), LegBR1 = v(0.6), _root = v(0, -0.3, 0.8) } },
	{ 0.4, { Neck = v(0.2), LegFR1 = v(0.6), LegFL1 = v(-0.6), _root = v(0, 0, -0.5) } },
	{ 0.6, { Neck = v(-0.6), Head = v(-0.6), LegFR1 = v(1.0), LegFL1 = v(0.8), LegBR1 = v(-0.9), LegBL1 = v(-0.8), _root = v(0, 0.4, -3.2) } },
	{ 0.75, { Neck = v(-0.4), Head = v(-0.4), _root = v(0, 0.1, -2.8) } },
	{ 1.1, {} },
})
Poses.Quadruped.SpRear = clip(1.15, 0.7, { -- Cerf d'émeraude : cabré, puis sabots abattus
	{ 0, {} },
	{ 0.4, { Chest = v(0.9), Neck = v(0.5), Head = v(0.3), LegFR1 = v(-1.4), LegFL1 = v(-1.2), LegFR2 = v(-0.6), LegFL2 = v(-0.6), LegBR1 = v(-0.3), LegBL1 = v(-0.3), _root = v(0, 1.8, 0.6) } },
	{ 0.55, { Chest = v(1.0), Neck = v(0.55), Head = v(0.3), LegFR1 = v(-1.5), LegFL1 = v(-1.3), LegFR2 = v(-0.7), LegFL2 = v(-0.7), LegBR1 = v(-0.3), LegBL1 = v(-0.3), _root = v(0, 2.1, 0.6) } },
	{ 0.7, { Chest = v(-0.35), Neck = v(-0.5), Head = v(-0.4), LegFR1 = v(0.9), LegFL1 = v(0.9), _root = v(0, -0.3, -0.8) } },
	{ 0.9, { Chest = v(-0.3), Neck = v(-0.4), Head = v(-0.3), LegFR1 = v(0.8), LegFL1 = v(0.8), _root = v(0, -0.25, -0.7) } },
	{ 1.15, {} },
})
Poses.Quadruped.SpInferno = clip(1.4, 0.6, { -- Ignir : se dresse, puis balaie le sol de son brasier
	{ 0, {} },
	{ 0.35, { Neck1 = v(0.6), Neck2 = v(0.4), Head = v(0.3), Chest = v(0.4), _root = v(0, 1.2, 0.6) } },
	{ 0.6, { Neck1 = v(-0.4), Neck2 = v(-0.3), Head = v(-0.2), Jaw = v(0.9), Chest = v(-0.1), _root = v(0, 0.8, -0.3) } },
	{ 0.9, { Neck1 = v(-0.35, 0.45), Neck2 = v(-0.3, 0.2), Jaw = v(0.9), _root = v(0, 0.7, -0.3) } },
	{ 1.15, { Neck1 = v(-0.35, -0.45), Neck2 = v(-0.3, -0.2), Jaw = v(0.85), _root = v(0, 0.6, -0.3) } },
	{ 1.4, {} },
}, 0.6)

-- créatures ailées
Poses.Flyer.SpBlaze = clip(1.3, 0.55, { -- Wyverneau : s'élève et souffle en éventail
	{ 0, {} },
	{ 0.3, { _root = v(0, 1.8, 0.8), Neck1 = v(0.5), Neck2 = v(0.4), Head = v(0.3), Chest = v(0.3) } },
	{ 0.55, { _root = v(0, 1.2, -0.6), Neck1 = v(-0.4), Neck2 = v(-0.3), Jaw = v(0.9), Chest = v(-0.2) } },
	{ 0.75, { _root = v(0, 1.2, -0.6), Neck1 = v(-0.4, 0.45), Neck2 = v(-0.3, 0.2), Jaw = v(0.9) } },
	{ 1.0, { _root = v(0, 1.0, -0.5), Neck1 = v(-0.4, -0.45), Neck2 = v(-0.3, -0.2), Jaw = v(0.85) } },
	{ 1.3, {} },
}, 0.55)

-- crabes
Poses.Crab.SpCrush = clip(1.0, 0.5, { -- Crabe-bouclier : les deux pinces se referment
	{ 0, {} },
	{ 0.3, { ClawR1 = v(-1.0, 0.3, 0.4), ClawL1 = v(-1.0, -0.3, -0.4), ClawR2 = v(0, 0.6), ClawL2 = v(0, -0.6), Body = v(0.25), _root = v(0, 0.4, 0.2) } },
	{ 0.5, { ClawR1 = v(0.8, -0.4, -0.3), ClawL1 = v(0.8, 0.4, 0.3), ClawR2 = v(0, -0.6), ClawL2 = v(0, 0.6), Body = v(-0.25), _root = v(0, -0.1, -0.8) } },
	{ 0.7, { ClawR1 = v(0.7, -0.4, -0.3), ClawL1 = v(0.7, 0.4, 0.3), ClawR2 = v(0, -0.5), ClawL2 = v(0, 0.5), Body = v(-0.2), _root = v(0, -0.1, -0.7) } },
	{ 1.0, {} },
})

-- Correspondance style d'attaque -> famille de poses (avec repli).
local FALLBACK = {
	Biped = { Charge = "Slash", Bite = "Claw", Breath = "Staff", Tentacle = "Slam" },
	Quadruped = { Slash = "Bite", Cleave = "Charge", Slam = "Charge", Breath = "Bite", Thrust = "Charge", Staff = "Bite", Tentacle = "Bite" },
	Flyer = { Slash = "Claw", Charge = "Claw", Slam = "Claw", Thrust = "Claw", Staff = "Breath", Tentacle = "Bite" },
	Crab = {},
	Tentacled = {},
}

function Poses.Resolve(family: string, style: string): Clip?
	local lib = (Poses :: any)[family]
	if not lib then
		lib = Poses.Biped
		family = "Biped"
	end
	local c = lib[style]
	if c then
		return c
	end
	local alias = (FALLBACK[family] or {})[style]
	if alias and lib[alias] then
		return lib[alias]
	end
	-- dernier recours : la première attaque disponible
	for k, cl in lib do
		if k ~= "Flinch" then
			return cl
		end
	end
	return nil
end

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

-- Pose interpolée au temps `t` (secondes) d'un clip, écrite dans `out` (os -> rotation), avec intensité `power`.
function Poses.Sample(c: Clip, t: number, power: number, out: { [string]: Vector3 })
	local keys = c.keys
	local a, b = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if t >= keys[i].t and t <= keys[i + 1].t then
			a, b = keys[i], keys[i + 1]
			break
		end
	end
	local span = math.max(1e-4, b.t - a.t)
	local f = ease(math.clamp((t - a.t) / span, 0, 1))
	for bone, va in a.pose do
		local vb = b.pose[bone] or Vector3.zero
		out[bone] = (out[bone] or Vector3.zero) + (va + (vb - va) * f) * power
	end
	for bone, vb in b.pose do
		if not a.pose[bone] then
			out[bone] = (out[bone] or Vector3.zero) + vb * f * power
		end
	end
end

return Poses
