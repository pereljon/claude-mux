# claude-mux - Multiplexor de Claude Code

[English](../README.md) · **Español** · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

Sesiones persistentes de Claude Code para todos tus proyectos, accesibles desde cualquier lugar a travs de la app mvil de Claude. ***Gestionado por Claude!***

## Por qu

Remote Control promete Claude Code desde cualquier lugar, pero sin gestin de sesiones, es una interfaz de segunda clase incluso desde Claude Desktop:

- Las sesiones mueren cuando cierras la terminal y el contexto de la conversacin no se reanuda automticamente
- No hay base de operaciones: nada est en ejecucin cuando coges el telfono a menos que hayas dejado algo abierto
- Si una sesin no est en ejecucin, Remote Control es intil: no puedes alcanzar un proyecto ni iniciar uno
- Incluso en una sesin RC activa, los slash commands no funcionan: sin cambio de modelo, compactacin ni cambios de modo de permisos
- Iniciar un nuevo proyecto requiere crear manualmente un directorio, inicializar git, escribir un CLAUDE.md, establecer un modo de permisos y elegir un modelo, nada de lo cual se puede hacer desde RC
- Gestionar mltiples proyectos implica mltiples lanzamientos manuales de terminal sin visin general de qu est en ejecucin ni en qu estado

claude-mux soluciona todo esto. Envuelve Claude Code en tmux para que las sesiones persistan, inyecta un system prompt para que Claude pueda gestionar sus propias sesiones, y enruta los slash commands a travs de tmux para que funcionen sobre Remote Control. Una vez que una sesin est en ejecucin, gestionas todo hablando con Claude, en la terminal o la app mvil.

## Inicio rpido

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

Luego inicia una sesin:

```bash
cd ~/ruta/a/tu/proyecto
claude-mux
```

O:

```bash
claude-mux ~/ruta/a/tu/proyecto
```

Listo. Ests en una sesin de Claude persistente y consciente del contexto, con Remote Control habilitado. A partir de aqu, todo es conversacional.

## Hablando con Claude

As es como usas claude-mux en el da a da. Cada sesin recibe comandos inyectados para que Claude pueda gestionar sesiones, cambiar modelos, enviar slash commands y crear nuevos proyectos, todo desde dentro de la conversacin. No necesitas recordar flags del CLI.

```
T: "status"
Claude: reporta el nombre de sesin, modelo, modo de permisos, uso de contexto y lista todas las sesiones

T: "listar sesiones activas"
Claude: muestra todas las sesiones en ejecucin con su estado

T: "inicia una sesin para mi proyecto api-server"
Claude: lanza una sesin en ~/Claude/work/api-server

T: "crea un nuevo proyecto llamado mobile-app usando la plantilla web"
Claude: crea el directorio del proyecto, inicializa git, aplica la plantilla, lanza una sesin

T: "cambia esta sesin a Haiku"
Claude: enva /model haiku a s mismo va tmux

T: "compacta la sesin api-server"
Claude: enva /compact a la sesin api-server

T: "reinicia la sesin web-dashboard"
Claude: apaga y relanza la sesin, preservando el contexto de conversacin

T: "cambia la sesin api-server a modo plan"
Claude: reinicia la sesin con el modo de permisos plan

T: "cambia esta sesin a modo yolo"
Claude: cambia a modo bypassPermissions va Shift+Tab, sin necesidad de reinicio

T: "en qu modo est esta sesin"
Claude: reporta el modo de permisos actual (default, acceptEdits, plan, bypassPermissions)

T: "cambia esta sesin a Opus"
Claude: enva /model opus a s mismo va tmux

T: "limpia esta sesin"
Claude: enva /clear a s mismo, reiniciando la conversacin

T: "oculta este proyecto"
Claude: escribe .claudemux-ignore para que el proyecto se excluya de los listados -L

T: "protege esta sesin"
Claude: escribe .claudemux-protected y establece el marcador en tmux; ahora --shutdown requiere --force

T: "est protegida esta sesin"
Claude: comprueba si existe .claudemux-protected en la carpeta del proyecto y reporta

T: "elimina el proyecto old-prototype"
Claude: confirma en el chat, luego mueve la carpeta del proyecto a la papelera del sistema

T: "renombra este proyecto a my-new-name"
Claude: detiene la sesin, renombra la carpeta, migra el historial de conversacin, reinicia

T: "guarda esto como plantilla con nombre web"
Claude: copia CLAUDE.md a ~/.claude-mux/templates/web.md

T: "tip"
Claude: muestra un consejo; el mismo todo el da, o aleatorio si TIP_MODE=random est configurado

T: "activar tips" / "desactivar tips"
Claude: registra o elimina el hook de tip del da en todos los proyectos

T: "actualizar claude-mux"
Claude: avisa que todas las sesiones se reiniciarn, pide confirmacin, luego actualiza y reinicia

T: "detn todas las sesiones"
Claude: cierra de forma ordenada todas las sesiones gestionadas

T: "help"
Claude: muestra la lista completa de comandos conversacionales
```

