--!strict

-- Tokens visuales del kit. Es el único lugar donde viven colores, fuentes,
-- radios, tamaños de texto e IDs de sonido (R-09).

local Types = require(script.Parent.Types)

export type Theme = Types.Theme

local Theme: Theme = {
	Colors = {
		-- Variantes de botón
		Primary = Color3.fromRGB(59, 130, 246),
		Secondary = Color3.fromRGB(75, 85, 99),
		Danger = Color3.fromRGB(220, 38, 38),
		Warning = Color3.fromRGB(217, 119, 6),
		Ghost = Color3.fromRGB(255, 255, 255),
		Disabled = Color3.fromRGB(55, 65, 81),
		Spinner = Color3.fromRGB(243, 244, 246),
		-- Superficies y texto
		Surface = Color3.fromRGB(31, 41, 55),
		Text = Color3.fromRGB(243, 244, 246),
		Backdrop = Color3.fromRGB(0, 0, 0),
	},
	Font = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
	CornerRadius = UDim.new(0, 8),
	TextMaxSize = 24,
	-- Claves -> "rbxassetid://...". Vacío = silencio; el juego consumidor asigna sus propios IDs.
	Sounds = {
		Click = "",
		Hover = "",
		Error = "",
	},
}

return Theme
