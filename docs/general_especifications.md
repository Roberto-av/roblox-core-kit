# **Roblox Core Kit — Especificación Técnica v0.1.0 (corregida)**

Nov 5, 2026 · @DevcoBaja

## **Registro de correcciones**

Se encontraron 24 fallas en la versión original: 9 críticas (el código no funcionaría o tendría un hueco de seguridad), 10 de diseño (comportamiento ambiguo o incompleto) y 5 de forma. Todas están resueltas en las secciones siguientes.

| \# | Sección | Severidad | Falla original | Corrección |
| :---- | :---- | :---- | :---- | :---- |
| 1 | 4.1 | Crítica | SoundService:PlayLocalSound recibe una instancia Sound, no un ID. Pasarle el ID de Theme falla. | SoundPlayer precarga una Sound por cada ID del tema y reproduce esa instancia. |
| 2 | 4.1 | Crítica | UIStroke dentro de un TextButton se aplica al texto por defecto, no al borde. | ApplyStrokeMode \= Enum.ApplyStrokeMode.Border. |
| 3 | 4.1 | Crítica | Escuchar ButtonA en InputBegan para ejecutar el clic duplica la acción: Roblox ya dispara Activated con ButtonA. | El clic se ejecuta solo en Activated; ButtonA en InputBegan/Ended solo anima la escala. |
| 4 | 3.3 | Crítica | El handler de ContextActionService se invoca en Begin y en End; sin filtrar, cada pulsación de B haría dos :Pop(). | El handler actúa solo con Enum.UserInputState.Begin y devuelve Sink. |
| 5 | 3.2 | Crítica | Un TextButton modal de pantalla completa bloquea los clics del HUD y puede recibir foco de mando. | Botón de tamaño 0, Selectable \= false, Active \= false; solo sirve para Modal. |
| 6 | 5.1 | Crítica | ExecuteCommand no revalida la lista blanca: cualquier cliente puede invocar el remote sin pasar por CanUseDebug. | Cada invocación revalida autorización en servidor antes del rate limit y la ejecución. |
| 7 | 5.1 | Crítica | Se exige validar tipos pero no existe API para registrar comandos ni un esquema de argumentos. | DebugService.RegisterCommand(name, { Args, Callback }) con esquema de tipos. |
| 8 | 2 / 5.2 | Crítica | El router crea CoreKit\_Debug para todos los jugadores, contradiciendo que no se crea UI para no autorizados. | CoreKit\_Debug lo crea DebugController solo tras autorización. |
| 9 | 6 | Crítica | Util/Signal.luau duplica la dependencia Wally sleitnick/signal. | Se elimina Util/Signal.luau; se usa la dependencia. |
| 10 | 3.2 | Diseño | Con Kind \= "Screen" solo se ocultaba la vista superior; si había un Overlay encima de otra Screen, esta quedaba visible. | Push de Screen oculta todas las vistas visibles; Pop restaura hasta la Screen más cercana. |
| 11 | 3.2 | Diseño | "Pierde interactividad" sin mecanismo. | Interactable \= false en el contenedor anterior (heredado por descendientes). |
| 12 | 3.2 | Diseño | Sin regla para hacer Push de una vista ya presente en la pila. | Si es la superior se ignora; si está más abajo se rechaza con advertencia. |
| 13 | 3.2 | Diseño | Asignar SelectedObject siempre muestra el recuadro de selección a usuarios de ratón. | Solo si la última entrada es de gamepad; se reasigna al cambiar a gamepad. |
| 14 | 3.1 | Diseño | ViewLayer incluye HUD, que no es una vista de pila; y Kind puede contradecir a Layer. | HUD sale de ViewLayer; se valida Windows→Screen, Drawers/Dialogs→Overlay. |
| 15 | 4.3 | Diseño | Si el panel es hijo del backdrop, un clic dentro del panel cierra el drawer. | Backdrop y panel son hermanos; panel con Active \= true y ZIndex superior. |
| 16 | 4.6 | Diseño | El diálogo no tenía backdrop (los clics atravesaban) ni definía qué pasa con B/Backspace. | Backdrop no cerrable; retroceso \= Cancelar; Confirmar se bloquea tras la primera pulsación. |
| 17 | 4.2 | Diseño | El botón \[X\] no tenía comportamiento por defecto; :Pop() podría cerrar otra vista. | \[X\] llama OnCloseRequested o UiRouter:Pop(viewId) con verificación de cima. |
| 18 | 5.2 | Diseño | Iris crea sus propios ScreenGuis; no se monta "dentro" de una capa. F4 no existe en consola ni móvil. | Configuración de DisplayOrderOffset; toggle por F4, combinación de gamepad y botón táctil. |
| 19 | 1 / 4 | Diseño | Se promete prevenir desbordamiento tipográfico pero ningún componente lo especifica. | TextScaled \+ UITextSizeConstraint \+ TextTruncate en Button, Modal y Toast. |
| 20 | 6.2 | Forma | rokit.toml no incluye Wally; wally.toml sin description, license, include. | Toolchain completo y manifiesto publicable. |
| 21 | 7.1 | Forma | No se aclara que en 0.x un cambio incompatible sube MINOR y que ^0.1.0 no acepta 0.2.0. | Regla explícita de SemVer 0.x. |
| 22 | 3.2 | Forma | Numeración rota en los pasos de Push/Pop (1, b, c, d, 1, 2, 3, e…). | Renumerado secuencial. |
| 23 | 6 | Forma | No se explica cómo resuelve dependencias el paquete dentro de Wally ni en el place de prueba. | Regla script.Parent.\<Dep\> y mapeo en dev.project.json. |
| 24 | 5.1 | Forma | Server code en realm shared es legible por clientes. | Nota: no incluir secretos; la lista blanca se pasa en Init desde un script del servidor. |

