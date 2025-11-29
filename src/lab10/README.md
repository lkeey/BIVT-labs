# Лабораторная работа №10 — Структуры данных: Stack, Queue, Linked List и бенчмарки

> **Цель:** реализовать базовые структуры данных (стек, очередь, связный список),
> сравнить их производительность и научиться думать в терминах асимптотики (O(1), O(n)).

---

## Теоретическая часть

### Стек (Stack)

**Стек** — это структура данных, работающая по принципу "последним пришёл — первым вышел" (LIFO, Last In First Out). 
Представляет собой список элементов, организованных по принципу LIFO.

**Основные операции:**
- `push(item)` — добавить элемент на вершину стека — **O(1)**
- `pop()` — извлечь верхний элемент — **O(1)**
- `peek()` — посмотреть верхний элемент без извлечения — **O(1)**
- `is_empty()` — проверить, пуст ли стек — **O(1)**

**Применение:**
- Обратная польская нотация
- Рекурсивные вызовы функций
- Отмена операций (undo)

### Очередь (Queue)

**Очередь** — это структура данных, работающая по принципу "первым пришёл — первым вышел" (FIFO, First In First Out).
Представляет собой список элементов, организованных по принципу FIFO.

**Основные операции:**
- `enqueue(item)` — добавить элемент в конец очереди — **O(1)**
- `dequeue()` — извлечь первый элемент — **O(1)**
- `peek()` — посмотреть первый элемент без извлечения — **O(1)**
- `is_empty()` — проверить, пуста ли очередь — **O(1)**

**Применение:**
- Планирование задач
- Обработка запросов
- Алгоритмы обхода графов

### Связный список (Linked List)

**Связный список** — это структура данных, состоящая из узлов, каждый из которых содержит данные и ссылку (указатель) на следующий узел в последовательности.

**Односвязный список (Singly Linked List):**
- Каждый узел содержит данные и указатель на следующий узел
- Первый узел называется "головой" (head)
- Последний узел указывает на `None`

**Основные операции:**
- `append(value)` — добавить элемент в конец — **O(1)** (при наличии tail)
- `prepend(value)` — добавить элемент в начало — **O(1)**
- `insert(idx, value)` — вставить элемент по индексу — **O(n)**
- `remove(value)` — удалить элемент по значению — **O(n)**
- `remove_at(idx)` — удалить элемент по индексу — **O(n)**

**Преимущества:**
- Динамический размер
- Эффективная вставка и удаление в начале — **O(1)**

**Недостатки:**
- Доступ к элементу по индексу — **O(n)**
- Дополнительная память на хранение указателей

---

## Реализация

### Stack и Queue (`src/lab10/structures.py`)

```python
from collections import deque
from typing import Any


class Stack:
    """Стек (LIFO) на базе list."""
    
    def __init__(self):
        self._data: list[Any] = []
    
    def push(self, item: Any) -> None:
        """Добавить элемент на вершину стека."""
        self._data.append(item)
    
    def pop(self) -> Any:
        """Снять верхний элемент стека и вернуть его."""
        if self.is_empty():
            raise IndexError("Невозможно извлечь элемент из пустого стека")
        return self._data.pop()
    
    def peek(self) -> Any | None:
        """Вернуть верхний элемент без удаления."""
        if self.is_empty():
            return None
        return self._data[-1]
    
    def is_empty(self) -> bool:
        """Проверить, пуст ли стек."""
        return len(self._data) == 0
    
    def __len__(self) -> int:
        """Вернуть количество элементов в стеке."""
        return len(self._data)
    
    def __repr__(self) -> str:
        return f"Stack({self._data})"


class Queue:
    """Очередь (FIFO) на базе collections.deque."""
    
    def __init__(self):
        self._data: deque[Any] = deque()
    
    def enqueue(self, item: Any) -> None:
        """Добавить элемент в конец очереди."""
        self._data.append(item)
    
    def dequeue(self) -> Any:
        """Взять элемент из начала очереди и вернуть его."""
        if self.is_empty():
            raise IndexError("Невозможно извлечь элемент из пустой очереди")
        return self._data.popleft()
    
    def peek(self) -> Any | None:
        """Вернуть первый элемент без удаления."""
        if self.is_empty():
            return None
        return self._data[0]
    
    def is_empty(self) -> bool:
        """Проверить, пуста ли очередь."""
        return len(self._data) == 0
    
    def __len__(self) -> int:
        """Вернуть количество элементов в очереди."""
        return len(self._data)
    
    def __repr__(self) -> str:
        return f"Queue({list(self._data)})"
```

