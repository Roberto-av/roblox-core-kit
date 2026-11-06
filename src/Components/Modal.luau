--!strict

-- Modal: ventana de la capa Windows (Kind = "Screen") con barra de título, [X] y ContentFrame (sección 4.2).
-- Es un componente visual: la vista registrada en el router lo envuelve y usa modal.Gui como Container.

local Root = script.Parent.Parent
local Button = require(script.Parent.Button)
local Cleaner = require(Root.Util.Cleaner)
local Theme = require(Root.Theme)
local Types = require(Root.Types)
local UiRouter = require(Root.UiRouter)

export type ModalProps = Types.ModalProps
export type ModalInstance = Types.ModalInstance

local DEFAULT_SIZE = UDim2.fromScale(0.5, 0.6)
local DEFAULT_POSITION = UDim2.fromScale(0.5, 0.5)
local TITLE_BAR_HEIGHT = 48
local CLOSE_SIZE = 40
local MIN_TEXT_SIZE = 12

local Modal = {}

function Modal.new(props: ModalProps): ModalInstance
	if props.OnCloseRequested == nil and props.ViewId == nil then
		error("[CoreKit][Modal] se requiere ViewId u OnCloseRequested para poder cerrar el modal", 2)
	end

	local cleaner = Cleaner.new()

	local gui = cleaner:Add(Instance.new("Frame"))
	gui.Name = "CoreKit_Modal"
	gui.AnchorPoint = Vector2.new(0.5, 0.5)
	gui.Size = props.Size or DEFAULT_SIZE
	gui.Position = props.Position or DEFAULT_POSITION
	gui.BackgroundColor3 = Theme.Colors.Surface
	gui.BorderSizePixel = 0
	gui.Active = true -- absorbe los clics dentro de la ventana

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius
	corner.Parent = gui

	-- Barra de título
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, TITLE_BAR_HEIGHT)
	titleBar.BackgroundTransparency = 1
	titleBar.Parent = gui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Position = UDim2.fromOffset(12, 0)
	titleLabel.Size = UDim2.new(1, -(CLOSE_SIZE + 24), 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = Theme.Font
	titleLabel.TextColor3 = Theme.Colors.Text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextScaled = true
	titleLabel.TextWrapped = false
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Text = props.Title
	titleLabel.Parent = titleBar

	local titleConstraint = Instance.new("UITextSizeConstraint")
	titleConstraint.MinTextSize = MIN_TEXT_SIZE
	titleConstraint.MaxTextSize = Theme.TextMaxSize
	titleConstraint.Parent = titleLabel

	-- [X]: OnCloseRequested o, si no existe, Pop(viewId) (solo cierra si esta vista es la cima)
	local function requestClose()
		local callback = props.OnCloseRequested
		if callback then
			task.spawn(callback)
		elseif props.ViewId then
			UiRouter:Pop(props.ViewId)
		end
	end

	local closeButton = Button.new({
		Parent = titleBar,
		Text = "X",
		Variant = "Ghost",
		Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		OnClick = requestClose,
	})
	cleaner:Add(closeButton)

	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Position = UDim2.fromOffset(0, TITLE_BAR_HEIGHT)
	contentFrame.Size = UDim2.new(1, 0, 1, -TITLE_BAR_HEIGHT)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = gui

	local self: ModalInstance = {
		Gui = gui,
		ContentFrame = contentFrame,
		CloseButton = closeButton,

		SetTitle = function(_self: ModalInstance, title: string)
			titleLabel.Text = title
		end,

		Destroy = function(_self: ModalInstance)
			cleaner:Destroy() -- idempotente
		end,
	}
	return self
end

return Modal
