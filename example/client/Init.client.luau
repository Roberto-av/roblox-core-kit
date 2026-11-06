--!strict

-- Ejemplo / prueba de la Fase 1: Cleaner con 3 conexiones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreKit = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("CoreKit")
local Cleaner = require(CoreKit.Util.Cleaner)
local Logger = require(CoreKit.Util.Logger)

local MODULE = "Example"

local function countAlive(connections: { RBXScriptConnection }): number
	local alive = 0
	for _, connection in connections do
		if connection.Connected then
			alive += 1
		end
	end
	return alive
end

local function testCleaner()
	local event = Instance.new("BindableEvent")
	local cleaner = Cleaner.new()

	local connections: { RBXScriptConnection } = {}
	for index = 1, 3 do
		connections[index] = cleaner:Add(event.Event:Connect(function() end))
	end

	local aliveBefore = countAlive(connections)
	cleaner:Clean()
	local aliveAfter = countAlive(connections)

	-- Destroy debe ser idempotente
	local okDestroy = pcall(function()
		cleaner:Destroy()
		cleaner:Destroy()
	end)

	event:Destroy()

	if aliveBefore == 3 and aliveAfter == 0 and okDestroy then
		Logger.Info(MODULE, "Cleaner OK: 3 conexiones creadas, 0 vivas tras Clean, Destroy idempotente")
	else
		Logger.Error(MODULE, `Cleaner FALLO: antes={aliveBefore} despues={aliveAfter} destroy={okDestroy}`)
	end
end

testCleaner()
