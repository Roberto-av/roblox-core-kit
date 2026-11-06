--!strict

-- Tipos públicos de roblox-core-kit (secciones 3.1, 4 y 5 de la especificación).
-- Se reexportan desde init.luau.

local Packages = script.Parent.Parent
local Signal = require(Packages.Signal)

-- 3.1 Router ---------------------------------------------------------------

export type ViewKind = "Screen" | "Overlay"
export type ViewLayer = "Windows" | "Drawers" | "Dialogs" -- HUD no es apilable

export type ViewContract = {
	Kind: ViewKind,
	Layer: ViewLayer,
	Container: GuiObject,
	DefaultFocusObject: GuiObject?,
	OnOpen: ((payload: any?) -> ())?,
	OnClose: (() -> ())?,
	OnBackRequested: (() -> ())?, -- si existe, B/Backspace lo llaman en vez de Pop()
}

export type ViewFactory = () -> ViewContract

export type UiRouter = {
	Init: (self: UiRouter) -> (),
	Register: (self: UiRouter, viewId: string, factory: ViewFactory) -> (),
	Push: (self: UiRouter, viewId: string, payload: any?) -> boolean,
	Pop: (self: UiRouter, expectedViewId: string?) -> boolean,
	Clear: (self: UiRouter) -> (),
	GetTop: (self: UiRouter) -> string?,
	IsOpen: (self: UiRouter, viewId: string) -> boolean,
	GetLayer: (self: UiRouter, layer: "HUD" | ViewLayer | "Toasts") -> ScreenGui,
	StackChanged: Signal.Signal<string?>, -- dispara (topViewId: string?)
}

-- 4.0 Tema -----------------------------------------------------------------

export type Theme = {
	Colors: { [string]: Color3 }, -- Primary, Secondary, Danger, Warning, Ghost, Surface, Text, Backdrop...
	Font: Font,
	CornerRadius: UDim,
	TextMaxSize: number,
	Sounds: { [string]: string }, -- clave -> "rbxassetid://..." (Click, Hover, Error...)
}

-- 4.1 Button ---------------------------------------------------------------

export type ButtonVariant = "Primary" | "Secondary" | "Danger" | "Warning" | "Ghost"

export type ButtonProps = {
	Parent: GuiObject?,
	Text: string?,
	Variant: ButtonVariant?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Sound: string?, -- clave de Theme.Sounds (por defecto "Click")
	DebounceTime: number?,
	Disabled: boolean?,
	Loading: boolean?,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
}

export type ButtonInstance = {
	Gui: TextButton,
	SetText: (self: ButtonInstance, text: string) -> (),
	SetVariant: (self: ButtonInstance, variant: ButtonVariant) -> (),
	SetDisabled: (self: ButtonInstance, disabled: boolean) -> (),
	SetLoading: (self: ButtonInstance, loading: boolean) -> (),
	SetOnClick: (self: ButtonInstance, callback: () -> ()) -> (),
	Destroy: (self: ButtonInstance) -> (),
}

-- 4.2 Modal ----------------------------------------------------------------

export type ModalProps = {
	Title: string,
	ViewId: string?, -- requerido si no se pasa OnCloseRequested
	Size: UDim2?,
	Position: UDim2?,
	OnCloseRequested: (() -> ())?,
}

export type ModalInstance = {
	Gui: Frame,
	ContentFrame: Frame,
	CloseButton: ButtonInstance,
	SetTitle: (self: ModalInstance, title: string) -> (),
	Destroy: (self: ModalInstance) -> (),
}

-- 4.3 SubModal -------------------------------------------------------------

export type SubModalProps = {
	Title: string,
	Side: "Left" | "Right" | "Bottom",
	ViewId: string?,
	Size: UDim2?,
	OnCloseRequested: (() -> ())?,
}

export type SubModalInstance = {
	Gui: Frame,
	Backdrop: TextButton,
	Panel: Frame,
	ContentFrame: Frame,
	PlayEnter: (self: SubModalInstance) -> (), -- llamado desde OnOpen
	Destroy: (self: SubModalInstance) -> (),
}

-- 4.4 ScrollView -----------------------------------------------------------

export type ScrollViewProps = {
	Parent: GuiObject?,
	Size: UDim2?,
	Position: UDim2?,
	Layout: ("List" | "Grid")?, -- por defecto "List"
	Padding: UDim?,
	CellSize: UDim2?, -- solo Grid
}

export type ScrollViewInstance = {
	Gui: ScrollingFrame,
	ResetScroll: (self: ScrollViewInstance) -> (), -- CanvasPosition = Vector2.zero
	Destroy: (self: ScrollViewInstance) -> (),
}

-- 4.5 Toast ----------------------------------------------------------------

export type ToastType = "Info" | "Success" | "Warning" | "Error"

export type ToastService = {
	Show: (message: string, toastType: ToastType?, duration: number?) -> (),
}

-- 4.6 ConfirmDialog --------------------------------------------------------

export type ConfirmDialogProps = {
	Title: string,
	Message: string,
	ConfirmText: string?, -- por defecto "Confirmar"
	CancelText: string?, -- por defecto "Cancelar"
	Variant: ("Primary" | "Danger")?, -- variante del botón Confirmar
	OnConfirm: () -> (),
	OnCancel: (() -> ())?,
}

export type ConfirmDialogService = {
	Show: (props: ConfirmDialogProps) -> boolean,
}

-- 5.1 DebugService (servidor) ----------------------------------------------

export type ArgType = "string" | "number" | "integer" | "boolean" | "Player"

export type CommandDefinition = {
	Description: string?,
	Args: { ArgType },
	Callback: (player: Player, args: { any }) -> (boolean, any),
}

export type DebugService = {
	Init: (
		config: {
			AllowedUserIds: { number },
			ProductionEnabled: boolean?, -- por defecto false
		}
	) -> (),
	RegisterCommand: (name: string, definition: CommandDefinition) -> (),
}

-- 5.2 DebugController (cliente) --------------------------------------------

export type DebugController = {
	Init: (
		config: {
			ToggleKey: Enum.KeyCode?, -- por defecto F4
			ShowTouchButton: boolean?, -- por defecto true en dispositivos táctiles
		}?
	) -> (),
	RegisterTab: (tabTitle: string, renderFn: () -> ()) -> (),
	Execute: (commandName: string, args: { any }) -> (boolean, any),
}

return {}
