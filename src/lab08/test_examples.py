#!/usr/bin/env python3
"""
Test script to verify the examples in README.md work correctly
"""

import sys
import os

# Add the parent directory to the path so we can import from lab08
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from models import Student
from serialize import students_to_json, students_from_json

def test_students_to_json_example():
    """Test the students_to_json example from README.md"""
    print("Testing students_to_json example...")
    
    # Создаем список студентов
    students = [
        Student("Иванов Иван Иванович", "2000-05-15", "SE-01", 4.2),
        Student("Петрова Мария Сергеевна", "1999-12-03", "SE-02", 3.8),
        Student("Сидоров Алексей Дмитриевич", "2001-08-22", "SE-01", 4.5)
    ]

    # Сохраняем список студентов в файл JSON
    output_path = "../../data/lab08/test_examples_output.json"
    students_to_json(students, output_path)
    print("Данные успешно сохранены в файл test_examples_output.json")
    
    # Verify the file was created
    if os.path.exists(output_path):
        print("✓ Output file was created successfully")
    else:
        print("✗ Output file was not created")
        return False
    
    return True

def test_students_from_json_example():
    """Test the students_from_json example from README.md"""
    print("\nTesting students_from_json example...")
    
    # Загружаем студентов из файла JSON
    input_path = "../../data/lab08/students_input.json"
    students = students_from_json(input_path)

    # Выводим информацию о студентах
    print(f"Загружено {len(students)} студентов:")
    for student in students:
        print(student)
    
    return True

def test_combined_example():
    """Test the combined example from README.md"""
    print("\nTesting combined example...")
    
    # 1. Загружаем студентов из входного файла
    input_path = "../../data/lab08/students_input.json"
    input_students = students_from_json(input_path)
    print(f"Загружено {len(input_students)} студентов из входного файла")

    # 2. Выводим информацию о студентах
    for student in input_students:
        print(f"{student.fio} ({student.group}) - GPA: {student.gpa}, Возраст: {student.age()}")

    # 3. Создаем нового студента и добавляем его в список
    new_student = Student("Новиков Петр Сергеевич", "2002-03-10", "SE-03", 4.8)
    input_students.append(new_student)

    # 4. Сохраняем обновленный список в выходной файл
    output_path = "../../data/lab08/test_combined_output.json"
    students_to_json(input_students, output_path)
    print(f"Сохранено {len(input_students)} студентов в выходной файл")
    
    # Verify the file was created
    if os.path.exists(output_path):
        print("✓ Combined output file was created successfully")
    else:
        print("✗ Combined output file was not created")
        return False
    
    # Clean up test file
    os.remove(output_path)
    print("✓ Cleaned up test file")
    
    return True

def main():
    """Run all examples"""
    print("=== Testing Examples from README.md ===\n")
    
    success = True
    
    try:
        success &= test_students_to_json_example()
        success &= test_students_from_json_example()
        success &= test_combined_example()
        
        if success:
            print("\n=== All examples work correctly! ===")
        else:
            print("\n=== Some examples failed ===")
    except Exception as e:
        print(f"\n=== Error running examples: {e} ===")
        success = False
    
    # Clean up test file
    test_output = "../../data/lab08/test_examples_output.json"
    if os.path.exists(test_output):
        os.remove(test_output)
        print("✓ Cleaned up test output file")
    
    return success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)