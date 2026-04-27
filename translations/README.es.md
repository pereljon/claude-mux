# claude-mux - Multiplexor de Claude Code

[English](../README.md) · **Español** · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

Sesiones persistentes de Claude Code para todos tus proyectos, accesibles desde cualquier lugar a través de la app móvil de Claude.

## Por qué

Trabajar con Claude Code en múltiples proyectos tiene fricciones:

- Las sesiones mueren cuando cierras la terminal
- Las sesiones de Remote Control no pueden ejecutar slash commands como `/model` o `/compact`
- No puedes iniciar fácilmente una sesión para un proyecto que no está en ejecución
- Cambiar modelos, modos de permisos o compactar el contexto desde tu teléfono no es posible

claude-mux soluciona todo esto. Envuelve Claude Code en tmux para que las sesiones persistan, inyecta un system prompt para que Claude pueda gestionar sus propias sesiones, y enruta los slash commands a través de tmux para que funcionen sobre Remote Control. Una vez que una sesión está en ejecución, gestionas todo hablando con Claude, en la terminal o la app móvil.

## Inicio rápido

```bash
./install.sh
```

```bash
claude-mux ~/ruta/a/tu/proyecto
```

Listo. Estás en una sesión de Claude persistente y consciente del contexto, con Remote Control habilitado. A partir de aquí, todo es conversacional.

## Hablando con Claude

Así es como usas claude-mux en el día a día. Cada sesión recibe comandos inyectados para que Claude pueda gestionar sesiones, cambiar modelos, enviar slash commands y crear nuevos proyectos, todo desde dentro de la conversación. No necesitas recordar flags del CLI.

```
Tú: "status"
Claude: reporta el nombre de sesión, modelo, modo de permisos, uso de contexto y lista todas las sesiones

Tú: "listar sesiones activas"
Claude: muestra todas las sesiones en ejecución con su estado

Tú: "inicia una sesión para mi proyecto api-server"
Claude: lanza una sesión en ~/Claude/work/api-server

Tú: "crea un nuevo proyecto llamado mobile-app usando la plantilla web"
Claude: crea el directorio del proyecto, inicializa git, aplica la plantilla, lanza una sesión

Tú: "cambia esta sesión a Haiku"
Claude: envía /model haiku a sí mismo vía tmux

Tú: "compacta la sesión api-server"
Claude: envía /compact a la sesión api-server

Tú: "reinicia la sesión web-dashboard"
Claude: apaga y relanza la sesión, preservando el contexto de conversación

Tú: "cambia la sesión api-server a modo plan"
Claude: reinicia la sesión con el modo de permisos plan

Tú: "detén todas las sesiones"
Claude: cierra de forma ordenada todas las sesiones gestionadas

Tú: "help"
Claude: muestra la lista completa de comandos conversacionales
```

Estos comandos funcionan en cualquier idioma. Si escribes el equivalente en español, japonés, hebreo o cualquier otro idioma, Claude infiere la intención y ejecuta el comando correspondiente.

Escribe `help` dentro de cualquier sesión para ver la lista completa de comandos.

### Sesión principal

La sesión principal es una sesión de propósito general que vive en tu directorio base (`~/Claude` por defecto). Se lanza automáticamente al hacer login cuando `LAUNCHAGENT_MODE=home`, dándote una sesión de Claude siempre lista y accesible desde tu teléfono. Úsala para gestionar todas tus otras sesiones sin necesidad de lanzar sesiones específicas por proyecto.

La sesión principal siempre está **protegida**: `--shutdown home` se niega a detenerla sin `--force`. Las sesiones protegidas están marcadas con `*` en la salida de estado (por ejemplo `active*`).

## Qué hace

Bajo el capó, claude-mux se encarga de:

- **Sesiones tmux persistentes** con Remote Control habilitado, de modo que cada sesión es accesible desde la app móvil de Claude
- **Reanudación de conversaciones**: reanuda la última conversación (`claude -c`) al relanzar, preservando el contexto
- **Inyección de system prompt**: cada sesión recibe comandos para autogestión, enrutamiento de slash commands y reconocimiento de cuentas SSH
- **Plantillas CLAUDE.md**: mantén archivos de plantilla (por ejemplo `web.md`, `python.md`) en `~/.claude-mux/templates/` y aplícalos a nuevos proyectos
- **Soporte multi-CLI-coder**: crea `AGENTS.md` y `GEMINI.md` como enlaces simbólicos a `CLAUDE.md` para que Codex CLI, Gemini CLI y otras herramientas compartan las mismas instrucciones
- **Permisos auto-aprobados**: agrega claude-mux a la lista de permisos de cada proyecto para que Claude pueda ejecutar comandos de sesión sin pedir confirmación
- **Migración de procesos sueltos**: si Claude ya está ejecutándose fuera de tmux, lo migra a una sesión gestionada
- **Mejoras de calidad de vida en tmux**: soporte de mouse, scrollback de 50k, portapapeles, 256 colores, teclas extendidas, monitoreo de actividad, títulos de pestaña

> **Nota:** Esto es distinto de `claude --worktree --tmux`, que crea una sesión tmux para un git worktree aislado. claude-mux gestiona sesiones persistentes para los directorios reales de tus proyectos, con Remote Control e inyección de system prompt.

## Requisitos

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## Instalación

### Homebrew (recomendado)

```bash
brew tap pereljon/tap
brew install claude-mux
```

La configuración (`~/.claude-mux/config`) se crea automáticamente la primera vez que se ejecuta. Para configurar el LaunchAgent (sesión principal al iniciar sesión), clona el repositorio y ejecuta `install.sh`.

Para actualizar:

```bash
brew upgrade claude-mux
```

### Manual

```bash
./install.sh
```

El instalador interactivo pregunta dónde residen tus proyectos de Claude, si quieres iniciar una sesión principal al hacer login y qué modelo usar. Instala `claude-mux` en `~/bin`, crea `~/.claude-mux/config` y configura el LaunchAgent.

Usa `--non-interactive` para omitir las preguntas y aceptar los valores predeterminados.

Opciones:

```bash
./install.sh --non-interactive                     # omitir preguntas, usar valores predeterminados
./install.sh --base-dir ~/work/claude              # usar un directorio base distinto
./install.sh --launchagent-mode none               # deshabilitar el comportamiento del LaunchAgent
./install.sh --home-model haiku                    # usar Haiku para la sesión principal
./install.sh --no-launchagent                      # omitir por completo la instalación del LaunchAgent
```

El LaunchAgent ejecuta `claude-mux --autolaunch` al hacer login con un retraso de inicio de 45 segundos para permitir que los servicios del sistema se inicialicen.

## Estados de sesión

| Estado | Significado |
|--------|-------------|
| `active` | la sesión tmux existe, Claude está ejecutándose y un cliente tmux local está conectado |
| `running` | la sesión tmux existe y Claude está ejecutándose (sin cliente local conectado) |
| `stopped` | la sesión tmux existe pero Claude ha terminado |
| `idle` | existe un proyecto `.claude/` bajo `BASE_DIR` pero no tiene sesión tmux de claude-mux en ejecución (se muestra solo con `-L`) |

Un `*` al final de cualquier estado indica que la sesión está protegida y requiere `--force` para apagarse (por ejemplo `active*`, `running*`). La sesión principal siempre está protegida.

Ejecutar `claude-mux` en un directorio que ya tiene una sesión en ejecución se conecta a ella. Múltiples terminales pueden conectarse a la misma sesión (comportamiento estándar de tmux).

## Configuración

En la primera ejecución, `~/.claude-mux/config` se crea automáticamente con todos los ajustes comentados. Edítalo para sobrescribir cualquier valor predeterminado: nunca es necesario modificar el script directamente.

