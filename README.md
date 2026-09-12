# Gitleaks Pre-Commit Hook

Git `pre-commit` hook для автоматичної перевірки staged changes на наявність секретів за допомогою [Gitleaks](https://github.com/gitleaks/gitleaks).

Hook запускається перед створенням commit і блокує його, якщо Gitleaks знаходить потенційний secret.

## Можливості

- Git `pre-commit` hook
- перевірка тільки staged changes
- автоматичний запуск Gitleaks перед commit
- блокування commit при виявленні secret
- використання `--redact` для приховування secret у terminal output
- enable/disable через `git config`
- автоматичне встановлення Gitleaks
- підтримка Linux
- підтримка macOS
- підтримка Windows Git Bash
- підтримка `amd64/x86_64`
- підтримка `arm64`
- pinned Gitleaks version
- перевірка SHA256 release artifact
- bootstrap installation через `curl | sh`
- використання built-in Gitleaks rules, включно з detection Telegram Bot API Token

## Структура репозиторію

```text
.
├── .gitleaks.toml
├── hooks/
│   └── pre-commit
├── scripts/
│   └── install-gitleaks.sh
├── install.sh
└── README.md
```

## Архітектура

```text
git commit
    |
    v
hooks/pre-commit
    |
    +-- git config gitleaks.enabled
    |       |
    |       +-- false --> commit дозволено
    |
    v
Gitleaks доступний?
    |
    +-- system binary
    |
    +-- .git/tools/gitleaks
    |
    v
gitleaks git --staged --redact
    |
    +-- secret не знайдено --> commit дозволено
    |
    +-- secret знайдено --> commit відхилено
```

## Встановлення

Клонувати репозиторій:

```bash
git clone https://github.com/visys-dev/gitleaks-precommit-hook.git
cd gitleaks-precommit-hook
```

Запустити bootstrap installer:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/visys-dev/gitleaks-precommit-hook/main/install.sh \
  | sh
```

Installer налаштовує:

```bash
git config --local core.hooksPath hooks
git config --local gitleaks.enabled true
```

і встановлює Gitleaks у:

```text
.git/tools/gitleaks
```

Для Windows Git Bash:

```text
.git/tools/gitleaks.exe
```

## Увімкнення hook

```bash
git config --local gitleaks.enabled true
```

Перевірка:

```bash
git config --local --get gitleaks.enabled
```

Очікуваний результат:

```text
true
```

## Вимкнення hook

```bash
git config --local gitleaks.enabled false
```

Перевірка:

```bash
git config --local --get gitleaks.enabled
```

Очікуваний результат:

```text
false
```

## Перевірка hooks path

```bash
git config --local --get core.hooksPath
```

Очікуваний результат:

```text
hooks
```

## Автоматичне встановлення Gitleaks

Gitleaks встановлюється за допомогою:

```text
scripts/install-gitleaks.sh
```

Installer виконує:

1. визначення OS
2. визначення CPU architecture
3. завантаження pinned release Gitleaks
4. завантаження офіційного checksum-файлу
5. SHA256 verification
6. розпакування binary
7. встановлення у `.git/tools`

Поточна pinned version:

```text
8.30.1
```

Перевірка:

```bash
.git/tools/gitleaks version
```

Очікуваний результат:

```text
8.30.1
```

## Робота pre-commit hook

Hook виконує:

```bash
gitleaks git \
  --staged \
  --redact \
  --verbose
```

Параметр:

```text
--staged
```

обмежує scan лише змінами, які підготовлені до commit.

Параметр:

```text
--redact
```

не дозволяє виводити повне значення знайденого secret у terminal output.

## Тест clean commit

Створити безпечний файл:

```bash
echo "test" > clean.txt
git add clean.txt
git commit -m "test: clean commit"
```

Очікуваний результат:

```text
[gitleaks] Pre-commit secret scan
[gitleaks] Using: .git/tools/gitleaks
...
no leaks found
[gitleaks] No secrets detected.
```

Commit створюється успішно.

## Тест Telegram Bot Token

Для перевірки необхідно використовувати тільки synthetic token.

Приклад:

```bash
cat > telegram.env <<'EOF'
TELEGRAM_BOT_TOKEN=<TELEGRAM_BOT_TOKEN_FOR_TEST>
EOF
```

Додати файл у staging:

```bash
git add telegram.env
```

Перевірити staged diff:

```bash
git diff --cached
```

Спробувати виконати commit:

```bash
git commit -m "test: telegram bot token"
```

Очікуваний результат:

```text
Finding:     TELEGRAM_BOT_TOKEN=REDACTED
Secret:      REDACTED
RuleID:      telegram-bot-api-token
File:        telegram.env

ERROR: Gitleaks detected a potential secret.
Commit rejected.
Remove the secret and stage the changes again.
```

Commit не повинен бути створений.

Після тесту видалити тестовий файл:

```bash
git restore --staged telegram.env
rm telegram.env
```

## Ручна перевірка

Перевірка Git history:

```bash
.git/tools/gitleaks git \
  --redact \
  --verbose \
  .
```

Перевірка директорії:

```bash
.git/tools/gitleaks dir \
  --config .gitleaks.toml \
  --redact \
  --verbose \
  .
```

## Валідація shell scripts

Перевірити syntax:

```bash
sh -n hooks/pre-commit
sh -n install.sh
sh -n scripts/install-gitleaks.sh
```

Перевірити staged diff на whitespace errors:

```bash
git diff --cached --check
```

Запустити hook вручну:

```bash
git hook run pre-commit
```

## Перевірка Git configuration

Показати активну конфігурацію:

```bash
git config --show-origin --get core.hooksPath
git config --show-origin --get gitleaks.enabled
```

Приклад:

```text
file:.git/config        hooks
file:.git/config        true
```

## Security

У рішенні реалізовані такі security controls:

- Gitleaks version pinned
- release artifact перевіряється через SHA256
- не використовується `sudo`
- Gitleaks встановлюється repository-local
- secret не виводиться повністю завдяки `--redact`
- під час commit перевіряються тільки staged changes
- detection secret повертає non-zero exit code
- commit блокується при виявленні secret
- стандартний Gitleaks ruleset залишається активним

Client-side Git hook технічно можна обійти командою:

```bash
git commit --no-verify
```

Тому для production-середовища pre-commit hook потрібно дублювати в CI/CD або server-side policy.

Рекомендована defense-in-depth схема:

```text
Developer workstation
        |
        v
pre-commit Gitleaks
        |
        v
Git remote
        |
        v
CI Gitleaks scan
        |
        v
Merge / deployment
```

## Результати перевірки

Рішення протестовано з:

```text
Git:       2.53.0
Gitleaks:  8.30.1
OS:        Linux x86_64
```

Перевірені сценарії:

```text
Clean staged changes           PASS
Pre-commit execution           PASS
Gitleaks staged scan           PASS
Telegram token detection       PASS
Secret redaction               PASS
Commit rejection               PASS
Git config enable              PASS
OS/architecture detection      PASS
SHA256 verification            PASS
```

## Репозиторій

```text
https://github.com/visys-dev/gitleaks-precommit-hook
```