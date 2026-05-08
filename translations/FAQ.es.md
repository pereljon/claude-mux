# FAQ

[English](../FAQ.md) · **Español** · [Français](FAQ.fr.md) · [Deutsch](FAQ.de.md) · [Português](FAQ.pt-BR.md) · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · [עברית](FAQ.he.md) · [العربية](FAQ.ar.md) · [हिन्दी](FAQ.hi.md)

## Qu es claude-mux?

Un script de shell que envuelve Claude Code en tmux para sesiones persistentes. Las sesiones sobreviven al cierre de la terminal, reanudan el contexto de conversacin al reiniciar y son accesibles desde la app mvil de Claude va Remote Control. Gestionas todo hablando con Claude dentro de una sesin.

## Funciona en Linux?

Todava no. Solo macOS (Apple Silicon e Intel). El soporte para Linux est planificado para v2.0. El instalador se ejecuta en Linux pero omite la configuracin de LaunchAgent y muestra una nota. El binario en s funciona, pero an no hay un servicio systemd ni un mecanismo equivalente de inicio automtico.

## Qu es la sesin principal?

La sesin principal es una sesin de Claude de propsito general que vive en tu directorio base (`~/Claude` por defecto). Cuando `LAUNCHAGENT_MODE=home` (el valor predeterminado), se lanza automticamente al hacer login y se mantiene activa todo el da. Est **protegida** por defecto, lo que significa que `--shutdown home` se niega a detenerla sin `--force`.

Usa la sesin principal como tu punto de entrada siempre disponible desde la app mvil de Claude. Desde ah puedes listar proyectos, iniciar otras sesiones, gestionar la configuracin y hacer trabajo general que no pertenece a un proyecto especfico.

## Qu es Remote Control?

Remote Control (RC) es una funcionalidad de Claude Code que te permite conectarte a una sesin de Claude en ejecucin desde la app mvil de Claude o Claude Desktop. claude-mux lanza cada sesin con `--remote-control` habilitado, de modo que todas las sesiones aparecen en la lista de RC automticamente. Una vez conectado, hablas con Claude de la misma forma que en una terminal. claude-mux tambin soluciona las limitaciones de RC como que los slash commands no funcionan de forma nativa, enrutndolos a travs de tmux.

## Qu son los modos de permisos?

Claude Code tiene cuatro modos de permisos que controlan cunta autonoma tiene Claude:

| Modo | Comportamiento |
|------|----------------|
| `default` | Claude pregunta antes de ejecutar comandos o editar archivos |
| `acceptEdits` | Claude aplica ediciones de archivos automticamente pero pregunta antes de ejecutar comandos de shell |
| `plan` | Claude solo puede leer y planificar, sin escrituras ni comandos |
| `bypassPermissions` | Claude ejecuta todo sin preguntar (requiere confirmacin en el primer lanzamiento) |

Establece el modo predeterminado para todos los proyectos mediante `DEFAULT_PERMISSION_MODE` en la configuracin. Cambia el modo de una sesin activa diciendo "cambia esta sesin a modo plan" (o cualquier nombre de modo). "yolo" es un alias para `bypassPermissions`.

Cambiar a `bypassPermissions` desde otro modo usa la navegacin con Shift+Tab y no requiere reinicio. Cambiar desde `bypassPermissions` a otro modo requiere un reinicio, que claude-mux gestiona automticamente.

## Cmo reinicio una sesin?

Tres opciones, segn lo que necesites:

- **Limpiar** ("limpia esta sesin"): enva `/clear` a la sesin. Borra el historial de conversacin y empieza de cero. La sesin sigue activa.
- **Compactar** ("compacta esta sesin"): enva `/compact` a la sesin. Resume la conversacin en un contexto ms corto, liberando la ventana de contexto. El historial se preserva en forma comprimida.
- **Reiniciar** ("reinicia esta sesin"): apaga Claude y lo relanza con `claude -c`, que reanuda la ltima conversacin. Usa esto cuando necesites un proceso limpio (por ejemplo, tras cambiar modos de permisos o cuando Claude est atascado).

