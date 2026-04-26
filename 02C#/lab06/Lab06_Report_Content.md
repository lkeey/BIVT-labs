# СОДЕРЖИМОЕ ДЛЯ ОТЧЕТА LAB06
## Лабораторная работа №6: Делегаты и события в C#

---

## КРАТКОЕ ОПИСАНИЕ

Приложение "Менеджер задач" демонстрирует все ключевые механизмы работы с делегатами и событиями в C#:
- Собственные делегаты (TaskFilter, NotifyHandler)
- Multicast-делегаты для множественных уведомлений
- Лямбда-выражения для компактной записи логики
- Стандартные делегаты (Action<T>, Func<T, TResult>, Predicate<T>)
- События и паттерн "издатель-подписчик"
- LINQ для фильтрации и статистики

---

## ФАЙЛЫ ДЛЯ СКРИНШОТОВ В ОТЧЕТЕ

1. **TaskItem.cs** (26 строк) - модель задачи
2. **TaskEventArgs.cs** (18 строк) - аргументы события
3. **TaskManager.cs** (41 строка) - менеджер с событиями
4. **MainWindow.axaml** (~90 строк) - XAML интерфейс
5. **MainWindow.axaml.cs** (~200 строк) - логика с делегатами

---

## РЕКОМЕНДУЕМЫЕ СКРИНШОТЫ РАБОТЫ

1. **Начальное состояние** - пустой список, статистика "Всего: 0"
2. **Добавление задач** - 5-6 задач с разными приоритетами
3. **Журнал событий** - записи о добавлении задач с временем
4. **Фильтр "Выполненные"** - только выполненные задачи
5. **Фильтр "Высокий приоритет"** - задачи с приоритетом 4-5
6. **Статистика** - полная: всего/выполнено/осталось/средний приоритет/процент
7. **Отключение уведомлений** - CheckBox выключен
8. **Разные состояния задач** - mix выполненных и невыполненных

---

## КЛЮЧЕВЫЕ ФРАГМЕНТЫ КОДА ДЛЯ ОТЧЕТА

### 1. Объявление делегатов
```csharp
// Собственные делегаты
delegate bool TaskFilter(TaskItem task);
delegate void NotifyHandler(string message);
```

### 2. Multicast-делегат
```csharp
// Создание цепочки методов
notifyHandlers = LogToListBox;
notifyHandlers += ShowInStatusBar;

// Вызов - сработают ОБА метода
notifyHandlers?.Invoke("Задача добавлена");
```

### 3. Событие
```csharp
// Объявление события
public event EventHandler<TaskEventArgs> TaskChanged;

// Генерация события
TaskChanged?.Invoke(this, new TaskEventArgs(task, "Добавлена"));

// Подписка
taskManager.TaskChanged += OnTaskChanged;
```

### 4. Лямбда-выражения
```csharp
// Фильтры через лямбда
Func<int> getTotal = () => tasks.Count;
Func<int> getDone = () => tasks.Count(t => t.IsDone);

// LINQ с лямбда
var sorted = allTasks
    .Where(t => filter(t))
    .OrderBy(t => t.IsDone)
    .ThenByDescending(t => t.Priority)
    .ToList();
```

### 5. Стандартные делегаты
```csharp
// Func<T> - возвращает значение
Func<int> getTotal = () => tasks.Count;

// Action<T> - не возвращает значение
Action<string> updateLabel = text => labelStats.Text = text;

// Predicate<T> - возвращает bool (используется неявно в LINQ)
```

### 6. LINQ статистика
```csharp
double avgPriority = tasks.Average(t => (double)t.Priority);
double donePercent = tasks.Count(t => t.IsDone) * 100.0 / tasks.Count();

var byPriority = tasks
    .GroupBy(t => t.Priority)
    .OrderBy(g => g.Key)
    .Select(g => $"[{g.Key}]:{g.Count()}")
    .ToList();
```

---

## СТРУКТУРА ОТЧЕТА

1. **Титульный лист**
2. **Цель работы** (из задания)
3. **Задание** (базовое + усложненное)
4. **План работы** (см. Lab06_Plan_And_Conclusion.md)
5. **Код классов предметной области** (TaskItem, TaskEventArgs, TaskManager)
6. **Код GUI** (XAML + code-behind с делегатами)
7. **Скриншоты работы приложения** (8 скриншотов)
8. **Вывод** (см. Lab06_Plan_And_Conclusion.md)
9. **Ответы на контрольные вопросы**

---

## КОНТРОЛЬНЫЕ ВОПРОСЫ (КРАТКИЕ ОТВЕТЫ)

1. **Что такое делегат?** - Тип данных, хранящий ссылку на метод с определенной сигнатурой
2. **Multicast-делегат** - Делегат, содержащий список методов, вызываемых последовательно
3. **Action/Func/Predicate** - Стандартные делегаты: Action (void), Func (возвращает значение), Predicate (bool)
4. **Лямбда-выражение** - Компактная форма анонимного метода: `x => x * 2`
5. **Ключевое слово event** - Ограничивает доступ к делегату: вызов только изнутри класса
6. **Паттерн издатель-подписчик** - Один объект генерирует события, другие подписываются и реагируют
7. **LINQ и делегаты** - LINQ использует Func<T, bool> в Where, Func<T, TKey> в OrderBy и т.д.

---

**Дата создания:** 26 апреля 2026  
**Вариант:** Усложненное задание (+4 балла)
