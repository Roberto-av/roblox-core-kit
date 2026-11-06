--!strict

-- Logger: única vía de registro del kit. Formato: [CoreKit][Modulo] mensaje

local PREFIX = "[CoreKit]"

local Logger = {}

local function format(moduleName: string, message: string): string
	return `{PREFIX}[{moduleName}] {message}`
end

function Logger.Info(moduleName: string, message: string)
	print(format(moduleName, message))
end

function Logger.Warn(moduleName: string, message: string)
	warn(format(moduleName, message))
end

-- Registra un error sin lanzarlo (el kit nunca debe romperse por un log).
function Logger.Error(moduleName: string, message: string)
	warn(format(moduleName, `ERROR: {message}`))
end

return Logger
