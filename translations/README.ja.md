# claude-mux - Claude Code マルチプレクサ

[English](../README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · **日本語** · [한국어](README.ko.md) · [Italiano](README.it.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [עברית](README.he.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

すべてのプロジェクトに対して永続的な Claude Code セッションを提供し、Claude モバイルアプリからどこでもアクセスできるようにします。

## なぜ必要か

Remote Control はどこからでも Claude Code を使えることを約束しています — しかしセッション管理なしでは、Claude Desktop からでさえ二流のインターフェースです:

- ターミナルを閉じるとセッションが終了し、会話のコンテキストは自動的に再開されない
- 常時起動のホームベースがない — 何かを開いたままにしていない限り、スマートフォンを手に取っても何も動いていない
- セッションが起動していなければ Remote Control は無意味 — プロジェクトに到達することも新たに開始することもできない
- 起動中の RC セッションでもスラッシュコマンドは動作しない — モデル切り替え、コンパクト化、permission モード変更はすべて不可
- 新しいプロジェクトを開始するには、ディレクトリの手動作成、git の初期化、CLAUDE.md の作成、permission モードの設定、モデルの選択が必要 — これらはいずれも RC からは実行できない
- 複数プロジェクトの管理は複数のターミナルを手動で起動することを意味し、何が動いているかや状態の全体像が把握できない

claude-mux はこれらをすべて解決します。Claude Code を tmux でラップしてセッションを永続化し、Claude が自身のセッションを管理できるようシステムプロンプトを注入し、スラッシュコマンドを tmux 経由でルーティングして Remote Control 上でも動作するようにします。セッションが起動したら、ターミナルからでもモバイルアプリからでも、Claude に話しかけることですべてを管理できます。

## クイックスタート

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

```bash
cd ~/path/to/your/project
claude-mux
```

または：

```bash
claude-mux ~/path/to/your/project
```

これだけです。Remote Control が有効化された永続的なセッション認識型 Claude セッションに入れます。あとはすべて会話で操作できます。

## Claude に話しかける

これが claude-mux の日常的な使い方です。各セッションにはコマンドが注入されており、Claude はセッションの管理、モデルの切り替え、スラッシュコマンドの送信、新規プロジェクトの作成をすべて会話の中から行えます。CLI フラグを覚える必要はありません。

```
あなた：「status」
Claude：セッション名、モデル、permission モード、コンテキスト使用量を報告し、全セッションを一覧表示

あなた：「アクティブなセッションを一覧表示して」
Claude：動作中の全セッションをステータス付きで表示

あなた：「api-server プロジェクトのセッションを開始して」
Claude：~/Claude/work/api-server にセッションを起動

あなた：「web テンプレートを使って mobile-app という新規プロジェクトを作成して」
Claude：プロジェクトディレクトリを作成し、git を初期化して、テンプレートを適用し、セッションを起動

あなた：「このセッションを Haiku に切り替えて」
Claude：tmux 経由で自身に /model haiku を送信

あなた：「api-server セッションをコンパクト化して」
Claude：api-server セッションに /compact を送信

あなた：「web-dashboard セッションを再起動して」
Claude：セッションをシャットダウンして再起動し、会話コンテキストを保持

あなた：「api-server セッションを plan モードに切り替えて」
Claude：plan permission モードでセッションを再起動

あなた：「全セッションを停止して」
Claude：管理対象の全セッションを正常終了

あなた：「help」
Claude：会話コマンドの全一覧を表示
```

これらのコマンドはどの言語でも動作します。スペイン語、日本語、ヘブライ語など、他の言語で同等の表現を入力しても、Claude は意図を読み取って対応するコマンドを実行します。

任意のセッション内で `help` と入力すると、コマンド一覧を確認できます。

### Home セッション

home セッションはベースディレクトリ (デフォルトは `~/Claude`) に置かれた汎用セッションです。`LAUNCHAGENT_MODE=home` の場合はログイン時に自動起動し、スマートフォンからすぐにアクセスできる常時待機の Claude セッションを提供します。プロジェクト固有のセッションを先に起動しなくても、他のすべてのセッションをここから管理できます。

home セッションはデフォルトで**保護**されています。`--shutdown home` は `--force` なしでは停止を拒否します。保護は `$BASE_DIR` 内の `.claudemux-protected` マーカーファイルによって制御され、`claude-mux --install` によって作成されます。保護されたセッションはステータス列に `protected` と表示されます。呼び出し元セッションは名前列に `>` が付きます。

## 何をするか

内部では claude-mux が以下を処理します:

- **Remote Control 付きの永続的な tmux セッション** — すべてのセッションが Claude モバイルアプリからアクセス可能
- **会話の再開** — 再起動時に直前の会話を再開 (`claude -c`) してコンテキストを保持
- **システムプロンプトの注入** — 各セッションにセルフ管理、スラッシュコマンドのルーティング、SSH アカウント認識のためのコマンドを注入
- **CLAUDE.md テンプレート** — `~/.claude-mux/templates/` にテンプレートファイル (例: `web.md`、`python.md`) を維持し、新規プロジェクトに適用
- **マルチ CLI ツール対応** — `AGENTS.md` と `GEMINI.md` を `CLAUDE.md` へのシンボリックリンクとして作成し、Codex CLI、Gemini CLI などのツールが同じ指示を共有できるようにする
- **権限の自動承認** — claude-mux を各プロジェクトの許可リストに追加し、Claude がプロンプトなしでセッションコマンドを実行できるようにする
- **野良プロセスの移行** — Claude が tmux 外で既に動いている場合、管理対象のセッションに移行
- **tmux の品質向上設定** — マウスサポート、50k 行のスクロールバック、クリップボード連携、256 色、拡張キー、アクティビティ監視、タブタイトル

> **注意:** これは `claude --worktree --tmux` とは異なります。後者は隔離された git worktree 用に tmux セッションを作成するものです。claude-mux は実際のプロジェクトディレクトリの永続セッションを管理し、Remote Control とシステムプロンプトの注入を提供します。

## 必要環境

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## インストール

### Homebrew（推奨）

```bash
brew tap pereljon/tap
brew install claude-mux
```

インストール後、セットアップコマンドを実行して config を作成し、オプションで LaunchAgent をインストールします（ログイン時のホームセッション）：

```bash
claude-mux --install
```

更新するには：

```bash
brew upgrade claude-mux       # または: claude-mux --update  (任意のセッション内から実行可能)
```

### 手動

```bash
./install.sh
```

`install.sh` はバイナリを `~/bin` にコピーして `PATH` に追加します。その後、次を実行します：

```bash
claude-mux --install
```

対話型セットアップは、Claude プロジェクトの配置場所、ログイン時に home セッションを開始するか、どのモデルを使うかを尋ねます。`~/.claude-mux/config` を作成し、LaunchAgent をインストールします。

プロンプトをスキップしてデフォルトを受け入れるには `--non-interactive` を使用します。

オプション:

```bash
claude-mux --install --non-interactive                     # プロンプトをスキップしてデフォルトを使用
claude-mux --install --base-dir ~/work/claude              # 別のベースディレクトリを使用
claude-mux --install --launchagent-mode none               # LaunchAgent の動作を無効化
claude-mux --install --home-model haiku                    # home セッションに Haiku を使用
claude-mux --install --no-launchagent                      # LaunchAgent のインストールを完全にスキップ
```

LaunchAgent はログイン時に `claude-mux --autolaunch` を実行し、システムサービスの初期化を待つために 45 秒の起動遅延を入れます。

## セッションのステータス

| ステータス | 意味 |
|--------|---------|
| `running` | tmux セッションが存在し、Claude が動作している |
| `protected` | `running` と同様だが、セッションが保護されている — `--shutdown` には `--force` が必要 |
| `stopped` | tmux セッションは存在するが、Claude が終了している |
| `idle` | `BASE_DIR` 配下に `.claude/` プロジェクトが存在するが、claude-mux の tmux セッションが動作していない (`-L` の場合のみ表示) |

セッション名の `>` プレフィックス (例: `> home`) は、list コマンドを実行したセッションを示します。

すでに動作中のセッションがあるディレクトリで `claude-mux` を実行すると、そのセッションへアタッチします。複数のターミナルから同じセッションへアタッチできます (標準的な tmux の動作)。

## プロジェクトマーカー

プロジェクト単位の状態はプロジェクトルートのマーカーファイルに保存され、中央の設定には保存されません。マーカーは `.claudemux-` プレフィックスを使用し、git 管理プロジェクト内で作成された際に自動的に `.gitignore` へ追加されます。

| マーカー | 意味 | CLI |
|---------|------|-----|
| `.claudemux-protected` | 起動時にセッションを保護 — `--shutdown` には `--force` が必要 | `--protect` / `--unprotect` |
| `.claudemux-ignore` | `claude-mux -L` の一覧からプロジェクトを非表示にする | `--hide` / `--show` |

```bash
claude-mux --hide                    # 現在のプロジェクトを -L 一覧から非表示にする
claude-mux --show                    # 現在のプロジェクトの非表示を解除する
claude-mux --protect                 # このセッションを誤ったシャットダウンから保護する
claude-mux --unprotect               # 保護を解除する
claude-mux -L --hidden               # 非表示のプロジェクトのみ一覧表示する
claude-mux --delete ~/projects/old   # プロジェクトフォルダをシステムゴミ箱に移動する (macOS)
```

マーカーはプロジェクトフォルダの名前変更や移動に追従します。単一の `.gitignore` パターン (`.claudemux-*`) が現在および将来のすべてのマーカーをカバーします。

## 設定

`~/.claude-mux/config` は `claude-mux --install` によって作成されます（config が存在しない場合は任意のコマンドの初回実行時にも作成されます）。デフォルトを上書きするには編集してください。スクリプト本体を直接書き換える必要はありません。

| 変数 | デフォルト | 説明 |
|----------|---------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Claude プロジェクト (`.claude/` を含むディレクトリ) を走査するルートディレクトリ |
| `LOG_DIR` | `$HOME/Library/Logs` | `claude-mux.log` ファイルを置くディレクトリ |
| `DEFAULT_PERMISSION_MODE` | `auto` | 各プロジェクトの Claude `permissions.defaultMode` を設定。有効値: `default`、`acceptEdits`、`plan`、`auto`、`dontAsk`、`bypassPermissions`。`""` で無効化 |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | `true` の場合、Claude セッション同士でスラッシュコマンドを送信可能。マルチエージェント連携で有用 |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | CLAUDE.md テンプレートファイルを置くディレクトリ |
| `DEFAULT_TEMPLATE` | `default.md` | 新規プロジェクト (`-n`) に適用されるデフォルトテンプレート。`""` で無効化 |
| `SLEEP_BETWEEN` | `5` | `-a` 使用時のセッション起動間隔の秒数。RC 登録が失敗する場合は値を増やす |
| `HOME_SESSION_MODEL` | `""` | home セッション用のモデル。有効値: `sonnet`、`haiku`、`opus`。空の場合は Claude のデフォルトを継承 |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | 他の AI CLI ツール向けに `CLAUDE.md` へのシンボリックリンクとして作成するファイルのスペース区切りリスト。`""` で無効化 |
| `LAUNCHAGENT_MODE` | `home` | ログイン時の LaunchAgent の動作: `none` (何もしない) または `home` (保護された home セッションを起動)。レガシーの `LAUNCHAGENT_ENABLED=true` は `home` として扱われる |

**Tmux セッションのオプション** (すべて設定可能、デフォルトで有効):

| 変数 | デフォルト | 説明 |
|----------|---------|-------------|
| `TMUX_MOUSE` | `true` | マウスサポート - スクロール、選択、ペインサイズ変更 |
| `TMUX_HISTORY_LIMIT` | `50000` | スクロールバックバッファのサイズ (行数。tmux のデフォルトは 2000) |
| `TMUX_CLIPBOARD` | `true` | OSC 52 によるシステムクリップボード連携 |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | 適切な色表示のための端末タイプ |
| `TMUX_EXTENDED_KEYS` | `true` | Shift+Enter を含む拡張キーシーケンス (tmux 3.2 以上が必要) |
| `TMUX_ESCAPE_TIME` | `10` | Escape キーの遅延 (ミリ秒。tmux のデフォルトは 500) |
| `TMUX_TITLE_FORMAT` | `#S` | ターミナル/タブタイトルのフォーマット (`#S` = セッション名、`""` で無効化) |
| `TMUX_MONITOR_ACTIVITY` | `true` | 他セッションでアクティビティが発生したときに通知 |

## ディレクトリ構造

プロジェクトは任意の階層に存在する `.claude/` ディレクトリの有無で検出されます:

```
~/Claude/
├── work/
│   ├── project-a/          # ✓ .claude/ あり - 管理対象
│   │   └── .claude/
│   ├── project-b/          # ✓ .claude/ あり - 管理対象
│   │   └── .claude/
│   └── -archived/          # ✗ 除外 (- で始まる)
│       └── .claude/
├── personal/
│   ├── project-c/          # ✓ .claude/ あり - 管理対象
│   │   └── .claude/
│   ├── .hidden/            # ✗ 除外 (隠しディレクトリ)
│   │   └── .claude/
│   └── project-d/          # ✗ .claude/ なし - Claude プロジェクトではない
├── deep/nested/project-e/  # ✓ .claude/ あり - 任意の階層で検出
│   └── .claude/
└── ignored-project/        # ✗ 除外 (.claudemux-ignore)
    ├── .claude/
    └── .claudemux-ignore
```

セッション名はディレクトリ名から導出されます。スペースはハイフンに置換され、英数字とハイフン以外の文字は置換され、先頭/末尾のハイフンは削除されます。サニタイズ後に空文字列となるディレクトリは、ログに警告を出してスキップされます。

## Session System Prompt

各 Claude セッションは、その環境に関するコンテキストを含む `--append-system-prompt` 付きで起動されます:

```
You are running inside tmux session '<session-name>'.
claude-mux version: <version>
[Update available: <new-version> (found <date>). Tell the user and suggest they say "update claude-mux" to update.]
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
- When user says: ready — respond with "Session ready!" on one line. Nothing else.
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
- When user says: update claude-mux — warns about restart, gets confirmation, then runs --update and --restart

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
  --update                    Update claude-mux to the latest version
  -a                          Start ALL sessions (use with caution)

GitHub SSH accounts configured in ~/.ssh/config: <accounts>.
```

(更新行はオプションです — アップデートが利用可能なときのみ表示されます。)

`ALLOW_CROSS_SESSION_CONTROL=true` の場合、send コマンドの説明が変わり、自身だけでなく任意のセッションを対象に取れるようになります。パスは起動時のスクリプトの絶対パスで、セッションは `PATH` に依存しません。

## CLI リファレンス

セッション内では Claude がこれらを代わりに実行してくれるため、直接使う機会はほとんどありません。スクリプト/自動化用途や、セッション外で操作する場合に利用できます。

```bash
# 起動してアタッチ
claude-mux                       # カレントディレクトリで Claude を起動してアタッチ
claude-mux ~/projects/my-app     # 指定ディレクトリで Claude を起動してアタッチ
claude-mux -d ~/projects/my-app  # 同上 (明示形式)
claude-mux -t my-app             # 既存の tmux セッションにアタッチ

# 新規プロジェクトの作成
claude-mux -n ~/projects/app     # 新規 Claude プロジェクトを作成してアタッチ
claude-mux -n ~/new/path/app -p  # 同上、必要なら親ディレクトリも作成
claude-mux -n ~/app --template web        # 特定の CLAUDE.md テンプレートで新規プロジェクトを作成
claude-mux -n ~/app --no-multi-coder      # AGENTS.md/GEMINI.md シンボリックリンクなしで新規プロジェクトを作成

# セッション管理
claude-mux -l                    # ステータス別にセッションを一覧 (active、running、stopped)
claude-mux -L                    # すべてのプロジェクトを一覧 (active + idle)
claude-mux -L --hidden           # 非表示のプロジェクトのみ一覧表示する
claude-mux -s my-app '/model sonnet'      # セッションにスラッシュコマンドを送信
claude-mux --shutdown my-app              # 特定のセッションをシャットダウン
claude-mux --shutdown                     # 管理対象の全セッションをシャットダウン
claude-mux --shutdown home --force        # 保護された home セッションをシャットダウン
claude-mux --restart my-app              # 特定のセッションを再起動
claude-mux --restart                     # 動作中の全セッションを再起動
claude-mux --permission-mode plan my-app  # plan モードでセッションを再起動
claude-mux -a                    # BASE_DIR 配下の管理対象セッションをすべて起動

# プロジェクトマーカー
claude-mux --hide                    # 現在のプロジェクトを -L 一覧から非表示にする
claude-mux --hide ~/projects/old     # 特定のプロジェクトを非表示にする
claude-mux --show                    # 現在のプロジェクトの非表示を解除する
claude-mux --protect                 # このセッションを誤ったシャットダウンから保護する
claude-mux --unprotect               # 保護を解除する
claude-mux --delete ~/projects/old           # プロジェクトフォルダをシステムゴミ箱に移動する (macOS)
claude-mux --delete ~/projects/old --yes     # 同上、確認プロンプトをスキップ

# その他
claude-mux --commands            # CLI リファレンス全体を表示
claude-mux --config-help         # デフォルト値と説明付きですべての設定オプションを表示
claude-mux --list-templates      # 利用可能な CLAUDE.md テンプレートを表示
claude-mux --guide               # セッション内で使う会話コマンド一覧を表示
claude-mux --install          # 対話型セットアップ: config + LaunchAgent
claude-mux --update           # 最新バージョンに更新
claude-mux --dry-run             # 実行せずアクションをプレビュー
claude-mux --version             # バージョンを表示
claude-mux --help                # すべてのオプションを表示

# ログを監視
tail -f ~/Library/Logs/claude-mux.log
```

ターミナルから実行するとリアルタイムで stdout にも出力されます。LaunchAgent 経由で実行された場合はログファイルにのみ出力されます。

## トラブルシューティング

### セッションに「Not logged in · Run /login」と表示される

これは初回起動時に macOS のキーチェーンがロックされている場合に発生します (ログイン後にキーチェーンがアンロックされる前にスクリプトが動くケースで一般的)。修正方法:

```bash
# 通常のターミナルでキーチェーンをアンロック
security unlock-keychain

# その後、動作中の任意のセッションで認証を完了
claude-mux -t <any-session>
# /login を実行してブラウザフローを完了
```

一度認証を完了すれば、全セッションを kill して再起動するだけで、保存された認証情報を自動的に拾います。

### Claude Code Remote にセッションが表示されない

セッションは認証済みでなければなりません ("Not logged in" が表示されていないこと)。クリーンに認証された起動の後、数秒以内に RC のリストに表示されるはずです。

### tmux 内での複数行入力

`/terminal-setup` コマンドは tmux 内では動作しません。claude-mux はデフォルトで tmux の `extended-keys` を有効化しているため (`TMUX_EXTENDED_KEYS=true`)、現代的な多くのターミナルで Shift+Enter をサポートします。Shift+Enter が動作しない場合は、プロンプトで `\` + Return を使って改行を入力してください。

### セッション開始時の「Ready.」

セッションが起動または再起動すると、Claude の読み込み完了後に claude-mux が自動的に `ready` メッセージを送信します。注入された指示により、Claude は「Ready.」とだけ返答します。これでセッションが生きており、注入が機能していることを確認できます。

### Remote Control 経由のスラッシュコマンド

スラッシュコマンド (例: `/model`、`/clear`) は RC セッションでは[ネイティブにサポートされていません](https://github.com/anthropics/claude-code/issues/30674)。claude-mux はこれを回避します。各セッションには `claude-mux -s` が注入されており、Claude が tmux 経由で自身にスラッシュコマンドを送信できます。

## ログ

- `~/Library/Logs/claude-mux.log` - すべてのスクリプトアクションを UTC タイムスタンプで記録 (`LOG_DIR` で設定可能)

LaunchAgent の低レベルなデバッグには Console.app または `log show` を使用してください。