Estos comandos funcionan en cualquier idioma. Si escribes el equivalente en espaol, japons, hebreo o cualquier otro idioma, Claude infiere la intencin y ejecuta el comando correspondiente.

Escribe `help` dentro de cualquier sesin para ver la lista completa de comandos.

### Sesin principal

La sesin principal es una sesin de propsito general que vive en tu directorio base (`~/Claude` por defecto). Se lanza automticamente al hacer login cuando `LAUNCHAGENT_MODE=home`, dndote una sesin de Claude siempre lista y accesible desde tu telfono. sala para gestionar todas tus otras sesiones sin necesidad de lanzar sesiones especficas por proyecto.

La sesin principal est **protegida** por defecto: `--shutdown home` se niega a detenerla sin `--force`. La proteccin est activada por el marcador `.claudemux-protected` en `$BASE_DIR`, creado por `claude-mux --install`. Las sesiones protegidas muestran `protected` en la columna de estado; la sesin que ejecut el comando se marca con `>` en la columna de nombre.

## Qu hace

Bajo el cap, claude-mux se encarga de:

- **Sesiones tmux persistentes** con Remote Control habilitado, de modo que cada sesin es accesible desde la app mvil de Claude
- **Reanudacin de conversaciones**: reanuda la ltima conversacin (`claude -c`) al relanzar, preservando el contexto
- **Inyeccin de system prompt**: cada sesin recibe comandos para autogestin, enrutamiento de slash commands y reconocimiento de cuentas SSH
- **Plantillas CLAUDE.md**: mantiene archivos de plantilla (por ejemplo `web.md`, `python.md`) en `~/.claude-mux/templates/` y los aplica a nuevos proyectos
- **Soporte multi-CLI-coder**: crea `AGENTS.md` y `GEMINI.md` como enlaces simblicos a `CLAUDE.md` para que Codex CLI, Gemini CLI y otras herramientas compartan las mismas instrucciones
- **Permisos auto-aprobados**: agrega claude-mux a la lista de permisos de cada proyecto para que Claude pueda ejecutar comandos de sesin sin pedir confirmacin
- **Migracin de procesos sueltos**: si Claude ya est ejecutndose fuera de tmux, lo migra a una sesin gestionada
- **Mejoras de calidad de vida en tmux**: soporte de mouse, scrollback de 50k, portapapeles, 256 colores, teclas extendidas, monitoreo de actividad, ttulos de pestaa

> **Nota:** Esto es distinto de `claude --worktree --tmux`, que crea una sesin tmux para un git worktree aislado. claude-mux gestiona sesiones persistentes para los directorios reales de tus proyectos, con Remote Control e inyeccin de system prompt.

## Requisitos

- macOS (Apple Silicon o Intel)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## Instalacin

### curl (recomendado)

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

Descarga el binario, lo instala en `~/bin`, lo agrega al `PATH` y ejecuta la configuracin interactiva. Funciona en macOS y Linux (Linux: el paso de LaunchAgent se omite).

Para actualizar:

```bash
claude-mux --update     # funciona desde dentro de cualquier sesin, o desde la terminal
```

### Homebrew (alternativa para macOS)

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

Para actualizar:

```bash
brew upgrade claude-mux
```

### Manual

```bash
./install.sh
```

`install.sh` copia el binario a `~/bin` y lo aade al `PATH`. Despus, ejecuta:

```bash
claude-mux --install
```

La configuracin interactiva pregunta dnde residen tus proyectos de Claude, si quieres iniciar una sesin principal al hacer login y qu modelo usar. Crea `~/.claude-mux/config` e instala el LaunchAgent.

Usa `--non-interactive` para omitir las preguntas y aceptar los valores predeterminados.

Opciones:

