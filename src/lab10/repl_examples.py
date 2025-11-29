#!/usr/bin/env python3
"""
Примеры для демонстрации в интерпретаторе Python.

Эти примеры можно копировать и вставлять в интерпретатор Python построчно.
"""

# Примеры для Stack
stack_examples = """
from lab10.structures import Stack
stack = Stack()
stack.push(1)
stack.push(2)
stack.push(3)
print(stack)
stack.pop()
stack.peek()
len(stack)
"""

# Примеры для Queue
queue_examples = """
from lab10.structures import Queue
queue = Queue()
queue.enqueue("первый")
queue.enqueue("второй")
queue.enqueue("третий")
print(queue)
queue.dequeue()
queue.peek()
len(queue)
"""

# Примеры для SinglyLinkedList
linked_list_examples = """
from lab10.linked_list import SinglyLinkedList
ll = SinglyLinkedList()
ll.append(1)
ll.append(2)
ll.append(3)
ll.prepend(0)
print(ll)
ll.display()
ll.insert(2, 1.5)
list(ll)
ll.remove(1.5)
len(ll)
"""

if __name__ == "__main__":
    print("Примеры для Stack:")
    print(stack_examples)
    print("\nПримеры для Queue:")
    print(queue_examples)
    print("\nПримеры для SinglyLinkedList:")
    print(linked_list_examples)