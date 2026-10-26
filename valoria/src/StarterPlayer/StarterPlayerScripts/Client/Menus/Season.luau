--!strict
-- Autel de saison en grand (même contenu que le panneau au-dessus de l'autel, UI/AltarBoard).

local Theme = require(script.Parent.Parent.UI.Theme)
local AltarBoard = require(script.Parent.Parent.UI.AltarBoard)
local MenuManager = require(script.Parent.Parent.UI.MenuManager)

local function build(ctx: MenuManager.Ctx): MenuManager.View
	local refresh = AltarBoard.Season(ctx.win.body)
	return { watch = { "gems", "index" }, refresh = refresh }
end

MenuManager.Register("Season", { title = "Autel de saison", icon = "Summon", color = Theme.C.orange, size = Vector2.new(560, 400), build = build })

return {}
