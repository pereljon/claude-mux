# Resilio Sync: Guía de Acceso Remoto a Archivos

Notas sobre el uso de Resilio Sync para acceder a archivos en una computadora de casa o del trabajo desde dispositivos móviles y otras computadoras, sin usar servicios en la nube.

## Por Qué Esto Importa para los Usuarios de claude-mux

claude-mux mantiene tus sesiones de Claude Code activas y accesibles desde cualquier lugar mediante Remote Control - puedes hablar con Claude desde tu teléfono o cualquier dispositivo remoto. Pero RC te da acceso a la *sesión*, no a los *archivos*. Si Claude crea o modifica archivos en un proyecto, esos archivos quedan en tu computadora de escritorio.

Resilio Sync cierra esa brecha. Sincroniza tu carpeta de proyectos de Claude con tu dispositivo móvil y podrás leer resultados, revisar notas y abrir archivos justo al lado de la sesión RC, sin subir nada a un servicio en la nube.

## Qué Es

Resilio Sync es una herramienta de sincronización de archivos punto a punto (P2P). Los archivos se transfieren directamente entre tus dispositivos a través de la red. No hay servidor central, ni cuenta en la nube, ni suscripción mensual para uso personal.

Originalmente basado en el protocolo de sincronización de BitTorrent, ahora desarrollado por Resilio Inc. Software propietario (código cerrado).

## Cuándo Resilio Sync Es Una Buena Opción

- Acceso desde móvil a archivos en una computadora de escritorio (iOS, Android, además de macOS, Windows, Linux)
- Quieres mantener tus datos fuera de los servicios en la nube
- Tu conjunto de datos son muchos archivos pequeños (markdown, código, notas, configuraciones); P2P los maneja mejor que las nubes comerciales
- No te importa no tener un respaldo central (los pares son el respaldo)

## Cuándo Es Mejor Otra Opción

- Necesitas colaboración en tiempo real con varios editores sobre el mismo archivo
- Necesitas una interfaz web para acceder a los archivos desde cualquier navegador
- Necesitas calendario, contactos y colaboración de documentos integrados (considera Nextcloud)
- Necesitas que el acceso sin conexión en iOS sea 100% continuo (las restricciones de Apple en segundo plano limitan cualquier app de sincronización)
- La carpeta contiene repositorios git activos y quieres ejecutar operaciones de git en varios dispositivos (sincronizar `.git/` es riesgoso; ver más abajo)

## Costo

- **Sync Home (gratis)**: cubre el uso personal con una cantidad razonable de dispositivos
- **Sync Home Pro (~$60 USD una sola vez)**: elimina los límites de dispositivos y mejora la sincronización selectiva
- Existen niveles para empresas; el plan gratuito suele ser suficiente para uso personal

## Plataformas

Apps nativas para:
- macOS
- Windows
- Linux
- iOS
- Android

Empareja los dispositivos escaneando un código QR o compartiendo una clave de texto.

## Resumen de Configuración

1. Instala Resilio Sync en la computadora principal
2. **Solo macOS**: otorga Acceso Completo al Disco (ver más abajo) antes de agregar carpetas
3. **Importante**: configura la IgnoreList antes de agregar cualquier carpeta (ver más abajo)
4. Agrega la carpeta o las carpetas que realmente quieres compartir; no tu carpeta de inicio completa. Por lo general eliges una o unas pocas carpetas de nivel superior que contienen el contenido al que quieres acceso remoto. Para quienes hacen trabajo de IA / LLM, esto suele ser la carpeta de proyectos de IA (donde viven los prompts, notas, configuraciones, archivos de agentes y contenido de proyectos).
5. Elige el tipo de carpeta:
   - **Lectura y Escritura (sendreceive)**: cualquier par puede editar; los cambios se propagan al resto
   - **Solo Lectura**: los pares pueden leer pero no modificar
6. Instala Resilio Sync en los dispositivos móviles y secundarios
7. Escanea el código QR o ingresa la clave compartida para emparejar
8. Configura la sincronización selectiva en el móvil para controlar qué subcarpetas se descargan por defecto

## Otorgar Acceso Completo al Disco en macOS

En macOS moderno, la protección del sistema (TCC) bloquea por defecto que las apps lean muchas carpetas del usuario (Documentos, Escritorio, Descargas, iCloud, entre otras). Sin Acceso Completo al Disco, Resilio Sync puede parecer que funciona, pero falla silenciosamente al leer o sincronizar archivos en ubicaciones protegidas, o muestra los archivos como faltantes o vacíos en los dispositivos pares.