## Qu son las plantillas?

Las plantillas son archivos CLAUDE.md reutilizables almacenados en `~/.claude-mux/templates/`. Cuando creas un nuevo proyecto con `-n`, la plantilla predeterminada (o la que especifiques con `--template NAME`) se copia al proyecto como su CLAUDE.md.

Crear una plantilla: "guarda esto como plantilla con nombre web" (copia el CLAUDE.md del proyecto actual a `~/.claude-mux/templates/web.md`).

Usar una plantilla: `claude-mux -n ~/proyectos/mi-app --template web` o desde dentro de una sesin: "crea un nuevo proyecto llamado mi-app usando la plantilla web".

Listar plantillas: "listar plantillas" o `claude-mux --list-templates`.

## Cmo funciona el tip del da?

Un hook Stop de Claude Code en el `.claude/settings.local.json` de cada proyecto llama a `claude-mux --tipotd` despus de cada turno de conversacin. El comando verifica si ya se mostr un tip hoy (va `~/.claude-mux/.tip-date`). Si es as, termina en unos 6ms. Si no, muestra un tip y registra la fecha de hoy.

Los tips estn habilitados por defecto (`TIP_OF_DAY=true`). Actvalo o desactvalo con "activar tips" o "desactivar tips" dentro de cualquier sesin. `TIP_MODE=daily` muestra el mismo tip todo el da; `TIP_MODE=random` elige un tip aleatorio por invocacin (con el hook Stop, esto significa un tip aleatorio por da debido a la compuerta diaria).

El comando `--tip` siempre funciona independientemente de la compuerta diaria, as que puedes decir "tip" en cualquier momento.

## Puedo usar esto con mltiples cuentas de GitHub?

S. claude-mux detecta entradas `Host github.com-*` en `~/.ssh/config` y las inyecta en el system prompt de cada sesin. Claude sabe qu alias SSH estn disponibles y puede usar el correcto al configurar repositorios remotos de git.

Ejemplo de configuracin `~/.ssh/config`:

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

Entonces Claude sabr usar `git@github.com-work:org/repo.git` para repositorios de trabajo y `git@github.com-personal:user/repo.git` para los personales.

## Dnde se almacena el estado?

| Ubicacin | Qu contiene |
|-----------|-------------|
| `~/.claude-mux/config` | Configuracin del usuario (se carga como bash) |
| `~/.claude-mux/templates/` | Archivos de plantilla CLAUDE.md |
| `~/.claude-mux/.tip-date` | Fecha del ltimo tip mostrado |
| `~/.claude-mux/.update-check` | Resultado cacheado de la verificacin de versin |
| `~/Library/Logs/claude-mux.log` | Archivo de log (configurable va `LOG_DIR`) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | Plist del LaunchAgent (generado por `--install`) |
| `.claudemux-protected` (por proyecto) | Marca una sesin como protegida contra apagados |
| `.claudemux-ignore` (por proyecto) | Oculta un proyecto de los listados |

Los archivos marcadores (`.claudemux-*`) viven en el directorio raz de cada proyecto y viajan con la carpeta cuando se renombra, mueve o sincroniza. Se aaden automticamente al `.gitignore`.

El historial de conversaciones lo gestiona Claude Code directamente, almacenado en `~/.claude/projects/`.

## Qu pasa con la actualizacin automtica si hago fork de claude-mux?

La verificacin de actualizaciones y el comando `--update` tienen codificado `pereljon/claude-mux` como repositorio de GitHub. Si haces fork, las verificaciones de actualizaciones seguirn comparando contra la versin publicada en upstream, y `--update` sobrescribir el binario de tu fork con el de upstream. Configura `UPDATE_CHECK=false` en `~/.claude-mux/config` para deshabilitarlo, o cambia la URL del repositorio en las funciones `check_for_update()` y `do_update()` del script.