### SinglyLinkedList (`src/lab10/linked_list.py`)

```python
from typing import Any


class Node:
    """Узел односвязного списка."""
    
    def __init__(self, value: Any):
        self.value = value
        self.next: 'Node' | None = None


class SinglyLinkedList:
    """Односвязный список."""
    
    def __init__(self):
        self.head: Node | None = None
        self.tail: Node | None = None
        self._size = 0
    
    def append(self, value: Any) -> None:
        """Добавить элемент в конец списка за O(1)."""
        new_node = Node(value)
        if self.head is None:
            # Список пуст
            self.head = new_node
            self.tail = new_node
        else:
            # Добавляем в конец
            self.tail.next = new_node
            self.tail = new_node
        self._size += 1
    
    def prepend(self, value: Any) -> None:
        """Добавить элемент в начало списка за O(1)."""
        new_node = Node(value)
        if self.head is None:
            # Список был пуст
            self.head = new_node
            self.tail = new_node
        else:
            # Вставляем в начало
            new_node.next = self.head
            self.head = new_node
        self._size += 1
    
    def insert(self, idx: int, value: Any) -> None:
        """Вставить элемент по индексу idx."""
        if idx < 0 or idx > self._size:
            raise IndexError("Индекс вне диапазона")
        
        if idx == 0:
            self.prepend(value)
            return
        
        if idx == self._size:
            self.append(value)
            return
        
        # Вставка в середину
        new_node = Node(value)
        current = self.head
        for _ in range(idx - 1):
            current = current.next
        
        new_node.next = current.next
        current.next = new_node
        self._size += 1
    
    def remove_at(self, idx: int) -> None:
        """Удалить элемент по индексу idx."""
        if idx < 0 or idx >= self._size:
            raise IndexError("Индекс вне диапазона")
        
        if idx == 0:
            # Удаление первого элемента
            self.head = self.head.next
            if self.head is None:
                # Список стал пустым
                self.tail = None
            self._size -= 1
            return
        
        # Найти элемент перед удаляемым
        current = self.head
        for _ in range(idx - 1):
            current = current.next
        
        # Удалить элемент
        node_to_remove = current.next
        current.next = node_to_remove.next
        
        # Если удалили последний элемент, обновить tail
        if node_to_remove == self.tail:
            self.tail = current
        
        self._size -= 1
    
    def remove(self, value: Any) -> None:
        """Удалить первое вхождение значения value."""
        if self.head is None:
            return  # Список пуст
        
        if self.head.value == value:
            # Удаление первого элемента
            self.head = self.head.next
            if self.head is None:
                # Список стал пустым
                self.tail = None
            self._size -= 1
            return
        
        # Поиск элемента для удаления
        current = self.head
        while current.next is not None and current.next.value != value:
            current = current.next
        
        if current.next is not None:
            # Нашли элемент для удаления
            node_to_remove = current.next
            current.next = node_to_remove.next
            
            # Если удалили последний элемент, обновить tail
            if node_to_remove == self.tail:
                self.tail = current
            
            self._size -= 1
    
    def __iter__(self):
        """Возвращает итератор по значениям в списке."""
        current = self.head
        while current is not None:
            yield current.value
            current = current.next
    
    def __len__(self) -> int:
        """Возвращает количество элементов."""
        return self._size
    
    def __repr__(self) -> str:
        """Возвращает строковое представление."""
        values = list(self)
        return f"SinglyLinkedList({values})"
    
    def display(self) -> str:
        """Красивый текстовый вывод структуры."""
        if self.head is None:
            return "None"
        
        result = ""
        current = self.head
        while current is not None:
            result += f"[{current.value}]"
            if current.next is not None:
                result += " -> "
            else:
                result += " -> None"
            current = current.next
        return result
```

---

## Примеры использования

### Stack

