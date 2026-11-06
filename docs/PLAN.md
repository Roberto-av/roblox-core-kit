# Roblox Core Kit — Plan de implementación y reglas para el agente

Nov 5, 2026 · @DevcoBaja

El agente implementa la especificación v0.1.0 (corregida) en 11 fases, en orden, sin avanzar a la siguiente hasta cumplir los criterios de aceptación de la actual.

## Instrucción inicial para el agente

Pega este bloque como primer mensaje, adjuntando la especificación corregida y este plan.

```text
Vas a implementar desde cero el repositorio roblox-core-kit siguiendo DOS documentos adjuntos:
1) "Especificación Técnica v0.1.0 (corregida)": fuente de verdad de QUÉ construir (APIs, tipos, comportamiento).
2) "Plan de implementación y reglas": fuente de verdad de CÓMO y EN QUÉ ORDEN construirlo.

Trabaja fase por fase en el orden del plan. Al terminar cada fase:
- verifica todos sus criterios de aceptación,
- ejecuta stylua --check, selene y rojo build sin errores,
- haz el commit indicado,
- y entrégame un reporte breve con el formato de la regla R-20.
No empieces la siguiente fase hasta que yo responda "continúa".
Si la especificación es ambigua o contradictoria, detente y pregunta; no inventes comportamiento.
```

## Reglas de desarrollo

Veinte reglas obligatorias; si alguna choca con la especificación, gana la especificación y el agente lo reporta.

### Alcance y fuente de verdad

- **R-01** La especificación define las APIs públicas. No se añaden, renombran ni eliminan funciones, campos o tipos públicos sin aprobación.
- **R-02** Ante ambigüedad o contradicción: detenerse, citar la sección y proponer una opción. Nunca inventar comportamiento en silencio.
- **R-03** Nada de lógica de juego, persistencia (ProfileStore, DataStore) ni dependencias fuera de Iris y sleitnick/signal.

### Código Luau

- **R-04** Todo archivo empieza con `--!strict`. Prohibido `any` salvo donde la especificación lo usa (`payload`, `args`, retorno de comandos).
- **R-05** Los tipos públicos viven en `Types.luau` y se reexportan desde `init.luau`. Cada módulo exporta su tipo de instancia.
- **R-06** Nada de globales, `_G`, `shared` ni `wait()`/`spawn()`/`delay()`: usar `task.wait`, `task.spawn`, `task.defer`, `task.delay`.
- **R-07** Toda conexión, tween e instancia creada por un componente se registra en su `Cleaner`; `Destroy()` deja cero conexiones vivas y es idempotente (llamarlo dos veces no falla).
- **R-08** Los callbacks del consumidor (`OnClick`, `OnOpen`, `OnClose`, `OnConfirm`, comandos) se ejecutan con `task.spawn` o `pcall`; un error del consumidor nunca rompe el kit.
- **R-09** Colores, fuentes, radios, tamaños de texto y sonidos salen siempre de `Theme.luau`. Prohibido `Color3` o `rbxassetid` literal en componentes.
- **R-10** Requires de dependencias según la regla de la sección 6.2 de la especificación (`Packages` = padre de la raíz del kit). Nunca `game.ReplicatedStorage.Packages` dentro de `src/`.
- **R-11** Logs solo a través de `Logger` con prefijo `[CoreKit]`; nada de `print` suelto en `src/`.

### Seguridad (servidor)

- **R-12** El servidor no confía en ningún dato del cliente: autorización, rate limit y validación de tipos en cada invocación, en el orden de la sección 5.1.
- **R-13** La lista blanca solo existe en el script de servidor que llama `DebugService.Init`; nunca en `src/`, en `example/client` ni en un objeto replicado.

### Estilo y herramientas

- **R-14** `stylua --check src example` y `selene src example` deben pasar sin errores ni advertencias antes de cada commit.
- **R-15** `rojo build default.project.json -o build.rbxm` y `rojo build dev.project.json -o dev.rbxl` deben compilar sin errores en cada fase.
- **R-16** Nombres: módulos y tipos en PascalCase, funciones locales y variables en camelCase, constantes en UPPER\_SNAKE\_CASE. Comentarios y logs en español.

### Git y entregas

- **R-17** Un commit por paso del plan, con el mensaje indicado (Conventional Commits, sección 7.2). Nunca mezclar dos fases en un commit.
- **R-18** Prohibido commitear `Packages/`, `ServerPackages/`, `sourcemap.json`, `*.rbxl`, `*.rbxm` ni archivos de lock de Studio.
- **R-19** Cada componente nuevo se demuestra en `example/` dentro del mismo commit, para poder probarlo con F5.
- **R-20** Reporte al cierre de cada fase, con este formato:

