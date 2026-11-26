# claude-mux - Multiplexor de Claude Code

[English](../README.md) · **Español** · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

Sesiones persistentes de Claude Code para todos tus proyectos - accesibles desde cualquier lugar a través de la app móvil de Claude. ***Gestionado por Claude!***

## Instalar

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

Luego inicia una sesión:

```bash
claude-mux ~/ruta/a/tu/proyecto
```

El instalador pregunta si quieres una sesión home al iniciar sesión. Si aceptas, una sesión protegida de Claude se lanza automáticamente cada vez que inicias sesión - siempre accesible desde tu teléfono o cualquier cliente de Remote Control, incluso si nunca abres una terminal.

¡Eso es todo! Estás en una sesión persistente de Claude con detección de sesión y Remote Control habilitado. **A partir de aquí, todo es conversacional.**

[Homebrew, instalación manual y otras opciones](../docs/INSTALL.md)

## Por qué

Remote Control promete Claude Code desde cualquier lugar - pero sin gestión de sesiones, es una interfaz de segunda clase incluso desde Claude Desktop:

- **Las sesiones mueren** cuando cierras la terminal - y no vuelven tras un fallo o un reinicio
- **El contexto de conversación** no se reanuda automáticamente
- **Sin base de operaciones** - nada se ejecuta cuando tomas tu teléfono a menos que hayas dejado algo abierto
- **Remote Control requiere una sesión activa** - no puedes iniciar una desde RC
- **Los comandos slash no funcionan en sesiones RC** - no hay cambio de modelo, compactación ni cambios de modo de permisos
- **Iniciar nuevos proyectos** - requiere crear un directorio manualmente, inicializar git, escribir un archivo de instrucciones (AGENTS.md o CLAUDE.md) y elegir un modelo
- **Sin gestión de proyectos** - no hay forma de ver proyectos inactivos, ni renombrar, mover o eliminar proyectos sin romper el historial

**claude-mux soluciona la brecha de gestión de sesiones.** Envuelve Claude Code en tmux para que las sesiones persistan, las restaura automáticamente tras fallos y reinicios (siempre que tengas el inicio de sesión automático activado), inyecta un prompt de sistema para que Claude gestione sus propias sesiones, y enruta los comandos slash a través de tmux para que funcionen sobre Remote Control. Una vez que una sesión está activa, gestionas todo hablando con Claude - en la terminal o en la app móvil.

## Qué puedes hacer en una sesión de claude-mux

