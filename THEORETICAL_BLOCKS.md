# Theoretical Guide for Labs 8-10 Defense

This document contains the essential theoretical concepts you need to know to successfully defend laboratory works 8, 9, and 10.

## Laboratory Work 8: Object-Oriented Programming with @dataclass

### Core Concepts

#### 1. Object-Oriented Programming (OOP) Principles
- **Encapsulation**: Bundling data and methods that operate on that data within a class
- **Dataclass**: A decorator that automatically generates special methods like `__init__()`, `__repr__()`, `__eq__()` based on class fields
- **Class vs Instance**: Understanding the difference between class attributes/methods and instance attributes/methods

#### 2. @dataclass Decorator
- Automatically generates boilerplate code:
  - `__init__()` method based on field annotations
  - `__repr__()` method for string representation
  - `__eq__()` method for equality comparison
- Field types and validation
- `__post_init__()` method for custom initialization logic

#### 3. Data Validation
- Input validation in `__post_init__()`
- Exception handling with `ValueError`
- Date format validation using `datetime.strptime()`

#### 4. Serialization/Deserialization
- Converting objects to dictionaries (`to_dict()`)
- Creating objects from dictionaries (`from_dict()`)
- JSON serialization with `json.dump()` and `json.load()`
- File I/O operations with proper encoding

#### 5. Key Methods Implementation
- `age()` method for calculating student's age
- String representation with `__str__()`
- Class methods using `@classmethod` decorator

## Laboratory Work 9: Data Management with CSV Storage

### Core Concepts

#### 1. CRUD Operations
- **Create**: Adding new records to storage
- **Read**: Retrieving records from storage
- **Update**: Modifying existing records
- **Delete**: Removing records from storage

#### 2. CSV File Handling
- Using `csv.DictReader` and `csv.DictWriter`
- File path management with `pathlib.Path`
- Header management in CSV files
- Data type conversion between string (CSV) and appropriate types (float for GPA)

#### 3. Class Design for Data Management
- Constructor (`__init__()`) for initializing storage
- Private helper methods (prefixed with `_`)
- Data persistence between program runs
- Error handling for invalid records

#### 4. Search and Filter Operations
- Substring matching in text fields
- Case-insensitive search
- List comprehensions for filtering

#### 5. Data Statistics
- Aggregation functions (min, max, average)
- Grouping data by categories
- Sorting data by specific criteria
- Top-N queries

#### 6. Data Export
- Converting between CSV and JSON formats
- File format conversion techniques

## Laboratory Work 10: Data Structures - Stack, Queue, Linked List

### Core Concepts

#### 1. Asymptotic Complexity (Big O Notation)
- **O(1)** - Constant time operations
- **O(n)** - Linear time operations
- **O(log n)** - Logarithmic time operations
- Understanding time complexity for different operations

#### 2. Stack (LIFO - Last In, First Out)
- **Operations**:
  - `push(item)` - Add element to top - O(1)
  - `pop()` - Remove and return top element - O(1)
  - `peek()` - View top element without removing - O(1)
  - `is_empty()` - Check if stack is empty - O(1)
- **Applications**: Function call management, undo operations, expression evaluation

#### 3. Queue (FIFO - First In, First Out)
- **Operations**:
  - `enqueue(item)` - Add element to rear - O(1)
  - `dequeue()` - Remove and return front element - O(1)
  - `peek()` - View front element without removing - O(1)
  - `is_empty()` - Check if queue is empty - O(1)
- **Applications**: Task scheduling, breadth-first search, buffering

#### 4. Singly Linked List
- **Structure**: Nodes containing data and reference to next node
- **Operations**:
  - `append(value)` - Add to end - O(1) with tail reference
  - `prepend(value)` - Add to beginning - O(1)
  - `insert(idx, value)` - Insert at index - O(n)
  - `remove(value)` - Remove by value - O(n)
  - `remove_at(idx)` - Remove at index - O(n)
- **Advantages**: Dynamic size, efficient insertions/deletions at ends
- **Disadvantages**: No random access, extra memory for pointers

#### 5. Performance Comparison
- **Stack/Queue on list/deque vs custom implementations**
- **Insertion/deletion at beginning vs end**
- **Memory overhead of different structures**
- **When to use each structure**

### Implementation Details

#### 1. Stack Implementation
- Using Python `list` as underlying storage
- Exception handling for empty stack operations
- Proper encapsulation with private attributes

#### 2. Queue Implementation
- Using `collections.deque` for efficient operations
- Understanding why deque is better than list for queues
- Proper exception handling

#### 3. Singly Linked List Implementation
- Node class design
- Head and tail references for O(1) operations
- Size tracking
- Iterator implementation for easy traversal
- Proper memory management

#### 4. Benchmarking and Performance Analysis
- Time measurement with `time.time()`
- Statistical analysis of operation times
- Comparison between different implementations
- Understanding performance trade-offs

## Common Python Concepts Across All Labs

### 1. Type Hints
- Using `typing` module for type annotations
- `List`, `Dict`, `Any`, `Optional` types
- Benefits of type hinting for code maintainability

### 2. Exception Handling
- `try/except` blocks
- Raising custom exceptions
- Proper error messages

### 3. File I/O Operations
- Opening files with proper encoding
- Context managers (`with` statement)
- Reading and writing different file formats (CSV, JSON)

### 4. Testing
- Unit testing with `unittest` framework
- Test case organization
- Assertion methods
- Edge case testing

### 5. Code Quality
- Following PEP 8 style guidelines
- Using linters (ruff) and formatters (black)
- Writing clean, readable code
- Proper documentation with docstrings

## Defense Preparation Tips

### 1. Understand the Code Flow
- Be able to explain how each lab's main components work
- Know the purpose of each method and class
- Understand data flow between components

### 2. Know the Theory
- Be prepared to explain OOP concepts
- Understand data structures and their complexities
- Know when to use each data structure

### 3. Practice Implementation Details
- Be ready to explain implementation choices
- Understand why certain data structures were used
- Know the advantages and disadvantages of different approaches

### 4. Performance Considerations
- Understand time complexity of operations
- Be able to explain performance differences
- Know when optimization matters

### 5. Error Handling
- Understand how errors are handled in each lab
- Be prepared to discuss edge cases
- Know how to improve error handling if needed