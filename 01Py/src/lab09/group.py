import csv
from pathlib import Path
from typing import List, Dict, Any
from src.lab08.models import Student
from src.lib.io_txt_csv import ensure_parent_dir, write_csv
from src.lib.json_csv import csv_to_json


class Group:
    def __init__(self, storage_path: str):
        """
        Initialize the Group with a path to the CSV storage file.
        
        Args:
            storage_path: Path to the CSV file for student storage
        """
        self.path = Path(storage_path)
        self._ensure_storage_exists()

    def _ensure_storage_exists(self) -> None:
        """Create the CSV file with header if it doesn't exist."""
        if not self.path.exists():
            ensure_parent_dir(self.path)
            write_csv([], self.path, header=("fio", "birthdate", "group", "gpa"))

    def _read_all(self) -> List[Dict[str, str]]:
        """
        Read all rows from the CSV file.
        
        Returns:
            List of dictionaries representing each row
        """
        if not self.path.exists():
            return []
            
        with self.path.open("r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            return list(reader)

    def _write_all(self, rows: List[Dict[str, str]]) -> None:
        """
        Write all rows to the CSV file.
        
        Args:
            rows: List of dictionaries to write to the CSV
        """
        if rows:
            # Convert dict rows to tuple rows for write_csv
            header = tuple(rows[0].keys())
            tuple_rows = [tuple(row.values()) for row in rows]
            write_csv(tuple_rows, self.path, header=header)
        else:
            # Write header only if no rows
            write_csv([], self.path, header=("fio", "birthdate", "group", "gpa"))

    def list(self) -> List[Student]:
        """
        Get all students from the storage.
        
        Returns:
            List of Student objects
        """
        rows = self._read_all()
        students = []
        for row in rows:
            try:
                # Convert GPA to float since CSV stores it as string
                row_copy = row.copy()
                row_copy["gpa"] = float(row_copy["gpa"])
                student = Student.from_dict(row_copy)
                students.append(student)
            except (ValueError, KeyError) as e:
                # Skip invalid records
                print(f"Warning: Skipping invalid record: {row}. Error: {e}")
        return students

    def add(self, student: Student) -> None:
        """
        Add a new student to the storage.
        
        Args:
            student: Student object to add
        """
        rows = self._read_all()
        # Convert GPA to string for CSV storage
        student_dict = student.to_dict()
        student_dict["gpa"] = str(student_dict["gpa"])
        rows.append(student_dict)
        self._write_all(rows)

    def find(self, substr: str) -> List[Student]:
        """
        Find students by substring in their FIO.
        
        Args:
            substr: Substring to search for in FIO
            
        Returns:
            List of matching Student objects
        """
        all_students = self.list()
        return [s for s in all_students if substr.lower() in s.fio.lower()]

    def remove(self, fio: str) -> int:
        """
        Remove student(s) by FIO.
        
        Args:
            fio: Full name of the student to remove
            
        Returns:
            Number of students removed
        """
        rows = self._read_all()
        initial_count = len(rows)
        rows = [r for r in rows if r["fio"] != fio]
        final_count = len(rows)
        self._write_all(rows)
        return initial_count - final_count

    def update(self, fio: str, **fields) -> bool:
        """
        Update fields of an existing student.
        
        Args:
            fio: Full name of the student to update
            **fields: Fields to update (fio, birthdate, group, gpa)
            
        Returns:
            True if student was found and updated, False otherwise
        """
        rows = self._read_all()
        updated = False
        
        for row in rows:
            if row["fio"] == fio:
                # Update the fields
                for key, value in fields.items():
                    if key in row:
                        # Convert GPA to string for storage
                        if key == "gpa":
                            row[key] = str(value)
                        else:
                            row[key] = str(value)
                updated = True
                break
                
        if updated:
            self._write_all(rows)
        return updated

    def stats(self) -> Dict[str, Any]:
        """
        Get statistics about the group.
        
        Returns:
            Dictionary with group statistics
        """
        students = self.list()
        
        if not students:
            return {
                "count": 0,
                "min_gpa": None,
                "max_gpa": None,
                "avg_gpa": None,
                "groups": {},
                "top_5_students": []
            }
        
        # Calculate basic statistics
        gpas = [s.gpa for s in students]
        count = len(students)
        min_gpa = min(gpas)
        max_gpa = max(gpas)
        avg_gpa = sum(gpas) / count
        
        # Group statistics
        groups = {}
        for s in students:
            groups[s.group] = groups.get(s.group, 0) + 1
        
        # Top 5 students by GPA
        top_students = sorted(students, key=lambda s: s.gpa, reverse=True)[:5]
        top_5_students = [{"fio": s.fio, "gpa": s.gpa} for s in top_students]
        
        return {
            "count": count,
            "min_gpa": min_gpa,
            "max_gpa": max_gpa,
            "avg_gpa": round(avg_gpa, 2),
            "groups": groups,
            "top_5_students": top_5_students
        }

    def export_to_json(self, json_path: str) -> None:
        """
        Export the group data to JSON format.
        
        Args:
            json_path: Path to the output JSON file
        """
        csv_to_json(self.path, json_path)