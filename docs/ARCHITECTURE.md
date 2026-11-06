# Arquitectura

## Capas

`UiRouter:Init()` crea cinco `ScreenGui` en `PlayerGui`, una sola vez por sesión. Todas usan `ResetOnSpawn = false`, `ZIndexBehavior = Sibling`, `IgnoreGuiInset = false` y `ScreenInsets = CoreUISafeInsets`.

| Capa | ScreenGui | DisplayOrder | Contenido |
| --- | --- | --- | --- |
| HUD | `CoreKit_HUD` | 0 | Elementos fijos; no es una vista de pila |
| Windows | `CoreKit_Windows` | 10 | Vistas `Screen` (menús, inventarios) |
| Drawers | `CoreKit_Drawers` | 20 | Vistas `Overlay` laterales con backdrop |
| Dialogs | `CoreKit_Dialogs` | 30 | Vistas `Overlay` bloqueantes |
| Toasts | `CoreKit_Toasts` | 40 | Notificaciones; nunca seleccionables |
| Debug | `CoreKit_Debug` | 100 | Solo existe si el servidor autoriza al jugador |

`CoreKit_Debug` lo crea `DebugController`, no el router. Iris crea sus propios `ScreenGui`; se les aplica `DisplayOrderOffset = 100` para que queden sobre todas las capas.

## Pila de vistas

El router mantiene una pila LIFO. Cada vista es un `ViewContract` creado por una factory en el primer `Push` y cacheado después.

- **Validación**: `Windows` exige `Kind = "Screen"`; `Drawers` y `Dialogs` exigen `"Overlay"`. Si no coinciden, `error()` con el `viewId`.
- **Push**: si la vista ya es la cima, solo refresca `OnOpen`; si está más abajo, se rechaza. La vista anterior pierde `Interactable`. Una `Screen` oculta todas las vistas visibles; un `Overlay` deja las anteriores visibles (su backdrop bloquea los clics).
- **Pop**: restaura la visibilidad desde la nueva cima hasta la primera `Screen` y devuelve `Interactable` a la cima. `Pop(expectedViewId)` solo actúa si ese id es la cima.
- **ModalUnlock**: con la pila no vacía, un `TextButton` de tamaño 0 con `Modal = true` libera el cursor en primera persona sin bloquear clics ni recibir foco.
- Los callbacks del consumidor (`OnOpen`, `OnClose`, `OnBackRequested`) corren con `task.spawn`: un error suyo no rompe el router.

## Flujo de foco

1. Cada contenedor de vista es un `SelectionGroup` con `SelectionBehavior.Stop` en las cuatro direcciones: el foco no escapa de la vista superior.
2. El foco por defecto (`DefaultFocusObject`) se asigna con `task.defer` **solo si la última entrada es de gamepad**. Con ratón o toque nunca aparece el recuadro de selección. Al volver a gamepad con pila no vacía y sin selección, se enfoca la cima.
3. Al abrir una vista encima, se guarda `lastFocusedObject` de la anterior. Al hacer `Pop`, se restaura si sigue siendo válido (en el árbol, descendiente del contenedor, visible y seleccionable); si no, se usa `DefaultFocusObject`.
4. Retroceso: `CoreKit_BackAction` (ButtonB + Backspace, prioridad 3000) actúa solo en `Begin`, pasa si hay un `TextBox` enfocado o la pila está vacía, llama `OnBackRequested` si existe o `Pop()`, y devuelve `Sink`.

## Componentes

Leen colores, fuente, radios, tamaño de texto y sonidos de `Theme.luau`. Todo texto usa `TextScaled` + `UITextSizeConstraint` + `TextTruncate.AtEnd`. Cada componente registra conexiones, tweens e instancias en un `Cleaner`; `Destroy()` es idempotente.

- `Button`: el clic se ejecuta solo en `Activated` (ratón, toque y ButtonA); ButtonA en `InputBegan/Ended` solo anima la escala.
- `SubModal`: Backdrop y Panel son hermanos; el panel es `Active` y con ZIndex superior para que sus clics no lleguen al backdrop.
- `ConfirmDialog`: se registra al cargar su módulo (`UiRouter:Init()` lo carga con un require diferido para evitar un ciclo). B equivale a Cancelar; Confirmar se bloquea tras la primera pulsación.

## Modelo de seguridad del debug

El servidor es la única autoridad. El cliente no decide nada.

- La lista blanca se pasa a `DebugService.Init` desde un script de `ServerScriptService`; nunca vive en `src/`, en `example/client` ni en un objeto replicado. Con `realm = "shared"` el código de `DebugService` es legible por los clientes, y por eso no contiene secretos.
- `DebugAuth.IsAllowed`: en Studio siempre `true`; fuera de Studio, `false` si `ProductionEnabled` no es `true`, y si lo es, solo para los `UserId` del set.
- `ExecuteCommand` revalida en cada llamada, en este orden, devolviendo `(false, motivo)` en la primera falla:
  1. autorización
  2. rate limit (token bucket 10/s, capacidad 10, limpieza en `PlayerRemoving`)
  3. nombre de comando (string, ≤ 64, registrado)
  4. `args` es una tabla limpia con exactamente los argumentos esperados
  5. cada argumento contra su tipo (string ≤ 256; number finito; integer; boolean; `Player` por `UserId` presente en el servidor)
  6. `pcall` del callback; un error devuelve `(false, "error interno")` y se registra
- `DebugController.Init` consulta `CanUseDebug`; si no devuelve `true`, no crea `ScreenGui`, listeners ni carga Iris.
- Los `renderFn` de las pestañas corren dentro del ciclo de Iris, que no admite yields: `Execute` (que invoca al servidor) debe llamarse con `task.spawn`.
