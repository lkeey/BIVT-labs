using System;

namespace TaskManagerGUI
{
    public class TaskEventArgs : EventArgs
    {
        public TaskItem Task { get; }
        public string Action { get; }
        public DateTime Time { get; }

        public TaskEventArgs(TaskItem task, string action)
        {
            Task = task;
            Action = action;
            Time = DateTime.Now;
        }
    }
}
