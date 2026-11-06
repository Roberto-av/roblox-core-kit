--!strict

-- ToastService: notificaciones flotantes en CoreKit_Toasts (sección 4.5).
-- Máximo 4 visibles; el resto espera en cola. Nada es Selectable ni Active.

local TweenService = game:GetService("TweenService")

local Root = script.Parent.Parent
local Cleaner = require(Root.Util.Cleaner)
local Logger = require(Root.Util.Logger)
local Theme = require(Root.Theme)
local Types = require(Root.Types)
local UiRouter = require(Root.UiRouter)

export type ToastType = Types.ToastType
export type ToastService = Types.ToastService

type QueuedToast = {
	Message: string,
	ToastType: ToastType,
	Duration: number,
}

local MODULE = "Toast"
local MAX_VISIBLE = 4
local DEFAULT_DURATION = 3
local FADE_TIME = 0.2
local TOAST_WIDTH = 320
local TOAST_HEIGHT = 48
local TOAST_SPACING = 6
local TOP_MARGIN = 8
local MIN_TEXT_SIZE = 12

local TYPE_COLORS: { [string]: string } = {
	Info = "Primary",
	Success = "Success",
	Warning = "Warning",
	Error = "Danger",
}

local FADE_INFO = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local queue: { QueuedToast } = {}
local visibleCount = 0
local holder: Frame? = nil

-- Contenedor anclado arriba al centro con un UIListLayout; se crea la primera vez que se necesita.
local function getHolder(): Frame?
	local current = holder
	if current and current.Parent then
		return current
	end
	local ok, layer = pcall(UiRouter.GetLayer, UiRouter, "Toasts")
	if not ok then
		Logger.Warn(MODULE, "UiRouter:Init() debe llamarse antes de mostrar toasts")
		return nil
	end
	local frame = Instance.new("Frame")
	frame.Name = "ToastHolder"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, TOP_MARGIN)
	frame.Size = UDim2.fromOffset(TOAST_WIDTH, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	frame.Active = false
	frame.Selectable = false
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, TOAST_SPACING)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = frame
	frame.Parent = layer :: ScreenGui
	holder = frame
	return frame
end

local function createToastGui(request: QueuedToast): CanvasGroup
	local group = Instance.new("CanvasGroup")
	group.Name = "Toast"
	group.Size = UDim2.new(1, 0, 0, TOAST_HEIGHT)
	group.BackgroundColor3 = Theme.Colors[TYPE_COLORS[request.ToastType]]
	group.BorderSizePixel = 0
	group.GroupTransparency = 1
	group.Active = false
	group.Selectable = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius
	corner.Parent = group

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = group

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Theme.Font
	label.TextColor3 = Theme.Colors.Text
	label.TextScaled = true
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = request.Message
	label.Active = false
	label.Parent = group

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = MIN_TEXT_SIZE
	constraint.MaxTextSize = Theme.TextMaxSize
	constraint.Parent = label

	return group
end

local processQueue

-- Ciclo de vida de un toast: entrada, espera, salida y liberación del hueco.
local function runToast(request: QueuedToast, parent: Frame)
	local cleaner = Cleaner.new()
	local group = cleaner:Add(createToastGui(request))
	group.Parent = parent

	local function fade(target: number)
		local tween = TweenService:Create(group, FADE_INFO, { GroupTransparency = target })
		cleaner:Add(tween)
		tween:Play()
		tween.Completed:Wait()
	end

	task.spawn(function()
		fade(0)
		task.wait(request.Duration)
		fade(1)
		cleaner:Destroy()
		visibleCount -= 1
		processQueue()
	end)
end

function processQueue()
	while visibleCount < MAX_VISIBLE and #queue > 0 do
		local parent = getHolder()
		if parent == nil then
			table.clear(queue)
			return
		end
		local request = table.remove(queue, 1) :: QueuedToast
		visibleCount += 1
		runToast(request, parent)
	end
end

local Toast: ToastService = {
	Show = function(message: string, toastType: ToastType?, duration: number?)
		if type(message) ~= "string" then
			Logger.Warn(MODULE, "el mensaje del toast debe ser un string")
			return
		end
		local resolvedType: ToastType = if toastType ~= nil and TYPE_COLORS[toastType] ~= nil then toastType else "Info"
		table.insert(queue, {
			Message = message,
			ToastType = resolvedType,
			Duration = if duration ~= nil and duration > 0 then duration else DEFAULT_DURATION,
		})
		processQueue()
	end,
}

return Toast
