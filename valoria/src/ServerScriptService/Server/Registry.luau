--!strict
-- Registre des services : évite les require circulaires (chaque service y lit les autres à l'exécution).
local Registry = {} :: { [string]: any }
return Registry
