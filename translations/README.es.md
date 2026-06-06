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

- **Las sesiones mueren** cuando cierras la terminal
- **El contexto de conversación** no se reanuda automáticamente
- **Sin base de operaciones** - nada se ejecuta cuando tomas tu teléfono a menos que hayas dejado algo abierto
- **Remote Control requiere una sesión activa** - no puedes iniciar una desde RC
- **Los comandos slash no funcionan en sesiones RC** - no hay cambio de modelo, compactación ni cambios de modo de permisos
- **Iniciar nuevos proyectos** - requiere crear un directorio manualmente, inicializar git, escribir un CLAUDE.md y elegir un modelo
- **Sin gestión de proyectos** - no hay forma de ver proyectos inactivos, ni renombrar, mover o eliminar proyectos sin romper el historial

**claude-mux soluciona la brecha de gestión de sesiones.** Envuelve Claude Code en tmux para que las sesiones persistan, inyecta un prompt de sistema para que Claude gestione sus propias sesiones, y enruta los comandos slash a través de tmux para que funcionen sobre Remote Control. Una vez que una sesión está activa, gestionas todo hablando con Claude - en la terminal o en la app móvil.

## Qué puedes hacer en una sesión de claude-mux

- **Gestionar cualquier sesión desde cualquier sesión** - iniciar, detener, reiniciar, listar y compactar proyectos usando lenguaje natural
- **Acceder a todo desde cualquier lugar** - cada sesión tiene Remote Control habilitado, así que la app móvil de Claude, la app de escritorio o cualquier cliente remoto es una interfaz completa
- **Cambiar modelos y modos de permisos** - di "cambia a Haiku" o "cambia a modo plan" y Claude lo gestiona, incluso sobre Remote Control
- **Crear nuevos proyectos** - "crea un nuevo proyecto llamado my-app" configura el directorio, git, CLAUDE.md y lanza una sesión. Las plantillas de CLAUDE.md permiten reutilizar instrucciones entre proyectos
- **Mantener sesiones vivas entre reinicios** - una sesión home opcional se lanza al iniciar sesión y permanece activa; todas las sesiones reanudan su última conversación automáticamente
- **Enviar comandos slash sobre Remote Control** - Claude enruta `/model`, `/compact`, `/clear` y otros comandos slash a la sesión activa, evitando una [limitación conocida](https://github.com/anthropics/claude-code/issues/30674)
- **Preservar historial de conversación** - renombrar, mover y reiniciar proyectos preservan el historial de conversación automáticamente
- **Organizar proyectos** - ocultar, renombrar, mover, eliminar y proteger proyectos desde cualquier sesión
- **Soporte multi-cuenta de GitHub** - detecta alias SSH en `~/.ssh/config` y los inyecta en las sesiones para que Claude use la cuenta correcta por proyecto
- **Soporte multi-CLI-coder** - crea automáticamente symlinks `AGENTS.md` y `GEMINI.md` para que Codex CLI, Gemini CLI y otros compartan instrucciones
- **Funciona en cualquier idioma** - los comandos conversacionales se infieren por intención, no por palabras clave

## Hablando con Claude

Así es como usas claude-mux día a día. Cada sesión se inyecta con comandos para que Claude pueda gestionar sesiones, cambiar modelos, enviar comandos slash y crear nuevos proyectos - todo desde dentro de la conversación. No necesitas recordar flags de CLI.

```
Tú: "estado"
Claude: reporta nombre de sesión, modelo, modo de permisos, uso de contexto y lista todas las sesiones

Tú: "listar sesiones activas"
Claude: muestra todas las sesiones activas con su estado

Tú: "inicia una sesión para mi proyecto api-server"
Claude: lanza una sesión en ~/Claude/work/api-server

Tú: "crea un nuevo proyecto llamado mobile-app usando la plantilla web"
Claude: crea el directorio del proyecto, inicializa git, aplica la plantilla, lanza una sesión

Tú: "cambia esta sesión a Haiku"
Claude: envía /model haiku a sí mismo vía tmux

Tú: "compacta la sesión api-server"
Claude: envía /compact a la sesión api-server

Tú: "reinicia la sesión web-dashboard"
Claude: detiene y relanza la sesión, preservando el contexto de conversación

Tú: "cambia la sesión api-server a modo plan"
Claude: reinicia la sesión con modo de permisos plan

Tú: "cambia esta sesión a modo yolo"
Claude: cambia a modo bypassPermissions vía Shift+Tab - sin reinicio necesario

Tú: "¿en qué modo está esta sesión?"
Claude: reporta el modo de permisos actual (default, acceptEdits, plan, bypassPermissions)

Tú: "cambia esta sesión a Opus"
Claude: envía /model opus a sí mismo vía tmux

Tú: "limpia esta sesión"
Claude: envía /clear a sí mismo, reiniciando la conversación

Tú: "oculta este proyecto"
Claude: escribe .claudemux-ignore para que el proyecto se excluya de los listados -L

Tú: "protege esta sesión"
Claude: escribe .claudemux-protected y establece el marcador tmux - el apagado ahora requiere --force

Tú: "¿está protegida esta sesión?"
Claude: verifica .claudemux-protected en la carpeta del proyecto y reporta

Tú: "elimina el proyecto old-prototype"
Claude: confirma en el chat, luego mueve la carpeta del proyecto a la papelera del sistema

Tú: "renombra este proyecto a my-new-name"
Claude: detiene la sesión, renombra la carpeta, migra el historial de conversación, reinicia

Tú: "guarda esto como plantilla con nombre web"
Claude: copia CLAUDE.md a ~/.claude-mux/templates/web.md

Tú: "consejo"
Claude: muestra un consejo - el mismo consejo todo el día, o aleatorio si TIP_MODE=random está configurado

Tú: "activar consejos" / "desactivar consejos"
Claude: activa o desactiva el consejo del día en todos los proyectos

Tú: "actualizar claude-mux"
Claude: advierte que todas las sesiones se reiniciarán, pide confirmación, luego actualiza y reinicia

Tú: "detener todas las sesiones"
Claude: cierra ordenadamente todas las sesiones gestionadas

Tú: "ayuda"
Claude: muestra la lista completa de comandos conversacionales
```

**Estos comandos funcionan en cualquier idioma.** Si escribes el equivalente en inglés, japonés, hebreo o cualquier otro idioma, Claude infiere la intención y ejecuta el comando correspondiente.

**Escribe `help` dentro de cualquier sesión para ver la lista completa de comandos.**

## Más

- [Referencia CLI](../docs/CLI.md) - referencia completa de comandos para scripting y automatización
- [Guía](../docs/guide.md) - configuración, detalles de sesión, internos y solución de problemas
- [Opciones de instalación](../docs/INSTALL.md) - Homebrew, instalación manual, configuración de LaunchAgent
- [FAQ](../docs/FAQ.md) - preguntas frecuentes sobre claude-mux
- [Problemas conocidos](../docs/ISSUES.md) - bugs abiertos, funcionalidades planeadas y problemas resueltos
- [Registro de cambios](../CHANGELOG.md) - qué cambió en cada versión
