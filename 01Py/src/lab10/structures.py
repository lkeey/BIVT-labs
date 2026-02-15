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