#!/usr/bin/env python3
"""Бенчмарк для структур данных."""

import sys
import os
import time

# Add the parent directory to the path to allow imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from lab10.structures import Stack, Queue
from lab10.linked_list import SinglyLinkedList


def benchmark_stack(n=10000):
    """Бенчмарк для стека."""
    print(f"=== Benchmark Stack (n={n}) ===")
    stack = Stack()
    
    # Тест вставки
    start = time.time()
    for i in range(n):
        stack.push(i)
    push_time = time.time() - start
    
    # Тест извлечения
    start = time.time()
    while not stack.is_empty():
        stack.pop()
    pop_time = time.time() - start
    
    print(f"Вставка {n} элементов: {push_time:.6f} сек")
    print(f"Извлечение {n} элементов: {pop_time:.6f} сек")
    print()


def benchmark_queue(n=10000):
    """Бенчмарк для очереди."""
    print(f"=== Benchmark Queue (n={n}) ===")
    queue = Queue()
    
    # Тест вставки
    start = time.time()
    for i in range(n):
        queue.enqueue(i)
    enqueue_time = time.time() - start
    
    # Тест извлечения
    start = time.time()
    while not queue.is_empty():
        queue.dequeue()
    dequeue_time = time.time() - start
    
    print(f"Вставка {n} элементов: {enqueue_time:.6f} сек")
    print(f"Извлечение {n} элементов: {dequeue_time:.6f} сек")
    print()


def benchmark_linked_list(n=10000):
    """Бенчмарк для связного списка."""
    print(f"=== Benchmark SinglyLinkedList (n={n}) ===")
    
    # Тест вставки в конец
    ll = SinglyLinkedList()
    start = time.time()
    for i in range(n):
        ll.append(i)
    append_time = time.time() - start
    
    # Тест вставки в начало
    ll2 = SinglyLinkedList()
    start = time.time()
    for i in range(n):
        ll2.prepend(i)
    prepend_time = time.time() - start
    
    # Тест извлечения с начала
    start = time.time()
    while len(ll2) > 0:
        ll2.remove_at(0)
    remove_time = time.time() - start
    
    print(f"Вставка {n} элементов в конец: {append_time:.6f} сек")
    print(f"Вставка {n} элементов в начало: {prepend_time:.6f} сек")
    print(f"Удаление {n} элементов с начала: {remove_time:.6f} сек")
    print()


def benchmark_python_list(n=10000):
    """Бенчмарк для обычного списка Python."""
    print(f"=== Benchmark Python List (n={n}) ===")
    
    # Тест вставки в конец (как стек)
    lst = []
    start = time.time()
    for i in range(n):
        lst.append(i)
    append_time = time.time() - start
    
    # Тест извлечения с конца (как стек)
    start = time.time()
    while len(lst) > 0:
        lst.pop()
    pop_time = time.time() - start
    
    # Тест вставки в начало
    lst2 = []
    start = time.time()
    for i in range(n):
        lst2.insert(0, i)
    insert_begin_time = time.time() - start
    
    # Тест извлечения с начала
    start = time.time()
    while len(lst2) > 0:
        lst2.pop(0)
    pop_begin_time = time.time() - start
    
    print(f"Вставка {n} элементов в конец: {append_time:.6f} сек")
    print(f"Извлечение {n} элементов с конца: {pop_time:.6f} сек")
    print(f"Вставка {n} элементов в начало: {insert_begin_time:.6f} сек")
    print(f"Извлечение {n} элементов с начала: {pop_begin_time:.6f} сек")
    print()


def compare_structures():
    """Сравнение структур данных."""
    print("=== Сравнение структур данных ===")
    n = 10000
    
    # Stack
    stack = Stack()
    start = time.time()
    for i in range(n):
        stack.push(i)
    stack_push_time = time.time() - start
    
    start = time.time()
    for _ in range(n):
        if not stack.is_empty():
            stack.pop()
    stack_pop_time = time.time() - start
    
    # Queue
    queue = Queue()
    start = time.time()
    for i in range(n):
        queue.enqueue(i)
    queue_enqueue_time = time.time() - start
    
    start = time.time()
    for _ in range(n):
        if not queue.is_empty():
            queue.dequeue()
    queue_dequeue_time = time.time() - start
    
    # LinkedList
    ll = SinglyLinkedList()
    start = time.time()
    for i in range(n):
        ll.append(i)
    ll_append_time = time.time() - start
    
    ll2 = SinglyLinkedList()
    start = time.time()
    for i in range(n):
        ll2.prepend(i)
    ll_prepend_time = time.time() - start
    
    start = time.time()
    while len(ll2) > 0:
        ll2.remove_at(0)
    ll_remove_time = time.time() - start
    
    # Python List (как стек)
    lst = []
    start = time.time()
    for i in range(n):
        lst.append(i)
    list_append_time = time.time() - start
    
    start = time.time()
    for _ in range(n):
        if len(lst) > 0:
            lst.pop()
    list_pop_time = time.time() - start
    
    # Python List (как очередь - неэффективно)
    lst_queue = []
    start = time.time()
    for i in range(n):
        lst_queue.append(i)
    list_queue_enqueue_time = time.time() - start
    
    start = time.time()
    for _ in range(n):
        if len(lst_queue) > 0:
            lst_queue.pop(0)  # Неэффективная операция!
    list_queue_dequeue_time = time.time() - start
    
    print(f"{'Операция':<30} {'Stack':<12} {'Queue':<12} {'LinkedList':<12} {'Python List':<12}")
    print("-" * 75)
    print(f"{'Вставка (push/enqueue/append)':<30} {stack_push_time:<12.6f} {queue_enqueue_time:<12.6f} {ll_append_time:<12.6f} {list_append_time:<12.6f}")
    print(f"{'Извлечение (pop/dequeue/pop)':<30} {stack_pop_time:<12.6f} {queue_dequeue_time:<12.6f} {ll_remove_time:<12.6f} {list_pop_time:<12.6f}")
    print(f"{'Вставка в начало':<30} {'-':<12} {'-':<12} {ll_prepend_time:<12.6f} {'Очень медл.':<12}")
    print(f"{'Очередь (pop(0) - неэфф.)':<30} {'-':<12} {'-':<12} {'-':<12} {list_queue_dequeue_time:<12.6f}")
    print()


if __name__ == "__main__":
    n = 10000
    benchmark_stack(n)
    benchmark_queue(n)
    benchmark_linked_list(n)
    benchmark_python_list(n)
    compare_structures()