## **1\. Visión general y alcance**

**Versión:** 0.1.0 · **Arquitectura:** Theme-Driven Vanilla Luau \+ Immediate Mode Debug (Iris) · **Entorno:** Rojo 7.4+, Luau \--\!strict, Rokit, Wally · **Entradas:** PC (ratón y teclado), móvil (táctil), consola (gamepad Xbox / PlayStation).

roblox-core-kit es una biblioteca modular, desacoplada y agnóstica de juego, distribuida por Wally y sincronizada con Rojo. Resuelve:

1. **Robustez visual multiplataforma:** respeta zonas seguras (CoreUISafeInsets), persiste la interfaz entre respawns (ResetOnSpawn \= false) y evita desbordamientos de texto (TextScaled \+ UITextSizeConstraint \+ TextTruncate).  
2. **Navegación direccional para gamepad:** aislamiento de foco con SelectionGroup y SelectionBehavior.Stop, foco predeterminado solo cuando la entrada activa es gamepad, y retroceso controlado (ButtonB, Backspace).  
3. **Depuración extensible y segura:** infraestructura cliente-servidor con Iris, lista blanca autoritativa revalidada en cada llamada, y registro de pestañas (cliente) y comandos con esquema de tipos (servidor) por parte del juego consumidor.

**Fuera de alcance:** persistencia (ProfileStore u otras), lógica de juego y localización de textos.

## **2\. Arquitectura de capas y ScreenGuis**

UiRouter:Init() crea cinco ScreenGuis dentro de PlayerGui, una sola vez por sesión. Todas usan ResetOnSpawn \= false, ZIndexBehavior \= Enum.ZIndexBehavior.Sibling, IgnoreGuiInset \= false y ScreenInsets \= Enum.ScreenInsets.CoreUISafeInsets. DisplayOrder actúa a nivel de ScreenGui, por eso cada capa es una ScreenGui propia.

| Capa | ScreenGui | DisplayOrder | Creada por | Propósito |
| :---- | :---- | :---- | :---- | :---- |
| HUD | CoreKit\_HUD | 0 | UiRouter | Elementos fijos de juego. No es una vista de pila; se accede con UiRouter:GetLayer("HUD"). |
| Windows | CoreKit\_Windows | 10 | UiRouter | Menús, inventarios, tiendas (Kind \= "Screen"). |
| Drawers | CoreKit\_Drawers | 20 | UiRouter | Paneles laterales con backdrop (Kind \= "Overlay"). |
| Dialogs | CoreKit\_Dialogs | 30 | UiRouter | Confirmaciones y alertas bloqueantes (Kind \= "Overlay"). |
| Toasts | CoreKit\_Toasts | 40 | UiRouter | Notificaciones temporales, nunca seleccionables. |
| Debug | CoreKit\_Debug | 100 | DebugController | Solo existe si el servidor autoriza al jugador (ver 5.2). |

**Nota sobre backdrops:** con CoreUISafeInsets el backdrop no cubre la barra superior de Roblox ni el notch. Es el comportamiento deseado (los botones de Roblox siguen accesibles); los clics en esa franja no llegan a la UI del juego.

## **3\. Contrato de vistas y navegación (UiRouter.luau)**

El router mantiene una pila LIFO de vistas; cada Push guarda el foco y cada Pop lo restaura, con trampa de foco nativa y retroceso por B/Backspace mientras la pila no esté vacía.

