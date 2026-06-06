# claude-mux - Multiplexador do Claude Code

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · **Português** · [日本語](README.ja.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

Sessoes persistentes do Claude Code para todos os seus projetos - acessiveis de qualquer lugar pelo app movel do Claude. ***Gerenciado pelo Claude!***

## Instalar

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

Depois inicie uma sessao:

```bash
claude-mux ~/caminho/para/seu/projeto
```

O instalador pergunta se voce quer uma sessao home no login. Se aceitar, uma sessao protegida do Claude inicia automaticamente toda vez que voce faz login - sempre acessivel pelo celular ou qualquer cliente Remote Control, mesmo que voce nunca abra o terminal.

E isso! Voce esta em uma sessao persistente e contextualizada do Claude com Remote Control habilitado. **A partir daqui, tudo e por conversa.**

[Homebrew, instalacao manual e outras opcoes](../docs/INSTALL.md)

## Por que

Remote Control promete Claude Code de qualquer lugar - mas sem gerenciamento de sessoes, e uma interface de segunda classe mesmo pelo Claude Desktop:

- **Sessoes morrem** quando voce fecha o terminal
- **Contexto da conversa** nao retoma automaticamente
- **Sem base fixa** - nada esta rodando quando voce pega o celular, a menos que tenha deixado algo aberto
- **Remote Control precisa de uma sessao rodando** - voce nao pode iniciar uma pelo RC
- **Slash commands nao funcionam em sessoes RC** - sem troca de modelo, compactacao ou mudanca de modo de permissao
- **Iniciar novos projetos** - exige criar manualmente um diretorio, inicializar git, escrever um CLAUDE.md e escolher um modelo
- **Sem gerenciamento de projetos** - sem como ver projetos inativos, ou renomear, mover e excluir projetos sem perder o historico

**claude-mux resolve a lacuna no gerenciamento de sessoes.** Ele envolve o Claude Code em tmux para que sessoes persistam, injeta um system prompt para que o Claude gerencie suas proprias sessoes, e roteia slash commands pelo tmux para que funcionem via Remote Control. Uma vez que a sessao esta rodando, voce gerencia tudo conversando com o Claude - no terminal ou no app movel.

## O que voce pode fazer em uma sessao claude-mux

- **Gerenciar qualquer sessao de qualquer sessao** - iniciar, parar, reiniciar, listar e compactar projetos usando linguagem natural
- **Acessar tudo de qualquer lugar** - toda sessao tem Remote Control habilitado, entao o app movel do Claude, app desktop ou qualquer cliente remoto e uma interface completa
- **Trocar modelos e modos de permissao** - diga "mude para Haiku" ou "mude para modo plan" e o Claude faz isso, mesmo pelo Remote Control
- **Criar novos projetos** - "crie um novo projeto chamado my-app" configura diretorio, git, CLAUDE.md e inicia uma sessao. Templates CLAUDE.md permitem reutilizar instrucoes entre projetos.
- **Manter sessoes vivas apos reinicializacoes** - uma sessao home opcional inicia no login e continua rodando; todas as sessoes retomam a ultima conversa automaticamente
- **Enviar slash commands pelo Remote Control** - o Claude roteia `/model`, `/compact`, `/clear` e outros slash commands para a sessao rodando, contornando uma [limitacao conhecida](https://github.com/anthropics/claude-code/issues/30674)
- **Preservar historico de conversas** - renomear, mover e reiniciar projetos preservam o historico de conversas automaticamente
- **Organizar projetos** - ocultar, renomear, mover, excluir e proteger projetos de dentro de qualquer sessao
- **Suporte a multiplas contas GitHub** - detecta aliases SSH em `~/.ssh/config` e os injeta nas sessoes para que o Claude use a conta certa por projeto
- **Suporte multi-CLI-coder** - cria automaticamente symlinks `AGENTS.md` e `GEMINI.md` para que Codex CLI, Gemini CLI e outros compartilhem instrucoes
- **Funciona em qualquer idioma** - comandos conversacionais sao inferidos pela intencao, nao por palavras-chave

## Conversando com o Claude

E assim que voce usa o claude-mux no dia a dia. Cada sessao recebe comandos injetados para que o Claude gerencie sessoes, troque modelos, envie slash commands e crie novos projetos - tudo de dentro da conversa. Voce nao precisa lembrar flags do CLI.

```
Voce: "status"
Claude: reporta nome da sessao, modelo, modo de permissao, uso de contexto e lista todas as sessoes

Voce: "listar sessoes ativas"
Claude: mostra todas as sessoes rodando com seu status

Voce: "inicie uma sessao para meu projeto api-server"
Claude: inicia uma sessao em ~/Claude/work/api-server

Voce: "crie um novo projeto chamado mobile-app usando o template web"
Claude: cria o diretorio do projeto, inicializa git, aplica o template, inicia uma sessao

Voce: "mude esta sessao para Haiku"
Claude: envia /model haiku para si mesmo via tmux

Voce: "compacte a sessao api-server"
Claude: envia /compact para a sessao api-server

Voce: "reinicie a sessao web-dashboard"
Claude: encerra e reinicia a sessao, preservando o contexto da conversa

Voce: "mude a sessao api-server para modo plan"
Claude: reinicia a sessao com modo de permissao plan

Voce: "mude esta sessao para modo yolo"
Claude: muda para bypassPermissions via Shift+Tab - sem necessidade de reinicio

Voce: "qual o modo desta sessao"
Claude: reporta o modo de permissao atual (default, acceptEdits, plan, bypassPermissions)

Voce: "mude esta sessao para Opus"
Claude: envia /model opus para si mesmo via tmux

Voce: "limpe esta sessao"
Claude: envia /clear para si mesmo, resetando a conversa

Voce: "oculte este projeto"
Claude: escreve .claudemux-ignore para que o projeto seja excluido das listagens -L

Voce: "proteja esta sessao"
Claude: escreve .claudemux-protected e define o marcador tmux - --shutdown agora exige --force

Voce: "esta sessao esta protegida"
Claude: verifica se .claudemux-protected existe na pasta do projeto e reporta

Voce: "exclua o projeto old-prototype"
Claude: confirma no chat, depois move a pasta do projeto para a lixeira do sistema

Voce: "renomeie este projeto para my-new-name"
Claude: para a sessao, renomeia a pasta, migra o historico de conversas, reinicia

Voce: "salve isso como template com nome web"
Claude: copia CLAUDE.md para ~/.claude-mux/templates/web.md

Voce: "tip"
Claude: mostra uma dica - a mesma o dia todo, ou aleatoria se TIP_MODE=random estiver definido

Voce: "ativar tips" / "desativar tips"
Claude: ativa ou desativa a dica do dia em todos os projetos

Voce: "atualizar claude-mux"
Claude: avisa que todas as sessoes serao reiniciadas, pede confirmacao, atualiza e reinicia

Voce: "parar todas as sessoes"
Claude: encerra ordenadamente todas as sessoes gerenciadas

Voce: "help"
Claude: mostra a lista completa de comandos conversacionais
```

**Esses comandos funcionam em qualquer idioma.** Se voce digitar o equivalente em portugues, japones, hebraico ou qualquer outro idioma, o Claude infere a intencao e executa o comando correspondente.

**Digite `help` dentro de qualquer sessao para ver a lista completa de comandos.**

## Mais

- [Referencia CLI](../docs/CLI.md) - referencia completa de comandos para scripting e automacao
- [Guia](../docs/guide.md) - configuracao, detalhes de sessao, internos e solucao de problemas
- [Opcoes de instalacao](../docs/INSTALL.md) - Homebrew, instalacao manual, configuracao do LaunchAgent
- [FAQ](../docs/FAQ.md) - perguntas frequentes sobre claude-mux
- [Problemas conhecidos](../docs/ISSUES.md) - bugs abertos, features planejadas e problemas resolvidos
- [Changelog](../CHANGELOG.md) - mudancas por release
