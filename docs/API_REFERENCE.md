# Referencia de API

Todos los módulos se obtienen desde el paquete instalado, p. ej. `local CoreKit = ReplicatedStorage.Packages.CoreKit`. Los tipos públicos están en `Types.luau` y se reexportan desde `init.luau`.

## UiRouter

`require(CoreKit.UiRouter)` — singleton, solo cliente.

```lua
type ViewKind = "Screen" | "Overlay"
type ViewLayer = "Windows" | "Drawers" | "Dialogs"
type ViewContract = {
	Kind: ViewKind,
	Layer: ViewLayer,
	Container: GuiObject,
	DefaultFocusObject: GuiObject?,
	OnOpen: ((payload: any?) -> ())?,
	OnClose: (() -> ())?,
	OnBackRequested: (() -> ())?,
}
type ViewFactory = () -> ViewContract
```

| Firma | Descripción |
| --- | --- |
| `Init(self)` | Crea las 5 capas y `ModalUnlock`. Idempotente. |
| `Register(self, viewId: string, factory: ViewFactory)` | Registra una vista. La factory corre en el primer `Push`. |
| `Push(self, viewId: string, payload: any?) -> boolean` | Abre la vista. `false` si no está registrada, está más abajo en la pila o antes de `Init`. |
| `Pop(self, expectedViewId: string?) -> boolean` | Cierra la cima. Con `expectedViewId`, solo si es la cima. |
| `Clear(self)` | `Pop` repetido hasta vaciar la pila. |
| `GetTop(self) -> string?` | Id de la cima. |
| `IsOpen(self, viewId: string) -> boolean` | Si la vista está en la pila. |
| `GetLayer(self, layer: "HUD" \| ViewLayer \| "Toasts") -> ScreenGui` | La `ScreenGui` de la capa. Error antes de `Init`. |
| `StackChanged: Signal<string?>` | Se dispara con el id de la nueva cima (o `nil`). |

```lua
UiRouter:Init()
UiRouter:Register("Tienda", function()
	local frame = Instance.new("Frame")
	return { Kind = "Screen", Layer = "Windows", Container = frame }
end)
UiRouter.StackChanged:Connect(function(top) print("cima:", top) end)
UiRouter:Push("Tienda", { tab = "armas" })
```

## Theme

`require(CoreKit.Theme)` — tabla `Theme`:

```lua
type Theme = {
	Colors: { [string]: Color3 }, -- Primary, Secondary, Danger, Warning, Ghost, Success, Disabled, Spinner, Surface, Text, Backdrop
	Font: Font,
	CornerRadius: UDim,
	TextMaxSize: number,
	Sounds: { [string]: string }, -- Click, Hover, Error ("" = silencio)
}
```

```lua
Theme.Sounds.Click = "rbxassetid://123456" -- antes de crear botones
```

## SoundPlayer

| Firma | Descripción |
| --- | --- |
| `Play(key: string)` | Reproduce la `Sound` de la clave (una sola instancia en `SoundService.CoreKit_Sounds`). Clave inexistente: aviso, sin error. |
| `Preload()` | Precarga todos los sonidos con `ContentProvider:PreloadAsync`. |

```lua
local SoundPlayer = require(CoreKit.SoundPlayer)
SoundPlayer.Preload()
SoundPlayer.Play("Click")
```

## Button

`require(CoreKit.Components.Button)`

```lua
type ButtonVariant = "Primary" | "Secondary" | "Danger" | "Warning" | "Ghost"
type ButtonProps = {
	Parent: GuiObject?, Text: string?, Variant: ButtonVariant?, Size: UDim2?, Position: UDim2?,
	AnchorPoint: Vector2?, Sound: string?, DebounceTime: number?, Disabled: boolean?,
	Loading: boolean?, LayoutOrder: number?, OnClick: (() -> ())?,
}
type ButtonInstance = {
	Gui: TextButton,
	SetText: (self, text: string) -> (), SetVariant: (self, variant: ButtonVariant) -> (),
	SetDisabled: (self, disabled: boolean) -> (), SetLoading: (self, loading: boolean) -> (),
	SetOnClick: (self, callback: () -> ()) -> (), Destroy: (self) -> (),
}
```

`Button.new(props: ButtonProps) -> ButtonInstance`

```lua
local button = Button.new({ Parent = frame, Text = "Comprar", Variant = "Primary", OnClick = function() print("ok") end })
button:SetLoading(true)
```

## Modal

`Modal.new(props: ModalProps) -> ModalInstance`. Error si faltan `ViewId` y `OnCloseRequested`.

```lua
type ModalProps = { Title: string, ViewId: string?, Size: UDim2?, Position: UDim2?, OnCloseRequested: (() -> ())? }
type ModalInstance = {
	Gui: Frame, ContentFrame: Frame, CloseButton: ButtonInstance,
	SetTitle: (self, title: string) -> (), Destroy: (self) -> (),
}
```

```lua
local modal = Modal.new({ Title = "Inventario", ViewId = "Inventario" })
-- usar modal.Gui como Container de una vista Kind = "Screen", Layer = "Windows"
```

## SubModal

