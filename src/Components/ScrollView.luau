--!strict

-- ScrollView: ScrollingFrame responsivo que no secuestra el foco del mando (sección 4.4).
-- Selectable = false: la selección recorre los hijos y Roblox desplaza el frame al hijo enfocado.

local Root = script.Parent.Parent
local Cleaner = require(Root.Util.Cleaner)
local Theme = require(Root.Theme)
local Types = require(Root.Types)

export type ScrollViewProps = Types.ScrollViewProps
export type ScrollViewInstance = Types.ScrollViewInstance

local DEFAULT_SIZE = UDim2.fromScale(1, 1)
local DEFAULT_CELL_SIZE = UDim2.fromOffset(100, 100)
local DEFAULT_PADDING = UDim.new(0, 6)
local SCROLLBAR_THICKNESS = 6

local ScrollView = {}

function ScrollView.new(props: ScrollViewProps): ScrollViewInstance
	local cleaner = Cleaner.new()

	local gui = cleaner:Add(Instance.new("ScrollingFrame"))
	gui.Name = "CoreKit_ScrollView"
	gui.Size = props.Size or DEFAULT_SIZE
	gui.Position = props.Position or UDim2.new()
	gui.BackgroundTransparency = 1
	gui.BorderSizePixel = 0
	gui.Selectable = false
	gui.ScrollingDirection = Enum.ScrollingDirection.Y
	gui.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gui.CanvasSize = UDim2.fromScale(0, 0)
	gui.ScrollBarThickness = SCROLLBAR_THICKNESS
	gui.ScrollBarImageColor3 = Theme.Colors.Text
	gui.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar -- la barra no tapa el contenido
	gui.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable

	local padding = props.Padding or DEFAULT_PADDING
	if props.Layout == "Grid" then
		local grid = Instance.new("UIGridLayout")
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.CellSize = props.CellSize or DEFAULT_CELL_SIZE
		grid.CellPadding = UDim2.new(padding.Scale, padding.Offset, padding.Scale, padding.Offset)
		grid.Parent = gui
	else
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = padding
		list.Parent = gui
	end

	if props.Parent then
		gui.Parent = props.Parent
	end

	local self: ScrollViewInstance = {
		Gui = gui,

		ResetScroll = function(_self: ScrollViewInstance)
			gui.CanvasPosition = Vector2.zero
		end,

		Destroy = function(_self: ScrollViewInstance)
			cleaner:Destroy() -- idempotente
		end,
	}
	return self
end

return ScrollView
