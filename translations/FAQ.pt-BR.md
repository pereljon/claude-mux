# FAQ

[English](../docs/FAQ.md) · [Español](FAQ.es.md) · [Français](FAQ.fr.md) · [Deutsch](FAQ.de.md) · **Português** · [日本語](FAQ.ja.md) · [한국어](FAQ.ko.md) · [Italiano](FAQ.it.md) · [Русский](FAQ.ru.md) · [中文](FAQ.zh-CN.md) · [עברית](FAQ.he.md) · [العربية](FAQ.ar.md) · [हिन्दी](FAQ.hi.md)

## O que e o claude-mux?

Um script shell que envolve o Claude Code em tmux para sessoes persistentes. Sessoes sobrevivem ao fechamento do terminal, retomam o contexto da conversa ao reiniciar e sao acessiveis pelo app movel do Claude via Remote Control. Voce gerencia tudo conversando com o Claude dentro de uma sessao.

## Funciona no Linux?

Ainda nao. Apenas macOS (Apple Silicon e Intel). Suporte a Linux esta planejado para v2.0. O instalador roda no Linux mas pula a configuracao do LaunchAgent e mostra uma nota. O binario em si funciona, mas ainda nao ha servico systemd ou mecanismo de auto-inicio equivalente.

## O que e a sessao home?

A sessao home e uma sessao Claude de uso geral que fica no seu diretorio base (`~/Claude` por padrao). Quando `LAUNCHAGENT_MODE=home` (padrao), ela inicia automaticamente no login e fica rodando o dia todo. Ela e **protegida** por padrao, o que significa que `--shutdown home` recusa parar sem `--force`.

Use a sessao home como seu ponto de entrada sempre disponivel pelo app movel do Claude. De la voce pode listar projetos, iniciar outras sessoes, gerenciar configuracao e fazer trabalho geral que nao pertence a um projeto especifico.

## O que e Remote Control?

Remote Control (RC) e um recurso do Claude Code que permite conectar a uma sessao Claude rodando pelo app movel do Claude ou Claude Desktop. claude-mux inicia cada sessao com `--remote-control` habilitado, entao todas as sessoes aparecem na lista do RC automaticamente. Uma vez conectado, voce conversa com o Claude da mesma forma que no terminal. claude-mux tambem contorna limitacoes do RC como slash commands que nao funcionam nativamente, roteando-os pelo tmux.

## O que sao modos de permissao?

O Claude Code tem quatro modos de permissao que controlam quanta autonomia o Claude tem:

| Modo | Comportamento |
|------|---------------|
| `default` | Claude pergunta antes de rodar comandos ou editar arquivos |
| `acceptEdits` | Claude aplica edicoes automaticamente mas pergunta antes de comandos shell |
| `plan` | Claude so pode ler e planejar, sem escrita ou comandos |
| `bypassPermissions` | Claude roda tudo sem perguntar (requer confirmacao no primeiro inicio) |

Defina o padrao para todos os projetos via `DEFAULT_PERMISSION_MODE` na configuracao. Mude uma sessao rodando dizendo "mude esta sessao para modo plan" (ou qualquer nome de modo). "yolo" e um alias para `bypassPermissions`.

Mudar para `bypassPermissions` de outro modo usa navegacao Shift+Tab e nao requer reinicio. Mudar de `bypassPermissions` para outro modo requer reinicio, que o claude-mux faz automaticamente.

## Como reseto uma sessao?

Tres opcoes, dependendo do que voce precisa:

- **Clear** ("limpe esta sessao"): envia `/clear` para a sessao. Apaga o historico da conversa e comeca do zero. A sessao continua rodando.
- **Compact** ("compacte esta sessao"): envia `/compact` para a sessao. Resume a conversa em um contexto mais curto, liberando a janela de contexto. O historico e preservado em forma comprimida.
- **Restart** ("reinicie esta sessao"): encerra o Claude e reinicia com `claude -c`, que retoma a ultima conversa. Use quando precisar de um processo limpo (ex: apos mudar modos de permissao ou quando o Claude esta travado).

## O que sao templates?

