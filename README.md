# BIVT Labs

Учебный монорепозиторий: лабораторные и курсовые работы по нескольким
дисциплинам хранятся в одном Git-репозитории и разделены по каталогам.
Изменения публикуются через pull request; правила для участников описаны в
[CONTRIBUTING.md](CONTRIBUTING.md), инструкции для агентов — в
[AGENTS.md](AGENTS.md) и более близких к проекту файлах `AGENTS.md`.

## Карта репозитория

| Каталог | Содержание и границы |
| --- | --- |
| [`01Py/`](01Py/README.md) | Python, лабораторные 01–10: код в `src/`, общая библиотека, тесты, учебные данные и скриншоты. |
| [`02C#/`](02C%23/) | C#, лабораторные 01–11. Каждая работа содержит отдельные .NET-проекты; `RUN_LABS.sh` запускает часть GUI-работ 05–09. |
| [`03SQL/`](03SQL/README.md) | SQL-лабораторные: T-SQL-работы 01–03 и 05 используют `AdventureWorksLT2019`; отдельный семинар 04 использует PostgreSQL 16. |
| [`03SQL-CourseWork/`](03SQL-CourseWork/README.md) | Курсовая на T-SQL и SQL Server 2025 с SQL Graph; отдельная PostgreSQL-копия для публичной демонстрации, общий Go API, Python обработчик и JavaScript-сайт. Среда не смешивается с `03SQL`. |
| [`03TechnologiesOfProgramming/`](03TechnologiesOfProgramming/README.md) | Kotlin/JVM, лабораторные 01–07 в одном Gradle-проекте. |
| [`.agents/skills/`](.agents/skills/sql-coursework/SKILL.md) | Узкие повторяемые процедуры для агентских задач; сейчас здесь Skill для курсовой. Общие постоянные правила хранятся в `AGENTS.md`. |
| `.github/` | GitHub Actions и шаблоны pull request. |
| `.githooks/` | Локальные Git hooks; подключаются скриптом из `scripts/`. |
| `scripts/` | Вспомогательные скрипты репозитория, включая настройку hooks. |

Каталоги дисциплин принадлежат своим лабораторным и курсовым проектам.
Изменяйте только нужный каталог и связанные с ним документы; общие файлы
репозитория меняйте, когда это необходимо для нескольких проектов.

## Команды проектов

Команды ниже запускаются из корня репозитория, если не сказано иное.

### Python

```bash
cd 01Py
python3 -m pip install -r requirements.txt
python3 -m pytest
python3 -m ruff check .
python3 -m black --check .
```

### C#

В `02C#/` нет единой сборки всех лабораторных: выберите `.csproj` нужной
работы. Корневой `BIVT-labs.sln` не является общей сборкой монорепозитория.
Например:

```bash
dotnet build "02C#/lab01/Level01/Level1.csproj"
dotnet run --project "02C#/lab05/GeometryGUI/GeometryGUI.csproj"
```

Интерактивный сценарий для лабораторных 05–09 можно запустить из каталога
`02C#`:

```bash
cd "02C#"
./RUN_LABS.sh
```

### SQL

Для среды SQL Server лабораторных 01–03 и 05 нужны Docker Desktop и настройки
из `03SQL/docker/README.md`:

```bash
cd 03SQL/docker
colima start --profile sqlserver
./scripts/setup.sh
```

Для курсовой инструкции и T-SQL-скрипты находятся в
[`03SQL-CourseWork/`](03SQL-CourseWork/). Семинар PostgreSQL описан в
[`03SQL/lab04/README.md`](03SQL/lab04/README.md) и использует отдельный
контейнер.

### Kotlin

```bash
cd 03TechnologiesOfProgramming
./gradlew build
./gradlew :lab02:run
./gradlew :lab06:test
```

Другие команды, включая запуск отдельных лабораторных, приведены в
[`03TechnologiesOfProgramming/README.md`](03TechnologiesOfProgramming/README.md).

## Pull requests и локальная настройка

После клонирования можно включить локальную проверку staged-файлов:

```bash
./scripts/setup-git-hooks.sh
```

Hook и GitHub Actions блокируют часть типичных сгенерированных файлов; правила
хранения локальных данных и порядок проверки изменений описаны в
[CONTRIBUTING.md](CONTRIBUTING.md). Перед отправкой ветки сверяйте затронутые
проекты и проверки в шаблоне pull request.
