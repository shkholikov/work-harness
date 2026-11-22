# Copilot CLI: шпаргалка

Для Windows + PowerShell 7, без прав администратора, Copilot Business/Enterprise,
оплата токенами (AI Credits), бюджет $50/месяц.

Источник: исходники docs.github.com (репо `github/docs`) на 2026-11-22, CLI 1.0.114.
CLI обновляется почти каждый день: сверяй с `/help`, `copilot help` и `/changelog`.

## 1. Деньги: как считается

- С 2026-06-01 оплата по токенам: **1 AI Credit = $0.01**, твои $50 = 5 000 credits.
- Цена = (вход + кэш + выход) × цена модели. Выход дороже входа примерно в 5 раз.
- Длинная сессия = каждый ход заново отправляет весь контекст (частично из кэша). Чем короче сессия, тем дешевле.
- **Бесплатно и безлимитно:** автодополнение и Next Edit Suggestions в VS Code.
- Минимальная версия CLI для правильного учёта: 1.0.48.

| Модель | Когда | Вход / Кэш / Выход за 1M |
|---|---|---|
| Claude Haiku 5.5, GPT-6 Luna | вопросы, объяснения, мелочи | $0.10 / $0.01 / $0.50 |
| GPT-6.1 Terra | обычная работа, дешевле Sonnet | $1 / $0.05 / $5 |
| Claude Sonnet 5.5 | обычная агентная работа (по умолчанию) | $2 / $0.10 / $10 |
| Claude Opus 5.5 | сложная отладка, дизайн | $4 / $0.20 / $20 |
| Claude Fable 5.2 | почти никогда | $8 / $0.20 / $40 |

Какие модели доступны, решает политика организации. Проверь через `/model`.

## 2. Команды, которые экономят деньги

| Команда | Что делает |
|---|---|
| `/model` | Сменить модель для текущей сессии. `--global` / `--repo` сохраняет выбор. `auto efficiency\|balance\|intelligence` включает автовыбор |
| `/usage` | Расход токенов и AI Credits по моделям |
| `/limits set max-ai-credits N` | Мягкий лимит на один ответ (сбрасывается с каждым твоим сообщением) |
| `/context` | Что занимает контекст: инструкции, MCP-инструменты, сообщения |
| `/compact [фокус]` | Сжать историю (автоматически при ~80% окна) |
| `/clear`, `/new` | Новая задача = новый разговор |
| `/ask`, `/btw` | Побочный вопрос, не попадает в историю |
| `!команда` | Запустить в shell **без** добавления вывода в контекст |
| `/resume`, `--continue` | Вернуться к прошлой сессии |

Дорого: `/fleet` (параллельные субагенты), autopilot без лимита, `/delegate` (облачный агент), длинный контекст (`Tab` в выборе модели).

## 3. Режимы

`Shift+Tab` переключает режимы: обычный → plan → autopilot.

- **Plan** (`/plan задача` или `--plan`): правки проекта заблокированы, агент задаёт вопросы и пишет `plan.md`, ждёт одобрения. `Ctrl+Y` редактирует план. Для задач на несколько файлов.
- **Autopilot** (`/autopilot цель` = `/goal`): работает до конца задачи. **Всегда с лимитом:** `/goal цель --max-ai-credits 200`.
- Связка: `copilot --plan --mode autopilot`: сначала план, после одобрения выполнение.

## 4. Права (строже, чем в Claude)

Режимы: `/permissions default|assisted|allow-all|show|reset`. Работай в `default` (ручное подтверждение).

Шаблон: `Kind(arg)`. **Deny всегда сильнее allow**, даже при `--allow-all`.

```powershell
copilot --allow-tool='shell(git status),shell(git diff:*),shell(git log:*)' `
        --deny-tool='shell(git push),shell(oc apply),shell(oc delete),shell(argocd app sync),shell(vault)'