**Otórgalo una sola vez, antes de agregar carpetas:**

1. Abre **Ajustes del Sistema** > **Privacidad y Seguridad** > **Acceso Completo al Disco**
2. Haz clic en el botón **+** (puede que necesites desbloquear con Touch ID o contraseña)
3. Navega a `/Aplicaciones` y selecciona **Resilio Sync.app**
4. Confirma que el interruptor esté activado
5. Cierra Resilio Sync por completo (Cmd+Q o clic derecho en el ícono de la barra de menús y elige Salir) y vuelve a abrirlo para que el permiso tenga efecto

**Verifica que haya tomado efecto:**

- Agrega una carpeta de prueba desde Documentos o Escritorio
- Confirma que los archivos aparecen y los conteos coinciden con los dispositivos pares
- Si los archivos parecen faltar o la sincronización se queda detenida sin error, revisa otra vez la configuración de Acceso Completo al Disco

Es un paso de configuración por única vez. Sin él, vas a encontrar problemas confusos de sincronización parcial que es fácil diagnosticar erróneamente como errores de Resilio.

## Vincular Dispositivos Mediante Código QR

Una vez que el dispositivo principal tiene Resilio Sync instalado y la carpeta agregada, vincula los demás dispositivos así.

**En el dispositivo principal (Mac/Windows/Linux):**

1. En Resilio Sync, busca la carpeta sincronizada en la vista principal
2. Haz clic en el icono de compartir junto a la carpeta (suele decir "Share" o "Compartir"; también puedes usar el menú de tres puntos y elegir Compartir)
3. Aparece un diálogo con:
   - Un código QR
   - Una clave de compartición (cadena larga alfanumérica)
   - Un enlace para compartir (empieza con `https://link.resilio.com/`)
4. Elige el nivel de permisos para el par:
   - **Lectura y Escritura**: el par puede editar archivos; los cambios se propagan a todos los dispositivos
   - **Solo Lectura**: el par puede leer pero no modificar
   - **Propietario (Owner)**: control total, incluyendo cambiar los permisos de otros pares (rara vez necesario)

   Para la mayoría de los usos personales entre tus propios dispositivos, usa **Lectura y Escritura** para que cualquier dispositivo pueda editar y que los cambios fluyan de vuelta a los demás. Usa Solo Lectura únicamente cuando quieras que un par consuma contenido sin poder modificarlo (por ejemplo, una carpeta compartida donde una persona publica y los demás solo leen).
5. Opcional: pon una expiración a la clave o limita cuántos dispositivos pueden usarla
6. Mantén este diálogo abierto mientras escaneas desde el otro dispositivo

**En el dispositivo móvil (iOS/Android):**

1. Instala Resilio Sync desde la App Store o Play Store
2. Abre la app y acepta los avisos iniciales
3. Toca el botón **+** (arriba a la derecha en iOS, abajo a la derecha en Android)
4. Elige **Escanear código QR** (o **Agregar carpeta** > **Ingresar clave**)
5. Apunta la cámara al código QR en la pantalla del dispositivo principal
6. La app reconoce la compartición, pide una carpeta de destino en el dispositivo móvil e inicia la sincronización
7. Opcional: activa la **sincronización selectiva** para que el dispositivo muestre marcadores de archivos y solo descargue cuando los toques, ahorrando espacio

**En una segunda computadora de escritorio:**

1. Instala Resilio Sync
2. Haz clic en **+** en la vista principal y elige **Ingresar una clave o enlace**
3. Pega la clave de compartición o abre el enlace desde el dispositivo principal
4. Elige una carpeta local donde vivirá el contenido sincronizado
5. Confirma y Resilio comienza la sincronización inicial

**Verificar que la vinculación funcionó:**

- El nuevo dispositivo aparece en la pestaña **Peers** (pares) de la carpeta en el dispositivo principal
- Ambos dispositivos muestran cantidades de archivos coincidentes (después de completar la sincronización inicial)
- La vista de la carpeta en el dispositivo principal muestra un conteo de pares

**Compartir de forma segura:**

- Trata la clave de compartición, el código QR y el enlace como secretos. Cualquiera que tenga alguno puede unirse al recurso compartido con el nivel de permisos codificado en ellos.
- Usa Solo Lectura para los pares a los que quieres dar acceso de visualización sin permitir escritura.
- Usa claves con expiración cuando compartas con un par por un tiempo limitado.
- Si una clave pudo haberse filtrado, regenérala desde el diálogo de compartición; las claves viejas quedan revocadas.

## La Carpeta `.sync/`