`SubModal.new(props: SubModalProps) -> SubModalInstance`. Para vistas `Kind = "Overlay"`, `Layer = "Drawers"`.

```lua
type SubModalProps = { Title: string, Side: "Left" | "Right" | "Bottom", ViewId: string?, Size: UDim2?, OnCloseRequested: (() -> ())? }
type SubModalInstance = {
	Gui: Frame, Backdrop: TextButton, Panel: Frame, ContentFrame: Frame,
	PlayEnter: (self) -> (), Destroy: (self) -> (),
}
```

```lua
local drawer = SubModal.new({ Title = "Detalles", Side = "Right", ViewId = "Detalles" })
-- en la vista: OnOpen = function() drawer:PlayEnter() end
```

## ScrollView

`ScrollView.new(props: ScrollViewProps) -> ScrollViewInstance`

```lua
type ScrollViewProps = { Parent: GuiObject?, Size: UDim2?, Position: UDim2?, Layout: ("List" | "Grid")?, Padding: UDim?, CellSize: UDim2? }
type ScrollViewInstance = { Gui: ScrollingFrame, ResetScroll: (self) -> (), Destroy: (self) -> () }
```

```lua
local scroll = ScrollView.new({ Parent = frame, Layout = "Grid", CellSize = UDim2.fromOffset(80, 80) })
scroll:ResetScroll()
```

## Toast

`require(CoreKit.Components.Toast)`

| Firma | Descripción |
| --- | --- |
| `Show(message: string, toastType: ToastType?, duration: number?)` | Muestra un toast (`"Info" \| "Success" \| "Warning" \| "Error"`, 3 s por defecto). Máximo 4 visibles; el resto espera en cola. Requiere `UiRouter:Init()`. |

```lua
Toast.Show("Guardado", "Success", 2)
```

## ConfirmDialog

`require(CoreKit.Components.ConfirmDialog)` — se registra como vista `CoreKit_ConfirmDialog`.

```lua
type ConfirmDialogProps = {
	Title: string, Message: string, ConfirmText: string?, CancelText: string?,
	Variant: ("Primary" | "Danger")?, OnConfirm: () -> (), OnCancel: (() -> ())?,
}
```

| Firma | Descripción |
| --- | --- |
| `Show(props: ConfirmDialogProps) -> boolean` | `false` si ya hay un diálogo abierto o los props son inválidos. |

```lua
ConfirmDialog.Show({ Title = "Borrar", Message = "¿Seguro?", Variant = "Danger", OnConfirm = function() end })
```

## DebugService (servidor)

`require(CoreKit.Debug.DebugService)`

```lua
type ArgType = "string" | "number" | "integer" | "boolean" | "Player"
type CommandDefinition = {
	Description: string?,
	Args: { ArgType },
	Callback: (player: Player, args: { any }) -> (boolean, any),
}
```

| Firma | Descripción |
| --- | --- |
| `Init(config: { AllowedUserIds: { number }, ProductionEnabled: boolean? })` | Crea `ReplicatedStorage.CoreKit_Debug`. Una sola vez: la segunda llamada lanza error. Solo en el servidor. |
| `RegisterCommand(name: string, definition: CommandDefinition)` | Registra un comando (antes o después de `Init`). Error si el nombre, el esquema o un duplicado son inválidos. |

```lua
DebugService.Init({ AllowedUserIds = { 123456 }, ProductionEnabled = false })
DebugService.RegisterCommand("set_speed", {
	Args = { "number" },
	Callback = function(player, args)
		return true, args[1]
	end,
})
```

## DebugController (cliente)

`require(CoreKit.Debug.DebugController)`

| Firma | Descripción |
| --- | --- |
| `Init(config: { ToggleKey: Enum.KeyCode?, ShowTouchButton: boolean? }?)` | Cede hasta 10 s esperando los remotes. Si el jugador no está autorizado, termina sin crear nada. Abre con F4, L3+R3 o botón táctil. |
| `RegisterTab(tabTitle: string, renderFn: () -> ())` | Añade una pestaña de Iris (antes o después de `Init`). Solo se ejecuta el render de la pestaña activa. |
| `Execute(commandName: string, args: { any }) -> (boolean, any)` | Invoca un comando; los `Player` viajan como `UserId`. **Cede**: dentro de un `renderFn` llamarlo con `task.spawn`. |

```lua
DebugController.RegisterTab("Jugador", function()
	local Iris = require(ReplicatedStorage.Packages.Iris)
	if Iris.Button({ "Dar 100 monedas" }).clicked() then
		task.spawn(DebugController.Execute, "give_coins", { 100 })
	end
end)
DebugController.Init()
```

## Util

- `Cleaner.new() -> Cleaner` (`require(CoreKit.Util.Cleaner)`): `Add(item)` acepta `RBXScriptConnection`, `Instance`, `Tween`, función o tabla con `Destroy`, y devuelve el item. `Clean()` libera en orden inverso; `Destroy()` es idempotente (un `Add` posterior libera de inmediato).
- `Logger` (`require(CoreKit.Util.Logger)`): `Info`, `Warn`, `Error`, todas con la firma `(moduleName: string, message: string)` y el prefijo `[CoreKit][Modulo]`. `Error` registra, no lanza.
