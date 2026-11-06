--!strict

-- Ejemplo / prueba de la Fase 1: Cleaner con 3 conexiones.

local Players = game:GetService("Players")
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

-- Fase 3: UiRouter con tres vistas de prueba (Screen A, Screen B, Overlay C).
local function createTestView(title: string, kind: "Screen" | "Overlay", layer: "Windows" | "Drawers", offset: number)
	return function()
		local frame = Instance.new("Frame")
		frame.Name = title
		frame.Size = UDim2.fromScale(0.4, 0.4)
		frame.Position = UDim2.new(0.3, offset, 0.4, offset)

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 0.3)
		label.BackgroundTransparency = 1
		label.Text = title
		label.TextScaled = true
		label.Parent = frame

		-- Botones seleccionables para probar foco y retroceso con gamepad
		local list = Instance.new("Frame")
		list.Position = UDim2.fromScale(0, 0.3)
		list.Size = UDim2.fromScale(1, 0.7)
		list.BackgroundTransparency = 1
		list.Parent = frame
		local layout = Instance.new("UIListLayout")
		layout.Parent = list

		local buttons: { TextButton } = {}
		for index = 1, 2 do
			local button = Instance.new("TextButton")
			button.Name = `Boton{index}`
			button.Size = UDim2.new(1, 0, 0.3, 0)
			button.Text = `{title} / Boton {index}`
			button.Parent = list
			buttons[index] = button
		end

		-- El Screen A incluye un TextBox: Backspace no debe cerrar la vista mientras se escribe
		if title == "Screen A" then
			local box = Instance.new("TextBox")
			box.Size = UDim2.new(1, 0, 0.3, 0)
			box.Text = ""
			box.PlaceholderText = "Escribe aquí (Backspace no cierra)"
			box.Parent = list
		end

		return {
			Kind = kind,
			Layer = layer,
			Container = frame,
			DefaultFocusObject = buttons[1],
		}
	end
end

local function testRouter()
	local UiRouter = require(CoreKit.UiRouter)
	UiRouter:Init()
	UiRouter:Init() -- no debe duplicar capas

	UiRouter:Register("A", createTestView("Screen A", "Screen", "Windows", 0))
	UiRouter:Register("B", createTestView("Screen B", "Screen", "Windows", 20))
	UiRouter:Register("C", createTestView("Overlay C", "Overlay", "Drawers", 40))

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local results: { [string]: boolean } = {}

	local function container(viewId: string): GuiObject
		local layerName = if viewId == "C" then "Drawers" else "Windows"
		local gui = UiRouter:GetLayer(layerName)
		return gui:FindFirstChild(
			if viewId == "A" then "Screen A" elseif viewId == "B" then "Screen B" else "Overlay C"
		) :: GuiObject
	end

	local layerCount = 0
	for _, child in playerGui:GetChildren() do
		if string.sub(child.Name, 1, 8) == "CoreKit_" then
			layerCount += 1
		end
	end
	results["Init doble no duplica (5 capas)"] = layerCount == 5

	UiRouter:Push("A")
	UiRouter:Push("B")
	results["Push A->B oculta A"] = not container("A").Visible and container("B").Visible

	UiRouter:Push("C")
	results["Push C mantiene B visible y no interactiva"] = container("B").Visible
		and not container("B").Interactable
		and container("C").Visible

	results["Pop('X') con otra cima devuelve false"] = UiRouter:Pop("X") == false
	local popped = UiRouter:Pop() and UiRouter:Pop() and UiRouter:Pop()
	results["Pop x3 deja la pila vacia"] = popped and UiRouter:GetTop() == nil and UiRouter:Pop() == false

	UiRouter:Push("A")
	UiRouter:Push("A")
	local first = UiRouter:Pop()
	results["Push A dos veces no duplica"] = first and UiRouter:GetTop() == nil

	for name, ok in results do
		if ok then
			Logger.Info(MODULE, `Router OK: {name}`)
		else
			Logger.Error(MODULE, `Router FALLO: {name}`)
		end
	end

	-- Panel manual en el HUD para probar con F5 (cursor en primera persona, etc.)
	local hud = UiRouter:GetLayer("HUD")
	local panel = Instance.new("Frame")
	panel.Name = "RouterTestPanel"
	panel.Size = UDim2.fromOffset(120, 160)
	panel.Parent = hud
	local layout = Instance.new("UIListLayout")
	layout.Parent = panel
	for _, action in { "Push A", "Push B", "Push C", "Pop", "Clear" } do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, 0, 0, 30)
		button.Text = action
		button.Parent = panel
		button.Activated:Connect(function()
			if action == "Pop" then
				UiRouter:Pop()
			elseif action == "Clear" then
				UiRouter:Clear()
			else
				UiRouter:Push(string.sub(action, 6))
			end
		end)
	end
end

task.spawn(testRouter)