Cada carpeta sincronizada recibe un directorio oculto `.sync/` que contiene:

- `ID`: identificador de la carpeta usado para emparejar pares. **Trátalo como información sensible**; cualquiera que tenga este ID puede unirse al recurso compartido.
- `IgnoreList`: patrones excluidos de la sincronización
- `StreamsList`: lista blanca para flujos alternativos, atributos extendidos y bifurcaciones de recursos
- `Archive`: versiones anteriores de archivos eliminados o modificados (versionado)
- `*.!sync`: archivos temporales de transferencias en curso

**No elimines ni muevas la carpeta `.sync/`**. Hacerlo provoca el error "Service files missing" y rompe la sincronización de ese recurso compartido.

## Archivos Placeholder RSLS

Cuando la **Sincronización Selectiva** está habilitada en un dispositivo (o el dispositivo está en modo Conectado), Resilio crea archivos placeholder `.rsls` en lugar de descargar el contenido real. Los placeholders son archivos de 0 bytes que representan un archivo en el recurso compartido sin almacenar sus datos localmente. El archivo se descarga bajo demanda cuando lo tocas o abres.

Esta es una función de **Sync Home Pro**. Es útil en dispositivos móviles con almacenamiento limitado - ves la estructura completa de carpetas y solo descargas los archivos que realmente necesitas.

**Importante para repositorios git:** Los archivos `.rsls` nunca deben ser confirmados. Agrega `*.rsls` al `.gitignore` de tu repositorio. Si un placeholder llega a una carpeta rastreada antes de que lo gitignores, elimínalo con `git rm --cached *.rsls`.

La carpeta `.sync/` también debe estar en el gitignore - contiene el ID del recurso compartido y el estado interno que no debe estar en control de versiones.

## Sintaxis de IgnoreList (verificada)

Ubicación: `<carpeta>/.sync/IgnoreList`. Texto plano UTF-8, una regla por línea.

**Comodines:**
- `*` coincide con cualquier secuencia de caracteres
- `?` coincide con un solo carácter
- `**` coincide con cualquier número de directorios intermedios (por ejemplo, `a/**/b` coincide con `a/b`, `a/x/b`, `a/x/y/b`)

**Semántica de rutas:**
- Un nombre sin barra como `node_modules` coincide con archivos Y directorios con ese nombre, a cualquier profundidad
- Un patrón con separador `/` queda anclado a la raíz de sincronización: `src/secrets` coincide solo con `<raíz>/src/secrets`
- Una barra inicial `/` también ancla: `/temp` coincide solo con `<raíz>/temp`
- `FOO/*` ignora los archivos dentro de `<raíz>/FOO`, pero no detiene las carpetas `FOO/` anidadas más profundas

**Otras reglas:**
- **Distingue mayúsculas y minúsculas** (incluso en macOS)
- `#` al inicio de una línea es un comentario
- Para que coincida con un archivo que empieza literalmente con `#`, usa `?recycle` en lugar de `#recycle`
- Usa `/` en macOS/Linux, `\` en Windows

## Comportamiento Crítico

**La IgnoreList no elimina archivos ya sincronizados.** Si agregas una carpeta a Sync primero y después añades patrones a la IgnoreList, los archivos que ya se replicaron en los pares se quedan ahí. Simplemente dejan de propagar futuros cambios.

**Mejor práctica**: configura la `IgnoreList` ANTES de agregar la carpeta a Sync.

**Aplicación de cambios**: Sync vuelve a leer la IgnoreList cuando el archivo cambia o en el intervalo `folder_rescan_interval`. Reinicia Resilio para que los cambios tengan efecto inmediato.

**Consistencia**: mantén la misma IgnoreList en todos los pares para evitar diferencias confusas de tamaño entre dispositivos.

## IgnoreList Inicial Recomendada

Adáptala al contenido de tu carpeta. Las claves son: nunca sincronizar secretos, nunca sincronizar el interior de git, nunca sincronizar artefactos grandes que se pueden reconstruir.

```
# Interior de Git: riesgo de corrupción con operaciones concurrentes en varios dispositivos
.git
.gitignore
.gitattributes
.gitmodules

# Secretos y credenciales: mantener fuera de los dispositivos móviles
.env
.env.*
*.env
*.pem
*.key
*.p12
*.pfx
id_rsa
id_rsa.*
id_ed25519
id_ed25519.*
credentials.json
secrets.json
service-account*.json
.aws
.ssh
.gnupg
.netrc

# Node / JavaScript
node_modules
.npm
.yarn
.next
.nuxt
.turbo
.parcel-cache
.vite

