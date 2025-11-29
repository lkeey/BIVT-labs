# Лабораторная работа 9 — «База данных» на CSV: класс `Group`, CRUD-операции и CLI

## Цель работы
Реализовать простейшее хранилище данных студентов на основе CSV-файла, отработать CRUD-операции (Create / Read / Update / Delete) и научиться работать с ними через отдельный класс `Group`.

## Структура проекта
```
python_labs/
├─ src/
│   └─ lab09/
│       ├─ group.py          # класс Group + CRUD
│       ├─ test_group.py     # тестирование класса Group
│       └─ __init__.py
├─ data/
│   └─ lab09/
│       └─ students.csv      # «база данных» студентов
└─ images/
    └─ lab09/                # скриншоты работы
```

## Реализация

### Класс `Group`
Класс `Group` реализует CRUD-операции над студентами:

#### Методы:
- `__init__(storage_path)` — инициализация группы и файла-хранилища
- `list()` — вернуть **всех** студентов в виде списка `Student`
- `add(student)` — добавить нового студента в CSV
- `find(substr)` — найти студентов по подстроке в `fio`
- `remove(fio)` — удалить запись(и) с данным `fio`
- `update(fio, **fields)` — обновить поля существующего студента
- `stats()` — получить статистику по группе (дополнительное задание)

#### Внутренние вспомогательные методы:
- `_read_all()` — прочитать все строки из CSV
- `_write_all(rows)` — записать все строки в CSV
- `_ensure_storage_exists()` — создать файл с заголовком, если его ещё нет

## Примеры использования

### Создание экземпляра группы
```python
from src.lab09.group import Group

group = Group("data/lab09/students.csv")
```

### Получение списка всех студентов
```python
students = group.list()
for student in students:
    print(student)
```

### Добавление нового студента
```python
from src.lab08.models import Student

new_student = Student(
    fio="Смирнов Алексей Владимирович",
    birthdate="2003-03-22",
    group="БИВТ-21-3",
    gpa=4.1
)
group.add(new_student)
```

### Поиск студентов
```python
# Найти студентов с "Иванов" в ФИО
found_students = group.find("Иванов")
```

### Обновление данных студента
```python
# Обновить GPA у студента
group.update("Иванов Иван Иванович", gpa=4.8)
```

### Удаление студента
```python
# Удалить студента по ФИО
removed_count = group.remove("Сидоров Сидор Сидорович")
```

### Получение статистики (дополнительное задание)
```python
stats = group.stats()
print(f"Всего студентов: {stats['count']}")
print(f"Минимальный GPA: {stats['min_gpa']}")
print(f"Максимальный GPA: {stats['max_gpa']}")
print(f"Средний GPA: {stats['avg_gpa']}")
```

Пример вывода статистики:
```json
{
  "count": 6,
  "min_gpa": 3.5,
  "max_gpa": 4.9,
  "avg_gpa": 4.3,
  "groups": {
    "БИВТ-21-1": 2,
    "БИВТ-21-2": 2,
    "БИВТ-21-3": 2
  },
  "top_5_students": [
    {"fio": "Морозова Анна Сергеевна", "gpa": 4.9},
    {"fio": "Иванов Иван Иванович", "gpa": 4.8},
    {"fio": "Сидоров Сидор Сидорович", "gpa": 4.7},
    {"fio": "Смирнов Алексей Владимирович", "gpa": 4.1},
    {"fio": "Петров Петр Петрович", "gpa": 3.8}
  ]
}
```

## Формат CSV-файла
Файл хранится по пути `data/lab09/students.csv`.

Структура:
```csv
fio,birthdate,group,gpa
Иванов Иван Иванович,2003-10-10,БИВТ-21-1,4.3
Петров Петр Петрович,2002-05-15,БИВТ-21-2,3.8
...
```

## Тестирование
Для проверки работы реализации запустите тестовый скрипт:
```bash
python3 src/lab09/test_group.py
```

## Скриншоты работы
Скриншоты работы программы находятся в каталоге `images/lab09/`.

### Get and Add Methods
![Get and Add Methods](../../images/lab09/get_add_methods.png)

### Search, Update, and Delete Methods
![Search, Update, and Delete Methods](../../images/lab09/search_update_delete_methods.png)

### Statistics and Export to JSON
![Statistics and Export to JSON](../../images/lab09/statistics_export2json.png)