import argparse

from src.lib.cvs_xlsx import csv_to_xlsx
from src.lib.json_csv import csv_to_json, json_to_csv


def main():
    """
    Точка входа для CLI-утилиты лабораторной работы №6.

    Назначение:
        Предоставляет интерфейс командной строки для конвертации файлов между форматами:
        JSON ↔ CSV и CSV → XLSX.

    Подкоманды:
        json2csv — конвертировать JSON в CSV
        csv2json — конвертировать CSV в JSON
        csv2xlsx — конвертировать CSV в XLSX

    Примеры:
        python3 -m src.lab06.cli_convert json2csv --in data/samples/people.json --out data/out/people.csv
        python3 -m src.lab06.cli_convert csv2json --in data/out/people.csv --out data/out/people.json
        python3 -m src.lab06.cli_convert csv2xlsx --in data/out/people.csv --out data/out/people.xlsx

    Исключения:
        FileNotFoundError — если указанный входной файл не существует.
        ValueError — если структура входных данных некорректна.
    """

    parser = argparse.ArgumentParser(description="CLI-утилиты лабораторной №6")
    subparsers = parser.add_subparsers(dest="command")

    # --- json2csv ---
    json2csv_parser = subparsers.add_parser(
        "json2csv", help="Конвертировать JSON в CSV"
    )
    json2csv_parser.add_argument(
        "--in", dest="input", required=True, help="Путь к JSON-файлу"
    )
    json2csv_parser.add_argument(
        "--out", dest="output", required=True, help="Путь для CSV-файла"
    )

    # --- csv2json ---
    csv2json_parser = subparsers.add_parser(
        "csv2json", help="Конвертировать CSV в JSON"
    )
    csv2json_parser.add_argument(
        "--in", dest="input", required=True, help="Путь к CSV-файлу"
    )
    csv2json_parser.add_argument(
        "--out", dest="output", required=True, help="Путь для JSON-файла"
    )

    # --- csv2xlsx ---
    csv2xlsx_parser = subparsers.add_parser(
        "csv2xlsx", help="Конвертировать CSV в XLSX"
    )
    csv2xlsx_parser.add_argument(
        "--in", dest="input", required=True, help="Путь к CSV-файлу"
    )
    csv2xlsx_parser.add_argument(
        "--out", dest="output", required=True, help="Путь для XLSX-файла"
    )

    args = parser.parse_args()

    # --- Выполнение выбранной команды ---
    if args.command == "json2csv":
        json_to_csv(
            json_path=args.input,
            csv_path=args.output,
        )

    elif args.command == "csv2json":
        csv_to_json(
            csv_path=args.input,
            json_path=args.output,
        )

    elif args.command == "csv2xlsx":
        csv_to_xlsx(
            csv_path=args.input,
            xlsx_path=args.output,
        )


if __name__ == "__main__":
    main()