-- Fase 5: demostración de Button (variantes, debounce, carga, deshabilitado, texto largo).
local function testButtons()
	local UiRouter = require(CoreKit.UiRouter)
	local Button = require(CoreKit.Components.Button)

	local panel = Instance.new("Frame")
	panel.Name = "ButtonDemoPanel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.fromScale(1, 0)
	panel.Size = UDim2.fromOffset(200, 440)
	panel.BackgroundTransparency = 0.3
	panel.Parent = UiRouter:GetLayer("HUD")
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local counter = Instance.new("TextLabel")
	counter.Size = UDim2.new(1, 0, 0, 24)
	counter.Text = "Clics: 0"
	counter.LayoutOrder = 0
	counter.Parent = panel

	local clicks = 0
	local function onClick()
		clicks += 1
		counter.Text = `Clics: {clicks}`
	end

	local order = 1
	local function add(text: string, variant: Button.ButtonVariant): Button.ButtonInstance
		local button = Button.new({
			Parent = panel,
			Text = text,
			Variant = variant,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = order,
			OnClick = onClick,
		})
		order += 1
		return button
	end

	add("Primary", "Primary")
	add("Secondary", "Secondary")
	add("Danger", "Danger")
	add("Warning", "Warning")
	add("Ghost", "Ghost")
	add("Texto muy largo para comprobar que se trunca sin desbordar el boton de ninguna manera", "Primary")

	local disabledButton = add("Deshabilitado", "Primary")
	disabledButton:SetDisabled(true)

	local loadingButton = add("Alternar carga", "Secondary")
	local toggled = false
	loadingButton:SetOnClick(function()
		onClick()
		-- Se activa la carga 2 s y se revierte; el tamaño del botón no debe cambiar
		if toggled then
			return
		end
		toggled = true
		loadingButton:SetLoading(true)
		task.delay(2, function()
			loadingButton:SetLoading(false)
			toggled = false
		end)
	end)
end

task.spawn(testButtons)

-- Fase 6: ScrollView con 30 botones (recorrible con la cruceta) y ToastService.
local function testScrollAndToast()
	local UiRouter = require(CoreKit.UiRouter)
	local Button = require(CoreKit.Components.Button)
	local ScrollView = require(CoreKit.Components.ScrollView)
	local Toast = require(CoreKit.Components.Toast)

	UiRouter:Register("Lista", function()
		local frame = Instance.new("Frame")
		frame.Name = "Lista"
		frame.Size = UDim2.fromScale(0.4, 0.6)
		frame.Position = UDim2.fromScale(0.3, 0.2)

		local scroll = ScrollView.new({ Parent = frame, Size = UDim2.fromScale(1, 1) })
		local first: GuiObject? = nil
		for index = 1, 30 do
			local button = Button.new({
				Parent = scroll.Gui,
				Text = `Elemento {index}`,
				Size = UDim2.new(1, -8, 0, 40),
				LayoutOrder = index,
				OnClick = function()
					Toast.Show(`Elemento {index} pulsado`, "Success", 1.5)
				end,
			})
			if first == nil then
				first = button.Gui
			end
		end

		return {
			Kind = "Screen",
			Layer = "Windows",
			Container = frame,
			DefaultFocusObject = first,
		}
	end)

	local panel = Instance.new("Frame")
	panel.Name = "ScrollToastPanel"
	panel.Position = UDim2.fromOffset(0, 170)
	panel.Size = UDim2.fromOffset(160, 130)
	panel.BackgroundTransparency = 0.3
	panel.Parent = UiRouter:GetLayer("HUD")
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel

	Button.new({
		Parent = panel,
		Text = "Abrir lista (30)",
		Size = UDim2.new(1, 0, 0, 40),
		OnClick = function()
			UiRouter:Push("Lista")
		end,
	})
	Button.new({
		Parent = panel,
		Text = "10 toasts",
		Variant = "Secondary",
		Size = UDim2.new(1, 0, 0, 40),
		OnClick = function()
			local types = { "Info", "Success", "Warning", "Error" }
			for index = 1, 10 do
				Toast.Show(`Toast {index}`, types[(index - 1) % 4 + 1] :: any, 4)
			end
		end,
	})
end

task.spawn(testScrollAndToast)

