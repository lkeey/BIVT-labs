import csv
from collections import Counter
from pathlib import Path
from typing import Iterable, Sequence

from src.lib.text import normalize, tokenize

"""
Функции:
    - read_text: чтение текстового файла целиком
    - write_csv: запись строк в CSV-файл
    - ensure_parent_dir: создание родительских директорий (опционально)
    - frequencies_from_text: частоты слов (использует normalize/tokenize из ЛР3)
    - sorted_word_counts: сортировка слов по убыванию частоты и алфавиту

Пример использования:
    from src.lab04.io_txt_csv import read_text, write_csv

    txt = read_text("data/input.txt")   # возвращает содержимое файла как строку
    write_csv([("word", "count"), ("test", 3)], "data/check.csv")  # создаст CSV

Краевые случаи:
    - Пустой файл -> возвращается пустая строка.
    - Очень большой файл -> читается целиком (по нашему ТЗ).
      В README рекомендуется построчное чтение для реальных больших данных.
    - write_csv([], "file.csv", header=None) -> создаётся пустой файл (0 строк).
    - write_csv([], "file.csv", header=("a","b")) -> файл содержит только заголовок.
"""


def ensure_parent_dir(path: str | Path) -> None:
    """
    Создать родительские директории для указанного пути, если их ещё нет.

    Args:
        path: путь к файлу (строка или pathlib.Path).
    """
    p = Path(path)
    if p.parent and not p.parent.exists():
        p.parent.mkdir(parents=True, exist_ok=True)


def read_text(path: str | Path, encoding: str = "utf-8") -> str:
    """
    Открыть текстовый файл и вернуть его содержимое как одну строку.

    Аргументы:
        path: путь к файлу (строка или pathlib.Path).
        encoding: кодировка файла (по умолчанию "utf-8").
                  Если нужна другая, можно указать, например: encoding="cp1251".

    Возвращает:
        str: содержимое файла.

    Падает с ошибками:
        FileNotFoundError: если файл не найден.
        UnicodeDecodeError: если содержимое не подходит под выбранную кодировку.
    """

    p = Path(path)
    return p.read_text(encoding=encoding)


def write_csv(
    rows: Iterable[Sequence], path: str | Path, header: tuple[str, ...] | None = None
) -> None:
    """
    Создать или перезаписать CSV-файл с разделителем ','.

    Аргументы:
        rows: последовательность строк (каждая строка — tuple или list).
        path: путь к CSV-файлу (строка или pathlib.Path).
        header: необязательный заголовок (tuple[str,...]), будет записан первой строкой.
    """

    p = Path(path)
    ensure_parent_dir(p)

    rows = list(rows)
    with p.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if header is not None:
            w.writerow(header)
        for r in rows:
            w.writerow(r)


def frequencies_from_text(text: str) -> dict[str, int]:
    """
    Подсчитать частоты слов в тексте, используя normalize/tokenize из ЛР3.

    Аргументы:
        text: исходный текст.

    Возвращает:
        dict[str, int]: словарь слово -> частота.
    """

    tokens = tokenize(normalize(text))
    return Counter(tokens)  # dict-like


def sorted_word_counts(freq: dict[str, int]) -> list[tuple[str, int]]:
    """
    Отсортировать пары (слово, частота):
      - сначала по убыванию частоты,
      - затем по алфавиту.

    Аргументы:
        freq: словарь слово -> частота.

    Возвращает:
        list[tuple[str, int]]: отсортированный список.
    """

    return sorted(freq.items(), key=lambda kv: (-kv[1], kv[0]))
