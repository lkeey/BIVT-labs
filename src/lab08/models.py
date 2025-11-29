from dataclasses import dataclass
from datetime import datetime, date
import json


@dataclass
class Student:
    fio: str
    birthdate: str
    group: str
    gpa: float

    def __post_init__(self):
        # Validate date format
        try:
            datetime.strptime(self.birthdate, "%Y-%m-%d")
        except ValueError:
            raise ValueError(f"Invalid birthdate format: {self.birthdate}. Expected format: YYYY-MM-DD")
        
        # Validate GPA range
        if not (0 <= self.gpa <= 5):
            raise ValueError(f"GPA must be between 0 and 5, got: {self.gpa}")

    def age(self) -> int:
        """Calculate the student's age in full years."""
        birth_date = datetime.strptime(self.birthdate, "%Y-%m-%d").date()
        today = date.today()
        age = today.year - birth_date.year
        # Adjust if birthday hasn't occurred this year
        if today.month < birth_date.month or (today.month == birth_date.month and today.day < birth_date.day):
            age -= 1
        return age

    def to_dict(self) -> dict:
        """Serialize the student object to a dictionary."""
        return {
            "fio": self.fio,
            "birthdate": self.birthdate,
            "group": self.group,
            "gpa": self.gpa
        }

    @classmethod
    def from_dict(cls, d: dict):
        """Create a Student instance from a dictionary."""
        return cls(
            fio=d["fio"],
            birthdate=d["birthdate"],
            group=d["group"],
            gpa=d["gpa"]
        )

    def __str__(self):
        """Return a string representation of the student."""
        return f"Student: {self.fio}, Group: {self.group}, GPA: {self.gpa}, Age: {self.age()}"


# Example usage (for testing)
if __name__ == "__main__":
    # Create a student
    student = Student("Ivanov Ivan Ivanovich", "2000-05-15", "SE-01", 4.2)
    print(student)
    print(f"Age: {student.age()}")
    
    # Serialize to dict
    student_dict = student.to_dict()
    print(f"Serialized: {student_dict}")
    
    # Deserialize from dict
    restored_student = Student.from_dict(student_dict)
    print(f"Restored: {restored_student}")