```bash
claude-mux --install --non-interactive                     # omitir preguntas, usar valores predeterminados
claude-mux --install --base-dir ~/work/claude              # usar un directorio base distinto
claude-mux --install --launchagent-mode none               # deshabilitar el comportamiento del LaunchAgent
claude-mux --install --home-model haiku                    # usar Haiku para la sesin principal
claude-mux --install --no-launchagent                      # omitir por completo la instalacin del LaunchAgent
```

El LaunchAgent ejecuta `claude-mux --autolaunch` al hacer login con un retraso de inicio de 45 segundos para permitir que los servicios del sistema se inicialicen.

## Estados de sesin

| Estado | Significado |
|--------|-------------|
| `running` | la sesin tmux existe y Claude est ejecutndose |
| `protected` | igual que `running`, pero la sesin est protegida: `--shutdown` necesita `--force` para detenerla |
| `stopped` | la sesin tmux existe pero Claude ha terminado |
| `idle` | existe un proyecto `.claude/` bajo `BASE_DIR` pero no tiene sesin tmux de claude-mux en ejecucin (se muestra solo con `-L`) |

Un prefijo `>` en el nombre de la sesin (p. ej. `> home`) marca la sesin que ejecut el comando de lista.

Ejecutar `claude-mux` en un directorio que ya tiene una sesin en ejecucin se conecta a ella. Mltiples terminales pueden conectarse a la misma sesin (comportamiento estndar de tmux).

## Marcadores de proyecto

El estado por proyecto se almacena en archivos marcadores en la raz del proyecto, no en una configuracin central. Los marcadores usan el prefijo `.claudemux-` y se aaden automticamente al `.gitignore` cuando se crean en un proyecto con seguimiento git.

| Marcador | Significado | CLI |
|----------|-------------|-----|
| `.claudemux-protected` | La sesin queda protegida al arrancar: `--shutdown` requiere `--force` | `--protect` / `--unprotect` |
| `.claudemux-ignore` | El proyecto se oculta de los listados de `claude-mux -L` | `--hide` / `--show` |

```bash
claude-mux --hide                    # ocultar el proyecto de la sesin actual de los listados -L
claude-mux --hide my-project         # ocultar el proyecto de una sesin especfica
claude-mux --show my-project         # mostrar de nuevo un proyecto
claude-mux --protect                 # proteger esta sesin de apagados accidentales
claude-mux --unprotect               # eliminar la proteccin
claude-mux -L --hidden               # listar solo los proyectos ocultos
claude-mux --delete my-project       # mover la carpeta del proyecto a la papelera del sistema (macOS)
```

Los marcadores viajan con la carpeta del proyecto cuando se renombra o mueve. Un nico patrn en `.gitignore` (`.claudemux-*`) cubre todos los marcadores actuales y futuros.

## Configuracin

`~/.claude-mux/config` se crea mediante `claude-mux --install` (o en la primera ejecucin de cualquier comando si no existe config). Edtalo para sobrescribir cualquier valor predeterminado: nunca es necesario modificar el script directamente.

