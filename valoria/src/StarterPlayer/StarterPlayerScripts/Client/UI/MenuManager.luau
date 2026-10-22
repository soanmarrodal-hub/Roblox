--!strict
-- Gestion des fenêtres : une seule ouverte à la fois, ouverture par nom (boutons du HUD ou stations),
-- rafraîchissement automatique quand une section du profil change, fermeture animée.

local Signal = require(game:GetService("ReplicatedStorage").Shared.Util.Signal)
local Kit = require(script.Parent.Kit)
local App = require(script.Parent.App)
local State = require(script.Parent.Parent.State)

local MenuManager = {}

export type Ctx = {
	win: Kit.Window,
	arg: any,
	name: string,
	Close: () -> (),
	Reopen: () -> (),
}

export type View = {
	refresh: ((section: string) -> ())?,
	destroy: (() -> ())?,
	watch: { string }?, -- sections du profil qui déclenchent refresh (nil = toutes)
}

export type Def = {
	title: string | (arg: any) -> string,
	icon: string,
	color: Color3,
	size: Vector2,
	build: (ctx: Ctx) -> View?,
}

local defs: { [string]: Def } = {}
local current: { name: string, arg: any, win: Kit.Window, view: View?, conn: any, source: string? }? = nil

MenuManager.Opened = Signal.new() -- (name)
MenuManager.Closed = Signal.new() -- (name)

function MenuManager.Register(name: string, def: Def)
	defs[name] = def
end

function MenuManager.Current(): string?
	return if current then current.name else nil
end

function MenuManager.Source(): string?
	return if current then current.source else nil
end

function MenuManager.Close()
	local c = current
	if not c then
		return
	end
	current = nil
	if c.conn then
		c.conn:Disconnect()
	end
	if c.view and c.view.destroy then
		pcall(c.view.destroy)
	end
	local win = c.win
	Kit.Tween(win.scale, 0.14, { Scale = 0.75 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Once(function()
		win.root:Destroy()
	end)
	MenuManager.Closed:Fire(c.name)
end

-- Ouvre un menu ; `source` = clé de la station qui l'a ouvert (fermé en s'éloignant).
function MenuManager.Open(name: string, arg: any?, source: string?)
	local def = defs[name]
	if not def then
		warn("[Menus] menu inconnu : " .. name)
		return
	end
	if current and current.name == name and current.arg == arg then
		current.source = source or current.source
		return
	end
	MenuManager.Close()
	local title = if type(def.title) == "function" then def.title(arg) else def.title
	local win = Kit.Window(App.menus, { title = title :: string, icon = def.icon, color = def.color, size = def.size })
	local entry = { name = name, arg = arg, win = win, view = nil :: View?, conn = nil :: any, source = source }
	current = entry
	win.onClose = function()
		if current == entry then
			MenuManager.Close()
		end
	end
	local ctx: Ctx = {
		win = win,
		arg = arg,
		name = name,
		Close = function()
			if current == entry then
				MenuManager.Close()
			end
		end,
		Reopen = function()
			if current == entry then
				local src = entry.source
				MenuManager.Close()
				MenuManager.Open(name, arg, src)
			end
		end,
	}
	local ok, view = pcall(def.build :: any, ctx)
	if not ok then
		warn("[Menus] " .. name .. " : " .. tostring(view))
	elseif view then
		entry.view = view
		if view.refresh then
			local watch = view.watch
			local fn = view.refresh
			entry.conn = State.Changed:Connect(function(section: string)
				if current ~= entry then
					return
				end
				if watch == nil or section == "*" or table.find(watch, section) then
					local ok2, err = pcall(fn, section)
					if not ok2 then
						warn("[Menus] " .. name .. " (rafraîchissement) : " .. tostring(err))
					end
				end
			end)
		end
	end
	Kit.OpenAnim(win)
	MenuManager.Opened:Fire(name)
end

function MenuManager.Toggle(name: string, arg: any?)
	if current and current.name == name then
		MenuManager.Close()
	else
		MenuManager.Open(name, arg)
	end
end

return MenuManager