```text
Fase N — <nombre>: COMPLETA | BLOQUEADA
Archivos: <lista de archivos creados/modificados>
Criterios: <cada criterio con ✔ o ✘>
Herramientas: stylua ✔ · selene ✔ · rojo build ✔
Commit: <hash corto> <mensaje>
Dudas o desvíos de la spec: <ninguno | lista>
Cómo probarlo: <pasos concretos en Studio>
```

## Plan paso a paso

Once fases en orden de dependencia: cada una solo usa lo construido en las anteriores. Las referencias entre paréntesis apuntan a secciones de la especificación.

### Fase 0 — Repositorio y toolchain

1. Crear la estructura de carpetas exacta de la sección 6.1, con archivos `.luau` vacíos que solo contengan `--!strict` y `return {}`.
2. Escribir `rokit.toml` (6.4) y ejecutar `rokit install`.
3. Escribir `wally.toml` (6.3), `default.project.json` y `dev.project.json` (6.2). Ejecutar `wally search iris` y `wally search signal`, corregir nombres y versiones si difieren, y luego `wally install`.
4. Escribir `selene.toml` (`std = "roblox"`), `stylua.toml` (tabs, ancho 120, comillas dobles), `.gitignore` (R-18) y `CHANGELOG.md` con la sección `[Unreleased]`.
5. Generar sourcemap y ejecutar `wally-package-types` (6.2).

**Criterios:** `rojo build` de ambos proyectos compila; `require(Packages.Iris)` y `require(Packages.Signal)` funcionan desde `src/init.luau` en el place de prueba. **Commit:** `chore: scaffold repository and toolchain`

### Fase 1 — Utilidades base

1. `Util/Cleaner.luau`: `Add(item)` acepta `RBXScriptConnection`, `Instance`, `Tween` (lo cancela), función o tabla con `Destroy`; `Clean()` libera en orden inverso; `Destroy()` idempotente.
2. `Util/Logger.luau`: `Info`, `Warn`, `Error` con prefijo `[CoreKit]` y nombre de módulo.
3. `Types.luau`: todos los tipos públicos de las secciones 3.1, 4 y 5.

**Criterios:** un script de prueba en `example/client` crea un Cleaner con 3 conexiones, lo limpia y verifica que ninguna sigue conectada (`connection.Connected == false`). **Commit:** `feat(util): add cleaner, logger and public types`

### Fase 2 — Tema y sonido (4.0)

1. `Theme.luau` con el tipo `Theme`, valores por defecto para las 5 variantes de botón, `Surface`, `Text`, `Backdrop` y claves de sonido `Click`, `Hover`, `Error`.
2. `SoundPlayer.luau`: caché de una `Sound` por clave en `SoundService.CoreKit_Sounds`, `Play(key)` con `PlayLocalSound(sound)`, `Preload()`. Clave inexistente → `Logger.Warn`, sin error.

**Criterios:** llamar `Play("Click")` 20 veces crea una sola instancia `Sound`. **Commit:** `feat(theme): add theme tokens and sound player`

### Fase 3 — UiRouter: capas y pila (2, 3.1, 3.2)

1. `Init()`: crear las 5 ScreenGuis con las propiedades de la sección 2 (no `CoreKit_Debug`). Llamarlo dos veces no duplica nada.
2. `GetLayer`, `Register`, validación Kind/Layer, instanciación perezosa y caché de vistas.
3. `Push` y `Pop` siguiendo literalmente los pasos numerados de 3.2, incluido `Interactable`, la visibilidad hasta la primera `Screen` y `expectedViewId`.
4. Botón `ModalUnlock` (paso 8.2 de Push).
5. `Clear`, `GetTop`, `IsOpen`, `StackChanged`.

**Criterios:** en el ejemplo, con 3 vistas de prueba (Screen A, Screen B, Overlay C) hechas con `Frame` simples: Push A→B oculta A; Push C mantiene B visible y no interactiva; Pop ×3 deja la pila vacía; Push de A dos veces no duplica; `Pop("X")` con otra cima devuelve `false`. Con cámara en primera persona, el cursor se libera al abrir y se bloquea al cerrar. **Commit:** `feat(router): add layered screen guis and view stack`

### Fase 4 — UiRouter: foco y retroceso (3.2 pasos 6–8, 3.3)

1. Trampa de foco con `SelectionGroup` y `SelectionBehavior.Stop`.
2. Foco por defecto solo con gamepad, con `task.defer`, y reasignación en `LastInputTypeChanged`.
3. Guardado y restauración de `lastFocusedObject` con la validación de 3.2.
4. Acción `CoreKit_BackAction` (ButtonB + Backspace), handler exacto de 3.3 y soporte de `OnBackRequested`.

