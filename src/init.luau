--!strict

-- Raíz del kit: reexporta los tipos públicos (R-05).

local Types = require(script.Types)

export type ViewKind = Types.ViewKind
export type ViewLayer = Types.ViewLayer
export type ViewContract = Types.ViewContract
export type ViewFactory = Types.ViewFactory
export type UiRouter = Types.UiRouter
export type Theme = Types.Theme
export type ButtonVariant = Types.ButtonVariant
export type ButtonProps = Types.ButtonProps
export type ButtonInstance = Types.ButtonInstance
export type ModalProps = Types.ModalProps
export type ModalInstance = Types.ModalInstance
export type SubModalProps = Types.SubModalProps
export type SubModalInstance = Types.SubModalInstance
export type ScrollViewProps = Types.ScrollViewProps
export type ScrollViewInstance = Types.ScrollViewInstance
export type ToastType = Types.ToastType
export type ToastService = Types.ToastService
export type ConfirmDialogProps = Types.ConfirmDialogProps
export type ConfirmDialogService = Types.ConfirmDialogService
export type ArgType = Types.ArgType
export type CommandDefinition = Types.CommandDefinition
export type DebugService = Types.DebugService
export type DebugController = Types.DebugController

return {}