### **3.1. Tipos (\--\!strict)**

export type ViewKind \= "Screen" \| "Overlay"  
export type ViewLayer \= "Windows" \| "Drawers" \| "Dialogs" \-- HUD no es apilable

export type ViewContract \= {  
	Kind: ViewKind,  
	Layer: ViewLayer,  
	Container: GuiObject,  
	DefaultFocusObject: GuiObject?,  
	OnOpen: ((payload: any?) \-\> ())?,  
	OnClose: (() \-\> ())?,  
	OnBackRequested: (() \-\> ())?, \-- si existe, B/Backspace lo llaman en vez de Pop()  
}

export type ViewFactory \= () \-\> ViewContract

export type UiRouter \= {  
	Init: (self: UiRouter) \-\> (),  
	Register: (self: UiRouter, viewId: string, factory: ViewFactory) \-\> (),  
	Push: (self: UiRouter, viewId: string, payload: any?) \-\> boolean,  
	Pop: (self: UiRouter, expectedViewId: string?) \-\> boolean,  
	Clear: (self: UiRouter) \-\> (),  
	GetTop: (self: UiRouter) \-\> string?,  
	IsOpen: (self: UiRouter, viewId: string) \-\> boolean,  
	GetLayer: (self: UiRouter, layer: "HUD" \| ViewLayer \| "Toasts") \-\> ScreenGui,  
	StackChanged: Signal, \-- sleitnick/signal; dispara (topViewId: string?)  
}  
**Validación al instanciar la vista:** Windows exige Kind \= "Screen"; Drawers y Dialogs exigen Kind \= "Overlay". Si no coinciden, error() con el viewId. La factory se ejecuta en el primer Push; el ViewContract se cachea y se reutiliza. El router hace Container.Parent \= GetLayer(view.Layer) y deja Container.Visible \= false al instanciar.

### **3.2. Ciclo de vida de la pila**

**:Push(viewId, payload?) \-\> boolean**

1. Si viewId no está registrado: warn y return false.  
2. Si viewId ya es la cima: llama OnOpen(payload) de nuevo (refresco) y return true. Si está más abajo en la pila: warn y return false.  
3. Instancia o recupera la vista y valida Kind/Layer.  
4. Si hay vista superior previa:  
   1. Guarda GuiService.SelectedObject en su metadata como lastFocusedObject.  
   2. Pone Interactable \= false en su Container (se hereda a los descendientes).  
   3. Si la nueva vista es Screen: oculta (Visible \= false) todas las vistas de la pila que estén visibles.  
   4. Si la nueva vista es Overlay: las vistas anteriores siguen visibles; el backdrop de la nueva bloquea los clics.  
5. Inserta la vista en la pila y muestra su contenedor (Visible \= true, Interactable \= true).  
6. Trampa de foco en view.Container: SelectionGroup \= true y SelectionBehaviorUp/Down/Left/Right \= Enum.SelectionBehavior.Stop.  
7. Foco: si la última entrada es gamepad (UserInputService:GetLastInputType() es Gamepad1..8), asigna GuiService.SelectedObject \= view.DefaultFocusObject con task.defer (el objeto debe estar visible y ser Selectable). El router escucha LastInputTypeChanged y, al pasar a gamepad con pila no vacía y sin selección, enfoca el DefaultFocusObject de la cima.  
8. Si \#stack \== 1 (la pila estaba vacía):  
   1. ContextActionService:BindActionAtPriority("CoreKit\_BackAction", handleBack, false, 3000, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace).  
   2. Activa el botón modal (ModalUnlock.Visible \= true). Es un TextButton dentro de CoreKit\_Windows con Size \= UDim2.fromOffset(0, 0\), BackgroundTransparency \= 1, Text \= "", Active \= false, Selectable \= false, Modal \= true. Libera el cursor en experiencias con LockCenter o primera persona sin bloquear clics del HUD.  
9. Invoca view.OnOpen(payload) dentro de task.spawn (un error del consumidor no rompe el router).  
10. Dispara StackChanged(viewId) y return true.

**:Pop(expectedViewId?) \-\> boolean**

1. Si la pila está vacía: return false. Si se pasa expectedViewId y no es la cima: return false (evita cerrar la vista equivocada desde un botón \[X\] tardío).  
2. Extrae la cima, ejecuta OnClose() en task.spawn, oculta su contenedor y limpia GuiService.SelectedObject si apuntaba dentro de él.  
3. Si quedan vistas:  
   1. Restaura Visible \= true desde la nueva cima hacia abajo hasta incluir la primera vista Screen.  
   2. Interactable \= true en el contenedor de la nueva cima.  
   3. Si la última entrada es gamepad, restaura el foco en lastFocusedObject solo si sigue siendo válido (obj.Parent \~= nil, obj:IsDescendantOf(view.Container), obj.Visible y obj.Selectable); si no, en DefaultFocusObject.  
