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
- автоматичне встановлення Gitleaks безпосередньо з `pre-commit` hook
- bootstrap installation через `curl | sh`
- repo-local Gitleaks має пріоритет над system binary
- pinned Gitleaks version
- перевірка SHA256 release artifact
- підтримка Linux
- реалізована логіка для macOS
- реалізована логіка для Windows Git Bash
- підтримка `amd64/x86_64`
- підтримка `arm64`
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
    +-- .git/tools/gitleaks
    |       |
    |       +-- так --> використати pinned repo-local binary
    |
    +-- system gitleaks у PATH
    |       |
    |       +-- так --> використати system binary
    |
    +-- binary відсутній
            |
            v
        curl installer | sh
            |
            v
        .git/tools/gitleaks
            |
            v
gitleaks git --staged --redact --verbose
    |
    +-- secret не знайдено --> commit дозволено
    |
    +-- secret знайдено --> commit відхилено
```

## Prerequisites

Потрібні:

- Git
- `curl`
- POSIX-compatible shell
- `tar` для Linux/macOS
- `unzip` для Windows Git Bash
- `sha256sum` або `shasum` для SHA256 verification

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

та зберігає URL installer:

```bash
git config --local gitleaks.installerUrl \
  https://raw.githubusercontent.com/visys-dev/gitleaks-precommit-hook/main/scripts/install-gitleaks.sh
```

Gitleaks встановлюється repository-local у:

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

При вимкненому hook commit не сканується:

```text
[gitleaks] Pre-commit secret scan
[gitleaks] Disabled via git config.
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

Якщо repo-local binary відсутній, `pre-commit` hook автоматично запускає installer:

```text
[gitleaks] Gitleaks not found.
[gitleaks] Installing automatically...
Installing Gitleaks v8.30.1
Platform: linux/x64
SHA256 verification: OK
Installed:
8.30.1
```

Після встановлення scan продовжується автоматично.

## Пріоритет Gitleaks binary

Hook використовує Gitleaks у такому порядку:

```text
1. .git/tools/gitleaks
2. system gitleaks із PATH
3. automatic installation у .git/tools
```

Таким чином pinned repo-local binary має пріоритет над глобально встановленою версією.

Приклад:

```text
[gitleaks] Using: .git/tools/gitleaks
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

обмежує scan змінами, які вже додані до Git index і будуть включені в наступний commit.

Параметр:

```text
--redact
```

не дозволяє виводити повне значення знайденого secret у terminal output.

Параметр:

```text
--verbose
```

виводить детальну інформацію про результат scan.

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

Після тесту:

```bash
git rm clean.txt
git commit -m "chore: remove test file"
```

## Тест Telegram Bot Token

Для перевірки необхідно використовувати тільки synthetic token.

Щоб сам README не містив рядок, який Gitleaks визначить як secret, test token формується під час виконання команд із двох частин:

```bash
BOT_ID='123456789'
BOT_SECRET='AAGitleaksTestToken1234567890abcdef'

printf 'TELEGRAM_BOT_TOKEN=%s:%s\n' \
  "$BOT_ID" \
  "$BOT_SECRET" \
  > telegram.env
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
[gitleaks] Pre-commit secret scan
[gitleaks] Using: .git/tools/gitleaks

Finding:     TELEGRAM_BOT_TOKEN=REDACTED
Secret:      REDACTED
RuleID:      telegram-bot-api-token
File:        telegram.env

