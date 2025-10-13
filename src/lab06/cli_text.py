# stats --input <txt> [--top 5]
# — анализ частот слов в тексте
# (использовать функции из lab03);

# cat --input <path> [-n]
# — вывод содержимого файла построчно
# (с нумерацией при -n).

import argparse
from pathlib import Path

# python -m src.lab06.cli_convert json2csv --in data/samples/people.json --out data/out/people.csv


def main():
    parser = argparse.ArgumentParser(description="CLI‑утилиты лабораторной №6")
    subparsers = parser.add_subparsers(dest="command")

    # подкоманда cat
    cat_parser = subparsers.add_parser("cat", help="Вывести содержимое файла")
    cat_parser.add_argument("--input", required=True)
    cat_parser.add_argument("-n", action="store_true", help="Нумеровать строки")

    # подкоманда stats
    stats_parser = subparsers.add_parser("stats", help="Частоты слов")
    stats_parser.add_argument("--input", required=True)
    stats_parser.add_argument("--top", type=int, default=5)

    args = parser.parse_args()

    if args.command == "cat":
        # python3 -m src.lab06.cli_text cat --input data/samples/cities.csv -n

        filepath = Path(args.input)

        if not filepath.exists():
            raise FileNotFoundError(f"Файл {filepath} не найден")

        with filepath.open("r", encoding="utf-8") as f:
            num = 1
            for line in f:
                line = line.rstrip("\n")
                if args.n:
                    print(f"{num}: {line}")
                    num += 1
                else:
                    print(line)

    elif args.command == "stats":
        """ Реализация команды stats """


if __name__ == "__main__":
    main()
