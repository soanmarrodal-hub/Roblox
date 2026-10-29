--!strict
-- Identifiants des effets sonores téléversés sur Roblox (facultatif). Les sons 8 bits du jeu sont générés par
-- tools/audio/sfx.py dans assets/sfx/<Nom>.ogg : les téléverser dans le Creator Hub (Créations >
-- Développement > Audio, ou le Gestionnaire de ressources de Studio, import groupé), puis renseigner ici :
--   Click = "rbxassetid://1234567890",
-- Noms : Click, Hover, Open, Close, Tab, Toggle, Error, Notify, Success, Pop, Whoosh, Coin, Gem, Rune, Reward,
-- Fanfare, LevelUp, Purchase, Unlock, Summon, Reveal, RevealRare, Equip, Trash. Les sons absents de cette table
-- utilisent un son intégré au client Roblox (UI/Sfx.luau).

return {} :: { [string]: string }