# Python
.venv
venv
__pycache__
*.pyc
.pytest_cache
.mypy_cache

# Artefactos de compilación
dist
build
out
target
coverage

# Placeholders de Resilio Sync (sincronización selectiva / modo conectado)
*.rsls

# Caché y basura del sistema operativo
.cache
.tmp
.DS_Store
Thumbs.db
desktop.ini

# Estado de IDE
.idea
.vscode
*.swp

# Logs
*.log
logs
```

## Trabajando Con Repositorios Git en Carpetas Sincronizadas

No sincronices los directorios `.git/`. Agrega `.git` a la IgnoreList antes de agregar la carpeta.

Sincronizar `.git/` entre dispositivos es inseguro porque las operaciones concurrentes de git (por ejemplo, un commit en un dispositivo mientras otro está a mitad de sincronización) pueden corromper el estado del repositorio. Las nubes comerciales (iCloud, Google Drive, Dropbox, OneDrive) manejan `.git/` aún peor y tienen una larga historia de corrupción de repositorios.

Con `.git/` excluido:
- El dispositivo principal (escritorio) es el único operador de git
- Los dispositivos móviles y secundarios solo reciben los archivos de trabajo, sin historial ni estado de git
- Las ediciones hechas en móvil se sincronizan de vuelta al principal como modificaciones del árbol de trabajo, que se confirman manualmente ahí

## Notas Específicas para iOS

- App oficial de Resilio Sync, gratuita
- Se integra con la app Archivos de iOS (aparece como ubicación junto a iCloud)
- La sincronización en segundo plano está limitada por iOS: la app debe estar en primer plano o haber estado activa recientemente para que se propaguen los cambios
- No es una experiencia "configura y olvida" en iOS; espera tener que abrir la app de vez en cuando
- Esta es una limitación de la plataforma iOS, no específica de Resilio: cualquier app de sincronización la enfrenta

## Notas Específicas para Android

- App oficial de Resilio Sync, gratuita
- Sincronización en segundo plano más flexible que iOS
- Disponible la subida automática del carrete de fotos
- La sincronización selectiva funciona bien

## Conflictos de Sincronización

Cuando se edita el mismo archivo en dos dispositivos mientras uno está sin conexión, Resilio conserva ambas copias:
- El nombre original mantiene una versión
- La otra versión se guarda como `archivo.sync-conflict-FECHA-HORA.ext`

Resuélvelo manualmente inspeccionando ambos archivos.

Para reducir los conflictos:
- Designa un dispositivo como el escritor principal
- Usa la sincronización selectiva en móvil para limitar qué carpetas puede editar el móvil
- Para colaboración compartida, considera el modo Solo Lectura en los dispositivos secundarios

## Consideraciones de Seguridad

- El archivo `.sync/ID` es efectivamente la clave secreta del recurso compartido. Cualquiera que lo tenga puede unirse al share. No lo subas a repositorios públicos ni lo pegues públicamente.
- Los códigos QR generados para compartir contienen la misma clave. No los captures y compartas públicamente.
- El tráfico de sincronización está cifrado en tránsito (AES-128).
- Los archivos en reposo NO están cifrados por Resilio. Combínalo con cifrado a nivel de disco (FileVault, BitLocker) o una bóveda cifrada (Cryptomator) si lo necesitas.
- Del lado móvil: mantén los secretos y credenciales fuera de las carpetas sincronizadas. Los dispositivos móviles se pierden o roban con más facilidad que los de escritorio.

## Alternativas en Resumen

- **Syncthing**: equivalente de código abierto. Sin app nativa para iOS (requiere un envoltorio pago de terceros). Por lo demás, comparable.
- **Nextcloud**: plataforma completa de nube auto-hospedada. Requiere servidor. Configuración más pesada, más funciones (calendario, contactos, documentos).
- **Nubes comerciales** (iCloud, Google Drive, Dropbox, OneDrive): centralizadas, fáciles, pero malas con `.git/` y pagas por almacenamiento a escala.
- **Tailscale + SMB**: acceso remoto directo a archivos sobre una malla wireguard. No es sincronización; sin acceso sin conexión. Gratis para uso personal.

## Referencias

- Descargas de Resilio: https://www.resilio.com/platforms/desktop/
- Documentación de la IgnoreList: https://help.resilio.com/hc/en-us/articles/205458165-Ignoring-files-in-Sync-Ignore-List
- Contenido de la carpeta `.sync/`: https://help.resilio.com/hc/en-us/articles/206217185-What-is-sync-folder-and-StreamsList-IgnoreList-and-Archive-inside
