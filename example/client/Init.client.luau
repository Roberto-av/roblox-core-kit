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

-- Fase 2: 20 llamadas a Play("Click") deben crear una sola Sound.
local function testSoundPlayer()
	local SoundService = game:GetService("SoundService")
	local SoundPlayer = require(CoreKit.SoundPlayer)

	for _ = 1, 20 do
		SoundPlayer.Play("Click")
	end
	SoundPlayer.Play("ClaveInexistente") -- debe avisar con Logger.Warn y no fallar

	local folder = SoundService:FindFirstChild("CoreKit_Sounds")
	local count = 0
	if folder then
		for _, child in folder:GetChildren() do
			if child.Name == "Click" then
				count += 1
			end
		end
	end

	if count == 1 then
		Logger.Info(MODULE, "SoundPlayer OK: 20 Play('Click') -> 1 sola Sound")
	else
		Logger.Error(MODULE, `SoundPlayer FALLO: {count} Sounds 'Click'`)
	end
end

testSoundPlayer()
