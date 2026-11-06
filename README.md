# roblox-core-kit

UI multiplataforma, navegación por gamepad y depuración extensible con Iris para Roblox. Luau `--!strict`, sin lógica de juego ni persistencia.

- **Capas de UI** persistentes entre respawns y respetando las zonas seguras.
- **Router de vistas** con pila LIFO, trampa de foco para gamepad y retroceso por B / Backspace.
- **Componentes**: `Button`, `Modal`, `SubModal` (drawer), `ScrollView`, `Toast`, `ConfirmDialog`.
- **Debug seguro**: consola Iris en el cliente y servidor autoritativo (lista blanca, rate limit, esquema de tipos).

## Instalación (Wally)

```toml
[dependencies]
CoreKit = "roberto-av/roblox-core-kit@^0.1.0"
```

```bash
wally install
rojo sourcemap default.project.json -o sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages/
```

En `0.x` un cambio incompatible sube MINOR: `^0.1.0` acepta `0.1.x` pero no `0.2.0`.

## Ejemplo mínimo (cliente)

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreKit = ReplicatedStorage.Packages.CoreKit

local UiRouter = require(CoreKit.UiRouter)
local Modal = require(CoreKit.Components.Modal)

UiRouter:Init()

UiRouter:Register("Inventario", function()
	local modal = Modal.new({ Title = "Inventario", ViewId = "Inventario" })
	return {
		Kind = "Screen",
		Layer = "Windows",
		Container = modal.Gui,
	}
end)

UiRouter:Push("Inventario") -- abre
UiRouter:Pop("Inventario") -- cierra solo si es la cima
```

## Debug (servidor)

La lista blanca vive únicamente en un script de `ServerScriptService`:

```lua
local DebugService = require(ReplicatedStorage.Packages.CoreKit.Debug.DebugService)

DebugService.Init({ AllowedUserIds = { 123456 }, ProductionEnabled = false })
DebugService.RegisterCommand("give_coins", {
	Args = { "integer" },
	Callback = function(player, args)
		return true, args[1]
	end,
})
```

## Desarrollo

```bash
rokit install
wally install
rojo serve dev.project.json
stylua --check src example
selene src example
```

Documentación: [ARCHITECTURE](docs/ARCHITECTURE.md) · [API_REFERENCE](docs/API_REFERENCE.md) · [CHANGELOG](CHANGELOG.md).

## Licencia

MIT.
