--!strict

-- Ejemplo de servidor (Fase 9): DebugService con comandos de prueba.
-- La lista blanca vive solo aquí (ServerScriptService), nunca en src/ ni replicada.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreKit = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("CoreKit")
local DebugService = require(CoreKit.Debug.DebugService)
local Logger = require(CoreKit.Util.Logger)

local MODULE = "ExampleServer"

-- Protección del ejemplo: si por algún motivo este script se ejecuta más de una vez
-- (p. ej. una copia duplicada en el place), no se vuelve a llamar a Init ni a RegisterCommand.
if ReplicatedStorage:FindFirstChild("CoreKit_Debug") ~= nil then
	Logger.Warn(MODULE, "DebugService ya estaba iniciado; se omite esta ejecución duplicada del ejemplo")
	return
end

-- En Studio todos están autorizados. En un servidor publicado hace falta
-- ProductionEnabled = true y tu UserId en esta lista.
DebugService.Init({
	AllowedUserIds = {},
	ProductionEnabled = false,
})

DebugService.RegisterCommand("give_coins", {
	Description = "Suma monedas al jugador (atributo Coins, sin persistencia)",
	Args = { "integer" },
	Callback = function(player: Player, args: { any })
		local amount = args[1] :: number
		local total = (player:GetAttribute("Coins") or 0) + amount
		player:SetAttribute("Coins", total)
		return true, total
	end,
})

DebugService.RegisterCommand("set_speed", {
	Description = "Cambia el WalkSpeed del jugador",
	Args = { "number" },
	Callback = function(player: Player, args: { any })
		local speed = math.clamp(args[1] :: number, 0, 200)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then
			return false, "sin Humanoid"
		end
		humanoid.WalkSpeed = speed
		return true, speed
	end,
})

DebugService.RegisterCommand("say", {
	Description = "Escribe un mensaje en el log del servidor",
	Args = { "string" },
	Callback = function(player: Player, args: { any })
		Logger.Info(MODULE, `{player.Name} dice: {args[1]}`)
		return true, nil
	end,
})

DebugService.RegisterCommand("kick", {
	Description = "Expulsa a un jugador del servidor",
	Args = { "Player" },
	Callback = function(_player: Player, args: { any })
		local target = args[1] :: Player
		target:Kick("Expulsado desde la consola de depuración")
		return true, target.Name
	end,
})

Logger.Info(MODULE, `DebugService listo ({#Players:GetPlayers()} jugadores conectados)`)
