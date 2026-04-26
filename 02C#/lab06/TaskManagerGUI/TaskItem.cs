using System;

namespace TaskManagerGUI
{
    public class TaskItem
    {
        public string Name { get; set; }
        public int Priority { get; set; }
        public bool IsDone { get; set; }
        public DateTime CreatedAt { get; set; }

        public TaskItem(string name, int priority)
        {
            Name = name;
            Priority = priority;
            IsDone = false;
            CreatedAt = DateTime.Now;
        }

        public override string ToString()
        {
            string status = IsDone ? "[✓]" : "[ ]";
            return $"{status} [{Priority}] {Name}";
        }
    }
}
