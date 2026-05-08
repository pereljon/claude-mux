# FAQ

[English](../FAQ.md) · [Español](FAQ.es.md) · [Français](FAQ.fr.md) · [Deutsch](FAQ.de.md) · **Português** · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · [עברית](FAQ.he.md) · [العربية](FAQ.ar.md) · [हिन्दी](FAQ.hi.md)

## O que é o claude-mux?

Um script shell que envolve o Claude Code no tmux para sessões persistentes. As sessões sobrevivem ao fechamento do terminal, retomam o contexto da conversa ao reiniciar e ficam acessíveis pelo aplicativo móvel do Claude via Remote Control. Você gerencia tudo conversando com o Claude dentro de uma sessão.

## Funciona no Linux?

Ainda não. Apenas macOS (Apple Silicon e Intel). Suporte a Linux está planejado para a v2.0. O instalador roda no Linux, mas pula a configuração do LaunchAgent e exibe uma nota. O binário em si funciona, mas ainda não há um serviço systemd ou mecanismo equivalente de auto-inicialização.

## O que é a sessão home?

A sessão home é uma sessão de propósito geral do Claude que reside no seu diretório base (`~/Claude` por padrão). Quando `LAUNCHAGENT_MODE=home` (o padrão), ela inicia automaticamente no login e fica rodando o dia todo. Ela é **protegida** por padrão, o que significa que `--shutdown home` se recusa a pará-la sem `--force`.

Use a sessão home como seu ponto de entrada sempre disponível pelo aplicativo móvel do Claude. A partir dela você pode listar projetos, iniciar outras sessões, gerenciar configuração e fazer trabalho geral que não pertence a um projeto específico.

## O que é o Remote Control?

Remote Control (RC) é uma funcionalidade do Claude Code que permite conectar a uma sessão Claude em execução pelo aplicativo móvel do Claude ou pelo Claude Desktop. claude-mux inicia toda sessão com `--remote-control` habilitado, então todas as sessões aparecem na lista do RC automaticamente. Uma vez conectado, você conversa com o Claude da mesma forma que faria no terminal. claude-mux também contorna limitações do RC, como slash commands não funcionando nativamente, roteando-os pelo tmux.

## O que são modos de permissão?

O Claude Code tem quatro modos de permissão que controlam quanta autonomia o Claude tem:

| Modo | Comportamento |
|------|---------------|
| `default` | Claude pede antes de executar comandos ou editar arquivos |
| `acceptEdits` | Claude aplica edições automaticamente, mas pede antes de comandos shell |
| `plan` | Claude só pode ler e planejar, sem escrita ou comandos |
| `bypassPermissions` | Claude executa tudo sem perguntar (requer confirmação no primeiro lançamento) |

Defina o padrão para todos os projetos via `DEFAULT_PERMISSION_MODE` no config. Troque uma sessão em execução dizendo "trocar esta sessão para o modo plan" (ou qualquer nome de modo). "yolo" é um alias para `bypassPermissions`.

Trocar para `bypassPermissions` a partir de outro modo usa a navegação Shift+Tab e não requer reinício. Trocar de `bypassPermissions` para outro modo requer um reinício, que o claude-mux faz automaticamente.

## Como eu reinicio uma sessão?

Três opções, dependendo do que você quer:

- **Clear** ("limpar esta sessão"): envia `/clear` para a sessão. Apaga o histórico da conversa e começa do zero. A sessão continua rodando.
- **Compact** ("compactar esta sessão"): envia `/compact` para a sessão. Resume a conversa em um contexto mais curto, liberando a janela de contexto. O histórico é preservado de forma comprimida.
- **Restart** ("reiniciar esta sessão"): encerra o Claude e relança com `claude -c`, que retoma a última conversa. Use quando precisar de um processo limpo (por exemplo, após mudar modos de permissão ou quando o Claude travar).

## O que são templates?

Templates são arquivos CLAUDE.md reutilizáveis armazenados em `~/.claude-mux/templates/`. Quando você cria um novo projeto com `-n`, o template padrão (ou um que você especificar com `--template NAME`) é copiado para o projeto como seu CLAUDE.md.

Criar um template: "salvar como template chamado web" (copia o CLAUDE.md do projeto atual para `~/.claude-mux/templates/web.md`).

Usar um template: `claude-mux -n ~/projetos/meu-app --template web` ou de dentro de uma sessão: "criar um novo projeto chamado meu-app usando o template web".

Listar templates: "list templates" ou `claude-mux --list-templates`.

## Como funciona a dica do dia?

Um hook Stop do Claude Code no `.claude/settings.local.json` de cada projeto chama `claude-mux --tipotd` após cada turno de conversa. O comando verifica se uma dica já foi mostrada hoje (via `~/.claude-mux/.tip-date`). Se sim, sai em cerca de 6ms. Se não, exibe uma dica e registra a data de hoje.

Dicas estão habilitadas por padrão (`TIP_OF_DAY=true`). Alterne com "enable tips" ou "disable tips" dentro de qualquer sessão. `TIP_MODE=daily` mostra a mesma dica o dia todo; `TIP_MODE=random` escolhe uma dica aleatória por invocação (com o hook Stop, isso significa uma dica aleatória por dia devido à trava diária).

O comando `--tip` sempre funciona independentemente da trava diária, então você pode dizer "tip" a qualquer momento.

## Posso usar com múltiplas contas GitHub?

Sim. claude-mux detecta entradas `Host github.com-*` no `~/.ssh/config` e injeta-as no system prompt de cada sessão. O Claude sabe quais aliases SSH estão disponíveis e pode usar o correto ao configurar remotes do git.