Templates sao arquivos CLAUDE.md reutilizaveis armazenados em `~/.claude-mux/templates/`. Quando voce cria um novo projeto com `-n`, o template padrao (ou um especificado com `--template NAME`) e copiado para o projeto como CLAUDE.md.

Criar um template: "salve isso como template com nome web" (copia o CLAUDE.md do projeto atual para `~/.claude-mux/templates/web.md`).

Usar um template: `claude-mux -n ~/projetos/my-app --template web` ou de dentro de uma sessao: "crie um novo projeto chamado my-app usando o template web".

Listar templates: "listar templates" ou `claude-mux --list-templates`.

## Como funciona o tip-of-the-day?

Um hook `UserPromptSubmit` do Claude Code no `.claude/settings.local.json` de cada projeto chama `claude-mux --on-prompt` a cada prompt. O primeiro prompt do dia injeta uma dica na conversa; prompts posteriores naquele dia nao injetam nada. O estado e por sessao, armazenado em `~/.claude-mux/tip-state/<session_id>.json`, entao cada sessao ativa mostra a dica uma vez por dia. Como o hook injeta no contexto (nao um hook Stop, cuja saida vai apenas para o transcript), a dica fica visivel na conversa e no Remote Control.

Dicas sao habilitadas por padrao (`TIP_OF_DAY=true`). Alterne com "ativar tips" ou "desativar tips" dentro de qualquer sessao. `TIP_MODE=daily` mostra a mesma dica o dia todo; `TIP_MODE=random` escolhe uma dica aleatoria.

O comando `--tip` sempre funciona independente da trava diaria (e independente de `TIP_OF_DAY`), entao voce pode dizer "tip" a qualquer momento.

## Posso usar com multiplas contas GitHub?

Sim. claude-mux detecta entradas `Host github.com-*` em `~/.ssh/config` e as injeta no system prompt de cada sessao. O Claude sabe quais aliases SSH estao disponiveis e pode usar o correto ao configurar git remotes.

Exemplo de `~/.ssh/config`:

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

O Claude entao usara `git@github.com-work:org/repo.git` para repos de trabalho e `git@github.com-personal:user/repo.git` para pessoais.

## Onde o estado e armazenado?

| Local | O que fica la |
|-------|---------------|
| `~/.claude-mux/config` | Configuracao do usuario (carregada como bash) |
| `~/.claude-mux/templates/` | Arquivos de template CLAUDE.md |
| `~/.claude-mux/tip-state/<session_id>.json` | Data da dica por sessao + limite de avisos de atualizacao |
| `~/.claude-mux/.update-check` | Resultado em cache da verificacao de versao |
| `~/.claude-mux/.update-checking` | Trava durante a verificacao de atualizacao em segundo plano |
| `~/Library/Logs/claude-mux.log` | Arquivo de log (configuravel via `LOG_DIR`) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | plist do LaunchAgent (gerado por `--install`) |
| `.claudemux-protected` (por projeto) | Marca uma sessao como protegida contra encerramento |
| `.claudemux-ignore` (por projeto) | Oculta um projeto das listagens |

Arquivos marcadores (`.claudemux-*`) ficam no diretorio raiz de cada projeto e acompanham a pasta em renomeacoes, mudancas e sincronizacoes. Sao adicionados automaticamente ao `.gitignore`.

O historico de conversas e gerenciado pelo proprio Claude Code, armazenado em `~/.claude/projects/`.

## O que acontece com auto-update se eu fizer fork do claude-mux?

A verificacao de atualizacao e o comando `--update` usam `pereljon/claude-mux` como repo GitHub fixo. Se voce fizer fork, as verificacoes de atualizacao continuarao comparando com o release upstream, e `--update` sobrescrevera seu binario do fork com o upstream. Defina `UPDATE_CHECK=false` em `~/.claude-mux/config` para desabilitar, ou altere a URL do repo nas funcoes `check_for_update()` e `do_update()` no script.

## Como instalo via Homebrew?

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

Atualize com `brew upgrade claude-mux`. Nota: se voce instalou via Homebrew, `--update` delega para `brew upgrade` automaticamente.

