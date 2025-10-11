from pathlib import Path
from src.lib.io_txt_csv import ensure_parent_dir, write_csv
import csv
from openpyxl import Workbook


def csv_to_xlsx(
    csv_path: str | Path,
    xlsx_path: str | Path,
    encoding: str = "utf-8",
) -> None:
    wb = Workbook()
    ws = wb.active
    ws.title = "Sheet1"

    csv_path = Path(csv_path)
    with csv_path.open("r", encoding=encoding) as csv_file:
        reader = csv.DictReader(csv_file)

        ws.append(reader.fieldnames)

        for row in reader:
            ws.append([row[field] for field in reader.fieldnames])

    xlsx_path = Path(xlsx_path)
    ensure_parent_dir(xlsx_path)
    wb.save(xlsx_path)
