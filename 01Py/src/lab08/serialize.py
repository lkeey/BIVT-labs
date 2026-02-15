import json
from typing import List
from models import Student


def students_to_json(students: List[Student], path: str):
    """
    Save a list of students to a JSON file.
    
    Args:
        students: List of Student objects
        path: Path to the output JSON file
    """
    data = [student.to_dict() for student in students]
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def students_from_json(path: str) -> List[Student]:
    """
    Load a list of students from a JSON file.
    
    Args:
        path: Path to the input JSON file
        
    Returns:
        List of Student objects
    """
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    students = [Student.from_dict(item) for item in data]
    
    return students