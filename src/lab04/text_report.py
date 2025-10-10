from src.lib.io_txt_csv import (
    read_text,
    write_csv,
    frequencies_from_text,
    sorted_word_counts,
)
import argparse
from src.lib.table import print_summary


def main():
    """
    Анализ текста и сохранение отчёта в CSV.

    Скрипт выполняет:
        1. Читает входной текстовый файл (--in, по умолчанию data/input.txt).
        2. Нормализует и токенизирует текст (функции из src/lib/text.py).
        3. Считает частоты слов.
        4. Сохраняет результат в CSV (--out, по умолчанию data/report.csv)
           с колонками: word,count (отсортировано по убыванию частоты, затем по слову).
        5. Печатает резюме в консоль:
            - количество всех слов
            - количество уникальных слов
            - топ-5 слов (в табличной форме или в виде списка).

    Аргументы командной строки:
        --in <путь>       путь к входному текстовому файлу (по умолчанию data/input.txt)
        --out <путь>      путь к выходному CSV (по умолчанию data/report.csv)
        --encoding <код>  кодировка входного файла (по умолчанию utf-8).
                          Например: --encoding cp1251

    Примеры запуска:
        python3 -m src.lab04.text_report
        python3 -m src.lab04.text_report --in data/lab04/b.txt --out data/report.csv
        python3 -m src.lab04.text_report --in data/lab04/a.txt --encoding cp1251u

    Падает с ошибками:
        - Если входной файл не найден → FileNotFoundError.
        - Если кодировка не подходит → UnicodeDecodeError.
        - Пустой файл → report.csv будет содержать только заголовок.
    """

    parser = argparse.ArgumentParser(description="Анализ текста и отчёт в CSV")
    parser.add_argument("--in", dest="input", default="data/lab04/input.txt")
    parser.add_argument("--out", dest="output", default="data/report.csv")
    parser.add_argument("--encoding", dest="encoding", default="utf-8")
    args = parser.parse_args()

    text = read_text(
        path=args.input,
        encoding=args.encoding,
    )
    freq = frequencies_from_text(text)
    data = sorted_word_counts(freq)

    write_csv(
        header=("word", "count"),
        rows=data,
        path=args.output,
    )

    print_summary(text=text, is_table=True)


main()


places = [
    {
        "title": "awda",
        "category": "напитки",
        "subcategory": "",
        "is_cute": "комфортно",
        "url": "",
    },
    {},
]
