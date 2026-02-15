import csv
from pathlib import Path

from openpyxl import Workbook

from src.lib.io_txt_csv import ensure_parent_dir


def csv_to_xlsx(
    csv_path: str | Path,
    xlsx_path: str | Path,
    encoding: str = "utf-8",
) -> None:
    """
    Преобразует CSV-файл в Excel (XLSX) с проверкой структуры и корректности данных.

    CSV-файл должен содержать строку заголовков и хотя бы одну строку данных.
    Каждая колонка CSV будет перенесена в отдельный столбец листа Excel.

    Аргументы:
        csv_path: Путь к исходному CSV-файлу.
        xlsx_path: Путь к создаваемому XLSX-файлу.
        encoding: Кодировка файлов. По умолчанию "utf-8".

    Падает с:
        FileNotFoundError: Если CSV-файл отсутствует.
        ValueError: Если CSV не содержит заголовков или пуст.
                    Если структура CSV-файла некорректна.
    """

    csv_path = Path(csv_path)

    if not csv_path.exists():
        raise FileNotFoundError(f"CSV-файл {csv_path} не найден")

    wb = Workbook()
    ws = wb.active
    ws.title = "Sheet1"

    with csv_path.open("r", encoding=encoding) as csv_file:
        reader = csv.DictReader(csv_file)

        if not reader.fieldnames:
            raise ValueError("CSV без заголовков или пуст")

        ws.append(reader.fieldnames)

        for row in reader:
            ws.append([row[field] for field in reader.fieldnames])

    xlsx_path = Path(xlsx_path)
    ensure_parent_dir(xlsx_path)
    wb.save(xlsx_path)
