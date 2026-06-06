# FAQ

[English](../docs/FAQ.md) · **Español** · [Français](FAQ.fr.md) · [Deutsch](FAQ.de.md) · [Português](FAQ.pt-BR.md) · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · [עברית](FAQ.he.md) · [العربية](FAQ.ar.md) · [हिन्दी](FAQ.hi.md)

## ¿Qué es claude-mux?

Un script de shell que envuelve Claude Code en tmux para sesiones persistentes. Las sesiones sobreviven al cierre de terminales, reanudan el contexto de conversación al reiniciar, y son accesibles desde la app móvil de Claude vía Remote Control. Todo se gestiona hablando con Claude dentro de una sesión.

## ¿Funciona en Linux?

Todavía no. Solo macOS (Apple Silicon e Intel). El soporte para Linux está planeado para v2.0. El instalador se ejecuta en Linux pero omite la configuración del LaunchAgent e imprime una nota. El binario en sí funciona, pero aún no hay un servicio systemd ni un mecanismo equivalente de inicio automático.

## ¿Qué es la sesión home?

La sesión home es una sesión de Claude de propósito general que vive en tu directorio base (`~/Claude` por defecto). Cuando `LAUNCHAGENT_MODE=home` (el valor por defecto), se lanza automáticamente al iniciar sesión y permanece activa todo el día. Está **protegida** por defecto, lo que significa que `--shutdown home` se niega a detenerla sin `--force`.

Usa la sesión home como tu punto de entrada siempre disponible desde la app móvil de Claude. Desde ahí puedes listar proyectos, iniciar otras sesiones, gestionar la configuración y hacer trabajo general que no pertenece a un proyecto específico.

## ¿Qué es Remote Control?

Remote Control (RC) es una funcionalidad de Claude Code que permite conectarse a una sesión de Claude activa desde la app móvil de Claude o Claude Desktop. claude-mux lanza cada sesión con `--remote-control` habilitado, así que todas las sesiones aparecen en la lista de RC automáticamente. Una vez conectado, hablas con Claude de la misma forma que en una terminal. claude-mux también evita las limitaciones de RC como que los comandos slash no funcionen nativamente, enrutándolos a través de tmux.

## ¿Qué son los modos de permisos?

Claude Code tiene cuatro modos de permisos que controlan cuánta autonomía tiene Claude:

| Modo | Comportamiento |
|------|----------------|
| `default` | Claude pregunta antes de ejecutar comandos o editar archivos |
| `acceptEdits` | Claude aplica ediciones automáticamente pero pregunta antes de comandos de shell |
| `plan` | Claude solo puede leer y planificar, sin escrituras ni comandos |
| `bypassPermissions` | Claude ejecuta todo sin preguntar (requiere confirmación en el primer lanzamiento) |

Configura el valor por defecto para todos los proyectos vía `DEFAULT_PERMISSION_MODE` en config. Cambia una sesión activa diciendo "cambia esta sesión a modo plan" (o cualquier nombre de modo). "yolo" es un alias para `bypassPermissions`.

Cambiar a `bypassPermissions` desde otro modo usa la navegación Shift+Tab y no requiere reinicio. Cambiar de `bypassPermissions` a otro modo requiere reinicio, que claude-mux gestiona automáticamente.

## ¿Cómo reinicio una sesión?

Tres opciones, según lo que necesites:

- **Limpiar** ("limpia esta sesión"): envía `/clear` a la sesión. Borra el historial de conversación y empieza de nuevo. La sesión sigue activa.
- **Compactar** ("compacta esta sesión"): envía `/compact` a la sesión. Resume la conversación en un contexto más corto, liberando la ventana de contexto. El historial se preserva en forma comprimida.
- **Reiniciar** ("reinicia esta sesión"): detiene Claude y lo relanza con `claude -c`, que reanuda la última conversación. Usa esto cuando necesites un proceso limpio (ej. después de cambiar modos de permisos o cuando Claude está atascado).

## ¿Qué son las plantillas?

Las plantillas son archivos CLAUDE.md reutilizables almacenados en `~/.claude-mux/templates/`. Cuando creas un nuevo proyecto con `-n`, la plantilla por defecto (o una que especifiques con `--template NAME`) se copia al proyecto como su CLAUDE.md.