```python
>>> from src.lab10.structures import Stack
>>> stack = Stack()
>>> stack.push(1)
>>> stack.push(2)
>>> stack.push(3)
>>> print(stack)
Stack([1, 2, 3])
>>> stack.pop()
3
>>> stack.peek()
2
>>> len(stack)
2
```

### Queue

```python
>>> from src.lab10.structures import Queue
>>> queue = Queue()
>>> queue.enqueue("первый")
>>> queue.enqueue("второй")
>>> queue.enqueue("третий")
>>> print(queue)
Queue(['первый', 'второй', 'третий'])
>>> queue.dequeue()
'первый'
>>> queue.peek()
'второй'
>>> len(queue)
2
```

### SinglyLinkedList

```python
>>> from src.lab10.linked_list import SinglyLinkedList
>>> ll = SinglyLinkedList()
>>> ll.append(1)
>>> ll.append(2)
>>> ll.append(3)
>>> ll.prepend(0)
>>> print(ll)
SinglyLinkedList([0, 1, 2, 3])
>>> ll.display()
'[0] -> [1] -> [2] -> [3] -> None'
>>> ll.insert(2, 1.5)
>>> print(list(ll))
[0, 1, 1.5, 2, 3]
>>> ll.remove(1.5)
>>> print(len(ll))
4
```

---

## Бенчмарки и анализ производительности

Для анализа производительности структур данных были проведены тесты с различным количеством операций.

### Результаты тестирования (10,000 операций)

```
=== Benchmark Stack (n=10000) ===
Вставка 10000 элементов: 0.000487 сек
Извлечение 10000 элементов: 0.001265 сек

=== Benchmark Queue (n=10000) ===
Вставка 10000 элементов: 0.000481 сек
Извлечение 10000 элементов: 0.001324 сек

=== Benchmark SinglyLinkedList (n=10000) ===
Вставка 10000 элементов в конец: 0.001710 сек
Вставка 10000 элементов в начало: 0.001643 сек
Удаление 10000 элементов с начала: 0.001466 сек
```

### Сравнение структур данных

```
=== Сравнение структур данных ===
Операция                  Stack        Queue        LinkedList  
------------------------------------------------------------
Вставка (push/enqueue)    0.000439     0.000468     0.001585    
Извлечение (pop/dequeue)  0.001223     0.001264     0.001552    
Вставка в начало          -            -            0.002150    
```

### Выводы

1. **Stack на базе list**:
   - Эффективен для операций вставки/удаления с конца (вершины стека) — O(1)
   - Вставка 10,000 элементов занимает ~0.0004 секунды
   - Извлечение 10,000 элементов занимает ~0.0013 секунды

2. **Queue на базе deque**:
   - Эффективен для операций вставки в конец и удаления из начала — O(1)
   - Вставка 10,000 элементов занимает ~0.0005 секунды
   - Извлечение 10,000 элементов занимает ~0.0013 секунды
   - deque оптимизирован для операций с обоих концов, что делает его идеальным выбором для очереди

3. **SinglyLinkedList**:
   - Эффективен для вставки/удаления в начале и конце — O(1) (при наличии tail)
   - Вставка 10,000 элементов в конец занимает ~0.0017 секунды
   - Вставка 10,000 элементов в начало занимает ~0.0016 секунды
   - Использует больше памяти из-за хранения указателей
   - Медленнее, чем list/deque, из-за накладных расходов на создание объектов Node

### Когда что использовать:

- **Stack**: Когда нужны только операции с одним концом данных (например, история браузера)
- **Queue**: Когда важен порядок поступления данных (например, обработка запросов)
- **LinkedList**: Когда часто меняется размер и нужны эффективные вставки/удаления в начале/конце

---

## Заключение

В ходе лабораторной работы были реализованы три базовые структуры данных: стек, очередь и односвязный список. 
Каждая структура имеет свои особенности и области применения. 
Понимание асимптотической сложности операций позволяет выбирать наиболее подходящую структуру данных для конкретной задачи.

Результаты бенчмарков показывают, что:
- Stack и Queue на основе встроенных структур Python (list и deque) работают быстрее
- SinglyLinkedList имеет большую накладную стоимость из-за создания объектов Node
- Для большинства практических задач лучше использовать встроенные структуры данных
- LinkedList полезен в академических целях и в специфических случаях, где важна концепция связных структур