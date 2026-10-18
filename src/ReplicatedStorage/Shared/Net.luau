--!strict
-- Registre des remotes. Le serveur les crée, le client les attend.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.Events = {
	-- serveur -> client
	"DataSync", "Notify", "Announce", "Telegraph", "DuelState", "CarryState", "SummonResult", "StealAlert",
	"Cinematic", "BossState", "PlayerFx", "StormRecap", "LevelUp", "TradeState",
	-- client -> serveur
	"Attack", "Skill", "Dodge", "Interact", "Teleport", "ReturnBase",
}
Net.Unreliable = { "HitFx", "SkillFx" }
Net.Functions = { "Action" }

local folder: Folder

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
		folder = f :: Folder
	else
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	return folder
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
