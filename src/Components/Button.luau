--!strict

-- Button: botón temático (sección 4.1). El clic se ejecuta solo en Activated;
-- ButtonA en InputBegan/Ended únicamente anima la escala.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Root = script.Parent.Parent
local Cleaner = require(Root.Util.Cleaner)
local SoundPlayer = require(Root.SoundPlayer)
local Theme = require(Root.Theme)
local Types = require(Root.Types)

export type ButtonVariant = Types.ButtonVariant
export type ButtonProps = Types.ButtonProps
export type ButtonInstance = Types.ButtonInstance

local DEFAULT_SIZE = UDim2.fromOffset(160, 44)
local DEFAULT_DEBOUNCE = 0.2
local PRESSED_SCALE = 0.94
local STROKE_NORMAL = 1.5
local STROKE_FOCUSED = 3.0
local MIN_TEXT_SIZE = 12
local SPINNER_SIZE = 24
local SPINNER_SPEED = 360 -- grados por segundo

local PRESS_INFO = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local Button = {}

-- Un objeto puede recibir el foco si es visible, seleccionable e interactuable.
local function isFocusable(object: GuiObject): boolean
	return object.Visible and object.Selectable and object.Interactable
end

-- Busca a dónde mover el foco cuando el botón deja de ser seleccionable.
local function findFocusFallback(gui: TextButton): GuiObject?
	local nextDown = gui.NextSelectionDown
	if nextDown and nextDown:IsA("GuiObject") and isFocusable(nextDown) then
		return nextDown
	end
	-- Sin NextSelectionDown válido: primer objeto enfocable de la vista (el contenedor con SelectionGroup)
	local container: Instance? = gui.Parent
	while container and not (container:IsA("GuiObject") and container.SelectionGroup) do
		container = container.Parent
	end
	if container then
		for _, descendant in container:GetDescendants() do
			if descendant ~= gui and descendant:IsA("GuiObject") and isFocusable(descendant) then
				return descendant
			end
		end
	end
	return nil
end

