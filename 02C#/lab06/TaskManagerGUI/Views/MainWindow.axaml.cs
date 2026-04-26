using Avalonia.Controls;
using Avalonia.Interactivity;
using System;
using System.Linq;

namespace TaskManagerGUI.Views
{
    public partial class MainWindow : Window
    {
        // Собственные делегаты (базовое задание)
        delegate bool TaskFilter(TaskItem task);
        delegate void NotifyHandler(string message);

        // Multicast-делегат для уведомлений
        private NotifyHandler? notifyHandlers;

        // Менеджер задач с событиями
        private TaskManager taskManager;

        // Обработчики событий для возможности отписки
        private EventHandler<TaskEventArgs>? taskChangedHandler;
        private EventHandler<TaskEventArgs>? taskChangedStatsHandler;

        public MainWindow()
        {
            InitializeComponent();

            // Инициализация менеджера
            taskManager = new TaskManager();

            // Создание multicast-делегата
            notifyHandlers = LogToListBox;
            notifyHandlers += ShowInStatusBar;

            // Подписка на события
            taskChangedHandler = OnTaskChanged;
            taskChangedStatsHandler = OnTaskChangedStats;
            
            taskManager.TaskChanged += taskChangedHandler;
            taskManager.TaskChanged += taskChangedStatsHandler;

            // Инициализация
            UpdateStats();
        }

        // ==================== MULTICAST-ДЕЛЕГАТ ====================

        private void LogToListBox(string msg)
        {
            string logMsg = $"{DateTime.Now:HH:mm:ss} - {msg}";
            listBoxLog.Items.Add(logMsg);
            
            // Автопрокрутка вниз
            if (listBoxLog.ItemCount > 0)
            {
                listBoxLog.ScrollIntoView(listBoxLog.Items[listBoxLog.ItemCount - 1]!);
            }
        }

        private void ShowInStatusBar(string msg)
        {
            labelStatus.Text = $"Последнее действие: {msg}";
        }

        // ==================== ФИЛЬТРЫ ====================

        // Методы фильтрации совместимые с делегатом TaskFilter
        private bool FilterAll(TaskItem t) => true;
        private bool FilterDone(TaskItem t) => t.IsDone;
        private bool FilterNotDone(TaskItem t) => !t.IsDone;
        private bool FilterHighPriority(TaskItem t) => t.Priority >= 4;

        private TaskFilter GetCurrentFilter()
        {
            // Защита от вызова до инициализации
            if (comboBoxFilter == null) return FilterAll;
            
            return comboBoxFilter.SelectedIndex switch
            {
                1 => FilterDone,
                2 => FilterNotDone,
                3 => FilterHighPriority,
                _ => FilterAll
            };
        }

        // Применение фильтра с LINQ и лямбда-выражениями
        private void ApplyFilter()
        {
            // Защита от вызова до инициализации
            if (listBoxTasks == null || taskManager == null) return;
            
            TaskFilter filter = GetCurrentFilter();

            // Получаем отфильтрованные и отсортированные задачи через LINQ
            var filtered = taskManager.GetAllTasks()
                .Where(t => filter(t))
                .OrderBy(t => t.IsDone)           // Сначала невыполненные
                .ThenByDescending(t => t.Priority) // Затем по приоритету
                .ToList();

            listBoxTasks.Items.Clear();
            foreach (var task in filtered)
            {
                listBoxTasks.Items.Add(task);
            }
        }

        // ==================== СТАТИСТИКА С FUNC/ACTION ====================

        private void UpdateStats()
        {
            // Защита от вызова до инициализации
            if (labelStats == null || taskManager == null) return;
            
            var tasks = taskManager.GetAllTasks();

            // Использование Func<T> для вычислений
            Func<int> getTotal = () => tasks.Count;
            Func<int> getDone = () => tasks.Count(t => t.IsDone);
            Func<int> getRemaining = () => tasks.Count(t => !t.IsDone);

            // Использование Action<string> для обновления UI
            Action<string> updateLabel = text => labelStats.Text = text;

            int total = getTotal();
            int done = getDone();
            int remaining = getRemaining();

            // Расширенная статистика с LINQ (усложненное задание)
            string statsText = $"Всего: {total} | Выполнено: {done} | Осталось: {remaining}";

            if (total > 0)
            {
                double avgPriority = tasks.Average(t => (double)t.Priority);
                double donePercent = done * 100.0 / total;
                
                var byPriority = tasks
                    .GroupBy(t => t.Priority)
                    .OrderBy(g => g.Key)
                    .Select(g => $"[{g.Key}]:{g.Count()}")
                    .ToList();

                statsText += $" | Ср.приоритет: {avgPriority:F1} | " +
                            $"Выполнено: {donePercent:F0}% | " +
                            $"По приоритетам: {string.Join(" ", byPriority)}";
            }

            updateLabel(statsText);
        }

        // ==================== ОБРАБОТЧИКИ СОБЫТИЙ ====================

        private void OnTaskChanged(object? sender, TaskEventArgs e)
        {
            // Уведомления через multicast-делегат
            if (checkBoxNotify.IsChecked == true && notifyHandlers != null)
            {
                notifyHandlers($"{e.Action}: {e.Task.Name}");
            }
        }

        private void OnTaskChangedStats(object? sender, TaskEventArgs e)
        {
            // Обновление статистики и списка
            UpdateStats();
            ApplyFilter();
        }

        // ==================== ОБРАБОТЧИКИ КНОПОК ====================

        private void OnAddClick(object? sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(textBoxName.Text))
            {
                labelStatus.Text = "Ошибка: Введите название задачи!";
                return;
            }

            TaskItem task = new TaskItem(
                textBoxName.Text,
                (int)(numericPriority.Value ?? 3));

            taskManager.AddTask(task);
            textBoxName.Clear();
            numericPriority.Value = 3;
        }

        private void OnDeleteClick(object? sender, RoutedEventArgs e)
        {
            if (listBoxTasks.SelectedItem is TaskItem task)
            {
                taskManager.RemoveTask(task);
            }
            else
            {
                labelStatus.Text = "Ошибка: Выберите задачу для удаления!";
            }
        }

        private void OnDoneClick(object? sender, RoutedEventArgs e)
        {
            if (listBoxTasks.SelectedItem is TaskItem task)
            {
                taskManager.ToggleTaskStatus(task);
            }
            else
            {
                labelStatus.Text = "Ошибка: Выберите задачу!";
            }
        }

        private void OnFilterChanged(object? sender, SelectionChangedEventArgs e)
        {
            // Защита от вызова до инициализации
            if (listBoxTasks == null || comboBoxFilter == null) return;
            
            ApplyFilter();
        }

        // Обработчик CheckBox для включения/выключения уведомлений (усложненное)
        private void OnNotifyCheckedChanged(object? sender, RoutedEventArgs e)
        {
            if (labelStatus == null) return; // Защита от вызова до инициализации
            
            if (checkBoxNotify.IsChecked == true)
            {
                // Подписываемся на события
                if (taskChangedHandler != null)
                {
                    taskManager.TaskChanged -= taskChangedHandler;
                    taskManager.TaskChanged += taskChangedHandler;
                }
                labelStatus.Text = "Уведомления включены";
            }
            else
            {
                labelStatus.Text = "Уведомления выключены";
            }
        }
    }
}