ERROR: Gitleaks detected a potential secret.
Commit rejected.
Remove the secret and stage the changes again.
```

Commit не повинен бути створений.

Після тесту:

```bash
git restore --staged telegram.env
rm telegram.env
```

## Тест автоматичного встановлення з hook

Видалити repo-local Gitleaks:

```bash
rm -f .git/tools/gitleaks
```

Перевірити:

```bash
test ! -f .git/tools/gitleaks && echo "Gitleaks binary removed"
```

Створити harmless staged change:

```bash
echo "auto-install-test" > auto-install-test.txt
git add auto-install-test.txt
```

Виконати commit:

```bash
git commit -m "test: verify hook auto-install"
```

Очікується:

```text
[gitleaks] Gitleaks not found.
[gitleaks] Installing automatically...
Installing Gitleaks v8.30.1
Platform: linux/x64
SHA256 verification: OK
Installed:
8.30.1
[gitleaks] Using: .git/tools/gitleaks
...
[gitleaks] No secrets detected.
```

Після тесту:

```bash
git rm auto-install-test.txt
git commit -m "chore: remove auto-install test file"
```

## Ручна перевірка

Перевірка Git history:

```bash
.git/tools/gitleaks git \
  --redact \
  --verbose \
  .
```

Очікуваний результат для чистого repository:

```text
no leaks found
```

Перевірка директорії:

```bash
.git/tools/gitleaks dir \
  --config .gitleaks.toml \
  --redact \
  --verbose \
  .
```

## Gitleaks configuration

Файл:

```text
.gitleaks.toml
```

містить:

```toml
title = "Gitleaks configuration"

[extend]
useDefault = true
```

`useDefault = true` залишає активним стандартний Gitleaks ruleset, включно з built-in detection для Telegram Bot API Token.

## Валідація shell scripts

Перевірити syntax:

```bash
sh -n hooks/pre-commit
sh -n install.sh
sh -n scripts/install-gitleaks.sh
```

Успішна перевірка повинна завершитися з exit code `0`.

Наприклад:

```bash
sh -n hooks/pre-commit
echo $?
```

Очікувано:

```text
0
```

Перевірити staged diff на whitespace errors:

```bash
git diff --cached --check
```

При відсутності помилок команда нічого не виводить.

Запустити hook вручну:

```bash
git hook run pre-commit
```

## Перевірка Git configuration

Показати активну конфігурацію:

```bash
git config --show-origin --get core.hooksPath
git config --show-origin --get gitleaks.enabled
git config --show-origin --get gitleaks.installerUrl
```

Приклад:

```text
file:.git/config        hooks
file:.git/config        true
file:.git/config        https://raw.githubusercontent.com/visys-dev/gitleaks-precommit-hook/main/scripts/install-gitleaks.sh
```

## Security

У рішенні реалізовані такі security controls:

- Gitleaks version pinned
- release artifact перевіряється через SHA256
- не використовується `sudo`
- Gitleaks встановлюється repository-local
- repo-local binary має пріоритет над system binary
- secret не виводиться повністю завдяки `--redact`
- під час commit перевіряються тільки staged changes
- detection secret повертає non-zero exit code
- commit блокується при виявленні secret
- стандартний Gitleaks ruleset залишається активним
- installation failure блокує виконання hook

Client-side Git hook технічно можна обійти командою:

```bash
git commit --no-verify
```

Тому для production-середовища `pre-commit` hook потрібно дублювати в CI/CD або server-side Git policy.

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

### Supply-chain consideration

Використання:

```bash
curl ... | sh
```

є вимогою цього завдання, але має inherent supply-chain risk.

Поточний installer завантажується з:

```text
raw.githubusercontent.com/.../main/...
```

тобто branch `main` є mutable reference.

Для production-рішення рекомендовано:

- використовувати immutable Git tag або commit SHA для installer URL
- контролювати integrity самого bootstrap script
- дублювати secret scanning у CI/CD
- використовувати branch protection / required checks

Release artifact самого Gitleaks перевіряється через офіційний SHA256 checksum перед встановленням.

## Результати перевірки

Рішення фактично протестовано з:

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
Git config enable/disable      PASS
OS/architecture detection      PASS
SHA256 verification            PASS
Hook automatic installation    PASS
Repo-local binary priority     PASS
curl | sh bootstrap            PASS
Git history scan               PASS
```

Для macOS та Windows Git Bash реалізована відповідна OS-specific логіка, але фактичний acceptance test у межах цього завдання виконано на Linux x86_64.

## Репозиторій

https://github.com/visys-dev/gitleaks-precommit-hook