Crear una plantilla: "guarda esto como plantilla con nombre web" (copia el CLAUDE.md del proyecto actual a `~/.claude-mux/templates/web.md`).

Usar una plantilla: `claude-mux -n ~/proyectos/my-app --template web` o desde una sesión: "crea un nuevo proyecto llamado my-app usando la plantilla web".

Listar plantillas: "listar plantillas" o `claude-mux --list-templates`.

## ¿Cómo funciona el consejo del día?

Un hook `UserPromptSubmit` de Claude Code en el `.claude/settings.local.json` de cada proyecto llama a `claude-mux --on-prompt` en cada prompt. El primer prompt del día inyecta un consejo en la conversación; los prompts posteriores de ese día no inyectan nada. El estado es por sesión, almacenado en `~/.claude-mux/tip-state/<session_id>.json`, así que cada sesión activa muestra el consejo una vez al día. Como el hook inyecta en el contexto (no un hook Stop, cuya salida solo va al transcript), el consejo es visible en la conversación y en Remote Control.

Los consejos están habilitados por defecto (`TIP_OF_DAY=true`). Alterna con "activar consejos" o "desactivar consejos" dentro de cualquier sesión. `TIP_MODE=daily` muestra el mismo consejo todo el día; `TIP_MODE=random` elige un consejo aleatorio.

El comando `--tip` siempre funciona independientemente de la puerta diaria (y de `TIP_OF_DAY`), así que puedes decir "consejo" en cualquier momento.

## ¿Puedo usar esto con múltiples cuentas de GitHub?

Sí. claude-mux detecta entradas `Host github.com-*` en `~/.ssh/config` y las inyecta en el prompt de sistema de cada sesión. Claude sabe qué alias SSH están disponibles y puede usar el correcto al configurar remotos de git.

Ejemplo de configuración de `~/.ssh/config`:

```
Host github.com-work
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_work

Host github.com-personal
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_personal
```

Claude entonces sabrá usar `git@github.com-work:org/repo.git` para repos de trabajo y `git@github.com-personal:user/repo.git` para los personales.

## ¿Dónde se almacena el estado?

| Ubicación | Qué contiene |
|-----------|--------------|
| `~/.claude-mux/config` | Configuración del usuario (se carga como bash) |
| `~/.claude-mux/templates/` | Archivos de plantilla CLAUDE.md |
| `~/.claude-mux/tip-state/<session_id>.json` | Fecha del consejo por sesión + límite de avisos de actualización |
| `~/.claude-mux/.update-check` | Resultado cacheado de verificación de versión |
| `~/.claude-mux/.update-checking` | Bloqueo durante la verificación de actualización en segundo plano |
| `~/Library/Logs/claude-mux.log` | Archivo de log (configurable vía `LOG_DIR`) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | Plist del LaunchAgent (generado por `--install`) |
| `.claudemux-protected` (por proyecto) | Marca una sesión como protegida contra el apagado |
| `.claudemux-ignore` (por proyecto) | Oculta un proyecto de los listados |

Los archivos marcadores (`.claudemux-*`) viven en el directorio raíz de cada proyecto y viajan con la carpeta al renombrar, mover y sincronizar. Se agregan automáticamente al `.gitignore`.

El historial de conversación lo gestiona Claude Code, almacenado en `~/.claude/projects/`.

## ¿Qué pasa con la actualización automática si hago fork de claude-mux?

La verificación de actualizaciones y el comando `--update` tienen hardcodeado `pereljon/claude-mux` como el repo de GitHub. Si haces fork, las verificaciones de actualización seguirán comparando contra la versión upstream, y `--update` sobreescribirá el binario de tu fork con el de upstream. Configura `UPDATE_CHECK=false` en `~/.claude-mux/config` para deshabilitarlo, o cambia la URL del repo en las funciones `check_for_update()` y `do_update()` del script.

## ¿Cómo instalo vía Homebrew?

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

Actualiza con `brew upgrade claude-mux`. Nota: si instalaste vía Homebrew, `--update` delega a `brew upgrade` automáticamente.

