--!strict

-- DebugController (cliente): consola de depuración con Iris (sección 5.2).
-- Solo se crea UI y se carga Iris si el servidor autoriza al jugador.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Root = script.Parent.Parent
local Cleaner = require(Root.Util.Cleaner)
local Logger = require(Root.Util.Logger)
local Types = require(Root.Types)

export type DebugController = Types.DebugController

type Tab = {
	Title: string,
	Render: () -> (),
	Failed: boolean,
}

local MODULE = "DebugController"
local REMOTES_FOLDER = "CoreKit_Debug"
local REMOTES_TIMEOUT = 10
local DISPLAY_ORDER = 100
local TOUCH_BUTTON_SIZE = 40
local WINDOW_TITLE = "CoreKit Debug"
local WINDOW_SIZE = Vector2.new(480, 320)

local cleaner = Cleaner.new()
local tabs: { Tab } = {}
local executeRemote: RemoteFunction? = nil
local initialized = false
local isOpen = false

local function toggle()
	isOpen = not isOpen
end

local function isTyping(): boolean
	return UserInputService:GetFocusedTextBox() ~= nil
end

-- F4 (teclado) y L3 + R3 (gamepad); ambos ignoran la entrada con un TextBox enfocado.
local function connectToggleInputs(toggleKey: Enum.KeyCode)
	cleaner:Add(UserInputService.InputBegan:Connect(function(input: InputObject)
		if isTyping() then
			return
		end
		if input.KeyCode == toggleKey then
			toggle()
		elseif input.KeyCode == Enum.KeyCode.ButtonR3 then
			if UserInputService:IsGamepadButtonDown(input.UserInputType, Enum.KeyCode.ButtonL3) then
				toggle()
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonL3 then
			if UserInputService:IsGamepadButtonDown(input.UserInputType, Enum.KeyCode.ButtonR3) then
				toggle()
			end
		end
	end))
end

local function createTouchButton(gui: ScreenGui)
	local Button = require(Root.Components.Button)
	local button = Button.new({
		Parent = gui,
		Text = "Dbg",
		Variant = "Secondary",
		Size = UDim2.fromOffset(TOUCH_BUTTON_SIZE, TOUCH_BUTTON_SIZE),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		OnClick = toggle,
	})
	cleaner:Add(button)
end

-- Dibuja la consola cada ciclo de Iris, solo cuando isOpen es true.
-- Importante: los renderFn corren dentro del ciclo de Iris, que NO admite yields. Execute
-- invoca al servidor (yield), así que debe llamarse desde task.spawn, nunca directamente en el render.
local function startIris(Iris: any)
	local openedState = Iris.State(true)
	local sizeState = Iris.State(WINDOW_SIZE)

	Iris:Connect(function()
		if not isOpen then
			return
		end
		local window = Iris.Window({ WINDOW_TITLE }, { isOpened = openedState, size = sizeState })
		if window.closed() then
			isOpen = false
			openedState:set(true) -- listo para la próxima apertura
		end
		if #tabs > 0 then
			Iris.TabBar()
			for _, tab in tabs do
				-- Iris identifica cada widget por la línea de código que lo crea: todas las pestañas
				-- salen de esta misma línea, así que cada una necesita un ID propio (PushId/PopId).
				Iris.PushId(tab.Title)
				local tabWidget = Iris.Tab({ tab.Title })
				-- Modo inmediato: solo se ejecuta el render de la pestaña seleccionada
				if tabWidget.active() then
					local ok, err = pcall(tab.Render)
					if not ok and not tab.Failed then
						tab.Failed = true -- se registra una sola vez por pestaña
						Logger.Error(MODULE, `error al dibujar la pestaña '{tab.Title}': {err}`)
					end
				end
				Iris.End() -- cierra exactamente la Tab abierta arriba
				Iris.PopId()
			end
			Iris.End()
		else
			Iris.Text({ "No hay pestañas registradas" })
		end
		Iris.End()
	end)
end

local DebugController: DebugController = {
	Init = function(config)
		if initialized then
			return
		end
		-- 1. Esperar los remotes; si no aparecen, salir en silencio
		local folder = ReplicatedStorage:WaitForChild(REMOTES_FOLDER, REMOTES_TIMEOUT)
		if folder == nil then
			return
		end
		local canUse = folder:WaitForChild("CanUseDebug", REMOTES_TIMEOUT)
		local execute = folder:WaitForChild("ExecuteCommand", REMOTES_TIMEOUT)
		if canUse == nil or execute == nil or not canUse:IsA("RemoteFunction") or not execute:IsA("RemoteFunction") then
			return
		end
		-- 2. Consultar autorización; cualquier cosa distinta de true termina sin crear nada
		local ok, allowed = pcall(function()
			return canUse:InvokeServer()
		end)
		if not ok or allowed ~= true then
			return
		end
		initialized = true
		executeRemote = execute

		-- 3. ScreenGui propio y configuración de Iris (cargado solo ahora)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
		local gui = Instance.new("ScreenGui")
		gui.Name = "CoreKit_Debug"
		gui.DisplayOrder = DISPLAY_ORDER
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.IgnoreGuiInset = false
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		gui.Parent = playerGui
		cleaner:Add(gui)

		local Iris = require(Root.Parent.Iris) :: any
		-- Iris crea sus propios ScreenGuis: se desplaza su orden para quedar sobre todas las capas
		Iris.UpdateGlobalConfig({ DisplayOrderOffset = DISPLAY_ORDER })
		Iris.Init()
		startIris(Iris)

		-- 5. Atajos de apertura
		local resolved = config or {}
		connectToggleInputs(resolved.ToggleKey or Enum.KeyCode.F4)
		local showTouch = resolved.ShowTouchButton
		if showTouch == nil then
			showTouch = UserInputService.TouchEnabled
		end
		if showTouch then
			createTouchButton(gui)
		end
	end,

	RegisterTab = function(tabTitle: string, renderFn: () -> ())
		-- Puede llamarse antes o después de Init; se dibujan en orden de registro
		for _, tab in tabs do
			if tab.Title == tabTitle then
				tab.Render = renderFn
				tab.Failed = false
				return
			end
		end
		table.insert(tabs, { Title = tabTitle, Render = renderFn, Failed = false })
	end,

	Execute = function(commandName: string, args: { any }): (boolean, any)
		local remote = executeRemote
		if remote == nil then
			return false, "debug no disponible"
		end
		-- Los Player viajan como UserId
		local converted: { any } = {}
		for index, value in args do
			if typeof(value) == "Instance" and value:IsA("Player") then
				converted[index] = value.UserId
			else
				converted[index] = value
			end
		end
		local ok, success, result = pcall(function()
			return remote:InvokeServer(commandName, converted)
		end)
		if not ok then
			return false, "error al invocar el servidor"
		end
		return success == true, result
	end,
}

return DebugController