Exemplo de configuração em `~/.ssh/config`:

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

O Claude então saberá usar `git@github.com-work:org/repo.git` para repos de trabalho e `git@github.com-personal:user/repo.git` para repos pessoais.

## Onde o estado é armazenado?

| Local | O que fica lá |
|-------|---------------|
| `~/.claude-mux/config` | Configuração do usuário (sourced como bash) |
| `~/.claude-mux/templates/` | Arquivos de template CLAUDE.md |
| `~/.claude-mux/.tip-date` | Data da última dica exibida |
| `~/.claude-mux/.update-check` | Resultado do check de versão em cache |
| `~/Library/Logs/claude-mux.log` | Arquivo de log (configurável via `LOG_DIR`) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | Plist do LaunchAgent (gerado por `--install`) |
| `.claudemux-protected` (por projeto) | Marca uma sessão como protegida contra shutdown |
| `.claudemux-ignore` (por projeto) | Oculta um projeto das listagens |

Arquivos marcadores (`.claudemux-*`) ficam na raiz de cada projeto e acompanham a pasta em renomeações, movimentações e sincronizações. São adicionados automaticamente ao `.gitignore`.

O histórico de conversas é gerenciado pelo próprio Claude Code, armazenado em `~/.claude/projects/`.

## O que acontece com auto-update se eu fizer fork do claude-mux?

O check de atualização e o comando `--update` usam `pereljon/claude-mux` como repositório GitHub fixo. Se você fizer fork, os checks de atualização ainda comparam com o release upstream, e `--update` sobrescreve o binário do seu fork com o upstream. Defina `UPDATE_CHECK=false` em `~/.claude-mux/config` para desabilitar, ou altere a URL do repo nas funções `check_for_update()` e `do_update()` no script.

## Como instalo via Homebrew?

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

Atualize com `brew upgrade claude-mux`. Nota: se você instalou via Homebrew, `--update` delega para `brew upgrade` automaticamente.

## Qual a diferença para `claude --worktree --tmux`?

`claude --worktree --tmux` cria uma sessão tmux para um worktree git isolado, projetado para tarefas de codificação paralelas. claude-mux gerencia sessões persistentes para os diretórios reais dos seus projetos, com Remote Control habilitado, injeção de system prompt para autogerenciamento, retomada de conversa e gerenciamento do ciclo de vida das sessões. Resolvem problemas diferentes.

## Por que as sessões mostram "Not logged in"?

Isso acontece no primeiro lançamento se o keychain do macOS estiver bloqueado, o que é comum quando o LaunchAgent inicia antes de você desbloquear o keychain após o login. Corrija executando `security unlock-keychain` em um terminal normal, depois conecte a qualquer sessão (`claude-mux -t <nome>`) e execute `/login` para completar o fluxo de autenticação no navegador. Depois disso, reinicie todas as sessões e elas vão pegar a credencial armazenada.

## Múltiplos terminais podem se conectar à mesma sessão?

Sim. Isso é comportamento padrão do tmux. Executar `claude-mux` em um diretório que já tem uma sessão em execução conecta-se a ela. Múltiplos terminais veem o conteúdo da mesma sessão em tempo real.

## Como paro a sessão home permanentemente?

O LaunchAgent tem `KeepAlive: true`, então encerrar a sessão home dispara um respawn em cerca de 60 segundos. Para pará-la permanentemente, desabilite o LaunchAgent:

```bash
claude-mux --install --launchagent-mode none
```

## O que significa a mensagem "Session ready!"?

Quando uma sessão inicia ou reinicia, o claude-mux envia um prompt `Ready?` após o Claude terminar de carregar. A injeção instrui o Claude a responder com "Session ready!" e nada mais. Isso confirma que a sessão está ativa e a injeção de system prompt está funcionando. Você pode ignorá-la.

## Como oculto um projeto das listagens?

Diga "ocultar este projeto" dentro de qualquer sessão, ou execute `claude-mux --hide my-project`. Isso cria um arquivo marcador `.claudemux-ignore`. O projeto não aparecerá na saída de `claude-mux -L`. Para ver projetos ocultos: `claude-mux -L --hidden`. Para mostrar novamente: "mostrar este projeto" ou `claude-mux --show my-project`.

## Como desinstalo o claude-mux?

```bash
claude-mux --uninstall
```

Isso remove hooks de dicas e regras de permissão de todos os projetos, descarrega o LaunchAgent e opcionalmente remove `~/.claude-mux/`. Reporta o caminho do binário para você poder deletá-lo manualmente (ou `brew uninstall claude-mux` se instalado via Homebrew).

## Slash commands funcionam via Remote Control?

Não nativamente. O Claude Code não suporta slash commands (`/model`, `/clear`, etc.) em sessões RC. claude-mux contorna isso injetando `claude-mux -s` em cada sessão para que o Claude possa enviar slash commands a si mesmo via tmux. Basta dizer "trocar para Haiku" ou "compactar esta sessão" e o Claude cuida do resto.

## Não consigo selecionar texto em uma sessão

Segure **Option** (macOS) ou **Shift** (terminais Linux/Windows) enquanto clica e arrasta. Isso contorna a captura de mouse do tmux e copia a seleção para o clipboard do sistema. Nenhuma mudança de configuração necessária.

## Quais idiomas são suportados para comandos conversacionais?

Todos. As frases-gatilho ("help", "status", "list sessions", etc.) funcionam em qualquer idioma. O Claude infere a intenção a partir da linguagem natural do usuário e executa o comando correspondente. O README também está traduzido em 12 idiomas.
