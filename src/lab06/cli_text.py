import argparse
from pathlib import Path
from src.lib.text import tokenize, count_freq, top_n


def main():
    """
    Точка входа для CLI-утилиты лабораторной работы №6 (текстовые инструменты).

    Назначение:
        Предоставляет две подкоманды:
        1. cat   — вывод содержимого текстового файла (с нумерацией строк при флаге -n);
        2. stats — анализ частот встречаемости слов в тексте.

    Подкоманды:
        cat --input <path> [-n]
            Выводит содержимое файла построчно.
            При указании флага -n добавляет нумерацию строк.

        stats --input <path> [--top N]
            Подсчитывает частоты слов в тексте, выводит N наиболее частых.
            Использует функции из модуля src.lib.text:
                - tokenize(text)
                - count_freq(tokens)
                - top_n(freq, n)

    Примеры:
        python3 -m src.lab06.cli_text cat --input data/samples/cities.csv -n
        python3 -m src.lab06.cli_text stats --input data/samples/input.txt --top 3

    Исключения:
        FileNotFoundError — если указанный файл не найден.
        ValueError — если текст пустой или содержит некорректные данные.
    """

    parser = argparse.ArgumentParser(description="CLI-утилиты лабораторной №6")
    subparsers = parser.add_subparsers(dest="command")

    # --- cat ---
    cat_parser = subparsers.add_parser("cat", help="Вывести содержимое файла")
    cat_parser.add_argument("--input", required=True, help="Путь к входному файлу")
    cat_parser.add_argument("-n", action="store_true", help="Нумеровать строки")

    # --- stats ---
    stats_parser = subparsers.add_parser("stats", help="Частоты слов в тексте")
    stats_parser.add_argument("--input", required=True, help="Путь к текстовому файлу")
    stats_parser.add_argument(
        "--top", type=int, default=5, help="Количество наиболее частых слов"
    )

    args = parser.parse_args()

    filepath = Path(args.input)

    if not filepath.exists():
        raise FileNotFoundError(f"Файл {filepath} не найден")

    if args.command == "cat":
        # python3 -m src.lab06.cli_text cat --input data/samples/cities.csv -n

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
        # python3 -m src.lab06.cli_text stats --input data/samples/input.txt --top 3

        content = [i for i in filepath.open("r", encoding="utf-8")]
        tokens = tokenize(text="".join(content))
        freq = count_freq(tokens=tokens)
        top = top_n(freq=freq, n=args.top)

        num = 1
        for q, w in top:
            print(f"{num}. {q} - {w}")
            num += 1


if __name__ == "__main__":
    main()