## Qual a diferenca para `claude --worktree --tmux`?

`claude --worktree --tmux` cria uma sessao tmux para um git worktree isolado, projetado para tarefas de programacao paralelas. claude-mux gerencia sessoes persistentes para os diretorios reais dos seus projetos, com Remote Control habilitado, injecao de system prompt para autogerenciamento, retomada de conversa e gerenciamento do ciclo de vida da sessao. Resolvem problemas diferentes.

## Qual a diferenca para o Claude Cowork Dispatch?

O Dispatch inicia tarefas pelo app desktop do Claude, mas exige que o app esteja rodando e nao e vinculado a um projeto especifico. claude-mux gerencia sessoes persistentes, vinculadas a projetos, que sobrevivem a reinicializacoes e sao acessiveis de qualquer lugar via Remote Control - sem necessidade do app desktop.

## Por que sessoes mostram "Not logged in"?

Isso acontece no primeiro inicio se o keychain do macOS esta bloqueado, o que e comum quando o LaunchAgent inicia antes de voce desbloquear o keychain apos o login. Solucao: rode `security unlock-keychain` em um terminal normal, depois conecte a qualquer sessao (`claude-mux -t <name>`) e rode `/login` para completar o fluxo de autenticacao no navegador. Depois disso, reinicie todas as sessoes e elas pegarao a credencial armazenada.

## Multiplos terminais podem conectar a mesma sessao?

Sim. Isso e comportamento padrao do tmux. Rodar `claude-mux` em um diretorio que ja tem uma sessao rodando conecta a ela. Multiplos terminais veem o mesmo conteudo da sessao em tempo real.

## Como paro a sessao home permanentemente?

O LaunchAgent tem `KeepAlive: true`, entao encerrar a sessao home dispara um reinicio em cerca de 60 segundos. Para para-la permanentemente, desabilite o LaunchAgent:

```bash
claude-mux --install --launchagent-mode none
```

## O que significa a mensagem "Session ready!"?

Quando uma sessao inicia ou reinicia, claude-mux envia um prompt `Ready?` apos o Claude terminar de carregar. A injecao instrui o Claude a responder com "Session ready!" e nada mais. Isso confirma que a sessao esta ativa e a injecao do system prompt esta funcionando. Voce pode ignorar.

## Como oculto um projeto das listagens?

Diga "oculte este projeto" dentro de qualquer sessao, ou rode `claude-mux --hide my-project`. Isso cria um arquivo marcador `.claudemux-ignore`. O projeto nao aparecera na saida de `claude-mux -L`. Para ver projetos ocultos: `claude-mux -L --hidden`. Para mostrar novamente: "mostre este projeto" ou `claude-mux --show my-project`.

## Como desinstalo o claude-mux?

```bash
claude-mux --uninstall
```

Isso remove hooks de dicas e regras de permissao de todos os projetos, descarrega o LaunchAgent e opcionalmente remove `~/.claude-mux/`. Ele informa o caminho do binario para que voce possa deletar manualmente (ou `brew uninstall claude-mux` se instalado via Homebrew).

## Slash commands funcionam pelo Remote Control?

Nao nativamente. O Claude Code nao suporta slash commands (`/model`, `/clear`, etc.) em sessoes RC. claude-mux contorna isso injetando `claude-mux -s` em cada sessao para que o Claude possa enviar slash commands para si mesmo via tmux. Basta dizer "mude para Haiku" ou "compacte esta sessao" e o Claude cuida disso.

## Nao consigo selecionar texto em uma sessao

Segure **Option** (macOS) ou **Shift** (terminais Linux/Windows) enquanto clica e arrasta. Isso ignora a captura de mouse do tmux e copia a selecao para a area de transferencia do sistema. Nenhuma mudanca de configuracao necessaria.

## Quais idiomas sao suportados para comandos conversacionais?

Todos. As frases de gatilho ("help", "status", "list sessions", etc.) funcionam em qualquer idioma. O Claude infere a intencao da linguagem natural do usuario e roda o comando correspondente. O README tambem esta traduzido em 12 idiomas.