**Criterios:** con gamepad emulado, el foco no sale de la vista superior; B cierra exactamente una vista por pulsación; Backspace no cierra nada con un `TextBox` enfocado; al cerrar un Overlay el foco vuelve al botón que lo abrió; con ratón nunca aparece recuadro de selección. **Commit:** `feat(router): add focus trap and back navigation`

### Fase 5 — Button (4.1)

1. Estructura, variantes y `UIStroke` con `ApplyStrokeMode.Border`.
2. Clic solo por `Activated`, con debounce, sonido y `task.spawn`.
3. Animación de escala con ratón, toque y ButtonA, y los tres resets de seguridad.
4. `SetDisabled`, `SetLoading` (spinner, tamaño constante, traspaso de foco), `SetText`, `SetVariant`, `SetOnClick`, `Destroy`.

**Criterios:** un clic con gamepad dispara `OnClick` exactamente una vez; 10 clics rápidos con debounce 0.2 s disparan ≤ 2 veces en 0.3 s; arrastrar el ratón fuera mientras se presiona devuelve la escala a 1.0; en carga el `AbsoluteSize` no cambia; texto largo se trunca sin desbordar. **Commit:** `feat(button): add themed interactive button`

### Fase 6 — ScrollView y Toast (4.4, 4.5)

1. ScrollView con layouts List y Grid, propiedades de 4.4 y `ResetScroll`.
2. ToastService con `CanvasGroup`, cola, máximo 4 visibles y duración por defecto 3 s.

**Criterios:** una lista de 30 botones dentro de ScrollView se recorre entera con la cruceta y el scroll sigue al foco; 10 toasts seguidos muestran 4 a la vez y el resto en cola, sin robar foco. **Commit:** `feat(components): add scroll view and toast service`

### Fase 7 — Modal y SubModal (4.2, 4.3)

1. Modal con título, \[X\] y `ContentFrame`; cierre por `OnCloseRequested` o `Pop(viewId)`.
2. SubModal con backdrop y panel hermanos, tween de entrada por `Side`, cierre por backdrop.
3. En el ejemplo: una vista "Inventario" (Modal) que abre un drawer "Detalles" (SubModal).

**Criterios:** clic dentro del panel no cierra el drawer; clic en el backdrop sí; B cierra primero el drawer y luego el modal; el modal queda visible bajo el drawer pero no responde a clics. **Commit:** `feat(components): add modal and drawer`

### Fase 8 — ConfirmDialog (4.6)

1. Vista `CoreKit_ConfirmDialog` registrada en `UiRouter:Init()`.
2. Backdrop que bloquea sin cerrar, foco en Cancelar, `OnBackRequested` = Cancelar, bloqueo de doble confirmación, rechazo de un segundo `Show`.

**Criterios:** con gamepad, el foco inicial está en Cancelar; B ejecuta `OnCancel` una vez; pulsar Confirmar dos veces seguidas ejecuta `OnConfirm` una sola vez; el diálogo se abre encima de un drawer abierto y al cerrarse el foco vuelve al drawer. **Commit:** `feat(dialog): add blocking confirm dialog`

### Fase 9 — Debug servidor (5.1)

1. `DebugAuth` con la lógica Studio / `ProductionEnabled` / set de UserIds.
2. `DebugRateLimiter` (token bucket 10/s, limpieza en `PlayerRemoving`).
3. `DebugService.Init` (remotes, doble Init = error) y `RegisterCommand`.
4. `ExecuteCommand` con las 6 comprobaciones en orden y `pcall`.
5. En `example/server`: comandos `give_coins(integer)`, `set_speed(number)`, `say(string)`, `kick(Player)`.

**Criterios:** desde la barra de comandos del cliente, invocar `ExecuteCommand` con tipos erróneos, argumentos de más, NaN, `math.huge`, strings de 1000 caracteres y nombres inexistentes devuelve `false` sin errores en servidor; 50 llamadas en un segundo dejan pasar ≤ 10; con `ProductionEnabled = false` en un servidor publicado, todo devuelve `false`. **Commit:** `feat(debug): add authoritative debug service`

### Fase 10 — Debug cliente (5.2)

1. `DebugController.Init`: espera de remotes, `CanUseDebug` con `pcall`, salida silenciosa si no autoriza.
2. Creación de `CoreKit_Debug`, configuración de Iris (`DisplayOrderOffset`) e `Iris.Init`.
3. Toggle por F4, L3+R3 y botón táctil, ignorando TextBox enfocado.
4. `RegisterTab` (antes o después de Init) y `Execute`.
5. En `example/client`: pestañas "Jugador" (botones para los comandos de la fase 9) y "UI" (pila actual del router vía `StackChanged`).

