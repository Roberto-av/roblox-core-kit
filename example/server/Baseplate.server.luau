--!strict

-- Solo para pruebas con F5 en el place de desarrollo: crea un suelo anclado y un
-- SpawnLocation anclado para que el personaje no caiga al vacío y se pueda probar quieto.

local Workspace = game:GetService("Workspace")

local BASEPLATE_SIZE = Vector3.new(512, 16, 512)

local baseplate = Instance.new("Part")
baseplate.Name = "Baseplate"
baseplate.Anchored = true
baseplate.Size = BASEPLATE_SIZE
baseplate.Position = Vector3.new(0, -BASEPLATE_SIZE.Y / 2, 0) -- superficie superior en Y = 0
baseplate.Material = Enum.Material.Grass
baseplate.Color = Color3.fromRGB(106, 127, 63)
baseplate.TopSurface = Enum.SurfaceType.Smooth
baseplate.BottomSurface = Enum.SurfaceType.Smooth
baseplate.Parent = Workspace

local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Name = "SpawnLocation"
spawnLocation.Anchored = true
spawnLocation.Neutral = true
spawnLocation.Size = Vector3.new(12, 1, 12)
spawnLocation.Position = Vector3.new(0, 0.5, 0)
spawnLocation.Parent = Workspace