## Cmo instalo va Homebrew?

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

Actualiza con `brew upgrade claude-mux`. Nota: si instalaste va Homebrew, `--update` delega automticamente a `brew upgrade`.

## En qu se diferencia de `claude --worktree --tmux`?

`claude --worktree --tmux` crea una sesin tmux para un git worktree aislado, diseado para tareas de codificacin en paralelo. claude-mux gestiona sesiones persistentes para los directorios reales de tus proyectos, con Remote Control habilitado, inyeccin de system prompt para autogestin, reanudacin de conversaciones y gestin del ciclo de vida de las sesiones. Resuelven problemas distintos.

## Por qu las sesiones muestran "Not logged in"?

Esto pasa en el primer lanzamiento si el llavero de macOS est bloqueado, lo cual es comn cuando el LaunchAgent se inicia antes de que desbloquees el llavero tras el login. Solucin: ejecuta `security unlock-keychain` en una terminal normal, luego conctate a cualquier sesin (`claude-mux -t <nombre>`) y ejecuta `/login` para completar el flujo de autenticacin en el navegador. Despus de eso, reinicia todas las sesiones y tomarn la credencial almacenada.

## Pueden conectarse mltiples terminales a la misma sesin?

S. Es el comportamiento estndar de tmux. Ejecutar `claude-mux` en un directorio que ya tiene una sesin activa se conecta a ella. Mltiples terminales ven el mismo contenido de la sesin en tiempo real.

## Cmo detengo la sesin principal permanentemente?

El LaunchAgent tiene `KeepAlive: true`, as que matar la sesin principal provoca un reinicio en unos 60 segundos. Para detenerla permanentemente, deshabilita el LaunchAgent:

```bash
claude-mux --install --launchagent-mode none
```

## Qu significa el mensaje "Session ready!"?

Cuando una sesin se inicia o reinicia, claude-mux enva un prompt `Ready?` despus de que Claude termina de cargar. La inyeccin le indica a Claude que responda con "Session ready!" y nada ms. Esto confirma que la sesin est activa y que la inyeccin del system prompt funciona. Puedes ignorarlo.

## Cmo oculto un proyecto de los listados?

Di "oculta este proyecto" dentro de cualquier sesin, o ejecuta `claude-mux --hide my-project`. Esto crea un archivo marcador `.claudemux-ignore`. El proyecto no aparecer en la salida de `claude-mux -L`. Para ver proyectos ocultos: `claude-mux -L --hidden`. Para mostrar de nuevo: "muestra este proyecto" o `claude-mux --show my-project`.

## Cmo desinstalo claude-mux?

```bash
claude-mux --uninstall
```

Esto elimina los hooks de tips y las reglas de permisos de todos los proyectos, descarga el LaunchAgent y opcionalmente elimina `~/.claude-mux/`. Muestra la ruta del binario para que puedas eliminarlo manualmente (o `brew uninstall claude-mux` si se instal va Homebrew).

## Funcionan los slash commands sobre Remote Control?

No de forma nativa. Claude Code no soporta slash commands (`/model`, `/clear`, etc.) en sesiones RC. claude-mux soluciona esto inyectando `claude-mux -s` en cada sesin para que Claude pueda enviar slash commands a s mismo va tmux. Solo di "cambia a Haiku" o "compacta esta sesin" y Claude se encarga.

## No puedo seleccionar texto en una sesin

Mantn presionado **Option** (macOS) o **Shift** (terminales Linux/Windows) mientras haces clic y arrastras. Esto ignora la captura de mouse de tmux y copia la seleccin al portapapeles del sistema. No se necesitan cambios de configuracin.

## Qu idiomas se soportan para los comandos conversacionales?

Todos. Las frases de activacin ("help", "status", "list sessions", etc.) funcionan en cualquier idioma. Claude infiere la intencin del lenguaje natural del usuario y ejecuta el comando correspondiente. El README tambin est traducido a 12 idiomas.