| Variable | Predeterminado | Descripcin |
|----------|----------------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Directorio raz para escanear proyectos de Claude (directorios que contienen `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | Directorio para el archivo `claude-mux.log` |
| `DEFAULT_PERMISSION_MODE` | `auto` | Define `permissions.defaultMode` de Claude en cada proyecto. Vlidos: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Establece `""` para deshabilitarlo. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | Cuando es `true`, las sesiones de Claude pueden enviar slash commands a otras sesiones, til para orquestacin multiagente |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | Directorio que contiene los archivos de plantilla CLAUDE.md |
| `DEFAULT_TEMPLATE` | `default.md` | Plantilla predeterminada aplicada a nuevos proyectos (`-n`). Establece `""` para deshabilitarla. |
| `SLEEP_BETWEEN` | `5` | Segundos entre lanzamientos de sesiones cuando se usa `-a`. Aumenta este valor si falla el registro de RC. |
| `HOME_SESSION_MODEL` | `""` | Modelo para la sesin principal. Vlidos: `sonnet`, `haiku`, `opus`. Vaco hereda el valor predeterminado de Claude. |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | Lista de archivos separados por espacios que se crean como enlaces simblicos a `CLAUDE.md` para otras herramientas de IA CLI. Establece `""` para deshabilitarlo. |
| `LAUNCHAGENT_MODE` | `home` | Comportamiento del LaunchAgent al hacer login: `none` (no hacer nada) o `home` (lanzar la sesin principal protegida). El legado `LAUNCHAGENT_ENABLED=true` se trata como `home`. |

**Opciones de la sesin tmux** (todas configurables, todas habilitadas por defecto):

| Variable | Predeterminado | Descripcin |
|----------|----------------|-------------|
| `TMUX_MOUSE` | `true` | Soporte de mouse: scroll, seleccin, redimensionar paneles |
| `TMUX_HISTORY_LIMIT` | `50000` | Tamao del buffer de scrollback en lneas (el predeterminado de tmux es 2000) |
| `TMUX_CLIPBOARD` | `true` | Integracin con el portapapeles del sistema va OSC 52 |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | Tipo de terminal para un renderizado de color correcto |
| `TMUX_EXTENDED_KEYS` | `true` | Secuencias de teclas extendidas, incluyendo Shift+Enter (requiere tmux 3.2+) |
| `TMUX_ESCAPE_TIME` | `10` | Retraso de la tecla escape en milisegundos (el predeterminado de tmux es 500) |
| `TMUX_TITLE_FORMAT` | `#S` | Formato del ttulo de la terminal/pestaa (`#S` = nombre de sesin, `""` para deshabilitar) |
| `TMUX_MONITOR_ACTIVITY` | `true` | Notificar cuando ocurre actividad en otras sesiones |

## Estructura de directorios

Los proyectos se descubren por la presencia de un directorio `.claude/`, a cualquier profundidad:

```
~/Claude/
 work/
    project-a/          #  tiene .claude/ - gestionado
       .claude/
    project-b/          #  tiene .claude/ - gestionado
       .claude/
    -archived/          #  excluido (empieza con -)
        .claude/
 personal/
    project-c/          #  tiene .claude/ - gestionado
       .claude/
    .hidden/            #  excluido (directorio oculto)
       .claude/
    project-d/          #  sin .claude/ - no es un proyecto de Claude
 deep/nested/project-e/ #  tiene .claude/ - encontrado a cualquier profundidad
    .claude/
 ignored-project/       #  excluido (.claudemux-ignore)
     .claude/
     .claudemux-ignore
```

Los nombres de las sesiones se derivan de los nombres de los directorios: los espacios se convierten en guiones, los caracteres no alfanumricos (excepto los guiones) se reemplazan, y los guiones iniciales/finales se eliminan. Los directorios cuyo nombre, al sanearse, queda vaco se omiten con una advertencia en el log.

## System prompt de la sesin

Cada sesin de Claude se lanza con `--append-system-prompt` que contiene contexto sobre su entorno:

```
You are running inside tmux session '<session-name>'. claude-mux path: /path/to/claude-mux
claude-mux version: <version>
[Update available: <new-version> (found <date>). Tell the user and suggest they say "update claude-mux" to update.]

Reference lookups (run on demand if you need information not covered by trigger rules):
  claude-mux --guide          -> conversational commands list (used for "help")
  claude-mux --commands       -> full CLI reference
  claude-mux --config-help    -> config options with defaults, types, descriptions
  claude-mux --list-templates -> available CLAUDE.md templates

Rules:
- Always run claude-mux using the absolute path shown above (claude-mux path:). The bare command may not be in PATH.
- You CAN send slash commands (/model, /compact, /clear, etc.) to this session via the -s command.
- Always use --no-attach with -d and -n -- attach is interactive only
- --shutdown and --restart never attach -- safe to run from inside a session; do NOT add --no-attach to these commands
- Always print command output verbatim in your response text -- if a command fails, report the error
- When command output contains <assistant-must-display> tags, include the COMPLETE content verbatim
- The 'home' session is the always-available session in the base directory. It is protected (shows 'protected' in status): --shutdown requires --force, but --restart bypasses protection. Protection is driven by the .claudemux-protected marker.
- Disambiguate 'home': 'home session' means the claude-mux session named home; 'home folder' means ~/
- When asked to shut down sessions, run the command directly -- protected sessions are skipped automatically
- Use claude-mux for ALL session management. Never use raw tmux, ls, or other shell commands for session management.
- Don't guess at claude-mux flags. If you need information not in the trigger rules, run the relevant lookup.
- When user says: ready -- respond with "Session ready!" on one line. Nothing else.
- When user says: help -- run claude-mux --guide and print the output verbatim
- When user says: status -- report session name, model, permission mode, context estimate, then run claude-mux -l
- When user says: list active sessions -- run claude-mux -l
- When user says: list all sessions -- run claude-mux -L
- When user says: list hidden projects -- run claude-mux -L --hidden
- When user says: start session SESSION -- run claude-mux -d SESSION --no-attach
- When user says: stop this session / stop session NAME -- run claude-mux --shutdown
- When user says: stop all sessions -- run claude-mux --shutdown
- When user says: restart this session / restart session NAME -- run claude-mux --restart
- When user says: restart all sessions -- run claude-mux --restart
- When user says: start new session in FOLDER -- run claude-mux -n FOLDER --no-attach
- When user says: switch this session to MODE mode / switch session NAME to MODE mode
- When user says: switch this session to MODEL model / switch session NAME to MODEL model
- When user says: compact/clear this session / compact/clear session NAME
- When user says: update claude-mux -- warn sessions will restart, get confirmation, run --update then --restart
- When user says: hide this project / hide PROJECT -- run claude-mux --hide
- When user says: show this project / show PROJECT / unhide PROJECT -- run claude-mux --show
- When user says: protect this session / protect SESSION -- run claude-mux --protect
- When user says: unprotect this session / unprotect SESSION -- run claude-mux --unprotect
- When user says: is this hidden / is this protected -- check for .claudemux-ignore or .claudemux-protected
- When user says: delete this project / delete PROJECT -- confirm in chat first, then run claude-mux --delete SESSION --yes
- When user says: list templates -- run claude-mux --list-templates
- When user says: enable tips / turn on tips -- run claude-mux --enable-tips
- When user says: disable tips / turn off tips -- run claude-mux --disable-tips
- These trigger phrases work in any language.

Additional capabilities (run claude-mux --commands for full syntax):
  - Attach interactively to a session (-t -- user-only, never from inside a session)
  - Start all sessions at once (-a)
  - New project with a CLAUDE.md template (-n DIR --template NAME, -p for parent dirs)
  - Force-shutdown a protected session (--shutdown SESSION --force)
  - Hide/show projects (--hide / --show)
  - Protect/unprotect sessions (--protect / --unprotect)
  - Move a project to trash (--delete SESSION -- macOS; honors protection unless --force)
  - Enable/disable tip-of-the-day hook (--enable-tips / --disable-tips)
  - Show all config options (--config-help)
  - Run interactive setup or reconfigure (--install)
  - Remove all hooks and permissions (--uninstall)
  - Update claude-mux (--update)

Self-targeting send: claude-mux -s '<session-name>' '/command' sends slash commands to yourself.
GitHub SSH accounts configured in ~/.ssh/config: <accounts>.
```

La sesin principal recibe contexto adicional: una descripcin de su rol, adems de triggers de autogestin para leer/editar la configuracin y las plantillas. Cuando `ALLOW_CROSS_SESSION_CONTROL=true`, el comando de envo puede apuntar a cualquier sesin, no solo a s misma. La ruta es la ruta absoluta al script en el momento del lanzamiento, as las sesiones no dependen de `PATH`.

## Referencia CLI

Rara vez necesitas estos directamente: Claude los ejecuta por ti desde dentro de las sesiones. Estn disponibles para scripting, automatizacin o cuando no ests dentro de una sesin.

```bash
# Lanzar y conectarse
claude-mux                       # ejecutar Claude en el directorio actual y conectarse
claude-mux ~/proyectos/mi-app   # ejecutar Claude en un directorio y conectarse
claude-mux -d ~/proyectos/mi-app # igual que arriba (forma explcita)
claude-mux -t my-app             # conectarse a una sesin tmux existente

# Crear nuevos proyectos
claude-mux -n ~/proyectos/app    # crear un nuevo proyecto de Claude y conectarse
claude-mux -n ~/nueva/ruta/app -p  # igual, creando el directorio y los padres
claude-mux -n ~/app --template web        # nuevo proyecto con una plantilla CLAUDE.md especfica
claude-mux -n ~/app --no-multi-coder      # nuevo proyecto sin enlaces simblicos AGENTS.md/GEMINI.md

# Gestin de sesiones
claude-mux -l                    # listar sesiones por estado (active, running, stopped)
claude-mux -L                    # listar todos los proyectos (activos + inactivos)
claude-mux -L --hidden           # listar solo los proyectos ocultos
claude-mux -s my-app '/model sonnet'      # enviar un slash command a una sesin
claude-mux --shutdown my-app              # apagar una sesin especfica
claude-mux --shutdown                     # apagar todas las sesiones gestionadas
claude-mux --shutdown home --force        # apagar la sesin principal protegida
claude-mux --restart my-app              # reiniciar una sesin especfica
claude-mux --restart                     # reiniciar todas las sesiones en ejecucin
claude-mux --permission-mode plan my-app  # reiniciar la sesin en modo plan
claude-mux -a                    # iniciar todas las sesiones gestionadas bajo BASE_DIR

# Marcadores de proyecto (todos los comandos usan nombres de sesin, no rutas)
claude-mux --hide                # ocultar el proyecto de la sesin actual de los listados -L
claude-mux --hide my-project     # ocultar un proyecto especfico por nombre de sesin
claude-mux --show my-project     # mostrar de nuevo un proyecto
claude-mux --protect             # proteger esta sesin de apagados accidentales
claude-mux --unprotect           # eliminar la proteccin
claude-mux --delete my-project           # mover la carpeta del proyecto a la papelera del sistema (macOS)
claude-mux --delete my-project --yes     # lo mismo, sin confirmacin
claude-mux --rename my-project new-name  # renombrar directorio del proyecto
claude-mux --move my-project ~/Claude/work  # mover proyecto a un nuevo directorio padre

# Otros
claude-mux --list-templates      # mostrar plantillas CLAUDE.md disponibles
claude-mux --guide               # mostrar comandos conversacionales para usar dentro de sesiones
claude-mux --commands            # mostrar la referencia CLI completa
claude-mux --config-help         # mostrar todas las opciones de configuracin con valores predeterminados y descripciones
claude-mux --install             # configuracin interactiva: config + LaunchAgent
claude-mux --update              # actualizar a la ltima versin
claude-mux --dry-run             # previsualizar acciones sin ejecutarlas
claude-mux --version             # mostrar la versin
claude-mux --help                # mostrar todas las opciones

# Ver el log
tail -f ~/Library/Logs/claude-mux.log
```

Cuando se ejecuta desde la terminal, la salida se replica en stdout en tiempo real. Cuando se ejecuta va LaunchAgent, la salida solo va al archivo de log.

## Solucin de problemas

### Las sesiones muestran "Not logged in  Run /login"

Esto pasa en el primer lanzamiento si el llavero de macOS est bloqueado (comn cuando el script se ejecuta antes de que el llavero se desbloquee tras el login). Solucin:

```bash
# Desbloquea el llavero en una terminal normal
security unlock-keychain

# Luego completa la autenticacin en cualquier sesin en ejecucin
claude-mux -t <any-session>
# Ejecuta /login y completa el flujo en el navegador
```

Tras completar la autenticacin una vez, mata y relanza todas las sesiones: tomarn la credencial almacenada automticamente.

### Las sesiones no aparecen en Claude Code Remote

Las sesiones deben estar autenticadas (no mostrar "Not logged in"). Tras un lanzamiento limpio y autenticado, deberan aparecer en la lista de RC en pocos segundos.

### Entrada multilnea en tmux

El comando `/terminal-setup` no puede ejecutarse dentro de tmux. claude-mux habilita las `extended-keys` de tmux por defecto (`TMUX_EXTENDED_KEYS=true`), lo que permite Shift+Enter en la mayora de las terminales modernas. Si Shift+Enter no funciona, usa `\` + Return para ingresar saltos de lnea en tu prompt.

### "Session ready!" al iniciar la sesin

Cuando una sesin se inicia o reinicia, claude-mux enva automticamente un mensaje `Ready?` despus de que Claude termina de cargar. La inyeccin le indica a Claude que responda con "Session ready!" y nada ms. Esto confirma que la sesin est activa y que la inyeccin funciona correctamente.

### Slash commands sobre Remote Control

Los slash commands (por ejemplo `/model`, `/clear`) [no tienen soporte nativo](https://github.com/anthropics/claude-code/issues/30674) en sesiones RC. claude-mux soluciona esto: cada sesin recibe inyectado `claude-mux -s` para que Claude pueda enviar slash commands a s mismo va tmux.

## Logs

- `~/Library/Logs/claude-mux.log`: todas las acciones del script con timestamps en UTC (configurable mediante `LOG_DIR`)

Para depuracin de bajo nivel del LaunchAgent, usa Console.app o `log show`.

## Ms

- [FAQ](FAQ.es.md): preguntas frecuentes sobre claude-mux
- [Problemas conocidos](ISSUES.es.md): bugs abiertos, funcionalidades planificadas y problemas resueltos
- [Changelog](../CHANGELOG.md): cambios por versin
