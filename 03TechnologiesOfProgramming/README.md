# Технологии программирования

Семь лабораторных собраны в одном Gradle-проекте. Модули независимы по
содержанию: каждую лабораторную можно собрать отдельной Gradle-задачей.

## Требования

- JDK 17 или новее;
- Gradle Wrapper из этого каталога;
- для лабораторной №7 база SQLite создаётся при запуске программы.

## Структура

| Модуль | Тема |
|---|---|
| `lab01` | Git и работа с существующим монорепозиторием |
| `lab02` | Иерархия классов пошаговой стратегии |
| `lab03` | Singleton, Factory Method, Abstract Factory, Builder |
| `lab04` | Strategy, Chain of Responsibility, Iterator |
| `lab05` | Proxy, Bridge, Adapter |
| `lab06` | Тестирование BankAccount с mock-зависимостью |
| `lab07` | CRUD для Category и Product через Exposed и SQLite |

## Команды

Из каталога `03TechnologiesOfProgramming`:

```bash
./gradlew build
./gradlew :lab02:run
./gradlew :lab03:run
./gradlew :lab04:run
./gradlew :lab05:run
./gradlew :lab06:test
./gradlew :lab06:run
./gradlew :lab07:run
./gradlew :lab01:verifyLabDocumentation
```

Подробности решения и отчёт по каждой теме находятся в её каталоге.