4. Si la pila queda vacía:  
   1. ContextActionService:UnbindAction("CoreKit\_BackAction").  
   2. ModalUnlock.Visible \= false y GuiService.SelectedObject \= nil.  
5. Dispara StackChanged(nuevaCima) y return true.

**:Clear()** hace Pop repetido hasta vaciar la pila (útil al morir o cambiar de modo de juego, porque la UI persiste entre respawns).

### **3.3. Control de retroceso**

Una sola acción atiende gamepad y teclado. Escape está reservado por el menú de Roblox, por eso el teclado usa Backspace.

local function handleBack(\_actionName: string, state: Enum.UserInputState, \_input: InputObject): Enum.ContextActionResult  
	if state \~= Enum.UserInputState.Begin then  
		return Enum.ContextActionResult.Pass  
	end  
	if UserInputService:GetFocusedTextBox() \~= nil then  
		return Enum.ContextActionResult.Pass \-- el jugador está escribiendo  
	end  
	if \#stack \== 0 then  
		return Enum.ContextActionResult.Pass  
	end  
	local top \= stack\[\#stack\]  
	if top.OnBackRequested then  
		top.OnBackRequested() \-- p. ej. ConfirmDialog lo trata como Cancelar  
	else  
		Router:Pop()  
	end  
	return Enum.ContextActionResult.Sink  
end  
OnBackRequested: (() \-\> ())? es un campo opcional del ViewContract para vistas que deben interceptar el retroceso. Devolver Sink impide que Roblox use B para salir del modo de selección. El botón táctil \[X\] de cada vista cumple la función de retroceso en móvil.

## **4\. Componentes base de interfaz**

Todos los componentes leen colores, fuentes, radios y sonidos de Theme.luau, usan Cleaner para desconectar eventos en Destroy() y aplican TextScaled \= true con UITextSizeConstraint (MinTextSize 12, MaxTextSize del tema) y TextTruncate \= AtEnd en todo texto.

### **4.0. Tema y sonido (Theme.luau, SoundPlayer.luau)**

export type Theme \= {  
	Colors: { \[string\]: Color3 }, \-- Primary, Secondary, Danger, Warning, Ghost, Surface, Text, Backdrop...  
	Font: Font,  
	CornerRadius: UDim,  
	TextMaxSize: number,  
	Sounds: { \[string\]: string }, \-- clave \-\> "rbxassetid://..." (Click, Hover, Error...)  
}  
SoundService:PlayLocalSound() recibe una instancia Sound, no un ID. SoundPlayer.Play(key: string) crea una sola Sound por clave la primera vez (parent: carpeta CoreKit\_Sounds en SoundService), la cachea y llama SoundService:PlayLocalSound(sound). SoundPlayer.Preload() precarga todas con ContentProvider:PreloadAsync. Ningún botón crea su propia Sound.

### **4.1. Botón interactivo (Button.luau)**

**Estructura:** TextButton con AutoButtonColor \= false, UICorner, UIStroke con ApplyStrokeMode \= Enum.ApplyStrokeMode.Border (sin esto el trazo se aplica al texto), UIPadding, UIScale y SelectionImageObject apuntando a un Frame transparente sin parent visible (oculta el recuadro de selección nativo).

**Foco:** SelectionGained → UIStroke.Thickness \= 3.0; SelectionLost → 1.5 y escala forzada a 1.0.

**Clic:** la acción se ejecuta solo en Activated, que Roblox dispara con ratón, toque y ButtonA sobre el objeto seleccionado. Aplica DebounceTime (por defecto 0.2 s), reproduce Sound vía SoundPlayer y llama OnClick en task.spawn.

**Animación de escala:**

* Presión: tween a 0.94 en 0.06 s (Quad, Out) en InputBegan de MouseButton1/Touch, y en UserInputService.InputBegan con KeyCode.ButtonA cuando GuiService.SelectedObject \== self.Gui. En este último caso no se descarta el evento por gameProcessedEvent \= true (consola siempre lo marca procesado). Solo anima; nunca ejecuta el clic.  
* Recuperación: tween a 1.0 en 0.15 s (Back, Out) en InputEnded y en UserInputService.InputEnded con ButtonA.  
* Seguridad: escala forzada a 1.0 también en MouseLeave, SelectionLost y cuando el botón deja de ser visible (AncestryChanged / Visible cambia).

**Deshabilitado (SetDisabled(true)):** Interactable \= false, Selectable \= false, color atenuado del tema.

**Carga (SetLoading(true)):** Interactable \= false y Selectable \= false; el texto pasa a TextTransparency \= 1 (el tamaño de la instancia no cambia) y aparece un ImageLabel spinner centrado, girado con RunService.RenderStepped. Si el botón tenía el foco de gamepad, el foco pasa al NextSelectionDown válido o al DefaultFocusObject de la vista. SetLoading(false) revierte todo y desconecta el giro.

export type ButtonVariant \= "Primary" \| "Secondary" \| "Danger" \| "Warning" \| "Ghost"

export type ButtonProps \= {  
	Parent: GuiObject?,  
	Text: string?,  
	Variant: ButtonVariant?,  
	Size: UDim2?,  
	Position: UDim2?,  
	AnchorPoint: Vector2?,  
	Sound: string?, \-- clave de Theme.Sounds (por defecto "Click")  
	DebounceTime: number?,  
	Disabled: boolean?,  
	Loading: boolean?,  
	LayoutOrder: number?,  
	OnClick: (() \-\> ())?,  
}

export type ButtonInstance \= {  
	Gui: TextButton,  
	SetText: (self: ButtonInstance, text: string) \-\> (),  
	SetVariant: (self: ButtonInstance, variant: ButtonVariant) \-\> (),  
	SetDisabled: (self: ButtonInstance, disabled: boolean) \-\> (),  
	SetLoading: (self: ButtonInstance, loading: boolean) \-\> (),  
	SetOnClick: (self: ButtonInstance, callback: () \-\> ()) \-\> (),  
	Destroy: (self: ButtonInstance) \-\> (),  
}

### **4.2. Modal base (Modal.luau)**

Ventana de la capa Windows (Kind \= "Screen") con barra de título, botón \[X\] (un Button variante Ghost) y ContentFrame. El \[X\] llama OnCloseRequested si existe; si no, UiRouter:Pop(viewId), que solo cierra si esta vista es la cima. El Modal es un componente visual; la vista registrada en el router lo envuelve en su factory y usa modal.Gui como Container.

export type ModalProps \= {  
	Title: string,  
	ViewId: string?, \-- requerido si no se pasa OnCloseRequested  
	Size: UDim2?,  
	Position: UDim2?,  
	OnCloseRequested: (() \-\> ())?,  
}

export type ModalInstance \= {  
	Gui: Frame,  
	ContentFrame: Frame,  
	CloseButton: ButtonInstance,  
	SetTitle: (self: ModalInstance, title: string) \-\> (),  
	Destroy: (self: ModalInstance) \-\> (),  
}

### **4.3. SubModal / Drawer con backdrop (SubModal.luau)**

Panel deslizante de la capa Drawers (Kind \= "Overlay"). Gui es un Frame transparente de pantalla completa que actúa como Container y contiene dos hermanos:

* **Backdrop:** TextButton de cobertura total, ZIndex \= 1, Text \= "", AutoButtonColor \= false, Active \= true, Selectable \= false, color Theme.Colors.Backdrop con transparencia 0.5. En Activated llama OnCloseRequested o UiRouter:Pop(viewId).  
* **Panel:** Frame con ZIndex \= 2 y Active \= true (absorbe los clics para que no lleguen al backdrop). Contiene título, \[X\] y ContentFrame. Entra con tween de posición desde Side en 0.2 s (Quad, Out).

export type SubModalProps \= {  
	Title: string,  
	Side: "Left" \| "Right" \| "Bottom",  
	ViewId: string?,  
	Size: UDim2?,  
	OnCloseRequested: (() \-\> ())?,  
}

export type SubModalInstance \= {  
	Gui: Frame,  
	Backdrop: TextButton,  
	Panel: Frame,  
	ContentFrame: Frame,  
	PlayEnter: (self: SubModalInstance) \-\> (), \-- llamado desde OnOpen  
	Destroy: (self: SubModalInstance) \-\> (),  
}

### **4.4. Scroll responsivo (ScrollView.luau)**

ScrollingFrame que no secuestra el foco de mando: Selectable \= false (la selección recorre los hijos y el frame se desplaza solo para mostrar el hijo enfocado), ScrollingDirection \= Y, AutomaticCanvasSize \= Enum.AutomaticSize.Y, CanvasSize \= UDim2.fromScale(0, 0\), ScrollBarThickness \= 6, VerticalScrollBarInset \= Enum.ScrollBarInset.ScrollBar (la barra no tapa el contenido) y ElasticBehavior \= Enum.ElasticBehavior.WhenScrollable. Crea el layout indicado con SortOrder \= LayoutOrder.

export type ScrollViewProps \= {  
	Parent: GuiObject?,  
	Size: UDim2?,  
	Position: UDim2?,  
	Layout: ("List" \| "Grid")?, \-- por defecto "List"  
	Padding: UDim?,  
	CellSize: UDim2?, \-- solo Grid  
}

export type ScrollViewInstance \= {  
	Gui: ScrollingFrame,  
	ResetScroll: (self: ScrollViewInstance) \-\> (), \-- CanvasPosition \= Vector2.zero  
	Destroy: (self: ScrollViewInstance) \-\> (),  
}

### **4.5. Notificaciones flotantes (Toast.luau)**

Cada toast es un CanvasGroup en CoreKit\_Toasts, con entrada y salida por tween de GroupTransparency (0.2 s). Se apilan en un UIListLayout anclado arriba al centro; máximo 4 visibles, los extra esperan en cola. Duración por defecto 3 s. Nada es Selectable ni Active, así que nunca roban foco ni clics.

export type ToastType \= "Info" \| "Success" \| "Warning" \| "Error"

export type ToastService \= {  
	Show: (message: string, toastType: ToastType?, duration: number?) \-\> (),  
}

### **4.6. Diálogo bloqueante (ConfirmDialog.luau)**

Vista registrada por el kit como "CoreKit\_ConfirmDialog" en la capa Dialogs (Kind \= "Overlay"). ConfirmDialog.Show(props) equivale a UiRouter:Push("CoreKit\_ConfirmDialog", props); OnOpen aplica los textos.

* **Backdrop:** igual al de 4.3 pero sin acción al clic (bloquea, no cierra).  
* **Foco inicial:** botón Cancelar (DefaultFocusObject), por seguridad.  
* **Retroceso:** define OnBackRequested, que equivale a pulsar Cancelar.  
* **Cancelar:** UiRouter:Pop("CoreKit\_ConfirmDialog") y luego OnCancel() si existe.  
* **Confirmar:** deshabilita ambos botones (evita doble confirmación), hace Pop y luego llama OnConfirm() en task.spawn.  
* Si se llama Show con el diálogo ya abierto, se rechaza con warn (un diálogo a la vez).

export type ConfirmDialogProps \= {  
	Title: string,  
	Message: string,  
	ConfirmText: string?, \-- por defecto "Confirmar"  
	CancelText: string?, \-- por defecto "Cancelar"  
	Variant: ("Primary" \| "Danger")?, \-- variante del botón Confirmar  
	OnConfirm: () \-\> (),  
	OnCancel: (() \-\> ())?,  
}

export type ConfirmDialogService \= {  
	Show: (props: ConfirmDialogProps) \-\> boolean,  
}

## **5\. Infraestructura de depuración (Iris extensible)**

El servidor es la única autoridad: revalida la lista blanca en cada llamada, limita la tasa y valida cada argumento contra el esquema del comando. El kit no incluye persistencia.

### **5.1. Servidor (DebugService.luau, DebugAuth.luau, DebugRateLimiter.luau)**

export type ArgType \= "string" \| "number" \| "integer" \| "boolean" \| "Player"

export type CommandDefinition \= {  
	Description: string?,  
	Args: { ArgType },  
	Callback: (player: Player, args: { any }) \-\> (boolean, any),  
}

export type DebugService \= {  
	Init: (config: {  
		AllowedUserIds: { number },  
		ProductionEnabled: boolean?, \-- por defecto false  
	}) \-\> (),  
	RegisterCommand: (name: string, definition: CommandDefinition) \-\> (),  
}  
**Autorización (DebugAuth.IsAllowed(player)):** en Studio (RunService:IsStudio()) siempre true. Fuera de Studio, false si ProductionEnabled no es true; si lo es, true solo si player.UserId está en AllowedUserIds (convertida a un set al iniciar).

**Remotes:** Init crea la carpeta ReplicatedStorage.CoreKit\_Debug con dos RemoteFunction. Init debe llamarse una sola vez; una segunda llamada lanza error().

* CanUseDebug() → boolean. También pasa por el rate limiter.  
* ExecuteCommand(commandName, args) → (ok: boolean, result: any). Orden obligatorio de comprobaciones, devolviendo (false, "\<motivo\>") en la primera que falle:  
  1. DebugAuth.IsAllowed(player); se revalida en cada llamada, nunca se confía en el cliente.  
  2. Rate limit: token bucket de 10 llamadas/s por jugador (capacidad 10, recarga 10/s); el estado se borra en PlayerRemoving.  
  3. typeof(commandName) \== "string", longitud ≤ 64 y comando registrado.  
  4. typeof(args) \== "table" y \#args \== \#definition.Args (sin argumentos extra).  
  5. Cada argumento contra su tipo: string ≤ 256 caracteres; number finito (n \== n y math.abs(n) \~= math.huge); integer además n % 1 \== 0; Player llega como UserId numérico y se resuelve con Players:GetPlayerByUserId (debe estar en el servidor).  
  6. Ejecuta pcall(definition.Callback, player, resolvedArgs). Un error devuelve (false, "error interno") y se registra con Logger en servidor.

**Nota de seguridad:** con realm \= "shared" todo el paquete vive en ReplicatedStorage, así que los clientes pueden leer el código de DebugService. Esto es aceptable porque no contiene secretos: la lista blanca la pasa a Init un script de ServerScriptService y nunca se replica.

### **5.2. Cliente (DebugController.luau)**

export type DebugController \= {  
	Init: (config: {  
		ToggleKey: Enum.KeyCode?, \-- por defecto F4  
		ShowTouchButton: boolean?, \-- por defecto true en dispositivos táctiles  
	}?) \-\> (),  
	RegisterTab: (tabTitle: string, renderFn: () \-\> ()) \-\> (),  
	Execute: (commandName: string, args: { any }) \-\> (boolean, any),  
}

1. Init espera ReplicatedStorage:WaitForChild("CoreKit\_Debug", 10\); si no aparece, termina en silencio.  
2. Invoca CanUseDebug dentro de pcall. Si devuelve otra cosa que true, termina: no requiere Iris, no crea ScreenGui ni listeners.  
3. Si está autorizado: crea CoreKit\_Debug (DisplayOrder 100, ResetOnSpawn \= false) y carga Iris. Iris crea sus propios ScreenGuis, por eso antes de Iris.Init() se configura su desplazamiento de orden (Iris.UpdateGlobalConfig({ DisplayOrderOffset \= 100 })) para que quede sobre todas las capas. Verificar el nombre de la clave en la versión de Iris instalada.  
4. Visibilidad: una variable isOpen; el render de Iris:Connect solo dibuja la ventana cuando isOpen es true (Iris en modo inmediato no dibuja lo que no se llama).  
5. Atajos de apertura: ToggleKey (F4) en teclado; en gamepad, mantener ButtonL3 y pulsar ButtonR3; en táctil, un botón pequeño de 40×40 px en la esquina inferior izquierda de CoreKit\_Debug. Todos ignoran la entrada si hay un TextBox enfocado.  
6. RegisterTab puede llamarse antes o después de Init; las pestañas se guardan y se dibujan en orden de registro.  
7. Execute envuelve ExecuteCommand:InvokeServer en pcall y convierte los argumentos Player a UserId.

## **6\. Estructura del proyecto y paquete Wally**

src/ es el paquete exportable; default.project.json lo empaqueta para Wally y dev.project.json lo monta junto a sus dependencias para probar con F5.

### **6.1. Árbol de repositorio**

roblox-core-kit/  
├── .gitignore            \-- Packages/, ServerPackages/, sourcemap.json, \*.rbxl\*  
├── default.project.json  \-- Proyecto Rojo del paquete Wally (apunta a src/)  
├── dev.project.json      \-- Place de prueba con dependencias  
├── rokit.toml            \-- Rojo, Wally, Selene, StyLua, wally-package-types  
├── wally.toml  
├── wally.lock  
├── selene.toml  
├── stylua.toml  
├── CHANGELOG.md  
├── docs/  
│   ├── ARCHITECTURE.md  
│   └── API\_REFERENCE.md  
├── example/  
│   ├── client/Init.client.luau  
│   └── server/Init.server.luau  
└── src/  
    ├── init.luau          \-- require(Packages.CoreKit)  
    ├── Types.luau  
    ├── Theme.luau  
    ├── SoundPlayer.luau  
    ├── UiRouter.luau  
    ├── Components/  
    │   ├── Button.luau  
    │   ├── Modal.luau  
    │   ├── SubModal.luau  
    │   ├── ScrollView.luau  
    │   ├── Toast.luau  
    │   └── ConfirmDialog.luau  
    ├── Debug/  
    │   ├── DebugService.luau  
    │   ├── DebugController.luau  
    │   ├── DebugAuth.luau  
    │   └── DebugRateLimiter.luau  
    └── Util/  
        ├── Cleaner.luau  
        └── Logger.luau    \-- Signal.luau eliminado: se usa sleitnick/signal

### **6.2. Resolución de dependencias**

Dentro de Packages/\_Index, Wally coloca las dependencias como hermanas del paquete. Regla para todo módulo de src/: la raíz del kit es init.luau y las dependencias están en su Parent.

\-- en src/init.luau  
local Packages \= script.Parent  
\-- en src/Components/Button.luau (un nivel más abajo)  
local Packages \= script.Parent.Parent.Parent  
local Signal \= require(Packages.Signal)  
dev.project.json reproduce ese entorno montando src/ dentro de la carpeta Packages que genera wally install, así el mismo require funciona en el place de prueba:

{  
  "name": "roblox-core-kit-dev",  
  "tree": {  
    "\$className": "DataModel",  
    "ReplicatedStorage": {  
      "Packages": {  
        "\$path": "Packages",  
        "CoreKit": { "\$path": "src" }  
      }  
    },  
    "ServerScriptService": { "Example": { "\$path": "example/server" } },  
    "StarterPlayer": {  
      "StarterPlayerScripts": { "Example": { "\$path": "example/client" } }  
    }  
  }  
}  
default.project.json:

{ "name": "CoreKit", "tree": { "\$path": "src" } }  
En modo estricto, los módulos puente que genera Wally pierden los tipos exportados; tras cada wally install ejecutar rojo sourcemap dev.project.json \-o sourcemap.json y wally-package-types \--sourcemap sourcemap.json Packages/.

### **6.3. Manifiesto Wally (wally.toml)**

\[package\]  
name \= "tu-organizacion/roblox-core-kit" \# scope \= tu usuario u org de GitHub, en minúsculas  
version \= "0.1.0"  
registry \= "https\://github.com/UpliftGames/wally-index"  
realm \= "shared"  
description \= "UI multiplataforma, navegación por gamepad y debug extensible con Iris"  
license \= "MIT"  
authors \= \["Tu Nombre"\]  
include \= \["src", "src/\*\*", "default.project.json", "wally.toml", "README.md", "LICENSE"\]

\[dependencies\]  
Iris \= "sirmallard/iris@^2"  
Signal \= "sleitnick/signal@^2.0.1"  
Antes de publicar, confirmar los nombres exactos de ambos paquetes y su última versión con wally search iris y wally search signal (no se pudo verificar en línea al redactar esta revisión).

### **6.4. Toolchain (rokit.toml)**

\[tools\]  
rojo \= "rojo-rbx/rojo@7.4.4"  
wally \= "UpliftGames/wally@0.3.2"  
selene \= "Kampfkarren/selene@0.27.1"  
stylua \= "JohnnyMorganz/StyLua@0.20.0"  
wally-package-types \= "JohnnyMorganz/wally-package-types@1.3.2"  
Versiones de referencia; actualizar a las vigentes con rokit add antes de fijarlas. selene.toml debe declarar std \= "roblox".

## **7\. Versionado, releases y commits**

### **7.1. SemVer y ciclo de versiones**

1. La serie empieza en 0.1.0 mientras la API se valida; pasa a 1.0.0 tras su adopción estable.  
2. **Regla 0.x:** mientras MAJOR sea 0, un cambio incompatible sube MINOR (0.1.x → 0.2.0) y un cambio compatible sube PATCH. En Wally, ^0.1.0 acepta 0.1.x pero no 0.2.0, así que los juegos consumidores solo reciben cambios incompatibles cuando actualizan el rango a mano.  
3. **Sincronización obligatoria** en cada release, en este orden:  
   1. version \= "x.y.z" en wally.toml.  
   2. Sección \#\# \[x.y.z\] \- AAAA-MM-DD en CHANGELOG.md.  
   3. Commit chore(release): vX.Y.Z.  
   4. Tag anotado: git tag \-a vX.Y.Z \-m "vX.Y.Z" y git push \--follow-tags.  
   5. wally login (una vez) y wally publish.

### **7.2. Convención de commits (Conventional Commits)**

\<tipo\>(\<alcance opcional\>): \<descripción concisa en imperativo y minúsculas\>

\[cuerpo opcional: qué cambia y por qué\]

\[BREAKING CHANGE: descripción, obligatoria si el cambio es incompatible\]

* Tipos permitidos: feat, fix, refactor, perf, docs, test, chore.  
* Alcances sugeridos: router, button, modal, submodal, scroll, toast, dialog, debug, theme, release.  
* Todo cambio incompatible lleva el pie BREAKING CHANGE: (o \! tras el tipo, p. ej. feat(router)\!:). En 0.x provoca subida de MINOR; desde 1.0.0, de MAJOR.