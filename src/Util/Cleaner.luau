--!strict

-- Cleaner: agrupa conexiones, instancias, tweens, funciones y objetos con Destroy
-- para liberarlos todos juntos (en orden inverso al de registro).

export type CleanerItem = RBXScriptConnection | Instance | Tween | () -> () | { Destroy: (any) -> () }

export type Cleaner = {
	Add: <T>(self: Cleaner, item: T) -> T,
	Clean: (self: Cleaner) -> (),
	Destroy: (self: Cleaner) -> (),
}

type CleanerImpl = {
	_items: { any },
	_destroyed: boolean,
	Add: <T>(self: CleanerImpl, item: T) -> T,
	Clean: (self: CleanerImpl) -> (),
	Destroy: (self: CleanerImpl) -> (),
}

local Cleaner = {}
Cleaner.__index = Cleaner

-- Libera un elemento según su tipo. Los errores se aíslan con pcall.
local function disposeItem(item: any)
	local itemType = typeof(item)
	if itemType == "RBXScriptConnection" then
		item:Disconnect()
	elseif itemType == "Instance" then
		if item:IsA("Tween") then
			item:Cancel()
		end
		item:Destroy()
	elseif itemType == "function" then
		item()
	elseif itemType == "table" and type(item.Destroy) == "function" then
		item:Destroy()
	end
end

local function safeDispose(item: any)
	local ok, err = pcall(disposeItem, item)
	if not ok then
		warn(`[CoreKit][Cleaner] error al liberar un elemento: {err}`)
	end
end

local function isSupported(item: any): boolean
	local itemType = typeof(item)
	if itemType == "RBXScriptConnection" or itemType == "Instance" or itemType == "function" then
		return true
	end
	return itemType == "table" and type(item.Destroy) == "function"
end

function Cleaner.new(): Cleaner
	local self: CleanerImpl = setmetatable({
		_items = {},
		_destroyed = false,
	}, Cleaner) :: any
	return self :: any
end

-- Registra un elemento y lo devuelve. Si el Cleaner ya fue destruido, lo libera de inmediato.
function Cleaner.Add(self: CleanerImpl, item: any): any
	if not isSupported(item) then
		error(`[CoreKit][Cleaner] tipo no soportado: {typeof(item)}`, 2)
	end
	if self._destroyed then
		safeDispose(item)
		return item
	end
	table.insert(self._items, item)
	return item
end

-- Libera todo en orden inverso; el Cleaner sigue siendo reutilizable.
function Cleaner.Clean(self: CleanerImpl)
	local items = self._items
	self._items = {}
	for index = #items, 1, -1 do
		safeDispose(items[index])
	end
end

-- Idempotente: llamarlo varias veces no falla.
function Cleaner.Destroy(self: CleanerImpl)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:Clean()
end

return Cleaner