function Button.new(props: ButtonProps): ButtonInstance
	local cleaner = Cleaner.new()

	local variant: ButtonVariant = props.Variant or "Primary"
	local debounceTime = props.DebounceTime or DEFAULT_DEBOUNCE
	local soundKey = props.Sound or "Click"
	local onClick: (() -> ())? = props.OnClick
	local disabled = props.Disabled == true
	local loading = false
	local lastClick = -math.huge
	local pressed = false
	local scaleTween: Tween? = nil
	local spinnerConnection: RBXScriptConnection? = nil

	-- Estructura ------------------------------------------------------------
	local gui = cleaner:Add(Instance.new("TextButton"))
	gui.Name = "CoreKit_Button"
	gui.AutoButtonColor = false
	gui.Size = props.Size or DEFAULT_SIZE
	gui.Position = props.Position or UDim2.new()
	gui.AnchorPoint = props.AnchorPoint or Vector2.zero
	gui.LayoutOrder = props.LayoutOrder or 0
	gui.FontFace = Theme.Font
	gui.TextColor3 = Theme.Colors.Text
	gui.TextScaled = true
	gui.TextWrapped = false
	gui.TextTruncate = Enum.TextTruncate.AtEnd
	gui.Text = props.Text or ""
	gui.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius
	corner.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- sin esto el trazo se aplica al texto
	stroke.Thickness = STROKE_NORMAL
	stroke.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = gui

	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MinTextSize = MIN_TEXT_SIZE
	textConstraint.MaxTextSize = Theme.TextMaxSize
	textConstraint.Parent = gui

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = gui

	-- Frame transparente sin parent: oculta el recuadro de selección nativo
	local selectionImage = cleaner:Add(Instance.new("Frame"))
	selectionImage.BackgroundTransparency = 1
	selectionImage.BorderSizePixel = 0
	gui.SelectionImageObject = selectionImage

	-- Spinner: círculo trazado con un degradado que deja un arco abierto
	local spinner = Instance.new("ImageLabel")
	spinner.Name = "Spinner"
	spinner.AnchorPoint = Vector2.new(0.5, 0.5)
	spinner.Position = UDim2.fromScale(0.5, 0.5)
	spinner.Size = UDim2.fromOffset(SPINNER_SIZE, SPINNER_SIZE)
	spinner.BackgroundTransparency = 1
	spinner.Visible = false
	spinner.Parent = gui
	local spinnerCorner = Instance.new("UICorner")
	spinnerCorner.CornerRadius = UDim.new(0.5, 0)
	spinnerCorner.Parent = spinner
	local spinnerStroke = Instance.new("UIStroke")
	spinnerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	spinnerStroke.Thickness = 3
	spinnerStroke.Color = Theme.Colors.Spinner
	spinnerStroke.Parent = spinner
	local spinnerGradient = Instance.new("UIGradient")
	spinnerGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0),
		NumberSequenceKeypoint.new(0.61, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	spinnerGradient.Parent = spinnerStroke

	-- Apariencia ---------------------------------------------------------------
	local function applyVisuals()
		local isGhost = variant == "Ghost"
		local baseColor = Theme.Colors[variant]
		if disabled then
			gui.BackgroundColor3 = Theme.Colors.Disabled
			gui.BackgroundTransparency = if isGhost then 1 else 0
			stroke.Color = Theme.Colors.Disabled
			stroke.Transparency = 0
			gui.TextTransparency = if loading then 1 else 0.5
		else
			gui.BackgroundColor3 = baseColor
			gui.BackgroundTransparency = if isGhost then 1 else 0
			stroke.Color = if isGhost then baseColor else Theme.Colors.Text
			stroke.Transparency = if isGhost then 0 else 0.6
			gui.TextTransparency = if loading then 1 else 0
		end
	end

	-- Escala -------------------------------------------------------------------
	local function cancelScaleTween()
		if scaleTween then
			scaleTween:Cancel()
			scaleTween = nil
		end
	end

	local function tweenScale(target: number, info: TweenInfo)
		cancelScaleTween()
		local tween = TweenService:Create(uiScale, info, { Scale = target })
		scaleTween = tween
		tween:Play()
	end

	-- Seguridad: vuelve a 1.0 de inmediato
	local function forceScaleReset()
		pressed = false
		cancelScaleTween()
		uiScale.Scale = 1
	end

	cleaner:Add(cancelScaleTween)

	local function press()
		pressed = true
		tweenScale(PRESSED_SCALE, PRESS_INFO)
	end

	local function release()
		if pressed then
			pressed = false
			tweenScale(1, RELEASE_INFO)
		end
	end

	-- Estado interactivo --------------------------------------------------------
	local function applyInteractivity()
		local interactive = not disabled and not loading
		if not interactive and GuiService.SelectedObject == gui then
			GuiService.SelectedObject = findFocusFallback(gui)
		end
		gui.Interactable = interactive
		gui.Selectable = interactive
		if not interactive then
			forceScaleReset()
		end
		applyVisuals()
	end

	-- Eventos -------------------------------------------------------------------
	cleaner:Add(gui.Activated:Connect(function()
		if disabled or loading then
			return
		end
		local now = os.clock()
		if now - lastClick < debounceTime then
			return
		end
		lastClick = now
		SoundPlayer.Play(soundKey)
		local callback = onClick
		if callback then
			task.spawn(callback)
		end
	end))

	cleaner:Add(gui.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			press()
		end
	end))

	cleaner:Add(gui.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			release()
		end
	end))

	-- ButtonA llega a UserInputService marcado como procesado; no se filtra por gameProcessedEvent
	cleaner:Add(UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.ButtonA and GuiService.SelectedObject == gui then
			press()
		end
	end))

	cleaner:Add(UserInputService.InputEnded:Connect(function(input: InputObject)
		local inputType = input.UserInputType
		if
			input.KeyCode == Enum.KeyCode.ButtonA
			or inputType == Enum.UserInputType.MouseButton1
			or inputType == Enum.UserInputType.Touch
		then
			release() -- también cubre soltar el ratón fuera del botón
		end
	end))

	cleaner:Add(gui.MouseLeave:Connect(release))

	cleaner:Add(gui.SelectionGained:Connect(function()
		stroke.Thickness = STROKE_FOCUSED
	end))

	cleaner:Add(gui.SelectionLost:Connect(function()
		stroke.Thickness = STROKE_NORMAL
		forceScaleReset()
	end))

	cleaner:Add(gui.AncestryChanged:Connect(forceScaleReset))
	cleaner:Add(gui:GetPropertyChangedSignal("Visible"):Connect(function()
		if not gui.Visible then
			forceScaleReset()
		end
	end))

	-- Spinner -------------------------------------------------------------------
	local function stopSpinner()
		if spinnerConnection then
			spinnerConnection:Disconnect()
			spinnerConnection = nil
		end
		spinner.Visible = false
		spinner.Rotation = 0
	end

	cleaner:Add(stopSpinner)

	local function startSpinner()
		if spinnerConnection then
			return
		end
		spinner.Visible = true
		spinnerConnection = RunService.RenderStepped:Connect(function(deltaTime: number)
			spinner.Rotation = (spinner.Rotation + SPINNER_SPEED * deltaTime) % 360
		end)
	end

	-- API pública ---------------------------------------------------------------
	local self: ButtonInstance = {
		Gui = gui,

		SetText = function(_self: ButtonInstance, text: string)
			gui.Text = text
		end,

		SetVariant = function(_self: ButtonInstance, newVariant: ButtonVariant)
			variant = newVariant
			applyVisuals()
		end,

		SetDisabled = function(_self: ButtonInstance, value: boolean)
			disabled = value
			applyInteractivity()
		end,

		SetLoading = function(_self: ButtonInstance, value: boolean)
			if loading == value then
				return
			end
			loading = value
			if loading then
				startSpinner()
			else
				stopSpinner()
			end
			applyInteractivity()
		end,

		SetOnClick = function(_self: ButtonInstance, callback: () -> ())
			onClick = callback
		end,

		Destroy = function(_self: ButtonInstance)
			cleaner:Destroy() -- idempotente
		end,
	}

	if props.Loading == true then
		loading = true
		startSpinner()
	end
	applyInteractivity()
	if props.Parent then
		gui.Parent = props.Parent
	end

	return self
end

return Button