**Criterios:** un jugador no autorizado no tiene `CoreKit_Debug` en `PlayerGui` ni Iris cargado; uno autorizado abre la consola con los tres métodos; la consola queda por encima de cualquier diálogo. **Commit:** `feat(debug): add iris debug controller`

Al final de la fase 10 se ejecuta la matriz de pruebas completa y el checklist de release (secciones siguientes); su commit es `chore(release): v0.1.0`.

## Matriz de pruebas manuales

Se ejecuta completa al cierre de la fase 10 y parcialmente al cierre de cada fase (las filas de lo construido). Móvil se prueba con el emulador de dispositivos de Studio (un iPhone con notch y una tablet); gamepad, con un mando real conectado en Studio.

| # | Prueba | PC | Móvil | Gamepad |
| --- | --- | --- | --- | --- |
| 1 | La UI respeta el notch y la barra superior de Roblox | ✔ | ✔ | ✔ |
| 2 | Tras morir y reaparecer, la UI y la pila siguen intactas | ✔ | ✔ | ✔ |
| 3 | Abrir Inventario → Detalles → Confirmar y cerrar todo en orden inverso | ✔ | ✔ | ✔ |
| 4 | El foco nunca sale de la vista superior con la cruceta ni el stick | — | — | ✔ |
| 5 | B cierra una sola vista por pulsación y no saca del modo selección | — | — | ✔ |
| 6 | Backspace cierra la vista superior, salvo con un TextBox enfocado | ✔ | — | — |
| 7 | Al cerrar un Overlay el foco vuelve al botón que lo abrió | — | — | ✔ |
| 8 | Con cámara en primera persona el cursor se libera con un menú abierto | ✔ | — | — |
| 9 | Los botones de la HUD siguen clicables con un menú abierto | ✔ | ✔ | — |
| 10 | Botón: escala vuelve a 1.0 tras arrastrar fuera o perder foco | ✔ | ✔ | ✔ |
| 11 | Botón: un clic ejecuta la acción exactamente una vez | ✔ | ✔ | ✔ |
| 12 | Botón en carga: sin cambio de tamaño ni interacción | ✔ | ✔ | ✔ |
| 13 | Textos largos (60+ caracteres) se truncan sin desbordar | ✔ | ✔ | ✔ |
| 14 | Clic dentro del drawer no lo cierra; clic en el backdrop sí | ✔ | ✔ | — |
| 15 | ScrollView: el scroll sigue al foco en una lista de 30 elementos | ✔ | ✔ | ✔ |
| 16 | Toasts: máximo 4 visibles, nunca roban foco ni clics | ✔ | ✔ | ✔ |
| 17 | ConfirmDialog: foco inicial en Cancelar; doble confirmación imposible | ✔ | ✔ | ✔ |
| 18 | Debug: jugador no autorizado no recibe ScreenGui ni Iris | ✔ | ✔ | ✔ |
| 19 | Debug: apertura con F4, L3+R3 y botón táctil | ✔ | ✔ | ✔ |
| 20 | Debug: argumentos inválidos y spam devuelven `false` sin errores en servidor | ✔ | — | — |

✔ = aplica en esa plataforma · — = no aplica.

## Definición de terminado y release 0.1.0

Una fase está terminada solo si cumple todos los puntos de la primera lista; el release, si además cumple la segunda.

### Por fase

- [ ] Todos los criterios de aceptación de la fase verificados en Studio.
- [ ] `--!strict` sin errores de tipo en los archivos tocados.
- [ ] `stylua --check`, `selene` y ambos `rojo build` pasan.
- [ ] Demostración funcional en `example/`.
- [ ] Commit único con el mensaje del plan y reporte R-20 entregado.

### Release 0.1.0

- [ ] Matriz de pruebas completa en verde (las 20 filas).
- [ ] `docs/ARCHITECTURE.md`: capas, pila de vistas, flujo de foco y modelo de seguridad del debug.
- [ ] `docs/API_REFERENCE.md`: cada función y tipo público con firma y un ejemplo de uso.
- [ ] `README.md` con instalación por Wally y un ejemplo mínimo de Push/Pop.
- [ ] `CHANGELOG.md`: `[Unreleased]` renombrado a `[0.1.0] - AAAA-MM-DD`.
- [ ] Versión `0.1.0` en `wally.toml`, commit `chore(release): v0.1.0` y tag anotado `v0.1.0`.
- [ ] Instalación probada desde cero en un proyecto vacío con `wally install` antes de `wally publish`.
