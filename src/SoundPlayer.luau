--!strict

-- SoundPlayer: una única Sound por clave del tema, cacheada en SoundService.CoreKit_Sounds.
-- SoundService:PlayLocalSound recibe una instancia Sound, no un ID.

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local Logger = require(script.Parent.Util.Logger)
local Theme = require(script.Parent.Theme)

local MODULE = "SoundPlayer"
local FOLDER_NAME = "CoreKit_Sounds"

local SoundPlayer = {}

local cache: { [string]: Sound } = {}

local function getFolder(): Folder
	local existing = SoundService:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = SoundService
	return folder
end

-- Devuelve la Sound de la clave (creándola la primera vez) o nil si la clave no existe.
local function getSound(key: string): Sound?
	local cached = cache[key]
	if cached and cached.Parent then
		return cached
	end
	local soundId = Theme.Sounds[key]
	if soundId == nil then
		Logger.Warn(MODULE, `clave de sonido inexistente: {key}`)
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = soundId
	sound.Parent = getFolder()
	cache[key] = sound
	return sound
end

function SoundPlayer.Play(key: string)
	local sound = getSound(key)
	if sound == nil or sound.SoundId == "" then
		return
	end
	SoundService:PlayLocalSound(sound)
end

function SoundPlayer.Preload()
	local toLoad: { Instance } = {}
	for key in Theme.Sounds do
		local sound = getSound(key)
		if sound and sound.SoundId ~= "" then
			table.insert(toLoad, sound)
		end
	end
	if #toLoad == 0 then
		return
	end
	local ok, err = pcall(ContentProvider.PreloadAsync, ContentProvider, toLoad)
	if not ok then
		Logger.Warn(MODULE, `fallo al precargar sonidos: {err}`)
	end
end

return SoundPlayer
