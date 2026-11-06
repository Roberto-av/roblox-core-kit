--!strict

-- UiRouter: capas (ScreenGuis) y pila LIFO de vistas (secciones 2, 3.1 y 3.2).
-- Incluye la trampa de foco, el foco por gamepad y el retroceso por B/Backspace (3.2 y 3.3).

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Packages = script.Parent.Parent
local Signal = require(Packages.Signal)
local Logger = require(script.Parent.Util.Logger)
local Types = require(script.Parent.Types)

export type ViewKind = Types.ViewKind
export type ViewLayer = Types.ViewLayer
export type ViewContract = Types.ViewContract
export type ViewFactory = Types.ViewFactory
export type UiRouter = Types.UiRouter

type LayerName = "HUD" | "Windows" | "Drawers" | "Dialogs" | "Toasts"

type StackEntry = {
	Id: string,
	View: ViewContract,
	LastFocused: GuiObject?, -- foco guardado cuando otra vista se abre encima
}

local MODULE = "UiRouter"
local BACK_ACTION = "CoreKit_BackAction"
local BACK_PRIORITY = 3000

-- Capas creadas por el router (CoreKit_Debug lo crea DebugController).
local LAYER_ORDER: { { Name: LayerName, DisplayOrder: number } } = {
	{ Name = "HUD", DisplayOrder = 0 },
	{ Name = "Windows", DisplayOrder = 10 },
	{ Name = "Drawers", DisplayOrder = 20 },
	{ Name = "Dialogs", DisplayOrder = 30 },
	{ Name = "Toasts", DisplayOrder = 40 },
}

-- Kind exigido por cada capa apilable.
local REQUIRED_KIND: { [string]: ViewKind } = {
	Windows = "Screen",
	Drawers = "Overlay",
	Dialogs = "Overlay",
}

local Router = {
	StackChanged = Signal.new() :: any,
}

local layers: { [string]: ScreenGui } = {}
local modalUnlock: TextButton? = nil
local initialized = false

local factories: { [string]: ViewFactory } = {}
local views: { [string]: ViewContract } = {}
local stack: { StackEntry } = {}

local GAMEPAD_TYPES: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
	[Enum.UserInputType.Gamepad5] = true,
	[Enum.UserInputType.Gamepad6] = true,
	[Enum.UserInputType.Gamepad7] = true,
	[Enum.UserInputType.Gamepad8] = true,
}

local function isGamepadActive(): boolean
	return GAMEPAD_TYPES[UserInputService:GetLastInputType()] == true
end

-- Un objeto puede recibir foco si está en el árbol, es visible y seleccionable.
local function canFocus(object: GuiObject?, container: GuiObject): boolean
	return object ~= nil
		and object.Parent ~= nil
		and object:IsDescendantOf(container)
		and object.Visible
		and object.Selectable
end

