#!/usr/bin/env python3
"""
Demo script to generate screenshots for Lab 9.
This script shows examples of all CRUD operations.
"""

from src.lab08.models import Student
from src.lab09.group import Group

""" python3 -m src.lab09.demo_screenshots """

def demo_crud_operations():
    print("=== Демонстрация CRUD-операций с группой студентов ===\n")
    
    # Initialize group
    storage_path = "data/lab09/students.csv"
    group = Group(storage_path)
    
    # 1. Read - List all students
    print("1. Просмотр всех студентов (READ):")
    students = group.list()
    for i, student in enumerate(students, 1):
        print(f"  {i}. {student}")
    print()
    
    # 2. Create - Add a new student
    print("2. Добавление нового студента (CREATE):")
    new_student = Student(
        fio="Новиков Николай Николаевич",
        birthdate="2004-02-29",
        group="БИВТ-21-4",
        gpa=4.5
    )
    group.add(new_student)
    print(f"  Добавлен: {new_student}\n")
    
    # 3. Read - List students after adding
    print("3. Список студентов после добавления:")
    students = group.list()
    for i, student in enumerate(students, 1):
        print(f"  {i}. {student}")
    print()
    
    # 4. Find - Search students
    print("4. Поиск студентов по подстроке 'Анна' (READ):")
    found_students = group.find("Анна")
    for i, student in enumerate(found_students, 1):
        print(f"  {i}. {student}")
    print()
    
    # 5. Update - Update a student's information
    print("5. Обновление информации о студенте (UPDATE):")
    updated = group.update("Петров Петр Петрович", gpa=4.2, group="БИВТ-21-4")
    if updated:
        print("  Успешно обновлены данные Петрова П.П.")
    else:
        print("  Студент не найден")
    print()
    
    # 6. Read - List students after update
    print("6. Список студентов после обновления:")
    students = group.list()
    for i, student in enumerate(students, 1):
        print(f"  {i}. {student}")
    print()
    
    # 7. Delete - Remove a student
    print("7. Удаление студента (DELETE):")
    removed_count = group.remove("Сидоров Сидор Сидорович")
    print(f"  Удалено {removed_count} студент(ов)\n")
    
    # 8. Read - Final list
    print("8. Финальный список студентов:")
    students = group.list()
    for i, student in enumerate(students, 1):
        print(f"  {i}. {student}")
    print()
    
    # 9. Statistics
    print("9. Статистика по группе:")
    stats = group.stats()
    print(f"  Всего студентов: {stats['count']}")
    print(f"  Минимальный GPA: {stats['min_gpa']}")
    print(f"  Максимальный GPA: {stats['max_gpa']}")
    print(f"  Средний GPA: {stats['avg_gpa']}")
    print("  Студентов по группам:")
    for group_name, count in stats['groups'].items():
        print(f"    {group_name}: {count}")
    print()
    
    # 10. Export to JSON
    print("10. Экспорт данных в JSON:")
    json_path = "data/lab09/students_export.json"
    group.export_to_json(json_path)
    print(f"  Данные экспортированы в {json_path}")


if __name__ == "__main__":
    demo_crud_operations()