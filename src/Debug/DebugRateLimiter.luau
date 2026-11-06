--!strict

-- DebugRateLimiter: token bucket por jugador (capacidad 10, recarga 10/s) (sección 5.1).
-- El estado de cada jugador se borra en PlayerRemoving.

local Players = game:GetService("Players")

local CAPACITY = 10
local REFILL_PER_SECOND = 10

type Bucket = {
	Tokens: number,
	LastRefill: number,
}

local DebugRateLimiter = {}

local buckets: { [number]: Bucket } = {}
local connection: RBXScriptConnection? = nil

-- Idempotente: conecta una sola vez la limpieza por PlayerRemoving.
function DebugRateLimiter.Init()
	if connection then
		return
	end
	connection = Players.PlayerRemoving:Connect(function(player: Player)
		buckets[player.UserId] = nil
	end)
end

-- Devuelve true si el jugador aún tiene una llamada disponible (y la consume).
function DebugRateLimiter.TryConsume(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player.UserId]
	if bucket == nil then
		bucket = { Tokens = CAPACITY, LastRefill = now }
		buckets[player.UserId] = bucket
	end
	local current = bucket :: Bucket
	current.Tokens = math.min(CAPACITY, current.Tokens + (now - current.LastRefill) * REFILL_PER_SECOND)
	current.LastRefill = now
	if current.Tokens < 1 then
		return false
	end
	current.Tokens -= 1
	return true
end

return DebugRateLimiter