- **Sobrevive a fallos y reinicios** - las sesiones se restauran automáticamente cuando vuelves a iniciar sesión y retoman la última conversación. Un `/exit` limpio o un apagado mantiene la sesión detenida; una sesión que falla en bucle se detiene y se marca en lugar de reiniciarse sin fin.
- **Gestionar cualquier sesión desde cualquier sesión** - iniciar, detener, reiniciar, listar y compactar proyectos usando lenguaje natural
- **Acceder a todo desde cualquier lugar** - cada sesión tiene Remote Control habilitado, así que la app móvil de Claude, la app de escritorio o cualquier cliente remoto es una interfaz completa
- **Cambiar modelos y modos de permisos** - di "cambia a Haiku" o "cambia a modo plan" y Claude lo gestiona, incluso sobre Remote Control
- **Crear nuevos proyectos** - "crea un nuevo proyecto llamado my-app" configura el directorio, git, un AGENTS.md a partir de una plantilla y lanza una sesión. Las plantillas permiten reutilizar instrucciones entre proyectos.
- **Enviar comandos slash sobre Remote Control** - Claude enruta `/model`, `/compact`, `/clear` y otros comandos slash a la sesión activa, evitando una [limitación conocida](https://github.com/anthropics/claude-code/issues/30674). RC se reconecta automáticamente tras `/compact` mediante un hook `PreCompact`.
- **Detección de actualizaciones de Claude Code** - cuando cambia el binario `claude` (tras `brew upgrade` o una actualización de npm), las sesiones en ejecución muestran un aviso para reiniciar y cargar el nuevo binario; el aviso persiste entre prompts hasta que reinicias, así que un turno perdido no lo pierde
- **Preservar historial de conversación** - renombrar, mover y reiniciar proyectos preservan el historial de conversación automáticamente
- **Organizar proyectos** - ocultar, renombrar, mover, eliminar y proteger proyectos desde cualquier sesión
- **Soporte multi-cuenta de GitHub** - detecta alias SSH en `~/.ssh/config` y los inyecta en las sesiones para que Claude use la cuenta correcta por proyecto
- **AGENTS.md como archivo de instrucciones del proyecto** - `AGENTS.md` es el único archivo real, leído por Claude Code y Codex CLI. Di "migra a AGENTS.md" para convertir un árbol existente desde `CLAUDE.md` (primero un informe, nada se confirma en git). Requiere Claude Code 2.1.277 o posterior; las versiones anteriores mantienen `CLAUDE.md`. Gemini CLI solo lo lee si `~/.gemini/settings.json` contiene `"context": {"fileName": ["AGENTS.md"]}`.
- **Funciona en cualquier idioma** - los comandos conversacionales se infieren por intención, no por palabras clave

## Hablando con Claude

Así es como usas claude-mux día a día. Cada sesión se inyecta con comandos para que Claude pueda gestionar sesiones, cambiar modelos, enviar comandos slash y crear nuevos proyectos - todo desde dentro de la conversación. No necesitas recordar flags de CLI.

```
Di: "estado"
Reporta nombre de sesión, modelo, modo de permisos, uso de contexto y lista todas las sesiones

Di: "listar sesiones activas"
Muestra todas las sesiones en ejecución con su estado

Di: "listar sesiones inactivas"
Muestra solo los proyectos inactivos

Di: "listar sesiones detenidas"
Muestra solo las sesiones detenidas

Di: "inicia una sesión para mi proyecto api-server"
Inicia la sesión por nombre; no hace nada si ya está en ejecución

Di: "crea un nuevo proyecto llamado mobile-app usando la plantilla web"
Crea el directorio del proyecto, inicializa git, aplica la plantilla, lanza una sesión

Di: "cambia esta sesión a Haiku"
Resuelve la familia al último ID concreto y se envía /model claude-haiku-4-5 a sí mismo

Di: "compacta la sesión api-server"
Envía /compact a la sesión api-server

Di: "reinicia la sesión web-dashboard"
Detiene y relanza la sesión, preservando el contexto de conversación

Di: "reinicia esta sesión desde cero"
Pide confirmación, luego reinicia con una conversación nueva - sin reanudar, sin contexto previo

Di: "mata la sesión api-server"
Pide confirmación, luego borra la conversación y la detiene; el siguiente inicio es una conversación nueva, no una reanudación

Di: "termina esta sesión"
Primero guarda el trabajo sin terminar y el siguiente paso, pide confirmación (y si hay algo sin guardar), luego reinicia desde cero

Di: "cambia la sesión api-server a modo plan"
Reinicia la sesión con modo de permisos plan

Di: "cambia esta sesión a modo yolo"
Cambia a modo bypassPermissions vía Shift+Tab - sin reinicio necesario

Di: "¿en qué modo está esta sesión?"
Reporta el modo de permisos actual (default, acceptEdits, plan, bypassPermissions)

Di: "cambia esta sesión a Opus"
Resuelve la familia al último ID concreto y se envía /model claude-opus-4-8 a sí mismo

Di: "limpia esta sesión"
Pide confirmación, luego se envía /clear a sí mismo, reiniciando la conversación

Di: "oculta este proyecto"
Escribe .claudemux-ignore para que el proyecto se excluya de los listados -L

Di: "protege esta sesión"
Escribe .claudemux-protected y establece el marcador tmux - el apagado ahora requiere --force

Di: "¿está protegida esta sesión?"
Verifica .claudemux-protected en la carpeta del proyecto y reporta

Di: "elimina el proyecto old-prototype"
Confirma en el chat, luego mueve la carpeta del proyecto a la papelera del sistema

Di: "renombra este proyecto a my-new-name"
Detiene la sesión, renombra la carpeta, migra el historial de conversación, reinicia

Di: "guarda esto como plantilla con nombre web"
Copia AGENTS.md (o CLAUDE.md) a ~/.claude-mux/templates/web.md

Di: "revisa la migración a agents" / "migra a AGENTS.md"
Reporta (solo lectura) qué archivos CLAUDE.md pueden pasar a AGENTS.md; tras la confirmación los renombra en todo el árbol y reinicia las sesiones en ejecución bajo el directorio base

Di: "consejo"
Muestra un consejo - el mismo consejo todo el día, o aleatorio si TIP_MODE=random está configurado

Di: "activar consejos" / "desactivar consejos"
Activa o desactiva el consejo del día en todos los proyectos

Di: "actualizar claude-mux"
Advierte que todas las sesiones se reiniciarán, pide confirmación, luego actualiza y reinicia

Di: "detener todas las sesiones"
Cierra ordenadamente todas las sesiones gestionadas

Di: "ayuda"
Muestra la lista completa de comandos conversacionales
```

**Estos comandos funcionan en cualquier idioma.** Si escribes el equivalente en inglés, japonés, hebreo o cualquier otro idioma, Claude infiere la intención y ejecuta el comando correspondiente.

**Escribe `help` dentro de cualquier sesión para ver la lista completa de comandos.**

## Más

- [Referencia CLI](../docs/CLI.md) - referencia completa de comandos para scripting y automatización
- [Guía](../docs/GUIDE.md) - configuración, detalles de sesión, internos y solución de problemas
- [Opciones de instalación](../docs/INSTALL.md) - Homebrew, instalación manual, configuración de LaunchAgent
- [FAQ](../docs/FAQ.md) - preguntas frecuentes sobre claude-mux
- [Problemas conocidos](../docs/ISSUES.md) - bugs abiertos, funcionalidades planeadas y problemas resueltos
- [Registro de cambios](../CHANGELOG.md) - qué cambió en cada versión
