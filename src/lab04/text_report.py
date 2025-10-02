from src.lab04.io_txt_csv import (
    read_text,
    write_csv,
    frequencies_from_text,
    sorted_word_counts,
)
import argparse
from src.lib.table import print_summary


def main():
    """
    Запуск:
        python3 -m src.lab04.text_report --in data/lab04/b.txt --out data/report.csv
    """

    parser = argparse.ArgumentParser(description="Анализ текста и отчёт в CSV")
    parser.add_argument("--in", dest="input", default="data/input.txt")
    parser.add_argument("--out", dest="output", default="data/report.csv")
    parser.add_argument("--encoding", dest="encoding", default="utf-8")
    args = parser.parse_args()

    text = read_text(args.input, encoding=args.encoding)
    freq = frequencies_from_text(text)
    data = sorted_word_counts(freq)

    write_csv(
        header=("word", "count"),
        rows=data,
        path="data/check.csv",
    )

    print_summary(text=text, is_table=True)


main()