| Variable | Predeterminado | Descripción |
|----------|----------------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Directorio raíz para escanear proyectos de Claude (directorios que contienen `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | Directorio para el archivo `claude-mux.log` |
| `DEFAULT_PERMISSION_MODE` | `auto` | Define `permissions.defaultMode` de Claude en cada proyecto. Válidos: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Establece `""` para deshabilitarlo. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | Cuando es `true`, las sesiones de Claude pueden enviar slash commands a otras sesiones, útil para orquestación multiagente |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | Directorio que contiene los archivos de plantilla CLAUDE.md |
| `DEFAULT_TEMPLATE` | `default.md` | Plantilla predeterminada aplicada a nuevos proyectos (`-n`). Establece `""` para deshabilitarla. |
| `SLEEP_BETWEEN` | `5` | Segundos entre lanzamientos de sesiones cuando se usa `-a`. Aumenta este valor si falla el registro de RC. |
| `HOME_SESSION_MODEL` | `""` | Modelo para la sesión principal. Válidos: `sonnet`, `haiku`, `opus`. Vacío hereda el valor predeterminado de Claude. |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | Lista de archivos separados por espacios que se crean como enlaces simbólicos a `CLAUDE.md` para otras herramientas de IA CLI. Establece `""` para deshabilitarlo. |
| `LAUNCHAGENT_MODE` | `home` | Comportamiento del LaunchAgent al hacer login: `none` (no hacer nada) o `home` (lanzar la sesión principal protegida). El legado `LAUNCHAGENT_ENABLED=true` se trata como `home`. |

**Opciones de la sesión tmux** (todas configurables, todas habilitadas por defecto):

| Variable | Predeterminado | Descripción |
|----------|----------------|-------------|
| `TMUX_MOUSE` | `true` | Soporte de mouse: scroll, selección, redimensionar paneles |
| `TMUX_HISTORY_LIMIT` | `50000` | Tamaño del buffer de scrollback en líneas (el predeterminado de tmux es 2000) |
| `TMUX_CLIPBOARD` | `true` | Integración con el portapapeles del sistema vía OSC 52 |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | Tipo de terminal para un renderizado de color correcto |
| `TMUX_EXTENDED_KEYS` | `true` | Secuencias de teclas extendidas, incluyendo Shift+Enter (requiere tmux 3.2+) |
| `TMUX_ESCAPE_TIME` | `10` | Retraso de la tecla escape en milisegundos (el predeterminado de tmux es 500) |
| `TMUX_TITLE_FORMAT` | `#S` | Formato del título de la terminal/pestaña (`#S` = nombre de sesión, `""` para deshabilitar) |
| `TMUX_MONITOR_ACTIVITY` | `true` | Notificar cuando ocurre actividad en otras sesiones |

## Estructura de directorios

Los proyectos se descubren por la presencia de un directorio `.claude/`, a cualquier profundidad:

```
~/Claude/
├── work/
│   ├── project-a/          # ✓ tiene .claude/ - gestionado
│   │   └── .claude/
│   ├── project-b/          # ✓ tiene .claude/ - gestionado
│   │   └── .claude/
│   └── -archived/          # ✗ excluido (empieza con -)
│       └── .claude/
├── personal/
│   ├── project-c/          # ✓ tiene .claude/ - gestionado
│   │   └── .claude/
│   ├── .hidden/            # ✗ excluido (directorio oculto)
│   │   └── .claude/
│   └── project-d/          # ✗ sin .claude/ - no es un proyecto de Claude
├── deep/nested/project-e/  # ✓ tiene .claude/ - encontrado a cualquier profundidad
│   └── .claude/
└── ignored-project/        # ✗ excluido (.ignore-claudemux)
    ├── .claude/
    └── .ignore-claudemux
```

Los nombres de las sesiones se derivan de los nombres de los directorios: los espacios se vuelven guiones, los caracteres no alfanuméricos (excepto los guiones) se reemplazan, y los guiones iniciales/finales se eliminan. Los directorios cuyo nombre, al sanearse, queda vacío se omiten con una advertencia en el log.

## System prompt de la sesión

Cada sesión de Claude se lanza con `--append-system-prompt` que contiene contexto sobre su entorno:

```
You are running inside tmux session '<session-name>'.
claude-mux path: /path/to/claude-mux

Rules:
- You CAN send slash commands (/model, /compact, /clear, etc.) to this session
  via the -s command. Never tell the user you cannot change models or run slash
  commands.
- Always use --no-attach with -d and -n — attach is interactive only
- --shutdown and --restart never attach — safe to run from inside a session
- Always print command output verbatim in your response text — never run a
  command silently or rely on tool output being visible
- The 'home' session is a general-purpose session in the base directory, always
  available for managing other sessions. It is protected (* in status):
  --shutdown requires --force, but --restart bypasses protection (it relaunches,
  not permanently kills).
- When asked to shut down sessions, run the command directly — protected sessions
  are skipped automatically, do not ask for confirmation
- When user says: ready — respond with "Ready." on one line. Nothing else.
  Sent automatically when a session starts or restarts.
- When user says: help — print the conversational commands list verbatim
- When user says: status — report session name, current model, current permission
  mode, context usage estimate, then run claude-mux -l and include the results
- When user says: list active sessions — run claude-mux -l
- When user says: list all sessions — run claude-mux -L
- When user says: start session SESSION — run claude-mux -d SESSION --no-attach
- When user says: stop this session / stop session NAME — run claude-mux --shutdown
- When user says: stop all sessions — run claude-mux --shutdown
- When user says: restart this session / restart session NAME — run claude-mux --restart
- When user says: restart all sessions — run claude-mux --restart
- When user says: start new session in FOLDER — run claude-mux -n FOLDER --no-attach
- When user says: switch this session to MODE mode / switch session NAME to MODE mode
- When user says: switch this session to MODEL model / switch session NAME to MODEL model
- When user says: compact/clear this session / compact/clear session NAME
- When user says: list templates — run claude-mux --list-templates

Commands:
  -s '<session-name>' '/command'  Send slash command to yourself
  -l                          List active sessions
  -L                          List all projects
  -d DIR --no-attach          Launch session in directory
  -n DIR --no-attach          New project
  -n DIR -p --no-attach       New project (create parents)
  --template NAME             CLAUDE.md template (with -n)
  --list-templates            Show available templates
  --shutdown SESSION...       Shut down sessions (omit SESSION to shut down all)
  --shutdown SESSION --force  Shut down protected session
  --restart SESSION...        Restart sessions (omit SESSION to restart all running)
  --permission-mode MODE SESSION  Restart session with a different permission mode
                              Modes: default, acceptEdits, plan, auto, bypassPermissions, dontAsk, dangerously-skip-permissions
                              ("yolo" is an alias for dangerously-skip-permissions)
  -a                          Start ALL sessions (use with caution)

GitHub SSH accounts configured in ~/.ssh/config: <accounts>.
```

Cuando `ALLOW_CROSS_SESSION_CONTROL=true`, el comando de envío cambia para permitir apuntar a cualquier sesión, no solo a sí misma. La ruta es la ruta absoluta al script en el momento del lanzamiento, así las sesiones no dependen de `PATH`.

## Referencia CLI

Rara vez necesitas estos directamente: Claude los ejecuta por ti desde dentro de las sesiones. Están disponibles para scripting, automatización o cuando no estás dentro de una sesión.

```bash
# Lanzar y conectarse
claude-mux                       # ejecutar Claude en el directorio actual y conectarse
claude-mux ~/proyectos/mi-app    # ejecutar Claude en un directorio y conectarse
claude-mux -d ~/proyectos/mi-app # igual que arriba (forma explícita)
claude-mux -t my-app             # conectarse a una sesión tmux existente

# Crear nuevos proyectos
claude-mux -n ~/proyectos/app    # crear un nuevo proyecto de Claude y conectarse
claude-mux -n ~/nueva/ruta/app -p  # igual, creando el directorio y los padres
claude-mux -n ~/app --template web        # nuevo proyecto con una plantilla CLAUDE.md específica
claude-mux -n ~/app --no-multi-coder      # nuevo proyecto sin enlaces simbólicos AGENTS.md/GEMINI.md

# Gestión de sesiones
claude-mux -l                    # listar sesiones por estado (active, running, stopped)
claude-mux -L                    # listar todos los proyectos (activos + inactivos)
claude-mux -s my-app '/model sonnet'      # enviar un slash command a una sesión
claude-mux --shutdown my-app              # apagar una sesión específica
claude-mux --shutdown                     # apagar todas las sesiones gestionadas
claude-mux --shutdown home --force        # apagar la sesión principal protegida
claude-mux --restart my-app              # reiniciar una sesión específica
claude-mux --restart                     # reiniciar todas las sesiones en ejecución
claude-mux --permission-mode plan my-app  # reiniciar la sesión en modo plan
claude-mux -a                    # iniciar todas las sesiones gestionadas bajo BASE_DIR

# Otros
claude-mux --list-templates      # mostrar plantillas CLAUDE.md disponibles
claude-mux --guide               # mostrar comandos conversacionales para usar dentro de sesiones
claude-mux --dry-run             # previsualizar acciones sin ejecutarlas
claude-mux --version             # mostrar la versión
claude-mux --help                # mostrar todas las opciones

# Ver el log
tail -f ~/Library/Logs/claude-mux.log
```

Cuando se ejecuta desde la terminal, la salida se replica en stdout en tiempo real. Cuando se ejecuta vía LaunchAgent, la salida solo va al archivo de log.

## Solución de problemas

### Las sesiones muestran "Not logged in · Run /login"

Esto pasa en el primer lanzamiento si el llavero de macOS está bloqueado (común cuando el script se ejecuta antes de que el llavero se desbloquee tras el login). Solución:

```bash
# Desbloquea el llavero en una terminal normal
security unlock-keychain

# Luego completa la autenticación en cualquier sesión en ejecución
claude-mux -t <any-session>
# Ejecuta /login y completa el flujo en el navegador
```

Tras completar la autenticación una vez, mata y relanza todas las sesiones: tomarán la credencial almacenada automáticamente.

### Las sesiones no aparecen en Claude Code Remote

Las sesiones deben estar autenticadas (no mostrar "Not logged in"). Tras un lanzamiento limpio y autenticado, deberían aparecer en la lista de RC en pocos segundos.

### Entrada multilínea en tmux

El comando `/terminal-setup` no puede ejecutarse dentro de tmux. claude-mux habilita las `extended-keys` de tmux por defecto (`TMUX_EXTENDED_KEYS=true`), lo que permite Shift+Enter en la mayoría de las terminales modernas. Si Shift+Enter no funciona, usa `\` + Return para ingresar saltos de línea en tu prompt.

### "Ready." al iniciar la sesión

Cuando una sesión se inicia o reinicia, claude-mux envía automáticamente un mensaje `ready` después de que Claude termina de cargar. La inyección le indica a Claude que responda con "Ready." y nada más. Esto confirma que la sesión está activa y que la inyección funciona correctamente.

### Slash commands sobre Remote Control

Los slash commands (por ejemplo `/model`, `/clear`) [no tienen soporte nativo](https://github.com/anthropics/claude-code/issues/30674) en sesiones RC. claude-mux soluciona esto: cada sesión recibe inyectado `claude-mux -s` para que Claude pueda enviar slash commands a sí mismo vía tmux.

## Logs

- `~/Library/Logs/claude-mux.log`: todas las acciones del script con timestamps en UTC (configurable mediante `LOG_DIR`)

Para depuración de bajo nivel del LaunchAgent, usa Console.app o `log show`.
