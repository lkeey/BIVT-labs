#!/usr/bin/env python3
"""Демонстрация работы структур данных."""

import sys
import os

# Add the parent directory to the path to allow imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from lab10.structures import Stack, Queue
from lab10.linked_list import SinglyLinkedList


def demo_stack():
    """Демонстрация работы стека."""
    print("=== Stack Demo ===")
    stack = Stack()
    
    # Добавляем элементы
    print("Добавляем элементы: 1, 2, 3")
    stack.push(1)
    stack.push(2)
    stack.push(3)
    print(f"Стек: {stack}")
    print(f"Размер: {len(stack)}")
    
    # Просматриваем верхний элемент
    print(f"Верхний элемент: {stack.peek()}")
    
    # Извлекаем элементы
    print("Извлекаем элементы:")
    while not stack.is_empty():
        item = stack.pop()
        print(f"  Извлечен: {item}")
    print()


def demo_queue():
    """Демонстрация работы очереди."""
    print("=== Queue Demo ===")
    queue = Queue()
    
    # Добавляем элементы
    print("Добавляем элементы: 'первый', 'второй', 'третий'")
    queue.enqueue("первый")
    queue.enqueue("второй")
    queue.enqueue("третий")
    print(f"Очередь: {queue}")
    print(f"Размер: {len(queue)}")
    
    # Просматриваем первый элемент
    print(f"Первый элемент: {queue.peek()}")
    
    # Извлекаем элементы
    print("Извлекаем элементы:")
    while not queue.is_empty():
        item = queue.dequeue()
        print(f"  Извлечен: {item}")
    print()


def demo_linked_list():
    """Демонстрация работы связного списка."""
    print("=== SinglyLinkedList Demo ===")
    ll = SinglyLinkedList()
    
    # Добавляем элементы в конец
    print("Добавляем элементы в конец: 1, 2, 3")
    ll.append(1)
    ll.append(2)
    ll.append(3)
    print(f"Список: {ll}")
    print(f"Красивый вывод: {ll.display()}")
    print(f"Размер: {len(ll)}")
    
    # Добавляем элемент в начало
    print("\nДобавляем элемент в начало: 0")
    ll.prepend(0)
    print(f"Список: {ll}")
    print(f"Красивый вывод: {ll.display()}")
    
    # Вставляем элемент по индексу
    print("\nВставляем элемент 1.5 по индексу 2")
    ll.insert(2, 1.5)
    print(f"Список: {ll}")
    print(f"Красивый вывод: {ll.display()}")
    
    # Удаляем элемент по значению
    print("\nУдаляем элемент 1.5")
    ll.remove(1.5)
    print(f"Список: {ll}")
    print(f"Красивый вывод: {ll.display()}")
    
    # Удаляем элемент по индексу
    print("\nУдаляем элемент по индексу 0")
    ll.remove_at(0)
    print(f"Список: {ll}")
    print(f"Красивый вывод: {ll.display()}")
    
    # Итерация по списку
    print("\nИтерация по списку:")
    for i, value in enumerate(ll):
        print(f"  Индекс {i}: {value}")
    print()


if __name__ == "__main__":
    demo_stack()
    demo_queue()
    demo_linked_list()