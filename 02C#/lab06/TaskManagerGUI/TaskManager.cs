using System;
using System.Collections.Generic;
using System.Linq;

namespace TaskManagerGUI
{
    public class TaskManager
    {
        private List<TaskItem> allTasks = new List<TaskItem>();

        public event EventHandler<TaskEventArgs>? TaskChanged;

        public void AddTask(TaskItem task)
        {
            allTasks.Add(task);
            TaskChanged?.Invoke(this, new TaskEventArgs(task, "Добавлена"));
        }

        public void RemoveTask(TaskItem task)
        {
            allTasks.Remove(task);
            TaskChanged?.Invoke(this, new TaskEventArgs(task, "Удалена"));
        }

        public void ToggleTaskStatus(TaskItem task)
        {
            task.IsDone = !task.IsDone;
            string action = task.IsDone ? "Выполнена" : "Возвращена";
            TaskChanged?.Invoke(this, new TaskEventArgs(task, action));
        }

        public List<TaskItem> GetFilteredTasks(Func<TaskItem, bool> filter)
        {
            return allTasks
                .Where(filter)
                .OrderBy(t => t.IsDone)
                .ThenByDescending(t => t.Priority)
                .ToList();
        }

        public List<TaskItem> GetAllTasks() => allTasks;
    }
}