-- Fase 7: vista "Inventario" (Modal) que abre un drawer "Detalles" (SubModal).
local function testModalAndDrawer()
	local UiRouter = require(CoreKit.UiRouter)
	local Button = require(CoreKit.Components.Button)
	local Modal = require(CoreKit.Components.Modal)
	local SubModal = require(CoreKit.Components.SubModal)
	local ConfirmDialog = require(CoreKit.Components.ConfirmDialog)
	local Toast = require(CoreKit.Components.Toast)

	UiRouter:Register("Inventario", function()
		local modal = Modal.new({ Title = "Inventario", ViewId = "Inventario" })

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.Parent = modal.ContentFrame

		local detailsButton = Button.new({
			Parent = modal.ContentFrame,
			Text = "Ver detalles",
			Size = UDim2.new(1, -16, 0, 44),
			OnClick = function()
				UiRouter:Push("Detalles", { Item = "Espada" })
			end,
		})
		Button.new({
			Parent = modal.ContentFrame,
			Text = "Otro botón del modal",
			Variant = "Secondary",
			Size = UDim2.new(1, -16, 0, 44),
		})

		return {
			Kind = "Screen",
			Layer = "Windows",
			Container = modal.Gui,
			DefaultFocusObject = detailsButton.Gui,
		}
	end)

	UiRouter:Register("Detalles", function()
		local drawer = SubModal.new({ Title = "Detalles", Side = "Right", ViewId = "Detalles" })

		local itemLabel = Instance.new("TextLabel")
		itemLabel.Size = UDim2.new(1, 0, 0, 40)
		itemLabel.BackgroundTransparency = 1
		itemLabel.Text = "Item"
		itemLabel.TextScaled = true
		itemLabel.Parent = drawer.ContentFrame

		local confirmButton = Button.new({
			Parent = drawer.ContentFrame,
			Text = "Usar",
			Position = UDim2.fromOffset(8, 52),
			Size = UDim2.new(1, -16, 0, 44),
		})

		-- Fase 8: abre un ConfirmDialog por encima del drawer
		Button.new({
			Parent = drawer.ContentFrame,
			Text = "Eliminar item",
			Variant = "Danger",
			Position = UDim2.fromOffset(8, 104),
			Size = UDim2.new(1, -16, 0, 44),
			OnClick = function()
				ConfirmDialog.Show({
					Title = "Eliminar item",
					Message = "Esta acción no se puede deshacer. ¿Seguro que quieres continuar?",
					ConfirmText = "Eliminar",
					Variant = "Danger",
					OnConfirm = function()
						Toast.Show("Item eliminado", "Success")
					end,
					OnCancel = function()
						Toast.Show("Cancelado", "Info")
					end,
				})
			end,
		})

		return {
			Kind = "Overlay",
			Layer = "Drawers",
			Container = drawer.Gui,
			DefaultFocusObject = confirmButton.Gui,
			OnOpen = function(payload: any?)
				if type(payload) == "table" and payload.Item then
					itemLabel.Text = tostring(payload.Item)
				end
				drawer:PlayEnter()
			end,
		}
	end)

	local panel = Instance.new("Frame")
	panel.Name = "InventoryPanel"
	panel.Position = UDim2.fromOffset(0, 310)
	panel.Size = UDim2.fromOffset(160, 50)
	panel.BackgroundTransparency = 0.3
	panel.Parent = UiRouter:GetLayer("HUD")

	Button.new({
		Parent = panel,
		Text = "Abrir Inventario",
		Size = UDim2.fromScale(1, 1),
		OnClick = function()
			UiRouter:Push("Inventario")
		end,
	})
end

task.spawn(testModalAndDrawer)

-- Fase 10: consola de depuración con pestañas "Jugador" y "UI".
local function testDebug()
	local UiRouter = require(CoreKit.UiRouter)
	local ConfirmDialog = require(CoreKit.Components.ConfirmDialog)
	local DebugController = require(CoreKit.Debug.DebugController)

	local lastResult = "(sin resultados)"
	local function run(commandName: string, args: { any })
		local ok, result = DebugController.Execute(commandName, args)
		lastResult = `{commandName}: {if ok then "OK" else "FALLO"} -> {tostring(result)}`
	end

	-- Iris solo se carga si el jugador está autorizado, así que se requiere dentro del render
	DebugController.RegisterTab("Jugador", function()
		local Iris = require(CoreKit.Parent.Iris) :: any
		if Iris.Button({ "Dar 100 monedas" }).clicked() then
			run("give_coins", { 100 })
		end
		if Iris.Button({ "Velocidad 16" }).clicked() then
			run("set_speed", { 16 })
		end
		if Iris.Button({ "Velocidad 50" }).clicked() then
			run("set_speed", { 50 })
		end
		if Iris.Button({ "Decir hola" }).clicked() then
			run("say", { "hola" })
		end
		if Iris.Button({ "Expulsarme (con confirmación)" }).clicked() then
			ConfirmDialog.Show({
				Title = "Expulsar",
				Message = "Se ejecutará kick sobre tu propio jugador.",
				Variant = "Danger",
				OnConfirm = function()
					run("kick", { Players.LocalPlayer })
				end,
			})
		end
		Iris.Text({ lastResult })
	end)

	local history: { string } = {}
	local currentTop = "(vacía)"
	UiRouter.StackChanged:Connect(function(top: string?)
		currentTop = top or "(vacía)"
		table.insert(history, 1, currentTop)
		if #history > 8 then
			table.remove(history)
		end
	end)

	DebugController.RegisterTab("UI", function()
		local Iris = require(CoreKit.Parent.Iris) :: any
		Iris.Text({ `Cima de la pila: {currentTop}` })
		Iris.Separator()
		Iris.Text({ "Últimos cambios:" })
		for _, entry in history do
			Iris.Text({ `- {entry}` })
		end
	end)

	DebugController.Init()
end

task.spawn(testDebug)
