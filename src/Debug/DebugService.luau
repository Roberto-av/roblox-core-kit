--!strict

-- DebugService (servidor): remotes, comandos con esquema de tipos y validación autoritativa (sección 5.1).
-- Nota: con realm "shared" este código es legible por los clientes. No contiene secretos:
-- la lista blanca se pasa a Init desde un script de ServerScriptService y nunca se replica.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Root = script.Parent.Parent
local Logger = require(Root.Util.Logger)
local Types = require(Root.Types)
local DebugAuth = require(script.Parent.DebugAuth)
local DebugRateLimiter = require(script.Parent.DebugRateLimiter)

export type ArgType = Types.ArgType
export type CommandDefinition = Types.CommandDefinition
export type DebugService = Types.DebugService

local MODULE = "DebugService"
local FOLDER_NAME = "CoreKit_Debug"
local MAX_NAME_LENGTH = 64
local MAX_STRING_LENGTH = 256

local VALID_ARG_TYPES: { [string]: boolean } = {
	string = true,
	number = true,
	integer = true,
	boolean = true,
	Player = true,
}

local commands: { [string]: CommandDefinition } = {}
local initialized = false

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

-- Valida un argumento contra su tipo. Devuelve (válido, valorResuelto).
local function resolveArg(value: any, argType: string): (boolean, any)
	if argType == "string" then
		if type(value) == "string" and #value <= MAX_STRING_LENGTH then
			return true, value
		end
	elseif argType == "number" then
		if isFiniteNumber(value) then
			return true, value
		end
	elseif argType == "integer" then
		if isFiniteNumber(value) and value % 1 == 0 then
			return true, value
		end
	elseif argType == "boolean" then
		if type(value) == "boolean" then
			return true, value
		end
	elseif argType == "Player" then
		-- Llega como UserId numérico y se resuelve en el servidor
		if isFiniteNumber(value) and value % 1 == 0 then
			local target = Players:GetPlayerByUserId(value)
			if target then
				return true, target
			end
		end
	end
	return false, nil
end

-- true si args es un arreglo limpio (claves 1..n, sin claves extra ni huecos).
local function isCleanArray(args: { [any]: any }): boolean
	local count = 0
	for key in args do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
			return false
		end
		count += 1
	end
	return count == #args
end

local function executeCommand(player: Player, commandName: any, args: any): (boolean, any)
	-- 1. Autorización, revalidada en cada llamada
	if not DebugAuth.IsAllowed(player) then
		return false, "no autorizado"
	end
	-- 2. Rate limit
	if not DebugRateLimiter.TryConsume(player) then
		return false, "demasiadas llamadas"
	end
	-- 3. Nombre del comando
	if type(commandName) ~= "string" or #commandName > MAX_NAME_LENGTH then
		return false, "nombre de comando inválido"
	end
	local definition = commands[commandName]
	if definition == nil then
		return false, "comando inexistente"
	end
	-- 4. Tabla de argumentos con el número exacto
	if type(args) ~= "table" or not isCleanArray(args) or #args ~= #definition.Args then
		return false, "argumentos inválidos"
	end
	-- 5. Cada argumento contra su tipo
	local resolved: { any } = {}
	for index, argType in definition.Args do
		local valid, value = resolveArg(args[index], argType)
		if not valid then
			return false, `argumento {index} inválido (se esperaba {argType})`
		end
		resolved[index] = value
	end
	-- 6. Ejecución aislada
	local ok, callbackOk, result = pcall(definition.Callback, player, resolved)
	if not ok then
		Logger.Error(MODULE, `error en el comando '{commandName}': {callbackOk}`)
		return false, "error interno"
	end
	return callbackOk == true, result
end

local function createRemote(parent: Folder, name: string): RemoteFunction
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local DebugService: DebugService = {
	Init = function(config)
		if not RunService:IsServer() then
			error("[CoreKit][DebugService] Init solo puede llamarse en el servidor", 2)
		end
		if initialized then
			error("[CoreKit][DebugService] Init ya fue llamado; solo puede llamarse una vez", 2)
		end
		if type(config) ~= "table" or type(config.AllowedUserIds) ~= "table" then
			error("[CoreKit][DebugService] Init requiere AllowedUserIds", 2)
		end
		initialized = true

		DebugAuth.Configure(config.AllowedUserIds, config.ProductionEnabled)
		DebugRateLimiter.Init()

		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		local canUse = createRemote(folder, "CanUseDebug")
		local execute = createRemote(folder, "ExecuteCommand")

		canUse.OnServerInvoke = function(player: Player): boolean
			return DebugAuth.IsAllowed(player) and DebugRateLimiter.TryConsume(player)
		end
		execute.OnServerInvoke = function(player: Player, commandName: any, args: any): (boolean, any)
			return executeCommand(player, commandName, args)
		end

		folder.Parent = ReplicatedStorage
	end,

	RegisterCommand = function(name: string, definition: CommandDefinition)
		if type(name) ~= "string" or name == "" or #name > MAX_NAME_LENGTH then
			error("[CoreKit][DebugService] nombre de comando inválido", 2)
		end
		if commands[name] ~= nil then
			error(`[CoreKit][DebugService] el comando ya está registrado: {name}`, 2)
		end
		if
			type(definition) ~= "table"
			or type(definition.Callback) ~= "function"
			or type(definition.Args) ~= "table"
		then
			error(`[CoreKit][DebugService] definición inválida para '{name}'`, 2)
		end
		for _, argType in definition.Args do
			if VALID_ARG_TYPES[argType] ~= true then
				error(`[CoreKit][DebugService] tipo de argumento inválido en '{name}': {argType}`, 2)
			end
		end
		commands[name] = definition
	end,
}

return DebugService