```

- `shell(git:*)`: `git` и любые подкоманды (`:*` = команда + пробел, `gitea` не попадает).
- `write`, `write(src/*.ts)`, `read(.env)`, `url(github.com)`, `ИмяMCP(инструмент)`.
- На Windows shell-инструмент называется `powershell`.
- В диалоге подтверждения: `y` один раз, `n` нет, `!` разрешить похожее на сессию, `#` запретить похожее на сессию.
- **Никогда:** `--allow-all`, `--yolo`, `/allow-all`.

## 5. Ввод и клавиши

| Ввод | Что делает |
|---|---|
| `@файл` | Добавить файл в контекст |
| `#123` | Issue или PR |
| `!cmd` | Shell без контекста |
| `$` | Настоящий shell (`%COMSPEC%`) |
| `?` | Быстрая справка |
| `Esc Esc` | Прервать ход |
| `Ctrl+C` ×2 | Выход |
| `Ctrl+G` | Написать промпт во внешнем редакторе |
| `Ctrl+R` | Поиск по истории |
| `Ctrl+Q` | Поставить сообщение в очередь |
| `Ctrl+T` | Показать или скрыть рассуждения |
| `Alt+Enter` | Новая строка (или `/terminal-setup` для `Shift+Enter`) |
| `Alt+V` | Вставить картинку |

## 6. Где что лежит (Windows)

`C:\Users\<ты>\.copilot\` (меняется через `COPILOT_HOME`):

| Файл/папка | Назначение |
|---|---|
| `settings.json` | Твои настройки (JSONC) |
| `config.json` | Состояние: логин, плагины, trusted folders (руками не править) |
| `permissions-config.json` | Сохранённые разрешения по папкам |
| `mcp-config.json` | MCP-серверы (`mcpServers`, поддерживает `$VAR`) |
| `copilot-instructions.md` | Глобальные инструкции |
| `instructions\*.instructions.md` | Глобальные инструкции по путям (`applyTo`) |
| `agents\` | Твои агенты |
| `skills\<имя>\SKILL.md` | Твои скиллы |
| `hooks\*.json` | Твои хуки |
| `session-state\<id>\` | Сессии, `plan.md`, чекпоинты |
| `logs\` | Логи, можно удалять |

Порядок настроек (последний побеждает): user `settings.json` < `.github/copilot/settings.json` < `.github/copilot/settings.local.json` < переменные окружения < флаги.

Полезные ключи `settings.json` (проверь через `copilot config --list`):

```jsonc
{
  "model": "claude-sonnet-5.5",
  "effortLevel": "medium",
  "defaultPermissionMode": "manual",
  "footer": { "showAiUsed": true, "showQuota": true, "showContextWindow": true }
}
```

## 7. Инструкции, агенты, скиллы, хуки: что совместимо с Claude

| Что | Где читает Copilot CLI | Совместимо с Claude |
|---|---|---|
| Инструкции | `AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`, `.github/copilot-instructions.md`, `.github/instructions/**/*.instructions.md`, `.claude/rules/**/*.md`, `~/.copilot/copilot-instructions.md` | Да, `CLAUDE.md` и `.claude/rules` читаются |
| Агенты | `~/.copilot/agents/` > `.github/agents/` > `.claude/agents/` | Да |
| Скиллы | `.github/skills/`, `.agents/skills/`, `.claude/skills/`, `~/.copilot/skills/` | Да, тот же `SKILL.md` |
| Команды | `.claude/commands/*.md` | Да |
| Хуки | `.github/hooks/*.json`, `~/.copilot/hooks/*.json`, ключ `hooks` в `settings.json` и `.claude/settings.json` | Да, PascalCase-события с Claude-форматом |
| MCP | `~/.copilot/mcp-config.json`, `.mcp.json`, `.github/mcp.json` (папка должна быть trusted) | Да, `.mcp.json` |

Важно:
- Все файлы инструкций **склеиваются**, порядка приоритета нет. Не допускай противоречий.
- После правки инструкций нужна новая сессия (`/new`).
- `/env` показывает, что реально загружено: инструкции, MCP, скиллы, агенты, хуки.
- `/instructions` включает и выключает отдельные файлы.
- Каждый MCP-сервер добавляет описания инструментов в контекст, а значит, в деньги. Подключай только нужные.

## 8. Хуки: замена твоим Claude-хукам

- События: `sessionStart`, `userPromptSubmitted`, `preToolUse`, `postToolUse`, `permissionRequest`, `agentStop`, `preCompact` и другие.
- **`preToolUse` может блокировать:** вернуть `permissionDecision: "deny"` с `permissionDecisionReason`. Хватает одного deny.
- Exit code 2 или падение скрипта = deny. **Таймаут = allow** (fail-open), поэтому хуки должны быть быстрыми.
- `agentStop` с `decision: "block"` заставляет агента продолжить (аналог твоего verify-stop), максимум 8 раз подряд.
- Формат:

```json
{ "version": 1, "hooks": { "preToolUse": [
  { "type": "command", "powershell": "pwsh -NoProfile -File $HOME/.copilot/hooks/guard.ps1", "timeoutSec": 10 }
] } }
```

Git hooks (`pre-push` на main) всё равно оставляем: они работают при любом инструменте.

## 9. Рабочий цикл задачи

1. `/new` и выбор модели (`/model`).
2. Для задач на несколько файлов: `/plan` с полной постановкой (цель, файлы, ограничения, критерий готовности, проверки).
3. Проверить и поправить план, потом выполнять.
4. Проверки детерминированными скриптами (build, tests, `kustomize build`), а не дополнительными агентами.
5. Посмотреть `/usage`, затем `/new` для следующей задачи.
