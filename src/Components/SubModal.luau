--!strict

-- SubModal: panel deslizante de la capa Drawers (Kind = "Overlay") con backdrop (sección 4.3).
-- Backdrop y Panel son hermanos: un clic dentro del panel nunca llega al backdrop.

local TweenService = game:GetService("TweenService")

local Root = script.Parent.Parent
local Button = require(script.Parent.Button)
local Cleaner = require(Root.Util.Cleaner)
local Theme = require(Root.Theme)
local Types = require(Root.Types)
local UiRouter = require(Root.UiRouter)

export type SubModalProps = Types.SubModalProps
export type SubModalInstance = Types.SubModalInstance

local TITLE_BAR_HEIGHT = 48
local CLOSE_SIZE = 40
local MIN_TEXT_SIZE = 12
local BACKDROP_TRANSPARENCY = 0.5
local ENTER_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local DEFAULT_SIZES = {
	Left = UDim2.new(0, 360, 1, 0),
	Right = UDim2.new(0, 360, 1, 0),
	Bottom = UDim2.new(1, 0, 0.5, 0),
}

local SubModal = {}

-- Posición de reposo (visible) y de partida (fuera de pantalla) según el lado.
local function getPositions(side: string, size: UDim2): (UDim2, UDim2, Vector2)
	if side == "Left" then
		return UDim2.fromScale(0, 0.5), UDim2.new(-size.X.Scale, -size.X.Offset, 0.5, 0), Vector2.new(0, 0.5)
	elseif side == "Right" then
		return UDim2.fromScale(1, 0.5), UDim2.new(1 + size.X.Scale, size.X.Offset, 0.5, 0), Vector2.new(1, 0.5)
	end
	return UDim2.fromScale(0.5, 1), UDim2.new(0.5, 0, 1 + size.Y.Scale, size.Y.Offset), Vector2.new(0.5, 1)
end

function SubModal.new(props: SubModalProps): SubModalInstance
	if props.OnCloseRequested == nil and props.ViewId == nil then
		error("[CoreKit][SubModal] se requiere ViewId u OnCloseRequested para poder cerrar el panel", 2)
	end

	local cleaner = Cleaner.new()
	local enterTween: Tween? = nil

	local function requestClose()
		local callback = props.OnCloseRequested
		if callback then
			task.spawn(callback)
		elseif props.ViewId then
			UiRouter:Pop(props.ViewId)
		end
	end

	-- Contenedor transparente de pantalla completa
	local gui = cleaner:Add(Instance.new("Frame"))
	gui.Name = "CoreKit_SubModal"
	gui.Size = UDim2.fromScale(1, 1)
	gui.BackgroundTransparency = 1
	gui.BorderSizePixel = 0

	-- Backdrop: cierra al hacer clic, pero nunca recibe foco de mando
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
	cleaner:Add(backdrop.Activated:Connect(requestClose))

	-- Panel: hermano del backdrop, con ZIndex superior y Active para absorber clics
	local panelSize = props.Size or DEFAULT_SIZES[props.Side]
	local restPosition, startPosition, anchor = getPositions(props.Side, panelSize)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.ZIndex = 2
	panel.Active = true
	panel.AnchorPoint = anchor
	panel.Size = panelSize
	panel.Position = startPosition
	panel.BackgroundColor3 = Theme.Colors.Surface
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius
	corner.Parent = panel

	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, TITLE_BAR_HEIGHT)
	titleBar.BackgroundTransparency = 1
	titleBar.Parent = panel

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

	cleaner:Add(Button.new({
		Parent = titleBar,
		Text = "X",
		Variant = "Ghost",
		Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		OnClick = requestClose,
	}))

	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Position = UDim2.fromOffset(0, TITLE_BAR_HEIGHT)
	contentFrame.Size = UDim2.new(1, 0, 1, -TITLE_BAR_HEIGHT)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = panel

	local function cancelEnterTween()
		if enterTween then
			enterTween:Cancel()
			enterTween = nil
		end
	end
	cleaner:Add(cancelEnterTween)

	local self: SubModalInstance = {
		Gui = gui,
		Backdrop = backdrop,
		Panel = panel,
		ContentFrame = contentFrame,

		-- Llamado desde OnOpen: reinicia la posición y desliza el panel hacia su lugar
		PlayEnter = function(_self: SubModalInstance)
			cancelEnterTween()
			panel.Position = startPosition
			local tween = TweenService:Create(panel, ENTER_INFO, { Position = restPosition })
			enterTween = tween
			tween:Play()
		end,

		Destroy = function(_self: SubModalInstance)
			cleaner:Destroy() -- idempotente
		end,
	}
	return self
end

return SubModal
