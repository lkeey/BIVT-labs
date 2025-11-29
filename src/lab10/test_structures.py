#!/usr/bin/env python3
"""Тесты для структур данных."""

import sys
import os
import unittest

# Add the parent directory to the path to allow imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from lab10.structures import Stack, Queue
from lab10.linked_list import SinglyLinkedList, Node


class TestStack(unittest.TestCase):
    """Тесты для стека."""
    
    def setUp(self):
        self.stack = Stack()
    
    def test_init(self):
        """Тест инициализации."""
        self.assertEqual(len(self.stack), 0)
        self.assertTrue(self.stack.is_empty())
    
    def test_push_pop(self):
        """Тест вставки и извлечения."""
        self.stack.push(1)
        self.stack.push(2)
        self.stack.push(3)
        
        self.assertEqual(len(self.stack), 3)
        self.assertFalse(self.stack.is_empty())
        
        self.assertEqual(self.stack.pop(), 3)
        self.assertEqual(self.stack.pop(), 2)
        self.assertEqual(self.stack.pop(), 1)
        
        self.assertEqual(len(self.stack), 0)
        self.assertTrue(self.stack.is_empty())
    
    def test_peek(self):
        """Тест просмотра верхнего элемента."""
        self.assertIsNone(self.stack.peek())
        
        self.stack.push(1)
        self.stack.push(2)
        
        self.assertEqual(self.stack.peek(), 2)
        self.assertEqual(len(self.stack), 2)  # peek не удаляет элемент
    
    def test_pop_empty(self):
        """Тест извлечения из пустого стека."""
        with self.assertRaises(IndexError):
            self.stack.pop()


class TestQueue(unittest.TestCase):
    """Тесты для очереди."""
    
    def setUp(self):
        self.queue = Queue()
    
    def test_init(self):
        """Тест инициализации."""
        self.assertEqual(len(self.queue), 0)
        self.assertTrue(self.queue.is_empty())
    
    def test_enqueue_dequeue(self):
        """Тест вставки и извлечения."""
        self.queue.enqueue(1)
        self.queue.enqueue(2)
        self.queue.enqueue(3)
        
        self.assertEqual(len(self.queue), 3)
        self.assertFalse(self.queue.is_empty())
        
        self.assertEqual(self.queue.dequeue(), 1)
        self.assertEqual(self.queue.dequeue(), 2)
        self.assertEqual(self.queue.dequeue(), 3)
        
        self.assertEqual(len(self.queue), 0)
        self.assertTrue(self.queue.is_empty())
    
    def test_peek(self):
        """Тест просмотра первого элемента."""
        self.assertIsNone(self.queue.peek())
        
        self.queue.enqueue(1)
        self.queue.enqueue(2)
        
        self.assertEqual(self.queue.peek(), 1)
        self.assertEqual(len(self.queue), 2)  # peek не удаляет элемент
    
    def test_dequeue_empty(self):
        """Тест извлечения из пустой очереди."""
        with self.assertRaises(IndexError):
            self.queue.dequeue()


class TestNode(unittest.TestCase):
    """Тесты для узла связного списка."""
    
    def test_init(self):
        """Тест инициализации."""
        node = Node(42)
        self.assertEqual(node.value, 42)
        self.assertIsNone(node.next)


