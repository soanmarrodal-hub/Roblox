--!strict
-- Registre des remotes : le serveur les crée au démarrage, le client les attend.
-- Les requêtes du client passent presque toutes par la fonction "Action" (nom + arguments), routée côté serveur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.Events = {
	-- serveur -> client
	"Sync", -- (sections) : morceaux du profil joueur modifiés
	"Notify", -- (texte, genre) : bulle de notification
	"Announce", -- (texte, couleur) : annonce serveur (invocation rare, boss…)
	"Zone", -- (zoneKey, info) : changement de zone (monde, tour, raid)
	"EnemySnapshot", -- (zoneKey, liste) : tous les ennemis de la zone
	"EnemySpawn", -- (zoneKey, ennemi)
	"EnemyDeath", -- (zoneKey, id, tueurs)
	"Drops", -- (position, gains) : butin à afficher (pièces, gemmes, objets)
	"RunState", -- (état) : tour / raid (vague, chrono, étage)
	"BossState", -- (état) : boss de monde (apparition, phase, récompenses)
	"Telegraph", -- (zoneKey, forme) : attaque de boss télégraphiée
	"Stun", -- (userId, durée) : héros étourdis par une attaque de boss
	"LevelUp", -- (genre, infos) : rang joueur, niveau de héros
	"Reveal", -- (résultats) : révélation d'invocation
	"Hits", -- (zoneKey, lot) : attaques des héros { propriétaire, emplacement, cible, dégâts, pv restants, drapeaux }
	"EnemyMove", -- (zoneKey, lot { id, x, y, z }) : nouvelles destinations des ennemis
	"Lobby", -- (état) : salle d'attente de raid
	-- client -> serveur
	"Target", -- (enemyId | nil)
	"Click", -- () : clic sur l'écran ou le bouton « Frapper » (dégâts en plus sur la cible)
}

Net.Unreliable = {
	"EnemyHp", -- (zoneKey, lot { id, pv }) : soins, saignements, régénération
}

Net.Functions = {
	"Action", -- (nom, ...) -> (ok, résultat | message)
}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
		if not f then
			local nf = Instance.new("Folder")
			nf.Name = "Remotes"
			for _, n in Net.Events do
				local e = Instance.new("RemoteEvent")
				e.Name = n
				e.Parent = nf
			end
			for _, n in Net.Unreliable do
				local e = Instance.new("UnreliableRemoteEvent")
				e.Name = n
				e.Parent = nf
			end
			for _, n in Net.Functions do
				local e = Instance.new("RemoteFunction")
				e.Name = n
				e.Parent = nf
			end
			nf.Parent = ReplicatedStorage
			f = nf
		end
		folder = f
		return f :: Folder
	end
	local remote = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	folder = remote
	return remote
end

function Net.Event(name: string): RemoteEvent
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Net.Unrel(name: string): UnreliableRemoteEvent
	return getFolder():WaitForChild(name) :: UnreliableRemoteEvent
end

function Net.Func(name: string): RemoteFunction
	return getFolder():WaitForChild(name) :: RemoteFunction
end

function Net.Init()
	getFolder()
end

return Net