-- Asigna el foco solo con entrada de gamepad (con ratón no debe aparecer el recuadro de selección).
local function focusDefault(entry: StackEntry)
	if not isGamepadActive() then
		return
	end
	local target = entry.View.DefaultFocusObject
	task.defer(function()
		if stack[#stack] == entry and canFocus(target, entry.View.Container) then
			GuiService.SelectedObject = target
		end
	end)
end

-- Handler de B / Backspace (3.3): actúa solo en Begin y devuelve Sink.
local function handleBack(
	_actionName: string,
	state: Enum.UserInputState,
	_input: InputObject
): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if UserInputService:GetFocusedTextBox() ~= nil then
		return Enum.ContextActionResult.Pass -- el jugador está escribiendo
	end
	if #stack == 0 then
		return Enum.ContextActionResult.Pass
	end
	local top = stack[#stack]
	if top.View.OnBackRequested then
		task.spawn(top.View.OnBackRequested) -- p. ej. ConfirmDialog lo trata como Cancelar
	else
		Router.Pop(Router :: any)
	end
	return Enum.ContextActionResult.Sink
end

local function createLayer(name: LayerName, displayOrder: number, playerGui: PlayerGui): ScreenGui
	local guiName = `CoreKit_{name}`
	local existing = playerGui:FindFirstChild(guiName)
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = guiName
	gui.DisplayOrder = displayOrder
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = playerGui
	return gui
end

-- Botón de tamaño 0 que solo sirve para liberar el cursor (Modal = true).
-- No recibe clics ni foco, así que no bloquea el HUD.
local function createModalUnlock(windows: ScreenGui): TextButton
	local existing = windows:FindFirstChild("ModalUnlock")
	if existing and existing:IsA("TextButton") then
		return existing
	end
	local button = Instance.new("TextButton")
	button.Name = "ModalUnlock"
	button.Size = UDim2.fromOffset(0, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Active = false
	button.Selectable = false
	button.Modal = true
	button.Visible = false
	button.Parent = windows
	return button
end

function Router.Init(_self: UiRouter)
	if initialized then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	for _, definition in LAYER_ORDER do
		layers[definition.Name] = createLayer(definition.Name, definition.DisplayOrder, playerGui)
	end
	modalUnlock = createModalUnlock(layers.Windows)
	-- Al pasar a gamepad con pila no vacía y sin selección, enfoca la cima
	UserInputService.LastInputTypeChanged:Connect(function()
		local top = stack[#stack]
		if top and isGamepadActive() and GuiService.SelectedObject == nil then
			focusDefault(top)
		end
	end)
	initialized = true
end

function Router.GetLayer(_self: UiRouter, layer: "HUD" | ViewLayer | "Toasts"): ScreenGui
	local gui = layers[layer]
	if gui == nil then
		error(`[CoreKit][{MODULE}] capa inexistente o router sin inicializar: {layer}`, 2)
	end
	return gui
end

function Router.Register(_self: UiRouter, viewId: string, factory: ViewFactory)
	if factories[viewId] ~= nil then
		Logger.Warn(MODULE, `la vista ya estaba registrada, se reemplaza la factory: {viewId}`)
		views[viewId] = nil
	end
	factories[viewId] = factory
end

-- Ejecuta la factory la primera vez, valida Kind/Layer y cachea el contrato.
local function getView(self: UiRouter, viewId: string): ViewContract?
	local cached = views[viewId]
	if cached then
		return cached
	end
	local ok, result = pcall(factories[viewId])
	if not ok then
		Logger.Error(MODULE, `la factory de {viewId} falló: {result}`)
		return nil
	end
	local view: ViewContract = result
	local required = REQUIRED_KIND[view.Layer]
	if required == nil or view.Kind ~= required then
		error(`[CoreKit][{MODULE}] vista '{viewId}': Kind '{view.Kind}' no es válido para la capa '{view.Layer}'`, 3)
	end
	view.Container.Visible = false
	view.Container.Parent = Router.GetLayer(self, view.Layer)
	views[viewId] = view
	return view
end

local function findInStack(viewId: string): number?
	for index, entry in stack do
		if entry.Id == viewId then
			return index
		end
	end
	return nil
end

function Router.Push(self: UiRouter, viewId: string, payload: any?): boolean
	if not initialized then
		Logger.Warn(MODULE, "Push antes de Init")
		return false
	end
	-- 1. Vista registrada
	if factories[viewId] == nil then
		Logger.Warn(MODULE, `vista no registrada: {viewId}`)
		return false
	end
	-- 2. Ya es la cima (refresco) o está más abajo (rechazo)
	local existingIndex = findInStack(viewId)
	if existingIndex then
		if existingIndex == #stack then
			local view = stack[existingIndex].View
			if view.OnOpen then
				task.spawn(view.OnOpen, payload)
			end
			return true
		end
		Logger.Warn(MODULE, `la vista ya está en la pila y no es la cima: {viewId}`)
		return false
	end
	-- 3. Instanciar o recuperar y validar
	local view = getView(self, viewId)
	if view == nil then
		return false
	end
	-- 4. Vista superior previa
	local previous = stack[#stack]
	if previous then
		local selected = GuiService.SelectedObject
		previous.LastFocused = if selected and selected:IsA("GuiObject") then selected else nil
		previous.View.Container.Interactable = false
		if view.Kind == "Screen" then
			for _, entry in stack do
				entry.View.Container.Visible = false
			end
		end
	end
	-- 5. Insertar y mostrar
	local entry: StackEntry = { Id = viewId, View = view }
	table.insert(stack, entry)
	view.Container.Visible = true
	view.Container.Interactable = true
	-- 6. Trampa de foco: el stick y la cruceta no salen del contenedor
	view.Container.SelectionGroup = true
	view.Container.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
	view.Container.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
	view.Container.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
	view.Container.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
	-- 7. Foco por defecto (solo gamepad)
	focusDefault(entry)
	-- 8. Pila antes vacía: acción de retroceso
	if #stack == 1 then
		ContextActionService:BindActionAtPriority(
			BACK_ACTION,
			handleBack,
			false,
			BACK_PRIORITY,
			Enum.KeyCode.ButtonB,
			Enum.KeyCode.Backspace
		)
	end
	-- 8.2 Pila antes vacía: activar el botón que libera el cursor
	if #stack == 1 and modalUnlock then
		modalUnlock.Visible = true
	end
	-- 9. OnOpen aislado del router
	if view.OnOpen then
		task.spawn(view.OnOpen, payload)
	end
	-- 10. Notificar
	Router.StackChanged:Fire(viewId)
	return true
end

function Router.Pop(_self: UiRouter, expectedViewId: string?): boolean
	-- 1. Pila vacía o cima distinta de la esperada
	local top = stack[#stack]
	if top == nil then
		return false
	end
	if expectedViewId ~= nil and top.Id ~= expectedViewId then
		return false
	end
	-- 2. Extraer la cima
	table.remove(stack)
	local container = top.View.Container
	if top.View.OnClose then
		task.spawn(top.View.OnClose)
	end
	container.Visible = false
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(container) then
		GuiService.SelectedObject = nil
	end
	local newTop = stack[#stack]
	if newTop then
		-- 3. Restaurar visibilidad desde la cima hasta la primera Screen (incluida)
		for index = #stack, 1, -1 do
			local view = stack[index].View
			view.Container.Visible = true
			if view.Kind == "Screen" then
				break
			end
		end
		newTop.View.Container.Interactable = true
		-- Restaurar el foco solo con gamepad y si el objeto guardado sigue siendo válido
		if isGamepadActive() then
			local saved = newTop.LastFocused
			local target = if canFocus(saved, newTop.View.Container) then saved else newTop.View.DefaultFocusObject
			if canFocus(target, newTop.View.Container) then
				GuiService.SelectedObject = target
			end
		end
		newTop.LastFocused = nil
	else
		ContextActionService:UnbindAction(BACK_ACTION)
		-- 4. Pila vacía
		if modalUnlock then
			modalUnlock.Visible = false
		end
		GuiService.SelectedObject = nil
	end
	-- 5. Notificar
	Router.StackChanged:Fire(if newTop then newTop.Id else nil)
	return true
end

function Router.Clear(self: UiRouter)
	while #stack > 0 do
		Router.Pop(self)
	end
end

function Router.GetTop(_self: UiRouter): string?
	local top = stack[#stack]
	return if top then top.Id else nil
end

function Router.IsOpen(_self: UiRouter, viewId: string): boolean
	return findInStack(viewId) ~= nil
end

return (Router :: any) :: UiRouter