class TestSinglyLinkedList(unittest.TestCase):
    """Тесты для односвязного списка."""
    
    def setUp(self):
        self.ll = SinglyLinkedList()
    
    def test_init(self):
        """Тест инициализации."""
        self.assertIsNone(self.ll.head)
        self.assertIsNone(self.ll.tail)
        self.assertEqual(len(self.ll), 0)
    
    def test_append(self):
        """Тест добавления в конец."""
        self.ll.append(1)
        self.assertEqual(self.ll.head.value, 1)
        self.assertEqual(self.ll.tail.value, 1)
        self.assertIsNone(self.ll.head.next)
        self.assertEqual(len(self.ll), 1)
        
        self.ll.append(2)
        self.assertEqual(self.ll.head.value, 1)
        self.assertEqual(self.ll.tail.value, 2)
        self.assertEqual(self.ll.head.next.value, 2)
        self.assertIsNone(self.ll.tail.next)
        self.assertEqual(len(self.ll), 2)
    
    def test_prepend(self):
        """Тест добавления в начало."""
        self.ll.prepend(1)
        self.assertEqual(self.ll.head.value, 1)
        self.assertEqual(self.ll.tail.value, 1)
        self.assertIsNone(self.ll.head.next)
        self.assertEqual(len(self.ll), 1)
        
        self.ll.prepend(0)
        self.assertEqual(self.ll.head.value, 0)
        self.assertEqual(self.ll.tail.value, 1)
        self.assertEqual(self.ll.head.next.value, 1)
        self.assertIsNone(self.ll.tail.next)
        self.assertEqual(len(self.ll), 2)
    
    def test_insert(self):
        """Тест вставки по индексу."""
        # Вставка в пустой список
        self.ll.insert(0, 1)
        self.assertEqual(list(self.ll), [1])
        
        # Вставка в начало
        self.ll.insert(0, 0)
        self.assertEqual(list(self.ll), [0, 1])
        
        # Вставка в конец
        self.ll.insert(2, 2)
        self.assertEqual(list(self.ll), [0, 1, 2])
        
        # Вставка в середину
        self.ll.insert(1, 0.5)
        self.assertEqual(list(self.ll), [0, 0.5, 1, 2])
        
        # Неверный индекс
        with self.assertRaises(IndexError):
            self.ll.insert(-1, -1)
        with self.assertRaises(IndexError):
            self.ll.insert(10, 10)
    
    def test_remove_at(self):
        """Тест удаления по индексу."""
        # Заполняем список
        for i in range(5):
            self.ll.append(i)
        self.assertEqual(list(self.ll), [0, 1, 2, 3, 4])
        
        # Удаление из середины
        self.ll.remove_at(2)
        self.assertEqual(list(self.ll), [0, 1, 3, 4])
        
        # Удаление из начала
        self.ll.remove_at(0)
        self.assertEqual(list(self.ll), [1, 3, 4])
        
        # Удаление из конца
        self.ll.remove_at(2)
        self.assertEqual(list(self.ll), [1, 3])
        
        # Удаление оставшихся элементов
        self.ll.remove_at(0)
        self.ll.remove_at(0)
        self.assertEqual(len(self.ll), 0)
        self.assertIsNone(self.ll.head)
        self.assertIsNone(self.ll.tail)
        
        # Удаление из пустого списка
        with self.assertRaises(IndexError):
            self.ll.remove_at(0)
    
    def test_remove(self):
        """Тест удаления по значению."""
        # Заполняем список
        for i in [1, 2, 3, 2, 4]:
            self.ll.append(i)
        self.assertEqual(list(self.ll), [1, 2, 3, 2, 4])
        
        # Удаление первого вхождения
        self.ll.remove(2)
        self.assertEqual(list(self.ll), [1, 3, 2, 4])
        
        # Удаление несуществующего элемента
        self.ll.remove(5)
        self.assertEqual(list(self.ll), [1, 3, 2, 4])
        
        # Удаление из пустого списка
        empty_ll = SinglyLinkedList()
        empty_ll.remove(1)
        self.assertEqual(len(empty_ll), 0)
    
    def test_iter(self):
        """Тест итерации."""
        values = [1, 2, 3, 4, 5]
        for value in values:
            self.ll.append(value)
        
        # Проверяем итерацию
        iterated_values = list(self.ll)
        self.assertEqual(iterated_values, values)
    
    def test_repr(self):
        """Тест строкового представления."""
        self.assertEqual(repr(self.ll), "SinglyLinkedList([])")
        
        self.ll.append(1)
        self.ll.append(2)
        self.assertEqual(repr(self.ll), "SinglyLinkedList([1, 2])")
    
    def test_display(self):
        """Тест красивого вывода."""
        self.assertEqual(self.ll.display(), "None")
        
        self.ll.append(1)
        self.assertEqual(self.ll.display(), "[1] -> None")
        
        self.ll.append(2)
        self.assertEqual(self.ll.display(), "[1] -> [2] -> None")


if __name__ == "__main__":
    unittest.main()