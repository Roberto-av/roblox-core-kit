--!strict

-- ConfirmDialog: diálogo bloqueante en la capa Dialogs (sección 4.6).
-- Se registra en el router como "CoreKit_ConfirmDialog" al cargar este módulo
-- (UiRouter:Init() lo carga, así que queda disponible tras iniciar el router).

local Root = script.Parent.Parent
local Button = require(script.Parent.Button)
local Logger = require(Root.Util.Logger)
local Theme = require(Root.Theme)
local Types = require(Root.Types)
local UiRouter = require(Root.UiRouter)

export type ConfirmDialogProps = Types.ConfirmDialogProps
export type ConfirmDialogService = Types.ConfirmDialogService

local MODULE = "ConfirmDialog"
local VIEW_ID = "CoreKit_ConfirmDialog"
local DEFAULT_CONFIRM_TEXT = "Confirmar"
local DEFAULT_CANCEL_TEXT = "Cancelar"
local PANEL_SIZE = UDim2.fromOffset(420, 220)
local BACKDROP_TRANSPARENCY = 0.4
local MIN_TEXT_SIZE = 12
local BUTTON_HEIGHT = 44

local function createLabel(name: string, parent: GuiObject): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.FontFace = Theme.Font
	label.TextColor3 = Theme.Colors.Text
	label.TextScaled = true
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = MIN_TEXT_SIZE
	constraint.MaxTextSize = Theme.TextMaxSize
	constraint.Parent = label
	return label
end

local function createView(): Types.ViewContract
	local current: ConfirmDialogProps? = nil
	local resolved = false

	local gui = Instance.new("Frame")
	gui.Name = VIEW_ID
	gui.Size = UDim2.fromScale(1, 1)
	gui.BackgroundTransparency = 1
	gui.BorderSizePixel = 0

	-- Backdrop: bloquea los clics hacia lo que hay debajo, pero no cierra el diálogo
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.ZIndex = 1
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Active = true
	backdrop.Selectable = false
	backdrop.BorderSizePixel = 0
	backdrop.BackgroundColor3 = Theme.Colors.Backdrop
	backdrop.BackgroundTransparency = BACKDROP_TRANSPARENCY
	backdrop.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.ZIndex = 2
	panel.Active = true
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = PANEL_SIZE
	panel.BackgroundColor3 = Theme.Colors.Surface
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius
	corner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.Parent = panel

	local titleLabel = createLabel("Title", panel)
	titleLabel.Size = UDim2.new(1, 0, 0, 36)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left

	local messageLabel = createLabel("Message", panel)
	messageLabel.Position = UDim2.fromOffset(0, 48)
	messageLabel.Size = UDim2.new(1, 0, 1, -(48 + BUTTON_HEIGHT + 12))
	messageLabel.TextWrapped = true
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextYAlignment = Enum.TextYAlignment.Top

	local buttonRow = Instance.new("Frame")
	buttonRow.Name = "Buttons"
	buttonRow.AnchorPoint = Vector2.new(0, 1)
	buttonRow.Position = UDim2.fromScale(0, 1)
	buttonRow.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
	buttonRow.BackgroundTransparency = 1
	buttonRow.Parent = panel
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rowLayout.Padding = UDim.new(0, 12)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = buttonRow

	local cancelButton: Types.ButtonInstance
	local confirmButton: Types.ButtonInstance

	-- Cancelar: Pop y luego OnCancel. Un único desenlace por apertura.
	local function cancel()
		if resolved then
			return
		end
		resolved = true
		local props = current
		UiRouter:Pop(VIEW_ID)
		if props and props.OnCancel then
			task.spawn(props.OnCancel)
		end
	end

	-- Confirmar: bloquea ambos botones (sin doble confirmación), Pop y luego OnConfirm.
	local function confirm()
		if resolved then
			return
		end
		resolved = true
		cancelButton:SetDisabled(true)
		confirmButton:SetDisabled(true)
		local props = current
		UiRouter:Pop(VIEW_ID)
		if props then
			task.spawn(props.OnConfirm)
		end
	end

	cancelButton = Button.new({
		Parent = buttonRow,
		Text = DEFAULT_CANCEL_TEXT,
		Variant = "Secondary",
		Size = UDim2.fromOffset(150, BUTTON_HEIGHT),
		LayoutOrder = 1,
		OnClick = cancel,
	})
	confirmButton = Button.new({
		Parent = buttonRow,
		Text = DEFAULT_CONFIRM_TEXT,
		Variant = "Primary",
		Size = UDim2.fromOffset(150, BUTTON_HEIGHT),
		LayoutOrder = 2,
		OnClick = confirm,
	})

	return {
		Kind = "Overlay",
		Layer = "Dialogs",
		Container = gui,
		DefaultFocusObject = cancelButton.Gui, -- foco inicial en Cancelar, por seguridad
		OnBackRequested = cancel, -- B / Backspace equivalen a Cancelar
		OnOpen = function(payload: any?)
			local props = payload :: ConfirmDialogProps
			current = props
			resolved = false
			titleLabel.Text = props.Title
			messageLabel.Text = props.Message
			cancelButton:SetText(props.CancelText or DEFAULT_CANCEL_TEXT)
			confirmButton:SetText(props.ConfirmText or DEFAULT_CONFIRM_TEXT)
			confirmButton:SetVariant(props.Variant or "Primary")
			cancelButton:SetDisabled(false)
			confirmButton:SetDisabled(false)
		end,
	}
end

UiRouter:Register(VIEW_ID, createView)

local ConfirmDialog: ConfirmDialogService = {
	Show = function(props: ConfirmDialogProps): boolean
		if type(props) ~= "table" or type(props.Title) ~= "string" or type(props.Message) ~= "string" then
			Logger.Warn(MODULE, "Show requiere Title y Message de tipo string")
			return false
		end
		if type(props.OnConfirm) ~= "function" then
			Logger.Warn(MODULE, "Show requiere OnConfirm")
			return false
		end
		-- Un diálogo a la vez
		if UiRouter:IsOpen(VIEW_ID) then
			Logger.Warn(MODULE, "ya hay un diálogo abierto; se rechaza el nuevo")
			return false
		end
		return UiRouter:Push(VIEW_ID, props)
	end,
}

return ConfirmDialog
