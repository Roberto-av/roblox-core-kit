--!strict

-- DebugAuth: autorización autoritativa del debug (sección 5.1).
-- En Studio siempre autoriza. Fuera de Studio exige ProductionEnabled = true
-- y que el UserId esté en la lista blanca (convertida a set al iniciar).

local RunService = game:GetService("RunService")

local DebugAuth = {}

local allowedSet: { [number]: boolean } = {}
local productionEnabled = false

function DebugAuth.Configure(allowedUserIds: { number }, enabledInProduction: boolean?)
	local set: { [number]: boolean } = {}
	for _, userId in allowedUserIds do
		if type(userId) == "number" then
			set[userId] = true
		end
	end
	allowedSet = set
	productionEnabled = enabledInProduction == true
end

function DebugAuth.IsAllowed(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if not productionEnabled then
		return false
	end
	return allowedSet[player.UserId] == true
end

return DebugAuth