## ¿En qué se diferencia de `claude --worktree --tmux`?

`claude --worktree --tmux` crea una sesión tmux para un worktree de git aislado, diseñado para tareas de codificación en paralelo. claude-mux gestiona sesiones persistentes para tus directorios de proyecto reales, con Remote Control habilitado, inyección de prompt de sistema para autogestión, reanudación de conversación y gestión del ciclo de vida de sesiones. Resuelven problemas diferentes.

## ¿En qué se diferencia de Claude Cowork Dispatch?

Dispatch lanza tareas desde la app de escritorio de Claude, pero requiere que la app esté ejecutándose y no está vinculado a un proyecto específico. claude-mux gestiona sesiones persistentes vinculadas a proyectos que sobreviven reinicios y son accesibles desde cualquier lugar vía Remote Control - sin necesidad de la app de escritorio.

## ¿Por qué las sesiones muestran "Not logged in"?

Esto ocurre en el primer lanzamiento si el llavero de macOS está bloqueado, lo cual es común cuando el LaunchAgent inicia antes de que desbloquees el llavero después de iniciar sesión. Arréglalo ejecutando `security unlock-keychain` en una terminal normal, luego conéctate a cualquier sesión (`claude-mux -t <nombre>`) y ejecuta `/login` para completar el flujo de autenticación del navegador. Después, reinicia todas las sesiones y recogerán la credencial almacenada.

## ¿Pueden múltiples terminales conectarse a la misma sesión?

Sí. Este es el comportamiento estándar de tmux. Ejecutar `claude-mux` en un directorio que ya tiene una sesión activa se conecta a ella. Múltiples terminales ven el mismo contenido de sesión en tiempo real.

## ¿Cómo detengo la sesión home permanentemente?

El LaunchAgent tiene `KeepAlive: true`, así que matar la sesión home dispara un reinicio en unos 60 segundos. Para detenerla permanentemente, deshabilita el LaunchAgent:

```bash
claude-mux --install --launchagent-mode none
```

## ¿Qué significa el mensaje "Session ready!"?

Cuando una sesión inicia o reinicia, claude-mux envía un prompt `Ready?` después de que Claude termine de cargar. La inyección le dice a Claude que responda con "Session ready!" y nada más. Esto confirma que la sesión está viva y que la inyección del prompt de sistema funciona. Puedes ignorarlo.

## ¿Cómo oculto un proyecto de los listados?

Di "oculta este proyecto" dentro de cualquier sesión, o ejecuta `claude-mux --hide mi-proyecto`. Esto crea un archivo marcador `.claudemux-ignore`. El proyecto no aparecerá en la salida de `claude-mux -L`. Para ver proyectos ocultos: `claude-mux -L --hidden`. Para mostrar: "muestra este proyecto" o `claude-mux --show mi-proyecto`.

## ¿Cómo desinstalo claude-mux?

```bash
claude-mux --uninstall
```

Esto elimina los hooks de consejos y las reglas de permisos de todos los proyectos, descarga el LaunchAgent, y opcionalmente elimina `~/.claude-mux/`. Reporta la ruta del binario para que lo puedas eliminar manualmente (o `brew uninstall claude-mux` si lo instalaste vía Homebrew).

## ¿Los comandos slash funcionan sobre Remote Control?

No nativamente. Claude Code no soporta comandos slash (`/model`, `/clear`, etc.) en sesiones RC. claude-mux evita esto inyectando cada sesión con `claude-mux -s` para que Claude pueda enviar comandos slash a sí mismo vía tmux. Solo di "cambia a Haiku" o "compacta esta sesión" y Claude lo gestiona.

## No puedo seleccionar texto en una sesión

Mantén presionada **Option** (macOS) o **Shift** (terminales Linux/Windows) mientras haces clic y arrastras. Esto evita la captura de ratón de tmux y copia la selección al portapapeles del sistema. No se necesitan cambios de configuración.

## ¿Qué idiomas son compatibles para los comandos conversacionales?

Todos. Las frases de activación ("help", "status", "list sessions", etc.) funcionan en cualquier idioma. Claude infiere la intención del lenguaje natural del usuario y ejecuta el comando correspondiente. El README también está traducido a 12 idiomas.
